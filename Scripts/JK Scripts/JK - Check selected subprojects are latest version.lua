-- @description JK - Check selected subprojects are latest version
-- @author Jonathan Kawchuk
-- @version 1.1
-- @about
--   Select subproject item(s) and run: for the active take of each item, looks
--   in the source .rpp's folder for a newer .rpp (by modified time; .rpp-bak
--   and Backups folders ignored). Reports up to date vs outdated and leaves
--   only the outdated items selected. Then offers to update them:
--     * if the newest version is already one of the item's takes, that take
--       is made the active take;
--     * otherwise the active take is repointed at the newest .rpp (position
--       and length kept).
--   Items whose newest version has no .rpp-PROX yet are reported: render them
--   with "JK - Render latest subproject versions (PROX)".

local function sh_quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function basename(p) return p:match("([^/\\]+)$") or p end
local function dirname(p) return p:match("^(.*)[/\\][^/\\]*$") or "." end
local function stem(p) return (basename(p):gsub("%.[Rr][Pp][Pp]$", "")) end

-- Newest .rpp directly inside dir -> path, mtime
local function newest_in(dir)
  local cmd = ("find %s -maxdepth 1 -type f -iname '*.rpp' -exec stat -f '%%m\t%%N' {} + 2>/dev/null | sort -rn | head -n 1")
    :format(sh_quote(dir))
  local p = io.popen(cmd)
  local line = p and p:read("*l")
  if p then p:close() end
  if not line or line == "" then return nil end
  local mt, path = line:match("^(%d+)\t(.+)$")
  return path, tonumber(mt)
end

local function mtime_of(path)
  local p = io.popen(("stat -f '%%m' %s 2>/dev/null"):format(sh_quote(path)))
  local s = p and p:read("*l")
  if p then p:close() end
  return tonumber(s)
end

local function take_path(take)
  local src = take and reaper.GetMediaItemTake_Source(take)
  local fp = src and reaper.GetMediaSourceFileName(src, "")
  if fp and #fp > 4 and fp:sub(-4):lower() == ".rpp" then return fp end
end

local function main()
  local sels = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    sels[#sels + 1] = reaper.GetSelectedMediaItem(0, i)
  end

  local cache = {}   -- per unique active-take source path
  local info = {}    -- per item
  local order = {}   -- unique source paths, in order
  for _, item in ipairs(sels) do
    local fp = take_path(reaper.GetActiveTake(item))
    if fp then
      if not cache[fp] then
        local newest, nmt = newest_in(dirname(fp))
        local mt = mtime_of(fp)
        cache[fp] = {
          newest = newest,
          outdated = (newest and newest ~= fp and mt and nmt and nmt > mt) and true or false,
        }
        order[#order + 1] = fp
      end
      local c = cache[fp]
      local rec = { fp = fp, outdated = c.outdated, newest = c.newest }
      if c.outdated then
        -- is the newest version already one of this item's takes?
        for t = 0, reaper.CountTakes(item) - 1 do
          local tk = reaper.GetTake(item, t)
          if take_path(tk) == c.newest then rec.takeIdx, rec.take = t, tk; break end
        end
      end
      info[item] = rec
    end
  end

  if #order == 0 then
    reaper.ShowMessageBox("No subproject (.rpp) items selected.", "JK Check Subprojects", 0)
    return
  end

  -- Report lines (one per unique source; note takes if any item already has it)
  local old, ok = {}, {}
  for _, fp in ipairs(order) do
    local c = cache[fp]
    if c.outdated then
      local viaTake = false
      for _, item in ipairs(sels) do
        local r = info[item]
        if r and r.fp == fp and r.take then viaTake = true end
      end
      old[#old + 1] = ("  %s\n     -> newer: %s%s"):format(basename(fp), basename(c.newest),
        viaTake and "  (already a take - will switch)" or "")
    else
      ok[#ok + 1] = "  " .. basename(fp)
    end
  end

  -- Leave only outdated items selected
  for _, item in ipairs(sels) do
    local r = info[item]
    reaper.SetMediaItemSelected(item, r ~= nil and r.outdated)
  end
  reaper.UpdateArrange()

  local msg = {}
  if #old > 0 then
    msg[#msg + 1] = ("OUTDATED (%d) - now the only items selected:\n%s"):format(#old, table.concat(old, "\n"))
  else
    msg[#msg + 1] = "All selected subprojects are the latest version."
  end
  if #ok > 0 then
    msg[#msg + 1] = ("Up to date (%d):\n%s"):format(#ok, table.concat(ok, "\n"))
  end

  if #old == 0 then
    reaper.ShowMessageBox(table.concat(msg, "\n\n"), "JK Check Subprojects", 0)
    return
  end

  msg[#msg + 1] = "Update the outdated items to their most recent version?"
  if reaper.ShowMessageBox(table.concat(msg, "\n\n"), "JK Check Subprojects", 4) ~= 6 then return end

  reaper.Undo_BeginBlock()
  local switched, repointed = 0, 0
  local missing, checked = {}, {}
  for _, item in ipairs(sels) do
    local r = info[item]
    if r and r.outdated then
      if r.take then
        reaper.SetActiveTake(r.take)
        switched = switched + 1
      else
        local take = reaper.GetActiveTake(item)
        local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if reaper.BR_SetTakeSourceFromFile then
          reaper.BR_SetTakeSourceFromFile(take, r.newest, false)
        else
          local newSrc = reaper.PCM_Source_CreateFromFile(r.newest)
          local oldSrc = reaper.SetMediaItemTake_Source(take, newSrc)
          if oldSrc then reaper.PCM_Source_Destroy(oldSrc) end
        end
        if takeName == stem(r.fp) or takeName == basename(r.fp) then
          reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", stem(r.newest), true)
        end
        repointed = repointed + 1
      end
      reaper.UpdateItemInProject(item)
      if not checked[r.newest] then
        checked[r.newest] = true
        local f = io.open(r.newest .. "-PROX", "rb")
        if f then f:close() else missing[#missing + 1] = basename(r.newest) end
      end
    end
  end
  reaper.Main_OnCommand(40047, 0) -- Peaks: build any missing peaks
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("JK: Update subprojects to latest version", -1)

  local done = ("Updated %d item%s: %d switched to an existing take, %d repointed to the newest .rpp.")
    :format(switched + repointed, switched + repointed == 1 and "" or "s", switched, repointed)
  if #missing > 0 then
    done = done .. "\n\nNo .rpp-PROX yet for (render these to hear them):\n  " .. table.concat(missing, "\n  ")
  end
  reaper.ShowMessageBox(done, "JK Check Subprojects", 0)
end

main()
