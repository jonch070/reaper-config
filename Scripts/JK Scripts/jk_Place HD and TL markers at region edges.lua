--[[
@description jk_Place HD and TL markers at region edges
@version 0.1
@author Jonathan Kawchuk
@about
  For every region in the project:
    - Adds an HD marker at region.start  (header silence anchor)
    - Adds a TL marker at region.end     (tail silence anchor)

  Idempotent: if a marker tagged HD or TL already sits within ±0.01s of the
  target position, it's left alone. Safe to run multiple times.

  Usage:
    Run, see how many were added. Then run the silence cropper preview to
    confirm placement, then the apply pass to crop and pad.

  Marker name format: matches the Pozotron-style tags so the cropper picks
  them up:
    "auto #N | HD: -- seconds"
    "auto #N | TL: -- seconds"
  (The "-- seconds" placeholder is fine; the cropper measures actual silence.)
]]--


local TOLERANCE = 0.01      -- seconds; consider markers at this distance "the same"


local function existing_tag_near(pos, tag)
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, mpos, _, name = reaper.EnumProjectMarkers(i)
    if not isrgn and math.abs(mpos - pos) < TOLERANCE then
      if name and name:upper():find("|%s*" .. tag .. ":") then
        return true
      end
    end
  end
  return false
end


function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Collect regions
  local total = reaper.CountProjectMarkers(0)
  local regions = {}
  for i = 0, total - 1 do
    local _, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
    if isrgn then
      table.insert(regions, { idx = idx, pos = pos, rgnend = rgnend, name = name })
    end
  end
  if #regions == 0 then
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox("No regions found in project.", "Place HD/TL", 0)
    return
  end
  table.sort(regions, function(a, b) return a.pos < b.pos end)

  local hd_added, tl_added, hd_skipped, tl_skipped = 0, 0, 0, 0
  local seq = 0

  for _, r in ipairs(regions) do
    seq = seq + 1
    local hd_name = string.format("auto #%d | HD: -- seconds", seq)
    if existing_tag_near(r.pos, "HD") then
      hd_skipped = hd_skipped + 1
    else
      reaper.AddProjectMarker2(0, false, r.pos, 0, hd_name, -1, 0)
      hd_added = hd_added + 1
    end

    local tl_name = string.format("auto #%d | TL: -- seconds", seq)
    if existing_tag_near(r.rgnend, "TL") then
      tl_skipped = tl_skipped + 1
    else
      reaper.AddProjectMarker2(0, false, r.rgnend, 0, tl_name, -1, 0)
      tl_added = tl_added + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Place HD and TL markers at region edges", -1)

  reaper.ShowMessageBox(
    string.format(
      "Regions: %d\n\n" ..
      "HD markers added:    %d\n" ..
      "HD markers skipped:  %d (already present)\n\n" ..
      "TL markers added:    %d\n" ..
      "TL markers skipped:  %d (already present)\n\n" ..
      "Run the silence cropper preview next to confirm.",
      #regions, hd_added, hd_skipped, tl_added, tl_skipped
    ),
    "Place HD/TL", 0)
end


main()
