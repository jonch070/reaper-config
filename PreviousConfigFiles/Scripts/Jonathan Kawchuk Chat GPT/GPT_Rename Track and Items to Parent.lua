-- User-defined variables
local parentTrackOffset = 1 -- The number of tracks to skip when searching for the next parent track

-- Get the current track
local currentTrack = reaper.GetSelectedTrack(0, 0)

-- Check if there is a selected track
if currentTrack ~= nil then
  -- Get the name of the current track
  local currentTrackName = reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", "", false)

  -- Get the parent track of the current track
  local parentTrack = reaper.GetParentTrack(currentTrack)

  -- Check if there is a parent track
  if parentTrack ~= nil then
    -- Get the name of the parent track
    local _, parentTrackName = reaper.GetSetMediaTrackInfo_String(parentTrack, "P_NAME", "", false)

    -- Loop through all items on the current track
    local itemCount = reaper.CountTrackMediaItems(currentTrack)
    for i = 0, itemCount - 1 do
      local item = reaper.GetTrackMediaItem(currentTrack, i)
      local take = reaper.GetMediaItemTake(item, 0)

      -- Set the name of the take to the name of the parent track
      reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", parentTrackName, true)
    end

    -- Set the name of the current track to the name of the parent track
    reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", parentTrackName, true)

    -- Show a message box indicating the renaming was successful
    reaper.ShowMessageBox("Renamed track and items to: " .. parentTrackName, "Success", 0)
  else
    -- Show an error message if there is no parent track
    reaper.ShowMessageBox("No parent track found.", "Error", 0)
  end
else
  -- Show an error message if there is no selected track
  reaper.ShowMessageBox("No track selected.", "Error", 0)
end

