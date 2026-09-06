--[[
@description jk_Insert room tone at markers
@version 0.1
@author Jonathan Kawchuk
@about
  For every HD, SH, and TL marker in the project: inserts the matching room
  tone audio file at the marker position, colour-codes it, and ripples all
  items and markers after it.

  Room tone file mapping (from <project>/room_tone/):
    HD → Clean silence_0.5 Seconds.mp3   (0.5s header silence)
    SH → Clean silence_2.5 Seconds.mp3   (2.5s subheader)
    TL → Clean silence_3.5 Seconds.mp3   (3.5s tail silence)

  Room tone folder is auto-detected from the RPP project location
  (looks for <project>/room_tone/). Markers are processed left-to-right so
  that cumulative ripples are handled correctly.

  Prerequisite: run "Item: Split items at project markers" first so items
  have clean split points at each marker.

  Idempotent: if a room tone item named "RT" already exists within 50ms of
  the marker position, the marker is skipped. Safe to run multiple times.

  Companion script: jk_Place HD and TL markers at region edges.lua
]]--


-- ── Config ──────────────────────────────────────────────────

local ROOM_TONE_MAP = {
  HD = { file = "Clean silence_0.5 Seconds.mp3", secs = 0.5, name = "HD" },
  SH = { file = "Clean silence_2.5 Seconds.mp3", secs = 2.5, name = "SH" },
  TL = { file = "Clean silence_3.5 Seconds.mp3", secs = 3.5, name = "TL" },
}

local ROOM_TONE_DIR  = ""    -- empty = auto-detect from RPP location + "/room_tone/"

-- Reaper native colour (ColorToNative(R,G,B) | 0x1000000)
-- Warm tan/brown to visually distinguish room tone from narration.
local ROOM_TONE_COLOR = reaper.ColorToNative(180, 130, 70) | 0x1000000

-- Prefix used for room tone item names (for idempotency check)
local RT_ITEM_PREFIX = "RT"

-- If an item with the RT prefix already exists within this distance of the
-- marker, skip that marker (idempotent re-run).
local REINSERT_TOLERANCE = 0.050

-- ── Helpers ─────────────────────────────────────────────────

local function basename(p)
  if not p then return "" end
  return p:match("([^/\\]+)$") or p
end

local function dirname(p)
  if not p then return "" end
  return p:match("(.*/)") or p:match("(.*\\)") or "./"
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end


-- ── Project root detection ─────────────────────────────────

local function detect_project_root()
  local _, rpp_full = reaper.EnumProjects(0, "")
  if not rpp_full or rpp_full == "" then
    rpp_full = reaper.GetProjectPath(0) .. "/"
  end
  local dir = dirname(rpp_full)

  local parent = dirname(dir:sub(1, -2))
  if basename(dir:sub(1, -2)):lower() == "reaper projects" then
    return parent
  end

  local f = io.open(dir .. "pipeline.config.yaml", "r")
  if f then f:close(); return dir end

  return dir
end


-- ── Room tone directory resolution ─────────────────────────

local function resolve_room_tone_dir()
  if ROOM_TONE_DIR ~= "" then return ROOM_TONE_DIR end
  local project_root = detect_project_root()
  local dir = project_root .. "room_tone/"
  local f = io.open(dir, "r")
  if f then f:close(); return dir end
  return nil
end


-- ── Marker kind detection ──────────────────────────────────
--
-- Rules (case-insensitive):
--   1. "hd:", "sh:", "tl:" preceded by a non-word char  →  match (catches "| HD:")
--   2. Bare "hd", "sh", "tl" as the entire marker name   →  match (catches "SH")
--   3. Does NOT match embedded occurrences like "axyloTL" or "HD tv"
--      because rule 1 requires a colon, and rule 2 requires an exact match.

local function marker_kind(name)
  if not name then return nil end
  local lower = " " .. name:lower() .. " "
  for kind, _ in pairs(ROOM_TONE_MAP) do
    local k = kind:lower()
    -- Rule 1: word-boundary before + colon after
    if lower:find("[^%w]" .. k .. ":") then return kind end
    -- Rule 2: marker named exactly this, case-insensitive
    if trim(name:lower()) == k then return kind end
  end
  return nil
end


-- ── Idempotency check ─────────────────────────────────────

local function room_tone_exists_at(marker_pos)
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      if math.abs(pos - marker_pos) < REINSERT_TOLERANCE then
        local take = reaper.GetActiveTake(item)
        if take then
          local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
          if take_name and take_name:sub(1, #RT_ITEM_PREFIX) == RT_ITEM_PREFIX then
            return true
          end
        end
      end
    end
  end
  return false
end


-- ── Find the track with items at this position ─────────────

local function track_at_position(pos)
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      if pos >= item_pos - 0.001 and pos <= item_pos + item_len + 0.001 then
        return track
      end
    end
  end
  -- Fallback: first track with items
  for t = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, t)
    if reaper.CountTrackMediaItems(track) > 0 then return track end
  end
  return nil
end


-- ── Shift items AT and beyond a position ───────────────────
--
-- Items at >= pivot get shifted. This handles the right half of
-- a split at the marker (which has position == marker_pos).
-- Markers use a strict > check so the current marker stays put.

local function shift_items_from(pivot, delta)
  if delta == 0 then return end
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
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

-- Shift markers strictly after a position. The current marker
-- (exclude_idx) and markers at == pivot are left in place.
local function shift_markers_after(pivot, delta, exclude_idx)
  if delta == 0 then return end
  local n = reaper.CountProjectMarkers(0)
  local snap = {}
  for i = 0, n - 1 do
    local _, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    table.insert(snap, {
      isrgn = isrgn, pos = pos, rgnend = rgnend,
      idx = idx, name = name, color = color,
    })
  end
  for _, m in ipairs(snap) do
    if m.idx == exclude_idx then
      -- Leave this marker where it is
    elseif m.pos > pivot + 1e-6 then
      reaper.SetProjectMarker3(0, m.idx, m.isrgn, m.pos + delta,
        m.isrgn and (m.rgnend + delta) or m.rgnend, m.name, m.color)
    elseif m.isrgn and m.pos <= pivot + 1e-6 and m.rgnend > pivot + 1e-6 then
      reaper.SetProjectMarker3(0, m.idx, true, m.pos, m.rgnend + delta, m.name, m.color)
    end
  end
end


-- ── Process one marker ─────────────────────────────────────

local function process_marker(marker_idx, marker_name, marker_pos, room_tone_dir)
  local kind = marker_kind(marker_name)
  if not kind then return nil end

  local info = ROOM_TONE_MAP[kind]
  local filepath = room_tone_dir .. info.file

  local f = io.open(filepath, "r")
  if not f then return nil, string.format("file not found: %s", info.file) end
  f:close()

  if room_tone_exists_at(marker_pos) then
    return { kind = kind, action = "skipped", reason = "room tone already present" }
  end

  local track = track_at_position(marker_pos)
  if not track then return nil, "no track at marker position" end

  -- 1. Ripple FIRST: push items at/after marker right by room tone duration
  --    This clears space for the room tone and moves the right half of any split.
  shift_items_from(marker_pos, info.secs)
  shift_markers_after(marker_pos, info.secs, marker_idx)

  -- 2. Insert room tone in the gap
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", marker_pos)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", info.secs)
  reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", ROOM_TONE_COLOR)

  local take = reaper.AddTakeToMediaItem(item)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", RT_ITEM_PREFIX .. " " .. info.name, true)
  local src = reaper.PCM_Source_CreateFromFile(filepath)
  reaper.SetMediaItemTake_Source(take, src)
  reaper.UpdateItemInProject(item)

  return { kind = kind, action = "inserted", secs = info.secs }
end


-- ── Collect all HD/SH/TL markers L→R ──────────────────────

local function collect_markers()
  local markers = {}
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, pos, _, name, idx = reaper.EnumProjectMarkers(i)
    if not isrgn and marker_kind(name) then
      table.insert(markers, {
        marker_idx = idx,
        pos = pos,
        name = name,
      })
    end
  end
  table.sort(markers, function(a, b) return a.pos < b.pos end)
  return markers
end


-- ── Main ──────────────────────────────────────────────────

function main()
  local room_tone_dir = resolve_room_tone_dir()
  if not room_tone_dir then
    reaper.ShowMessageBox(
      "Could not find room_tone/ directory.\n\n" ..
      "Place your room tone audio files in:\n" ..
      "  <project>/room_tone/\n\n" ..
      "Or set ROOM_TONE_DIR at the top of the script.",
      "Room tone directory", 0)
    return
  end

  -- Verify required files
  local missing = {}
  for kind, info in pairs(ROOM_TONE_MAP) do
    if not io.open(room_tone_dir .. info.file, "r") then
      table.insert(missing, kind .. " → " .. info.file)
    end
  end
  if #missing > 0 then
    reaper.ShowMessageBox(
      "Missing room tone files in:\n  " .. room_tone_dir ..
      "\n\n" .. table.concat(missing, "\n  "),
      "Missing files", 0)
    return
  end

  local markers = collect_markers()
  if #markers == 0 then
    reaper.ShowMessageBox(
      "No HD, SH, or TL markers found.\n\n" ..
      "Run jk_Place HD and TL markers at region edges first,\n" ..
      "then add SH markers at subheader positions.",
      "Insert room tone", 0)
    return
  end

  -- Confirm
  local counts = {}
  for _, m in ipairs(markers) do
    local k = marker_kind(m.name)
    counts[k] = (counts[k] or 0) + 1
  end
  local lines = {}
  for _, k in ipairs({"HD", "SH", "TL"}) do
    if counts[k] then table.insert(lines, string.format("  %s: %d", k, counts[k])) end
  end
  local msg = string.format(
    "Room tone dir: %s\n\nMarkers to process:\n%s\n\n" ..
    "Proceed?",
    room_tone_dir, table.concat(lines, "\n"))
  if reaper.ShowMessageBox(msg, "Insert room tone at markers", 1) ~= 1 then return end

  -- Split items at all markers first
  reaper.Main_OnCommand(40931, 0)

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local results = {}
  local inserted, skipped = 0, 0

  for _, m in ipairs(markers) do
    -- Re-fetch current marker position (may have shifted)
    local cur_pos = nil
    local n = reaper.CountProjectMarkers(0)
    for i = 0, n - 1 do
      local _, isrgn, pos, _, _, idx = reaper.EnumProjectMarkers(i)
      if not isrgn and idx == m.marker_idx then
        cur_pos = pos
        break
      end
    end
    if not cur_pos then
      table.insert(results, string.format("  M%-4d  ?  not found (deleted?)", m.marker_idx))
      skipped = skipped + 1
    else
      local r, err = process_marker(m.marker_idx, m.name, cur_pos, room_tone_dir)
      if r then
        if r.action == "inserted" then
          table.insert(results, string.format("  M%-4d  %s  inserted %.1fs room tone at %.3f",
            m.marker_idx, r.kind, r.secs, cur_pos))
          inserted = inserted + 1
        else
          table.insert(results, string.format("  M%-4d  %s  skipped — %s",
            m.marker_idx, r.kind, r.reason))
          skipped = skipped + 1
        end
      else
        table.insert(results, string.format("  M%-4d  %s  FAILED — %s",
          m.marker_idx, marker_kind(m.name) or "?", tostring(err)))
        skipped = skipped + 1
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Insert room tone at markers", -1)

  reaper.ClearConsole()
  reaper.ShowConsoleMsg(string.format(
    "Insert room tone at markers — %d inserted, %d skipped\n\n",
    inserted, skipped))
  for _, line in ipairs(results) do
    reaper.ShowConsoleMsg(line .. "\n")
  end
  reaper.ShowMessageBox(string.format(
    "Done.\n\nInserted: %d\nSkipped:  %d\n\nDetails in ReaScript console.",
    inserted, skipped), "Insert room tone at markers", 0)
end


main()
