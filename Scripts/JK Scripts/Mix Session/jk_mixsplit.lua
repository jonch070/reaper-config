-- Split a combined mix session (.RPP) into one session per cue, working on the file text:
-- REAPER does not need to open it and the source file is never modified.
--
-- Cue regions: the "<cue> MASTER REF" regions (start marker + unnamed end marker with the same id)
-- that the mix builder writes. Each output keeps:
--   * items whose source filename names the cue (stems "... dry - 1M03 - ...", "_1M03 - ... - CLICK")
--   * note items (no source) tagged JK_MIXNOTE <cue>, or untagged ones lying inside the cue's region
--   * items that belong to no cue (picture, dialogue, empty items): kept in every session
--   * markers/regions of that cue, and markers outside every cue region; markers inside another
--     cue's region are dropped
-- Tracks that had items and now have none are removed (a folder goes when all its children go);
-- tracks that were empty to begin with stay. Item times are NOT moved: each session keeps film time.
-- Output files go beside the source (so its relative media paths still resolve):
--   <source name> - <cue code> - <cue name>.RPP
local M = {}

local function read_all(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local s = f:read("*a")
    f:close()
    return s
end

local function split_lines(s)
    local eol = s:find("\r\n", 1, true) and "\r\n" or "\n"
    local lines = {}
    for line in (s .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = line end
    if lines[#lines] == "" then lines[#lines] = nil end
    return lines, eol
end

-- the cue a media file belongs to: the LAST "<code> - " in its name
-- (track names can mention other cues; the cue tail comes after "dry - " / "wet - ")
local function cue_of_file(path)
    local base = path:match("([^/\\]*)$") or path
    local code
    for c in base:gmatch("(%d+M%d+) %- ") do code = c end
    return code
end

-- Parse the file into pre (lines before the first track), tracks, post (everything after).
function M.parse(path)
    local text, err = read_all(path)
    if not text then return nil, err end
    local lines, eol = split_lines(text)
    local doc = { eol = eol, pre = {}, tracks = {}, post = {} }
    local i, n = 1, #lines
    while i <= n and not lines[i]:match("^  <TRACK") do doc.pre[#doc.pre + 1] = lines[i]; i = i + 1 end
    while i <= n and lines[i]:match("^  <TRACK") do
        local tr = { entries = {}, items = {}, nitems = 0 }
        local j, first = i, true
        while j <= n do
            local l = lines[j]
            if not first and l:match("^  >%s*$") then tr.entries[#tr.entries + 1] = l; j = j + 1; break end
            first = false
            if l:match("^    <ITEM") then
                local it = { lines = { l }, is_item = true }
                j = j + 1
                while j <= n and not lines[j]:match("^    >%s*$") do it.lines[#it.lines + 1] = lines[j]; j = j + 1 end
                it.lines[#it.lines + 1] = lines[j]
                tr.items[#tr.items + 1] = it
                tr.entries[#tr.entries + 1] = it
            else
                tr.entries[#tr.entries + 1] = l
            end
            j = j + 1
        end
        tr.nitems = #tr.items
        -- track settings can sit before or after the items, so look at every plain line
        for _, e in ipairs(tr.entries) do
            if type(e) == "string" then
                local nm = e:match("^    NAME%s+(.*)$")
                if nm and not tr.name then tr.name = nm:gsub('^"(.*)"$', "%1") end
                local x, y = e:match("^    ISBUS%s+(%-?%d+)%s+(%-?%d+)")
                if x then tr.isbus_a, tr.isbus_b = tonumber(x), tonumber(y) end
            end
        end
        doc.tracks[#doc.tracks + 1] = tr
        i = j
    end
    while i <= n do doc.post[#doc.post + 1] = lines[i]; i = i + 1 end
    return doc
end

-- cue regions from MASTER REF markers: { {code, name, id, start, stop}, ... }
local function find_regions(doc)
    local regions, byid = {}, {}
    for _, l in ipairs(doc.pre) do
        local id, pos, name = l:match('^  MARKER%s+(%d+)%s+(%S+)%s+"(.-)"')
        if id then
            local code = name:match("^(%d+M%d+) MASTER REF$")
            if code then
                local r = { code = code, id = id, start = tonumber(pos) }
                byid[id] = r
                regions[#regions + 1] = r
            elseif name == "" and byid[id] and not byid[id].stop then
                byid[id].stop = tonumber(pos)
            end
        end
    end
    return regions
end

local function item_info(it)
    local info = { text = table.concat(it.lines, "\n") }
    local f = info.text:match('FILE "([^"]*)"')
    info.file = f
    info.pos = tonumber(info.text:match("\n%s+POSITION%s+(%S+)")) or 0
    info.len = tonumber(info.text:match("\n%s+LENGTH%s+(%S+)")) or 0
    info.tag = info.text:match("JK_MIXNOTE%s+(%S+)")
    info.has_notes = info.text:find("\n%s+<NOTES") ~= nil
    return info
end

local function region_at(regions, pos)
    for _, r in ipairs(regions) do
        if r.stop and pos >= r.start - 0.001 and pos <= r.stop + 0.001 then return r end
    end
end

-- which cue an item belongs to: a code, or nil = every session
local function item_cue(info, regions)
    if info.file then return cue_of_file(info.file) end
    if info.has_notes then
        -- where the note sits wins: the JK_MIXNOTE tag only says which cue session it was imported from,
        -- and it travels with the item when a note is copied elsewhere
        local r = region_at(regions, info.pos)
        if r then return r.code end
        return info.tag -- outside every cue region: fall back to the tag
    end
    return info.tag
end

local function cue_names(doc, regions)
    local names = {}
    for _, tr in ipairs(doc.tracks) do
        for _, it in ipairs(tr.items) do
            local f = table.concat(it.lines, "\n"):match('FILE "([^"]*)"')
            local base = f and f:match("([^/\\]*)$")
            local code, nm = (base or ""):match("^_(%d+M%d+) %- (.-) %- v%d")
            if code and not names[code] then names[code] = nm end
        end
    end
    return names
end

-- Build one cue's file text. Returns text, stats.
function M.build_cue(doc, regions, code)
    local out, stats = {}, { items = 0, dropped = 0, tracks_removed = 0, markers = 0 }
    local region
    for _, r in ipairs(regions) do if r.code == code then region = r end end

    -- header: markers filtered, cursor / selection on the cue
    for _, l in ipairs(doc.pre) do
        local id, pos, name = l:match('^  MARKER%s+(%d+)%s+(%S+)%s+"(.-)"')
        local keep = true
        if id then
            local mine
            for _, r in ipairs(regions) do if r.id == id then mine = r end end
            if mine then keep = (mine.code == code)
            else
                local at = region_at(regions, tonumber(pos))
                keep = (at == nil) or (at.code == code)
            end
            if keep then stats.markers = stats.markers + 1 end
        elseif region and l:match("^  CURSOR%s") then
            l = string.format("  CURSOR %.14g", region.start)
        elseif region and l:match("^  SELECTION%s") then
            l = string.format("  SELECTION %.14g %.14g", region.start, region.stop or region.start)
        end
        if keep then out[#out + 1] = l end
    end

    -- tracks: filter items, then prune
    local kept = {}
    for ti, tr in ipairs(doc.tracks) do
        local k = { tr = tr, items = {} }
        for _, it in ipairs(tr.items) do
            local c = item_cue(item_info(it), regions)
            if c == nil or c == code then k.items[#k.items + 1] = it else stats.dropped = stats.dropped + 1 end
        end
        k.remove = tr.nitems > 0 and #k.items == 0
        kept[ti] = k
    end

    -- folders (any nesting): build the tree from ISBUS depth changes, prune bottom-up, then give every
    -- kept track a new depth change. A track with ISBUS "a b" opens a folder when b > 0 and closes -b
    -- levels when b < 0.
    local N = #doc.tracks
    local parent, stack = {}, {}
    for ti, tr in ipairs(doc.tracks) do
        parent[ti] = stack[#stack]
        local b = tr.isbus_b or 0
        if b > 0 then for _ = 1, b do stack[#stack + 1] = ti end
        elseif b < 0 then for _ = 1, -b do stack[#stack] = nil end end
    end
    local nkids = {} -- kept children per track, bottom-up
    for ti = N, 1, -1 do
        local k = kept[ti]
        local isfolder = (doc.tracks[ti].isbus_b or 0) > 0
        if isfolder and not k.remove and (nkids[ti] or 0) == 0 and #k.items == 0 and doc.tracks[ti].nitems == 0 then
            k.remove = true -- a folder whose children were all removed
        elseif isfolder and not k.remove and (nkids[ti] or 0) == 0 and (nkids[ti] or 0) == 0 and k.hadkids then
            -- parent with items of its own stays, as a plain track
        end
        if not k.remove and parent[ti] then nkids[parent[ti]] = (nkids[parent[ti]] or 0) + 1 end
        if parent[ti] then kept[parent[ti]].hadkids = true end
    end
    local isbus, level = {}, {}
    for ti = 1, N do
        local p, d = parent[ti], 0
        while p do if not kept[p].remove then d = d + 1 end p = parent[p] end
        level[ti] = d
    end
    local prev
    local seq = {}
    for ti = 1, N do if not kept[ti].remove then seq[#seq + 1] = ti end end
    for i, ti in ipairs(seq) do
        local nextlevel = seq[i + 1] and level[seq[i + 1]] or 0
        local b = nextlevel - level[ti]
        isbus[ti] = string.format("%d %d", b > 0 and 1 or (b < 0 and 2 or 0), b)
    end

    for ti, k in ipairs(kept) do
        if k.remove then
            stats.tracks_removed = stats.tracks_removed + 1
        else
            -- plain tracks may have no ISBUS line at all (REAPER omits "0 0" in some files): insert one
            -- (after MAINSEND_NCH, else NCHAN, else the NAME line) when the track needs a folder value
            local entries = k.tr.entries
            local has = false
            for _, e in ipairs(entries) do if type(e) == "string" and e:match("^    ISBUS%s") then has = true end end
            local anchor
            if isbus[ti] and not has and isbus[ti] ~= "0 0" then
                for _, pat in ipairs({ "^    MAINSEND_NCH%s", "^    NCHAN%s", "^    NAME%s" }) do
                    for ei, e in ipairs(entries) do
                        if not anchor and type(e) == "string" and e:match(pat) then anchor = ei end
                    end
                    if anchor then break end
                end
            end
            local keepset = {}
            for _, it in ipairs(k.items) do keepset[it] = true end
            for ei, e in ipairs(entries) do
                if type(e) == "string" then
                    if isbus[ti] and e:match("^    ISBUS%s") then e = "    ISBUS " .. isbus[ti] end
                    out[#out + 1] = e
                    if anchor == ei then out[#out + 1] = "    ISBUS " .. isbus[ti] end
                elseif keepset[e] then
                    for _, l in ipairs(e.lines) do out[#out + 1] = l end
                    stats.items = stats.items + 1
                end
            end
        end
    end
    for _, l in ipairs(doc.post) do out[#out + 1] = l end
    return table.concat(out, doc.eol) .. doc.eol, stats
end

-- Split `path` into one RPP per cue next to it. opts.dry = report only. Returns report text.
function M.split(path, opts)
    local doc, err = M.parse(path)
    if not doc then return nil, err end
    local regions = find_regions(doc)
    if #regions == 0 then return nil, 'No "<cue> MASTER REF" regions found in the session.' end
    local names = cue_names(doc, regions)
    local dir, base = path:match("^(.*)[/\\]([^/\\]*)$")
    base = base:gsub("%.[Rr][Pp][Pp]$", "")
    local lines = { string.format("%d cues in %s", #regions, base), "" }
    for _, r in ipairs(regions) do
        local text, st = M.build_cue(doc, regions, r.code)
        local nm = names[r.code]
        local file = dir .. "/" .. base .. " - " .. r.code .. (nm and (" - " .. nm) or "") .. ".RPP"
        local note = ""
        if not (opts and opts.dry) then
            local f = io.open(file, "wb")
            if f then f:write(text) f:close() else note = "  (COULD NOT WRITE)" end
        end
        lines[#lines + 1] = string.format("%s: %d items, %d markers, %d tracks removed -> %s%s",
            r.code, st.items, st.markers, st.tracks_removed, file:match("([^/\\]*)$"), note)
    end
    return table.concat(lines, "\n")
end

function M.run()
    local cur = reaper.GetProjectPath and select(2, reaper.EnumProjects(-1, "")) or ""
    local ok, path = reaper.GetUserFileNameForRead(cur ~= "" and cur or "", "Mix session to split by cue", "RPP")
    if not ok then return end
    local report, err = M.split(path)
    reaper.ShowMessageBox(report or err, "Split mix session by cue", 0)
end

return M
