-- Get the current project
local proj = 0 -- Set the current project to the active project

-- Check if ripple editing is enabled
local ripple_editing = reaper.GetToggleCommandState(1157)

if ripple_editing == 1 then
  -- Disable ripple editing
  reaper.Main_OnCommand(1157, 0)
end

-- Get the selected track
local sel_track = reaper.GetSelectedTrack(0, 0)

if sel_track then
  -- Copy the selected track
  reaper.Main_OnCommand(40210, 0) -- Copy tracks

  -- Paste the copied track below the original track
  reaper.SetOnlyTrackSelected(sel_track)
  reaper.Main_OnCommand(42398, 0) -- Paste items/tracks/envelope points

  -- Get the new track and delete all items on it
  local new_track = reaper.GetTrack(proj, reaper.CountTracks(proj)-1) -- Get the last track in the project
  reaper.Main_OnCommand(40421, 0) -- Select all items on current track
  reaper.Main_OnCommand(40006, 0) -- Remove items/tracks/envelope points

  -- If the original track was record armed, disable record arm
  local rec_arm = reaper.GetMediaTrackInfo_Value(sel_track, "I_RECARM")
  if rec_arm == 1 then
    reaper.SetMediaTrackInfo_Value(sel_track, "I_RECARM", 0)
  end
end

-- If ripple editing was enabled before, turn it back on
if ripple_editing == 1 then
  reaper.Main_OnCommand(1157, 0)
end

