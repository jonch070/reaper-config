-- @description JK - Render latest subproject versions (PROX)
-- @author Jonathan Kawchuk
-- @version 1.0
-- @about
--   Like rcraggs/reaper-auto-render (-l), but for .rpp-PROX files, run from
--   inside REAPER. Renders (save + render RPP-PROX) the NEWEST .rpp:
--     * for each selected subproject item: in that item's source folder, or
--     * with nothing selected: in each immediate subfolder of a parent folder
--       you enter.
--   Each project opens in its own tab, is rendered, then the tab is closed.
--   Newest = most recent modified time; .rpp-bak and Backups folders ignored.

local function sh_quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function dirname(p) return p:match("^(.*)[/\\][^/\\]*$") or "." end
local function basename(p) return p:match("([^/\\]+)$") or p end

local function newest_in(dir)
  local cmd = ("find %s -maxdepth 1 -type f -iname '*.rpp' -exec stat -f '%%m\t%%N' {} + 2>/dev/null | sort -rn | head -n 1 | cut -f2-")
    :format(sh_quote(dir))
  local p = io.popen(cmd)
  local line = p and p:read("*l")
  if p then p:close() end
  return (line and line ~= "") and line or nil
end

-- Collect target projects
local targets, seen = {}, {}
local function add(f)
  if f and not seen[f] then seen[f] = true; targets[#targets + 1] = f end
end

for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local take = reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, i))
  local src = take and reaper.GetMediaItemTake_Source(take)
  local fp = src and reaper.GetMediaSourceFileName(src, "")
  if fp and fp:sub(-4):lower() == ".rpp" then add(newest_in(dirname(fp))) end
end

if #targets == 0 then
  local last = reaper.GetExtState("JK_render_latest", "parent")
  local ok, parent = reaper.GetUserInputs("Render latest in each subfolder", 1,
    "Parent folder:,extrawidth=420", last)
  if not ok or parent == "" then return end
  parent = parent:match("^%s*(.-)%s*$")
  parent = parent:gsub("^(['\"])(.*)%1$", "%2"):gsub("\\ ", " "):gsub("/+$", "")
  reaper.SetExtState("JK_render_latest", "parent", parent, true)
  local i = 0
  while true do
    local sub = reaper.EnumerateSubdirectories(parent, i)
    if not sub then break end
    add(newest_in(parent .. "/" .. sub))
    i = i + 1
  end
end

if #targets == 0 then
  reaper.ShowMessageBox("No .rpp files found.", "JK Render latest PROX", 0)
  return
end

local names = {}
for _, f in ipairs(targets) do names[#names + 1] = "  " .. basename(f) end
if reaper.ShowMessageBox(("Render PROX for %d project%s?\n\n%s"):format(#targets, #targets == 1 and "" or "s",
    table.concat(names, "\n")), "JK Render latest PROX", 1) ~= 1 then return end

local selItems = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  selItems[#selItems + 1] = reaper.GetSelectedMediaItem(0, i)
end
local parentProj = reaper.EnumProjects(-1, "")

local failed = {}
for _, f in ipairs(targets) do
  reaper.Main_OnCommand(40859, 0)           -- new project tab
  reaper.Main_openProject(f)
  reaper.Main_OnCommand(42332, 0)           -- save project and render RPP-PROX
  if reaper.IsProjectDirty(0) > 0 then reaper.Main_OnCommand(40026, 0) end
  reaper.Main_OnCommand(40860, 0)           -- close tab
  local pf = io.open(f .. "-PROX", "rb")
  if pf then pf:close() else failed[#failed + 1] = basename(f) end
  if parentProj and reaper.ValidatePtr(parentProj, "ReaProject*") then
    reaper.SelectProjectInstance(parentProj)
  end
end

for _, item in ipairs(selItems) do reaper.SetMediaItemSelected(item, true) end
reaper.UpdateArrange()

local msg = ("Rendered %d project%s."):format(#targets - #failed, #targets - #failed == 1 and "" or "s")
if #failed > 0 then msg = msg .. "\n\nNo .rpp-PROX found after rendering:\n  " .. table.concat(failed, "\n  ") end
reaper.ShowMessageBox(msg, "JK Render latest PROX", 0)
