-- Opens the newest .rpp in each immediate subfolder of a parent folder, each in its own project tab.
-- Optionally opens them with all FX offline (REAPER's recovery mode).
-- Backup files (.rpp-bak) and "Backups" folders are ignored.

local function sh_quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local last_dir = reaper.GetExtState("JK_open_latest", "parent")
local last_off = reaper.GetExtState("JK_open_latest", "offline")
if last_off == "" then last_off = "y" end

local ok, vals = reaper.GetUserInputs("Open latest project in each subfolder", 2,
  "Parent folder:,FX offline (y/n):,extrawidth=420", last_dir .. "," .. last_off)
if not ok then return end
local parent, off = vals:match("^(.*),([^,]*)$")
if not parent or parent == "" then return end
parent = parent:match("^%s*(.-)%s*$")                 -- trim whitespace
parent = parent:gsub("^(['\"])(.*)%1$", "%2")         -- drop quotes pasted around the path
parent = parent:gsub("\\ ", " "):gsub("/+$", "")      -- unescape "\ " from a terminal paste, trim trailing /
local offline = not off:lower():match("^%s*n")
reaper.SetExtState("JK_open_latest", "parent", parent, true)
reaper.SetExtState("JK_open_latest", "offline", offline and "y" or "n", true)

-- newest project in each subfolder
local files = {}
local i = 0
while true do
  local sub = reaper.EnumerateSubdirectories(parent, i)
  if not sub then break end
  local cmd = ("find %s -type f -iname '*.rpp' -not -ipath '*/Backups/*' -exec stat -f '%%m\t%%N' {} + 2>/dev/null | sort -rn | head -n 1 | cut -f2-")
    :format(sh_quote(parent .. "/" .. sub))
  local p = io.popen(cmd)
  local latest = p and p:read("*l")
  if p then p:close() end
  if latest and latest ~= "" then files[#files + 1] = latest end
  i = i + 1
end

if #files == 0 then
  reaper.ShowMessageBox("No .rpp files found under:\n" .. parent, "Open latest projects", 0)
  return
end

local msg = ("Open %d project%s%s?"):format(#files, #files == 1 and "" or "s", offline and " with FX offline" or "")
if reaper.ShowMessageBox(msg, "Open latest projects", 1) ~= 1 then return end

for _, f in ipairs(files) do
  reaper.Main_OnCommand(40859, 0) -- File: New project tab
  reaper.Main_openProject((offline and "fxoffline:" or "") .. f)
end
