-- extract spacing value from script name
local script_name = ({reaper.get_action_context()})[2]:match("([^/\\]+)%.lua$")
local spacing = tonumber(script_name:match("(%d+)ms$")) / 1000

-- set default spacing if not found in script name
if spacing == nil then
  spacing = 0.25
end

-- get selected items
local num_selected_items = reaper.CountSelectedMediaItems(0)
if num_selected_items == 0 then return end

-- get first selected item
local first_item = reaper.GetSelectedMediaItem(0, 0)
local first_item_pos = reaper.GetMediaItemInfo_Value(first_item, "D_POSITION")
local first_item_len = reaper.GetMediaItemInfo_Value(first_item, "D_LENGTH")

-- create a table of selected items with their indices and original positions
local items = {}
for i = 1, num_selected_items do
  local item = reaper.GetSelectedMediaItem(0, i-1)
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  table.insert(items, {index = i, item = item, orig_pos = item_pos, orig_len = item_len})
end

-- sort the table by original position
table.sort(items, function(a, b) return a.orig_pos < b.orig_pos end)

-- calculate new position for each selected item relative to the first item
local new_positions = {}
local prev_pos = first_item_pos
for i, item in ipairs(items) do
  if i ~= 1 then
    prev_pos = prev_pos + items[i-1].orig_len + spacing
  end
  local new_pos = prev_pos
  new_positions[item.index] = new_pos
end

-- move all items to new positions, maintaining original order
reaper.PreventUIRefresh(1)
for i = 1, num_selected_items do
  local item = items[i].item
  local new_pos = new_positions[items[i].index]
  if new_pos ~= nil then
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
  end
end
reaper.PreventUIRefresh(-1)

-- refresh display
reaper.UpdateArrange()

