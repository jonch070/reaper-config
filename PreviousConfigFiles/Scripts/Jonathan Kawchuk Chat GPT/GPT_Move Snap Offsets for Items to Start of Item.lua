-- get the number of selected items
num_sel_items = reaper.CountSelectedMediaItems(0)

-- loop through each selected item
for i = 0, num_sel_items-1 do
  -- get the i-th selected item
  item = reaper.GetSelectedMediaItem(0, i)

  -- get the start position of the item
  item_start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

  -- get the active take for the item
  take = reaper.GetActiveTake(item)

  -- set snap offset to start position of item
  reaper.SetMediaItemTakeInfo_Value(take, "D_SNAPOFFSET", -item_start_pos)
end

