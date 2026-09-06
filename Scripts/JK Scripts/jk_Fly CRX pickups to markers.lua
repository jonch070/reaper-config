--[[
@description jk_Fly CRX pickups to markers
@version 0.3
@author Jonathan Kawchuk
@about
  Reads narrator markers from the current session, matches each to its
  corrected_word from the pickups CSV, finds that word in the whisper
  transcript by walking sequentially through the CRX source, and creates
  CRX items directly on a new track with correct SOFFS/SNAPOFFS so the
  word aligns perfectly with the marker.

  Uses silence-detected chunk boundaries (crx_chunks.csv from stage 04)
  to create items at exact pickup boundaries instead of fixed windows.

  Prerequisites:
    1. Run pipeline stages 01-03 (markers must be in the session)
    2. Run stage 04 (generates whisper TSV + pickups CSV + chunks CSV)
    3. Open the MAIN session RPP, run this script

  The script auto-detects:
    - Project root from the RPP location
    - Pickups CSV from <project>/transcriptions/qc report/
    - Whisper TSV from <project>/transcriptions/narrator<N> pickups/
    - CRX audio + chunks CSV from <project>/Unedited Masters/Narrator <N> CRX/
]]--

-- ── Config ──────────────────────────────────────────────────

local CASE_INSENSITIVE  = true

-- Track to create (or reuse) for CRX items
local CRX_TRACK_NAME = "CRX"
local CRX_TRACK_COLOR = reaper.ColorToNative(70, 120, 200) | 0x1000000


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

local function normalize_word(s)
  if not s then return "" end
  s = trim(s)
  s = s:gsub("[^%w']", "")
  if CASE_INSENSITIVE then s = s:lower() end
  return s
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


-- ── File auto-discovery ─────────────────────────────────────

local function find_file_in(patterns)
  for _, entry in ipairs(patterns) do
    local dir, pat = entry[1], entry[2]
    local i = 0
    while true do
      local n = reaper.EnumerateFiles(dir, i)
      if not n then break end
      i = i + 1
      if n:match(pat) then
        return dir .. n
      end
    end
  end
  return nil
end

local function discover_paths(project_root, narrator_id)
  local paths = {}

  -- Pickups CSV
  local csv_dir = project_root .. "transcriptions/qc report/"
  local i = 0
  while true do
    local n = reaper.EnumerateFiles(csv_dir, i)
    if not n then break end
    i = i + 1
    if n:match(narrator_id .. "_pickups%.csv$") then
      paths.pickups_csv = csv_dir .. n
      break
    end
  end
  if not paths.pickups_csv then
    -- fallback: any _pickups.csv
    paths.pickups_csv = find_file_in({
      { csv_dir, "_pickups%.csv$" },
      { project_root .. "transcriptions/", "_pickups%.csv$" },
    })
  end
  if not paths.pickups_csv then
    return nil, "No " .. narrator_id .. "_pickups.csv found"
  end

  -- Whisper TSV
  local whisper_dir = project_root .. "transcriptions/" .. narrator_id .. " pickups/"
  paths.whisper_tsv = find_file_in({
    { whisper_dir, "%.tsv$" },
  })
  if not paths.whisper_tsv then
    return nil, "No .tsv found in " .. whisper_dir
  end

  -- CRX audio file
  local narrator_num = narrator_id:match("%d+")
  local crx_dir = project_root .. "Unedited Masters/Narrator " .. narrator_num .. " CRX/"
  paths.crx_file = find_file_in({
    { crx_dir, "%.mp3$" },
    { crx_dir, "%.wav$" },
    { crx_dir, "%.flac$" },
  })
  if not paths.crx_file then
    -- Broader search
    paths.crx_file = find_file_in({
      { project_root .. "Unedited Masters/", "CRX.+" },
    })
  end
  if not paths.crx_file then
    return nil, "No CRX audio file found in " .. crx_dir
  end

  -- Chunks CSV (alongside CRX audio)
  paths.chunks_csv = crx_dir .. "crx_chunks.csv"
  if not io.open(paths.chunks_csv, "r") then
    paths.chunks_csv = nil
  end

  return paths
end


-- ── TSV loading ────────────────────────────────────────────

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
  return words, nil, #words
end


-- ── CSV loading ────────────────────────────────────────────

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


-- ── Chunks loading ──────────────────────────────────────────

local function load_chunks(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local chunks = {}
  local line_n = 0
  for line in f:lines() do
    line_n = line_n + 1
    if line_n == 1 then goto continue end  -- skip header
    local id, start_str, end_str = line:match("^(%d+),(%d+%.%d+),(%d+%.%d+)")
    if id then
      table.insert(chunks, {
        id = tonumber(id),
        start = tonumber(start_str),
        ended = tonumber(end_str),
      })
    end
    ::continue::
  end
  f:close()
  return chunks
end

local function find_chunk(chunks, time)
  -- Binary search: find chunk containing time
  local lo, hi = 1, #chunks
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local c = chunks[mid]
    if time < c.start then
      hi = mid - 1
    elseif time >= c.ended then
      lo = mid + 1
    else
      return c
    end
  end
  return nil
end


-- ── Marker collection ──────────────────────────────────────

-- Returns: list of { idx, pos, pickup_id, name } sorted by position
local function collect_narrator_markers(narrator_id)
  local prefix = narrator_id .. " #"
  local markers = {}
  local n = reaper.CountProjectMarkers(0)
  for i = 0, n - 1 do
    local _, isrgn, pos, _, name, idx = reaper.EnumProjectMarkers(i)
    if not isrgn and name then
      local pickup_str = name:match(prefix .. "(%d+)")
      if pickup_str then
        table.insert(markers, {
          marker_idx = idx,
          pos = pos,
          pickup_id = tonumber(pickup_str),
          name = name,
        })
      end
    end
  end
  table.sort(markers, function(a, b) return a.pos < b.pos end)
  return markers
end


-- ── Track management ───────────────────────────────────────

local function find_or_create_crx_track()
  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local tr = reaper.GetTrack(0, t)
    local ok, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if ok and name == CRX_TRACK_NAME then return tr end
  end
  local track = reaper.InsertTrackAtIndex(n_tracks, 1)
  if not track and n_tracks > 0 then
    track = reaper.InsertTrackAtIndex(0, 1)
  end
  if not track then
    reaper.Main_OnCommand(40001, 0)
    if reaper.CountTracks(0) > n_tracks then
      track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
    end
  end
  if not track then
    return nil
  end
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", CRX_TRACK_NAME, true)
  reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", CRX_TRACK_COLOR)
  return track
end


-- ── Item creation ──────────────────────────────────────────

-- Creates a CRX item on the track, aligned so source_time plays at marker_pos.
-- When chunk is provided, the item shows the full chunk (silence-bounded
-- pickup). Otherwise falls back to a fixed window (PRE_ROLL/POST_ROLL).
local function create_crx_item(track, crx_file, marker_pos, source_time, chunk)
  local soffs, item_pos, item_len, snapoff
  if chunk then
    -- Show the full silence-bounded chunk, word at the marker.
    soffs = chunk.start
    item_len = chunk.ended - chunk.start
    snapoff = chunk.start
    -- Item left edge = marker - (source_time - chunk.start):
    --   At left edge, source is at chunk.start (snap offset).
    --   At marker_pos, source is at source_time (the word).
    item_pos = marker_pos - (source_time - chunk.start)
  else
    -- Fallback: fixed context window
    local PRE_ROLL = 0.3
    local POST_ROLL = 1.5
    soffs = source_time - PRE_ROLL
    if soffs < 0 then soffs = 0 end
    item_pos = marker_pos - PRE_ROLL
    item_len = PRE_ROLL + POST_ROLL
    snapoff = source_time
  end

  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", item_pos)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len)
  reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", snapoff)

  local take = reaper.AddTakeToMediaItem(item)
  local src = reaper.PCM_Source_CreateFromFile(crx_file)
  reaper.SetMediaItemTake_Source(take, src)
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", soffs)
  reaper.UpdateItemInProject(item)

  return item
end


-- ── Sequential TSV walk ─────────────────────────────────────
--
-- Matches pickups to TSV words by walking forward through the
-- transcript. For each pickup word, scans from the current TSV
-- position forward to find the next occurrence. This respects
-- the CRX recording order.

local function match_pickups_to_tsv(pickup_list, tsv_words)
  local results = {}
  local tsv_idx = 1
  local n_tsv = #tsv_words

  for _, pu in ipairs(pickup_list) do
    local corrected = trim(pu.corrected_word or "")
    local said = trim(pu.said_word or "")
    local word = corrected ~= "" and corrected or said

    if word == "" then
      table.insert(results, {
        ok = false, word = word,
        reason = "no corrected or said word",
      })
      goto continue
    end

    local nw = normalize_word(word)
    local found = false

    -- Scan forward from current TSV position
    while tsv_idx <= n_tsv do
      if normalize_word(tsv_words[tsv_idx].text) == nw then
        table.insert(results, {
          ok = true,
          word = word,
          source_time = tsv_words[tsv_idx].time,
          tsv_index = tsv_idx,
        })
        tsv_idx = tsv_idx + 1
        found = true
        break
      end
      tsv_idx = tsv_idx + 1
    end

    if not found then
      -- Word not found in remaining TSV — try from beginning
      -- (might be out of order in the CRX)
      tsv_idx = 1
      while tsv_idx <= n_tsv do
        if normalize_word(tsv_words[tsv_idx].text) == nw then
          table.insert(results, {
            ok = true,
            word = word,
            source_time = tsv_words[tsv_idx].time,
            tsv_index = tsv_idx,
          })
          tsv_idx = tsv_idx + 1
          found = true
          break
        end
        tsv_idx = tsv_idx + 1
      end
    end

    if not found then
      table.insert(results, {
        ok = false, word = word,
        reason = string.format("'%s' not found in TSV", word),
      })
    end

    ::continue::
  end

  return results
end


-- ── Main ───────────────────────────────────────────────────

function main()
  -- Resolve narrator ID
  local ok, narrator_id = reaper.GetUserInputs(
    "Fly CRX pickups — narrator", 1,
    "Narrator (narrator1 or narrator2),extrawidth=300", "narrator1")
  if not ok or narrator_id == "" then return end
  narrator_id = trim(narrator_id):lower()
  if narrator_id ~= "narrator1" and narrator_id ~= "narrator2" then
    reaper.ShowMessageBox("Must be 'narrator1' or 'narrator2'",
      "Fly CRX pickups", 0)
    return
  end

  -- Detect project root
  local project_root = detect_project_root()
  if not project_root then
    reaper.ShowMessageBox("Could not detect project root.", "Fly CRX pickups", 0)
    return
  end

  -- Discover paths
  local paths, err = discover_paths(project_root, narrator_id)
  if not paths then
    reaper.ShowMessageBox("Path discovery failed:\n" .. tostring(err), "Fly CRX pickups", 0)
    return
  end

  -- Confirm
  local chunks_info = paths.chunks_csv and ("chunks: %s (%d)"):format(
    basename(paths.chunks_csv), chunks and #chunks or 0) or "chunks: none"
  local choice = reaper.ShowMessageBox(string.format(
    "Narrator: %s\n\nCSV:  %s\nTSV:  %s\nCRX:  %s\n%s\n\nProceed?",
    narrator_id, basename(paths.pickups_csv), basename(paths.whisper_tsv),
    basename(paths.crx_file), chunks_info), "Fly CRX pickups to markers", 1)
  if choice ~= 1 then return end

  -- Load data
  local pickups, err = load_pickups_csv(paths.pickups_csv)
  if not pickups then
    reaper.ShowMessageBox("Failed to load pickups CSV:\n" .. tostring(err), "Fly CRX", 0)
    return
  end

  local tsv_words, err = load_tsv(paths.whisper_tsv)
  if not tsv_words then
    reaper.ShowMessageBox("Failed to load whisper TSV:\n" .. tostring(err), "Fly CRX", 0)
    return
  end

  -- Load chunks CSV (optional — stage 04 generates this)
  local chunks = nil
  if paths.chunks_csv then
    chunks = load_chunks(paths.chunks_csv)
  end

  -- Collect narrator markers (ordered by position)
  local markers = collect_narrator_markers(narrator_id)
  if #markers == 0 then
    reaper.ShowMessageBox(string.format(
      "No '%s #N' markers found. Run stage 03 first.", narrator_id), "Fly CRX pickups", 0)
    return
  end

  -- Build pickup lookup by pickup_id and preserve marker order
  local pickup_by_id = {}
  for _, p in ipairs(pickups) do
    local pid = tonumber(p.pickup_id)
    if pid then pickup_by_id[pid] = p end
  end

  -- Build list of pickups matching markers (in marker order)
  local ordered_pickups = {}
  for _, m in ipairs(markers) do
    local pu = pickup_by_id[m.pickup_id]
    if pu then
      table.insert(ordered_pickups, pu)
    end
  end

  -- Match pickups to TSV words sequentially
  local tsv_results = match_pickups_to_tsv(ordered_pickups, tsv_words)

  -- Find or create CRX track
  local track = find_or_create_crx_track()
  if not track then
    reaper.ShowMessageBox("Could not find or create CRX track.", "Fly CRX pickups", 0)
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local created, skipped = 0, 0
  local console = {}
  table.insert(console, string.format("Fly CRX pickups — %s\n", narrator_id))
  table.insert(console, string.format("Markers: %d  Pickups: %d  TSV words: %d\n\n",
    #markers, #ordered_pickups, #tsv_words))

  for i, m in ipairs(markers) do
    local pu = pickup_by_id[m.pickup_id]
    if not pu then
      table.insert(console, string.format(
        "  M%-4d  #%-3d  SKIP — pickup_id %d not in CSV", m.marker_idx, m.pickup_id, m.pickup_id))
      skipped = skipped + 1
      goto continue
    end

    local tr = tsv_results[i]
    if not tr or not tr.ok then
      local reason = tr and tr.reason or "no match"
      table.insert(console, string.format(
        "  M%-4d  #%-3d  FAIL — %s", m.marker_idx, m.pickup_id, reason))
      skipped = skipped + 1
      goto continue
    end

    local chunk = nil
    if chunks then
      chunk = find_chunk(chunks, tr.source_time)
    end
    if chunk then
      create_crx_item(track, paths.crx_file, m.pos, tr.source_time, chunk)
      created = created + 1
      table.insert(console, string.format(
        "  M%-4d  #%-3d  OK   — '%s' chunk=[%.3f-%.3f]  src=%.3fs  tl=%.3fs",
        m.marker_idx, m.pickup_id, tr.word, chunk.start, chunk.ended,
        tr.source_time, m.pos))
    else
      -- Fallback: fixed window
      create_crx_item(track, paths.crx_file, m.pos, tr.source_time, nil)
      created = created + 1
      local note = (chunks and "no chunk") or "no chunks file"
      table.insert(console, string.format(
        "  M%-4d  #%-3d  OK   — '%s' %s  src=%.3fs  tl=%.3fs",
        m.marker_idx, m.pickup_id, tr.word, note,
        tr.source_time, m.pos))
    end

    ::continue::
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Fly CRX pickups to markers", -1)

  -- Report
  reaper.ClearConsole()
  for _, line in ipairs(console) do
    reaper.ShowConsoleMsg(line .. "\n")
  end

  reaper.ShowMessageBox(string.format(
    "Done.\n\nMarkers found: %d\nItems created: %d\nSkipped:       %d\n\nDetails in ReaScript console.",
    #markers, created, skipped), "Fly CRX pickups to markers", 0)
end

main()
