-- Function to export a MIDI file of the entire track
local function exportMIDI()
  reaper.Main_OnCommand(40440, 0) -- File: Save project as MIDI...
end

-- Function to export a stereo mix in WAV format
local function exportStereoMixWAV()
  reaper.Main_OnCommand(41823, 0) -- File: Render project, using the most recent render settings
end

-- Function to export a stereo mix in MP3 format
local function exportStereoMixMP3()
  reaper.Main_OnCommand(41824, 0) -- File: Render project to disk, using the most recent render settings (MP3)
end

-- Function to export a stereo mix with the track called "dialogue" mixed together in WAV format
local function exportStereoMixWithDialogueWAV()
  local trackName = "dialogue" -- Name of the track to be mixed with the stereo mix

  -- Find the track index based on the track name
  local trackIndex = reaper.GetTrackIndexByName(trackName)

  if trackIndex > 0 then
    -- Mute all tracks except the "dialogue" track
    for i = 0, reaper.CountTracks(0) - 1 do
      local track = reaper.GetTrack(0, i)
      reaper.SetMediaTrackInfo_Value(track, "B_MUTE", i ~= trackIndex - 1)
    end

    -- Export the stereo mix with the "dialogue" track mixed in
    reaper.Main_OnCommand(41823, 0) -- File: Render project, using the most recent render settings

    -- Unmute all tracks
    for i = 0, reaper.CountTracks(0) - 1 do
      local track = reaper.GetTrack(0, i)
      reaper.SetMediaTrackInfo_Value(track, "B_MUTE", false)
    end
  else
    reaper.ShowMessageBox("Track '" .. trackName .. "' not found.", "Error", 0)
  end
end

-- Export MIDI file
exportMIDI()

-- Export stereo mix in WAV format
exportStereoMixWAV()

-- Export stereo mix in MP3 format
exportStereoMixMP3()

-- Export stereo mix with "dialogue" mixed in
exportStereoMixWithDialogueWAV()

