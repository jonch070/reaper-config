-- Random Channel Routing (Multi-Parent)
-- For each selected track:
--   * make it a folder (keeps parent master send ON)
--   * ensure parent has at least 16 channels
--   * move that track's items to new child tracks
--   * route each child: SRC mono ch1 -> random mono parent channel (1..16, skip 4)
-- Finally selects all parents and all created children.

local MIN_PARENT_CHANS = 16

-- Build list of items per parent track:
-- If any items are selected, use only those (grouped by their source track).
-- Otherwise, use all items on selected tracks.
local function collect_items_by_track()
  local map = {}      -- track_ptr -> { items = {}, ordered = true }
  local parents = {}  -- ordered list of unique tracks

  local function ensure_entry(tr)
    if not map[tr] then
      map[tr] = { items = {} }
      table.insert(parents, tr)
    end
    return map[tr]
  end

  local sel_item_count = reaper.CountSelectedMediaItems(0)
  if sel_item_count > 0 then
    for i = 0, sel_item_count - 1 do
      local it  = reaper.GetSelectedMediaItem(0, i)
      local tr  = reaper.GetMediaItem_Track(it)
      ensure_entry(tr)
      table.insert(map[tr].items, it)
    end
  else
    local sel_trk_count = reaper.CountSelectedTracks(0)
    if sel_trk_count == 0 then return {}, {} end
    for i = 0, sel_trk_count - 1 do
      local tr = reaper.GetSelectedTrack(0, i)
      ensure_entry(tr)
      local ti = reaper.CountTrackMediaItems(tr)
      for j = 0, ti - 1 do
        local it = reaper.GetTrackMediaItem(tr, j)
        table.insert(map[tr].items, it)
      end
    end
  end

  -- Sort parents by current track index (top-to-bottom)
  table.sort(parents, function(a, b)
    local ia = reaper.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER")
    local ib = reaper.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
    return ia < ib
  end)

  return parents, map
end

-- Utility: make list 1..16 excluding 4
local function build_available_channels()
  local t = {}
  for i = 1, 16 do
    if i ~= 4 then table.insert(t, i) end
  end
  return t
end

-- Seed RNG so runs differ
math.randomseed(math.floor(reaper.time_precise() * 1e6) % 2^31)

local parents, track_items = collect_items_by_track()
if #parents == 0 then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local all_created_children = {}

for _, parent in ipairs(parents) do
  local items = track_items[parent] and track_items[parent].items or {}
  if #items > 0 then
    -- Ensure parent has at least MIN_PARENT_CHANS
    local parent_chans = reaper.GetMediaTrackInfo_Value(parent, "I_NCHAN")
    if parent_chans < MIN_PARENT_CHANS then
      reaper.SetMediaTrackInfo_Value(parent, "I_NCHAN", MIN_PARENT_CHANS)
    end

    -- Start folder on parent (keep parent's master send as-is)
    reaper.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)

    local available_channels = build_available_channels()
    local last_child = nil

    -- Insert a child for each item on THIS parent, right below parent
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

    -- Close folder on the last child we created for this parent
    if last_child then
      reaper.SetMediaTrackInfo_Value(last_child, "I_FOLDERDEPTH", -1)
    else
      -- If no children were created (no items), revert folder flag on parent
      reaper.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 0)
    end
  end
end

-- Select all parents + all created children
reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
for _, parent in ipairs(parents) do
  reaper.SetTrackSelected(parent, true)
end
for _, child in ipairs(all_created_children) do
  reaper.SetTrackSelected(child, true)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Random channel routing (multi-parent)", -1)