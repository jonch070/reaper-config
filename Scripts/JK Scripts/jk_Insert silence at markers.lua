--[[
@description jk_Insert silence at markers
@version 0.2
@author Jonathan Kawchuk
@about
  For every project marker tagged HD / SH / SB / PBP / PBS / TL (and CH if
  PROCESS_CH is true), insert silence at the marker position by shifting
  downstream items + markers, with optional placement of a media item
  inside the gap.

  SILENCE_MODE controls what fills the gap:
    "shift"   — open a silent timeline gap. No item created. Default.
    "empty"   — insert an empty Reaper item filling the entire gap.
    "rt_file" — insert a clean-silence / room-tone file from the configured
                folder, sized as close to target as possible. Any leftover
                gap (target − clip length) sits as empty timeline.

  Use AFTER:
    1. Place markers (HD/TL via the placer; PBP/SB/SH/CH manually or via QC)
    2. "Item: Split items at project markers" (Reaper command 40931)
    3. ek_Edge silence cropper to remove silent edges
    4. Reposition items with global ripple to close all gaps
    Wrap 2–4 as one Reaper custom action.

  Direct D_POSITION writes — markers shift with items.
@changelog
  0.2 — Added SILENCE_MODE: "shift" | "empty" | "rt_file". rt_file picks
        clips from a configured room-tone folder by matching length.
  0.1 — Initial; shift only.
]]--


-- ── Config ──────────────────────────────────────────────────

local SILENCE_MODE   = "rt_file"  -- "shift" | "empty" | "rt_file"
local ROOM_TONE_DIR  = "/Users/jonathankawchuk/Documents/Projects/Audiobook Editing/Spotify/Current Audiobook Project/room_tone"
local PROCESS_CH     = false      -- skip CH markers; move them to SH manually first
local UPDATE_LABELS  = true       -- rewrite marker label with the new silence amount


local MARKER_KINDS = {
  { name = "HD",  target = 0.5,  mode = "apply", desc = "Header" },
  { name = "SH",  target = 2.5,  mode = "apply", desc = "Subheader" },
  { name = "SB",  target = 0.9,  mode = "apply", desc = "Sentence break" },
  { name = "PBP", target = 1.7,  mode = "apply", desc = "Paragraph" },
  { name = "PBS", target = 1.7,  mode = "apply", desc = "Paragraph (alias)" },
  { name = "TL",  target = 3.5,  mode = "apply", desc = "Tail" },
  { name = "CH",  target = 2.5,  mode = PROCESS_CH and "apply" or "skip",
    desc = PROCESS_CH and "Chapter (treated as SH)" or "Chapter (skipped)" },
  { name = "CHP", target = nil,  mode = "skip", desc = "CHP — flagged elsewhere" },
}


-- ── Marker name parsing ─────────────────────────────────────

local function parse_marker(name)
  if not name or name == "" then return nil end
  for _, k in ipairs(MARKER_KINDS) do
    local kname = k.name
    local guarded = " " .. name:lower()
    if guarded:find("[^%w]" .. kname:lower() .. ":") then
      return k
    end
  end
  return nil
end


local function rewrite_label(name, kind_name, new_secs)
  local pattern = "(" .. kind_name .. ":%s*'?%s*)[%d%.]+(%s*'?%s*seconds?)"
  local result, n = name:gsub(pattern, "%1" .. string.format("%.2f", new_secs) .. "%2")
  if n == 0 then
    pattern = "(" .. kind_name:lower() .. ":%s*'?%s*)[%d%.]+(%s*'?%s*seconds?)"
    result, n = name:gsub(pattern, "%1" .. string.format("%.2f", new_secs) .. "%2")
  end
  if n == 0 then return name .. string.format(" [%.2fs]", new_secs) end
  return result
end


-- ── Room-tone clip catalog ─────────────────────────────────

local rt_catalog = nil  -- { {path=..., length=...}, ... } sorted by length

local function build_rt_catalog()
  local catalog = {}
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(ROOM_TONE_DIR, i)
    if not fname then break end
    i = i + 1
    local lower = fname:lower()
    if lower:match("%.mp3$") or lower:match("%.wav$")
        or lower:match("%.aiff?$") or lower:match("%.flac$") then
      local full = ROOM_TONE_DIR .. "/" .. fname
      local source = reaper.PCM_Source_CreateFromFile(full)
      if source then
        local length = reaper.GetMediaSourceLength(source)
        reaper.PCM_Source_Destroy(source)
        if length and length > 0 then
          table.insert(catalog, { path = full, name = fname, length = length })
        end
      end
    end
  end
  table.sort(catalog, function(a, b) return a.length < b.length end)
  return catalog
end


-- Pick the catalog entry with length ≤ target and closest to target.
-- If everything is longer than target, returns the shortest one anyway
-- (caller can still use it; gap will overshoot, downstream shift will
-- close to exact).
local function pick_rt_clip(target)
  if not rt_catalog or #rt_catalog == 0 then return nil end
  local best = rt_catalog[1]
  for _, c in ipairs(rt_catalog) do
    if c.length <= target + 0.05 and c.length > best.length then
      best = c
    end
  end
  return best
end


-- ── Track resolution ───────────────────────────────────────

-- Find a track that has an item adjacent (just before or just after) the
-- marker position. Used as the destination for inserted clips/empty items.
local function track_at_pos(pos)
  local n_tracks = reaper.CountTracks(0)
  local closest_track, closest_dist = nil, math.huge
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local p = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local end_pos = p + len
      local d = math.min(math.abs(p - pos), math.abs(end_pos - pos))
      if d < closest_dist then
        closest_dist = d
        closest_track = track
      end
    end
  end
  if closest_track then return closest_track end
  if n_tracks > 0 then return reaper.GetTrack(0, 0) end
  return nil
end


-- ── Item creation helpers ──────────────────────────────────

local function insert_empty_item(track, position, length)
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.0)
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.0)
  reaper.UpdateItemInProject(item)
  return item
end


local function insert_audio_clip(track, position, file_path, name)
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  local source = reaper.PCM_Source_CreateFromFile(file_path)
  if source then
    reaper.SetMediaItemTake_Source(take, source)
  end
  if name then
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
  end
  local len = source and reaper.GetMediaSourceLength(source) or 0
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", len)
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.0)
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.0)
  reaper.UpdateItemInProject(item)
  return item, len
end


-- ── Snapshot apply markers (right to left) ─────────────────

local function collect_apply_markers()
  local rows = {}
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if not isrgn then
      local kind = parse_marker(name)
      if kind and kind.mode == "apply" and kind.target then
        table.insert(rows, {
          marker_idx = idx,
          orig_pos = pos,
          name = name,
          color = color,
          kind = kind,
        })
      end
    end
  end
  table.sort(rows, function(a, b) return a.orig_pos > b.orig_pos end)
  return rows
end


-- ── Shift functions ────────────────────────────────────────

local function shift_items_at_or_after(pivot, delta)
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


local function shift_markers_after(pivot, delta, exclude_idx)
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
    if m.idx ~= exclude_idx then
      if m.pos > pivot + 1e-6 then
        local new_pos = m.pos + delta
        local new_end = m.isrgn and (m.rgnend + delta) or m.rgnend
        reaper.SetProjectMarker3(0, m.idx, m.isrgn, new_pos, new_end, m.name, m.color)
      elseif m.isrgn and m.pos <= pivot + 1e-6 and m.rgnend > pivot + 1e-6 then
        reaper.SetProjectMarker3(0, m.idx, true, m.pos, m.rgnend + delta, m.name, m.color)
      end
    end
  end
end


-- ── Main ────────────────────────────────────────────────────

function main()
  -- Validate config
  if SILENCE_MODE ~= "shift" and SILENCE_MODE ~= "empty" and SILENCE_MODE ~= "rt_file" then
    reaper.ShowMessageBox(
      "Bad SILENCE_MODE: " .. tostring(SILENCE_MODE) ..
      "\nUse 'shift', 'empty', or 'rt_file'.",
      "Insert silence at markers", 0)
    return
  end

  local rows = collect_apply_markers()
  if #rows == 0 then
    reaper.ShowMessageBox("No apply-mode markers found.",
      "Insert silence at markers", 0)
    return
  end

  -- Build room-tone catalog if needed
  if SILENCE_MODE == "rt_file" then
    rt_catalog = build_rt_catalog()
    if #rt_catalog == 0 then
      reaper.ShowMessageBox(
        "No room-tone clips found in:\n" .. ROOM_TONE_DIR ..
        "\n\nFalling back to 'shift' mode.",
        "Insert silence at markers", 0)
      SILENCE_MODE = "shift"
    end
  end

  -- Build summary
  local kind_counts = {}
  local total_to_insert = 0
  for _, r in ipairs(rows) do
    kind_counts[r.kind.name] = (kind_counts[r.kind.name] or 0) + 1
    total_to_insert = total_to_insert + r.kind.target
  end

  local prompt_lines = {
    string.format("Mode: %s", SILENCE_MODE:upper()),
    string.format("Markers: %d", #rows),
    "",
  }
  for _, k in ipairs(MARKER_KINDS) do
    local n = kind_counts[k.name] or 0
    if n > 0 and k.target then
      table.insert(prompt_lines, string.format("  %s ×%d → %.2fs each", k.name, n, k.target))
    end
  end
  if SILENCE_MODE == "rt_file" then
    table.insert(prompt_lines, "")
    table.insert(prompt_lines, string.format("Room-tone clips: %d", #rt_catalog))
    for _, c in ipairs(rt_catalog) do
      table.insert(prompt_lines, string.format("  %s (%.2fs)", c.name, c.length))
    end
  end
  table.insert(prompt_lines, string.format("\nTotal added: %.2fs", total_to_insert))
  table.insert(prompt_lines, "\nProceed?")

  local answer = reaper.ShowMessageBox(table.concat(prompt_lines, "\n"),
    "Insert silence at markers", 1)
  if answer ~= 1 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local processed = 0
  for _, r in ipairs(rows) do
    -- Re-fetch current marker position
    local cur_pos, cur_name, cur_color = nil, nil, 0
    local n = reaper.CountProjectMarkers(0)
    for i = 0, n - 1 do
      local _, isrgn, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
      if not isrgn and idx == r.marker_idx then
        cur_pos, cur_name, cur_color = pos, name, color
        break
      end
    end
    if cur_pos then
      local target = r.kind.target
      shift_items_at_or_after(cur_pos, target)
      shift_markers_after(cur_pos, target, r.marker_idx)

      if SILENCE_MODE == "empty" then
        local track = track_at_pos(cur_pos)
        if track then insert_empty_item(track, cur_pos, target) end
      elseif SILENCE_MODE == "rt_file" then
        local clip = pick_rt_clip(target)
        if clip then
          local track = track_at_pos(cur_pos)
          if track then insert_audio_clip(track, cur_pos, clip.path, clip.name) end
        end
      end

      if UPDATE_LABELS then
        local new_name = rewrite_label(cur_name, r.kind.name, target)
        reaper.SetProjectMarker3(0, r.marker_idx, false, cur_pos, 0, new_name, cur_color)
      end
      processed = processed + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Insert silence at markers (" .. SILENCE_MODE .. ")", -1)

  reaper.ShowMessageBox(
    string.format(
      "Done. %d markers processed.\n\n" ..
      "Mode: %s\n\n" ..
      "Single Cmd-Z reverts everything.",
      processed, SILENCE_MODE:upper()
    ),
    "Insert silence at markers", 0)
end


main()
