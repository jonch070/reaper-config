-- @description Open each selected subproject item in its own project tab, then return to the parent
-- @about
--   Each .rpp is opened only once, even if several selected items reference it,
--   and subprojects that are already open in a tab are skipped.

local function norm(p) return (p:gsub("\\", "/")):lower() end

local parent = reaper.EnumProjects(-1, "")

-- Collect unique .rpp items from the selection
local targets, seen = {}, {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  local src = take and reaper.GetMediaItemTake_Source(take)
  local path = src and reaper.GetMediaSourceFileName(src, "") or ""
  if path:lower():match("%.rpp$") and not seen[norm(path)] then
    seen[norm(path)] = true
    targets[#targets + 1] = { item = item, path = path }
  end
end

if #targets == 0 then
  reaper.ShowMessageBox("Select one or more subproject items first.", "Open Selected Subprojects", 0)
  return
end

-- Already-open tabs
local open = {}
local i = 0
while true do
  local p, fn = reaper.EnumProjects(i, "")
  if not p then break end
  if fn and fn ~= "" then open[norm(fn)] = true end
  i = i + 1
end

-- Save the selection so it can be restored
local saved = {}
for k = 0, reaper.CountSelectedMediaItems(0) - 1 do saved[#saved + 1] = reaper.GetSelectedMediaItem(0, k) end

reaper.PreventUIRefresh(1)
for _, t in ipairs(targets) do
  if not open[norm(t.path)] then
    reaper.SelectProjectInstance(parent)
    reaper.Main_OnCommand(40289, 0)               -- unselect all items
    reaper.SetMediaItemSelected(t.item, true)
    reaper.Main_OnCommand(40109, 0)               -- open associated project in new tab
  end
end
reaper.SelectProjectInstance(parent)
reaper.Main_OnCommand(40289, 0)
for _, it in ipairs(saved) do reaper.SetMediaItemSelected(it, true) end
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
