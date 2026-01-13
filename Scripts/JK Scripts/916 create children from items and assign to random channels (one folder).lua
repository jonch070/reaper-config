-- Random Channel Routing (Single Parent)
-- Takes all selected items and:
--   * creates/uses a single parent folder track
--   * ensures parent has at least 16 channels
--   * moves each item to a new child track
--   * routes each child: SRC mono ch1 -> random mono parent channel (1..16, skip 4)
-- Finally selects parent and all created children.

local MIN_PARENT_CHANS = 16

-- Utility: make list 1..16 excluding 4
local function build_available_channels()
  local t = {}
  for i = 1, 16 do
    if i ~= 4 then table.insert(t, i) end
  end
  return t
end

-- Collect all selected items
local function collect_selected_items()
  local items = {}
  local sel_item_count = reaper.CountSelectedMediaItems(0)

  if sel_item_count > 0 then
    for i = 0, sel_item_count - 1 do
      table.insert(items, reaper.GetSelectedMediaItem(0, i))
    end
  end

  return items
end

-- Seed RNG so runs differ
math.randomseed(math.floor(reaper.time_precise() * 1e6) % 2^31)

local items = collect_selected_items()
if #items == 0 then
  reaper.ShowMessageBox("No items selected", "Error", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Use first selected track as parent, or create a new one
local parent
local sel_trk_count = reaper.CountSelectedTracks(0)
if sel_trk_count > 0 then
  parent = reaper.GetSelectedTrack(0, 0)
else
  -- No track selected, insert a new track at the top
  reaper.InsertTrackAtIndex(0, false)
  parent = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(parent, "P_NAME", "Random Routing Parent", true)
end

-- Ensure parent has at least MIN_PARENT_CHANS
local parent_chans = reaper.GetMediaTrackInfo_Value(parent, "I_NCHAN")
if parent_chans < MIN_PARENT_CHANS then
  reaper.SetMediaTrackInfo_Value(parent, "I_NCHAN", MIN_PARENT_CHANS)
end

-- Start folder on parent (keep parent's master send as-is)
reaper.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)

local available_channels = build_available_channels()
local all_created_children = {}
local last_child = nil

-- Insert a child for each item, right below parent
for i, item in ipairs(items) do
  -- Recompute parent index each time (track list changes as we insert)
  local parent_idx = reaper.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER") - 1
  local insert_idx = parent_idx + i

  reaper.InsertTrackAtIndex(insert_idx, false)
  local child = reaper.GetTrack(0, insert_idx)
  last_child = child
  table.insert(all_created_children, child)

  -- Move this item to the child
  reaper.MoveMediaItemToTrack(item, child)

  -- Configure child
  reaper.SetMediaTrackInfo_Value(child, "I_NCHAN", 2)  -- stereo is fine
  reaper.SetMediaTrackInfo_Value(child, "B_MAINSEND", 0) -- child -> master OFF

  -- Routing: child ch1 (mono) -> random mono parent channel (skip 4)
  local target_chan = available_channels[math.random(#available_channels)]
  local send_idx = reaper.CreateTrackSend(child, parent)
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_SRCCHAN", 1024)                         -- mono ch1
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_DSTCHAN", 1024 + (target_chan - 1))     -- mono dest
end

-- Close folder on the last child
if last_child then
  reaper.SetMediaTrackInfo_Value(last_child, "I_FOLDERDEPTH", -1)
end

-- Select parent + all created children
reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
reaper.SetTrackSelected(parent, true)
for _, child in ipairs(all_created_children) do
  reaper.SetTrackSelected(child, true)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Random channel routing (single parent)", -1)
