-- Reset all selected track parameters to default values, delete all sends, reset record enable, monitor enable, phase invert, and set automation mode to trim/read

-- Get the number of selected tracks
local selected_track_count = reaper.CountSelectedTracks(0)

-- Loop through each selected track
for i = 0, selected_track_count - 1 do
  -- Get the current selected track
  local track = reaper.GetSelectedTrack(0, i)

  -- Reset all track parameters to default values
  reaper.SetMediaTrackInfo_Value(track, "D_VOL", 1)
  reaper.SetMediaTrackInfo_Value(track, "D_PAN", 0)
  reaper.SetMediaTrackInfo_Value(track, "D_WIDTH", 1)
  reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 0)
  reaper.SetMediaTrackInfo_Value(track, "B_SOLO", 0)
  reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", 0)
  reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 0)
  reaper.SetMediaTrackInfo_Value(track, "B_PHASE", 0)
  reaper.SetMediaTrackInfo_Value(track, "B_MONITOR", 1)
  reaper.SetMediaTrackInfo_Value(track, "I_RECMODE", 0)
  reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", 0)

  -- Delete all sends
  local send_count = reaper.GetTrackNumSends(track, 0)
  for j = send_count - 1, 0, -1 do
    reaper.RemoveTrackSend(track, 0, j)
  end
end

-- Update the arrange view
reaper.UpdateArrange()

