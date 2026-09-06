--[[
@description jk_Crop and pad at markers — apply
@version 0.1
@author Jonathan Kawchuk
@about
  DESTRUCTIVE pass. For every project marker tagged HD / SH / SB / PBP /
  PBS / TL (and CH if PROCESS_CH = true), measure the existing silence
  around the marker, then crop to the target silence amount by shifting
  downstream items + markers.

  Direct D_POSITION writes are used (not Reaper's global ripple) so project
  markers move in lockstep with items. This mirrors the VF Advanced
  reposition pattern.

  Workflow:
    1. Run the preview script first; verify the report looks right.
    2. Run THIS script; confirm the dialog. It applies all changes in one
       Undo block (single Cmd-Z reverts everything).
    3. Spot-check the result.

  Companion: jk_Silence detect lib.lua (must sit beside this script)
]]--


-- ── Config (must match the preview script) ─────────────────

local THRESHOLD_DB   = -60.0
local SCAN_WINDOW_S  = 5.0
local PROCESS_CH     = false
local WRITE_CSV      = false
local UPDATE_LABELS  = true   -- rewrite marker name with new measured silence

local MARKER_KINDS = {
  { name = "HD",  target = 0.7,  mode = "apply", desc = "Header (pre-announcement)" },
  { name = "SH",  target = 2.5,  mode = "apply", desc = "Subheader (post-announcement)" },
  { name = "SB",  target = 0.9,  mode = "apply", desc = "Sentence break" },
  { name = "PBP", target = 1.7,  mode = "apply", desc = "Paragraph" },
  { name = "PBS", target = 1.7,  mode = "apply", desc = "Paragraph (alias)" },
  { name = "TL",  target = 3.5,  mode = "apply", desc = "Tail (end of region)" },
  { name = "CH",  target = 2.5,  mode = PROCESS_CH and "apply" or "skip",
    desc = PROCESS_CH and "Chapter (treated as SH)" or "Chapter (skipped — move manually)" },
  { name = "CHP", target = nil,  mode = "warn", desc = "Likely typo of CH" },
}


-- ── Load detection library ─────────────────────────────────

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return src:match("(.*/)") or src:match("(.*\\)") or "./"
end

local lib_path = script_dir() .. "jk_Silence detect lib.lua"
local lib_loader = loadfile(lib_path)
if not lib_loader then
  reaper.ShowMessageBox(
    "Could not find jk_Silence detect lib.lua next to this script.\n\n" ..
    "Expected at:\n" .. lib_path,
    "Missing dependency", 0)
  return
end
local silence = lib_loader()


-- ── Marker-name parsing ─────────────────────────────────────

local function parse_marker(name)
  if not name or name == "" then return nil end
  for _, k in ipairs(MARKER_KINDS) do
    local kname = k.name
    local guarded = " " .. name:lower()
    if guarded:find("[^%w]" .. kname:lower() .. ":") then
      local secs = name:match(kname .. ":%s*'?%s*([%d%.]+)")
                or name:match(kname:lower() .. ":%s*'?%s*([%d%.]+)")
      return k, secs and tonumber(secs) or nil
    end
  end
  return nil
end


-- ── Marker label rewriting ─────────────────────────────────

-- Replace the "X seconds" portion of the marker name with the new measured
-- silence amount. Falls back to appending if no match.
local function rewrite_label(name, kind_name, new_secs)
  local pattern = "(" .. kind_name .. ":%s*'?%s*)[%d%.]+(%s*'?%s*seconds?)"
  local result, n = name:gsub(pattern, "%1" .. string.format("%.2f", new_secs) .. "%2")
  if n == 0 then
    -- Try lowercase
    pattern = "(" .. kind_name:lower() .. ":%s*'?%s*)[%d%.]+(%s*'?%s*seconds?)"
    result, n = name:gsub(pattern, "%1" .. string.format("%.2f", new_secs) .. "%2")
  end
  if n == 0 then
    return name .. string.format(" [→ %.2fs]", new_secs)
  end
  return result
end


-- ── Snapshot helpers ──────────────────────────────────────

-- Collect all relevant markers in left-to-right order.
local function collect_apply_markers()
  local rows = {}
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, pos, _, name, idx = reaper.EnumProjectMarkers(i)
    if not isrgn then
      local kind = parse_marker(name)
      if kind and kind.mode == "apply" and kind.target then
        table.insert(rows, {
          marker_idx = idx,
          enum_index = i,
          orig_pos = pos,
          name = name,
          kind = kind,
        })
      end
    end
  end
  table.sort(rows, function(a, b) return a.orig_pos < b.orig_pos end)
  return rows
end


-- ── Shift functions (direct D_POSITION writes; ripple-safe) ─

-- Shift every item whose current position is strictly greater than `pivot`
-- by `delta` seconds. Used after we've cropped silence at `pivot`.
local function shift_items_after(pivot, delta)
  if delta == 0 then return end
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      if pos > pivot + 1e-6 then
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + delta)
        reaper.UpdateItemInProject(item)
      end
    end
  end
end


-- Shift every project marker / region whose position is strictly greater
-- than `pivot` by `delta` seconds. The marker AT `pivot` is NOT moved here.
-- Regions get both endpoints shifted.
local function shift_markers_after(pivot, delta, exclude_idx)
  if delta == 0 then return end
  local n = reaper.CountProjectMarkers(0)
  -- Build a snapshot first to avoid index instability while editing
  local snap = {}
  for i = 0, n - 1 do
    local _, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    table.insert(snap, {
      isrgn = isrgn, pos = pos, rgnend = rgnend, name = name,
      idx = idx, color = color,
    })
  end
  for _, m in ipairs(snap) do
    if m.idx ~= exclude_idx and m.pos > pivot + 1e-6 then
      local new_pos = m.pos + delta
      local new_end = m.isrgn and (m.rgnend + delta) or m.rgnend
      reaper.SetProjectMarker3(0, m.idx, m.isrgn, new_pos, new_end, m.name, m.color)
    elseif m.isrgn and m.idx ~= exclude_idx
        and m.pos <= pivot + 1e-6 and m.rgnend > pivot + 1e-6 then
      -- Region that STRADDLES the pivot: extend its end with delta
      reaper.SetProjectMarker3(0, m.idx, true, m.pos, m.rgnend + delta, m.name, m.color)
    end
  end
end


-- Move a single marker to a new position, optionally renaming.
local function move_marker(mk_idx, new_pos, new_name, color)
  reaper.SetProjectMarker3(0, mk_idx, false, new_pos, 0, new_name, color or 0)
end


-- ── Apply pass ─────────────────────────────────────────────

local function apply()
  local rows = collect_apply_markers()
  if #rows == 0 then
    reaper.ShowMessageBox(
      "No apply-mode markers found. Nothing to do.\n\n" ..
      "Run the preview script to see what was detected.",
      "Crop and pad — apply", 0)
    return
  end

  -- Confirmation
  local prompt = string.format(
    "About to crop and pad %d markers.\n" ..
    "Threshold: %.1f dB\n" ..
    "Update marker labels: %s\n\n" ..
    "All changes are in a single Undo block (Cmd-Z reverts).\n\n" ..
    "Proceed?",
    #rows, THRESHOLD_DB, UPDATE_LABELS and "yes" or "no"
  )
  local answer = reaper.ShowMessageBox(prompt, "Crop and pad — apply", 1)  -- OK/Cancel
  if answer ~= 1 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local processed, skipped = 0, 0
  local applied_rows = {}

  for _, r in ipairs(rows) do
    -- The marker may have moved due to upstream shifts, so re-fetch its
    -- current position from Reaper rather than using orig_pos.
    local _, _, current_pos = reaper.EnumProjectMarkers(r.enum_index)
    -- Actually safer: look up by idx
    -- (enum_index is also subject to drift if regions/markers were added)
    -- Walk all markers and find the one with matching idx:
    local cur_pos, cur_name, cur_color = nil, nil, 0
    local n = reaper.CountProjectMarkers(0)
    for i = 0, n - 1 do
      local _, isrgn, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
      if not isrgn and idx == r.marker_idx then
        cur_pos, cur_name, cur_color = pos, name, color
        break
      end
    end
    if not cur_pos then
      skipped = skipped + 1
    else
      local m = silence.measure_silence_at(cur_pos, THRESHOLD_DB, SCAN_WINDOW_S)
      local current_dur = m.silence_end - m.silence_start
      local target = r.kind.target
      local delta = target - current_dur

      if math.abs(delta) < 0.005 then
        -- Already correct within 5ms; just relabel
        if UPDATE_LABELS then
          local new_name = rewrite_label(cur_name, r.kind.name, current_dur)
          move_marker(r.marker_idx, cur_pos, new_name, cur_color)
        end
        table.insert(applied_rows, {
          idx = r.marker_idx, kind = r.kind.name,
          pos = cur_pos, before = current_dur, after = current_dur, delta = 0,
        })
      else
        -- Shift everything strictly after silence_end by delta
        shift_items_after(m.silence_end, delta)
        shift_markers_after(m.silence_end, delta, r.marker_idx)

        -- Move this marker to the start of the new silence span
        local final_pos = m.silence_start
        local new_name = UPDATE_LABELS
          and rewrite_label(cur_name, r.kind.name, target)
          or cur_name
        move_marker(r.marker_idx, final_pos, new_name, cur_color)

        table.insert(applied_rows, {
          idx = r.marker_idx, kind = r.kind.name,
          pos = final_pos, before = current_dur, after = target, delta = delta,
        })
      end
      processed = processed + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Crop and pad at markers", -1)

  -- Summary
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(string.format(
    "Crop and pad — applied %d markers (%d skipped)\n\n",
    processed, skipped
  ))
  for _, a in ipairs(applied_rows) do
    reaper.ShowConsoleMsg(string.format(
      "M%-4d  %-3s  pos=%9.3fs  %5.2fs → %5.2fs  (Δ=%+5.2fs)\n",
      a.idx, a.kind, a.pos, a.before, a.after, a.delta
    ))
  end

  -- Optional CSV
  if WRITE_CSV then
    local proj_path = reaper.GetProjectPath("")
    local csv_path = proj_path .. "/edit_markers_applied.csv"
    local f = io.open(csv_path, "w")
    if f then
      f:write("marker_idx,kind,pos_seconds,before_secs,after_secs,delta_secs\n")
      for _, a in ipairs(applied_rows) do
        f:write(string.format("%d,%s,%.6f,%.6f,%.6f,%.6f\n",
          a.idx, a.kind, a.pos, a.before, a.after, a.delta))
      end
      f:close()
      reaper.ShowConsoleMsg("\nCSV: " .. csv_path .. "\n")
    end
  end

  reaper.ShowMessageBox(
    string.format(
      "Done.\n\n" ..
      "Applied:  %d\n" ..
      "Skipped:  %d\n\n" ..
      "Full table in the ReaScript console.\n" ..
      "Single Cmd-Z reverts everything.",
      processed, skipped
    ),
    "Crop and pad — apply", 0)
end


apply()
