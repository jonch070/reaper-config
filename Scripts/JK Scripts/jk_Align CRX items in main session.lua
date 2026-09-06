--[[
@description jk_Align CRX items in main session
  @version 1.0
  @author Jonathan Kawchuk
@about
  Run in the main session after manually placing CRX items near their
  narrator markers. Selects the placed items, finds each one's
  corrected_word in the whisper TSV, and sets D_SNAPOFFSET so the
  word aligns to the marker position.
  
  After running, use REAPER's built-in action:
    "Align selected items to markers inside time selection"
  to snap each item perfectly to its marker.
  
  Works with pickups CSV + whisper TSV from the pipeline.
  
  Derives paths from the project folder convention:
    <project>/
      pipeline.config.yaml
      transcriptions/
        qc report/           ← pickups CSV lives here (<narrator>_pickups.csv)
        narrator1 pickups/   ← whisper .tsv lives here or next to CRX source
        narrator2 pickups/

  Steps before running:
    1. In the main session, place CRX items roughly near their markers
       (split the CRX audio at silence boundaries like you would in the
       CRX session, one item per pickup, then drag them close to markers)
    2. Generate the pipeline data:
       ./bin/run python3 -m pipeline.whisper extract <crx>.whisper
       ./bin/run python3 -m pipeline.qc_pickups extract \
           --qc "<...>_QC Report.xlsx" \
           --narrator narrator1 \
           --output "transcriptions/qc report/narrator1_pickups.csv"
    3. Select the CRX items, run this script
    4. Select all items + their markers, run "Align items to markers"

@changelog
  1.0 — Main-session variant of jk_Set CRX snap offset.
         Same logic: smart pickup matching, item cursor, gap skipping.
  0.8 — Smart pickup matching: scan remaining pickups to find the one whose
         word lives in each item's source window. Unrecorded pickups (gaps)
         are skipped automatically instead of causing misalignment.
  0.7 — EXACT-only matching. Only set offset when word is in the item's source window.
        FAIL items show diagnostic info (where the word exists globally and gap from window).
        No silent wrong offsets from global/context fallback.
  0.6 — Quality-gated matching: EXACT (in-window) / APPROX (global) / FAIL.
        Drops risky context-word matching to avoid silent wrong offsets.
        Clearer console output with quality column and verification warnings.
  0.5 — Sort items by source offset (D_STARTOFFS) instead of timeline position (D_POSITION).
        Fixes mispairing when items are repositioned on the timeline.
  0.4 — Added fallback search chain: corrected_word in window → said_word → context words → global variants.
  0.3 — Auto-detect project root and pickups CSV from RPP path.
        Removed manual mode and path prompts.
  0.2 — Added auto-mode (driven by pickups CSV from QC report).
  0.1 — Initial.
]]--


-- ── Config ──────────────────────────────────────────────────

local CASE_INSENSITIVE  = true

-- Failure handling: items where the corrected_word couldn't be located get
-- flagged so you can spot them and fix manually.
local FLAG_FAILURES_COLOR   = true   -- tint failed items red
local FLAG_FAILURES_MARKER  = true   -- drop a "FAIL: <word>" marker


-- ── State (cached for the run) ──────────────────────────────

local cached_tsv_words = nil
local cached_tsv_path  = nil
local cached_pickups   = nil
local cached_pickups_path = nil
local cached_project   = nil


-- ── Helpers ────────────────────────────────────────────────

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

local function normalize_word(s)
  if not s then return "" end
  s = trim(s)
  s = s:gsub("[^%w']", "")
  if CASE_INSENSITIVE then s = s:lower() end
  return s
end


-- ── Project root detection ─────────────────────────────────

-- Conventions checked in order:
--   1. The RPP is at <project>/reaper projects/<file>.rpp
--   2. The RPP is at <project>/<anything>.rpp (project root = parent)

local function detect_project_root()
  local rpp = reaper.EnumProjects(-1, "")
  if not rpp then return nil end
  local rpp_path = reaper.GetProjectPath(0)  -- ,, get the project file path?
  
  -- Try via GetProjectPathEx
  local _, rpp_full = reaper.EnumProjects(0, "")
  if not rpp_full or rpp_full == "" then
    -- Fallback: use the project path
    rpp_full = reaper.GetProjectPath(0) .. "/"
  end
  
  local dir = dirname(rpp_full)
  
  -- Check: <dir>/reaper projects/ → project root = dir
  local parent = dirname(dir:sub(1, -2))
  if basename(dir:sub(1, -2)):lower() == "reaper projects" then
    return parent
  end
  
  -- Check: <dir>/pipeline.config.yaml exists → project root = dir
  if io.open(dir .. "pipeline.config.yaml", "r") then
    io.open(dir .. "pipeline.config.yaml", "r"):close()
    return dir
  end
  
  return dir  -- best guess
end


-- ── Pickups CSV auto-discovery ──────────────────────────────

-- Looks for any _pickups.csv in:
--   <project>/transcriptions/qc report/
--   <project>/transcriptions/

local function find_pickups_csv(project_root)
  local candidates = {
    project_root .. "transcriptions/qc report/",
    project_root .. "transcriptions/",
  }
  for _, dir in ipairs(candidates) do
    local i = 0
    while true do
      local n = reaper.EnumerateFiles(dir, i)
      if not n then break end
      i = i + 1
      if n:match("_pickups%.csv$") then
        return dir .. n
      end
    end
  end
  -- Also check the project root itself
  local i = 0
  while true do
    local n = reaper.EnumerateFiles(project_root, i)
    if not n then break end
    i = i + 1
    if n:match("_pickups%.csv$") then
      return project_root .. n
    end
  end
  return nil
end


-- ── TSV loading (whisper words) ────────────────────────────

local function load_tsv(path)
  local f = io.open(path, "r")
  if not f then return nil, "cannot open: " .. path end
  local words = {}
  for line in f:lines() do
    if line:sub(1, 1) ~= "#" and line ~= "" then
      local time_str, text = line:match("^([%d%.]+)%s*\t(.*)$")
      if time_str and text then
        table.insert(words, { time = tonumber(time_str), text = text })
      end
    end
  end
  f:close()
  return words
end


local function find_tsv_for_item(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil end
  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil end
  local fname = reaper.GetMediaSourceFileName(source)
  if not fname or fname == "" then return nil end
  local dir = dirname(fname)
  local stem = (basename(fname):gsub("%.[^.]+$", ""))
  local candidates = {
    dir .. stem .. ".tsv",
    dir .. stem:gsub("_PICKUPS$", "") .. ".tsv",
    dir .. stem:gsub("_pickups$", "") .. ".tsv",
  }
  for _, c in ipairs(candidates) do
    local f = io.open(c, "r"); if f then f:close(); return c end
  end
  -- Fallback: first .tsv in the dir
  local trimmed = dir:sub(1, -2)
  local i = 0
  while true do
    local n = reaper.EnumerateFiles(trimmed, i)
    if not n then break end
    i = i + 1
    if n:match("%.tsv$") then return dir .. n end
  end
  return nil
end


-- ── CSV loading (pickups) ──────────────────────────────────

local function parse_csv_line(line)
  local fields = {}
  local i, n = 1, #line
  while i <= n do
    local field = ""
    if line:sub(i, i) == '"' then
      i = i + 1
      while i <= n do
        local c = line:sub(i, i)
        if c == '"' then
          if line:sub(i + 1, i + 1) == '"' then
            field = field .. '"'; i = i + 2
          else
            i = i + 1; break
          end
        else
          field = field .. c; i = i + 1
        end
      end
    else
      while i <= n and line:sub(i, i) ~= "," do
        field = field .. line:sub(i, i); i = i + 1
      end
    end
    table.insert(fields, field)
    if i <= n and line:sub(i, i) == "," then i = i + 1 end
  end
  return fields
end


local function load_pickups_csv(path)
  local f = io.open(path, "r")
  if not f then return nil, "cannot open: " .. path end
  local header = nil
  local rows = {}
  for line in f:lines() do
    if line ~= "" then
      local fields = parse_csv_line(line)
      if not header then
        header = {}
        for i, h in ipairs(fields) do header[h] = i end
      else
        local r = {}
        for h, idx in pairs(header) do r[h] = fields[idx] or "" end
        table.insert(rows, r)
      end
    end
  end
  f:close()
  return rows
end


-- ── Word lookup ────────────────────────────────────────────

-- Find needle within a time window
local function find_all_matches(words, needle, win_start, win_end)
  if not words then return {} end
  local n = normalize_word(needle)
  if n == "" then return {} end
  local hits = {}
  for _, w in ipairs(words) do
    if w.time >= win_start - 0.001 and w.time <= win_end + 0.001 then
      if normalize_word(w.text) == n then
        table.insert(hits, w)
      end
    end
  end
  return hits
end

-- Find needle across the entire word list (no window)
local function find_all_matches_global(words, needle)
  if not words then return {} end
  local n = normalize_word(needle)
  if n == "" then return {} end
  local hits = {}
  for _, w in ipairs(words) do
    if normalize_word(w.text) == n then
      table.insert(hits, w)
    end
  end
  return hits
end

-- Pick the match closest to a target time
local function closest_match(hits, target)
  if #hits == 0 then return nil end
  local best, best_dist = hits[1], math.abs(hits[1].time - target)
  for i = 2, #hits do
    local d = math.abs(hits[i].time - target)
    if d < best_dist then best, best_dist = hits[i], d end
  end
  return best
end


-- ── Snap-offset application ────────────────────────────────

local function apply_offset(item, take, source_time)
  local soffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0
  local snap_offset_in_item = source_time - soffs
  if snap_offset_in_item < 0 then snap_offset_in_item = 0 end
  reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", snap_offset_in_item)
  reaper.UpdateItemInProject(item)
  return snap_offset_in_item
end


-- ── Failure flagging ───────────────────────────────────────

local function red_native()
  return reaper.ColorToNative(192, 32, 32) | 0x1000000
end

local function flag_item_fail(item, word, reason)
  if FLAG_FAILURES_COLOR then
    reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", red_native())
    reaper.UpdateItemInProject(item)
  end
  if FLAG_FAILURES_MARKER then
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local label = string.format("FAIL: %s — %s",
      tostring(word or ""), tostring(reason or ""))
    reaper.AddProjectMarker2(0, false, pos, 0, label, -1, red_native())
  end
end


-- ── Item helpers ───────────────────────────────────────────

local function item_window(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil, nil, nil end
  local soffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0
  local len   = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return take, soffs, soffs + len
end


local function selected_items_in_source_order()
  local list = {}
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    table.insert(list, reaper.GetSelectedMediaItem(0, i))
  end
  table.sort(list, function(a, b)
    local ta = reaper.GetActiveTake(a)
    local tb = reaper.GetActiveTake(b)
    local sa = ta and reaper.GetMediaItemTakeInfo_Value(ta, "D_STARTOFFS") or 0
    local sb = tb and reaper.GetMediaItemTakeInfo_Value(tb, "D_STARTOFFS") or 0
    return sa < sb
  end)
  return list
end


-- ── Input resolution ───────────────────────────────────────

local function resolve_inputs(first_item)
  -- 1. Detect project root (once)
  if not cached_project then
    local guess = detect_project_root()
    local ok, path = reaper.GetUserInputs(
      "Align CRX items — project folder", 1,
      "Project root (for pickups CSV lookup),extrawidth=500", guess or "")
    if not ok or path == "" then return false end
    cached_project = path:gsub("/$", "") .. "/"
  end

  -- 2. Find pickups CSV (once)
  if not cached_pickups then
    local auto = find_pickups_csv(cached_project)
    local prefill = auto or ""
    local ok, csv_path = reaper.GetUserInputs(
      "Pickups CSV (auto-detected below)", 1,
      "Path to <narrator>_pickups.csv,extrawidth=500", prefill)
    if not ok or csv_path == "" then return false end
    local rows, err = load_pickups_csv(csv_path)
    if not rows then
      reaper.ShowMessageBox(
        "Failed to load pickups CSV:\n" .. tostring(err) .. "\n\n" ..
        "Generate it from the pipeline:\n" ..
        "  ./bin/run python3 -m pipeline.qc_pickups extract \\\n" ..
        "    --qc \"<QC Report.xlsx>\" \\\n" ..
        "    --narrator narrator1 \\\n" ..
        "    --output \"<project>/transcriptions/qc report/narrator1_pickups.csv\"",
        "Auto-mode", 0)
      return false
    end
    cached_pickups = rows
    cached_pickups_path = csv_path
  end

  -- 3. Find whisper TSV (once)
  if not cached_tsv_words then
    local detected = find_tsv_for_item(first_item) or ""
    local ok, tsv_path = reaper.GetUserInputs(
      "Whisper TSV (auto-detected below)", 1,
      "Path to whisper TSV,extrawidth=500", detected)
    if not ok or tsv_path == "" then return false end
    local words, err = load_tsv(tsv_path)
    if not words then
      reaper.ShowMessageBox(
        "Failed to load whisper TSV:\n" .. tostring(err) .. "\n\n" ..
        "Generate it from the pipeline:\n" ..
        "  ./bin/run python3 -m pipeline.whisper extract <crx>.whisper",
        "Auto-mode", 0)
      return false
    end
    cached_tsv_words = words
    cached_tsv_path = tsv_path
  end
  return true
end


-- ── Main ───────────────────────────────────────────────────

local function main()
  local items = selected_items_in_source_order()
  if #items == 0 then
    reaper.ShowMessageBox("Select one or more CRX items first.",
    "Align CRX items", 0)
    return
  end

  if not resolve_inputs(items[1]) then return end

  -- Confirm pairing
  local n_items, n_pickups = #items, #cached_pickups
  local prompt = string.format(
    "Project:    %s\n" ..
    "Pickups:    %s  (%d rows)\n" ..
    "Whisper:    %s  (%d words)\n\n" ..
    "Items:      %d\n" ..
    "Pickups:    %d\n\n" ..
    "Smart matching: scans remaining pickups to find the one whose\n" ..
    "corrected/said word falls in each item's source window.\n" ..
    "Unmatched pickups (not recorded) are skipped automatically.\n\n" ..
    "Proceed?",
    cached_project,
    basename(cached_pickups_path), n_pickups,
    basename(cached_tsv_path), #cached_tsv_words,
    n_items, n_pickups)
    if reaper.ShowMessageBox(prompt, "Align CRX items confirmation", 1) ~= 1 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local results = {}
  local skipped = {}
  local pi = 1

  for ii = 1, #items do
    local item = items[ii]
    local take, win_start, win_end = item_window(item)
    if not take then
      flag_item_fail(item, "?", "no take")
      table.insert(results, { i = ii, ok = false, msg = "no take", word = "?" })
    else
      local match = nil
      local match_j = nil
      local match_hits_c = nil
      local match_hits_s = nil

      for j = pi, #cached_pickups do
        local p = cached_pickups[j]
        local c = p.corrected_word or ""
        local s = p.said_word or ""
        local hc = c ~= "" and find_all_matches(cached_tsv_words, c, win_start, win_end) or {}
        local hs = s ~= "" and find_all_matches(cached_tsv_words, s, win_start, win_end) or {}
        if #hc > 0 or #hs > 0 then
          match = p; match_j = j; match_hits_c = hc; match_hits_s = hs
          break
        end
      end

      if match then
        for j = pi, match_j - 1 do
          table.insert(skipped, { idx = j, pickup = cached_pickups[j] })
        end

        local word = match.corrected_word or match.said_word or ""
        if #match_hits_c > 0 then
          local chosen = match_hits_c[1]
          local set = apply_offset(item, take, chosen.time)
          table.insert(results, { i = ii, ok = true, quality = "EXACT", word = word,
            msg = string.format("offset=%.3f  word='%s'  method=corrected  at=%.3f  hits=%d",
              set, word, chosen.time, #match_hits_c) })
        else
          local chosen = match_hits_s[1]
          local set = apply_offset(item, take, chosen.time)
          table.insert(results, { i = ii, ok = true, quality = "EXACT", word = word,
            msg = string.format("offset=%.3f  word='%s'  method=said  at=%.3f  hits=%d",
              set, word, chosen.time, #match_hits_s) })
        end
        pi = match_j + 1
      else
        local next_word = pi <= #cached_pickups and (cached_pickups[pi].corrected_word or cached_pickups[pi].said_word or "") or ""
        local diag = string.format("window=[%.2fs-%.2fs]", win_start, win_end)
        if pi <= #cached_pickups then
          diag = diag .. string.format("  next_pickup='%s' not in window", next_word)
        else
          diag = diag .. "  no pickups remaining"
        end
        flag_item_fail(item, next_word, diag)
        table.insert(results, { i = ii, ok = false, quality = "FAIL", word = next_word, msg = diag })
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Align CRX items", -1)

  -- Summary
  local exact, fail_count = 0, 0
  for _, r in ipairs(results) do
    if r.ok then exact = exact + 1 else fail_count = fail_count + 1 end
  end
  local total_attempted = #results
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(string.format(
    "Align CRX items — %d/%d set  |  %d EXACT  %d FAIL\n", exact, total_attempted, exact, fail_count))
  if #skipped > 0 then
    reaper.ShowConsoleMsg(string.format("Skipped (gap) pickups: %d\n\n", #skipped))
  end
  reaper.ShowConsoleMsg(string.format("%-6s %-7s %-20s %s\n",
    "Item", "Result", "Word", "Detail"))
  reaper.ShowConsoleMsg(string.rep("-", 110) .. "\n")
  for _, r in ipairs(results) do
    local label = r.ok and "OK  " or "FAIL"
    reaper.ShowConsoleMsg(string.format("  %-4d %-7s %-20s %s\n",
      r.i, label, "'" .. (r.word or "") .. "'", r.msg))
  end
  if #skipped > 0 then
    reaper.ShowConsoleMsg("\nSkipped pickups (not found in any item's source window):\n")
    for _, s in ipairs(skipped) do
      local w = s.pickup.corrected_word or s.pickup.said_word or ""
      reaper.ShowConsoleMsg(string.format("  pickup #%d  word='%s'\n", s.idx, w))
    end
  end
  reaper.ShowMessageBox(string.format(
    "Complete.\n\n" ..
    "Items processed: %d\n" ..
    "Snap offsets set: %d\n" ..
    "  Exact:  %d\n" ..
    "Failures: %d\n" ..
    "Skipped (gap): %d\n\n" ..
    "Details in the ReaScript console.",
    total_attempted, exact, exact, fail_count, #skipped),
    "Set CRX snap offset", 0)
end


main()
