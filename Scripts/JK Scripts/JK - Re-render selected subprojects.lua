-- @description JK - Re-render selected subprojects
-- @author Jonathan Kawchuk
-- @version 1.0
-- @about
--   Select subproject item(s) and run: re-renders each unique source .rpp
--   with its most recent render settings (open tab -> render -> close),
--   refreshing its .rpp-PROX so every parent session picks up the change.
--   Shared sources render once. No prompts; finishes silently.

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
  -- Group selected subproject items by unique source path
  local order = {}
  local seen = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)
    local src = take and reaper.GetMediaItemTake_Source(take)
    local fp = src and reaper.GetMediaSourceFileName(src, "")
    if fp and #fp > 4 and fp:sub(-4):lower() == ".rpp" and not seen[fp] then
      seen[fp] = item
      order[#order + 1] = fp
    end
  end

  if #order == 0 then
    reaper.ShowMessageBox("No subproject (.rpp) items selected.", "JK Re-render Subprojects", 0)
    return
  end

  local selItems = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    selItems[#selItems + 1] = reaper.GetSelectedMediaItem(0, i)
  end

  reaper.Undo_BeginBlock()
  local parentName = reaper.GetProjectName(0, "")

  for _, fp in ipairs(order) do
    reaper.Main_OnCommand(40289, 0)          -- deselect all items
    reaper.SetMediaItemSelected(seen[fp], true)
    reaper.Main_OnCommand(40109, 0)          -- open subproject in new tab
    reaper.Main_OnCommand(42332, 0)          -- render project, last settings
    -- Save silently if rendering flagged the project dirty, so closing
    -- doesn't pop a "Save project before closing?" prompt
    if reaper.IsProjectDirty(0) > 0 then
      reaper.Main_OnCommand(40026, 0)        -- File: Save project
    end
    reaper.Main_OnCommand(40860, 0)          -- close tab
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

  reaper.Main_OnCommand(40289, 0)
  for _, item in ipairs(selItems) do
    reaper.SetMediaItemSelected(item, true)
  end
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)
  reaper.Undo_EndBlock("JK: Re-render selected subprojects", -1)
end

main()
