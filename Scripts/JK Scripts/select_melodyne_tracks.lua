-- Select all tracks with Melodyne ARA plugin
-- Searches for "Melodyne" in the FX chain name (works with any Melodyne version)

function main()
  reaper.Undo_BeginBlock()
  
  -- Deselect all tracks first
  for i = 0, reaper.CountTracks(0) - 1 do
    reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
  end
  
  local found_count = 0
  
  -- Loop through all tracks
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local fx_count = reaper.TrackFX_GetCount(track)
    
    -- Check each FX on the track
    for fx_idx = 0, fx_count - 1 do
      local retval, fx_name = reaper.TrackFX_GetFXName(track, fx_idx)
      
      -- Look for "Melodyne" in the plugin name
      if fx_name:lower():find("melodyne") then
        reaper.SetTrackSelected(track, true)
        found_count = found_count + 1
        break  -- Found Melodyne on this track, move to next track
      end
    end
  end
  
  reaper.Undo_EndBlock("Select tracks with Melodyne", 0)
  
  -- Show result
  if found_count == 0 then
    reaper.ShowMessageBox("No tracks with Melodyne found.", "Result", 0)
  else
    reaper.ShowMessageBox("Selected " .. found_count .. " track(s) with Melodyne.", "Result", 0)
  end
end

main()
