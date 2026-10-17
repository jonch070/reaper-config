-- @description Subproject: real Save As (tab is renamed), then point parent project items at the new file
-- @about
--   Run INSIDE a subproject. Opens REAPER's normal Save As dialog; type the new name
--   (e.g. change v01.01.01 to v01.02.01). After the save, any other open project tab with
--   items using the old .rpp gets the new version as a new active take.
--   Does NOT render the .RPP-PROX; do that manually.
--   If this file's name contains "increment", the next last-number version (v01.01.01 ->
--   v01.01.02) is copied to the clipboard so you can just paste it into the dialog (Cmd+V).

local TITLE = "Save New Subproject Version"
local function msg(s) reaper.ShowMessageBox(s, TITLE, 0) end

local script_path = ({reaper.get_action_context()})[2] or ""
local INCREMENT = script_path:lower():find("increment", 1, true) ~= nil

local function norm(p) return (p:gsub("\\", "/")) end

local proj, oldPath = reaper.EnumProjects(-1, "")
if not oldPath or oldPath == "" then msg("Save this project once first (it has no file path)."); return end
oldPath = norm(oldPath)
local oldLower = oldPath:lower()

if INCREMENT and reaper.CF_SetClipboard then
  local pre, xs, ys, zs = oldPath:match("([^/]-)v(%d+)%.(%d+)%.(%d+)%.[^./]+$")
  if pre then
    reaper.CF_SetClipboard(string.format("%sv%s.%s.%0" .. #zs .. "d", pre, xs, ys, tonumber(zs) + 1))
  end
end

-- Find parent items BEFORE saving (this tab's path changes on save)
local hits = {}
local i = 0
while true do
  local p = reaper.EnumProjects(i, "")
  if not p then break end
  if p ~= proj then
    for it = 0, reaper.CountMediaItems(p) - 1 do
      local item = reaper.GetMediaItem(p, it)
      for t = 0, reaper.CountTakes(item) - 1 do
        local take = reaper.GetTake(item, t)
        local src = take and reaper.GetMediaItemTake_Source(take)
        if src and norm(reaper.GetMediaSourceFileName(src, "")):lower() == oldLower then
          hits[#hits + 1] = { proj = p, item = item, take = take }
          break
        end
      end
    end
  end
  i = i + 1
end

-- Real Save As: shows the dialog and renames this tab. Old file stays on disk untouched.
reaper.Main_SaveProject(proj, true)

local _, newPath = reaper.EnumProjects(-1, "")
newPath = newPath and norm(newPath) or ""
if newPath == "" or newPath:lower() == oldLower then return end -- cancelled
local newBase = newPath:match("([^/]+)%.[^./]+$")

reaper.Undo_BeginBlock()
local touched = {}
for _, h in ipairs(hits) do
  local newTake = reaper.AddTakeToMediaItem(h.item)
  local newSrc = reaper.PCM_Source_CreateFromFile(newPath)
  if newTake and newSrc then
    reaper.SetMediaItemTake_Source(newTake, newSrc)
    reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", reaper.GetMediaItemTakeInfo_Value(h.take, "D_STARTOFFS"))
    reaper.SetMediaItemTakeInfo_Value(newTake, "D_PLAYRATE", reaper.GetMediaItemTakeInfo_Value(h.take, "D_PLAYRATE"))
    reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", newBase, true)
    reaper.SetMediaItemInfo_Value(h.item, "I_CURTAKE", reaper.CountTakes(h.item) - 1)
    reaper.UpdateItemInProject(h.item)
    touched[h.proj] = true
  end
end
for p in pairs(touched) do reaper.MarkProjectDirty(p) end
reaper.UpdateArrange()
reaper.Undo_EndBlock("Save new subproject version", -1)

if #hits == 0 then
  reaper.ShowConsoleMsg("Saved " .. newBase .. " but found no open parent project using the old version.\n")
end
