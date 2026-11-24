-- Mix session builder: lays the rendered multitrack stems of every cue (DRY or WET) onto
-- tracks in the OPEN project (open your template session first; the new tracks are appended
-- after whatever it already has). Each stem is placed at its own BWF time reference, which is
-- the cue's film position, so no TC maths is needed.
--
-- Folder structure comes from the stem filenames (`$folder[_]_$track`): split on "_", last
-- segment = track name, everything before = folder chain. All cues are merged into one tree.
-- Layouts: 1 = grouped by instrument (one merged tree, cues along the timeline),
--          2 = checkerboard by cue (one folder per cue holding that cue's own tree).
-- Per cue: the CLICK reference on top, and (dry only) the FX RETURN at the bottom.
local M = {}

M.DEFAULT_ROOT = "/Users/jonathankawchuk/Documents/Projects/Film/Hunt for the Grey Ghost/HGG Reaper Projects"
local EXT_SECTION = "JK_MixNotes" -- shared with the notes importer so the root is remembered once
local FILM_FPS = 23.976            -- only used when a file has no BWF time reference

-- Folder-name prefixes dropped before splitting (same as the export's STRIP_PREFIXES).
M.STRIP_PREFIXES = { "Music Sub Mix_" }
-- Cue-specific decoration removed from track names so the same instrument merges across cues,
-- e.g. "HGG-NWG-1m02 Hang Drum Finger v1" -> "Hang Drum Finger". Lua patterns, applied in order.
M.NAME_PATTERNS = { "^%u[%w]*%-%u[%w]*%-%d+[mM]%d+%s+", "^%d+[mM]%d+[%s%-]+", "%s+[vV]%d+$" }

---------------------------------------------------------------------------- files

-- WAV header facts without reading audio: { tref = BWF time reference in seconds or nil, len = seconds }
function M.wav_info(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local sr, tref, ba, dsize
    local hdr = f:read(12)
    if hdr and (hdr:sub(1, 4) == "RIFF" or hdr:sub(1, 4) == "RF64") then
        for _ = 1, 30 do
            local h = f:read(8)
            if not h or #h < 8 then break end
            local id, size = h:sub(1, 4), string.unpack("<I4", h, 5)
            if id == "data" then dsize = size break end
            local body = f:read(size)
            if not body then break end
            if size % 2 == 1 then f:read(1) end
            if id == "fmt " and #body >= 14 then sr, ba = string.unpack("<I4", body, 5), string.unpack("<I2", body, 13) end
            if id == "bext" and #body >= 346 then
                local lo, hi = string.unpack("<I4I4", body, 339)
                tref = hi * 4294967296 + lo
            end
        end
    end
    f:close()
    if not sr then return nil end
    return { tref = tref and tref / sr, len = (dsize and ba and ba > 0 and dsize < 4294967295) and dsize / (sr * ba) or nil }
end

local function tc_from_name(name) -- "10.14.26.15" -> film seconds
    local h, m, s, fr = name:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    if not h then return nil end
    return ((h * 3600 + m * 60 + s) * 24 + fr) / FILM_FPS
end

local function version_key(name)
    local a, b, c = name:match("[vV](%d+)%.(%d+)%.(%d+)")
    if not a then return 0 end
    return tonumber(a) * 1e8 + tonumber(b) * 1e4 + tonumber(c)
end

local function list(dir, fn)
    local out, i = {}, 0
    while true do
        local n = fn(dir, i)
        if not n then break end
        out[#out + 1] = n
        i = i + 1
    end
    return out
end
local function files(dir) return list(dir, reaper.EnumerateFiles) end
local function subdirs(dir) return list(dir, reaper.EnumerateSubdirectories) end

---------------------------------------------------------------------------- parsing

function M.clean_name(name)
    for _, p in ipairs(M.NAME_PATTERNS) do
        local c = name:gsub(p, "")
        if c ~= "" then name = c end
    end
    return name
end

-- "<folders>_<track> dry - <project> - <tc>.wav" -> { folders = {...}, track = "...", tc = "..." }
function M.parse_stem(file, tag)
    if file:sub(1, 1) == "_" then return nil end
    local base, rest = file:match("^(.*) " .. tag .. " %- (.+)%.[Ww][Aa][Vv]$")
    -- a track with an EMPTY name leaves "<folder>_dry - ..." (no space): the last folder is then the track
    if not base then base, rest = file:match("^(.*)_" .. tag .. " %- (.+)%.[Ww][Aa][Vv]$") end
    if not base then return nil end
    local changed = true
    while changed do
        changed = false
        for _, p in ipairs(M.STRIP_PREFIXES) do
            if base:lower():sub(1, #p) == p:lower() then base, changed = base:sub(#p + 1), true end
        end
    end
    local segs = {}
    for seg in (base .. "_"):gmatch("(.-)_") do
        if seg ~= "" then segs[#segs + 1] = seg end
    end
    if #segs == 0 then return nil end
    local track = table.remove(segs)
    return { folders = segs, track = track, base = base, tc = rest:match("(%d+%.%d+%.%d+%.%d+)%-?%d*$") }
end

-- The stem folder and the MULTITRACK folder for a user-chosen folder: accepts the MULTITRACK
-- folder, its DRY/WET folder, or a folder that simply holds the stems.
function M.resolve_folder(folder, variant)
    folder = folder:gsub("[/\\]+$", "")
    local base = folder:match("([^/\\]*)$")
    if base == "DRY" or base == "WET" then return folder, (folder:gsub("[/\\][^/\\]*$", "")) end
    if #files(folder .. "/" .. variant) > 0 then return folder .. "/" .. variant, folder end
    for _, sd in ipairs(subdirs(folder)) do
        if sd:match("MULTITRACK$") and #files(folder .. "/" .. sd .. "/" .. variant) > 0 then
            return folder .. "/" .. sd .. "/" .. variant, folder .. "/" .. sd
        end
    end
    return folder, folder
end

-- Every cue folder under root with its available exports for `variant`, newest first:
-- { { code, dir, versions = { {name, stemdir, mt} ... } } ... }
function M.scan(root, variant)
    local rows = {}
    for _, dir in ipairs(subdirs(root)) do
        local code = dir:match("^(%d+M%d+)")
        if code then
            local row = { code = code, dir = dir, versions = {} }
            for _, sd in ipairs(subdirs(root .. "/" .. dir .. "/exports")) do
                local mt = root .. "/" .. dir .. "/exports/" .. sd .. "/" .. sd .. " MULTITRACK"
                if #files(mt .. "/" .. variant) > 0 then
                    row.versions[#row.versions + 1] = { name = sd, stemdir = mt .. "/" .. variant, mt = mt }
                end
            end
            table.sort(row.versions, function(x, y)
                local kx, ky = version_key(x.name), version_key(y.name)
                if kx ~= ky then return kx > ky end
                return x.name > y.name
            end)
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(x, y) return x.code < y.code end)
    return rows
end

-- Read one cue's stems, click and FX RETURN from a chosen export.
function M.load_cue(code, name, stemdir, mt, variant)
    local tag = variant:lower()
    local cue = { code = code, name = name, dir = mt, stems = {} }
    -- long-named originals that have a short-named copy (Cue Export/jk_stemnames.lua) are skipped
    local here = debug.getinfo(1, "S").source:match("^@(.*[\\/])") or ""
    local okn, stemnames = pcall(dofile, here .. "../Cue Export/jk_stemnames.lua")
    local skip = okn and stemnames.originals(stemdir) or {}
    for _, file in ipairs(files(stemdir)) do
        local p = (not skip[file]) and M.parse_stem(file, tag) or nil
        if p then
            p.path, p.file = stemdir .. "/" .. file, file
            cue.stems[#cue.stems + 1] = p
        elseif file:match("%- FX RETURN%.[Ww][Aa][Vv]$") then
            cue.fxreturn = stemdir .. "/" .. file
        end
    end
    for _, file in ipairs(files(mt)) do
        if file:sub(1, 1) == "_" and file:match(" %- CLICK%.[Ww][Aa][Vv]$") then cue.click = mt .. "/" .. file end
        if file:sub(1, 1) == "_" and file:match(" %- MASTER REF%.[Ww][Aa][Vv]$") then cue.masterref = mt .. "/" .. file end
    end
    return cue
end

-- Newest export of each cue (batch/test helper). cue_filter: set of cue codes or nil.
function M.find_cues(root, variant, cue_filter)
    local cues, problems = {}, {}
    for _, row in ipairs(M.scan(root, variant)) do
        if not cue_filter or cue_filter[row.code:upper()] then
            local v = row.versions[1]
            if v then cues[#cues + 1] = M.load_cue(row.code, v.name, v.stemdir, v.mt, variant)
            else problems[#problems + 1] = row.code .. ": no " .. variant .. " stems found in exports" end
        end
    end
    return cues, problems
end

---------------------------------------------------------------------------- group profiles
-- A profile says which instrument group each stem belongs to, so the same builder serves other
-- films: ordered groups (first match wins), each with a colour and match terms. Terms are tested
-- (plain, lower-case) against the stem's folder path + track name; a leading/trailing "/" anchors a term
-- to whole folder names ("/pitched percussion/" does not match "Unpitched Percussion"), e.g.
-- "/orchestra/woodwinds/clarinets/clarinet solo/clarinet 3/". `assign` holds manual choices
-- (folder-path prefix -> group name, or SKIP) and beats the rules. Profiles live as Lua tables in
-- profiles/<name>.lua beside this file.
local SCRIPT_DIR = (debug.getinfo(1, "S").source:match("^@(.*[\\/])")) or ""
M.PROFILE_DIR = SCRIPT_DIR .. "profiles/"
M.SKIP = "(skip)"
M.UNASSIGNED = "Unassigned"

local function serialize(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t ~= "table" then return "nil" end
    local inner, out = indent .. "  ", {}
    if #v > 0 then
        for _, x in ipairs(v) do out[#out + 1] = inner .. serialize(x, inner) end
    else
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do out[#out + 1] = inner .. "[" .. string.format("%q", tostring(k)) .. "] = " .. serialize(v[k], inner) end
    end
    if #out == 0 then return "{}" end
    return "{\n" .. table.concat(out, ",\n") .. "\n" .. indent .. "}"
end

local function parse_table(text)
    local fn = load("return " .. text, "profile", "t", {})
    if not fn then return nil end
    local ok, v = pcall(fn)
    if ok and type(v) == "table" then return v end
end

-- Default profile for Hunt for the Grey Ghost (the mix engineer's groups). The match terms are a
-- starting point: anything they miss is listed in the picker for a one-time assignment.
function M.default_profile()
    local function g(name, rgb, match) return { name = name, color = rgb, match = match, exclude = {} } end
    return { name = "HGG", assign_depth = 3, fx_group = "Time Based Effects", assign = {}, groups = {
        g("Woodwinds", { 235, 140, 60 }, { "/woodwinds/" }),
        g("Organ", { 170, 130, 90 }, { "/organs/" }),
        g("Pitched Percussion", { 225, 190, 60 }, { "/pitched percussion/" }),
        g("Choir Pad", { 150, 200, 70 }, { "/choir/", "/synth pads/" }),
        g("Synth Bass", { 70, 140, 230 }, { "/synth basses/" }),
        g("Synth General", { 110, 100, 230 }, { "/synth arps/", "/synth melody/" }),
        g("Synth General 2 / Misc", { 170, 100, 220 }, { "/synth leads/", "/synths/" }),
        g("Time Based Effects", { 60, 190, 190 }, { "/effects/" }),
    } }
end

-- Names of the saved profiles (the default one is written on first use)
function M.list_profiles()
    local names, have = {}, false
    for _, f in ipairs(files(M.PROFILE_DIR)) do
        local n = f:match("^(.*)%.lua$")
        if n then names[#names + 1] = n have = have or n == "HGG" end
    end
    if not have then
        M.save_profile(M.default_profile())
        names[#names + 1] = "HGG"
    end
    table.sort(names)
    return names
end

function M.load_profile(name)
    local f = io.open(M.PROFILE_DIR .. name .. ".lua", "rb")
    if f then
        local text = f:read("*a")
        f:close()
        local p = parse_table(text)
        if p and type(p.groups) == "table" then
            p.name, p.assign = name, p.assign or {}
            p.assign_depth = p.assign_depth or 3
            return p
        end
    end
    if name == "HGG" then return M.default_profile() end
    return { name = name, assign_depth = 3, groups = {}, assign = {} }
end

-- Writes the profile without UI-only fields (the picker adds text buffers to its groups)
function M.save_profile(p)
    reaper.RecursiveCreateDirectory(M.PROFILE_DIR, 0)
    local copy = { assign_depth = p.assign_depth, fx_group = p.fx_group, assign = p.assign or {}, groups = {} }
    for _, g in ipairs(p.groups) do
        copy.groups[#copy.groups + 1] = { name = g.name, color = g.color, match = g.match or {}, exclude = g.exclude or {} }
    end
    local f = io.open(M.PROFILE_DIR .. p.name .. ".lua", "wb")
    if not f then return false end
    f:write(serialize(copy), "\n")
    f:close()
    return true
end

function M.clone_profile(p, name)
    local c = parse_table(serialize({ assign_depth = p.assign_depth, fx_group = p.fx_group, assign = {}, groups = (function()
        local gs = {}
        for _, g in ipairs(p.groups) do gs[#gs + 1] = { name = g.name, color = g.color, match = g.match or {}, exclude = g.exclude or {} } end
        return gs
    end)() }))
    c.name = name
    return c
end

-- Group name for a stem (folder chain + track name), nil when nothing matches
function M.group_for(profile, folders, track)
    local segs = {}
    for _, x in ipairs(folders) do segs[#segs + 1] = x end
    segs[#segs + 1] = track
    local full = table.concat(segs, "/"):lower()
    local best, bestlen
    for prefix, g in pairs(profile.assign or {}) do
        local pl = prefix:lower()
        if full == pl or full:sub(1, #pl + 1) == pl .. "/" then
            if not bestlen or #pl > bestlen then best, bestlen = g, #pl end
        end
    end
    if best then return best end
    local ps = "/" .. full .. "/"
    for _, g in ipairs(profile.groups) do
        local excluded = false
        for _, t in ipairs(g.exclude or {}) do
            if t ~= "" and ps:find(t:lower(), 1, true) then excluded = true break end
        end
        if not excluded then
            for _, t in ipairs(g.match or {}) do
                if t ~= "" and ps:find(t:lower(), 1, true) then return g.name end
            end
        end
    end
end

-- Put each stem under its group (stem.folders = { group }); the original chain stays in stem.orig
-- so the same instrument still merges across cues. Stems assigned SKIP are dropped.
function M.apply_groups(cues, profile)
    for _, cue in ipairs(cues) do
        local kept = {}
        for _, s in ipairs(cue.stems) do
            s.orig = s.orig or s.folders
            local g = M.group_for(profile, s.orig, s.track)
            if g ~= M.SKIP then
                s.folders = { g or M.UNASSIGNED }
                kept[#kept + 1] = s
            end
        end
        cue.stems = kept
    end
end

-- Folder prefixes (first `assign_depth` folders) of stems no group matches, with stem counts
function M.unassigned(cues, profile)
    local depth, counts, order = profile.assign_depth or 3, {}, {}
    for _, cue in ipairs(cues) do
        for _, s in ipairs(cue.stems) do
            local orig = s.orig or s.folders
            if M.group_for(profile, orig, s.track) == nil then
                local key = table.concat(orig, "/", 1, math.min(depth, #orig))
                if key == "" then key = s.track end
                if not counts[key] then counts[key] = 0 order[#order + 1] = key end
                counts[key] = counts[key] + 1
            end
        end
    end
    table.sort(order)
    local out = {}
    for _, k in ipairs(order) do out[#out + 1] = { key = k, count = counts[k] } end
    return out
end

-- group name -> position, so groups come out in the profile's order
function M.order_map(profile)
    local m = {}
    for i, g in ipairs(profile.groups) do m[g.name] = i end
    m[M.UNASSIGNED] = #profile.groups + 1
    return m
end

-- Shortest track names that are unique within a group: the last path segment, plus parent
-- segments only where two instruments would otherwise share a name. Repeats ("PSU Organ/PSU Organ")
-- collapse first.
local function short_names(order)
    local byg = {}
    for _, l in ipairs(order) do
        if l.grouped then byg[l.fpath[1]] = byg[l.fpath[1]] or {} table.insert(byg[l.fpath[1]], l) end
    end
    for _, list in pairs(byg) do
        for _, l in ipairs(list) do
            local sg = {}
            for _, x in ipairs(l.segs) do
                if not sg[#sg] or sg[#sg]:lower() ~= x:lower() then sg[#sg + 1] = x end
            end
            l.sg, l.k = sg, 1
        end
        local function nm(l)
            return table.concat(l.sg, " ", math.max(1, #l.sg - l.k + 1), #l.sg) .. (l.dup and (" " .. l.dup) or "")
        end
        for _ = 1, 10 do
            local seen, changed = {}, false
            for _, l in ipairs(list) do
                local n = nm(l):lower()
                seen[n] = seen[n] or {}
                table.insert(seen[n], l)
            end
            for _, ls in pairs(seen) do
                if #ls > 1 then
                    for _, l in ipairs(ls) do if l.k < #l.sg then l.k = l.k + 1 changed = true end end
                end
            end
            if not changed then break end
        end
        for _, l in ipairs(list) do l.name = nm(l) end
    end
end

---------------------------------------------------------------------------- tree

-- How a major section is laid out:
--   individual  one track per instrument (the stem's own name)
--   folder      stems of the same lowest folder share as few tracks as possible ("Hang 1", "Hang 2")
--   sub         stems of the same sub-folder of the section ("Violins 1", ...)
--   section     all stems of the section ("Strings 1", "Strings 2", ...)
M.MODES = { "individual", "folder", "sub", "section" }
M.MODE_LABELS = {
    individual = "Individual tracks",
    folder = "Consolidate: lowest folder (Hang 1, Hang 2...)",
    sub = "Consolidate: sub-folder (Violins 1, Violins 2...)",
    section = "Consolidate: whole section (Strings 1, Strings 2...)",
}

-- A leaf is one instrument track as named in the stems: { fpath = folder chain, name, items, cues }.
-- A second stem for the same leaf in the same cue becomes its own leaf ("name 2").
local function leaf_for(map, order, cue_code, stem)
    local name = M.clean_name(stem.track)
    local ident = stem.orig or stem.folders -- the original chain, so grouped stems still merge across cues
    local base = table.concat(ident, "\1") .. "\2"
    local n, key = 1, base .. name
    local shown = name
    while map[key] and map[key].cues[cue_code] do
        n = n + 1
        shown = name .. " " .. n
        key = base .. shown
    end
    if not map[key] then
        local segs = {}
        for _, x in ipairs(ident) do segs[#segs + 1] = x end
        segs[#segs + 1] = name
        map[key] = { fpath = stem.folders, name = shown, items = {}, cues = {}, segs = segs,
            dup = n > 1 and n or nil, grouped = stem.orig ~= nil }
        order[#order + 1] = map[key]
    end
    map[key].cues[cue_code] = true
    return map[key]
end

-- Number of distinct second-level folders under each top-level folder.
local function folder_children(leaves)
    local sets, counts = {}, {}
    for _, l in ipairs(leaves) do
        local top, second = l.fpath[1], l.fpath[2]
        if top and second then sets[top] = sets[top] or {} sets[top][second] = true end
    end
    for top, set in pairs(sets) do
        local k = 0
        for _ in pairs(set) do k = k + 1 end
        counts[top] = k
    end
    return counts
end

-- Depth of the "major section" level under a top-level folder: a folder with 2+ sub-folders
-- is a grouping (Orchestra -> Strings, ...), anything else is its own section. `override`
-- forces one level for everything (1 = top level, 2 = next, ...).
local function section_depth(top, counts, override)
    if override and override > 0 then return override end
    return ((counts[top] or 0) >= 2) and 2 or 1
end

-- Section of a path (list of names). A folder track above the section level has none.
local function section_of(path, counts, override, is_folder)
    if #path == 0 then return nil end
    local d = section_depth(path[1], counts, override)
    if #path >= d then return path[d] end
    if not is_folder then return path[#path] end
end

local function leaf_section(leaf, counts, override)
    local p = { table.unpack(leaf.fpath) }
    p[#p + 1] = leaf.name
    return section_of(p, counts, override, false)
end

-- Sorted section names for a set of loaded cues (stem filenames only, no audio is read).
function M.sections(cues, override, profile)
    if profile then
        M.apply_groups(cues, profile)
        local present, names = {}, {}
        for _, cue in ipairs(cues) do for _, s in ipairs(cue.stems) do present[s.folders[1]] = true end end
        for _, g in ipairs(profile.groups) do
            if present[g.name] then names[#names + 1] = g.name present[g.name] = nil end
        end
        local rest = {}
        for n in pairs(present) do if n ~= M.UNASSIGNED then rest[#rest + 1] = n end end
        table.sort(rest)
        for _, n in ipairs(rest) do names[#names + 1] = n end
        if present[M.UNASSIGNED] then names[#names + 1] = M.UNASSIGNED end
        return names
    end
    local map, order = {}, {}
    for _, cue in ipairs(cues) do
        for _, s in ipairs(cue.stems) do leaf_for(map, order, cue.code, s) end
    end
    local counts, set, names = folder_children(order), {}, {}
    for _, l in ipairs(order) do
        local sec = leaf_section(l, counts, override)
        if sec and not set[sec] then set[sec] = true names[#names + 1] = sec end
    end
    table.sort(names, function(a, b) if a:lower() ~= b:lower() then return a:lower() < b:lower() end return a < b end)
    return names
end

-- Where a leaf goes for a mode: the group path (folder chain of its track) and whether it is
-- a single named track ("exact") rather than a pool packed into numbered lanes.
local function group_of(leaf, mode, counts, override)
    local fp = leaf.fpath
    if mode == "individual" then
        local p = { table.unpack(fp) }
        p[#p + 1] = leaf.name
        return p, true
    end
    if #fp == 0 then return { "Unsorted" }, false end
    local keep = #fp
    if mode ~= "folder" then
        local d = section_depth(fp[1], counts, override)
        keep = (mode == "section") and d or d + 1
    end
    return { table.unpack(fp, 1, math.min(keep, #fp)) }, false
end

-- Items onto as few lanes as possible (greedy by start time, which is optimal for intervals).
local function lanes(items)
    local sorted = {}
    for _, it in ipairs(items) do sorted[#sorted + 1] = it end
    table.sort(sorted, function(a, b) if a.pos ~= b.pos then return a.pos < b.pos end return a.label < b.label end)
    local out, ends = {}, {}
    for _, it in ipairs(sorted) do
        local placed
        for i, e in ipairs(ends) do
            if it.pos >= e - 0.0005 then placed = i break end
        end
        if not placed then placed = #ends + 1 ends[placed] = 0 out[placed] = {} end
        ends[placed] = it.pos + (it.len > 0 and it.len or 0.001)
        out[placed][#out[placed] + 1] = it
    end
    return out
end

local function trie_node(root, path)
    local n = root
    for _, p in ipairs(path) do
        n.kids[p] = n.kids[p] or { name = p, kids = {} }
        n = n.kids[p]
    end
    return n
end

local function sorted_keys(kids, order)
    local keys = {}
    for k in pairs(kids) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if order then
            local oa, ob = order[a], order[b]
            if oa and ob then return oa < ob end
            if oa then return true end
            if ob then return false end
        end
        if a:lower() ~= b:lower() then return a:lower() < b:lower() end
        return a < b
    end)
    return keys
end

-- Flatten a trie to { {name, depth, folder?, items?, section, group?} ... }. A node with children
-- is a folder track (its own stems go inside it first); a node without is just its lane tracks.
local function emit(node, depth, path, out, ctx)
    path[#path + 1] = node.name
    local selfs = {}
    if node.pool then
        for i, items in ipairs(lanes(node.pool)) do
            selfs[#selfs + 1] = { name = node.name .. " " .. i, group = node.name, items = items }
        end
    end
    if node.exact then selfs[#selfs + 1] = { name = node.name, items = node.exact } end
    local keys = sorted_keys(node.kids, ctx.order)
    local d = depth
    if #keys > 0 then
        out[#out + 1] = { name = node.name, depth = depth, folder = true, section = section_of(path, ctx.counts, ctx.override, true) }
        d = depth + 1
    end
    local sec = section_of(path, ctx.counts, ctx.override, false)
    for _, e in ipairs(selfs) do e.depth, e.section = d, sec out[#out + 1] = e end
    for _, k in ipairs(keys) do emit(node.kids[k], d, path, out, ctx) end
    path[#path] = nil
end

local function emit_root(root, depth, out, ctx)
    for _, k in ipairs(sorted_keys(root.kids, ctx.order)) do emit(root.kids[k], depth, {}, out, ctx) end
end

---------------------------------------------------------------------------- colours

local PALETTE = { {230, 80, 80}, {235, 140, 60}, {225, 190, 60}, {150, 200, 70}, {70, 180, 110}, {60, 190, 190},
    {70, 140, 230}, {110, 100, 230}, {170, 100, 220}, {220, 100, 180}, {170, 130, 90}, {120, 150, 170} }
local SPECIAL = { click = {140, 140, 140}, fx = {235, 235, 235}, cue = {70, 70, 70}, ref = {190, 190, 190}, ret = {200, 215, 235} }

local function native(rgb) return reaper.ColorToNative(rgb[1], rgb[2], rgb[3]) | 0x1000000 end

-- Colour tracks by the major section the plan assigned them. Click / FX RETURN / per-cue folders
-- get fixed neutral colours. Returns the sorted section names.
function M.colour(out, group_rgb, fx_rgb)
    local set, names = {}, {}
    for _, e in ipairs(out) do
        if not e.special and e.section and not set[e.section] then set[e.section] = true names[#names + 1] = e.section end
    end
    table.sort(names, function(a, b) if a:lower() ~= b:lower() then return a:lower() < b:lower() end return a < b end)
    local idx = {}
    for i, n in ipairs(names) do idx[n] = (group_rgb and group_rgb[n]) or PALETTE[(i - 1) % #PALETTE + 1] end
    for _, e in ipairs(out) do
        local rgb = e.special and ((e.special == "fx" and fx_rgb) or SPECIAL[e.special]) or (e.section and idx[e.section])
        if rgb then e.color = native(rgb) end
    end
    return names
end

---------------------------------------------------------------------------- build

local function item_pos(path, fallback_name)
    local info = M.wav_info(path)
    if info and info.tref then return info.tref, true, info.len end
    return tc_from_name(fallback_name or path), false, info and info.len
end

-- Plan the track list. opts = { mode = default mode, modes = { [section] = mode }, override = section level }
-- Returns out (flat track list), problems.
function M.plan(cues, layout, variant, opts)
    opts = opts or {}
    local problems = {}
    local refs = opts.refs or {}
    local want_click = refs.click ~= false -- the click reference is on unless switched off
    if opts.profile then M.apply_groups(cues, opts.profile) end
    local function add_item(list, cue, path, label, name_hint, stem)
        local pos, bwf, len = item_pos(path, name_hint or path)
        if not pos then
            problems[#problems + 1] = cue.code .. ": no timestamp for " .. label .. ", skipped"
        else
            if not bwf then problems[#problems + 1] = cue.code .. ": no BWF time in " .. label .. ", used filename TC" end
            list[#list + 1] = { path = path, pos = pos, len = len or 0, label = label, sends = stem and stem.sends, cue = cue }
        end
    end

    -- leaves: one shared collection (by instrument) or one per cue (checkerboard)
    local shared_map, shared_order = {}, {}
    local per_cue, all = {}, {}
    for ci, cue in ipairs(cues) do
        local map, order = shared_map, shared_order
        if layout == 2 then map, order = {}, {} per_cue[ci] = order end
        for _, s in ipairs(cue.stems) do
            local leaf = leaf_for(map, order, cue.code, s)
            add_item(leaf.items, cue, s.path, s.file, s.tc or "", s)
        end
    end
    if opts.profile then
        if layout == 2 then for _, order in ipairs(per_cue) do short_names(order) end else short_names(shared_order) end
        local n = 0
        for _, cue in ipairs(cues) do for _, s in ipairs(cue.stems) do if s.folders[1] == M.UNASSIGNED then n = n + 1 end end end
        if n > 0 then problems[#problems + 1] = n .. " stems matched no group and sit in \"" .. M.UNASSIGNED .. "\"" end
    end
    if layout == 2 then
        for _, order in ipairs(per_cue) do for _, l in ipairs(order) do all[#all + 1] = l end end
    else
        all = shared_order
    end
    local ctx = { counts = folder_children(all), override = opts.profile and 1 or opts.override,
        order = opts.profile and M.order_map(opts.profile) or nil }

    local function trie_for(order)
        local root = { kids = {} }
        for _, leaf in ipairs(order) do
            local mode = (opts.modes and opts.modes[leaf_section(leaf, ctx.counts, ctx.override)]) or opts.mode or "individual"
            local gpath, exact = group_of(leaf, mode, ctx.counts, ctx.override)
            local node = trie_node(root, gpath)
            if exact then
                node.exact = leaf.items
            else
                node.pool = node.pool or {}
                for _, it in ipairs(leaf.items) do node.pool[#node.pool + 1] = it end
            end
        end
        return root
    end

    local out = {}
    local want_fx = variant == "DRY"
    if layout == 1 then
        local click = { name = "Click", depth = 0, items = {}, special = "click" }
        local fx = { name = "FX RETURN", depth = 0, items = {}, special = "fx" }
        local mref = { name = "Master Ref", depth = 0, items = {}, special = "ref", mute = refs.mute }
        for _, cue in ipairs(cues) do
            if cue.click and want_click then add_item(click.items, cue, cue.click, cue.code .. " CLICK") end
            if cue.masterref and refs.master then add_item(mref.items, cue, cue.masterref, cue.code .. " MASTER REF") end
            if cue.fxreturn and want_fx then add_item(fx.items, cue, cue.fxreturn, cue.code .. " FX RETURN") end
        end
        if #click.items > 0 then out[#out + 1] = click end
        if #mref.items > 0 then out[#out + 1] = mref end
        emit_root(trie_for(shared_order), 0, out, ctx)
        if #fx.items > 0 then out[#out + 1] = fx end
    else
        for ci, cue in ipairs(cues) do
            out[#out + 1] = { name = cue.name, depth = 0, folder = true, special = "cue" }
            if cue.click and want_click then
                local t = { name = "Click", depth = 1, items = {}, special = "click" }
                add_item(t.items, cue, cue.click, cue.code .. " CLICK")
                out[#out + 1] = t
            end
            if cue.masterref and refs.master then
                local t = { name = "Master Ref", depth = 1, items = {}, special = "ref", mute = refs.mute }
                add_item(t.items, cue, cue.masterref, cue.code .. " MASTER REF")
                out[#out + 1] = t
            end
            emit_root(trie_for(per_cue[ci]), 1, out, ctx)
            if cue.fxreturn and want_fx then
                local t = { name = "FX RETURN", depth = 1, items = {}, special = "fx" }
                add_item(t.items, cue, cue.fxreturn, cue.code .. " FX RETURN")
                out[#out + 1] = t
            end
        end
    end
    if opts.sends and opts.sends.on and variant == "DRY" then
        local lines, sp, nret = dofile(SCRIPT_DIR .. "jk_mixsends.lua").finish(out, cues, reaper.ScaleFromEnvelopeMode)
        out.sendlines, out.nret = lines, nret
        for _, p in ipairs(sp) do problems[#problems + 1] = p end
    end
    return out, problems
end

-- Create the planned tracks and items in the open project. Returns tracks, items created.
function M.create(out, opts)
    local offs = reaper.GetProjectTimeOffset(0, false)
    local base = reaper.CountTracks(0)
    local n_items = 0
    local made = {}
    for i, e in ipairs(out) do
        reaper.InsertTrackAtIndex(base + i - 1, true)
        local tr = reaper.GetTrack(0, base + i - 1)
        made[i] = tr
        reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", e.name, true)
        if e.color then reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", e.color) end
        if e.mute then reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 1) end
        local nd = out[i + 1] and out[i + 1].depth or 0
        reaper.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", nd > e.depth and 1 or (nd - e.depth))
        for _, it in ipairs(e.items or {}) do
            local src = reaper.PCM_Source_CreateFromFile(it.path)
            if src then
                local item = reaper.AddMediaItemToTrack(tr)
                local take = reaper.AddTakeToMediaItem(item)
                reaper.SetMediaItemTake_Source(take, src)
                reaper.SetMediaItemInfo_Value(item, "D_POSITION", it.pos - offs)
                reaper.SetMediaItemInfo_Value(item, "D_LENGTH", (reaper.GetMediaSourceLength(src)))
                reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", (it.label:gsub("%.[Ww][Aa][Vv]$", "")), true)
                n_items = n_items + 1
            end
        end
    end
    local n_sends, send_problems = 0, {}
    if out.sendlines then
        n_sends, send_problems = dofile(SCRIPT_DIR .. "jk_mixsends.lua").apply(out, made, offs, opts and opts.sends)
    end
    return #out, n_items, n_sends, send_problems
end

local function summarize(out)
    local lines, tracks, folders = {}, 0, 0
    for _, e in ipairs(out) do
        if e.folder then folders = folders + 1 else tracks = tracks + 1 end
    end
    return tracks, folders
end
M.summarize = summarize

---------------------------------------------------------------------------- entry

-- The note-bearing RPP of a cue's chosen export: <cue folder>/<export name>.rpp (the export folder is
-- named after the project), else the newest RPP in the cue folder
local function rpp_for(c)
    local notes = dofile(SCRIPT_DIR .. "jk_mixnotes.lua")
    local cuedir, ver = (c.mt or c.dir or ""):match("^(.*)/exports/([^/]+)/[^/]+$") -- loaded cues keep the MULTITRACK folder in .dir
    if not cuedir then return nil end
    local path
    for _, ext in ipairs({ ".RPP", ".rpp" }) do
        if reaper.file_exists(cuedir .. "/" .. ver .. ext) then path = cuedir .. "/" .. ver .. ext break end
    end
    if not path then
        local best = notes.newest_rpp(cuedir, c.code)
        if not best then return nil end
        path = cuedir .. "/" .. best
    end
    return { code = c.code, file = path:match("([^/]*)$"), path = path }, notes
end

-- Run a build. opts = { variant, layout (1|2), pack (bool), cues = { {code, name, stemdir, mt}, ... } }
function M.build(opts)
    local cues, problems = {}, {}
    for _, c in ipairs(opts.cues) do
        local cue = M.load_cue(c.code, c.name, c.stemdir, c.mt, opts.variant)
        if #cue.stems == 0 then problems[#problems + 1] = c.code .. ": no " .. opts.variant .. " stems in " .. c.stemdir
        else cues[#cues + 1] = cue end
    end
    if #cues == 0 then
        reaper.ShowMessageBox("Nothing to build.\n\n" .. table.concat(problems, "\n"), "Mix session", 0)
        return
    end
    -- read each cue session's FX-return sends (dry builds only; wet stems already contain the reverb)
    local use_sends = opts.sends and opts.sends.on and opts.variant == "DRY"
    if use_sends then
        local sm = dofile(SCRIPT_DIR .. "jk_mixsends.lua")
        for _, c in ipairs(cues) do
            local info = rpp_for(c)
            if not info then
                problems[#problems + 1] = c.code .. ": no session file found, reverb sends skipped"
            else
                local rpp, err = sm.parse_rpp(info.path)
                if not rpp then problems[#problems + 1] = c.code .. ": " .. err
                else
                    for _, p in ipairs(sm.match(c, rpp, sm.analyse(rpp))) do problems[#problems + 1] = p end
                end
            end
        end
    end
    local out, plan_problems = M.plan(cues, opts.layout, opts.variant,
        { mode = opts.mode, modes = opts.modes, override = opts.section_depth, profile = opts.profile, refs = opts.refs,
          sends = use_sends and opts.sends or nil })
    for _, p in ipairs(plan_problems) do problems[#problems + 1] = p end
    local sections
    if opts.colour then
        local gc, fxc
        if opts.profile then
            gc = {}
            for _, g in ipairs(opts.profile.groups) do gc[g.name] = g.color end
            fxc = opts.profile.fx_group and gc[opts.profile.fx_group] or nil
        end
        sections = M.colour(out, gc, fxc)
    end
    -- items sit at film time minus the project's start offset: warn if this project has none
    local first
    for _, e in ipairs(out) do for _, it in ipairs(e.items or {}) do if not first or it.pos < first then first = it.pos end end end
    if first and first > 3600 and reaper.GetProjectTimeOffset(0, false) == 0 then
        problems[#problems + 1] = "project start offset is 0, so items sit about " .. math.floor(first / 3600) .. " h into the timeline (use a template with the film's start offset)"
    end

    -- note items from the cues' own sessions go in first, so they sit above the new stem tracks
    local note_lines, notes_report
    if opts.notes and next(opts.notes) then
        local ncues, notes = {}, nil
        for _, c in ipairs(cues) do
            local info, mod = rpp_for(c)
            if info then notes = mod ncues[#ncues + 1] = info else problems[#problems + 1] = c.code .. ": no session file found for notes" end
        end
        if #ncues > 0 then
            local nreport, by_track, total, first, nproblems = notes.import(ncues, { tracks = opts.notes })
            note_lines = {}
            for _, name in ipairs(notes.TRACKS) do
                if opts.notes[name] then note_lines[#note_lines + 1] = string.format("%s %d", name, by_track[name] or 0) end
            end
            note_lines = "Notes imported (" .. total .. "): " .. table.concat(note_lines, ", ")
            if first then
                note_lines = note_lines .. string.format("  [first note at %d:%02d:%02d project time]",
                    math.floor(first // 3600), math.floor((first % 3600) // 60), math.floor(first % 60))
            end
            for _, pr in ipairs(nproblems or {}) do problems[#problems + 1] = pr end
            notes_report = nreport
        end
    end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    local n_tracks, n_items, n_sends, send_problems = M.create(out, { sends = opts.sends })
    for _, p in ipairs(send_problems or {}) do problems[#problems + 1] = p end
    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Build " .. opts.variant:lower() .. " mix session", -1)

    local lines = { string.format("%d tracks, %d items from %d cues (%s, %s%s).", n_tracks, n_items, #cues, opts.variant,
        opts.layout == 1 and "by instrument" or "by cue", (opts.mode and opts.mode ~= "individual") and ", consolidated" or ""), "" }
    for _, c in ipairs(cues) do lines[#lines + 1] = c.name .. "  (" .. #c.stems .. " stems)" end
    if note_lines then lines[#lines + 1] = "" lines[#lines + 1] = note_lines end
    if out.sendlines then
        local sheet = (opts.sheet_path and opts.sheet_path ~= "") and opts.sheet_path or (SCRIPT_DIR .. "mixbuild_sends.tsv")
        local ok = dofile(SCRIPT_DIR .. "jk_mixsends.lua").sheet(out.sendlines, sheet)
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("Reverb sends: %d sends rebuilt to %d return tracks%s", n_sends or 0, out.nret or 0,
            ok and ("; send sheet: " .. sheet) or "")
    end
    if sections and #sections > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Coloured sections: " .. table.concat(sections, ", ")
    end
    if #problems > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Notes:"
        for i, p in ipairs(problems) do
            if i > 25 then lines[#lines + 1] = "  ... and " .. (#problems - 25) .. " more" break end
            lines[#lines + 1] = "  " .. p
        end
    end
    -- keep a log of every build (what was asked for, what came in), beside this file
    local lf = io.open(SCRIPT_DIR .. "mixbuild_log.txt", "a")
    if lf then
        lf:write("=== ", os.date("%Y-%m-%d %H:%M:%S"), "  ", opts.variant, "  notes=", table.concat((function()
            local t = {} for k in pairs(opts.notes or {}) do t[#t + 1] = k end table.sort(t) return t end)(), ";"), "\n")
        lf:write(table.concat(lines, "\n"), "\n")
        if notes_report then lf:write("--- notes report\n", notes_report, "\n") end
        lf:close()
    end
    if opts.quiet then return table.concat(lines, "\n"), n_tracks end
    reaper.ShowMessageBox(table.concat(lines, "\n"), "Mix session built", 0)
end

local function safe_name(n) return (n:gsub('[\\/:*?"<>|]', "_")) end

-- One session per cue: a new project tab for each (optionally from a template, which should carry
-- the film's project start offset), built from that cue alone, then saved as
-- <outdir>/<cue> - MIX <DRY|WET>/<cue> - MIX <DRY|WET>.rpp
function M.build_each(opts)
    local outdir = (opts.outdir and opts.outdir ~= "") and opts.outdir or ((opts.root or "") .. "/_MIX SESSIONS")
    local lines = {}
    for _, c in ipairs(opts.cues) do
        reaper.Main_OnCommand(40859, 0) -- File: New project tab
        if opts.template and opts.template ~= "" then reaper.Main_openProject("template:" .. opts.template) end
        local o = {}
        for k, v in pairs(opts) do o[k] = v end
        local name = safe_name(c.name) .. " - MIX " .. opts.variant
        local dir = outdir .. "/" .. name
        reaper.RecursiveCreateDirectory(dir, 0)
        o.cues, o.quiet, o.sheet_path = { c }, true, dir .. "/" .. name .. " - reverb sends.tsv"
        local text, n = M.build(o)
        reaper.Main_SaveProjectEx(0, dir .. "/" .. name .. ".rpp", 0)
        lines[#lines + 1] = string.format("%s: %s tracks", name, tostring(n or 0))
        local extra = text and text:match("Notes:.*$")
        if extra then lines[#lines + 1] = "  " .. extra:gsub("\n", "\n  ") end
    end
    reaper.ShowMessageBox(table.concat(lines, "\n") .. "\n\nSaved under " .. outdir, "Mix sessions built", 0)
end

local function root_folder()
    local root = reaper.GetExtState(EXT_SECTION, "root")
    return root ~= "" and root or M.DEFAULT_ROOT
end

-- ReaImGui picker: root folder, dry/wet, layout, packing, and per cue: include, which export
-- version (default newest) or a folder of your choice.
function M.pick(variant)
    if not reaper.ImGui_CreateContext then
        reaper.ShowMessageBox("ReaImGui is required for the picker.", "Mix session", 0)
        return
    end
    local ctx = reaper.ImGui_CreateContext("JK Build Mix Session")
    local function flag(k, d) local v = reaper.GetExtState(EXT_SECTION, k) if v == "" then return d end return v end
    local st = {
        root = root_folder(), variant = variant or flag("variant", "DRY"),
        layout = tonumber(flag("layout", "1")), mode = flag("mode", "individual"), modes = {},
        colour = flag("colour", "1") == "1", sdepth = tonumber(flag("sdepth", "0")) or 0,
        rows = {}, extra = {}, rev = 0,
        usegroups = flag("usegroups", "0") == "1", pname = flag("profile", "HGG"),
        outdir = flag("outdir", ""), template = flag("template", ""), newname = "",
        notes = {}, sends_on = flag("sends_on", "0") == "1", sends_ph = flag("sends_ph", "0") == "1", ref_click = flag("ref_click", "1") == "1", ref_master = flag("ref_master", "0") == "1", ref_mute = flag("ref_mute", "1") == "1",
    }
    for name in (flag("notes", "") .. ";"):gmatch("([^;]*);") do if name ~= "" then st.notes[name] = true end end
    st.profile_names = M.list_profiles()
    local function split_terms(text)
        local t = {}
        for term in (text .. ","):gmatch("([^,]*),") do
            term = term:match("^%s*(.-)%s*$")
            if term ~= "" then t[#t + 1] = term end
        end
        return t
    end
    local function prep(profile) -- text buffers for the group editor
        for _, g in ipairs(profile.groups) do
            g.match_text = table.concat(g.match or {}, ", ")
            g.exclude_text = table.concat(g.exclude or {}, ", ")
        end
        return profile
    end
    st.profile = prep(M.load_profile(st.pname))
    local function bump() st.rev = st.rev + 1 st.sig = nil end
    for sec, m in flag("modes", ""):gmatch("([^;=]+)=([^;]+)") do
        if M.MODE_LABELS[m] then st.modes[sec] = m end
    end
    if not M.MODE_LABELS[st.mode] then st.mode = "individual" end

    local function selected_cues()
        local cues = {}
        for _, r in ipairs(st.rows) do
            if r.on and #r.versions > 0 then
                local v = r.versions[r.sel]
                if r.custom then
                    cues[#cues + 1] = { code = r.code, name = r.custom:match("([^/\\]*)$"), stemdir = r.cstem, mt = r.cmt }
                else
                    cues[#cues + 1] = { code = r.code, name = v.name, stemdir = v.stemdir, mt = v.mt }
                end
            end
        end
        for _, x in ipairs(st.extra) do
            if x.on then cues[#cues + 1] = { code = x.code, name = x.name, stemdir = x.stemdir, mt = x.mt } end
        end
        return cues
    end

    -- sections of the selected cues, recomputed only when the selection or section level changes
    local function current_info()
        local cues = selected_cues()
        local parts = { tostring(st.sdepth), st.variant, st.usegroups and ("g" .. st.rev) or "n" }
        for _, c in ipairs(cues) do parts[#parts + 1] = c.stemdir end
        local sig = table.concat(parts, "|")
        if st.sig ~= sig then
            local loaded = {}
            for _, c in ipairs(cues) do loaded[#loaded + 1] = M.load_cue(c.code, c.name, c.stemdir, c.mt, st.variant) end
            st.unassigned = st.usegroups and M.unassigned(loaded, st.profile) or {}
            st.sections, st.sig = M.sections(loaded, st.sdepth, st.usegroups and st.profile or nil), sig
        end
        return st.sections, st.unassigned
    end

    -- combo of the layout modes; returns the picked mode, false for "(default)", or nil if unchanged
    local function mode_combo(id, current, allow_default)
        local preview = current and M.MODE_LABELS[current] or "(default)"
        reaper.ImGui_SetNextItemWidth(ctx, 360)
        local pick
        if reaper.ImGui_BeginCombo(ctx, id, preview) then
            if allow_default and reaper.ImGui_Selectable(ctx, "(default)", current == nil) then pick = false end
            for _, m in ipairs(M.MODES) do
                if reaper.ImGui_Selectable(ctx, M.MODE_LABELS[m], current == m) then pick = m end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        return pick
    end

    local function rescan()
        st.rows = M.scan(st.root, st.variant)
        for _, r in ipairs(st.rows) do r.on, r.sel = #r.versions > 0, 1 end
        for _, x in ipairs(st.extra) do x.stems = nil end
    end
    rescan()

    local function stem_count(dir)
        st.counts = st.counts or {}
        if not st.counts[dir] then
            local n = 0
            for _, f in ipairs(files(dir)) do if M.parse_stem(f, st.variant:lower()) then n = n + 1 end end
            st.counts[dir] = n
        end
        return st.counts[dir]
    end

    local function browse(title, from)
        if not reaper.JS_Dialog_BrowseForFolder then
            reaper.ShowMessageBox("The js_ReaScriptAPI extension is needed to browse for folders.", "Mix session", 0)
            return nil
        end
        local ok, picked = reaper.JS_Dialog_BrowseForFolder(title, from or st.root)
        if ok == 1 and picked and picked ~= "" then return picked end
    end

    local result
    local function loop()
        reaper.ImGui_SetNextWindowSize(ctx, 760, 560, reaper.ImGui_Cond_FirstUseEver())
        local visible, open = reaper.ImGui_Begin(ctx, "Build mix session", true)
        if visible then
            local _
            reaper.ImGui_Text(ctx, "Cue folders:  " .. st.root)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Change...##root") then
                local p = browse("Folder holding the cue folders (1M01 - ..., 1M02 - ...)")
                if p then st.root = p st.counts = nil rescan() end
            end
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Stems:")
            for _, v in ipairs({ "DRY", "WET" }) do
                reaper.ImGui_SameLine(ctx)
                local pressed = reaper.ImGui_RadioButton(ctx, v, st.variant == v)
                if pressed and st.variant ~= v then st.variant = v st.counts = nil rescan() end
            end
            reaper.ImGui_Text(ctx, "Layout:")
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_RadioButton(ctx, "Grouped by instrument", st.layout == 1) then st.layout = 1 end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_RadioButton(ctx, "Checkerboard by cue", st.layout == 2) then st.layout = 2 end
            reaper.ImGui_Text(ctx, "Tracks:")
            reaper.ImGui_SameLine(ctx)
            local picked_mode = mode_combo("##defmode", st.mode, false)
            if picked_mode then st.mode = picked_mode end
            _, st.colour = reaper.ImGui_Checkbox(ctx, "Colour tracks by major section / group (for bus FX)", st.colour)
            if st.colour and not st.usegroups then
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, 90)
                _, st.sdepth = reaper.ImGui_InputInt(ctx, "section folder level (0 = auto)", st.sdepth)
                if st.sdepth < 0 then st.sdepth = 0 end
            end
            reaper.ImGui_Text(ctx, "Bring in:")
            reaper.ImGui_SameLine(ctx)
            _, st.ref_click = reaper.ImGui_Checkbox(ctx, "Click", st.ref_click)
            reaper.ImGui_SameLine(ctx)
            _, st.ref_master = reaper.ImGui_Checkbox(ctx, "Master reference (MASTER REF)", st.ref_master)
            if st.ref_master then
                reaper.ImGui_SameLine(ctx)
                _, st.ref_mute = reaper.ImGui_Checkbox(ctx, "muted", st.ref_mute)
            end
            if st.variant == "DRY" then
                _, st.sends_on = reaper.ImGui_Checkbox(ctx, "Rebuild reverb sends (from each cue session, incl. folder sends + send automation)", st.sends_on)
                if st.sends_on then
                    reaper.ImGui_SameLine(ctx)
                    _, st.sends_ph = reaper.ImGui_Checkbox(ctx, "ReaVerb placeholder on the returns", st.sends_ph)
                end
            end
            reaper.ImGui_Text(ctx, "Notes from the cue sessions:")
            for _, name in ipairs({ "Picture Markers", "Beat Markers", "Orch-Mix Markers", "Utility + To-Do" }) do
                reaper.ImGui_SameLine(ctx)
                local on
                on, st.notes[name] = reaper.ImGui_Checkbox(ctx, name, st.notes[name] or false)
                if not st.notes[name] then st.notes[name] = nil end
            end
            local ugc
            ugc, st.usegroups = reaper.ImGui_Checkbox(ctx, "Group by my instrument groups (profile)", st.usegroups)
            if ugc then bump() end
            local secs, unassigned = current_info()
            if st.usegroups then
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, 170)
                if reaper.ImGui_BeginCombo(ctx, "##profile", st.pname) then
                    for _, n in ipairs(st.profile_names) do
                        if reaper.ImGui_Selectable(ctx, n, n == st.pname) and n ~= st.pname then
                            M.save_profile(st.profile)
                            st.pname = n
                            st.profile = prep(M.load_profile(n))
                            bump()
                        end
                    end
                    reaper.ImGui_EndCombo(ctx)
                end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, 140)
                _, st.newname = reaper.ImGui_InputText(ctx, "##newprofile", st.newname)
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "New profile (copy groups)") and st.newname:match("%S") then
                    M.save_profile(st.profile)
                    local name = (st.newname:gsub('[\\/:*?"<>|]', "_"))
                    st.profile = prep(M.clone_profile(st.profile, name))
                    M.save_profile(st.profile)
                    st.pname, st.newname = name, ""
                    st.profile_names = M.list_profiles()
                    bump()
                end
                if reaper.ImGui_CollapsingHeader(ctx, "Groups (order = first match wins, also the track order)") then
                    local del, up, dn
                    local nflags = reaper.ImGui_ColorEditFlags_NoInputs and reaper.ImGui_ColorEditFlags_NoInputs() or 0
                    for i, g in ipairs(st.profile.groups) do
                        reaper.ImGui_PushID(ctx, "grp" .. i)
                        g.color = g.color or { 150, 150, 150 }
                        local c = (g.color[1] << 16) | (g.color[2] << 8) | g.color[3]
                        local cc
                        cc, c = reaper.ImGui_ColorEdit3(ctx, "##col", c, nflags)
                        if cc then g.color = { (c >> 16) & 255, (c >> 8) & 255, c & 255 } bump() end
                        reaper.ImGui_SameLine(ctx)
                        reaper.ImGui_SetNextItemWidth(ctx, 170)
                        local nc
                        nc, g.name = reaper.ImGui_InputText(ctx, "##name", g.name)
                        if nc then bump() end
                        reaper.ImGui_SameLine(ctx)
                        reaper.ImGui_SetNextItemWidth(ctx, 300)
                        local mc
                        mc, g.match_text = reaper.ImGui_InputText(ctx, "##match", g.match_text)
                        if mc then g.match = split_terms(g.match_text) bump() end
                        reaper.ImGui_SameLine(ctx)
                        if reaper.ImGui_SmallButton(ctx, "up") then up = i end
                        reaper.ImGui_SameLine(ctx)
                        if reaper.ImGui_SmallButton(ctx, "down") then dn = i end
                        reaper.ImGui_SameLine(ctx)
                        if reaper.ImGui_SmallButton(ctx, "x") then del = i end
                        reaper.ImGui_PopID(ctx)
                    end
                    local gs = st.profile.groups
                    if up and up > 1 then gs[up], gs[up - 1] = gs[up - 1], gs[up] bump() end
                    if dn and dn < #gs then gs[dn], gs[dn + 1] = gs[dn + 1], gs[dn] bump() end
                    if del then table.remove(gs, del) bump() end
                    reaper.ImGui_TextDisabled(ctx, "Match terms: comma separated, tested against the folder path + track name (e.g. woodwinds, clarinet).")
                    if reaper.ImGui_Button(ctx, "Add group") then
                        gs[#gs + 1] = { name = "New group", color = { 150, 150, 150 }, match = {}, exclude = {}, match_text = "", exclude_text = "" }
                        bump()
                    end
                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_SetNextItemWidth(ctx, 90)
                    local dc
                    dc, st.profile.assign_depth = reaper.ImGui_InputInt(ctx, "assign by first N folders", st.profile.assign_depth or 3)
                    if st.profile.assign_depth < 1 then st.profile.assign_depth = 1 end
                    if dc then bump() end
                    reaper.ImGui_SameLine(ctx)
                    if reaper.ImGui_Button(ctx, "Save profile") then M.save_profile(st.profile) end
                end
                if #unassigned > 0 then
                    reaper.ImGui_TextColored(ctx, 0xE8B04AFF, string.format("%d folders match no group (assign once; remembered in the profile):", #unassigned))
                    for i, u in ipairs(unassigned) do
                        reaper.ImGui_PushID(ctx, "un" .. i)
                        reaper.ImGui_Text(ctx, string.format("%s   (%d)", u.key, u.count))
                        reaper.ImGui_SameLine(ctx, 470)
                        reaper.ImGui_SetNextItemWidth(ctx, 210)
                        if reaper.ImGui_BeginCombo(ctx, "##assign", "assign to...") then
                            for _, g in ipairs(st.profile.groups) do
                                if reaper.ImGui_Selectable(ctx, g.name, false) then st.profile.assign[u.key] = g.name bump() end
                            end
                            if reaper.ImGui_Selectable(ctx, M.SKIP .. "  don't import", false) then st.profile.assign[u.key] = M.SKIP bump() end
                            reaper.ImGui_EndCombo(ctx)
                        end
                        reaper.ImGui_PopID(ctx)
                    end
                end
            end
            reaper.ImGui_Separator(ctx)

            reaper.ImGui_Text(ctx, "Cues (default = newest export; pick another version or a folder):")
            if reaper.ImGui_Button(ctx, "All") then for _, r in ipairs(st.rows) do r.on = #r.versions > 0 end end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "None") then for _, r in ipairs(st.rows) do r.on = false end end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Add a folder...") then
                local p = browse("Folder with the stems (MULTITRACK, DRY or WET)")
                if p then
                    local stemdir, mt = M.resolve_folder(p, st.variant)
                    local code = p:match("(%d+M%d+)") or p:match("([^/\\]*)$")
                    st.extra[#st.extra + 1] = { code = code, name = p:match("([^/\\]*)$"), stemdir = stemdir, mt = mt, on = true, custom = true }
                end
            end
            for i, r in ipairs(st.rows) do
                reaper.ImGui_PushID(ctx, "row" .. i)
                local v = r.versions[r.sel]
                if #r.versions == 0 then
                    reaper.ImGui_TextDisabled(ctx, "      " .. r.dir .. "   (no " .. st.variant .. " stems)")
                else
                    _, r.on = reaper.ImGui_Checkbox(ctx, "##on", r.on)
                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_SetNextItemWidth(ctx, 470)
                    local preview = (r.custom and ("folder: " .. r.custom) or (r.sel == 1 and "newest  " or "") .. v.name)
                    if reaper.ImGui_BeginCombo(ctx, "##ver", preview) then
                        for k, ver in ipairs(r.versions) do
                            if reaper.ImGui_Selectable(ctx, (k == 1 and "newest  " or "") .. ver.name, not r.custom and k == r.sel) then
                                r.sel, r.custom, r.cstem, r.cmt = k, nil, nil, nil
                            end
                        end
                        reaper.ImGui_EndCombo(ctx)
                    end
                    reaper.ImGui_SameLine(ctx)
                    if reaper.ImGui_Button(ctx, "Folder...") then
                        local p = browse("Stems for " .. r.code, root_folder() .. "/" .. r.dir)
                        if p then r.cstem, r.cmt = M.resolve_folder(p, st.variant) r.custom = p end
                    end
                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_TextDisabled(ctx, stem_count(r.custom and r.cstem or v.stemdir) .. " stems")
                end
                reaper.ImGui_PopID(ctx)
            end
            local drop
            for i, x in ipairs(st.extra) do
                reaper.ImGui_PushID(ctx, "x" .. i)
                _, x.on = reaper.ImGui_Checkbox(ctx, "##on", x.on)
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_Text(ctx, x.stemdir .. "   " .. stem_count(x.stemdir) .. " stems")
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Remove") then drop = i end
                reaper.ImGui_PopID(ctx)
            end
            if drop then table.remove(st.extra, drop) end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Sections (override the default per section):")
            if st.layout == 2 then
                reaper.ImGui_TextDisabled(ctx, "Checkerboard: stems inside one cue all overlap, so consolidating saves little. It pays off in the grouped layout.")
            end
            for i, sec in ipairs(secs) do
                reaper.ImGui_PushID(ctx, "sec" .. i)
                reaper.ImGui_Text(ctx, string.format("%-22s", sec))
                reaper.ImGui_SameLine(ctx, 190)
                local pick = mode_combo("##secmode", st.modes[sec], true)
                if pick ~= nil then st.modes[sec] = pick or nil end
                reaper.ImGui_PopID(ctx)
            end

            reaper.ImGui_Separator(ctx)
            local function make_result(batch)
                local active = {}
                for _, sec in ipairs(secs) do active[sec] = st.modes[sec] end
                return { variant = st.variant, layout = st.layout, mode = st.mode, modes = active, colour = st.colour,
                    section_depth = st.sdepth, cues = selected_cues(), batch = batch, root = st.root,
                    profile = st.usegroups and st.profile or nil, outdir = st.outdir, template = st.template,
                    refs = { click = st.ref_click, master = st.ref_master, mute = st.ref_mute }, notes = st.notes,
                    sends = { on = st.sends_on, placeholder = st.sends_ph } }
            end
            if reaper.ImGui_Button(ctx, "Build into the open project") then result = make_result(false) end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Build one session per cue (new tabs, saved)") then result = make_result(true) end
            reaper.ImGui_SetNextItemWidth(ctx, 420)
            _, st.outdir = reaper.ImGui_InputText(ctx, "Save sessions in (blank = <cue folders>/_MIX SESSIONS)", st.outdir)
            reaper.ImGui_SetNextItemWidth(ctx, 420)
            _, st.template = reaper.ImGui_InputText(ctx, "Template .rpp (optional; give it the film's start offset)", st.template)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Close") then open = false end
        end
        reaper.ImGui_End(ctx)
        if result then
            reaper.SetExtState(EXT_SECTION, "root", st.root, true)
            reaper.SetExtState(EXT_SECTION, "variant", st.variant, true)
            reaper.SetExtState(EXT_SECTION, "layout", tostring(st.layout), true)
            reaper.SetExtState(EXT_SECTION, "mode", st.mode, true)
            local parts = {}
            for sec, m in pairs(st.modes) do parts[#parts + 1] = sec .. "=" .. m end
            table.sort(parts)
            reaper.SetExtState(EXT_SECTION, "modes", table.concat(parts, ";"), true)
            reaper.SetExtState(EXT_SECTION, "colour", st.colour and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "sdepth", tostring(st.sdepth), true)
            local nl = {}
            for name in pairs(st.notes) do nl[#nl + 1] = name end
            table.sort(nl)
            reaper.SetExtState(EXT_SECTION, "notes", table.concat(nl, ";"), true)
            reaper.SetExtState(EXT_SECTION, "sends_on", st.sends_on and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "sends_ph", st.sends_ph and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "ref_click", st.ref_click and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "ref_master", st.ref_master and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "ref_mute", st.ref_mute and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "usegroups", st.usegroups and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "profile", st.pname, true)
            reaper.SetExtState(EXT_SECTION, "outdir", st.outdir, true)
            reaper.SetExtState(EXT_SECTION, "template", st.template, true)
            M.save_profile(st.profile)
            if reaper.ImGui_DestroyContext then pcall(reaper.ImGui_DestroyContext, ctx) end
            reaper.defer(function() if result.batch then M.build_each(result) else M.build(result) end end)
            return
        end
        if open then reaper.defer(loop) end
    end
    reaper.defer(loop)
end

return M
