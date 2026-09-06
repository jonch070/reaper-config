-- @description JK - Duplicate subprojects to new version (prompted)
-- @author Jonathan Kawchuk
-- @version 1.1
-- @about
--   Select subproject item(s) and run: duplicates each unique source .rpp to
--   a new version file, prompting for the new name (pre-filled with a smart
--   suggestion) instead of silently appending _vNN like Subproject Hub.
--
--   - Understands trailing version tokens in any of these shapes:
--       "... - v01.00.04"  -> "... - v01.00.05"
--       "..._v07"          -> "..._v08"
--       "... v3"           -> "... v4"
--     (zero-padding and separators are preserved; no token found -> suggests
--     appending " - v01")
--   - One prompt per unique source file; shared sources share one duplicate.
--   - Cancel/Escape at any prompt aborts the whole operation before any
--     changes are made.
--   - Adds the duplicate as a new take on each item and tags it with a take
--     marker named after the new file, leaving the original file/take
--     untouched as history.
--   - Makes the duplicate playable instantly: copies the original's
--     .rpp-PROX pre-render when one exists (audio is identical until you
--     edit the new version); falls back to an open/render/close pass only
--     for sources without a prox.

-- ============================================================================
-- HELPERS
-- ============================================================================

local SEP = package.config:sub(1, 1)

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

local function trim(s)
  return s:match("^%s*(.-)%s*$") or ""
end

local function sanitizeName(name)
  name = name:gsub('[<>:"/\\|?*]', "-")
  return trim(name)
end

---Increment the final numeric component of a trailing version token.
---"Title - v01.00.04" -> "Title - v01.00.05", "Cue_v07" -> "Cue_v08".
---Width overflow carries left ("v01.00.99" -> "v01.01.00"); a lone token
---grows instead ("v99" -> "v100"). Preserves separators and zero-padding.
---Returns nil if no token found.
---@param base string Filename without extension
---@return string? bumped
local function bumpVersion(base)
  local prefix, sep, ver = base:match("^(.-)([_%s%-]*)([vV]%d+[%d%.]*)$")
  if not ver then return nil end
  local nums = {}
  for n in ver:gmatch("%d+") do nums[#nums + 1] = n end
  if #nums == 0 then return nil end
  local i = #nums
  while i >= 1 do
    local group = nums[i]
    local bumped = tostring(tonumber(group) + 1)
    if #bumped <= #group then
      if #bumped < #group then bumped = string.rep("0", #group - #bumped) .. bumped end
      nums[i] = bumped
      break
    elseif i > 1 then
      nums[i] = string.rep("0", #group)  -- roll over, carry left
      i = i - 1
    else
      nums[i] = bumped  -- leftmost group: let it grow
      break
    end
  end
  local newver = ver:gsub("%d+", function() return table.remove(nums, 1) end)
  return prefix .. sep .. newver
end

---Shorten a long base name for dialog captions
local function shorten(s, maxlen)
  maxlen = maxlen or 40
  if #s <= maxlen then return s end
  return s:sub(1, maxlen - 3) .. "..."
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
  -- Collect selected subproject items grouped by source file path
  local groups, order = {}, {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)
    local src = take and reaper.GetMediaItemTake_Source(take)
    local fp = src and reaper.GetMediaSourceFileName(src, "")
    if fp and #fp > 4 and fp:sub(-4):lower() == ".rpp" then
      if not groups[fp] then groups[fp] = {}; order[#order + 1] = fp end
      table.insert(groups[fp], item)
    end
  end

  if #order == 0 then
    reaper.ShowMessageBox("No subproject (.rpp) items selected.", "Duplicate to New Version", 0)
    return
  end

  -- ------------------------------------------------------------------
  -- PHASE 1: Prompt for all new names BEFORE touching anything
  -- ------------------------------------------------------------------
  local plan = {}  -- origPath -> { newPath=..., newBase=... }
  for _, origPath in ipairs(order) do
    local folder, filename = origPath:match("^(.-)[\\/]+([^\\/]+)$")
    local base = filename and filename:match("^(.*)%.([^.]+)$")
    base = base and trim(base) or filename
    folder = folder or ""

    local proposal = bumpVersion(base) or (base .. " - v01")

    while true do
      local retval, vals = reaper.GetUserInputs(
        "Duplicate subproject to new version",
        1,
        "New name for '" .. shorten(base) .. "' (no extension):",
        proposal)
      if not retval then return end  -- cancelled -> abort everything

      -- GetUserInputs returns values as a single CSV string, not a table
      local newBase = sanitizeName(tostring(vals or ""))
      if newBase == "" then
        reaper.ShowMessageBox("Name cannot be empty.", "Duplicate to New Version", 0)
      elseif newBase:lower() == base:lower() then
        reaper.ShowMessageBox("New name must differ from the original.", "Duplicate to New Version", 0)
      else
        local newPath = folder .. SEP .. newBase .. ".rpp"
        if file_exists(newPath) then
          reaper.ShowMessageBox("File already exists:\n" .. newPath .. "\n\nChoose another name.",
            "Duplicate to New Version", 0)
        else
          plan[origPath] = { newPath = newPath, newBase = newBase }
          break
        end
      end
    end
  end

  -- ------------------------------------------------------------------
  -- PHASE 2: Copy files
  -- ------------------------------------------------------------------
  for origPath, p in pairs(plan) do
    local infile = io.open(origPath, "rb")
    if not infile then
      reaper.ShowMessageBox("Could not open:\n" .. origPath, "Duplicate to New Version", 0)
      return
    end
    local content = infile:read("*all")
    infile:close()
    local outfile = io.open(p.newPath, "wb")
    if not outfile then
      reaper.ShowMessageBox("Could not create:\n" .. p.newPath, "Duplicate to New Version", 0)
      return
    end
    outfile:write(content)
    outfile:close()
  end

  -- ------------------------------------------------------------------
  -- PHASE 3: Add new takes pointing at the duplicates
  -- ------------------------------------------------------------------
  reaper.Undo_BeginBlock()
  local parentName = reaper.GetProjectName(0, "")
  reaper.Main_OnCommand(40289, 0)  -- deselect all items

  local touched = {}  -- flat list of successfully updated items
  for _, origPath in ipairs(order) do
    local p = plan[origPath]
    for _, item in ipairs(groups[origPath]) do
      local take = reaper.GetActiveTake(item)
      local src = take and reaper.GetMediaItemTake_Source(take)
      if take and src then
        local newTake = reaper.AddTakeToMediaItem(item)
        local newSrc = reaper.PCM_Source_CreateFromFile(p.newPath)
        reaper.SetMediaItemTake_Source(newTake, newSrc)
        reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS",
          reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"))
        local ok, tname = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if ok then reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", tname, true) end
        reaper.SetMediaItemInfo_Value(item, "I_CURTAKE", reaper.CountTakes(item) - 1)
        touched[#touched + 1] = item
      end
    end
  end

  -- ------------------------------------------------------------------
  -- PHASE 4: Make each duplicate playable
  --
  -- REAPER plays subproject items from the <name>.rpp-PROX pre-render next
  -- to the .rpp. The original's prox holds identical audio (nothing changed
  -- yet), so copying it is instant and avoids opening/rendering tabs. Only
  -- fall back to the render pass when no prox exists. Once the duplicate is
  -- edited and saved, REAPER re-renders it as usual.
  -- ------------------------------------------------------------------
  local rendered = {}
  for _, origPath in ipairs(order) do
    local p = plan[origPath]
    if not rendered[p.newPath] then
      rendered[p.newPath] = true

      -- Fast path: clone the original's pre-render
      local oldProx = origPath .. "-PROX"
      local newProx = p.newPath .. "-PROX"
      if file_exists(oldProx) and not file_exists(newProx) then
        local pin = io.open(oldProx, "rb")
        if pin then
          local data = pin:read("*all")
          pin:close()
          if data then
            local pout = io.open(newProx, "wb")
            if pout then pout:write(data) pout:close() end
          end
        end
      end

      -- Fallback: no usable prox -> render via tab
      if not file_exists(newProx) then
        -- Isolate selection to one item bound to this duplicate
        reaper.Main_OnCommand(40289, 0)
        local rep = groups[origPath][1]
        reaper.SetMediaItemSelected(rep, true)
        reaper.Main_OnCommand(40109, 0)   -- open subproject in tab
        reaper.Main_OnCommand(42332, 0)   -- render project with last settings
        -- Save silently if rendering flagged the project dirty, so closing
        -- doesn't pop a "Save project before closing?" prompt
        if reaper.IsProjectDirty(0) > 0 then
          reaper.Main_OnCommand(40026, 0) -- File: Save project
        end
        reaper.Main_OnCommand(40860, 0)   -- close tab
        if parentName ~= "" then
          local i = 0
          while true do
            local proj = reaper.EnumProjects(i, "")
            if not proj then break end
            if reaper.GetProjectName(proj, "") == parentName then
              reaper.SelectProjectInstance(proj)
              break
            end
            i = i + 1
          end
        end
      end
    end
  end

  -- ------------------------------------------------------------------
  -- PHASE 5: Tag new takes with markers named after the new files
  -- ------------------------------------------------------------------
  reaper.Main_OnCommand(40289, 0)
  for _, item in ipairs(touched) do
    reaper.SetMediaItemSelected(item, true)
  end
  for _, item in ipairs(touched) do
    local tc = reaper.CountTakes(item)
    if tc > 1 then
      local newTake = reaper.GetTake(item, tc - 1)
      if newTake then
        local src = reaper.GetMediaItemTake_Source(newTake)
        if src then
          local fp = reaper.GetMediaSourceFileName(src, "")
          local fname = fp and fp:match("([^\\/]+)%.rpp$")
          if fname then
            reaper.SetTakeMarker(newTake, -1, fname,
              reaper.GetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS"))
          end
        end
      end
    end
  end

  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)
  reaper.Undo_EndBlock("JK: Duplicate subprojects to new version (prompted)", -1)
end

main()
