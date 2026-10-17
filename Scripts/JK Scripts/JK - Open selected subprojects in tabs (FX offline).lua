-- @description Open each selected subproject item in its own project tab with all FX offline, then return to the parent
-- @about
--   Same as "Open selected subprojects in tabs", but opens with REAPER's "fxoffline:" mode.
--   Each .rpp is opened only once, even if several selected items reference it,
--   and subprojects that are already open in a tab are skipped.

local function norm(p) return (p:gsub("\\", "/")):lower() end

local parent = reaper.EnumProjects(-1, "")

-- Collect unique .rpp paths from the selection
local targets, seen = {}, {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  local src = take and reaper.GetMediaItemTake_Source(take)
  local path = src and reaper.GetMediaSourceFileName(src, "") or ""
  if path:lower():match("%.rpp$") and not seen[norm(path)] then
    seen[norm(path)] = true
    targets[#targets + 1] = path
  end
end

if #targets == 0 then
  reaper.ShowMessageBox("Select one or more subproject items first.", "Open Selected Subprojects (FX offline)", 0)
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

reaper.PreventUIRefresh(1)
for _, path in ipairs(targets) do
  if not open[norm(path)] then
    reaper.Main_OnCommand(40859, 0) -- File: New project tab
    reaper.Main_openProject("fxoffline:" .. path)
  end
end
reaper.SelectProjectInstance(parent)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
