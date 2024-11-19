-- ReaScript Name: Set Track Channels to 16 and Recording Input to Mono Channel 1 for All Selected Tracks
-- Author: ChatGPT
-- Version: 1.2

-- Get the number of selected tracks
local num_tracks = reaper.CountSelectedTracks(0)
if num_tracks == 0 then
  reaper.ShowMessageBox("No tracks selected", "Error", 0)
  return
end

-- Loop through all selected tracks
for i = 0, num_tracks - 1 do
  local track = reaper.GetSelectedTrack(0, i)
  
  -- Set the track to use 16 output channels
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 16)
  
  -- Set the recording input to Mono input 1
  reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", 0)  -- 0 = Mono input 1
end
