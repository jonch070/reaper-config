-- Select all non-leaf tracks (folder/parent tracks) in the whole project
-- Non-leaf tracks = tracks that have children (I_FOLDERDEPTH == 1)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local track_count = reaper.CountTracks(0)
for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  local visible = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 1
  local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  reaper.SetTrackSelected(track, visible and folder_depth == 1)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("Select all non-leaf tracks (whole project)", -1)
