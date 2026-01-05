-- ReaScript name: Insert empty item on user-defined track with specified length, select it, and show item notes
-- Author: ChatGPT
-- Version: 1.4

-- User-defined variables
local itemLength = 0.2  -- Length of the empty item in seconds
local trackName = "Picture Markers"  -- Set the track name here

-- Function to get the track by its name
function GetTrackByName(name)
  local numTracks = reaper.CountTracks(0)
  for i = 0, numTracks - 1 do
    local track = reaper.GetTrack(0, i)
    local _, currentTrackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if currentTrackName == name then
      return track
    end
  end
  return nil
end

-- Start a new undo block
reaper.Undo_BeginBlock()

-- Find the track by the user-defined name
local track = GetTrackByName(trackName)
if track then
  -- Get the current edit cursor position
  local cursorPos = reaper.GetCursorPosition()

  -- Insert an empty media item on the found track at the cursor position
  local newItem = reaper.AddMediaItemToTrack(track)
  if newItem then
    -- Set the position and length of the new item
    reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", cursorPos)
    reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemLength)

    -- Deselect all items first
    reaper.Main_OnCommand(40289, 0)  -- Unselect all items

    -- Select the newly created item
    reaper.SetMediaItemSelected(newItem, true)

    -- Update the item selection
    reaper.UpdateItemInProject(newItem)

    -- Execute action to show notes for the selected item (Command ID: 40850)
    reaper.Main_OnCommand(40850, 0)
  end
else
  reaper.ShowMessageBox("Track not found!", "Error", 0)
end

-- End the undo block (for undo history)
reaper.Undo_EndBlock("Insert empty item on user-defined track, select it, and show item notes", -1)

-- Update the arrangement to reflect changes
reaper.UpdateArrange()
