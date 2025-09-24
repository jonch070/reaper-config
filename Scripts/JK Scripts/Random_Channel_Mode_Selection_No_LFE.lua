 -- Random Channel Assignment (excluding LFE/channel 4)
-- Automatically detects channel count from parent track
-- Assigns selected items to random mono output channels

-- Get count of selected items
local item_count = reaper.CountSelectedMediaItems(0)

if item_count == 0 then
  reaper.ShowMessageBox("No items selected!", "Error", 0)
  return
end

-- Get the parent track from the first selected item
local first_item = reaper.GetSelectedMediaItem(0, 0)
local parent_track = reaper.GetMediaItem_Track(first_item)

-- Get the number of channels on the parent track
local channel_count = reaper.GetMediaTrackInfo_Value(parent_track, "I_NCHAN")

-- Validate channel count
if channel_count < 2 then
  reaper.ShowMessageBox("Parent track must have at least 2 channels!", "Error", 0)
  return
end

-- Define available channels (excluding channel 4 which is LFE)
local available_channels = {}
for i = 1, channel_count do
  if i ~= 4 then  -- Skip channel 4 (LFE)
    table.insert(available_channels, i)
  end
end

-- Start undo block
reaper.Undo_BeginBlock()

-- Process each selected item
for i = 0, item_count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  
  -- Get a random channel from available channels
  local random_index = math.random(1, #available_channels)
  local channel = available_channels[random_index]
  
  -- Get the active take
  local take = reaper.GetActiveTake(item)
  
  if take then
    -- Set channel mode to mono (mode 3) and assign to the random channel
    -- Formula: 3 + (channel - 1) for mono output to specific channel
    reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 3 + (channel - 1))
  end
end

-- End undo block
reaper.Undo_EndBlock("Assign items to random channels (no LFE)", -1)

-- Update the arrangement
reaper.UpdateArrange()

-- Show completion message
reaper.ShowMessageBox("Assigned " .. item_count .. " items to random channels 1-" .. channel_count .. " (excluding ch 4/LFE)", "Complete", 0)
