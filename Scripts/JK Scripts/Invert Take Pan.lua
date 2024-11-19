num_items = reaper.CountSelectedMediaItems(0)
for i = 0, num_items - 1 do
  item = reaper.GetSelectedMediaItem(0, i)
  take = reaper.GetActiveTake(item)
  pan = reaper.GetMediaItemTakeInfo_Value(take,"D_PAN")
  reaper.SetMediaItemTakeInfo_Value(take, "D_PAN", -pan)
end
reaper.UpdateArrange()
