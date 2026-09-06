--[[
@description jk_Snap region edges to adjacent items
@version 0.1
@author Jonathan Kawchuk
@about
  For every region in the project:
    - Moves region START to the start edge of the item immediately before it
    - Moves region END   to the end edge   of the item immediately after it

  If no item exists adjacent to a region edge, that edge is left unchanged.
]]--


local TOLERANCE = 0.001


-- ── Find the nearest item left of a position ───────────────

local function item_left_of(pos)
  local best_item, best_end = nil, -1
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = item_pos + item_len
      -- Ends at or before pos, and is the closest such item
      if item_end <= pos + TOLERANCE and item_end > best_end then
        best_item = item
        best_end = item_end
      end
    end
  end
  return best_item, best_end
end


-- ── Find the nearest item right of a position ──────────────

local function item_right_of(pos)
  local best_item, best_pos = nil, math.huge
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      -- Starts at or after pos, and is the closest such item
      if item_pos >= pos - TOLERANCE and item_pos < best_pos then
        best_item = item
        best_pos = item_pos
      end
    end
  end
  return best_item, best_pos
end


-- ── Main ──────────────────────────────────────────────────

function main()
  local total = reaper.CountProjectMarkers(0)
  local regions = {}
  for i = 0, total - 1 do
    local _, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if isrgn then
      table.insert(regions, {
        idx = idx, pos = pos, rgnend = rgnend, name = name, color = color,
      })
    end
  end

  if #regions == 0 then
    reaper.ShowMessageBox("No regions found.", "Snap region edges", 0)
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local snapped_start, snapped_end = 0, 0

  for _, r in ipairs(regions) do
    local left_item, left_end = item_left_of(r.pos)
    local right_item, right_pos = item_right_of(r.rgnend)

    local new_pos = r.pos
    local new_end = r.rgnend

    if left_item then
      local left_start = reaper.GetMediaItemInfo_Value(left_item, "D_POSITION")
      new_pos = left_start
      snapped_start = snapped_start + 1
    end

    if right_item then
      local right_len = reaper.GetMediaItemInfo_Value(right_item, "D_LENGTH")
      new_end = right_pos + right_len
      snapped_end = snapped_end + 1
    end

    if new_pos ~= r.pos or new_end ~= r.rgnend then
      reaper.SetProjectMarker3(0, r.idx, true, new_pos, new_end, r.name, r.color)
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Snap region edges to adjacent items", -1)

  reaper.ShowMessageBox(string.format(
    "Regions: %d\n\n" ..
    "Starts snapped: %d\n" ..
    "Ends snapped:   %d",
    #regions, snapped_start, snapped_end), "Snap region edges", 0)
end


main()
