-- @description Explode regions to individual named tracks starting at 0:00
-- @author Jonathan Kawchuk (generated)
-- @version 1.1
-- @about
--   Takes every region in the project. For each region:
--   1. Creates a new track named after the region.
--   2. Moves the items that overlap the region (FROM the SOURCE TRACK only)
--      onto the new track.
--   3. Shifts items so the region start becomes 0:00 on the new track.
--   4. Stores the original region start/end/color on the new track's
--      extended state so the reassemble script can restore.
--   5. Deletes the original regions.
--
--   Source track is the SELECTED track. If no track is selected, falls back
--   to the first track that contains items.
--
--   Companion: jk_Reassemble tracks to regions.lua
--
-- @changelog
--   1.1 — Constrain explode to a single SOURCE TRACK (was merging items from
--          all tracks). Use proper item/region overlap detection (was
--          position-only). Plan the moves before executing them. Call
--          UpdateItemInProject after each position set so shifts apply
--          reliably.
--   1.0 — Initial.

local TOLERANCE = 0.001  -- seconds; floating-point fudge for region edges


-- ── Source-track resolution ─────────────────────────────────

local function resolve_source_track()
  -- Use the first selected track if there is one.
  local sel = reaper.CountSelectedTracks(0)
  if sel > 0 then
    return reaper.GetSelectedTrack(0, 0), "selected track"
  end

  -- Fall back: first track with at least one media item.
  local n = reaper.CountTracks(0)
  for t = 0, n - 1 do
    local tr = reaper.GetTrack(0, t)
    if reaper.CountTrackMediaItems(tr) > 0 then
      return tr, "first track with items (no track was selected)"
    end
  end
  return nil, nil
end


-- ── Item ↔ region overlap ───────────────────────────────────

-- Returns true if the item overlaps the region's [pos, rgnend] range.
-- Uses item endpoints, not just position.
local function item_overlaps_region(item, rgn_pos, rgn_end)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = pos + len
  return (item_end > rgn_pos + TOLERANCE) and (pos < rgn_end - TOLERANCE)
end


-- ── Main ────────────────────────────────────────────────────

function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Resolve the source track first
  local src_track, src_label = resolve_source_track()
  if not src_track then
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox(
      "No source track to explode from.\n\n" ..
      "Select the track whose items you want to explode, then run again.",
      "Explode Regions", 0)
    return
  end
  local _, src_track_name = reaper.GetSetMediaTrackInfo_String(src_track, "P_NAME", "", false)

  -- Collect regions
  local total_markers = reaper.CountProjectMarkers(0)
  local regions = {}
  for i = 0, total_markers - 1 do
    local _, isrgn, pos, rgnend, name, _, color = reaper.EnumProjectMarkers3(0, i)
    if isrgn then
      table.insert(regions, { pos = pos, rgnend = rgnend, name = name, color = color })
    end
  end
  if #regions == 0 then
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox("No regions found in project.", "Explode Regions", 0)
    return
  end
  table.sort(regions, function(a, b) return a.pos < b.pos end)

  -- Snapshot all items currently on the source track up front.
  -- Each entry is {item, pos}; we lock pos NOW so later moves don't disturb it.
  local src_items = {}
  local src_item_count = reaper.CountTrackMediaItems(src_track)
  for i = 0, src_item_count - 1 do
    local item = reaper.GetTrackMediaItem(src_track, i)
    table.insert(src_items, {
      item = item,
      pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    })
  end

  -- Plan: for each region, list which source items belong to it.
  -- An item is assigned to the FIRST region it overlaps (no double-counting).
  local plan = {}                         -- region_idx → { items = {...} }
  local assigned = {}                     -- item -> true
  for r_idx, rgn in ipairs(regions) do
    plan[r_idx] = { region = rgn, entries = {} }
    for _, rec in ipairs(src_items) do
      if not assigned[rec.item] and item_overlaps_region(rec.item, rgn.pos, rgn.rgnend) then
        table.insert(plan[r_idx].entries, rec)
        assigned[rec.item] = true
      end
    end
  end

  -- Execute the plan: create one track per region (skipping empty ones),
  -- move + shift items, store extended state.
  local exploded = 0
  for _, p in ipairs(plan) do
    if #p.entries > 0 then
      local idx = reaper.CountTracks(0)
      reaper.InsertTrackAtIndex(idx, false)
      local new_track = reaper.GetTrack(0, idx)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", p.region.name, true)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_EXT:JK_REGION_START",
        tostring(p.region.pos), true)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_EXT:JK_REGION_END",
        tostring(p.region.rgnend), true)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_EXT:JK_REGION_COLOR",
        tostring(p.region.color), true)
      reaper.GetSetMediaTrackInfo_String(new_track, "P_EXT:JK_REGION_SOURCE_TRACK",
        src_track_name, true)

      local offset = p.region.pos
      for _, rec in ipairs(p.entries) do
        local new_pos = rec.pos - offset
        reaper.MoveMediaItemToTrack(rec.item, new_track)
        reaper.SetMediaItemInfo_Value(rec.item, "D_POSITION", new_pos)
        reaper.UpdateItemInProject(rec.item)
      end
      exploded = exploded + 1
    end
  end

  -- Delete original regions (backwards to avoid index shifts)
  local cur_total = reaper.CountProjectMarkers(0)
  for i = cur_total - 1, 0, -1 do
    local _, isrgn = reaper.EnumProjectMarkers(i)
    if isrgn then reaper.DeleteProjectMarkerByIndex(0, i) end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Explode regions to tracks", -1)

  reaper.ShowMessageBox(
    string.format(
      "%d regions exploded to individual tracks.\n\n" ..
      "Source: %s (%s)\n\n" ..
      "Use 'jk_Reassemble tracks to regions' to reverse this.",
      exploded, src_label, src_track_name ~= "" and src_track_name or "(unnamed)"
    ),
    "Explode Regions", 0)
end


main()
