-- get the number of selected items
num_sel_items = reaper.CountSelectedMediaItems(0)

-- loop through each selected item
for i = 0, num_sel_items-1 do
  -- get the i-th selected item
  item = reaper.GetSelectedMediaItem(0, i)

  -- get the take for the item
  take = reaper.GetActiveTake(item)

  -- remove snap offset from take
  reaper.SetMediaItemTakeInfo_Value(take, "D_SNAPOFFSET", 0)
end

