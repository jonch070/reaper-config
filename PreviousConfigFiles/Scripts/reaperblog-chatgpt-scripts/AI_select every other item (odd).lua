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
  -- Check if item is odd-numbered
  if i % 2 == 1 then
    -- Add item to selection
    reaper.SetMediaItemSelected(item, true)
  else
    -- Deselect even-numbered items
    reaper.SetMediaItemSelected(item, false)
  end
end

