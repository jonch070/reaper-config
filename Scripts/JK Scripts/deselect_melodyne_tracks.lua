-- Deselect all tracks with Melodyne ARA plugin from current selection
-- Useful when you have all tracks selected and want to exclude Melodyne tracks

function main()
  reaper.Undo_BeginBlock()
  
  local deselected_count = 0
  
  -- Loop through all tracks
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    
    -- Check if track is currently selected
    if reaper.IsTrackSelected(track) then
      local fx_count = reaper.TrackFX_GetCount(track)
      
      -- Check each FX on the track
      for fx_idx = 0, fx_count - 1 do
        local retval, fx_name = reaper.TrackFX_GetFXName(track, fx_idx)
        
        -- Look for "Melodyne" in the plugin name
        if fx_name:lower():find("melodyne") then
          reaper.SetTrackSelected(track, false)
          deselected_count = deselected_count + 1
          break  -- Found Melodyne on this track, move to next track
        end
      end
    end
  end
  
  reaper.Undo_EndBlock("Deselect tracks with Melodyne", 0)
  
  -- Show result
  if deselected_count == 0 then
    reaper.ShowMessageBox("No Melodyne tracks were selected.", "Result", 0)
  else
    reaper.ShowMessageBox("Deselected " .. deselected_count .. " track(s) with Melodyne.", "Result", 0)
  end
end

main()
