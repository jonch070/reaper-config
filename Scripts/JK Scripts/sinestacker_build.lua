--[[
  Sine Stacker — in-place builder v2
  Requires: ReaImGui extension (install via ReaPack: Extensions > ReaPack > Browse packages,
            search "ReaImGui", install cfillion/ReaImGui).

  Workflow:
    1. Select an audio item whose source file you want to analyze.
    2. Run this action.
    3. Adjust params; click Run.
    4. Python analyzes the file, writes a JSON manifest; this script reads it and builds
       tracks/items directly into the current project at the selected item's position.

  Window modes:
    Float (keep open) — panel stays for re-runs with different params.
    Unchecked         — closes after Run.

  SETUP: edit PY and PROJ below.
]]

---------------------------------------------------------------- CONFIG
-- Full path to the installed sinestacker binary.
-- Install once with: pip install -e . && ln -sf .venv/bin/sinestacker /usr/local/bin/sinestacker
-- After moving the project folder, re-run the symlink — no need to edit this file.
local SINESTACKER = "/usr/local/bin/sinestacker"
----------------------------------------------------------------

-- ---------------------------------------------------------------- JSON decoder
local json = {}
do
  local function skip(s, i) return s:find("[^ \t\n\r]", i) or (#s + 1) end
  local parse
  local function parse_string(s, i)
    local parts, j = {}, i + 1
    while j <= #s do
      local c = s:sub(j, j)
      if     c == '"'  then return table.concat(parts), j + 1
      elseif c == '\\' then
        local esc = s:sub(j+1, j+1)
        parts[#parts+1] = ({['"']='"',['\\']='\\',['/']=
          '/',n='\n',t='\t',r='\r',b='\b',f='\f'})[esc] or esc
        j = j + 2
      else parts[#parts+1] = c; j = j + 1 end
    end
    error("unterminated string at " .. i)
  end
  local function parse_object(s, i)
    local obj, j = {}, skip(s, i + 1)
    if s:sub(j, j) == '}' then return obj, j + 1 end
    while true do
      j = skip(s, j)
      local key; key, j = parse_string(s, j)
      j = skip(s, j)
      assert(s:sub(j, j) == ':', "expected ':' at " .. j)
      local val; val, j = parse(s, j + 1)
      obj[key] = val
      j = skip(s, j)
      local sep = s:sub(j, j)
      if sep == '}' then return obj, j + 1 end
      assert(sep == ',', "expected ',' or '}' at " .. j); j = j + 1
    end
  end
  local function parse_array(s, i)
    local arr, j = {}, skip(s, i + 1)
    if s:sub(j, j) == ']' then return arr, j + 1 end
    while true do
      local val; val, j = parse(s, j)
      arr[#arr+1] = val
      j = skip(s, j)
      local sep = s:sub(j, j)
      if sep == ']' then return arr, j + 1 end
      assert(sep == ',', "expected ',' or ']' at " .. j); j = j + 1
    end
  end
  parse = function(s, i)
    i = skip(s, i)
    local c = s:sub(i, i)
    if     c == '"' then return parse_string(s, i)
    elseif c == '{' then return parse_object(s, i)
    elseif c == '[' then return parse_array(s, i)
    elseif c == 't' then return true,  i + 4
    elseif c == 'f' then return false, i + 5
    elseif c == 'n' then return nil,   i + 4
    else
      local num, j = s:match("^(-?%d+%.?%d*[eE]?[+-]?%d*)()", i)
      assert(num, "unexpected '" .. c .. "' at " .. i)
      return tonumber(num), j
    end
  end
  function json.decode(s)
    local ok, val = pcall(parse, s, 1)
    if ok then return val, nil end
    return nil, tostring(val)
  end
end

-- ---------------------------------------------------------------- macOS folder picker (multi-select)
-- Returns a table of paths (may be empty if cancelled).
-- AppleScript: choose folder with multiple selections allowed always returns a list.
local function pick_folders(prompt)
  local safe = (prompt or "Choose folders"):gsub('"', '\\"'):gsub("'", "'\\''")
  -- Write AppleScript to a temp file to avoid quoting hell with io.popen.
  local tmp = os.tmpname() .. ".applescript"
  local fh = io.open(tmp, "w")
  if not fh then return {} end
  fh:write(string.format([[
set theFolders to choose folder with prompt "%s" with multiple selections allowed
if class of theFolders is not list then set theFolders to {theFolders}
set out to {}
repeat with f in theFolders
  set end of out to POSIX path of f
end repeat
set AppleScript's text item delimiters to "\n"
return out as text
]], safe))
  fh:close()
  local h = io.popen('osascript "' .. tmp .. '" 2>/dev/null')
  local result = h and h:read("*a") or ""
  if h then h:close() end
  os.remove(tmp)
  local folders = {}
  if result and result ~= "" then
    for line in (result:gsub("%s+$","") .. "\n"):gmatch("([^\n]+)\n") do
      local f = line:gsub("/$","")
      if f ~= "" then folders[#folders+1] = f end
    end
  end
  return folders
end

-- ---------------------------------------------------------------- State
local EXTKEY = "SineStacker_v2"

local p = {
  mode         = 0,
  max_partials = 60,
  amp_floor    = -60.0,
  max_simul    = 0,
  sort         = 0,
  edge         = 0,
  fade_ms      = 5.0,
  channel      = 0,
  key_enable   = false,
  key_root     = 0,
  key_scale    = 0,
  key_mode     = 0,
  key_cents    = 50.0,
  strategy     = 1,
  pitch        = 0,
  amp_mode     = 0,
  sr           = 0,
  bit_depth    = 0,
  corpus_tolerance       = 50.0,
  corpus_repeat          = 0,
  corpus_on_miss         = 0,
  corpus_transpose       = false,
  corpus_normalize       = false,
  corpus_gain            = 1.0,
  corpus_loudness_weight = 0.0,
  corpus_amp_mode        = 0,
  corpus_length          = 0,
  corpus_whole_file      = true,
  corpus_rebuild         = false,
  corpus_recursive       = true,
  corpus_min_pitch_conf  = 0.0,
  corpus_max_voices      = 0,
  glide_split            = 0.0,
  mono_confidence        = 0.1,
  mono_smooth_ms         = 20.0,
  mono_unvoiced          = 2,    -- 0=silence 1=drop 2=interpolate
  mono_fmin              = 65.0,
  mono_fmax              = 2000.0,
  mono_render            = true,   -- true = render resynthesis WAV; false = PITCHENV/VOLENV
  mono_transpose         = 0.0,    -- semitones to shift before render
  mono_snap              = 0,      -- 0=none 1=semitone 2=key
  mono_key               = 0,      -- index into ROOTS
  mono_scale             = 0,      -- index into SCALES
  mono_portamento        = 0.0,    -- glide ms between snap transitions
  mono_portamento_rand   = 0.0,    -- randomise portamento ± ms per transition
  midi         = 0,
  bend_range   = 48,
  amp_target   = 0,
  float_mode   = true,
  wrap_folder  = true,
}

local corpus_folders = {}

local SCALES = {"major","minor","harmonic_minor","melodic_minor",
                "major_pentatonic","minor_pentatonic","whole_tone","chromatic"}
local ROOTS  = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local SR_VALS= {96000, 48000, 44100}
local BD_VALS= {24, 16}

local function load_state()
  local function gi(k, d) return tonumber(reaper.GetExtState(EXTKEY, k)) or d end
  local function gb(k, d)
    local v = reaper.GetExtState(EXTKEY, k)
    return v ~= "" and (v == "true") or d
  end
  p.mode         = gi("mode",         0)
  p.max_partials = gi("max_partials", 60)
  p.amp_floor    = gi("amp_floor",    -60.0)
  p.max_simul    = gi("max_simul",    0)
  p.sort         = gi("sort",         0)
  p.edge         = gi("edge",         0)
  p.fade_ms      = gi("fade_ms",      5.0)
  p.channel      = gi("channel",      0)
  p.key_enable   = gb("key_enable",   false)
  p.key_root     = gi("key_root",     0)
  p.key_scale    = gi("key_scale",    0)
  p.key_mode     = gi("key_mode",     0)
  p.key_cents    = gi("key_cents",    50.0)
  p.strategy     = gi("strategy",     0)
  p.pitch        = gi("pitch",        0)
  p.amp_mode     = gi("amp_mode",     0)
  p.sr           = gi("sr",           0)
  p.bit_depth    = gi("bit_depth",    0)
  p.corpus_tolerance       = gi("corpus_tolerance",       50)
  p.corpus_repeat          = gi("corpus_repeat",          0)
  p.corpus_on_miss         = gi("corpus_on_miss",         0)
  p.corpus_transpose       = gb("corpus_transpose",       false)
  p.corpus_normalize       = gb("corpus_normalize",       false)
  p.corpus_gain            = gi("corpus_gain",            1)
  p.corpus_loudness_weight = gi("corpus_loudness_weight", 0)
  p.corpus_amp_mode        = gi("corpus_amp_mode",        0)
  p.corpus_length          = gi("corpus_length",          0)
  p.corpus_whole_file      = gb("corpus_whole_file",      true)
  p.corpus_rebuild         = gb("corpus_rebuild",         false)
  p.corpus_recursive       = gb("corpus_recursive",       true)
  p.corpus_min_pitch_conf  = gi("corpus_min_pitch_conf",  0)
  p.corpus_max_voices      = gi("corpus_max_voices",      0)
  p.glide_split            = gi("glide_split",            0)
  p.mono_confidence        = gi("mono_confidence",        0.1)
  p.mono_smooth_ms         = gi("mono_smooth_ms",         20)
  p.mono_unvoiced          = gi("mono_unvoiced",          2)
  p.mono_fmin              = gi("mono_fmin",              65)
  p.mono_render            = gb("mono_render",    true)
  p.mono_transpose         = gi("mono_transpose",  0)
  p.mono_snap              = gi("mono_snap",       0)
  p.mono_key               = gi("mono_key",        0)
  p.mono_scale             = gi("mono_scale",      0)
  p.mono_portamento        = gi("mono_portamento",      0)
  p.mono_portamento_rand   = gi("mono_portamento_rand", 0)
  p.mono_fmax              = gi("mono_fmax",              2000)
  p.midi         = gi("midi",         0)
  p.bend_range   = gi("bend_range",   48)
  p.amp_target   = gi("amp_target",   0)
  p.float_mode   = gb("float_mode",   true)
  p.wrap_folder  = gb("wrap_folder",  true)
  local raw = reaper.GetExtState(EXTKEY, "corpus_folders")
  corpus_folders = {}
  if raw and raw ~= "" then
    for f in (raw .. "\n"):gmatch("([^\n]+)\n") do
      corpus_folders[#corpus_folders+1] = f
    end
  end
end

local function save_state()
  local function s(k, v) reaper.SetExtState(EXTKEY, k, tostring(v), true) end
  s("mode", p.mode); s("max_partials", p.max_partials); s("amp_floor", p.amp_floor)
  s("max_simul", p.max_simul); s("sort", p.sort); s("edge", p.edge)
  s("fade_ms", p.fade_ms); s("channel", p.channel)
  s("key_enable", p.key_enable); s("key_root", p.key_root); s("key_scale", p.key_scale)
  s("key_mode", p.key_mode); s("key_cents", p.key_cents)
  s("strategy", p.strategy); s("pitch", p.pitch); s("amp_mode", p.amp_mode)
  s("sr", p.sr); s("bit_depth", p.bit_depth)
  s("corpus_tolerance", p.corpus_tolerance); s("corpus_repeat", p.corpus_repeat)
  s("corpus_on_miss", p.corpus_on_miss); s("corpus_transpose", p.corpus_transpose)
  s("corpus_normalize", p.corpus_normalize); s("corpus_gain", p.corpus_gain)
  s("corpus_loudness_weight", p.corpus_loudness_weight)
  s("corpus_amp_mode", p.corpus_amp_mode); s("corpus_length", p.corpus_length)
  s("corpus_whole_file", p.corpus_whole_file)
  s("corpus_rebuild", p.corpus_rebuild)
  s("corpus_recursive", p.corpus_recursive)
  s("corpus_min_pitch_conf", p.corpus_min_pitch_conf)
  s("corpus_max_voices", p.corpus_max_voices)
  s("glide_split", p.glide_split)
  s("mono_confidence", p.mono_confidence)
  s("mono_smooth_ms",  p.mono_smooth_ms)
  s("mono_unvoiced",   p.mono_unvoiced)
  s("mono_fmin",       p.mono_fmin)
  s("mono_fmax",       p.mono_fmax)
  s("mono_render",     tostring(p.mono_render))
  s("mono_transpose",  p.mono_transpose)
  s("mono_snap",       p.mono_snap)
  s("mono_key",        p.mono_key)
  s("mono_scale",           p.mono_scale)
  s("mono_portamento",      p.mono_portamento)
  s("mono_portamento_rand", p.mono_portamento_rand)
  s("midi", p.midi); s("bend_range", p.bend_range); s("amp_target", p.amp_target)
  s("float_mode", p.float_mode); s("wrap_folder", p.wrap_folder)
  reaper.SetExtState(EXTKEY, "corpus_folders", table.concat(corpus_folders, "\n"), true)
end

-- ---------------------------------------------------------------- Helpers
local function q(s) return '"' .. tostring(s):gsub('"', '\\"') .. '"' end

local function resolve_path(path, base_dir)
  if not path or path == "" then return "" end
  if path:sub(1, 1) == "/" then return path end
  return base_dir .. "/" .. path
end

local function get_selected_item_info()
  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then return nil, 0.0, -1 end
  local take = reaper.GetActiveTake(item)
  if not take then return nil, 0.0, -1 end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil, 0.0, -1 end
  local src_file = reaper.GetMediaSourceFileName(src, "")
  local track    = reaper.GetMediaItemTrack(item)
  local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
  local pos      = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  return src_file, pos, track_idx
end

-- ---------------------------------------------------------------- Envelope injection
-- FRAGILE: GetItemStateChunk/SetItemStateChunk. Base strategy only.
local function make_env_chunk(tag, points)
  local lines = {"<" .. tag, "ACT 1", "VIS 1", "DEFSHAPE 0"}
  for _, pt in ipairs(points) do
    lines[#lines+1] = string.format("PT %.6f %.6f 0", pt[1], pt[2])
  end
  lines[#lines+1] = ">"
  return table.concat(lines, "\n")
end

local function inject_envelopes(item, item_def)
  local ok, chunk = reaper.GetItemStateChunk(item, "", false)
  if not ok or not chunk or chunk == "" then return false, "GetItemStateChunk failed" end
  local env_text = ""
  if item_def.vol_env   then env_text = env_text .. "\n" .. make_env_chunk("VOLENV",   item_def.vol_env) end
  if item_def.pitch_env then env_text = env_text .. "\n" .. make_env_chunk("PITCHENV", item_def.pitch_env) end
  if env_text == "" then return true end
  if     chunk:sub(-2) == ">\n" then chunk = chunk:sub(1,-3) .. env_text .. "\n>\n"
  elseif chunk:sub(-1) == ">"   then chunk = chunk:sub(1,-2) .. env_text .. "\n>"
  else return false, "unexpected chunk ending" end
  local set_ok = reaper.SetItemStateChunk(item, chunk, false)
  return set_ok, set_ok and nil or "SetItemStateChunk false"
end

-- ---------------------------------------------------------------- In-place builder
local function build_in_place(manifest, time_offset, insert_after_idx)
  local base_dir = manifest._base_dir or ""
  if #manifest.tracks == 0 then return false, "manifest has no tracks" end
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local errors = {}
  local track_idx = insert_after_idx + 1
  if p.wrap_folder then
    reaper.InsertTrackAtIndex(track_idx, false)
    local wt = reaper.GetTrack(0, track_idx)
    -- TODO: smarter folder label —
    --   Sine mode:   use "sine" or the source filename stem
    --   Corpus mode: join the basenames of all corpus_folders, e.g. "piano + strings"
    --   manifest.meta.mode and manifest.meta.corpus_folders would need to be emitted by Python
    local label = (manifest.meta and manifest.meta.source)
                  and manifest.meta.source:match("[^/\\]+$") or "sine stack"
    reaper.GetSetMediaTrackInfo_String(wt, "P_NAME", label, true)
    reaper.SetMediaTrackInfo_Value(wt, "I_FOLDERDEPTH", 1)
    track_idx = track_idx + 1
  end
  for ti, track_def in ipairs(manifest.tracks) do
    reaper.InsertTrackAtIndex(track_idx, false)
    local track = reaper.GetTrack(0, track_idx)
    if not track then errors[#errors+1] = "insert failed at " .. track_idx; goto ct end
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_def.name or ("Track "..ti), true)
    local fd = 0
    if track_def.folder == "open"  then fd =  1 end
    if track_def.folder == "close" then fd = -1 end
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", fd)
    for _, item_def in ipairs(track_def.items or {}) do
      local mi = reaper.AddMediaItemToTrack(track)
      reaper.SetMediaItemInfo_Value(mi, "D_POSITION", item_def.position + time_offset)
      reaper.SetMediaItemInfo_Value(mi, "D_LENGTH",   item_def.length)
      reaper.SetMediaItemInfo_Value(mi, "D_VOL",      item_def.item_volume or 1.0)
      reaper.SetMediaItemInfo_Value(mi, "B_LOOPSRC",  item_def.loop and 1 or 0)
      if (item_def.fade_in  or 0) > 0 then reaper.SetMediaItemInfo_Value(mi, "D_FADEINLEN",  item_def.fade_in)  end
      if (item_def.fade_out or 0) > 0 then reaper.SetMediaItemInfo_Value(mi, "D_FADEOUTLEN", item_def.fade_out) end
      local take = reaper.AddTakeToMediaItem(mi)
      local src_path = resolve_path(item_def.source, base_dir)
      local src = reaper.PCM_Source_CreateFromFile(src_path)
      if src then
        reaper.SetMediaItemTake_Source(take, src)
        if p.corpus_whole_file and p.mode == 1 then
          local src_len = reaper.GetMediaSourceLength(src, false)
          if src_len > 0 then
            reaper.SetMediaItemInfo_Value(mi, "D_LENGTH", src_len)
          end
        end
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", item_def.name or "", true)
        reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE",  item_def.playrate or 1.0)
        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", item_def.soffs    or 0.0)
        if item_def.vol_env or item_def.pitch_env then
          local env_ok, env_err = inject_envelopes(mi, item_def)
          if not env_ok then errors[#errors+1] = "env " .. (item_def.name or "?") .. ": " .. (env_err or "?") end
        end
      else
        errors[#errors+1] = "not found: " .. src_path
      end
    end
    track_idx = track_idx + 1
    ::ct::
  end
  if p.wrap_folder then
    local last = reaper.GetTrack(0, track_idx - 1)
    if last then
      local cur = reaper.GetMediaTrackInfo_Value(last, "I_FOLDERDEPTH")
      reaper.SetMediaTrackInfo_Value(last, "I_FOLDERDEPTH", cur - 1)
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Sine Stacker: build in place", -1)
  if #errors > 0 then return false, table.concat(errors, "\n") end
  return true, nil
end

-- ---------------------------------------------------------------- Run
local status_msg = ""
local status_ok  = true
local close_next = false

local strategy_vals   = {"base","render"}
local sort_vals       = {"freq","partial"}
local edge_vals       = {"none","zero","fade","both"}
local pitch_vals      = {"gliding","static"}
local midi_vals       = {"none","multitrack","mpe"}
local repeat_vals     = {"strict","roundrobin","free"}
local on_miss_vals    = {"drop","nearest"}
local amp_target_vals = {"pressure","cc11"}
local camp_mode_vals  = {"rms","peak"}
local clength_vals    = {"reject_shorter","allow_any"}

-- src_channel_count is updated every draw frame from the selected item.
-- 0 = unknown (no item selected or source not readable).
local src_channel_count = 0

-- Translate UI channel index → CLI --channel argument.
-- Layout: 0=Mix, 1..N=Ch i (0-based), N+1=Each
local function channel_cli_arg(idx)
  if idx == 0 then return "mix" end
  if src_channel_count > 0 then
    if idx == src_channel_count + 1 then return "each" end
    if idx >= 1 and idx <= src_channel_count then return tostring(idx - 1) end
  end
  -- fallback for static list (no item selected): treat indices 1,2 as left/right
  if idx == 1 then return "0" end
  if idx == 2 then return "1" end
  return "each"
end

local function run()
  status_msg = "Running Python…"
  status_ok  = true

  if p.mode == 1 and #corpus_folders == 0 then
    status_msg = "ERROR: add at least one corpus folder."
    status_ok = false; return
  end

  local src_file, time_offset, insert_after_idx = get_selected_item_info()
  if not src_file then
    local rv, chosen = reaper.GetUserFileNameForRead("", "Sine Stacker: choose source audio", "wav")
    if not rv then status_msg = "Cancelled."; return end
    src_file = chosen; time_offset = 0.0; insert_after_idx = reaper.CountTracks(0) - 1
  end

  local src_base = src_file:match("([^/\\]+)%.%w+$") or "sinestacker_out"

  -- Output goes to the open project's directory so media/ lands with the project,
  -- not scattered next to whatever audio file was analyzed. Falls back to source dir
  -- if no project is saved yet.
  local proj_dir = reaper.GetProjectPath("")
  local src_dir  = src_file:match("^(.*)[/\\]") or PROJ
  local out_dir  = (proj_dir and proj_dir ~= "") and proj_dir or src_dir

  local rpp_path      = out_dir .. "/" .. src_base .. "_sines.rpp"
  local manifest_path = out_dir .. "/" .. src_base .. "_manifest.json"

  -- ── Mono mode: pyin tracking, short-circuits sine/corpus ─────────────────
  if p.mode == 2 then
    -- ── build descriptive filename from active settings ───────────────────
    local suffix = "_mono"
    if p.mono_transpose ~= 0.0 then
      suffix = suffix .. string.format("_t%+.0f", p.mono_transpose)
    end
    if p.mono_snap == 1 then
      suffix = suffix .. "_semi"
    elseif p.mono_snap == 2 then
      local scale_short = ({"maj","min","harm","mel","majp","minp","wt","chr"})[p.mono_scale + 1]
      suffix = suffix .. "_" .. ROOTS[p.mono_key + 1] .. (scale_short or "")
    end
    if p.mono_portamento > 0 then
      suffix = suffix .. string.format("_p%.0f", p.mono_portamento)
    end
    -- ── non-destructive: increment if file already exists ────────────────
    local base_path = out_dir .. "/" .. src_base .. suffix
    local render_path = base_path .. ".wav"
    if reaper.file_exists(render_path) then
      local i = 1
      repeat
        render_path = base_path .. string.format("_%03d", i) .. ".wav"
        i = i + 1
      until not reaper.file_exists(render_path)
    end
    -- manifest shares the same stem as the WAV (strip .wav, add .json)
    local mono_manifest = render_path:gsub("%.wav$", ".json")
    local mono_cmd = q(SINESTACKER) .. " " .. q(src_file)
                  .. " --mono"
                  .. " --mono-confidence " .. p.mono_confidence
                  .. " --mono-smooth-ms "  .. p.mono_smooth_ms
                  .. " --mono-unvoiced "   .. ({"silence","drop","interpolate"})[p.mono_unvoiced + 1]
                  .. " --mono-fmin "       .. p.mono_fmin
                  .. " --mono-fmax "       .. p.mono_fmax
                  .. " --channel "         .. channel_cli_arg(p.channel)
                  .. " --manifest "        .. q(mono_manifest)
    if p.mono_transpose ~= 0.0 then
      mono_cmd = mono_cmd .. " --mono-transpose " .. p.mono_transpose
    end
    if p.mono_snap == 1 then
      mono_cmd = mono_cmd .. " --mono-snap-semitone"
    elseif p.mono_snap == 2 then
      mono_cmd = mono_cmd .. " --mono-key " .. ROOTS[p.mono_key + 1]
                          .. " --mono-scale " .. ({"major","minor","harmonic_minor","melodic_minor","major_pentatonic","minor_pentatonic","whole_tone","chromatic"})[p.mono_scale + 1]
    end
    if p.mono_portamento > 0 then
      mono_cmd = mono_cmd .. " --mono-portamento " .. p.mono_portamento
    end
    if p.mono_portamento_rand > 0 then
      mono_cmd = mono_cmd .. " --mono-portamento-random " .. p.mono_portamento_rand
    end
    if p.mono_render then
      mono_cmd = mono_cmd .. " --mono-render " .. q(render_path)
    else
      mono_cmd = mono_cmd .. " --rpp " .. q(rpp_path)
    end
    local handle = io.popen(mono_cmd .. " 2>&1")
    local py_out = handle and handle:read("*a") or "(io.popen failed)"
    if handle then handle:close() end
    if not reaper.file_exists(mono_manifest) then
      status_msg = "ERROR: no manifest.\n" .. py_out
      status_ok = false; return
    end
    local fh = io.open(mono_manifest, "r")
    if not fh then status_msg = "ERROR: can't open " .. mono_manifest; status_ok=false; return end
    local json_str = fh:read("*a"); fh:close()
    local manifest, jerr = json.decode(json_str)
    if not manifest then
      status_msg = "ERROR: JSON: " .. (jerr or "?"); status_ok = false; return
    end
    manifest._base_dir = out_dir
    local ok, build_err = build_in_place(manifest, time_offset, insert_after_idx)
    if ok then
      local out_name = render_path:match("([^/\\]+)$") or render_path
      status_msg = p.mono_render
        and ("Done — " .. out_name .. " at " .. string.format("%.2f", time_offset) .. "s")
        or  ("Done — mono envelopes at " .. string.format("%.2f", time_offset) .. "s")
    else
      status_msg = "Errors:\n" .. (build_err or "?"); status_ok = false
    end
    if not p.float_mode then close_next = true end
    return
  end

  local cmd = q(SINESTACKER) .. " " .. q(src_file)
           .. " --rpp "          .. q(rpp_path)
           .. " --manifest "     .. q(manifest_path)
           .. " --max-partials " .. p.max_partials
           .. " --amp-floor "    .. p.amp_floor
           .. " --sort "         .. sort_vals[p.sort + 1]
           .. " --edge "         .. edge_vals[p.edge + 1]
           .. " --channel "      .. channel_cli_arg(p.channel)

  if p.edge == 2 or p.edge == 3 then cmd = cmd .. " --fade-ms " .. p.fade_ms end
  if p.max_simul > 0 then cmd = cmd .. " --max-simultaneous " .. p.max_simul end

  if p.key_enable then
    cmd = cmd
       .. " --key "             .. ROOTS[p.key_root + 1]
       .. " --scale "           .. SCALES[p.key_scale + 1]
       .. " --key-mode "        .. (p.key_mode == 0 and "filter" or "snap")
       .. " --cents-tolerance " .. p.key_cents
  end

  if p.mode == 0 then
    cmd = cmd
       .. " --strategy "  .. strategy_vals[p.strategy + 1]
       .. " --pitch "     .. pitch_vals[p.pitch + 1]
       .. " --amp "       .. pitch_vals[p.amp_mode + 1]
       .. " --sr "        .. SR_VALS[p.sr + 1]
       .. " --bit-depth " .. BD_VALS[p.bit_depth + 1]
  else
    for _, f in ipairs(corpus_folders) do cmd = cmd .. " --corpus " .. q(f) end
    cmd = cmd
       .. " --corpus-tolerance " .. p.corpus_tolerance
       .. " --corpus-repeat "    .. repeat_vals[p.corpus_repeat + 1]
       .. " --corpus-on-miss "   .. on_miss_vals[p.corpus_on_miss + 1]
       .. " --corpus-amp-mode "  .. camp_mode_vals[p.corpus_amp_mode + 1]
       .. " --corpus-length "    .. clength_vals[p.corpus_length + 1]
    if p.corpus_transpose and p.corpus_on_miss == 1 then cmd = cmd .. " --corpus-transpose" end
    if p.corpus_normalize  then cmd = cmd .. " --corpus-normalize"  end
    if p.corpus_rebuild    then cmd = cmd .. " --corpus-rebuild"    end
    if not p.corpus_recursive then cmd = cmd .. " --corpus-no-recursive" end
    if p.corpus_min_pitch_conf > 0 then
      cmd = cmd .. " --corpus-min-pitch-confidence " .. p.corpus_min_pitch_conf
    end
    if p.corpus_max_voices > 0 then
      cmd = cmd .. " --corpus-max-voices " .. p.corpus_max_voices
    end
    if p.corpus_gain ~= 1.0 then cmd = cmd .. " --corpus-gain " .. p.corpus_gain end
    if p.corpus_loudness_weight > 0 then
      cmd = cmd .. " --corpus-loudness-weight " .. p.corpus_loudness_weight
    end
    if p.glide_split > 0 then cmd = cmd .. " --glide-split " .. p.glide_split end
  end

  if p.midi > 0 then
    local midi_path = src_dir .. "/" .. src_base .. "_sines.mid"
    cmd = cmd .. " --midi " .. q(midi_path) .. " --midi-flavour " .. midi_vals[p.midi + 1]
    if p.midi == 2 then
      cmd = cmd .. " --bend-range " .. p.bend_range
               .. " --amp-target "  .. amp_target_vals[p.amp_target + 1]
    end
  end

  local full_cmd = cmd .. " 2>&1"
  local handle   = io.popen(full_cmd)
  local py_out   = handle and handle:read("*a") or "(io.popen failed)"
  if handle then handle:close() end

  if not reaper.file_exists(manifest_path) then
    status_msg = "ERROR: no manifest.\n" .. py_out
    status_ok = false; return
  end

  local fh = io.open(manifest_path, "r")
  if not fh then status_msg = "ERROR: can't open " .. manifest_path; status_ok=false; return end
  local json_str = fh:read("*a"); fh:close()

  local manifest, jerr = json.decode(json_str)
  if not manifest then
    status_msg = "ERROR: JSON: " .. (jerr or "?"); status_ok = false; return
  end
  manifest._base_dir = out_dir   -- media/ is relative to out_dir (project dir), not src_dir

  local ok, build_err = build_in_place(manifest, time_offset, insert_after_idx)
  if ok then
    status_msg = string.format("Done — %d tracks at %.2fs", #manifest.tracks, time_offset)
    if p.corpus_rebuild then p.corpus_rebuild = false; save_state() end
  else
    status_msg = "Errors:\n" .. (build_err or "?"); status_ok = false
  end

  if not p.float_mode then close_next = true end
end

-- ---------------------------------------------------------------- UI helpers
local ctx = nil

-- Inline help marker: grayed (?) after the last widget; hover = wrapped tooltip.
-- ImGui_TextUnformatted was removed in ReaImGui 0.9; use ImGui_Text with % escaped.
local function help(text)
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_TextDisabled(ctx, "(?)")
  if reaper.ImGui_IsItemHovered(ctx) then
    -- BeginTooltip returns bool in ReaImGui 0.9+; only call EndTooltip if it returned true.
    -- Wrapping gsub in () truncates to one return value (avoids "expected 2 arguments" error).
    if reaper.ImGui_BeginTooltip(ctx) then
      reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 32)
      reaper.ImGui_Text(ctx, (text:gsub("%%", "%%%%")))
      reaper.ImGui_PopTextWrapPos(ctx)
      reaper.ImGui_EndTooltip(ctx)
    end
  end
end

local function draw_ui()
  -- Update channel count from selected item every frame.
  local item = reaper.GetSelectedMediaItem(0, 0)
  if item then
    local take = reaper.GetActiveTake(item)
    local src  = take and reaper.GetMediaItemTake_Source(take)
    local f    = src  and reaper.GetMediaSourceFileName(src, "") or ""
    local pos  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local n_ch = src  and reaper.GetMediaSourceNumChannels(src) or 0
    src_channel_count = n_ch
    reaper.ImGui_Text(ctx, "Source: " .. (f:match("[^/\\]+$") or f))
    local ch_label = n_ch > 0 and ("  " .. n_ch .. " ch") or ""
    reaper.ImGui_Text(ctx, string.format("At: %.3f s%s", pos, ch_label))
  else
    src_channel_count = 0
    reaper.ImGui_TextColored(ctx, 0xFF8800FF, "No item selected — will prompt for file")
  end
  -- Show where output will land.
  local proj_dir = reaper.GetProjectPath("")
  if proj_dir and proj_dir ~= "" then
    reaper.ImGui_TextColored(ctx, 0x888888FF, "Out: " .. proj_dir)
  else
    reaper.ImGui_TextColored(ctx, 0xFF8800FF, "No project saved — output goes next to source")
  end
  reaper.ImGui_Separator(ctx)

  do local rv, v = reaper.ImGui_Combo(ctx, "Mode", p.mode, "Sine\0Corpus\0Mono\0\0")
     if rv then p.mode = v end end
  help("Sine: additive resynthesis — one Reaper track per partial with PITCHENV + VOLENV.\n\nCorpus: same analysis but each partial is replaced by a matched real audio file from your library.\n\nMono: tracks a single melodic/vocal line using pyin pitch detection. Outputs one track with PITCHENV + VOLENV following the fundamental. Requires: pip install librosa.")
  reaper.ImGui_Separator(ctx)

  if p.mode == 0 then
    -- ── Sine ──────────────────────────────────────────────────────
    do local rv, v = reaper.ImGui_Combo(ctx, "Strategy", p.strategy,
         "base (envelopes, editable)\0render (pre-baked WAV)\0\0")
       if rv then p.strategy = v end end
    help("base: one shared sine WAV per partial + per-item VOLENV (amplitude) and PITCHENV (pitch deviation in semitones). Envelopes are fully editable after building — drag points in the envelope lane.\n\nrender: pre-renders each partial to its own WAV at the exact pitch and amplitude. Heavier on disk; no envelopes needed; cleanest first test.\n\nEnvelope injection (base) is fragile — uses chunk injection. If envelopes don't appear, switch to render.")
    if p.strategy == 0 then
      reaper.ImGui_TextColored(ctx, 0xFF8800FF, "  envelope injection is fragile — verify")
    end
    do local rv, v = reaper.ImGui_Combo(ctx, "Pitch", p.pitch, "gliding\0static\0\0")
       if rv then p.pitch = v end end
    help("gliding: pitch envelope follows the partial's frequency trajectory over time.\nstatic: pitch locked to the partial's mean frequency for its whole duration.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Amplitude", p.amp_mode, "gliding\0static\0\0")
       if rv then p.amp_mode = v end end
    help("gliding: volume envelope follows the partial's amplitude over time (most expressive).\nstatic: volume locked to the partial's mean amplitude.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Sample rate", p.sr, "96000\048000\044100\0\0")
       if rv then p.sr = v end end
    help("Output WAV sample rate. 96kHz is the default and gives the most headroom for high partials. Match your Reaper project rate if you care about sample-accurate alignment.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Bit depth", p.bit_depth, "24\016\0\0")
       if rv then p.bit_depth = v end end
    help("Output WAV bit depth. 24-bit is almost always correct.")
  elseif p.mode == 1 then
    -- ── Corpus ────────────────────────────────────────────────────
    reaper.ImGui_Text(ctx, "Corpus folders:")
    help("One or more folders of audio files to match against. Each folder is indexed recursively (fundamental freq derived from filename tags or FFT, RMS cached). Click '+ Add folder' to add; click − to remove. Index is cached next to the folder as .sinestacker_corpus_index.json.")
    local to_remove = nil
    for i, f in ipairs(corpus_folders) do
      reaper.ImGui_PushID(ctx, i)
      local avail = reaper.ImGui_GetContentRegionAvail(ctx)
      reaper.ImGui_SetNextItemWidth(ctx, avail - 30)
      local rv, nf = reaper.ImGui_InputText(ctx, "##cf"..i, f)
      if rv then corpus_folders[i] = nf end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "−", 24, 0) then to_remove = i end
      reaper.ImGui_PopID(ctx)
    end
    if to_remove then table.remove(corpus_folders, to_remove) end
    if reaper.ImGui_Button(ctx, "+ Add folder(s)", 0, 0) then
      local picked = pick_folders("Choose one or more corpus folders")
      for _, f in ipairs(picked) do
        -- avoid duplicates
        local already = false
        for _, existing in ipairs(corpus_folders) do
          if existing == f then already = true; break end
        end
        if not already then corpus_folders[#corpus_folders+1] = f end
      end
    end
    help("Cmd-click or Shift-click in the dialog to select multiple folders at once.")
    reaper.ImGui_Separator(ctx)

    do local rv, v = reaper.ImGui_DragDouble(ctx, "Tolerance (¢)",
         p.corpus_tolerance, 1.0, 1.0, 1200.0, "%.0f")
       if rv then p.corpus_tolerance = v end end
    help("Maximum cents distance between a partial's mean frequency and a corpus file's fundamental to count as a valid match. 50¢ = quarter-tone. Tighter = more dropped partials; wider = more off-pitch matches.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Repeat", p.corpus_repeat,
         "strict (each once)\0round-robin\0free (nearest always)\0\0")
       if rv then p.corpus_repeat = v end end
    help("strict: each corpus file used at most once. Partial dropped if no unused file is in range. Best for timbral variety.\n\nround-robin: prefer unused files; when exhausted, reuse the least-used. Never drops a partial.\n\nfree: always pick the nearest-pitch file regardless of prior use. Repeats a lot on small corpora.")
    do local rv, v = reaper.ImGui_Combo(ctx, "On miss", p.corpus_on_miss,
         "drop partial\0use nearest\0\0")
       if rv then p.corpus_on_miss = v end end
    help("What to do when no corpus file falls within the tolerance window.\n\ndrop: omit that partial from the output (default).\n\nuse nearest: take the closest file even if it's outside the tolerance. Enable 'Transpose to pitch' to correct the pitch via PLAYRATE.")
    if p.corpus_on_miss == 1 then
      local rv, v = reaper.ImGui_Checkbox(ctx, "Transpose to pitch (PLAYRATE)", p.corpus_transpose)
      if rv then p.corpus_transpose = v end
      help("With 'use nearest': adjust the item's PLAYRATE so the corpus file's pitch lands on the target frequency. Changes duration (faster = shorter).")
    end
    do local rv, v = reaper.ImGui_Combo(ctx, "Amp mode", p.corpus_amp_mode, "rms\0peak\0\0")
       if rv then p.corpus_amp_mode = v end end
    help("How the partial's loudness is measured when computing item volume.\n\nrms: RMS amplitude — matches the corpus file's own RMS reference. Usually sounds more balanced.\n\npeak: peak amplitude of the partial's envelope.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Length policy", p.corpus_length,
         "reject shorter\0allow any\0\0")
       if rv then p.corpus_length = v end end
    help("reject shorter: only consider corpus files at least as long as the partial duration. Avoids files that cut off mid-partial.\n\nallow any: include shorter files too (they'll ring out early).")
    do local rv, v = reaper.ImGui_Checkbox(ctx, "Ring out (whole file)", p.corpus_whole_file)
       if rv then p.corpus_whole_file = v end end
    help("ON (default): each corpus item plays for the full duration of the source file — the sample rings out naturally past the partial's end.\n\nOFF: item is trimmed to the partial's duration exactly.")
    do local rv, v = reaper.ImGui_Checkbox(ctx, "Normalize (loudest = unity)", p.corpus_normalize)
       if rv then p.corpus_normalize = v end end
    help("Scale all item volumes so the loudest match sits at unity gain. Prevents clipping on dense stacks without touching individual balance.")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Gain (linear)", p.corpus_gain,
         0.01, 0.0, 10.0, "%.2f")
       if rv then p.corpus_gain = v end end
    help("Global linear gain multiplied into every item volume. 1.0 = no change. Use to raise or lower the whole stack without re-running.")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Loudness weight",
         p.corpus_loudness_weight, 0.05, 0.0, 5.0, "%.2f")
       if rv then p.corpus_loudness_weight = v end end
    help("0 = match by pitch only.\n>0 = also prefer corpus files whose recorded dynamic (pp/mf/ff, read from filename tags or measured RMS) matches the partial's relative loudness in the piece.\n\nBlends with pitch score. Try 0.5–2.0. Useful for keeping soft partials soft and loud partials loud using real timbral difference rather than just gain.")
    reaper.ImGui_TextColored(ctx, 0x888888FF, "  0=pitch only  0.5-2=blend w/ dynamic")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Glide split (¢)",
         p.glide_split, 5.0, 0.0, 200.0, "%.0f (0=off)")
       if rv then p.glide_split = v end end
    help("Split a gliding partial into stepped segments when its pitch drifts past this threshold. Each segment is matched independently.\n\n0 = off (glide collapsed to mean frequency).\n50¢ = quarter-tone steps (good default for corpus).\n100¢ = semitone steps.")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextColored(ctx, 0x888888FF, "  Index filters (run at index time, cached)")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Min pitch confidence",
         p.corpus_min_pitch_conf, 0.01, 0.0, 1.0, "%.2f (0=off)")
       if rv then p.corpus_min_pitch_conf = math.max(0.0, math.min(v, 1.0)) end end
    help("0 = off (default). Runs a pyin pitch analysis on each corpus file at index time and drops any file whose voiced fraction is below this threshold.\n\n0.8 = at least 80%% of the file must be clearly pitched. Filters out noisy samples, drum hits, breath sounds, etc.\n\nSlow on first index of a large corpus; cached after. Tick 'Rebuild' to re-run.")
    do local rv, v = reaper.ImGui_InputInt(ctx, "Max voices (0=off)", p.corpus_max_voices)
       if rv then p.corpus_max_voices = math.max(0, v) end end
    help("0 = off (default). Runs a polyphony analysis at index time and drops any file with more simultaneous notes than this value.\n\n1 = monophonic only — rejects chords, scales, and polyphonic recordings. Good for clean single-note sample libraries.\n\nSlow on first index; cached after. Tick 'Rebuild' to re-run.")
    if p.corpus_min_pitch_conf > 0 or p.corpus_max_voices > 0 then
      reaper.ImGui_TextColored(ctx, 0xFF8800FF, "  index filters active — first run will be slow")
    end
    do local rv, v = reaper.ImGui_Checkbox(ctx, "Rebuild corpus index", p.corpus_rebuild)
       if rv then p.corpus_rebuild = v end end
    help("Force re-scan and re-analyse all corpus folders, ignoring any cached index. Turn on if you added new files to a corpus folder or changed index filters. Automatically turned off after a successful run.")
    do local rv, v = reaper.ImGui_Checkbox(ctx, "Scan subfolders (recursive)", p.corpus_recursive)
       if rv then p.corpus_recursive = v end end
    help("ON (default): scan corpus folders and all subfolders recursively.\nOFF: only look at files directly in each corpus folder, ignoring subfolders.")

  elseif p.mode == 2 then
    -- ── Mono ──────────────────────────────────────────────────────
    reaper.ImGui_TextColored(ctx, 0x88CCFFFF, "pyin fundamental tracking (requires librosa)")
    reaper.ImGui_Separator(ctx)
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Confidence gate",
         p.mono_confidence, 0.01, 0.0, 1.0, "%.2f")
       if rv then p.mono_confidence = math.max(0.0, math.min(v, 1.0)) end end
    help("Voiced-probability threshold from pyin (0-1). Frames below this are treated as unvoiced (breath, silence, consonants).\n\n0.5 = default, good starting point.\n0.7-0.8 = tighter, drops uncertain frames — cleaner envelopes on clear singing.\n0.3 = loose, keeps more frames including weak tone.")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Smooth (ms)",
         p.mono_smooth_ms, 1.0, 0.0, 200.0, "%.0f")
       if rv then p.mono_smooth_ms = math.max(0.0, v) end end
    help("Median filter width in ms applied to the f0 curve after confidence gating. Removes semitone-level jitter on sustained notes without affecting portamento.\n\n0 = off.\n20 ms = default (2 frames at 10 ms hop).\n50-100 ms = more aggressive smoothing, good for vibrato reduction.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Unvoiced frames", p.mono_unvoiced,
         "silence (VOLENV to 0)\0drop (interpolate)\0fill f0 (amp to 0)\0\0")
       if rv then p.mono_unvoiced = v end end
    help("How to handle frames pyin judges as unvoiced (breath, consonants, rests).\n\nsilence: VOLENV drops to 0, PITCHENV holds last value. Gap is silent but pitch doesn't jump. Default.\n\ndrop: no breakpoints emitted — Reaper linearly interpolates across the gap. Smooth but pitch continues through silence.\n\nfill f0: pitch is linearly interpolated across the gap, volume still goes to 0. Good for legato lines with short gaps.")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextColored(ctx, 0x888888FF, "  Frequency search range")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "fmin (Hz)",
         p.mono_fmin, 1.0, 20.0, 500.0, "%.0f")
       if rv then p.mono_fmin = math.max(20.0, v) end end
    help("Lowest frequency pyin will consider as a valid fundamental.\n\nC2 = 65 Hz (default) — good for most voices and instruments.\nLower to 40 Hz for bass guitar / baritone.\nRaise to 150 Hz for flute or high soprano to avoid octave errors.")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "fmax (Hz)",
         p.mono_fmax, 10.0, 200.0, 8000.0, "%.0f")
       if rv then p.mono_fmax = math.max(p.mono_fmin + 100, v) end end
    help("Highest frequency pyin will consider.\n\n2000 Hz (default) covers most voices and instruments up to ~B6.\nLower to 800 Hz for bass or bass guitar to prevent octave-up jumps.\nRaise to 4000+ for piccolo or synth leads with very high range.")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextColored(ctx, 0x888888FF, "  Output")
    do local rv, v = reaper.ImGui_Checkbox(ctx, "Render WAV", p.mono_render)
       if rv then p.mono_render = v end end
    help("When checked (default): synthesizes a sine-wave resynthesis WAV from the tracked pitch and amplitude, and places it as a plain audio item underneath the original.\n\nWhen unchecked: generates a looped base-sine item with PITCHENV and VOLENV automation envelopes instead. Use this if you want to retune or re-shape the envelopes by hand in Reaper.")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextColored(ctx, 0x888888FF, "  Pitch / Harmony")
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Transpose (semitones)",
         p.mono_transpose, 0.5, -24.0, 24.0, "%+.1f")
       if rv then p.mono_transpose = v end end
    help("Shift the tracked pitch up or down by this many semitones before rendering.\n\n+7 = perfect fifth\n+4 = major third\n+3 = minor third\n+12 = octave up\n-12 = octave down\n\nCombine with Snap to keep harmonies in tune.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Pitch snap", p.mono_snap,
         "None\0Semitone (equal tempered)\0Key + Scale\0\0")
       if rv then p.mono_snap = v end end
    help("None: pitch follows the raw tracking (with smoothing).\n\nSemitone: snap each frame to the nearest equal-tempered note. Good for locking a wobbly line to clean intervals before transposing.\n\nKey + Scale: snap to the nearest allowed pitch class in the chosen key and scale. Essential for harmony — keeps all voices on the same pitches as the original.")
    if p.mono_snap == 2 then
      do local rv, v = reaper.ImGui_Combo(ctx, "Key", p.mono_key,
           "C\0C#\0D\0D#\0E\0F\0F#\0G\0G#\0A\0A#\0B\0\0")
         if rv then p.mono_key = v end end
      do local rv, v = reaper.ImGui_Combo(ctx, "Scale", p.mono_scale,
           "major\0minor\0harmonic minor\0melodic minor\0major pent\0minor pent\0whole tone\0chromatic\0\0")
         if rv then p.mono_scale = v end end
    end
    if p.mono_snap > 0 then
      do local rv, v = reaper.ImGui_DragDouble(ctx, "Portamento (ms)",
           p.mono_portamento, 1.0, 0.0, 500.0, "%.0f (0=off)")
         if rv then p.mono_portamento = math.max(0.0, v) end end
      help("Glide time in ms between pitch snap transitions. The pitch chases the target using exponential smoothing in semitone space — identical to analog synth portamento.\n\n0 = instant snap (default).\n30-80 ms = subtle, keeps articulation clear.\n100-200 ms = obvious glide between notes.\n\nOnly active when Pitch snap is on.")
      do local rv, v = reaper.ImGui_DragDouble(ctx, "Portamento random ± (ms)",
           p.mono_portamento_rand, 1.0, 0.0, 300.0, "%.0f (0=deterministic)")
         if rv then p.mono_portamento_rand = math.max(0.0, v) end end
      help("Randomise the portamento time ± this many ms per note transition.\n\n0 = all glides the same length (deterministic).\n30 ms = slight variation — feels more human.\n100+ ms = wide variation, some transitions fast, some slow.\n\nThe random value is drawn fresh for every snap transition.")
    end
  end

  reaper.ImGui_Separator(ctx)

  -- ── Key filter / Density / MIDI — hidden in Mono mode ────────
  if p.mode ~= 2 then

  -- ── Key filter ────────────────────────────────────────────────
  do local rv, v = reaper.ImGui_Checkbox(ctx, "Key filter", p.key_enable)
     if rv then p.key_enable = v end end
  help("Filter or retune partials to a musical key/scale before building.\n\nfilter: drop partials whose mean frequency falls outside the tolerance window of any allowed pitch class.\n\nsnap: keep all partials but retune each one onto the nearest allowed pitch (preserves glide shape by ratio shift).")
  if p.key_enable then
    do local rv, v = reaper.ImGui_Combo(ctx, "Root", p.key_root,
         "C\0C#\0D\0D#\0E\0F\0F#\0G\0G#\0A\0A#\0B\0\0")
       if rv then p.key_root = v end end
    do local rv, v = reaper.ImGui_Combo(ctx, "Scale", p.key_scale,
         "major\0minor\0harmonic minor\0melodic minor\0major pent\0minor pent\0whole tone\0chromatic\0\0")
       if rv then p.key_scale = v end end
    do local rv, v = reaper.ImGui_Combo(ctx, "Key mode", p.key_mode, "filter\0snap\0\0")
       if rv then p.key_mode = v end end
    do local rv, v = reaper.ImGui_DragDouble(ctx, "Key tolerance (¢)", p.key_cents,
         1.0, 1.0, 600.0, "%.0f")
       if rv then p.key_cents = v end end
    help("How close (in cents) a partial's mean frequency must be to an allowed pitch class to pass the filter or be snapped onto it. 50¢ = quarter-tone window either side.")
  end
  reaper.ImGui_Separator(ctx)

  -- ── Density / declick / channel ────────────────────────────────
  do local rv, v = reaper.ImGui_InputInt(ctx, "Max partials", p.max_partials)
     if rv then p.max_partials = math.max(1, math.min(v, 2000)) end end
  help("Hard cap on the total number of partials kept (loudest N survive). Reaper slows noticeably past ~500 items; 60–120 is a good starting range for dense material.")
  do local rv, v = reaper.ImGui_DragDouble(ctx, "Amp floor (dBFS)",
       p.amp_floor, 0.5, -120.0, 0.0, "%.1f")
     if rv then p.amp_floor = v end end
  help("Drop any partial whose peak amplitude is below this threshold. −60 dBFS drops very quiet partials that would be inaudible anyway. Raise toward −40 to thin out further.")
  do local rv, v = reaper.ImGui_InputInt(ctx, "Max simultaneous (0=off)", p.max_simul)
     if rv then p.max_simul = math.max(0, v) end end
  help("Vertical density cap: at any moment in time, keep only the N loudest simultaneously sounding partials. Independent of max partials (which caps the total across the piece). Useful for controlling polyphony over time, e.g. max 16 simultaneous voices.")
  do local rv, v = reaper.ImGui_Combo(ctx, "Sort", p.sort,
       "freq (highest top)\0partial (energy rank)\0\0")
     if rv then p.sort = v end end
  help("Track order in Reaper.\n\nfreq: highest-frequency partial at the top, descending — mirrors a score layout.\n\npartial: ordered by energy rank (loudest partial first).")
  do local rv, v = reaper.ImGui_Combo(ctx, "Declick", p.edge,
       "none\0zero crossing\0fade\0both\0\0")
     if rv then p.edge = v end end
  help("Reduce clicks at partial start/end.\n\nnone: raw edges (fastest, may click on attack/release).\n\nzero crossing: snap edges to nearest zero crossing in the source (render strategy only).\n\nfade: add a short Reaper item fade/fade-out (works with both strategies, fully editable).\n\nboth: zero crossing + fade.")
  if p.edge == 2 or p.edge == 3 then
    local rv, v = reaper.ImGui_DragDouble(ctx, "Fade ms", p.fade_ms, 0.5, 0.1, 200.0, "%.1f")
    if rv then p.fade_ms = v end
    help("Length of the item fade-in and fade-out in milliseconds. 5ms is a good default for declicking without affecting the attack character.")
  end
  -- Channel combo: dynamic when an item is selected (mirrors item properties),
  -- static fallback when nothing is selected.
  do
    local ch_str, max_idx
    if src_channel_count > 0 then
      local parts = {"Mix (sum all)"}
      for i = 1, src_channel_count do parts[#parts+1] = "Ch " .. i end
      parts[#parts+1] = "Each (all separate)"
      ch_str  = table.concat(parts, "\0") .. "\0\0"
      max_idx = src_channel_count + 1
    else
      ch_str  = "Mix (sum all)\0Ch 1\0Ch 2\0Ch 3\0Ch 4\0Each (all separate)\0\0"
      max_idx = 5
    end
    if p.channel > max_idx then p.channel = 0 end
    local rv, v = reaper.ImGui_Combo(ctx, "Channel", p.channel, ch_str)
    if rv then p.channel = v end
  end
  help("Which channel(s) of the source to analyze.\n\nMix: average all channels to mono (default).\nCh N: analyze only that channel.\nEach: analyze every channel independently — one folder of tracks per channel. Item count multiplies by channel count; watch density caps.\n\nCombo updates to show the actual channel count of the selected item.")
  reaper.ImGui_Separator(ctx)

  -- ── MIDI ──────────────────────────────────────────────────────
  do local rv, v = reaper.ImGui_Combo(ctx, "MIDI", p.midi, "none\0multitrack\0mpe\0\0")
     if rv then p.midi = v end end
  help("Also export a MIDI file alongside the .rpp.\n\nnone: no MIDI.\n\nmultitrack: one MIDI track per partial, pitch via note + bend, amplitude via the chosen amp target.\n\nmpe: MPE format — one MIDI channel per partial (channels 2–16), per-note pitch bend and pressure. Load into Serum 2, Roli, etc.")
  if p.midi == 2 then
    do local rv, v = reaper.ImGui_InputInt(ctx, "Bend range (st)", p.bend_range)
       if rv then p.bend_range = math.max(1, math.min(v, 96)) end end
    help("Semitone range for MPE pitch bend. Must match the setting in your synth (Serum 2: set MPE bend range to this value). 48 semitones = ±4 octaves, which covers most partial frequency ranges.")
    do local rv, v = reaper.ImGui_Combo(ctx, "Amp target", p.amp_target,
         "pressure (aftertouch)\0cc11 (expression)\0\0")
       if rv then p.amp_target = v end end
    help("Which MIDI message carries amplitude.\n\npressure (aftertouch): MPE per-note pressure — Serum 2 reads this natively for modulation.\n\ncc11 (expression): CC11 on the note's channel — broader synth compatibility but not true MPE.")
  end
  reaper.ImGui_Separator(ctx)

  end -- mode ~= 2 (Mono) guard

  do local rv, v = reaper.ImGui_Checkbox(ctx, "Wrap in folder track", p.wrap_folder)
     if rv then p.wrap_folder = v end end
  help("Insert a parent folder track named after the source file, containing all generated partial tracks. Makes the stack collapsible and easy to move as a unit.")
  reaper.ImGui_Separator(ctx)

  local avail = reaper.ImGui_GetContentRegionAvail(ctx)
  if reaper.ImGui_Button(ctx, "  Run  ", avail * 0.45, 0) then run(); save_state() end
  if status_msg ~= "" then
    reaper.ImGui_TextColored(ctx, status_ok and 0x44FF44FF or 0xFF4444FF, status_msg)
  end
  reaper.ImGui_Separator(ctx)

  do local rv, v = reaper.ImGui_Checkbox(ctx, "Float (keep panel open)", p.float_mode)
     if rv then p.float_mode = v; save_state() end end
  help("Checked: panel stays open after Run so you can tweak params and run again.\nUnchecked: panel closes automatically once Run completes.")

  -- ── How to use (collapsible) ──────────────────────────────────
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_CollapsingHeader(ctx, "How to use") then
    reaper.ImGui_PushTextWrapPos(ctx, 420)
    -- ImGui_TextUnformatted removed in ReaImGui 0.9; use ImGui_Text with %% escaped.
    reaper.ImGui_Text(ctx,
[[SINE MODE
Analyzes audio into tracked sinusoidal partials (via Loris). Each partial becomes one Reaper track with a pitch + volume envelope.

  base strategy: one shared sine WAV per partial with VOLENV and PITCHENV take envelopes. Editable after building - drag envelope points in the lane. Envelope injection is fragile; render is safer for first tests.

  render strategy: pre-renders each partial to its own WAV. No envelopes, heavier disk use, cleanest drop-in.

CORPUS MODE
Same analysis, but each partial is replaced by a real audio file from your folders whose fundamental is nearest the partial's frequency. Files placed naked at the partial's onset with a single static item volume.

  Add folders with '+ Add folder'. Multiple folders are pooled. Index is cached next to each folder; tick 'Rebuild' only after adding new files.

  Tolerance: how far in cents a file's pitch can be from the partial and still count.
  Repeat: strict = each file once; round-robin = prefer unused; free = nearest always.
  On miss: drop the partial, or use the nearest file (optionally PLAYRATE-transposed).

WORKFLOW
1. Select an audio item in your project (its start position is used for placement).
2. Set Mode, adjust params.
3. Click Run.
4. Tracks appear immediately in your current project at the item's timeline position.
5. With Float on, tweak and re-run. Each run adds a new stack; undo (Ctrl+Z) to remove.

TIPS
- Start with render strategy - no fragile envelope injection.
- Max partials 40-80 is a good starting point; raise after confirming performance.
- Amp floor -60 removes inaudible partials; raise to -40 to thin further.
- Max simultaneous caps live polyphony independent of total partials.
- Key filter + snap is useful for tonal material - snaps all partials onto a scale.]])
    reaper.ImGui_PopTextWrapPos(ctx)
  end
end

-- ---------------------------------------------------------------- Loop
-- ImGui_DestroyContext was removed in ReaImGui 0.9 — contexts are reference-counted
-- and cleaned up automatically. Setting ctx = nil is sufficient to stop the loop.
local function loop()
  if close_next then ctx = nil; return end
  reaper.ImGui_SetNextWindowSize(ctx, 440, 720, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, "Sine Stacker", true)
  if visible then draw_ui(); reaper.ImGui_End(ctx) end
  if open then reaper.defer(loop)
  else ctx = nil end
end

-- ---------------------------------------------------------------- Entry
if not reaper.APIExists("ImGui_CreateContext") then
  reaper.ShowMessageBox(
    "Requires ReaImGui.\n\nInstall via ReaPack:\n  Extensions > ReaPack > Browse packages\n"
    .. "  Search: ReaImGui  |  Install: cfillion/ReaImGui\n\nThen restart Reaper.",
    "Sine Stacker — missing dependency", 0)
  return
end

load_state()
ctx = reaper.ImGui_CreateContext("SineStacker_v2")
reaper.defer(loop)
