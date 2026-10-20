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
    improve = { kind = "stems", label = "IMPROVE", marks = { IM = true }, preset = "Film IMPROVE" },
    orch = { kind = "stems", label = "ORCH", marks = { REC = true, TR = true }, preset = "Film ORCH" },
    multitrack_dry = { kind = "multitrack", label = "multitrack dry", preset = "Film Multitrack Dry", mute_effects = true },
    multitrack_wet = { kind = "multitrack", label = "multitrack wet", preset = "Film Multitrack Wet" },
}
M.job_order = { "improve", "orch", "multitrack_dry", "multitrack_wet" }

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
    for _, tr in ipairs(tracks) do reaper.SetTrackSelected(tr, true) end
end

-- One render pass over `tracks` (or none, for a master mix), at `settings`
local function render_pass(ctx, preset, pattern, settings, tracks, label, norm)
    select_only(tracks or {})
    apply_render(preset, ctx.region, pattern, settings, norm)
    describe_render(label)
    local got = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
    if got ~= settings then
        ctx.notes[#ctx.notes + 1] = string.format("REAPER set the render source to %d, not %d (%s)", got, settings, label)
    end
    return fire(ctx)
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
            return tr
        end
    end
end

-- Click reference. The click track is made if the project has none, and is muted again
-- afterwards (see the end of M.run). One item that exactly spans the cue is rendered as a
-- plain media item (fast, no project playback); anything else renders as a track stem.
-- Returns false if there is no click track to render.
local function render_click(ctx, preset, pattern)
    local click = find_click_track() or insert_click_track(ctx)
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

local function stems_job(job, ctx)
    local tracks = marked_tracks(job.marks)
    if #tracks == 0 then ctx.notes[#ctx.notes + 1] = job.label .. ": no marked tracks, skipped" return end
    msg(job.label .. ": " .. #tracks .. " tracks")

    local preset, err = load_preset(job.preset)
    if not preset then error(err) end

    local out_dir, tc
    if ctx.midi_only then
        out_dir, tc = expected_dir(preset, ctx.project_name), start_timecode(ctx.region)
    else
        -- Stems: selected tracks, via master, fast: all in one pass
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
        render_pass(ctx, preset, ref_pattern(preset.pattern, "MASTER"), 0, nil, "master", ctx.master_preset)
        for _, tr in ipairs(tracks) do set_muted(ctx, tr, true) end
        render_pass(ctx, preset, ref_pattern(preset.pattern, "MIX MINUS"), 0, nil, "mix minus")
        unsilence(ctx)

        if not render_click(ctx, preset, ref_pattern(preset.pattern, "CLICK")) then
            ctx.notes[#ctx.notes + 1] = job.label .. ": could not insert a click source, no click reference"
        end
    end

    if ctx.midi then
        reaper.RecursiveCreateDirectory(out_dir, 0)
        local count, skipped = write_midi(tracks, ctx.region, out_dir .. "/_" .. prefix .. job.label .. ".mid")
        msg("  midi: " .. (count > 0 and ("1 file, " .. count .. " parts on separate channels") or "none (no MIDI in region)"))
        if skipped > 0 then ctx.notes[#ctx.notes + 1] = job.label .. ": " .. skipped .. " MIDI tracks left out (only 16 channels)" end
    end
    ctx.dirs[#ctx.dirs + 1] = out_dir
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

local function multitrack_job(job, ctx)
    local tracks = leaf_tracks(ctx.region)
    if #tracks == 0 then ctx.notes[#ctx.notes + 1] = job.label .. ": no tracks with items or routing in range, skipped" return end
    msg(job.label .. ": " .. #tracks .. " tracks")

    local preset, err = load_preset(job.preset)
    if not preset then error(err) end
    local base = "$project/$project MULTITRACK/"

    -- Reference mix and click once per cue, before anything is muted.
    -- The mix is unnormalized so it nulls against the stems.
    -- TODO: dialogue reference (DIA REF) alongside these, once the dialogue bus is defined.
    if not ctx.multitrack_refs then
        ctx.multitrack_refs = true
        silence_click(ctx)
        local ref_pattern_text = base .. "_$project - $starttc - MASTER REF"
        local ref_targets = render_pass(ctx, preset, ref_pattern_text, 0, nil, "master ref")
        unsilence(ctx)

        -- Tempo / time-signature map as MIDI, beside the reference mix
        local ref_dir, tc
        if #ref_targets > 0 then
            ref_dir = dirname(ref_targets[1])
            tc = ref_targets[1]:match("([^\\/]*)$"):sub(#ctx.project_name + 5):match("^(%S+) %- ")
        elseif ctx.queue then
            ref_dir = expected_dir(preset, ctx.project_name, ref_pattern_text)
        end
        if ref_dir then
            reaper.RecursiveCreateDirectory(ref_dir, 0)
            write_tempo_map(ctx.region, ref_dir .. "/_" .. ctx.project_name .. " - "
                .. (tc or start_timecode(ctx.region)) .. " - TEMPO MAP.mid")
            if ctx.midi and write_project_midi(ctx.region, ref_dir .. "/_" .. ctx.project_name .. " - "
                .. (tc or start_timecode(ctx.region)) .. " - MIDI.mid") == 0 then
                ctx.notes[#ctx.notes + 1] = "multitrack: no MIDI in the cue range, no project MIDI file"
            end
        end
        if not render_click(ctx, preset, base .. "_$project - $starttc - CLICK") then
            ctx.notes[#ctx.notes + 1] = "multitrack: could not insert a click source, no click reference"
        end
    end

    local sub = job.mute_effects and "DRY/" or "WET/"
    local pattern = base .. sub .. preset.pattern:match("([^/]*)$")
    if job.mute_effects then
        -- Dry pass: Effects muted so returns aren't printed; they get their own stem below
        for _, t in ipairs(scan_tracks()) do
            if t.name:lower() == "effects" and t.depth == 1 then set_muted(ctx, t.track, true) end
        end
    end
    local targets = render_pass(ctx, preset, pattern, STEMS_SETTINGS, tracks, job.label)
    restore_mutes(ctx)

    if #targets > 0 then
        strip_prefixes(targets)
        ctx.dirs[#ctx.dirs + 1] = dirname(targets[1])
    elseif ctx.queue then
        ctx.dirs[#ctx.dirs + 1] = expected_dir(preset, ctx.project_name, pattern)
        ctx.notes[#ctx.notes + 1] = 'queued multitrack names keep the "Music Sub Mix_" prefix (only stripped after a real render)'
    else
        error("multitrack render produced no files")
    end

    if job.mute_effects then
        fx_return_pass(ctx, preset, base .. sub .. "$project - $starttc - FX RETURN")
    end
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

-- Numeric action ID, or a "_RS..." / "_SWS..." command name
local function run_action(id)
    local n = tonumber(id) or reaper.NamedCommandLookup(id)
    if n and n ~= 0 then reaper.Main_OnCommand(n, 0) end
end

-- opts: { jobs = { "improve", "orch", ... }, queue = bool, midi = bool (default true),
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
        midi = opts.midi_only or opts.midi ~= false,
        saved_mutes = {}, saved_mainsend = {}, dirs = {}, queued = 0, notes = {} }

    local saved_render = save_render_state()
    local saved_selection = {}
    for i = 0, reaper.CountSelectedTracks(0) - 1 do saved_selection[#saved_selection + 1] = reaper.GetSelectedTrack(0, i) end

    msg(string.format("Cue: %s (%.3f-%.3f)%s", region.name, region.start, region.finish,
        ctx.queue and " -> render queue" or ""))
    reaper.PreventUIRefresh(1)
    local ok, problem = pcall(function()
        for _, key in ipairs(opts.jobs) do
            local job = M.jobs[key]
            if job.kind == "stems" then stems_job(job, ctx) else multitrack_job(job, ctx) end
        end
    end)

    -- Always put the project back how we found it
    restore_main_sends(ctx)
    restore_mutes(ctx)
    local click_track = find_click_track()
    if click_track then reaper.SetMediaTrackInfo_Value(click_track, "B_MUTE", 1) end -- the click is always left muted
    reaper.Main_OnCommand(40297, 0)
    for _, tr in ipairs(saved_selection) do reaper.SetTrackSelected(tr, true) end
    restore_render_state(saved_render)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    if not ok then return alert("Export failed:\n\n" .. tostring(problem)) end

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
