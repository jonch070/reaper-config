--[[
@description jk_Crop and pad at markers — preview
@version 0.2
@author Jonathan Kawchuk
@about
  READ-ONLY preview pass. For every project marker whose name carries an
  edit-tag (HD, SH, SB, PBP, PBS, TL, CH), it parses the named silence,
  measures the actual silence around the marker, and reports per-tag stats
  + anomalies. No edits.

  Tag dispatch (target silence per kind):
    HD  = 0.7s   header (pre-announcement silence)
    SH  = 2.5s   subheader (post-announcement silence)
    SB  = 0.9s   sentence break
    PBP = 1.7s   paragraph
    PBS = 1.7s   paragraph (same as PBP — treat as typo-tolerant alias)
    TL  = 3.5s   tail (end of region)
    CH  = skip   informational only (Pozotron places these AT the chapter
                 announcement word, not in silence; future stage may use
                 these as hints to auto-place HD + SH markers)
    CHP = warn   probably a typo of CH

  Companion library: jk_Silence detect lib.lua  (must sit beside this script)
@changelog
  0.2 — Multi-kind dispatch (HD/SH/SB/PBP/PBS/TL/CH/CHP). Per-kind targets.
        Per-kind anomaly rules. CSV writer covers all kinds.
  0.1 — Initial PBP/PBS-only preview.
]]--


-- ── Config ──────────────────────────────────────────────────

local THRESHOLD_DB   = -60.0
local SCAN_WINDOW_S  = 5.0     -- max seconds to walk outward from a marker
local WRITE_CSV      = false   -- toggle to also write CSV next to project file
local PROCESS_CH     = false   -- false = skip CH markers (you'll move them to
                               --         become SH manually). true = treat
                               --         as same as SH (target 2.5s).

-- Tag matching is case-insensitive everywhere (CH, ch, Ch all work).
-- Marker-kind dispatch. Add/edit rows here. mode = "apply" | "skip" | "warn"
local MARKER_KINDS = {
  { name = "HD",  target = 0.5,  mode = "apply", desc = "Header (pre-announcement)" },
  { name = "SH",  target = 2.5,  mode = "apply", desc = "Subheader (post-announcement)" },
  { name = "SB",  target = 0.9,  mode = "apply", desc = "Sentence break" },
  { name = "PBP", target = 1.7,  mode = "apply", desc = "Paragraph" },
  { name = "PBS", target = 1.7,  mode = "apply", desc = "Paragraph (alias)" },
  { name = "TL",  target = 3.5,  mode = "apply", desc = "Tail (end of region)" },
  -- CH dispatch is set dynamically below from PROCESS_CH:
  { name = "CH",  target = 2.5,  mode = PROCESS_CH and "apply" or "skip",
    desc = PROCESS_CH and "Chapter (treated as SH)" or "Chapter (skipped — move manually)" },
  { name = "CHP", target = nil,  mode = "warn", desc = "Likely typo of CH" },
}


-- ── Load detection library from the same folder ────────────

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

-- Build a kind index keyed uppercase
local KIND_INDEX = {}
for _, k in ipairs(MARKER_KINDS) do
  KIND_INDEX[k.name:upper()] = k
end

-- Returns (kind_record, named_secs) if the name has any known tag, else nil.
local function parse_marker(name)
  if not name or name == "" then return nil end
  -- Try each known kind; return first match. Tags must be followed by ":" so
  -- we don't accidentally match substrings inside chapter titles, etc.
  for _, k in ipairs(MARKER_KINDS) do
    local kname = k.name
    -- Patterns: "TAG:" or "TAG :" with optional whitespace, case-insensitive.
    local pat = "[^%w](" .. kname:lower() .. "):"
    local guarded = " " .. name:lower()
    if guarded:find(pat) then
      -- Try to extract the named silence: "X" or "X.Y"
      local secs = name:match(kname .. ":%s*'?%s*([%d%.]+)")
                or name:match(kname:lower() .. ":%s*'?%s*([%d%.]+)")
      return k, secs and tonumber(secs) or nil
    end
  end
  return nil
end


-- ── Report build + format ──────────────────────────────────

local function build_report()
  local rows = {}
  local total_markers = reaper.CountProjectMarkers(0)
  for i = 0, total_markers - 1 do
    local _, isrgn, pos, _, name, idx = reaper.EnumProjectMarkers(i)
    if not isrgn then
      local kind, named_secs = parse_marker(name)
      if kind then
        local row = {
          marker_idx = idx,
          pos = pos,
          name = name,
          kind = kind.name,
          mode = kind.mode,
          named_secs = named_secs,
          target_secs = kind.target,
        }
        if kind.mode == "apply" then
          local m = silence.measure_silence_at(pos, THRESHOLD_DB, SCAN_WINDOW_S)
          row.measured_secs = m.duration
          row.silence_start = m.silence_start
          row.silence_end = m.silence_end
          row.delta_vs_target = (kind.target or 0) - m.duration
        else
          row.measured_secs = nil
          row.delta_vs_target = nil
        end
        table.insert(rows, row)
      end
    end
  end
  return rows
end


local function format_row(r)
  if r.mode ~= "apply" then
    return string.format(
      "M%-4d  %-3s  pos=%9.3fs  [%s] %s",
      r.marker_idx, r.kind, r.pos, r.mode, r.name
    )
  end
  return string.format(
    "M%-4d  %-3s  pos=%9.3fs  named=%5.2fs  measured=%5.2fs  target=%4.2fs  Δ=%+5.2fs",
    r.marker_idx, r.kind, r.pos,
    r.named_secs or 0, r.measured_secs or 0,
    r.target_secs or 0, r.delta_vs_target or 0
  )
end


local function detect_anomalies(rows)
  local notes = {}

  -- 1. CHP markers (warn)
  for _, r in ipairs(rows) do
    if r.kind == "CHP" then
      table.insert(notes, string.format(
        "  ⚠ M%d: 'CHP' tag at %.2fs is likely a typo of CH",
        r.marker_idx, r.pos
      ))
    end
  end

  -- 2. Big mismatch between named and measured (apply-mode only)
  for _, r in ipairs(rows) do
    if r.mode == "apply" and r.named_secs and r.measured_secs then
      if math.abs(r.named_secs - r.measured_secs) > 0.5 then
        table.insert(notes, string.format(
          "  ⚠ M%d (%s): named %.2fs vs measured %.2fs (diff > 0.5s)",
          r.marker_idx, r.kind, r.named_secs, r.measured_secs
        ))
      end
    end
  end

  -- 3. Two markers within 1s of each other (likely accidental duplicate)
  local prev = nil
  for _, r in ipairs(rows) do
    if prev and math.abs(r.pos - prev.pos) < 1.0 then
      table.insert(notes, string.format(
        "  ⚠ M%d (%s) within 1s of M%d (%s) — possible duplicate",
        r.marker_idx, r.kind, prev.marker_idx, prev.kind
      ))
    end
    prev = r
  end

  return notes
end


-- ── CSV ─────────────────────────────────────────────────────

local function write_csv(rows, path)
  local f, err = io.open(path, "w")
  if not f then return false, err end
  f:write("marker_idx,kind,mode,pos_seconds,name,named_secs,measured_secs,target_secs,delta_vs_target\n")
  for _, r in ipairs(rows) do
    local name_q = '"' .. r.name:gsub('"', '""') .. '"'
    f:write(string.format(
      "%d,%s,%s,%.6f,%s,%s,%s,%s,%s\n",
      r.marker_idx, r.kind, r.mode, r.pos, name_q,
      r.named_secs    and string.format("%.6f", r.named_secs)    or "",
      r.measured_secs and string.format("%.6f", r.measured_secs) or "",
      r.target_secs   and string.format("%.2f",   r.target_secs)  or "",
      r.delta_vs_target and string.format("%.6f", r.delta_vs_target) or ""
    ))
  end
  f:close()
  return true
end


-- ── Main ────────────────────────────────────────────────────

function main()
  local rows = build_report()
  if #rows == 0 then
    reaper.ShowMessageBox(
      "No markers with recognized tags were found.\n\n" ..
      "Looking for: HD: SH: SB: PBP: PBS: TL: CH: CHP:\n" ..
      "(case-insensitive). Marker names like\n" ..
      "  editing #22 | PBP: 2.5 seconds",
      "Crop and pad — preview", 0)
    return
  end

  -- Per-kind counts
  local counts = {}
  for _, r in ipairs(rows) do
    counts[r.kind] = (counts[r.kind] or 0) + 1
  end

  -- Console output
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(string.format(
    "Crop-and-pad marker preview\n" ..
    "  threshold:    %.1f dB\n" ..
    "  scan window:  ±%.1f s\n" ..
    "  total found:  %d markers\n",
    THRESHOLD_DB, SCAN_WINDOW_S, #rows
  ))
  reaper.ShowConsoleMsg("\nKinds:\n")
  for _, k in ipairs(MARKER_KINDS) do
    local n = counts[k.name] or 0
    if n > 0 then
      local target_str = k.target and string.format("%.2fs", k.target) or "—"
      reaper.ShowConsoleMsg(string.format(
        "  %-3s  ×%-3d  target=%-6s  [%s]  %s\n",
        k.name, n, target_str, k.mode, k.desc
      ))
    end
  end
  reaper.ShowConsoleMsg("\n")
  for _, r in ipairs(rows) do
    reaper.ShowConsoleMsg(format_row(r) .. "\n")
  end

  local anomalies = detect_anomalies(rows)
  if #anomalies > 0 then
    reaper.ShowConsoleMsg("\nAnomalies:\n")
    for _, n in ipairs(anomalies) do
      reaper.ShowConsoleMsg(n .. "\n")
    end
  end

  -- Optional CSV
  local csv_msg = ""
  if WRITE_CSV then
    local proj_path = reaper.GetProjectPath("")
    local csv_path = proj_path .. "/edit_markers_preview.csv"
    local ok, err = write_csv(rows, csv_path)
    if ok then
      csv_msg = "\n\nCSV written: " .. csv_path
      reaper.ShowConsoleMsg("\nCSV: " .. csv_path .. "\n")
    else
      csv_msg = "\n\nCSV write FAILED: " .. tostring(err)
    end
  end

  -- Summary dialog
  local lines = { string.format("Found %d markers.\n", #rows) }
  for _, k in ipairs(MARKER_KINDS) do
    local n = counts[k.name] or 0
    if n > 0 then
      local target_str = k.target and string.format(" → %.2fs", k.target) or " (skip)"
      table.insert(lines, string.format("  %s ×%d%s", k.name, n, target_str))
    end
  end
  table.insert(lines, string.format("\nThreshold: %.1f dB", THRESHOLD_DB))
  table.insert(lines, string.format("Anomalies: %d", #anomalies))
  table.insert(lines, "\nFull table in the ReaScript console." .. csv_msg)

  reaper.ShowMessageBox(table.concat(lines, "\n"), "Crop and pad — preview", 0)
end


main()
