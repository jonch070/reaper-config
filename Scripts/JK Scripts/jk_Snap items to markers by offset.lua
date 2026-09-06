--[[
@description jk_Snap items to markers by offset
  @version 1.1
  @author Jonathan Kawchuk
@about
  Snaps selected items to their nearest marker using D_SNAPOFFSET.
  Each item is moved so its snap-offset point aligns to the nearest
  project marker.

  Run jk_Count snap targets first to preview what this will do.

@changelog
  1.1 — Clean break: no flagging, just snap or skip. Run count first.
  1.0 — Initial.
]]--

local function main()
  local count = reaper.CountSelectedMediaItems(0)
  if count == 0 then
    reaper.ShowMessageBox("Select one or more items first.",
      "Snap items to markers", 0)
    return
  end

  -- Collect all project markers
  local _, marker_count = reaper.CountProjectMarkers(0)
  local markers = {}
  for i = 0, marker_count - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber
    retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
    if not isrgn then
      table.insert(markers, { pos = pos, name = name or "", idx = markrgnindexnumber })
    end
  end
  table.sort(markers, function(a, b) return a.pos < b.pos end)

  if #markers == 0 then
    reaper.ShowMessageBox("No markers found in project.",
      "Snap items to markers", 0)
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local snapped = 0
  local skipped = 0
  local results = {}

  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local snapoff = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    if not snapoff or snapoff <= 0 then
      skipped = skipped + 1
      table.insert(results, string.format("  item %-3d  SKIP  no SNAPOFFSET", i + 1))
      goto continue
    end

    local snap_point = pos + snapoff

    local best_marker, best_dist = nil, 1e18
    for _, m in ipairs(markers) do
      local d = math.abs(m.pos - snap_point)
      if d < best_dist then
        best_dist = d
        best_marker = m
      end
    end

    if not best_marker then
      skipped = skipped + 1
      table.insert(results, string.format("  item %-3d  SKIP  no markers", i + 1))
      goto continue
    end

    local new_pos = best_marker.pos - snapoff
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
    reaper.UpdateItemInProject(item)
    snapped = snapped + 1

    table.insert(results, string.format(
      "  item %-3d  OK    %.3f → %.3f  (Δ%+.3f)  marker='%s' @%.3f",
      i + 1, pos, new_pos, new_pos - pos, best_marker.name, best_marker.pos))

    ::continue::
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Snap items to markers", -1)

  reaper.ClearConsole()
  reaper.ShowConsoleMsg(string.format(
    "Snap items — %d/%d  |  %d OK  %d SKIP\n\n", snapped, count, snapped, skipped))
  for _, r in ipairs(results) do
    reaper.ShowConsoleMsg(r .. "\n")
  end
  reaper.ShowMessageBox(string.format(
    "Complete.\n\nSelected: %d\nSnapped: %d\nSkipped (no offset): %d",
    count, snapped, skipped), "Snap items to markers", 0)
end

main()
