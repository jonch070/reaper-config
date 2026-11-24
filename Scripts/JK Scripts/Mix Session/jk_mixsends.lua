-- Rebuild the cue sessions' FX-return sends (reverb, delay ...) in a mix session built from DRY stems.
-- The stems are rendered post-fader and carry no sends, so the send structure is read from the cue's
-- own RPP text (the session is never opened) and recreated as live sends to empty "return" tracks the
-- mix engineer can drop a reverb on.
--
-- What is read (AUXRECV lines live on the RECEIVING track; first field = source track index):
--   srcidx mode vol pan mute monosum phase srcchan dstchan panlaw midichan automode
-- * return = a track with no media items that receives audio (dstchan 0, srcchan >= 0) from other tracks.
--   dstchan >= 2 is a sidechain input (e.g. Trackspacer) and is NOT a return.
-- * a send from a FOLDER feeds everything inside it, so every child gets the folder's send, scaled by the
--   faders between (the stems only carry the child's own fader).
-- * pre-fader sends keep their mode; their level is divided by the track's own fader because that fader
--   is baked into the stem.
-- * send volume automation (<AUXVOLENV) is copied, shifted from cue time to film time. When a track holds
--   stems of several cues whose sends differ, the send gets a stepped envelope (one value per cue).
-- Not translated (reported): automated faders, send pan/mute automation, sends to non-return buses,
-- FX on folders, reverb plugins inserted on the tracks themselves.
local M = {}

---------------------------------------------------------------------------- parsing

local function unquote(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local q = s:sub(1, 1)
    if (q == '"' or q == "'" or q == "`") and s:sub(-1) == q and #s >= 2 then s = s:sub(2, -2) end
    return s
end

-- Parse an RPP into ordered tracks:
-- { projoffs, tracks = { {idx, name, vol, pan, mainsend, depth_in, depth_out, items, recv = {...},
--                          vol_auto = bool, parent = idx|nil} } }
-- recv entries: { src, mode, vol, pan, mute, srcchan, dstchan, env = { vtype, pts = {{t, v, shape}} } | nil }
function M.parse_rpp(path)
    local f = io.open(path, "r")
    if not f then return nil, "cannot open " .. path end
    local res = { projoffs = 0, tracks = {} }
    local stack, trk, env = {}, nil, nil
    for line in f:lines() do
        local c = line:match("^%s*(%S)")
        if c == "<" then
            local tag = line:match("^%s*<([%w_]+)")
            local parent = stack[#stack]
            stack[#stack + 1] = tag
            if tag == "TRACK" and parent == "REAPER_PROJECT" then
                trk = { idx = #res.tracks, name = "", vol = 1, pan = 0, mainsend = true, fold = 0, items = 0, recv = {}, vol_auto = false }
                res.tracks[#res.tracks + 1] = trk
            elseif trk and parent == "TRACK" and #stack == 3 then
                if tag == "ITEM" then trk.items = trk.items + 1
                elseif tag == "AUXVOLENV" and trk.recv[#trk.recv] then
                    env = { owner = trk.recv[#trk.recv], vtype = 0, pts = {}, active = true }
                elseif tag == "VOLENV2" then
                    env = { owner = "fader", vtype = 0, pts = {}, active = true, track = trk }
                end
            end
        elseif c == ">" and line:match("^%s*>%s*$") then
            local tag = table.remove(stack)
            if tag == "TRACK" then trk = nil
            elseif env and (tag == "AUXVOLENV" or tag == "VOLENV2") then
                if env.active and #env.pts > 0 then
                    if env.owner == "fader" then env.track.vol_auto = true else env.owner.env = { vtype = env.vtype, pts = env.pts } end
                end
                env = nil
            end
        elseif env and (stack[#stack] == "AUXVOLENV" or stack[#stack] == "VOLENV2") then
            local k, rest = line:match("^%s*(%u+)%s*(.*)$")
            if k == "PT" then
                local t, v, shape = rest:match("^(%S+)%s+(%S+)%s*(%S*)")
                if t then env.pts[#env.pts + 1] = { t = tonumber(t), v = tonumber(v), shape = tonumber(shape) or 0 } end
            elseif k == "ACT" then env.active = (tonumber(rest:match("^(%S+)")) or 1) ~= 0
            elseif k == "VOLTYPE" then env.vtype = tonumber(rest:match("^(%S+)")) or 0 end
        elseif trk and #stack == 2 and stack[2] == "TRACK" then
            local k, rest = line:match("^%s*(%u+)%s+(.*)$")
            if k == "NAME" and trk.name == "" then trk.name = unquote(rest)
            elseif k == "VOLPAN" then
                local v, p = rest:match("^(%S+)%s+(%S+)")
                trk.vol, trk.pan = tonumber(v) or 1, tonumber(p) or 0
            elseif k == "ISBUS" then
                local a, b = rest:match("^(-?%d+)%s+(-?%d+)")
                trk.fold = tonumber(b) or 0
            elseif k == "MUTESOLO" then trk.muted = (tonumber(rest:match("^(%S+)")) or 0) ~= 0
            elseif k == "MAINSEND" then trk.mainsend = (tonumber(rest:match("^(%S+)")) or 1) ~= 0
            elseif k == "AUXRECV" then
                local fld = {}
                for tok in rest:gmatch("%S+") do fld[#fld + 1] = tok end
                if #fld >= 9 then
                    trk.recv[#trk.recv + 1] = { src = tonumber(fld[1]), mode = tonumber(fld[2]) or 0, vol = tonumber(fld[3]) or 1,
                        pan = tonumber(fld[4]) or 0, mute = fld[5] == "1", srcchan = tonumber(fld[8]) or 0, dstchan = tonumber(fld[9]) or 0 }
                end
            end
        elseif #stack == 1 then
            local v = line:match("^%s*PROJOFFS%s+(%S+)")
            if v then res.projoffs = tonumber(v) or 0 end
        end
    end
    f:close()
    -- parents from folder depth changes (ISBUS second field: +1 opens a folder, -n closes n)
    local open = {}
    for _, t in ipairs(res.tracks) do
        t.parent = open[#open]
        if t.fold > 0 then for _ = 1, t.fold do open[#open + 1] = t.idx end
        elseif t.fold < 0 then for _ = 1, -t.fold do open[#open] = nil end end
    end
    return res
end

---------------------------------------------------------------------------- analysis

local function norm(s)
    s = s:lower():gsub("^music sub mix", ""):gsub("[^%w]", "")
    return (s:gsub("^musicsubmix", ""))
end
M.norm = norm

local function chain_names(tracks, t)
    local names, p = { t.name }, t.parent
    while p do table.insert(names, 1, tracks[p + 1].name) p = tracks[p + 1].parent end
    return names
end

-- Returns { returns = { [idx] = track }, tracks = { [idx] = { sends = {...} } } }
-- send = { dest = idx, mode, vol (linear, in the new session), pan, mute, env = {vtype, pts, mult}, via = folder name, own }
function M.analyse(rpp)
    local tracks = rpp.tracks
    local returns, outs = {}, {}
    local inbound = {} -- src idx -> list of { dest, recv }
    for _, d in ipairs(tracks) do
        for _, r in ipairs(d.recv) do
            if r.src and tracks[r.src + 1] and r.srcchan >= 0 and r.dstchan == 0 and d.items == 0 and d.fold <= 0 then
                returns[d.idx] = d
                inbound[r.src] = inbound[r.src] or {}
                inbound[r.src][#inbound[r.src] + 1] = { dest = d.idx, recv = r }
            end
        end
    end
    local function gain_of(r, k, post_mult) return r.vol * k * post_mult end
    for _, t in ipairs(tracks) do
        local sends, notes = {}, {}
        -- own sends: pre-fader ones are divided by the track's own fader (baked into the stem)
        for _, s in ipairs(inbound[t.idx] or {}) do
            local r = s.recv
            local pre = r.mode ~= 0
            local k = pre and (t.vol > 1e-6 and 1 / t.vol or 0) or 1
            if pre and t.vol_auto then notes[#notes + 1] = "pre-fader send on a track with an automated fader: level taken from the static fader" end
            sends[#sends + 1] = { dest = s.dest, mode = r.mode, vol = r.vol * k, pan = r.pan, mute = r.mute,
                env = r.env and { vtype = r.env.vtype, pts = r.env.pts, mult = k } or nil, own = true }
        end
        -- folder sends: a send on a parent carries everything inside it
        local below, link, p = 1, t, t.parent
        local alive = t.mainsend
        while p and alive do
            local P = tracks[p + 1]
            for _, s in ipairs(inbound[P.idx] or {}) do
                local r = s.recv
                local post = (r.mode == 0) and P.vol or 1
                local k = below * post
                if P.vol_auto then notes[#notes + 1] = "folder \"" .. P.name .. "\" fader is automated: its static level was used" end
                sends[#sends + 1] = { dest = s.dest, mode = 0, vol = r.vol * k, pan = r.pan, mute = r.mute,
                    env = r.env and { vtype = r.env.vtype, pts = r.env.pts, mult = k } or nil, via = P.name }
            end
            below = below * P.vol
            alive = P.mainsend
            p = P.parent
        end
        -- merge static sends to one destination with the same mode and pan (same signal, so gains add)
        local merged = {}
        for _, s in ipairs(sends) do
            local m
            if not s.env then
                for _, o in ipairs(merged) do
                    if not o.env and o.dest == s.dest and o.mode == s.mode and math.abs(o.pan - s.pan) < 1e-6 and o.mute == s.mute then m = o break end
                end
            end
            if m then
                m.vol = m.vol + s.vol
                if s.via and not (m.via or ""):find(s.via, 1, true) then m.via = (m.via and (m.via .. " + ") or "") .. s.via end
            else
                merged[#merged + 1] = s
            end
        end
        outs[t.idx] = { sends = merged, notes = notes }
    end
    return { returns = returns, tracks = outs }
end

-- Attach `sends` (list, each with a `ret` = lowercase return key) to every stem of a cue by matching the
-- stem's folder path + track name against the session's tracks. Returns problems (strings).
function M.match(cue, rpp, ana)
    local problems = {}
    local by_key, list = {}, {}
    for _, t in ipairs(rpp.tracks) do
        local names = chain_names(rpp.tracks, t)
        local key = norm(table.concat(names, "_"))
        t.key, t.folderkey = key, norm(table.concat(names, "_", 1, #names - 1))
        by_key[key] = by_key[key] or {}
        table.insert(by_key[key], t)
        list[#list + 1] = t
    end
    local function sig(t)
        local parts = {}
        for _, s in ipairs(ana.tracks[t.idx].sends) do
            parts[#parts + 1] = string.format("%d|%d|%.4f|%.3f|%s|%s", s.dest, s.mode, s.vol, s.pan, tostring(s.env ~= nil), tostring(s.mute))
        end
        table.sort(parts)
        return table.concat(parts, ";")
    end
    local nmatch, nnone, namb = 0, 0, 0
    local seen_note = {}
    for _, s in ipairs(cue.stems) do
        local cands = by_key[norm(s.base or "")] or {}
        if #cands == 0 and s.track and #s.track > 0 then -- shortened stem names keep the END of the track name
            local fk, tail = norm(table.concat(s.orig or s.folders, "_")), norm(s.track)
            for _, t in ipairs(list) do
                if t.key:sub(1, #fk) == fk and #t.key >= #fk + #tail and t.key:sub(-#tail) == tail then cands[#cands + 1] = t end
            end
        end
        if #cands > 1 then -- duplicate names: stems come from unmuted tracks that hold items, numbered -001, -002 ...
            local with = {}
            for _, t in ipairs(cands) do if t.items > 0 and not t.muted then with[#with + 1] = t end end
            if #with == 0 then for _, t in ipairs(cands) do if t.items > 0 then with[#with + 1] = t end end end
            if #with > 0 then cands = with end
            local n = tonumber((s.file or ""):match("%-(%d%d%d)%.[Ww][Aa][Vv]$") or "")
            if #cands > 1 and n and cands[n] then cands = { cands[n] } end
        end
        if #cands == 0 then
            nnone = nnone + 1
            problems[#problems + 1] = cue.code .. ": no session track found for stem " .. (s.file or s.track)
        else
            local first, same = cands[1], true
            for i = 2, #cands do if sig(cands[i]) ~= sig(first) then same = false end end
            if not same then
                namb = namb + 1
                problems[#problems + 1] = cue.code .. ": stem \"" .. s.track .. "\" matches " .. #cands .. " session tracks with different sends; sends skipped"
            else
                local a = ana.tracks[first.idx]
                s.sends = {}
                for _, x in ipairs(a.sends) do
                    local d = rpp.tracks[x.dest + 1]
                    local y = {}
                    for k, v in pairs(x) do y[k] = v end
                    y.ret, y.retname = norm(d.name), d.name
                    s.sends[#s.sends + 1] = y
                end
                for _, n in ipairs(a.notes) do
                    local msg = cue.code .. ": " .. (n:match("^folder") and "" or (first.name .. ": ")) .. n
                    if not seen_note[msg] then seen_note[msg] = true problems[#problems + 1] = msg end
                end
                nmatch = nmatch + 1
            end
        end
    end
    -- return tracks of this cue (name -> fader / pan) for the dummy tracks
    cue.returns = {}
    for idx, d in pairs(ana.returns) do cue.returns[norm(d.name)] = { name = d.name, vol = d.vol, pan = d.pan, vol_auto = d.vol_auto } end
    cue.sendinfo = { projoffs = rpp.projoffs, matched = nmatch, unmatched = nnone, ambiguous = namb }
    return problems
end

---------------------------------------------------------------------------- planning

local function env_at(pts, t)
    local prev
    for _, p in ipairs(pts) do
        if p.t > t then
            if not prev then return p.v end
            if prev.shape == 1 then return prev.v end -- square: hold
            return prev.v + (p.v - prev.v) * (t - prev.t) / (p.t - prev.t)
        end
        prev = p
    end
    return prev and prev.v or nil
end

local function lin(vtype, v, from_mode) -- raw envelope value -> linear gain
    if vtype == 1 and from_mode then return from_mode(1, v) end
    return v
end

-- Turn per-stem sends into per-track-entry sends and append the return tracks to `out`.
-- from_mode = reaper.ScaleFromEnvelopeMode (or nil in tests). Returns report lines, problems.
function M.finish(out, cues, from_mode)
    local problems, rets, retorder, rows = {}, {}, {}, {}
    local function note_return(cue, key, name)
        local info = cue.returns and cue.returns[key]
        if not info then return end
        local r = rets[key]
        if not r then
            r = { key = key, name = info.name, vol = info.vol, pan = info.pan }
            rets[key] = r
            retorder[#retorder + 1] = r
        elseif math.abs(r.vol - info.vol) > 0.01 * r.vol then
            r.varies = true
        end
        if info.vol_auto then r.auto = true end
    end
    for _, e in ipairs(out) do
        if e.items and #e.items > 0 and not e.special then
            -- slots: i-th send to each return, across the track's items
            local slots, order = {}, {}
            for _, it in ipairs(e.items) do
                local per = {}
                for _, s in ipairs(it.sends or {}) do
                    per[s.ret] = (per[s.ret] or 0) + 1
                    s.slot = per[s.ret]
                    local key = s.ret .. "#" .. s.slot
                    if not slots[key] then slots[key] = { ret = s.ret, slot = s.slot, mode = s.mode, pan = s.pan, mute = s.mute, via = s.via, pts = {} } order[#order + 1] = slots[key] end
                    local sl = slots[key]
                    if sl.mode ~= s.mode then problems[#problems + 1] = e.name .. ": pre/post differs between cues for " .. s.retname .. "; first kept" end
                    if it.cue then note_return(it.cue, s.ret) end
                end
            end
            local items = {}
            for _, it in ipairs(e.items) do items[#items + 1] = it end
            table.sort(items, function(a, b) return a.pos < b.pos end)
            local sends = {}
            for _, sl in ipairs(order) do
                -- value of this slot in every item (linear), nil = absent
                local per_item, any_env, uniform, ref = {}, false, true, nil
                for i, it in ipairs(items) do
                    local hit
                    for _, s in ipairs(it.sends or {}) do
                        if s.ret == sl.ret and s.slot == sl.slot then hit = s end
                    end
                    per_item[i] = hit
                    if hit and hit.env then any_env = true end
                end
                for i, h in ipairs(per_item) do
                    local v = h and h.vol or 0
                    if h and h.env then uniform = false end
                    if ref == nil then ref = v elseif math.abs(v - ref) > 1e-4 then uniform = false end
                end
                local send = { ret = sl.ret, mode = sl.mode, pan = sl.pan, mute = sl.mute, via = sl.via }
                if uniform then
                    send.vol = ref
                else
                    -- stepped (and automated) envelope in film time
                    local pts = {}
                    for i, it in ipairs(items) do
                        local h, projoffs = per_item[i], (it.cue and it.cue.sendinfo and it.cue.sendinfo.projoffs) or 0
                        local t0 = it.pos
                        if not h then
                            pts[#pts + 1] = { t = t0, v = 0, shape = 1 }
                        elseif not h.env then
                            pts[#pts + 1] = { t = t0, v = h.vol, shape = 1 }
                        else
                            local tc0 = t0 - projoffs
                            local v0 = env_at(h.env.pts, tc0)
                            pts[#pts + 1] = { t = t0, v = lin(h.env.vtype, v0 or 1, from_mode) * h.env.mult, shape = h.env.pts[1].shape or 0 }
                            for _, p in ipairs(h.env.pts) do
                                if p.t > tc0 and p.t < tc0 + (it.len > 0 and it.len or 1e9) then
                                    pts[#pts + 1] = { t = projoffs + p.t, v = lin(h.env.vtype, p.v, from_mode) * h.env.mult, shape = p.shape }
                                end
                            end
                        end
                    end
                    send.pts, send.vol = pts, pts[1] and pts[1].v or 1
                end
                sends[#sends + 1] = send
                rows[#rows + 1] = { track = e.name, ret = sl.ret, send = send }
            end
            if #sends > 0 then e.sends = sends end
        end
    end
    -- return tracks go last
    local lines = {}
    for _, r in ipairs(retorder) do
        out[#out + 1] = { name = r.name, depth = 0, special = "ret", retkey = r.key, retvol = r.vol, retpan = r.pan }
        if r.varies then problems[#problems + 1] = "return \"" .. r.name .. "\": its fader differs between cues; the first cue's level was used" end
        if r.auto then problems[#problems + 1] = "return \"" .. r.name .. "\": its fader is automated in a cue session (static level used)" end
    end
    for _, rw in ipairs(rows) do
        local s = rw.send
        lines[#lines + 1] = { track = rw.track, ret = rets[rw.ret] and rets[rw.ret].name or rw.ret, db = (s.vol and s.vol > 1e-6) and (20 * math.log(s.vol, 10)) or -150,
            mode = s.mode == 0 and "post-fader" or (s.mode == 1 and "pre-FX" or "pre-fader"), pan = s.pan, auto = s.pts ~= nil, via = s.via or "", mute = s.mute }
    end
    return lines, problems, #retorder
end

-- Tab-separated send sheet for the mix engineer.
function M.sheet(lines, path)
    local f = io.open(path, "w")
    if not f then return false end
    f:write("track\treturn\tlevel dB\tpre/post\tpan\tautomated/varies by cue\tvia folder\tmuted\n")
    for _, l in ipairs(lines) do
        f:write(string.format("%s\t%s\t%.1f\t%s\t%.2f\t%s\t%s\t%s\n", l.track, l.ret, l.db, l.mode, l.pan, l.auto and "yes" or "", l.via, l.mute and "yes" or ""))
    end
    f:close()
    return true
end

---------------------------------------------------------------------------- REAPER side

local function to_db_gain(v) return v < 0 and 0 or v end

-- Create the sends for planned entries. `tracks` = { [out index] = MediaTrack }, `offs` = project start offset.
-- Returns count of sends, problems.
function M.apply(out, tracks, offs, opts)
    local retr, problems, n = {}, {}, 0
    for i, e in ipairs(out) do
        if e.special == "ret" then
            retr[e.retkey] = tracks[i]
            reaper.SetMediaTrackInfo_Value(tracks[i], "D_VOL", to_db_gain(e.retvol or 1))
            reaper.SetMediaTrackInfo_Value(tracks[i], "D_PAN", e.retpan or 0)
            if opts and opts.placeholder and reaper.TrackFX_AddByName then reaper.TrackFX_AddByName(tracks[i], "ReaVerb", false, -1) end
        end
    end
    for i, e in ipairs(out) do
        for _, s in ipairs(e.sends or {}) do
            local dest = retr[s.ret]
            if dest and tracks[i] then
                local si = reaper.CreateTrackSend(tracks[i], dest)
                if si and si >= 0 then
                    reaper.SetTrackSendInfo_Value(tracks[i], 0, si, "D_VOL", to_db_gain(s.pts and 1 or s.vol))
                    reaper.SetTrackSendInfo_Value(tracks[i], 0, si, "D_PAN", s.pan or 0)
                    reaper.SetTrackSendInfo_Value(tracks[i], 0, si, "I_SENDMODE", s.mode or 0)
                    if s.mute then reaper.SetTrackSendInfo_Value(tracks[i], 0, si, "B_MUTE", 1) end
                    n = n + 1
                    if s.pts then
                        local ok, env = pcall(reaper.GetSetTrackSendInfo, tracks[i], 0, si, "P_ENV:<VOLENV", true)
                        if not ok or not env or env == 0 then
                            problems[#problems + 1] = e.name .. ": could not create the send envelope for " .. s.ret .. "; static level used"
                            reaper.SetTrackSendInfo_Value(tracks[i], 0, si, "D_VOL", to_db_gain(s.vol))
                        else
                            local mode = reaper.GetEnvelopeScalingMode and reaper.GetEnvelopeScalingMode(env) or 0
                            reaper.DeleteEnvelopePointRange(env, -1e9, 1e12)
                            for _, p in ipairs(s.pts) do
                                local v = reaper.ScaleToEnvelopeMode and reaper.ScaleToEnvelopeMode(mode, p.v) or p.v
                                reaper.InsertEnvelopePoint(env, p.t - offs, v, p.shape or 0, 0, false, true)
                            end
                            reaper.Envelope_SortPoints(env)
                        end
                    end
                end
            end
        end
    end
    return n, problems
end

return M
