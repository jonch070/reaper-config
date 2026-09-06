--[[
@description jk_Count snap targets
  @version 1.0
  @author Jonathan Kawchuk
@about
  Reports how many selected items have SNAPOFFSET set and which marker
  each would snap to. Does NOT move anything — dry-run preview only.

@changelog
  1.0 — Initial.
]]--

local function main()
  local count = reaper.CountSelectedMediaItems(0)
  if count == 0 then
    reaper.ShowMessageBox("Select one or more items first.",
      "Count snap targets", 0)
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

  local with_offset = 0
  local no_offset = 0
  local lines = {}

  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local snapoff = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    if not snapoff or snapoff <= 0 then
      no_offset = no_offset + 1
      table.insert(lines, string.format("  item %-3d  NO SNAPOFFSET  pos=%.3f", i + 1, pos))
    else
      with_offset = with_offset + 1
      local snap_point = pos + snapoff

      local best_marker, best_dist = nil, 1e18
      for _, m in ipairs(markers) do
        local d = math.abs(m.pos - snap_point)
        if d < best_dist then
          best_dist = d
          best_marker = m
        end
      end

      if best_marker then
        local new_pos = best_marker.pos - snapoff
        local delta = new_pos - pos
        table.insert(lines, string.format(
          "  item %-3d  snapoff=%.3f  pos=%.3f → %.3f (Δ%+.3f)  marker='%s' @%.3f  dist=%.3f",
          i + 1, snapoff, pos, new_pos, delta,
          best_marker.name, best_marker.pos, best_dist))
      else
        table.insert(lines, string.format(
          "  item %-3d  snapoff=%.3f  pos=%.3f  NO MARKER IN PROJECT",
          i + 1, snapoff, pos))
      end
    end
  end

  reaper.ClearConsole()
  reaper.ShowConsoleMsg(string.format(
    "Snap targets — %d selected  |  %d with SNAPOFFSET  %d without\n\n",
    count, with_offset, no_offset))
  for _, l in ipairs(lines) do
    reaper.ShowConsoleMsg(l .. "\n")
  end
  reaper.ShowMessageBox(string.format(
    "Count complete.\n\nSelected: %d\nWith SNAPOFFSET: %d\nWithout: %d\n\nDetails in console.",
    count, with_offset, no_offset), "Count snap targets", 0)
end

main()
