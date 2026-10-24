-- Cue export jobs, run over the time selection (or the region under the edit cursor):
--   improve / orch      stems + master + mix minus + one multichannel MIDI file, for
--                       tracks marked with leading all-caps name tokens (IM / REC, TR)
--   multitrack_dry/wet  every lowest-level track, rendered via master (dry mutes Effects)
-- No dialogs: render config comes from presets in reaper-render.ini, then either
-- "Render using most recent settings" (42230) or "Add to render queue" (41823).

local M = {}

local PPQ = 960
-- Source flags: 128 = selected tracks via master; 524288 = "Via master, fast" (all stems in one pass).
-- 524416 is what the Film IMPROVE / Film ORCH presets and REAPER's own saved projects use.
local STEMS_SETTINGS = 524416
local RENDER_ACTION = 42230 -- File: Render project, using the most recent settings, auto-close dialog

local RENDER_KEYS = { "RENDER_SETTINGS", "RENDER_BOUNDSFLAG", "RENDER_STARTPOS", "RENDER_ENDPOS",
    "RENDER_TAILFLAG", "RENDER_SRATE", "RENDER_CHANNELS", "RENDER_NORMALIZE",
    "RENDER_NORMALIZE_TARGET", "RENDER_BRICKWALL" }
local RENDER_STRINGS = { "RENDER_FILE", "RENDER_PATTERN", "RENDER_FORMAT" }

-- Progress is silent (no console window); problems and skips surface in a message box
local function msg() end
local function alert(text) reaper.ShowMessageBox(text, "Cue export", 0) end

local function sanitize(name) return (name:gsub('[\\/:*?"<>|]', "_")) end

-- Marks ------------------------------------------------------------------

local function track_name(track)
    local _, name = reaper.GetTrackName(track)
    return name
end

-- True if one of the leading all-caps tokens of the track name is in `marks`
local function has_mark(name, marks)
    for token in name:gmatch("%S+") do
        if not token:match("^%u+$") then return false end
        if marks[token] then return true end
    end
    return false
end

-- "Click" (ours / the template's) or "Click Track" (what SWS/AW would name it); exact names
-- only, so sound-design tracks that merely contain the word are left alone
local function is_click_name(name)
    name = name:lower()
    return name == "click" or name == "click track"
end

-- A track whose first item is a click source (SWS/AW leaves its track unnamed)
local function has_click_item(tr)
    local item = reaper.GetTrackMediaItem(tr, 0)
    local take = item and reaper.GetActiveTake(item)
    if not take then return false end
    local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    return name:lower():find("click source", 1, true) ~= nil
end

-- Folders whose contents never go out (sound design, video, session plumbing)
local EXCLUDED_FOLDERS = { effects = true, movie = true, utility = true }

-- Wrapper folders that don't count as a level (everything sits inside the master sub-mix)
local TRANSPARENT_FOLDERS = { ["music sub mix"] = true }

-- Every track in order, with its folder depth, whether it's visible, and
-- whether it is (or sits inside) an excluded folder
local function scan_tracks()
    local list, stack = {}, {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local name = track_name(tr)
        local depth = reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        local excluded = EXCLUDED_FOLDERS[name:lower()] and true or false
        for _, ancestor in ipairs(stack) do if EXCLUDED_FOLDERS[ancestor:lower()] then excluded = true end end
        local elevel = 0
        for _, ancestor in ipairs(stack) do if not TRANSPARENT_FOLDERS[ancestor:lower()] then elevel = elevel + 1 end end
        list[#list + 1] = { track = tr, name = name, depth = depth, excluded = excluded, level = elevel,
            transparent = depth == 1 and TRANSPARENT_FOLDERS[name:lower()] or false,
            click = is_click_name(name) or has_click_item(tr),
            visible = reaper.GetMediaTrackInfo_Value(tr, "B_SHOWINTCP") == 1 }
        if depth == 1 then stack[#stack + 1] = name end
        for _ = 1, math.max(0, -depth) do stack[#stack] = nil end
    end
    return list
end

local function marked_tracks(marks)
    local out = {}
    for _, t in ipairs(scan_tracks()) do
        if not t.excluded and not t.click and has_mark(t.name, marks) then out[#out + 1] = t.track end
    end
    return out
end

-- Cue region -------------------------------------------------------------

-- Innermost region containing `pos` (small tolerance for a cursor parked on a boundary)
local function region_at(pos)
    local best
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local _, is_region, rs, re, name = reaper.EnumProjectMarkers(i)
        if is_region and pos >= rs - 0.01 and pos < re then
            if not best or (re - rs) < (best.finish - best.start) then
                best = { start = rs, finish = re, name = name }
            end
        end
    end
    return best, num_regions
end

-- The project's =START / =END markers, when both exist and are in order
local function start_end_markers()
    local start_pos, end_pos
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local _, is_region, pos, _, name = reaper.EnumProjectMarkers(i)
        if not is_region then
            if name == "=START" then start_pos = pos elseif name == "=END" then end_pos = pos end
        end
    end
    if start_pos and end_pos and end_pos > start_pos then
        return { start = start_pos, finish = end_pos, name = "=START / =END" }
    end
end

-- A time selection wins when set (explicit override), then =START/=END, then
-- the region under the edit cursor. `ignore_time_selection` is for batch runs.
local function cue_region(ignore_time_selection)
    if not ignore_time_selection then
        local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        if ts_end > ts_start then
            return { start = ts_start, finish = ts_end, name = "time selection" }
        end
    end
    local markers = start_end_markers()
    if markers then return markers end
    local cursor = reaper.GetCursorPosition()
    local region, num_regions = region_at(cursor)
    if region then return region end
    return nil, string.format("No cue range: add =START and =END markers or set a time selection (%d regions, cursor at %.3fs).",
        num_regions or 0, cursor)
end

-- Render presets ---------------------------------------------------------

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

-- Pulls format + output settings for `preset_name` out of reaper-render.ini
local function load_preset(preset_name)
    local text = read_file(reaper.GetResourcePath() .. "/reaper-render.ini")
    if not text then return nil, "could not read reaper-render.ini" end
    local preset = {}
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
    local header = '<RENDERPRESET "' .. preset_name .. '" '
    local ext = 'RENDERPRESET_EXT "' .. preset_name .. '" '
    local output = 'RENDERPRESET_OUTPUT "' .. preset_name .. '" '
    for i, line in ipairs(lines) do
        if line:sub(1, #header) == header then
            local srate, chans = line:sub(#header + 1):match("^(%d+) (%d+)")
            preset.srate, preset.channels = tonumber(srate), tonumber(chans)
            preset.format = (lines[i + 1] or ""):match("^%s*(%S+)")
        elseif line:sub(1, #ext) == ext then
            -- flags (&1 normalize, &64 brickwall limiter), normalize target, limiter threshold
            local flags, target, brick = line:sub(#ext + 1):match("^(%S+) (%S+) (%S+)")
            preset.norm_flags, preset.norm_target, preset.brickwall =
                tonumber(flags), tonumber(target), tonumber(brick)
        elseif line:sub(1, #output) == output then
            local bounds, s, e, settings, tail, pattern, tailms, dir =
                line:sub(#output + 1):match('^(%S+) (%S+) (%S+) (%S+) (%S+) "([^"]*)" (%S+) "?([^"]-)"? ')
            preset.bounds, preset.start, preset.finish = tonumber(bounds), tonumber(s), tonumber(e)
            preset.settings, preset.tailflag = tonumber(settings), tonumber(tail)
            preset.pattern, preset.dir = pattern, dir
        end
    end
    if not preset.pattern or not preset.srate then
        return nil, 'render preset "' .. preset_name .. '" not found in reaper-render.ini'
    end
    return preset
end

local function save_render_state()
    local state = { nums = {}, strs = {} }
    for _, k in ipairs(RENDER_KEYS) do state.nums[k] = reaper.GetSetProjectInfo(0, k, 0, false) end
    for _, k in ipairs(RENDER_STRINGS) do
        local _, v = reaper.GetSetProjectInfo_String(0, k, "", false)
        state.strs[k] = v
    end
    return state
end

local function restore_render_state(state)
    for k, v in pairs(state.nums) do reaper.GetSetProjectInfo(0, k, v, true) end
    for k, v in pairs(state.strs) do reaper.GetSetProjectInfo_String(0, k, v, true) end
end

local function apply_render(preset, region, pattern, settings, norm)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", settings, true)
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, true) -- custom range = cue region
    reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", region.start, true)
    reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", region.finish, true)
    reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", preset.tailflag or 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", preset.srate, true)
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", preset.channels, true)
    -- norm = a loaded preset to take normalize/limiter from; nil means off
    -- (stems and mix minus stay at source level)
    reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", norm and norm.norm_flags or 0, true)
    if norm then
        reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", norm.norm_target, true)
        reaper.GetSetProjectInfo(0, "RENDER_BRICKWALL", norm.brickwall, true)
    end
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", preset.dir, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", pattern, true)
    if preset.format then reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", preset.format, true) end
end

local function describe_render(label)
    local function num(k) return reaper.GetSetProjectInfo(0, k, 0, false) end
    local _, pattern = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)
    msg(string.format("  [%s] source=%d srate=%d ch=%d normalize=%d target=%.4f range=%.3f-%.3f pattern=%s",
        label, num("RENDER_SETTINGS"), num("RENDER_SRATE"), num("RENDER_CHANNELS"),
        num("RENDER_NORMALIZE"), num("RENDER_NORMALIZE_TARGET"), num("RENDER_STARTPOS"), num("RENDER_ENDPOS"), pattern))
end

local function render_targets()
    local _, targets = reaper.GetSetProjectInfo_String(0, "RENDER_TARGETS", "", false)
    local out = {}
    for path in targets:gmatch("[^;]+") do out[#out + 1] = path end
    return out
end

-- MIDI -------------------------------------------------------------------

local function vlq(n)
    local bytes = { n & 0x7F }
    n = n >> 7
    while n > 0 do
        table.insert(bytes, 1, (n & 0x7F) | 0x80)
        n = n >> 7
    end
    return string.char(table.unpack(bytes))
end

local function chunk(tag, data) return tag .. string.pack(">I4", #data) .. data end

-- Channel events from every unmuted MIDI item overlapping the region, as
-- { tick, order, bytes } with tick relative to region start (note-offs only
-- kept when their note-on was kept).
local function collect_midi(track, region)
    local start_qn = reaper.TimeMap2_timeToQN(0, region.start)
    local end_qn = reaper.TimeMap2_timeToQN(0, region.finish)
    local events = {}
    for i = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local ilen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) and reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 0
            and ipos < region.finish and ipos + ilen > region.start then
            -- the take can show only part of its source, so clip to the item too
            local lo_qn = math.max(start_qn, reaper.TimeMap2_timeToQN(0, ipos))
            local hi_qn = math.min(end_qn, reaper.TimeMap2_timeToQN(0, ipos + ilen))
            local _, buf = reaper.MIDI_GetAllEvts(take, "")
            local ppq, pos = 0, 1
            local open = {}
            while pos <= #buf - 8 do
                local offset, flags, len = string.unpack("<i4Bi4", buf, pos)
                local m = buf:sub(pos + 9, pos + 8 + len)
                pos = pos + 9 + len
                ppq = ppq + offset
                local status = m:byte(1)
                if status and status >= 0x80 and status < 0xF0 and flags & 2 == 0 then
                    local qn = reaper.MIDI_GetProjQNFromPPQPos(take, ppq)
                    local kind, chan = status & 0xF0, status & 0x0F
                    local key = chan * 128 + (m:byte(2) or 0)
                    local keep
                    if kind == 0x90 and (m:byte(3) or 0) > 0 then
                        keep = qn >= lo_qn and qn < hi_qn
                        open[key] = keep or nil
                    elseif kind == 0x80 or kind == 0x90 then
                        keep = open[key]
                        open[key] = nil
                        if keep and qn > hi_qn then qn = hi_qn end
                    else
                        keep = qn >= lo_qn and qn < hi_qn
                    end
                    if keep then
                        local tick = math.max(0, math.floor((qn - start_qn) * PPQ + 0.5))
                        local is_off = kind == 0x80 or (kind == 0x90 and (m:byte(3) or 0) == 0)
                        events[#events + 1] = { tick = tick, order = is_off and 0 or 1, bytes = m, n = #events }
                    end
                end
            end
        end
    end
    table.sort(events, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        if a.order ~= b.order then return a.order < b.order end
        return a.n < b.n
    end)
    return events
end

-- SMPTE offset meta event: the timecode of the cue start (project offset included)
local function smpte_offset(t)
    local fps = reaper.TimeMap_curFrameRate(0)
    local code = fps < 24.5 and 0 or fps < 27 and 1 or fps < 29.98 and 2 or 3
    local rate = ({ 24, 25, 29.97, 30 })[code + 1]
    local secs = math.max(0, t + reaper.GetProjectTimeOffset(0, false))
    local whole = math.floor(secs)
    local fr = math.min(math.floor((secs - whole) * rate), 29)
    return "\xFF\x54\x05" .. string.char((whole // 3600 % 24) | (code << 5), whole // 60 % 60, whole % 60, fr, 0)
end

-- Tempo track: tempo, time signature, SMPTE offset and project markers
-- inside the cue range, all relative to the cue start
local function tempo_track(region)
    local evs = {}
    local function add(tick, data) evs[#evs + 1] = { tick = tick, data = data, n = #evs } end
    local start_qn = reaper.TimeMap2_timeToQN(0, region.start)
    local function tick_at(t) return math.max(0, math.floor((reaper.TimeMap2_timeToQN(0, t) - start_qn) * PPQ + 0.5)) end
    local num, den, bpm = reaper.TimeMap_GetTimeSigAtTime(0, region.start) -- returns num, denom, tempo
    add(0, smpte_offset(region.start))
    add(0, "\xFF\x51\x03" .. string.pack(">I3", math.floor(60000000 / bpm + 0.5)))
    add(0, "\xFF\x58\x04" .. string.char(num, math.floor(math.log(den, 2) + 0.5), 24, 8))
    for i = 0, reaper.CountTempoTimeSigMarkers(0) - 1 do
        local _, t, _, _, mbpm, num, den = reaper.GetTempoTimeSigMarker(0, i)
        if t > region.start and t < region.finish then
            local tick = tick_at(t)
            if num and num > 0 then
                add(tick, "\xFF\x58\x04" .. string.char(num, math.floor(math.log(den, 2) + 0.5), 24, 8))
            end
            if mbpm and mbpm > 0 then
                add(tick, "\xFF\x51\x03" .. string.pack(">I3", math.floor(60000000 / mbpm + 0.5)))
            end
        end
    end
    local _, nmarkers, nregions = reaper.CountProjectMarkers(0)
    for i = 0, nmarkers + nregions - 1 do
        local _, isrgn, pos, _, name = reaper.EnumProjectMarkers(i)
        if not isrgn and pos >= region.start and pos < region.finish and name ~= "" and name ~= "=START" and name ~= "=END" then
            add(tick_at(pos), "\xFF\x06" .. vlq(#name) .. name)
        end
    end
    table.sort(evs, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        return a.n < b.n
    end)
    local out, last = {}, 0
    for _, ev in ipairs(evs) do
        out[#out + 1] = vlq(ev.tick - last) .. ev.data
        last = ev.tick
    end
    out[#out + 1] = vlq(0) .. "\xFF\x2F\x00"
    return chunk("MTrk", table.concat(out))
end

-- Channel order: 1-9, 11-16, then 10 last (drums by GM convention)
local CHANNELS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 9 }

-- One format-1 file: tempo track + a single MTrk with every track's MIDI,
-- each source track rewritten onto its own channel. A text event at tick 0
-- per channel says which track it was. Returns { count, skipped }.
local function write_midi(tracks, region, path)
    local merged, labels, skipped = {}, {}, 0
    for _, tr in ipairs(tracks) do
        local events = collect_midi(tr, region)
        if #events > 0 then
            local chan = CHANNELS[#labels + 1]
            if chan then
                labels[#labels + 1] = "Ch " .. (chan + 1) .. ": " .. track_name(tr)
                for _, ev in ipairs(events) do
                    ev.bytes = string.char((ev.bytes:byte(1) & 0xF0) | chan) .. ev.bytes:sub(2)
                    ev.n = #merged
                    merged[#merged + 1] = ev
                end
            else
                skipped = skipped + 1
            end
        end
    end
    if #labels == 0 then return 0, skipped end
    table.sort(merged, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        if a.order ~= b.order then return a.order < b.order end
        return a.n < b.n
    end)
    local body = {}
    for _, label in ipairs(labels) do body[#body + 1] = vlq(0) .. "\xFF\x01" .. vlq(#label) .. label end
    local last = 0
    for _, ev in ipairs(merged) do
        body[#body + 1] = vlq(ev.tick - last) .. ev.bytes
        last = ev.tick
    end
    body[#body + 1] = vlq(0) .. "\xFF\x2F\x00"
    local smf = chunk("MThd", string.pack(">I2I2I2", 1, 2, PPQ))
        .. tempo_track(region) .. chunk("MTrk", table.concat(body))
    local f = assert(io.open(path, "wb"))
    f:write(smf)
    f:close()
    return #labels, skipped
end

-- Tempo and time-signature map only, aligned to the start of the cue range
local function write_tempo_map(region, path)
    local smf = chunk("MThd", string.pack(">I2I2I2", 1, 1, PPQ)) .. tempo_track(region)
    local f = assert(io.open(path, "wb"))
    f:write(smf)
    f:close()
end

-- Every MIDI track in the cue as its own MTrk (original channels kept, no
-- 16-channel limit), after the tempo track. Returns the number of tracks.
local function write_project_midi(region, path)
    local trks = {}
    for _, t in ipairs(scan_tracks()) do
        if not t.excluded and not t.click then
            local events = collect_midi(t.track, region)
            if #events > 0 then
                local name = track_name(t.track)
                local body, last = { vlq(0) .. "\xFF\x03" .. vlq(#name) .. name }, 0
                for _, ev in ipairs(events) do
                    body[#body + 1] = vlq(ev.tick - last) .. ev.bytes
                    last = ev.tick
                end
                body[#body + 1] = vlq(0) .. "\xFF\x2F\x00"
                trks[#trks + 1] = chunk("MTrk", table.concat(body))
            end
        end
    end
    if #trks == 0 then return 0 end
    local smf = chunk("MThd", string.pack(">I2I2I2", 1, #trks + 1, PPQ)) .. tempo_track(region) .. table.concat(trks)
    local f = assert(io.open(path, "wb"))
    f:write(smf)
    f:close()
    return #trks
end

-- Jobs ------------------------------------------------------------------

M.jobs = {
    prox = { kind = "prox", label = "PROX" },
    improve = { kind = "stems", label = "IMPROVE", marks = { IM = true }, mark_names = { "IM" }, preset = "Film IMPROVE" },
    orch = { kind = "stems", label = "ORCH", marks = { REC = true, TR = true }, mark_names = { "REC", "TR" }, preset = "Film ORCH" },
    multitrack_dry = { kind = "multitrack", label = "multitrack dry", preset = "Film Multitrack Dry", mute_effects = true },
    multitrack_wet = { kind = "multitrack", label = "multitrack wet", preset = "Film Multitrack Wet" },
}
M.job_order = { "prox", "improve", "orch", "multitrack_dry", "multitrack_wet" }

M.marked_tracks = marked_tracks
M.cue_region = cue_region

local function dirname(path) return path:match("^(.*)[\\/]") end

local function project_dir()
    local _, path = reaper.EnumProjects(-1)
    return dirname(path)
end

-- Where a preset will write, for queued renders (nothing on disk to read back yet)
local function expected_dir(preset, project_name, pattern)
    local dir = preset.dir:gsub("^%./", "")
    if dir:sub(1, 1) ~= "/" then dir = project_dir() .. "/" .. dir end
    local pattern_dir = (pattern or preset.pattern):match("^(.*)/[^/]*$")
    if pattern_dir then dir = dir .. "/" .. pattern_dir:gsub("%$project", project_name) end
    return dir
end

local function start_timecode(region)
    return (reaper.format_timestr_pos(region.start, "", 5):gsub("[:;]", "."))
end

-- Export log: one line per event in <exports>/<project>/_export_log.tsv, appended and
-- closed every time so a REAPER crash leaves a trail. Columns: time, job, state
-- (start, step, queued, done, error), cue start timecode, detail. Skipped jobs
-- and MIDI-only runs write nothing.
local function set_log(ctx, job, preset)
    if ctx.midi_only then return end
    ctx.log_job, ctx.log_tc = job.label, start_timecode(ctx.region)
    ctx.log_dir = expected_dir(preset, ctx.project_name, "$project/x")
end

local function log_event(ctx, state, detail)
    if not ctx.log_dir then return end
    reaper.RecursiveCreateDirectory(ctx.log_dir, 0)
    local f = io.open(ctx.log_dir .. "/_export_log.tsv", "ab")
    if not f then return end
    local clean = ((detail or ""):gsub("[\t\r\n]", " "))
    f:write(table.concat({ os.date("%Y-%m-%d %H:%M:%S"), ctx.log_job, state, ctx.log_tc, clean }, "\t"), "\n")
    f:close()
end

local function starts_with(s, p) return s:sub(1, #p) == p end
local function ends_with(s, p) return p == "" or s:sub(-#p) == p end

local function list_files(dir)
    local names, i = {}, 0
    while true do
        local n = reaper.EnumerateFiles(dir, i)
        if not n then break end
        names[#names + 1] = n
        i = i + 1
    end
    return names
end

local function list_subdirs(dir)
    local names, i = {}, 0
    while true do
        local n = reaper.EnumerateSubdirectories(dir, i)
        if not n then break end
        names[#names + 1] = n
        i = i + 1
    end
    return names
end

-- REAPER names files with the render start's timecode, which can land a frame before
-- the cue start we compute (the render range starts a hair early). Returns the timecode
-- the files in `dir` actually use when it is within a frame of `tc`, else `tc`.
local function tc_seconds(tc)
    local h, m, sec, f = tc:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not h then return nil end
    return (tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)) * 30 + tonumber(f)
end

local function near_tc(dir, root, tc)
    local want = tc_seconds(tc)
    if not want then return tc end
    local esc = root:gsub("%p", "%%%0")
    local counts, best = {}, nil
    for _, name in ipairs(list_files(dir)) do
        -- the click is rendered from an item, so its timecode is not the stems' timecode
        if not ends_with(name, " - CLICK.wav") then
            local found = name:match("^_?" .. esc .. " %- (%S+) %- .+%.wav$")
                or name:match(" " .. esc .. " %- (%d+%.%d+%.%d+%.%d+)%-?%d*%.wav$")
            local have = found and tc_seconds(found)
            if have and math.abs(have - want) <= 1 then
                counts[found] = (counts[found] or 0) + 1
                if not best or counts[found] > counts[best] then best = found end
            end
        end
    end
    return best or tc
end

local function file_size(path)
    local f = io.open(path, "rb")
    if not f then return 0 end
    local n = f:seek("end")
    f:close()
    return n or 0
end

-- reqs: { { label, test = function(name) -> bool, min = n }, ... }; every file
-- a requirement counts must be non-empty
local function check_files(dir, reqs)
    local files = list_files(dir)
    local missing, found_any = {}, false
    for _, req in ipairs(reqs) do
        local n = 0
        for _, name in ipairs(files) do
            if req.test(name) and file_size(dir .. "/" .. name) > (name:match("%.wav$") and 44 or 0) then n = n + 1 end
        end
        if n > 0 then found_any = true end
        local min = req.min or 1
        if n < min then
            missing[#missing + 1] = min > 1 and (req.label .. " (" .. n .. " of " .. min .. ")") or req.label
        end
    end
    if #missing == 0 then return "complete", "" end
    return found_any and "partial" or "missing", "missing: " .. table.concat(missing, ", ")
end

-- Last attempt per job from the export log: job -> { state, tc, time, detail, steps }
local function read_log(dir)
    local last = {}
    local f = io.open(dir .. "/_export_log.tsv", "rb")
    if not f then return last end
    for line in f:lines() do
        local time, job, state, tc, detail = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
        if job and state ~= "note" then
            local e = last[job]
            if not e or state == "start" then e = { steps = {} } last[job] = e end -- "start" begins a new attempt
            e.state, e.tc, e.time, e.detail = state, tc, time, detail
            if state == "step" or state == "queued" then e.steps[#e.steps + 1] = detail end
        end
    end
    f:close()
    return last
end

-- Replace mode: before a render pass, move the files that pass is about to write (same
-- project name, cue start within a frame or two) into <dir>/_replaced/<time>/ so REAPER
-- never meets an existing file and asks about overwriting. Nothing is deleted.
local function clear_old(ctx, dir, kind, dry)
    if not ctx.replace then return end
    local root = ctx.project_name
    local esc = root:gsub("%p", "%%%0")
    local want = tc_seconds(start_timecode(ctx.region))
    local function near(tc, tolerance)
        local have = tc and tc_seconds(tc)
        return have and want and math.abs(have - want) <= tolerance
    end
    local function matches(name)
        if not name:match("%.wav$") then return false end
        if kind == "stems" then
            local tc = name:match("^" .. esc .. " %- (%d+%.%d+%.%d+%.%d+) %- .+%.wav$")
            return near(tc, 1)
        elseif kind == "master" or kind == "mixminus" or kind == "masterref" then
            local label = kind == "master" and "MASTER" or kind == "mixminus" and "MIX MINUS" or "MASTER REF"
            local tc = name:match("^_" .. esc .. " %- (%d+%.%d+%.%d+%.%d+) %- " .. label:gsub("%p", "%%%0") .. "%.wav$")
            return near(tc, 1)
        elseif kind == "click" then
            local tc = name:match("^_" .. esc .. " %- (%d+%.%d+%.%d+%.%d+) %- CLICK%.wav$")
            return near(tc, 2)
        elseif kind == "mt_stems" then
            local tc = name:match(" " .. dry .. " %- " .. esc .. " %- (%d+%.%d+%.%d+%.%d+)%-?%d*%.wav$")
            return near(tc, 1)
        elseif kind == "fxreturn" then
            local tc = name:match("^" .. esc .. " %- (%d+%.%d+%.%d+%.%d+) %- FX RETURN%.wav$")
            return near(tc, 1)
        end
        return false
    end
    local moved_to
    for _, name in ipairs(list_files(dir)) do
        if matches(name) then
            moved_to = moved_to or (dir .. "/_replaced/" .. os.date("%Y%m%d-%H%M%S"))
            reaper.RecursiveCreateDirectory(moved_to, 0)
            os.rename(dir .. "/" .. name, moved_to .. "/" .. name)
        end
    end
    if moved_to then log_event(ctx, "note", "replaced files moved to " .. moved_to) end
end

-- Resume: steps (stems, master, ...) that an earlier unfinished attempt of this job
-- completed for the same cue start. A step is only skipped when its file exists too.
local function finished_steps(ctx, job_label)
    local done = {}
    if not ctx.resume or not ctx.log_dir then return done end
    local e = read_log(ctx.log_dir)[job_label]
    if e and e.tc == ctx.log_tc and (e.state == "start" or e.state == "step" or e.state == "error") then
        for _, st in ipairs(e.steps) do done[(st:gsub(" %(kept%)$", ""))] = true end
    end
    return done
end

-- keep(step, exists): true (and logged as kept) when `step` can be skipped
local function step_keeper(ctx, before)
    return function(step, exists)
        if before[step] and exists() then
            log_event(ctx, "step", step .. " (kept)")
            return true
        end
        return false
    end
end

-- Fire the render (or queue it); returns the files written, empty when queued
local function fire(ctx)
    if ctx.queue then
        reaper.Main_OnCommand(41823, 0) -- File: Add project to render queue, using the most recent settings
        ctx.queued = ctx.queued + 1
        return {}
    end
    reaper.Main_OnCommand(RENDER_ACTION, 0)
    return render_targets()
end

local function set_muted(ctx, track, muted)
    if ctx.saved_mutes[track] == nil then ctx.saved_mutes[track] = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") end
    reaper.SetMediaTrackInfo_Value(track, "B_MUTE", muted and 1 or 0)
end

local function restore_mutes(ctx)
    for tr, mute in pairs(ctx.saved_mutes) do reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", mute) end
    ctx.saved_mutes = {}
end

-- Cut / restore a track's send to its parent (or master)
local function set_main_send(ctx, track, on)
    if ctx.saved_mainsend[track] == nil then ctx.saved_mainsend[track] = reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND") end
    reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", on and 1 or 0)
end

local function restore_main_sends(ctx)
    for tr, v in pairs(ctx.saved_mainsend) do reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", v) end
    ctx.saved_mainsend = {}
end

local function find_click_track()
    for _, t in ipairs(scan_tracks()) do
        if t.click then return t.track end
    end
end

-- An existing Click track is muted and cut from the master while mixes render
local function silence_click(ctx)
    local click = find_click_track()
    if click then
        set_muted(ctx, click, true)
        set_main_send(ctx, click, false)
    end
end

local function unsilence(ctx)
    restore_mutes(ctx)
    restore_main_sends(ctx)
end

local function select_only(tracks)
    reaper.Main_OnCommand(40297, 0) -- unselect all tracks
    reaper.SetTrackSelected(reaper.GetMasterTrack(0), false) -- a selected master would join the stems list
    for _, tr in ipairs(tracks) do reaper.SetTrackSelected(tr, true) end
end

-- One render pass over `tracks` (or none, for a master mix), at `settings`
-- Optional wait between steps (ctx.delay seconds). The script thread is REAPER's main
-- thread, so this is a plain wait: background work finishes, the window does not redraw.
local function pause(ctx)
    if not ctx.delay or ctx.delay <= 0 then return end
    local t0 = reaper.time_precise()
    while reaper.time_precise() - t0 < ctx.delay do end
end

local function render_pass(ctx, preset, pattern, settings, tracks, label, norm)
    select_only(tracks or {})
    apply_render(preset, ctx.region, pattern, settings, norm)
    describe_render(label)
    log_event(ctx, "note", string.format("%s range %.6f - %.6f (cue %.6f - %.6f)", label,
        reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", 0, false), reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", 0, false),
        ctx.region.start, ctx.region.finish))
    local got = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
    if got ~= settings then
        ctx.notes[#ctx.notes + 1] = string.format("REAPER set the render source to %d, not %d (%s)", got, settings, label)
    end
    -- Every render action opens REAPER's render dialog, which walks the track list: make sure
    -- it is current (tracks were inserted, muted or reselected since the last pass)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    pause(ctx)
    local targets = fire(ctx)
    log_event(ctx, ctx.queue and "queued" or "step", label)
    pause(ctx)
    return targets
end

-- Reference files (master, mix minus, click) get a leading "_" so they sort above the stems:
-- the preset's pattern with "$track" replaced by `name` and "_" prepended to the filename
local function ref_pattern(pattern, name)
    local dir = pattern:match("^(.*/)") or ""
    local file = pattern:match("([^/]*)$"):gsub("%$track$", "")
    return dir .. "_" .. file .. name
end

-- Insert a click track over the cue range with SWS/AW "Insert click track" (falls back to a
-- plain track + native "Insert click source" if that action isn't available).
local function insert_click_track(ctx)
    local before = {}
    for i = 0, reaper.CountTracks(0) - 1 do before[reaper.GetTrack(0, i)] = true end

    local old_start, old_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local old_cursor = reaper.GetCursorPosition()
    reaper.GetSet_LoopTimeRange(true, false, ctx.region.start, ctx.region.finish, false)
    reaper.SetEditCurPos(ctx.region.start, false, false)

    local sws = reaper.NamedCommandLookup("_SWS_AWINSERTCLICKTRK")
    if sws ~= 0 then
        reaper.Main_OnCommand(sws, 0) -- SWS/AW: Insert click track
    else
        local index = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(index, false)
        local tr = reaper.GetTrack(0, index)
        reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "Click Track", true)
        select_only({ tr })
        reaper.Main_OnCommand(40013, 0) -- Insert click source
    end

    reaper.GetSet_LoopTimeRange(true, false, old_start, old_end, false)
    reaper.SetEditCurPos(old_cursor, false, false)

    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        if not before[tr] then
            reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "Click", true) -- SWS/AW leaves it unnamed
            local item = reaper.GetTrackMediaItem(tr, 0)
            if item then
                reaper.SetMediaItemInfo_Value(item, "D_POSITION", ctx.region.start)
                reaper.SetMediaItemInfo_Value(item, "D_LENGTH", ctx.region.finish - ctx.region.start)
            end
            reaper.TrackList_AdjustWindows(false) -- rebuild REAPER's track lists after inserting
            reaper.UpdateArrange()
            return tr
        end
    end
end

-- Click reference. The click track is made if the project has none, and is muted again
-- afterwards (see the end of M.run). One item that exactly spans the cue is rendered as a
-- plain media item (fast, no project playback); anything else renders as a track stem.
-- Returns false if there is no click track to render.
local function render_click(ctx, preset, pattern)
    local click = find_click_track()
    if not click then
        click = insert_click_track(ctx)
        ctx.inserted_click = click -- remembered so "remove the click track" only removes one we made
    end
    if not click then return false end
    set_muted(ctx, click, false)

    local items = {}
    for j = 0, reaper.CountTrackMediaItems(click) - 1 do
        local item = reaper.GetTrackMediaItem(click, j)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos < ctx.region.finish and pos + len > ctx.region.start then items[#items + 1] = { item, pos, len } end
    end
    local span = ctx.region.finish - ctx.region.start
    local exact = #items == 1 and math.abs(items[1][2] - ctx.region.start) < 0.01 and math.abs(items[1][3] - span) < 0.01

    if exact then
        local saved = {}
        for i = 0, reaper.CountSelectedMediaItems(0) - 1 do saved[#saved + 1] = reaper.GetSelectedMediaItem(0, i) end
        reaper.SelectAllMediaItems(0, false)
        reaper.SetMediaItemSelected(items[1][1], true)
        render_pass(ctx, preset, pattern, 32, {}, "click") -- 32 = selected media items
        reaper.SelectAllMediaItems(0, false)
        for _, it in ipairs(saved) do reaper.SetMediaItemSelected(it, true) end
    else
        render_pass(ctx, preset, pattern, STEMS_SETTINGS, { click }, "click")
    end
    restore_mutes(ctx)
    return true
end

-- PROX ---------------------------------------------------------------------
-- The subproject proxy (<project>.rpp-PROX): "File: Save project and render RPP-PROX".
-- A job of its own, only for projects that are used as a subproject.

local PROX_ACTION = 42332

local function same_path(a, b) return a:lower():gsub("%-prox$", "") == b:lower():gsub("%-prox$", "") end

-- True when another open project tab has an item whose source is this project
local function used_as_subproject()
    local _, me = reaper.EnumProjects(-1)
    if not me or me == "" then return false end
    local i = 0
    while true do
        local proj, path = reaper.EnumProjects(i)
        if not proj then break end
        if path ~= me then
            for k = 0, reaper.CountMediaItems(proj) - 1 do
                local take = reaper.GetActiveTake(reaper.GetMediaItem(proj, k))
                local src = take and reaper.GetMediaItemTake_Source(take)
                if src and reaper.GetMediaSourceType(src, ""):upper():find("RPP", 1, true)
                    and same_path(reaper.GetMediaSourceFileName(src, ""), me) then
                    return true
                end
            end
        end
        i = i + 1
    end
    return false
end

local function prox_file(pdir, project_name)
    local esc = project_name:gsub("%p", "%%%0")
    for _, n in ipairs(list_files(pdir)) do
        if n:match("^" .. esc .. "%.[Rr][Pp][Pp]%-PROX$") then return n end
    end
end

local function file_mtime(path)
    local p = io.popen('stat -f %m "' .. path:gsub('"', '\\"') .. '" 2>/dev/null')
    local v = p and p:read("*l")
    if p then p:close() end
    return tonumber(v)
end

local function prox_job(job, ctx)
    if ctx.midi_only then return end
    if ctx.queue then ctx.notes[#ctx.notes + 1] = "PROX can't be added to the render queue, skipped" return end
    local pdir = project_dir()
    if not used_as_subproject() and not prox_file(pdir, ctx.project_name) then
        ctx.notes[#ctx.notes + 1] = "PROX: this project isn't used as a subproject, skipped"
        return
    end
    reaper.Main_OnCommand(PROX_ACTION, 0) -- saves the project, then renders the proxy
end

-- The click reference is rendered after every other pass of the run. Inserting the click
-- track changes the session, and REAPER's render dialog has crashed on every pass that
-- followed an insert; rendering the clicks last keeps the track out of all other passes.
local function defer_click(ctx, label, preset, pattern, dir)
    ctx.pending_clicks = ctx.pending_clicks or {}
    ctx.pending_clicks[#ctx.pending_clicks + 1] = {
        label = label, preset = preset, pattern = pattern, dir = dir,
        log_job = ctx.log_job, log_dir = ctx.log_dir, log_tc = ctx.log_tc,
    }
end

local function render_pending_clicks(ctx)
    for _, c in ipairs(ctx.pending_clicks or {}) do
        ctx.log_job, ctx.log_dir, ctx.log_tc = c.log_job, c.log_dir, c.log_tc
        clear_old(ctx, c.dir, "click")
        if not render_click(ctx, c.preset, c.pattern) then
            ctx.notes[#ctx.notes + 1] = c.label .. ": could not insert a click source, no click reference"
        end
    end
    ctx.pending_clicks = nil
end

local function has_item_in_range(tr, region)
    for j = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local item = reaper.GetTrackMediaItem(tr, j)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos < region.finish and pos + len > region.start then return true end
    end
    return false
end

local function stems_job(job, ctx)
    local tracks = marked_tracks(job.marks)
    if #tracks == 0 then ctx.notes[#ctx.notes + 1] = job.label .. ": no marked tracks, skipped" return end
    msg(job.label .. ": " .. #tracks .. " tracks")

    local preset, err = load_preset(job.preset)
    if not preset then error(err) end
    set_log(ctx, job, preset)
    local before = finished_steps(ctx, job.label)
    local keep = step_keeper(ctx, before)
    log_event(ctx, "start", #tracks .. " marked tracks" .. (next(before) and ", resuming" or ""))

    local out_dir, tc
    local expected = expected_dir(preset, ctx.project_name)
    local expected_tc = near_tc(expected, ctx.project_name, start_timecode(ctx.region))
    local expected_prefix = ctx.project_name .. " - " .. expected_tc .. " - "
    local function have(test, min)
        return check_files(expected, { { label = "x", min = min or 1, test = test } }) == "complete"
    end
    local with_items = 0 -- a marked track with nothing in the cue renders no stem
    for _, tr in ipairs(tracks) do if has_item_in_range(tr, ctx.region) then with_items = with_items + 1 end end
    if ctx.midi_only or keep("stems", function()
            return have(function(n) return ends_with(n, ".wav") and starts_with(n, expected_prefix) end, math.max(with_items, 1))
        end) then
        out_dir, tc = expected, expected_tc
    else
        -- Stems: selected tracks, via master, fast: all in one pass
        clear_old(ctx, expected, "stems")
        local targets = render_pass(ctx, preset, preset.pattern, STEMS_SETTINGS, tracks, "stems")
        if #targets > 0 then
            out_dir = dirname(targets[1])
            tc = targets[1]:match("([^\\/]*)$"):sub(#ctx.project_name + 4):match("^(%S+) %- ")
        elseif ctx.queue then
            out_dir = expected_dir(preset, ctx.project_name)
        else
            error("stem render produced no files (check overwrite prompt / preset)")
        end
        tc = tc or start_timecode(ctx.region)
    end
    local prefix = ctx.project_name .. " - " .. tc .. " - "

    if not ctx.midi_only then
        -- Master (Film Master's normalize/limiter) and mix minus (stems muted, no
        -- normalize); the click is muted so it never lands in either
        silence_click(ctx)
        if not keep("master", function() return have(function(n) return n == "_" .. prefix .. "MASTER.wav" end) end) then
            clear_old(ctx, expected, "master")
            render_pass(ctx, preset, ref_pattern(preset.pattern, "MASTER"), 0, nil, "master", ctx.master_preset)
        end
        if not keep("mix minus", function() return have(function(n) return n == "_" .. prefix .. "MIX MINUS.wav" end) end) then
            for _, tr in ipairs(tracks) do set_muted(ctx, tr, true) end
            clear_old(ctx, expected, "mixminus")
            render_pass(ctx, preset, ref_pattern(preset.pattern, "MIX MINUS"), 0, nil, "mix minus")
        end
        unsilence(ctx)

        local click_kept = keep("click", function()
            return have(function(n) return starts_with(n, "_" .. ctx.project_name .. " - ") and ends_with(n, " - CLICK.wav") end)
        end)
        if not click_kept then
            defer_click(ctx, job.label, preset, ref_pattern(preset.pattern, "CLICK"), expected)
        end
    end

    if ctx.midi then
        reaper.RecursiveCreateDirectory(out_dir, 0)
        local count, skipped = write_midi(tracks, ctx.region, out_dir .. "/_" .. prefix .. job.label .. ".mid")
        msg("  midi: " .. (count > 0 and ("1 file, " .. count .. " parts on separate channels") or "none (no MIDI in region)"))
        log_event(ctx, ctx.queue and "queued" or "step", count > 0 and "midi" or "midi (none in range)")
        if skipped > 0 then ctx.notes[#ctx.notes + 1] = job.label .. ": " .. skipped .. " MIDI tracks left out (only 16 channels)" end
    end
    ctx.dirs[#ctx.dirs + 1] = out_dir
    log_event(ctx, ctx.queue and "queued" or "done")
end

-- True if the track has an unmuted send to, or receive from, a track that is
-- itself going out (so item-less instrument / bus tracks aren't dropped)
local function has_live_routing(tr, outgoing)
    for category, key in pairs({ [0] = "P_DESTTRACK", [-1] = "P_SRCTRACK" }) do
        for i = 0, reaper.GetTrackNumSends(tr, category) - 1 do
            local other = reaper.GetTrackSendInfo_Value(tr, category, i, key)
            if reaper.GetTrackSendInfo_Value(tr, category, i, "B_MUTE") == 0 and outgoing[other] then
                return true
            end
        end
    end
    return false
end

-- Lowest-level visible tracks (not folders), outside Effects / Movie / Utility
-- folders, that have an item in the range or are wired to another such track
local function leaf_tracks(region)
    local candidates, outgoing = {}, {}
    for _, t in ipairs(scan_tracks()) do
        if t.depth ~= 1 and t.visible and not t.excluded and not t.click then
            candidates[#candidates + 1] = t.track
            outgoing[t.track] = true
        end
    end
    local leaves = {}
    for _, tr in ipairs(candidates) do
        if has_item_in_range(tr, region) or has_live_routing(tr, outgoing) then leaves[#leaves + 1] = tr end
    end
    return leaves
end

-- Folder-name prefixes dropped from multitrack filenames ($folder[_] includes every
-- parent), e.g. the template's master sub-mix folder. Only possible after a real render.
local STRIP_PREFIXES = { "Music Sub Mix_" }

local function strip_prefixes(targets)
    for _, path in ipairs(targets) do
        local dir, file = dirname(path), path:match("([^\\/]*)$")
        for _, prefix in ipairs(STRIP_PREFIXES) do
            if file:lower():sub(1, #prefix) == prefix:lower() then
                os.rename(path, dir .. "/" .. file:sub(#prefix + 1))
                break
            end
        end
    end
end

-- Effects / reverb returns as their own stem: with Effects live, every top-level
-- track except Effects stops feeding the master, so only the returns are heard.
local function fx_return_pass(ctx, preset, pattern)
    local scan = scan_tracks()
    local fx
    for _, t in ipairs(scan) do
        if t.name:lower() == "effects" and t.depth == 1 then fx = t break end
    end
    if not fx then ctx.notes[#ctx.notes + 1] = "FX RETURN skipped: no Effects folder" return end
    if fx.level ~= 0 then ctx.notes[#ctx.notes + 1] = "FX RETURN skipped: Effects folder is nested, not top-level" return end
    set_muted(ctx, fx.track, false)
    for _, t in ipairs(scan) do
        if t.level == 0 and not t.transparent and t.track ~= fx.track then set_main_send(ctx, t.track, false) end
    end
    render_pass(ctx, preset, pattern, 0, nil, "fx return")
    restore_main_sends(ctx)
    restore_mutes(ctx)
end

-- MIDI-only run for the multitrack package: the tempo map and the all-tracks MIDI file at
-- the top of the MULTITRACK folder, nothing rendered (written once, whichever pass asks)
local function multitrack_midi_only(job, ctx)
    if ctx.multitrack_refs then return end
    ctx.multitrack_refs = true
    local preset, err = load_preset(job.preset)
    if not preset then error(err) end
    local top = expected_dir(preset, ctx.project_name, "$project/$project MULTITRACK/x")
    local tc = near_tc(top, ctx.project_name, start_timecode(ctx.region))
    reaper.RecursiveCreateDirectory(top, 0)
    local prefix = top .. "/_" .. ctx.project_name .. " - " .. tc .. " - "
    write_tempo_map(ctx.region, prefix .. "TEMPO MAP.mid")
    if ctx.midi and write_project_midi(ctx.region, prefix .. "MIDI.mid") == 0 then
        ctx.notes[#ctx.notes + 1] = "multitrack: no MIDI in the cue range, no project MIDI file"
    end
    ctx.dirs[#ctx.dirs + 1] = top
end

local function multitrack_job(job, ctx)
    if ctx.midi_only then return multitrack_midi_only(job, ctx) end
    local tracks = leaf_tracks(ctx.region)
    if #tracks == 0 then ctx.notes[#ctx.notes + 1] = job.label .. ": no tracks with items or routing in range, skipped" return end
    msg(job.label .. ": " .. #tracks .. " tracks")

    local preset, err = load_preset(job.preset)
    if not preset then error(err) end
    set_log(ctx, job, preset)
    local before = finished_steps(ctx, job.label)
    local keep = step_keeper(ctx, before)
    log_event(ctx, "start", #tracks .. " tracks" .. (next(before) and ", resuming" or ""))
    local base = "$project/$project MULTITRACK/"
    local top = expected_dir(preset, ctx.project_name, base .. "x")
    local etc = near_tc(top .. "/DRY", ctx.project_name, near_tc(top, ctx.project_name, start_timecode(ctx.region)))
    local function have(dir, test, min)
        return check_files(dir, { { label = "x", min = min or 1, test = test } }) == "complete"
    end

    -- Reference mix and click once per cue, before anything is muted.
    -- The mix is unnormalized so it nulls against the stems.
    -- TODO: dialogue reference (DIA REF) alongside these, once the dialogue bus is defined.
    if not ctx.multitrack_refs then
        ctx.multitrack_refs = true
        silence_click(ctx)
        local ref_pattern_text = base .. "_$project - $starttc - MASTER REF"
        local ref_targets = {}
        local ref_kept = keep("master ref", function()
            return have(top, function(n) return n == "_" .. ctx.project_name .. " - " .. etc .. " - MASTER REF.wav" end)
        end)
        if not ref_kept then clear_old(ctx, top, "masterref") end
        if not ref_kept then ref_targets = render_pass(ctx, preset, ref_pattern_text, 0, nil, "master ref") end
        unsilence(ctx)

        -- Tempo / time-signature map as MIDI, beside the reference mix
        local ref_dir, tc
        if #ref_targets > 0 then
            ref_dir = dirname(ref_targets[1])
            tc = ref_targets[1]:match("([^\\/]*)$"):sub(#ctx.project_name + 5):match("^(%S+) %- ")
        elseif ctx.queue or ref_kept then
            ref_dir = expected_dir(preset, ctx.project_name, ref_pattern_text)
        end
        if ref_dir then
            reaper.RecursiveCreateDirectory(ref_dir, 0)
            write_tempo_map(ctx.region, ref_dir .. "/_" .. ctx.project_name .. " - "
                .. (tc or start_timecode(ctx.region)) .. " - TEMPO MAP.mid")
            log_event(ctx, "step", "tempo map")
            if ctx.midi and write_project_midi(ctx.region, ref_dir .. "/_" .. ctx.project_name .. " - "
                .. (tc or start_timecode(ctx.region)) .. " - MIDI.mid") == 0 then
                ctx.notes[#ctx.notes + 1] = "multitrack: no MIDI in the cue range, no project MIDI file"
            end
        end
        local click_kept = keep("click", function()
            return have(top, function(n) return starts_with(n, "_" .. ctx.project_name .. " - ") and ends_with(n, " - CLICK.wav") end)
        end)
        if not click_kept then
            defer_click(ctx, "multitrack", preset, base .. "_$project - $starttc - CLICK", top)
        end
    end

    local sub = job.mute_effects and "DRY/" or "WET/"
    local pattern = base .. sub .. preset.pattern:match("([^/]*)$")
    local stem_dir = expected_dir(preset, ctx.project_name, pattern)
    local tag = (job.mute_effects and " dry - " or " wet - ") .. ctx.project_name .. " - " .. etc
    local stems_kept = keep(job.label, function()
        return have(stem_dir, function(n) return ends_with(n, ".wav") and not starts_with(n, "_") and n:find(tag, 1, true) ~= nil end, #tracks)
    end)
    if not stems_kept and job.mute_effects then
        -- Dry pass: Effects muted so returns aren't printed; they get their own stem below
        for _, t in ipairs(scan_tracks()) do
            if t.name:lower() == "effects" and t.depth == 1 then set_muted(ctx, t.track, true) end
        end
    end
    local targets = {}
    if not stems_kept then clear_old(ctx, stem_dir, "mt_stems", job.mute_effects and "dry" or "wet") end
    if not stems_kept then targets = render_pass(ctx, preset, pattern, STEMS_SETTINGS, tracks, job.label) end
    restore_mutes(ctx)

    if stems_kept then
        ctx.dirs[#ctx.dirs + 1] = stem_dir
    elseif #targets > 0 then
        strip_prefixes(targets)
        ctx.dirs[#ctx.dirs + 1] = dirname(targets[1])
    elseif ctx.queue then
        ctx.dirs[#ctx.dirs + 1] = expected_dir(preset, ctx.project_name, pattern)
        ctx.notes[#ctx.notes + 1] = 'queued multitrack names keep the "Music Sub Mix_" prefix (only stripped after a real render)'
    else
        error("multitrack render produced no files")
    end

    if job.mute_effects and not keep("fx return", function()
            return have(stem_dir, function(n) return n == ctx.project_name .. " - " .. etc .. " - FX RETURN.wav" end)
        end) then
        clear_old(ctx, stem_dir, "fxreturn")
        fx_return_pass(ctx, preset, base .. sub .. "$project - $starttc - FX RETURN")
    end
    log_event(ctx, ctx.queue and "queued" or "done")
end

-- Deepest folder that contains every output dir
local function common_dir(dirs)
    local common
    for _, d in ipairs(dirs) do
        local parts = {}
        for seg in d:gmatch("[^/]+") do parts[#parts + 1] = seg end
        if not common then
            common = parts
        else
            local n = 0
            while n < #common and n < #parts and common[n + 1] == parts[n + 1] do n = n + 1 end
            for i = #common, n + 1, -1 do common[i] = nil end
        end
    end
    return common and ("/" .. table.concat(common, "/"))
end

-- Export status: is there already a complete export of this cue? --------
-- Looks at the files on disk for the project's current name (its version) and
-- the current cue start. "complete" = every expected file exists and is not
-- empty; "partial" says what is missing.

-- exports/<project>, or the longest exports/<folder> that is a name prefix of the
-- project (exports made before the project was renamed, for example "... TEST_002")
local function find_export_root(preset, project_name, pdir)
    local base = preset.dir:gsub("^%./", "")
    if base:sub(1, 1) ~= "/" then base = pdir .. "/" .. base end
    local best
    for _, d in ipairs(list_subdirs(base)) do
        if d == project_name then best = d break end
        if starts_with(project_name, d .. " ") and (not best or #d > #best) then best = d end
    end
    return base, best
end

-- The cue start timecode used in the files of `dir`: the one given, else the
-- most common one found there (sub-projects, where the cue range is unknown)
local function find_tc(dir, root, tc)
    if tc then return tc end
    local counts, best = {}, nil
    local esc = root:gsub("%p", "%%%0")
    for _, name in ipairs(list_files(dir)) do
        local found = name:match("^_?" .. esc .. " %- (%S+) %- .+%.wav$")           -- <project> - <tc> - <name>
            or name:match(" " .. esc .. " %- (%d+%.%d+%.%d+%.%d+)%-?%d*%.wav$")     -- ... dry|wet - <project> - <tc>[-001]
        if found then
            counts[found] = (counts[found] or 0) + 1
            if not best or counts[found] > counts[best] then best = found end
        end
    end
    return best
end

-- spec: { root = folder name used in the files, base = exports dir, tc = cue start
-- (nil = whatever is there), marked = function(job) -> count, has_midi = function(job)
-- -> bool or nil (unknown), leaves = count or nil (unknown) }
local function stems_status(job, spec)
    local count = spec.marked(job)
    if count == 0 then return "n/a", "no " .. table.concat(job.mark_names, "/") .. " tracks, nothing to export" end
    if spec.soft_counts then count = 1 end -- sub-project: tracks without items still count in the file
    local root = spec.root
    local dir = spec.base .. "/" .. root .. "/" .. root .. " " .. job.label
    if #list_files(dir) == 0 then return "missing", "no files in " .. dir, dir end
    local tc = find_tc(dir, root, spec.tc and near_tc(dir, root, spec.tc))
    if not tc then return "partial", "no stems for " .. root .. " in " .. dir, dir end
    local stem_prefix = root .. " - " .. tc .. " - "
    local reqs = {
        { label = "stems", min = count, test = function(n) return ends_with(n, ".wav") and starts_with(n, stem_prefix) end },
        { label = "MASTER", test = function(n) return n == "_" .. stem_prefix .. "MASTER.wav" end },
        { label = "MIX MINUS", test = function(n) return n == "_" .. stem_prefix .. "MIX MINUS.wav" end },
        { label = "CLICK", test = function(n) return starts_with(n, "_" .. root .. " - ") and ends_with(n, " - CLICK.wav") end },
    }
    if spec.has_midi and spec.has_midi(job) then
        reqs[#reqs + 1] = { label = "MIDI", test = function(n) return n == "_" .. stem_prefix .. job.label .. ".mid" end }
    end
    local state, detail = check_files(dir, reqs)
    if state ~= "complete" and spec.tc then
        -- files from another cue start in the same folder?
        for _, name in ipairs(list_files(dir)) do
            local other = name:match("^" .. root:gsub("%p", "%%%0") .. " %- (%S+) %- .+%.wav$")
            if other and other ~= tc then detail = detail .. "  (found files for cue start " .. other .. ")" break end
        end
    end
    return state, detail, dir
end

local function multitrack_status(job_key, spec)
    local dry = job_key == "multitrack_dry"
    local root = spec.root
    if spec.leaves == 0 then return "n/a", "no tracks with items or routing in range" end
    local top = spec.base .. "/" .. root .. "/" .. root .. " MULTITRACK"
    local dir = top .. "/" .. (dry and "DRY" or "WET")
    if #list_files(dir) == 0 then return "missing", "no files in " .. dir, dir end
    local tc = find_tc(dir, root, spec.tc and near_tc(dir, root, spec.tc)) or find_tc(top, root, nil)
    if not tc then return "partial", "no files for " .. root .. " in " .. dir, dir end
    local tag = (dry and " dry - " or " wet - ") .. root .. " - " .. tc
    local reqs = {
        { label = "stems", min = spec.soft_counts and 1 or (spec.leaves or 1), test = function(n)
            return ends_with(n, ".wav") and not starts_with(n, "_") and n:find(tag, 1, true) ~= nil
        end },
    }
    if dry then
        reqs[#reqs + 1] = { label = "FX RETURN", test = function(n) return n == root .. " - " .. tc .. " - FX RETURN.wav" end }
    end
    local state, detail = check_files(dir, reqs)
    -- the cue references live at the top of the MULTITRACK folder
    local rstate, rdetail = check_files(top, {
        { label = "MASTER REF", test = function(n) return n == "_" .. root .. " - " .. tc .. " - MASTER REF.wav" end },
        { label = "CLICK", test = function(n) return starts_with(n, "_" .. root .. " - ") and ends_with(n, " - CLICK.wav") end },
        { label = "TEMPO MAP", test = function(n) return n == "_" .. root .. " - " .. tc .. " - TEMPO MAP.mid" end },
    })
    if rstate ~= "complete" then
        detail = (detail ~= "" and detail .. "; " or "") .. "references " .. rdetail
        if state == "complete" then state = "partial" end
    end
    return state, detail, dir
end

-- Combine what the files say with what the log says happened. Complete files win;
-- otherwise an attempt that never finished is "interrupted" (REAPER crashed or was
-- stopped), an error is "failed", and a queued render is "queued", so none of them
-- is mistaken for a package that was simply never run.
local function apply_log(state, detail, entry, tc)
    if state == "complete" or state == "n/a" or not entry then return state, detail end
    if tc and entry.tc ~= tc then return state, detail end -- the log is about another cue start
    local when = entry.time:sub(1, 16)
    if entry.state == "start" or entry.state == "step" then
        local steps = #entry.steps > 0 and table.concat(entry.steps, ", ") or "nothing"
        return "interrupted", "stopped after: " .. steps .. " (" .. when .. ")" .. (detail ~= "" and ("; " .. detail) or "")
    elseif entry.state == "error" then
        return "failed", entry.detail .. " (" .. when .. ")"
    elseif entry.state == "queued" then
        return "queued", "added to the render queue " .. when .. (detail ~= "" and ("; " .. detail) or "")
    elseif entry.state == "done" then
        return state, "log says it finished " .. when .. " but files are missing; " .. detail
    end
    return state, detail
end

-- How each status state is shown: word and 0xRRGGBBAA colour
M.STATE_UI = {
    complete = { "done", 0x6FCF7FFF }, partial = { "partial", 0xF0B050FF },
    interrupted = { "interrupted", 0xE5645CFF }, failed = { "failed", 0xE5645CFF },
    queued = { "queued", 0x6FA8E8FF }, missing = { "not run", 0x9A9A9AFF }, ["n/a"] = { "none", 0x777777FF },
}

-- PROX status: complete when <project>.rpp-PROX exists, is not empty and is not older
-- than the last save; n/a when the project isn't a subproject
local function prox_status(rpp_path, project_name, is_sub)
    local pdir = dirname(rpp_path)
    local file = prox_file(pdir, project_name)
    if not file and not is_sub then return "n/a", "not used as a subproject" end
    if not file then return "missing", "no .rpp-PROX next to the project" end
    local full = pdir .. "/" .. file
    if file_size(full) == 0 then return "partial", file .. " is empty" end
    local saved, rendered = file_mtime(rpp_path), file_mtime(full)
    if saved and rendered and saved > rendered + 5 then
        return "partial", string.format("PROX is %d min older than the last save", math.floor((saved - rendered) / 60 + 0.5))
    end
    return "complete", ""
end

-- One row per job for a spec builder: spec_for(preset) -> spec (or nil, reason)
local function status_rows(project_name, pdir, make_spec, rpp_path, is_sub)
    local rows = {}
    for _, key in ipairs(M.job_order) do
        local job = M.jobs[key]
        local preset = job.preset and load_preset(job.preset)
        local row = { key = key, label = job.label }
        if job.kind == "prox" then
            row.state, row.detail = prox_status(rpp_path, project_name, is_sub)
        elseif not preset then
            row.state, row.detail = "missing", 'render preset "' .. job.preset .. '" not found'
        else
            local base, root = find_export_root(preset, project_name, pdir)
            if not root then
                row.state, row.detail = "missing", "no export folder for " .. project_name
            else
                local spec = make_spec(base, root)
                if job.kind == "stems" then
                    row.state, row.detail, row.dir = stems_status(job, spec)
                else
                    row.state, row.detail, row.dir = multitrack_status(key, spec)
                end
                row.state, row.detail = apply_log(row.state, row.detail, read_log(base .. "/" .. root)[job.label], spec.tc)
            end
        end
        rows[#rows + 1] = row
    end
    return rows
end

-- Status of the open project's cue. Returns rows, region; or nil and a reason.
function M.export_status()
    local region, why = cue_region()
    if not region then return nil, why end
    local project_name = reaper.GetProjectName(0):gsub("%.[Rr][Pp][Pp]$", "")
    if project_name == "" then return nil, "Save the project first." end
    local _, rpp_path = reaper.EnumProjects(-1)
    local rows = status_rows(project_name, project_dir(), function(base, root)
        return {
            base = base, root = root, tc = start_timecode(region),
            marked = function(job)
                -- a marked track with no items in the cue range renders no stem
                local n = 0
                for _, tr in ipairs(marked_tracks(job.marks)) do
                    if has_item_in_range(tr, region) then n = n + 1 end
                end
                return n
            end,
            has_midi = function(job)
                for _, tr in ipairs(marked_tracks(job.marks)) do
                    if #collect_midi(tr, region) > 0 then return true end
                end
                return false
            end,
            leaves = #leaf_tracks(region),
        }
    end, rpp_path, used_as_subproject())
    return rows, region
end

-- Sub-projects ----------------------------------------------------------

-- Cue range, marked-track counts and timecode read from a project file on disk
-- (the file is not opened, so the leaf-track count is unknown)
local function read_rpp(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a"):gsub("\r", "")
    f:close()
    local info = { marked = {} }
    local sel_s, sel_e = text:match("\n%s*SELECTION ([%d%.%-]+) ([%d%.%-]+)")
    if sel_s and tonumber(sel_e) > tonumber(sel_s) then info.start = tonumber(sel_s) info.finish = tonumber(sel_e) end
    local ms, me
    for pos, rest in text:gmatch("\n%s*MARKER %d+ ([%d%.%-]+) ([^\n]*)") do
        local name = rest:match('^"([^"]*)"') or rest:match("^(%S+)")
        if name == "=START" then ms = tonumber(pos) elseif name == "=END" then me = tonumber(pos) end
    end
    if not info.start and ms and me and me > ms then info.start, info.finish = ms, me end
    for _, key in ipairs(M.job_order) do
        local job = M.jobs[key]
        if job.kind == "stems" then
            local n = 0
            for raw in text:gmatch('\n%s*<TRACK[^\n]*\n%s*NAME ([^\n]*)') do
                local name = raw:match('^"(.*)"$') or raw
                if has_mark(name, job.marks) and not EXCLUDED_FOLDERS[name:lower()] then n = n + 1 end
            end
            info.marked[key] = n
        end
    end
    return info
end

-- Status of another project (a sub-project's .rpp): { project, rows } or nil, reason.
-- Needs its exports folder next to the project file. Expected counts come from
-- the marked tracks in the file, and the cue start timecode from the files.
function M.export_status_for_rpp(path)
    path = path:gsub("%-PROX$", "")
    local info = read_rpp(path)
    if not info then return nil, "cannot read " .. path end
    local pdir = dirname(path)
    local project_name = path:match("([^\\/]*)$"):gsub("%.[Rr][Pp][Pp]$", "")
    local rows = status_rows(project_name, pdir, function(base, root)
        -- the cue start is taken from the files: a time selection saved in the project can differ
        -- from the one used for the export, and its timecode depends on this project's offset
        return { base = base, root = root, tc = nil, soft_counts = true,
            marked = function(job) return info.marked[job.label:lower()] or 0 end }
    end, path, true)
    return { project = project_name, rows = rows }
end

-- .rpp paths of the sub-project items in the open project, taken from each
-- item's ACTIVE take only; selected items when any are sub-projects, otherwise all
function M.subproject_paths()
    local function paths_of(selected_only)
        local found = {}
        for i = 0, reaper.CountMediaItems(0) - 1 do
            local item = reaper.GetMediaItem(0, i)
            if not selected_only or reaper.IsMediaItemSelected(item) then
                local take = reaper.GetActiveTake(item)
                local src = take and reaper.GetMediaItemTake_Source(take)
                if src and reaper.GetMediaSourceType(src, ""):upper():find("RPP", 1, true) then
                    found[#found + 1] = {
                        path = reaper.GetMediaSourceFileName(src, ""):gsub("%-PROX$", ""),
                        pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
                        track = reaper.GetMediaTrackInfo_Value(reaper.GetMediaItem_Track(item), "IP_TRACKNUMBER"),
                    }
                end
            end
        end
        -- timeline order (then top track first); a project used twice is listed once, at its first spot
        table.sort(found, function(a, b)
            if a.pos ~= b.pos then return a.pos < b.pos end
            return a.track < b.track
        end)
        local out, seen = {}, {}
        for _, f in ipairs(found) do
            if not seen[f.path] then seen[f.path] = true out[#out + 1] = f.path end
        end
        return out
    end
    local selected = paths_of(true)
    if #selected > 0 then return selected, true end
    return paths_of(false), false
end

-- Numeric action ID, or a "_RS..." / "_SWS..." command name
local function run_action(id)
    local n = tonumber(id) or reaper.NamedCommandLookup(id)
    if n and n ~= 0 then reaper.Main_OnCommand(n, 0) end
end

-- opts: { jobs = { "improve", "orch", ... }, queue = bool, midi = bool (default true),
--         resume = bool (skip steps an interrupted run already finished),
--         replace = bool (move existing files for this cue to _replaced/ before rendering),
--         remove_click = bool (delete the click track this run inserted, instead of leaving it muted),
--         delay = seconds to wait before and after every render pass (default 0),
--         freeze_ui = bool (PreventUIRefresh during the run; off by default),
--         open_queue_action = action ID to run after queueing (opens the render queue) }
function M.run(opts)
    local project_name = reaper.GetProjectName(0):gsub("%.[Rr][Pp][Pp]$", "")
    if project_name == "" then return alert("Save the project first.") end
    local region, why = cue_region()
    if not region then return alert(why) end
    local master_preset, err = load_preset("Film Master")
    if not master_preset then return alert(err) end

    local ctx = { region = region, project_name = project_name, master_preset = master_preset,
        queue = opts.queue and true or false, midi_only = opts.midi_only and true or false,
        delay = (not opts.queue) and tonumber(opts.delay) or 0, -- adding to the queue renders nothing, so no waiting
        resume = opts.resume and not opts.queue and not opts.midi_only,
        replace = opts.replace and not opts.resume and not opts.queue and not opts.midi_only,
        midi = opts.midi_only or opts.midi ~= false,
        saved_mutes = {}, saved_mainsend = {}, dirs = {}, queued = 0, notes = {} }

    local saved_render = save_render_state()
    local saved_selection = {}
    for i = 0, reaper.CountSelectedTracks(0) - 1 do saved_selection[#saved_selection + 1] = reaper.GetSelectedTrack(0, i) end

    msg(string.format("Cue: %s (%.3f-%.3f)%s", region.name, region.start, region.finish,
        ctx.queue and " -> render queue" or ""))
    if opts.freeze_ui then reaper.PreventUIRefresh(1) end -- off by default: a frozen UI can leave REAPER's track list stale for the render dialog
    local ok, problem = pcall(function()
        for _, key in ipairs(opts.jobs) do
            local job = M.jobs[key]
            if job.kind == "stems" then stems_job(job, ctx)
            elseif job.kind == "prox" then prox_job(job, ctx)
            else multitrack_job(job, ctx) end
        end
        render_pending_clicks(ctx)
    end)

    -- Always put the project back how we found it
    restore_main_sends(ctx)
    restore_mutes(ctx)
    local click_track = find_click_track()
    if click_track then
        if opts.remove_click and ctx.inserted_click == click_track then
            reaper.DeleteTrack(click_track) -- only a click track this run inserted
        else
            reaper.SetMediaTrackInfo_Value(click_track, "B_MUTE", 1) -- otherwise the click is always left muted
        end
    end
    reaper.Main_OnCommand(40297, 0)
    for _, tr in ipairs(saved_selection) do reaper.SetTrackSelected(tr, true) end
    restore_render_state(saved_render)
    if opts.freeze_ui then reaper.PreventUIRefresh(-1) end
    reaper.UpdateArrange()
    if not ok then
        log_event(ctx, "error", tostring(problem))
        return alert("Export failed:\n\n" .. tostring(problem))
    end

    local seen, unique = {}, {}
    for _, n in ipairs(ctx.notes) do if not seen[n] then seen[n] = true unique[#unique + 1] = n end end
    local notes = #unique > 0 and ("\n\n" .. table.concat(unique, "\n")) or ""
    if ctx.midi_only then
        local d = common_dir(ctx.dirs)
        return alert("MIDI written." .. notes .. (d and ("\n\n" .. d) or ""))
    end
    if ctx.queue then
        if opts.open_queue_action and opts.open_queue_action ~= "" then run_action(opts.open_queue_action) end
        return alert(ctx.queued .. " renders added to the render queue." .. notes)
    end
    local open_dir = common_dir(ctx.dirs)
    if open_dir then
        local answer = reaper.ShowMessageBox("Export finished." .. notes .. "\n\nOpen in Finder?", "Cue export", 4)
        if answer == 6 then
            if reaper.CF_ShellExecute then reaper.CF_ShellExecute(open_dir) else os.execute('open "' .. open_dir .. '"') end
        end
    elseif notes ~= "" then
        alert("Nothing exported." .. notes)
    end
end

return M
