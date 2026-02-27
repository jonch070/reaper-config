-- Select all leaf tracks that have items overlapping the time selection
-- Leaf tracks = tracks that have no children (I_FOLDERDEPTH ~= 1)

local function track_has_item_in_time_sel(track, sel_start, sel_end)
  local item_count = reaper.CountTrackMediaItems(track)
  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if item_start < sel_end and item_end > sel_start then
      return true
    end
  end
  return false
end

local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

if sel_start == sel_end then
  reaper.ShowMessageBox("No time selection found.", "Select Leaf Tracks", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local track_count = reaper.CountTracks(0)
for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  local visible = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 1
  local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  local is_leaf = folder_depth ~= 1
  local in_time_sel = visible and is_leaf and track_has_item_in_time_sel(track, sel_start, sel_end)
  reaper.SetTrackSelected(track, in_time_sel)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("Select leaf tracks in time selection", -1)
