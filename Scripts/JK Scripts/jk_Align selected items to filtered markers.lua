--[[
@description jk_Align selected items to filtered markers
@version 0.1
@author Jonathan Kawchuk (forked from LKC)
@about
  Same as LKC's "Align selected items to markers inside time selection",
  but only counts markers whose name matches MARKER_FILTER_PATTERN.

  The pattern is a Lua pattern, applied to the lowercased marker name.
  Default: "@%s*narrator" — matches "@narrator" with optional whitespace,
  with or without a trailing digit. Adjust to taste.

  Behavior:
    - Build a time selection that spans the markers you want to align to.
    - Select the items (in order) that should snap to those markers.
    - Run the action.
    - The Nth selected item snaps to the Nth filter-matching marker.
    - Items use their D_SNAPOFFSET when snapping (set with
      jk_Set CRX snap offset.lua first).

  Original credit: LKC, "Align selected items to markers inside time
  selection" v1.0 (2019). This fork adds the name filter and a small
  diagnostic dialog.
]]--


-- ── Config ──────────────────────────────────────────────────

-- Lua pattern, applied to lowercased marker name.
-- Examples:
--   "@%s*narrator"           — any @narrator (with or without digit)
--   "@%s*narrator%s*1"       — only @narrator1
--   "|%s*pbp:"               — only PBP-tagged markers
--   ".-"                     — match anything (= LKC behavior)
local MARKER_FILTER_PATTERN = "narrator"

-- If true, show a confirmation dialog with marker count + skip if user cancels.
local SHOW_CONFIRMATION = false


-- ── Main ────────────────────────────────────────────────────

function main()
  -- Items to snap (in selection order)
  local items = {}
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    items[i + 1] = reaper.GetSelectedMediaItem(0, i)
  end

  -- Time selection bounds
  local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if endTime - startTime <= 0 then
    reaper.ShowMessageBox(
      "Make a time selection first that includes the markers you want to align to.",
      "Align to filtered markers", 0)
    return
  end
  if #items == 0 then
    reaper.ShowMessageBox("Select one or more items first.", "Align to filtered markers", 0)
    return
  end

  -- Filtered marker positions inside the time selection, in time order
  local marker_positions = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  local total = num_markers + num_regions
  for i = 0, total - 1 do
    local _, isrgn, pos, _, name = reaper.EnumProjectMarkers(i)
    if not isrgn and pos >= startTime and pos <= endTime then
      local lname = (name or ""):lower()
      if lname:find(MARKER_FILTER_PATTERN) then
        table.insert(marker_positions, pos)
      end
    end
  end

  if #marker_positions == 0 then
    reaper.ShowMessageBox(
      "No markers in the time selection match the filter:\n  " ..
      MARKER_FILTER_PATTERN ..
      "\n\nEdit MARKER_FILTER_PATTERN at the top of the script.",
      "Align to filtered markers", 0)
    return
  end

  if SHOW_CONFIRMATION then
    local prompt = string.format(
      "Filter pattern: %s\n" ..
      "Matching markers in selection: %d\n" ..
      "Selected items: %d\n\n" ..
      "Items pair 1↔1 with markers in time order. Proceed?",
      MARKER_FILTER_PATTERN, #marker_positions, #items)
    if reaper.ShowMessageBox(prompt, "Align to filtered markers", 1) ~= 1 then
      return
    end
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local n = math.min(#items, #marker_positions)
  for i = 1, n do
    local item = items[i]
    local marker_pos = marker_positions[i]
    if item then
      local snap_offset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", marker_pos - snap_offset)
      reaper.UpdateItemInProject(item)
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Align selected items to filtered markers", -1)

  reaper.ShowMessageBox(
    string.format(
      "Aligned %d items to filtered markers.\n\n" ..
      "Filter: %s\n" ..
      "Items: %d  Markers: %d\n" ..
      "Pairs made: %d (the smaller of the two).",
      n, MARKER_FILTER_PATTERN, #items, #marker_positions, n
    ),
    "Align to filtered markers", 0)
end


main()
