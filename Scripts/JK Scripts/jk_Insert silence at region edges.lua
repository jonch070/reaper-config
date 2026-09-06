--[[
@description jk_Insert silence at region edges
@version 0.2
@author Jonathan Kawchuk
@about
  For every region in the project, inserts a clean-silence MP3:
    - HEAD copy: left edge sits on the region START
    - TAIL copy: right edge sits on the region END (after any ripple shift)

  Inserted items are color-coded so they're easy to spot:
    HEAD = blue, TAIL = orange.

  Respects Reaper's global ripple mode:
    Ripple OFF
      Clips overlay the region edges. Head at [start, start+0.5], tail at
      [end-0.5, end]. Nothing shifts. The clips visually sit on top of
      whatever audio is already there at those positions.
    Ripple PER-TRACK or ALL
      Region grows by clip length per insertion. Downstream items + markers
      shift to make room. After both insertions, region span is
      [start, end + 2 * clip_len], containing:
          [start, start+clip_len]                head silence
          [start+clip_len, end+clip_len]         shifted chapter content
          [end+clip_len, end+2*clip_len]         tail silence

  Iterates regions RIGHT-TO-LEFT so earlier (lower-position) regions don't
  see their bounds disturbed by later regions' insertions. Within each
  region, inserts TAIL first, then HEAD (head's shift won't disturb tail's
  already-placed position because tail is to the right; tail's shift won't
  matter when head goes next).

@changelog
  0.2 — Fixed ripple: shift first then insert; items + markers at-or-after
        pivot get shifted; current region's start stays, its rgnend extends.
        Recoloured inserted items (head=blue, tail=orange).
  0.1 — Initial.
]]--


-- ── Config ──────────────────────────────────────────────────

-- Different clips per edge: header = 0.5s, tail = 3.5s.
local HEAD_FILE = "/Users/jonathankawchuk/Documents/Projects/Audiobook Editing/Spotify/Current Audiobook Project/room_tone/Clean silence_0.5 Seconds.mp3"
local TAIL_FILE = "/Users/jonathankawchuk/Documents/Projects/Audiobook Editing/Spotify/Current Audiobook Project/room_tone/Clean silence_3.5 Seconds.mp3"

local INSERT_HEAD = true
local INSERT_TAIL = true

-- Item colors (RGB)
local HEAD_RGB = { 60, 160, 220 }     -- light blue
local TAIL_RGB = { 220, 130, 60 }     -- orange

-- Regions shorter than this many * clip_length are skipped to avoid the
-- head and tail overlapping each other. Set to 0 to allow overlap.
local MIN_LENGTH_MULTIPLIER = 2.0

-- Ripple behavior. The detection via GetToggleCommandState isn't reliable
-- across all Reaper versions (some report 0 even when ripple-all is on in
-- the project state). Easiest: just force ripple-all here. Set to false to
-- read the actual toggle state via GetToggleCommandState instead, in which
-- case DEFAULT_RIPPLE_WHEN_OFF is used as a fallback.
local FORCE_RIPPLE_ALL        = true
local DEFAULT_RIPPLE_WHEN_OFF = "all"   -- "all" | "per_track" | "off"


-- ── Helpers ────────────────────────────────────────────────

local function basename(p)
  if not p then return "" end
  return p:match("([^/\\]+)$") or p
end


local function rgb_to_native(rgb)
  return reaper.ColorToNative(rgb[1], rgb[2], rgb[3]) | 0x1000000
end


-- Ripple state: 0 = off, 1 = per-track, 2 = all.
-- If FORCE_RIPPLE_ALL is set (default), returns 2 unconditionally.
-- Otherwise tries GetToggleCommandState (40310 per-track, 40311 all) and
-- falls back to DEFAULT_RIPPLE_WHEN_OFF when both are reported off.
local function ripple_mode()
  if FORCE_RIPPLE_ALL then
    return 2, "FORCE_RIPPLE_ALL = true"
  end
  if reaper.GetToggleCommandState(40311) == 1 then return 2, "Reaper: ALL" end
  if reaper.GetToggleCommandState(40310) == 1 then return 1, "Reaper: PER-TRACK" end
  -- Reaper says off — apply the script default
  if DEFAULT_RIPPLE_WHEN_OFF == "all" then
    return 2, "Reaper off → defaulting to ALL"
  elseif DEFAULT_RIPPLE_WHEN_OFF == "per_track" then
    return 1, "Reaper off → defaulting to PER-TRACK"
  end
  return 0, "Reaper: OFF"
end


-- Track resolution: prefer the track that already has items near `pos`.
-- Falls back to track 1.
local function track_at_pos(pos)
  local n_tracks = reaper.CountTracks(0)
  if n_tracks == 0 then return nil end
  local closest_track, closest_dist = nil, math.huge
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local p = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local d = math.min(math.abs(p - pos), math.abs(p + len - pos))
      if d < closest_dist then
        closest_dist = d
        closest_track = track
      end
    end
  end
  return closest_track or reaper.GetTrack(0, 0)
end


local function insert_clip(track, pos, file_path, color_int)
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  local source = reaper.PCM_Source_CreateFromFile(file_path)
  local len = 0
  if source then
    reaper.SetMediaItemTake_Source(take, source)
    len = reaper.GetMediaSourceLength(source)
  end
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", basename(file_path), true)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", len)
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.0)
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.0)
  if color_int then
    reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_int)
  end
  reaper.UpdateItemInProject(item)
  return item, len
end


-- Shift every item whose position is >= pivot (within 1e-6) by `delta`.
-- restrict_track non-nil = only that track (ripple per-track semantics).
local function shift_items_at_or_after(pivot, delta, restrict_track)
  if delta == 0 then return end
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    if (not restrict_track) or (track == restrict_track) then
      local n_items = reaper.CountTrackMediaItems(track)
      for i = 0, n_items - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if pos >= pivot - 1e-6 then
          reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + delta)
          reaper.UpdateItemInProject(item)
        end
      end
    end
  end
end


-- Shift markers and regions at or after pivot. The "current region" (by idx)
-- gets special handling: if its pos is at/after pivot, only its rgnend is
-- extended (the region's start stays anchored — needed for head insertion).
-- For regions whose pos is BEFORE pivot but whose rgnend is at/after pivot,
-- extend rgnend only.
local function shift_markers_at_or_after(pivot, delta, current_region_idx)
  if delta == 0 then return end
  local n = reaper.CountProjectMarkers(0)
  local snap = {}
  for i = 0, n - 1 do
    local _, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    table.insert(snap, {
      isrgn = isrgn, pos = pos, rgnend = rgnend, name = name,
      idx = idx, color = color,
    })
  end
  for _, m in ipairs(snap) do
    local is_current = m.isrgn and (m.idx == current_region_idx)
    if m.pos >= pivot - 1e-6 then
      if is_current then
        -- Anchor pos, extend rgnend
        reaper.SetProjectMarker3(0, m.idx, true, m.pos, m.rgnend + delta, m.name, m.color)
      else
        local new_pos = m.pos + delta
        local new_end = m.isrgn and (m.rgnend + delta) or m.rgnend
        reaper.SetProjectMarker3(0, m.idx, m.isrgn, new_pos, new_end, m.name, m.color)
      end
    elseif m.isrgn and m.rgnend >= pivot - 1e-6 then
      -- Region straddling (or with rgnend exactly at pivot) — extend rgnend only
      reaper.SetProjectMarker3(0, m.idx, true, m.pos, m.rgnend + delta, m.name, m.color)
    end
  end
end


-- ── Region snapshot ────────────────────────────────────────

local function collect_regions()
  local rows = {}
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if isrgn then
      table.insert(rows, {
        idx = idx, pos = pos, rgnend = rgnend, name = name, color = color,
      })
    end
  end
  return rows
end


local function refetch_region(idx)
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, pos, rgnend, _, m_idx = reaper.EnumProjectMarkers3(0, i)
    if isrgn and m_idx == idx then return pos, rgnend end
  end
  return nil, nil
end


-- ── Main ───────────────────────────────────────────────────

function main()
  -- Validate + measure both clip files
  local function measure(path)
    local s = reaper.PCM_Source_CreateFromFile(path)
    if not s then return nil end
    local l = reaper.GetMediaSourceLength(s)
    reaper.PCM_Source_Destroy(s)
    return l
  end

  local head_len = measure(HEAD_FILE)
  local tail_len = measure(TAIL_FILE)
  if INSERT_HEAD and (not head_len or head_len <= 0) then
    reaper.ShowMessageBox("Could not load HEAD_FILE:\n" .. HEAD_FILE,
      "Insert silence at region edges", 0)
    return
  end
  if INSERT_TAIL and (not tail_len or tail_len <= 0) then
    reaper.ShowMessageBox("Could not load TAIL_FILE:\n" .. TAIL_FILE,
      "Insert silence at region edges", 0)
    return
  end

  local regions = collect_regions()
  if #regions == 0 then
    reaper.ShowMessageBox("No regions found in project.",
      "Insert silence at region edges", 0)
    return
  end

  local mode, mode_label = ripple_mode()
  local respect_ripple = (mode > 0)

  -- Right-to-left so earlier regions aren't disturbed
  table.sort(regions, function(a, b) return a.pos > b.pos end)

  local head_color = rgb_to_native(HEAD_RGB)
  local tail_color = rgb_to_native(TAIL_RGB)

  local prompt = string.format(
    "Regions:        %d\n" ..
    "Head clip:      %s  (%.3fs)   %s   (blue)\n" ..
    "Tail clip:      %s  (%.3fs)   %s   (orange)\n" ..
    "Ripple mode:    %s\n\n" ..
    "Proceed?",
    #regions,
    basename(HEAD_FILE), head_len or 0, INSERT_HEAD and "yes" or "no",
    basename(TAIL_FILE), tail_len or 0, INSERT_TAIL and "yes" or "no",
    mode_label)
  if reaper.ShowMessageBox(prompt, "Insert silence at region edges", 1) ~= 1 then
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local heads, tails, skipped = 0, 0, 0
  local need = (INSERT_HEAD and (head_len or 0) or 0)
             + (INSERT_TAIL and (tail_len or 0) or 0)
  local min_room = need * MIN_LENGTH_MULTIPLIER

  for _, r in ipairs(regions) do
    local cur_pos, cur_end = refetch_region(r.idx)
    if cur_pos == nil then
      -- region gone
    elseif (cur_end - cur_pos) < min_room then
      skipped = skipped + 1
    else
      local track = track_at_pos(cur_pos)
      if track then
        local restrict = (mode == 1) and track or nil

        -- ── TAIL FIRST ─────────────────────────────────────
        if INSERT_TAIL then
          if respect_ripple then
            local tail_pivot = cur_end
            shift_items_at_or_after(tail_pivot, tail_len, restrict)
            shift_markers_at_or_after(tail_pivot, tail_len, r.idx)
            insert_clip(track, tail_pivot, TAIL_FILE, tail_color)
            _, cur_end = refetch_region(r.idx)
          else
            local tail_pivot = cur_end - tail_len
            insert_clip(track, tail_pivot, TAIL_FILE, tail_color)
          end
          tails = tails + 1
        end

        -- ── HEAD ───────────────────────────────────────────
        if INSERT_HEAD then
          if respect_ripple then
            local head_pivot = cur_pos
            shift_items_at_or_after(head_pivot, head_len, restrict)
            shift_markers_at_or_after(head_pivot, head_len, r.idx)
            insert_clip(track, head_pivot, HEAD_FILE, head_color)
          else
            insert_clip(track, cur_pos, HEAD_FILE, head_color)
          end
          heads = heads + 1
        end
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Insert silence at region edges", -1)

  reaper.ShowMessageBox(
    string.format(
      "Done.\n\n" ..
      "Heads inserted: %d (blue)\n" ..
      "Tails inserted: %d (orange)\n" ..
      "Regions skipped: %d (too short)\n\n" ..
      "Ripple mode: %s\n" ..
      "Single Cmd-Z reverts everything.",
      heads, tails, skipped, mode_label),
    "Insert silence at region edges", 0)
end


main()
