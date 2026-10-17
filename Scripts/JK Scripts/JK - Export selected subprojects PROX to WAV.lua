-- @description JK - Export selected subprojects PROX to WAV
-- @author Jonathan Kawchuk
-- @version 1.0
-- @about
--   Select subproject item(s) and run: copies each source's rendered
--   .rpp-PROX (which is a WAV) to <export folder>/<name>.wav. The export
--   folder template supports $project (parent project name, no extension),
--   and a relative template is resolved against the parent project's folder
--   (default) or, if "Relative to" is set to sub, each subproject's own folder.
--   Default: exports/$project   (i.e. <project folder>/exports/<project name>)
--   Existing files are overwritten. Render the PROX first if one is missing.

local function sh_quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function basename(p) return p:match("([^/\\]+)$") or p end

local projPath = reaper.GetProjectPath("")           -- recording path; use project file dir instead
local _, projFile = reaper.EnumProjects(-1, "")
local projDir = projFile and projFile ~= "" and projFile:match("^(.*)[/\\][^/\\]*$") or projPath
local projName = reaper.GetProjectName(0, "")
projName = projName ~= "" and projName:gsub("%.[Rr][Pp][Pp]$", "") or "untitled"

local last = reaper.GetExtState("JK_export_prox", "template")
if last == "" then last = "exports/$project" end
local lastBase = reaper.GetExtState("JK_export_prox", "base")
if lastBase == "" then lastBase = "parent" end
local ok, vals = reaper.GetUserInputs("Export subproject PROX to WAV", 2,
  "Export folder (use $project):,Relative to (parent / sub):,extrawidth=420", last .. "," .. lastBase)
if not ok then return end
local tpl, base = vals:match("^(.*),([^,]*)$")
if not tpl or tpl == "" then return end
tpl = tpl:match("^%s*(.-)%s*$"):gsub("^(['\"])(.*)%1$", "%2"):gsub("\\ ", " ")
local useSub = base:lower():match("^%s*s") ~= nil
reaper.SetExtState("JK_export_prox", "template", tpl, true)
reaper.SetExtState("JK_export_prox", "base", useSub and "sub" or "parent", true)

-- Export folder for a given subproject source path
local function dest_for(fp)
  local d = tpl:gsub("%$project", (projName:gsub("%%", "%%%%"))):gsub("/+$", "")
  if d:sub(1, 1) ~= "/" and d:sub(1, 1) ~= "~" then
    local root = useSub and (fp:match("^(.*)[/\\][^/\\]*$") or ".") or projDir
    d = root .. "/" .. d
  end
  return d
end
local dest

local seen, done, problems = {}, {}, {}
local firstOut
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local take = reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, i))
  local src = take and reaper.GetMediaItemTake_Source(take)
  local fp = src and reaper.GetMediaSourceFileName(src, "")
  if fp and fp:sub(-4):lower() == ".rpp" and not seen[fp] then
    seen[fp] = true
    local prox = fp .. "-PROX"
    local f = io.open(prox, "rb")
    local magic = f and f:read(12)
    if f then f:close() end
    local name = basename(fp):gsub("%.[Rr][Pp][Pp]$", "")
    if not magic then
      problems[#problems + 1] = name .. " (no .rpp-PROX - render it first)"
    elseif magic:sub(1, 4) ~= "RIFF" or magic:sub(9, 12) ~= "WAVE" then
      problems[#problems + 1] = name .. " (PROX is not a WAV)"
    else
      dest = dest_for(fp)
      os.execute(("mkdir -p %s"):format(sh_quote(dest)))
      local out = dest .. "/" .. name .. ".wav"
      local rc = os.execute(("cp -f %s %s"):format(sh_quote(prox), sh_quote(out)))
      if rc == true or rc == 0 then
        done[#done + 1] = name .. ".wav"
        firstOut = firstOut or out
      else problems[#problems + 1] = name .. " (copy failed)" end
    end
  end
end

if #done + #problems == 0 then
  reaper.ShowMessageBox("No subproject (.rpp) items selected.", "JK Export PROX", 0)
  return
end
local msg = ("Exported %d WAV%s%s"):format(#done, #done == 1 and "" or "s",
  #done == 0 and "." or (useSub and " into an export folder beside each subproject." or " to:\n" .. tostring(dest)))
if #problems > 0 then msg = msg .. "\n\nSkipped:\n  " .. table.concat(problems, "\n  ") end
if firstOut then
  msg = msg .. "\n\nShow in Finder?"
  if reaper.ShowMessageBox(msg, "JK Export PROX", 4) == 6 then
    os.execute(("open -R %s"):format(sh_quote(firstOut)))
  end
else
  reaper.ShowMessageBox(msg, "JK Export PROX", 0)
end
