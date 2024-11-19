-- ReaScript Name: Assign Random Output Channel to All Selected Tracks (excluding 4) and Set 16 Output Channels
-- Author: ChatGPT
-- Version: 1.3

-- Get the number of selected tracks
local num_tracks = reaper.CountSelectedTracks(0)
if num_tracks == 0 then
  reaper.ShowMessageBox("No tracks selected", "Error", 0)
  return
end

-- Seed the random number generator
math.randomseed(os.time())

-- Loop through all selected tracks
for i = 0, num_tracks - 1 do
  local track = reaper.GetSelectedTrack(0, i)
  
  -- Set the track to use 16 output channels
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 16)
  
  -- Set the input channel to 1 (Mono input, first hardware input)
  reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", 0)  -- 0 = Mono input 1, 1 = Mono input 2, ...

  -- Generate a random output channel between 1 and 16, excluding 4
  local output_channel
  repeat
    output_channel = math.random(1, 16)
  until output_channel ~= 4
  
  -- Assign the random output channel to the track
  -- Route the first channel of the track to the chosen output channel
  reaper.SetTrackSendInfo_Value(track, 0, -1, "I_SRCCHAN", 0) -- Source channel 1
  reaper.SetTrackSendInfo_Value(track, 0, -1, "I_DSTCHAN", output_channel - 1)  -- Channel indices start at 0 in REAPER
end
