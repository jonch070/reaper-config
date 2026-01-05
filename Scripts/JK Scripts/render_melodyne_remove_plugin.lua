-- Render Melodyne (and everything before it) to new take
-- Then remove Melodyne plugin, keeping all FX after it intact
-- Works on multiple selected tracks

function main()
  reaper.Undo_BeginBlock()
  
  local selected_tracks_count = reaper.CountSelectedTracks(0)
  
  if selected_tracks_count == 0 then
    reaper.ShowMessageBox("No tracks selected.", "Error", 0)
    return
  end
  
  local success_count = 0
  local skipped_count = 0
  local items_rendered = 0
  
  -- Collect all tracks with Melodyne first
  local tracks_to_process = {}
  for i = 0, selected_tracks_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local fx_count = reaper.TrackFX_GetCount(track)
    
    -- Find Melodyne in the FX chain
    local melodyne_idx = -1
    for fx_idx = 0, fx_count - 1 do
      local retval, fx_name = reaper.TrackFX_GetFXName(track, fx_idx)
      if fx_name:lower():find("melodyne") then
        melodyne_idx = fx_idx
        break
      end
    end
    
    if melodyne_idx >= 0 then
      table.insert(tracks_to_process, {track = track, melodyne_idx = melodyne_idx, fx_count = fx_count})
    else
      skipped_count = skipped_count + 1
    end
  end
  
  -- Process tracks with Melodyne
  for _, track_info in ipairs(tracks_to_process) do
    local track = track_info.track
    local melodyne_idx = track_info.melodyne_idx
    local fx_count = track_info.fx_count
    
    -- Get all items on track
    local item_count = reaper.CountTrackMediaItems(track)
    
    if item_count > 0 then
      -- For each item, render to new take with FX up to and including Melodyne
      for item_idx = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, item_idx)
        local take = reaper.GetActiveTake(item)
        
        if take then
          -- Store state of FX after Melodyne
          local fx_after_melodyne = {}
          for fx_idx = melodyne_idx + 1, fx_count - 1 do
            local is_enabled = reaper.TrackFX_GetEnabled(track, fx_idx)
            table.insert(fx_after_melodyne, {idx = fx_idx, was_enabled = is_enabled})
            -- Disable FX after Melodyne so they don't get rendered
            reaper.TrackFX_SetEnabled(track, fx_idx, false)
          end
          
          -- Select only this item for rendering
          reaper.SetMediaItemSelected(item, true)
          
          -- Render to new take (includes Melodyne + everything before it)
          local cmd_id = reaper.NamedCommandLookup("40209")
          if cmd_id > 0 then
            reaper.Main_OnCommand(cmd_id, 0)
          end
          
          -- Deselect item
          reaper.SetMediaItemSelected(item, false)
          
          -- Re-enable FX after Melodyne
          for _, fx_info in ipairs(fx_after_melodyne) do
            reaper.TrackFX_SetEnabled(track, fx_info.idx, fx_info.was_enabled)
          end
          
          items_rendered = items_rendered + 1
        end
      end
      
      -- After all items rendered, delete Melodyne plugin
      reaper.TrackFX_Delete(track, melodyne_idx)
      success_count = success_count + 1
    else
      skipped_count = skipped_count + 1
    end
  end
  
  reaper.Undo_EndBlock("Render Melodyne and remove plugin", -1)
  
  local msg = "Tracks processed: " .. success_count .. "\nItems rendered: " .. items_rendered .. "\nTracks skipped: " .. skipped_count .. "\n\nMelodyne audio is now baked into new takes.\nMelodyne plugin removed. FX after it are preserved."
  reaper.ShowMessageBox(msg, "Result", 0)
end

main()
