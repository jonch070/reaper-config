-- Get the selected items
local num_selected_items = reaper.CountSelectedMediaItems()
if num_selected_items == 0 then return end

-- Get the position and length of the first item
local first_item = reaper.GetSelectedMediaItem(0, 0)
local first_item_pos = reaper.GetMediaItemInfo_Value(first_item, "D_POSITION")
local first_item_len = reaper.GetMediaItemInfo_Value(first_item, "D_LENGTH")

-- Calculate the end position of the first item
local first_item_end_pos = first_item_pos + first_item_len

-- Loop through the selected items and adjust their positions
local prev_item_end_pos = first_item_end_pos
for i = 1, num_selected_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    -- Calculate the new position of the item
    local new_item_pos = prev_item_end_pos

    -- Adjust the position of the item to remove any gap
    if new_item_pos > item_pos then
        new_item_pos = item_pos
    end

    -- Calculate the new length of the item to preserve the original length
    local new_item_len = item_len - (new_item_pos - item_pos)

    -- Ensure that the new length is not negative
    if new_item_len < 0 then
        new_item_len = 0
    end

    -- Set the new position of the item
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_pos)

    -- Update the end position of the previous item
    prev_item_end_pos = new_item_pos + item_len
end

-- Update the arrange view
reaper.UpdateArrange()

