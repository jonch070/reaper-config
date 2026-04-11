-- Select leaf tracks from selected tracks
-- Leaf tracks = tracks that have no children (I_FOLDERDEPTH ~= 1)
-- Only considers currently selected tracks as candidates

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local selected_count = reaper.CountSelectedTracks(0)
local candidates = {}
for i = 0, selected_count - 1 do
  candidates[i] = reaper.GetSelectedTrack(0, i)
end

for i = 0, selected_count - 1 do
  local track = candidates[i]
  local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  reaper.SetTrackSelected(track, folder_depth ~= 1)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("Select leaf tracks from selected", -1)
