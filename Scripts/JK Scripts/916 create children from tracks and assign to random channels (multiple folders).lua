-- Random Channel Routing from Tracks (Multiple Folders)
-- Takes all selected tracks and:
--   * uses the first selected track as parent folder
--   * ensures parent has at least 16 channels
--   * makes remaining selected tracks children of the parent
--   * routes each child: SRC mono ch1 -> random mono parent channel (1..16, skip 4)
-- Finally selects parent and all children.

local MIN_PARENT_CHANS = 16

-- Utility: make list 1..16 excluding 4
local function build_available_channels()
  local t = {}
  for i = 1, 16 do
    if i ~= 4 then table.insert(t, i) end
  end
  return t
end

-- Collect all selected tracks
local function collect_selected_tracks()
  local tracks = {}
  local sel_trk_count = reaper.CountSelectedTracks(0)

  if sel_trk_count > 0 then
    for i = 0, sel_trk_count - 1 do
      table.insert(tracks, reaper.GetSelectedTrack(0, i))
    end
  end

  return tracks
end

-- Seed RNG so runs differ
math.randomseed(math.floor(reaper.time_precise() * 1e6) % 2^31)

local tracks = collect_selected_tracks()
if #tracks < 2 then
  reaper.ShowMessageBox("Select at least 2 tracks (first = parent, rest = children)", "Error", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- First selected track becomes parent
local parent = tracks[1]

-- Ensure parent has at least MIN_PARENT_CHANS
local parent_chans = reaper.GetMediaTrackInfo_Value(parent, "I_NCHAN")
if parent_chans < MIN_PARENT_CHANS then
  reaper.SetMediaTrackInfo_Value(parent, "I_NCHAN", MIN_PARENT_CHANS)
end

-- Get parent index before making changes
local parent_idx = reaper.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER") - 1

-- Collect children (all selected except first)
local children = {}
for i = 2, #tracks do
  table.insert(children, tracks[i])
end

-- Move children to be directly after parent, in order
for i, child in ipairs(children) do
  local target_idx = parent_idx + i
  reaper.SetOnlyTrackSelected(child)
  reaper.ReorderSelectedTracks(target_idx, 0)
end

-- Set parent as folder start
reaper.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)

-- Close folder properly using Lokasenna's method
-- Find the last child track
local last_child = children[#children]
local lastSelIdx = reaper.GetMediaTrackInfo_Value(last_child, "IP_TRACKNUMBER") - 1
local curDepth = 0
for trackIdx = lastSelIdx, reaper.CountTracks(0) - 1 do
  local track = reaper.GetTrack(0, trackIdx)
  local trackDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  curDepth = curDepth + trackDepth
  if curDepth <= 0 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", trackDepth - 1)
    break
  end
end

-- Apply random routing to each child
local available_channels = build_available_channels()

for _, child in ipairs(children) do
  -- Disable master/parent send
  reaper.SetMediaTrackInfo_Value(child, "B_MAINSEND", 0)

  -- Create send to parent with random channel routing
  local send_idx = reaper.CreateTrackSend(child, parent)

  -- Routing: child ch1 (mono) -> random mono parent channel (skip 4)
  local target_chan = available_channels[math.random(#available_channels)]
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_SRCCHAN", 1024)                         -- mono ch1
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_DSTCHAN", 1024 + (target_chan - 1))     -- mono dest
end

-- Select parent + all children
reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
reaper.SetTrackSelected(parent, true)
for _, child in ipairs(children) do
  reaper.SetTrackSelected(child, true)
end

reaper.TrackList_AdjustWindows(false)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Random channel routing from tracks (multiple folders, 16ch)", -1)
