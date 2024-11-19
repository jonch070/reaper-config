-- Get the fade amount from the script file name
fade_amount = tonumber(string.match(({reaper.get_action_context()})[2], "%d+"))

-- Get the number of selected items
num_items = reaper.CountSelectedMediaItems(0)

-- Iterate through each selected item
for i = 0, num_items - 1 do
-- Get the selected item
item = reaper.GetSelectedMediaItem(0, i)
-- Apply a fade-in to the item using the extracted number
reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_amount / 1000)

-- Apply a fade-out to the item using the extracted number
reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_amount / 1000)
end
