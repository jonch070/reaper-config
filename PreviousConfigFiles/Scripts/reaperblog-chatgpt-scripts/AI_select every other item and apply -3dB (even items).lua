-- Get selected items
selected_items = {}
num_items = reaper.CountMediaItems(0)

for i = 0, num_items - 1 do
  item = reaper.GetMediaItem(0, i)
  if reaper.IsMediaItemSelected(item) then
    table.insert(selected_items, item)
  end
end

-- Loop through selected items
for i, item in ipairs(selected_items) do
  -- Check if item is even-numbered
  if i % 2 == 0 then
    -- Get current volume of item
    item_vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    
    -- Calculate new volume (3 dB decrease)
    new_vol = item_vol / math.sqrt(2)
    
    -- Set new volume of item
    reaper.SetMediaItemInfo_Value(item, "D_VOL", new_vol)
    
    -- Add item to selection
    reaper.SetMediaItemSelected(item, true)
  else
    -- Deselect odd-numbered items
    reaper.SetMediaItemSelected(item, false)
  end
end
 
