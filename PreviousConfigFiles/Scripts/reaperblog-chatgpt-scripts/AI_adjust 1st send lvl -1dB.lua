-- Increase the volume of the selected track(s) by -1 dB

-- Get the selected tracks
local selected_tracks = reaper.CountSelectedTracks()

for i = 0, selected_tracks - 1 do
  -- Get the selected track
  local track = reaper.GetSelectedTrack(0, i)

  -- Get the volume of the first send
  local send_vol = reaper.GetTrackSendInfo_Value(track, 0, 0, "D_VOL")

  -- Increment the volume by 1 dB
  dbValue = -1
  send_vol = send_vol * 10^(0.05 * dbValue)

  -- Set the new volume of the first send
  reaper.SetTrackSendInfo_Value(track, 0, 0, "D_VOL", send_vol)
end

-- Update the tracks
reaper.TrackList_AdjustWindows(false)
