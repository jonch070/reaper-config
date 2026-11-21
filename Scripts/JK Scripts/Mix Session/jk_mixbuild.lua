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
    return { folders = segs, track = track, tc = rest:match("(%d+%.%d+%.%d+%.%d+)%-?%d*$") }
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
    for _, file in ipairs(files(stemdir)) do
        local p = M.parse_stem(file, tag)
        if p then
            p.path, p.file = stemdir .. "/" .. file, file
            cue.stems[#cue.stems + 1] = p
        elseif file:match("%- FX RETURN%.[Ww][Aa][Vv]$") then
            cue.fxreturn = stemdir .. "/" .. file
        end
    end
    for _, file in ipairs(files(mt)) do
        if file:sub(1, 1) == "_" and file:match(" %- CLICK%.[Ww][Aa][Vv]$") then cue.click = mt .. "/" .. file end
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

---------------------------------------------------------------------------- tree

local function new_node() return { folders = {}, leaves = {}, fkeys = {}, lkeys = {} } end

-- Put one stem into `root`: walks/creates the folder chain, then a leaf. A second stem for the
-- same leaf in the same cue gets its own leaf ("name 2"). Returns the leaf.
local function add_stem(root, cue_code, stem, conflicts)
    local node = root
    for _, f in ipairs(stem.folders) do
        if not node.folders[f] then
            node.folders[f] = new_node()
            node.fkeys[#node.fkeys + 1] = f
            if node.leaves[f] then conflicts[#conflicts + 1] = f .. " is both a track and a folder" end
        end
        node = node.folders[f]
    end
    local name = M.clean_name(stem.track)
    local n = 1
    local key = name
    while node.leaves[key] and node.leaves[key].cues[cue_code] do
        n = n + 1
        key = name .. " " .. n
    end
    if not node.leaves[key] then
        node.leaves[key] = { name = key, items = {}, cues = {} }
        node.lkeys[#node.lkeys + 1] = key
        if node.folders[key] then conflicts[#conflicts + 1] = key .. " is both a track and a folder" end
    end
    local leaf = node.leaves[key]
    leaf.cues[cue_code] = true
    return leaf
end

-- Flatten to { {name, depth, folder = bool, items = {...}} ... }, alphabetical.
local function flatten(node, depth, out)
    local entries = {}
    for _, k in ipairs(node.fkeys) do entries[#entries + 1] = { name = k, folder = node.folders[k] } end
    for _, k in ipairs(node.lkeys) do entries[#entries + 1] = { name = k, leaf = node.leaves[k] } end
    table.sort(entries, function(a, b)
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        if (a.folder ~= nil) ~= (b.folder ~= nil) then return a.folder ~= nil end
        return a.name < b.name
    end)
    for _, e in ipairs(entries) do
        if e.folder then
            out[#out + 1] = { name = e.name, depth = depth, folder = true }
            flatten(e.folder, depth + 1, out)
        else
            out[#out + 1] = { name = e.name, depth = depth, items = e.leaf.items }
        end
    end
end

-- Packed variant of flatten: each folder's own stems go onto as few tracks as possible
-- (greedy, no overlaps), named after the folder ("Hang", "Hang 2", ...). A folder that holds
-- only stems is not a folder track at all, just its lane tracks.
local function lanes(leaf_nodes)
    local items = {}
    for _, leaf in ipairs(leaf_nodes) do
        for _, it in ipairs(leaf.items) do items[#items + 1] = it end
    end
    table.sort(items, function(a, b) if a.pos ~= b.pos then return a.pos < b.pos end return a.label < b.label end)
    local out, ends = {}, {}
    for _, it in ipairs(items) do
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

local function flatten_packed(node, name, depth, out)
    local leaves = {}
    for _, k in ipairs(node.lkeys) do leaves[#leaves + 1] = node.leaves[k] end
    local lane_list = lanes(leaves)
    local function emit_lanes(d)
        for i, items in ipairs(lane_list) do
            out[#out + 1] = { name = i == 1 and name or (name .. " " .. i), group = name, depth = d, items = items }
        end
    end
    if #node.fkeys == 0 then emit_lanes(depth) return end
    out[#out + 1] = { name = name, depth = depth, folder = true }
    emit_lanes(depth + 1)
    local keys = {}
    for _, k in ipairs(node.fkeys) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) if a:lower() ~= b:lower() then return a:lower() < b:lower() end return a < b end)
    for _, k in ipairs(keys) do flatten_packed(node.folders[k], k, depth + 1, out) end
end

local function flatten_root(node, depth, out, pack)
    if not pack then return flatten(node, depth, out) end
    -- stems with no folder at all go to "Unsorted"; each top-level folder is packed on its own
    local keys = {}
    for _, k in ipairs(node.fkeys) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) if a:lower() ~= b:lower() then return a:lower() < b:lower() end return a < b end)
    for _, k in ipairs(keys) do flatten_packed(node.folders[k], k, depth, out) end
    if #node.lkeys > 0 then
        local loose = new_node()
        loose.lkeys, loose.leaves = node.lkeys, node.leaves
        flatten_packed(loose, "Unsorted", depth, out)
    end
end

---------------------------------------------------------------------------- colours

local PALETTE = { {230, 80, 80}, {235, 140, 60}, {225, 190, 60}, {150, 200, 70}, {70, 180, 110}, {60, 190, 190},
    {70, 140, 230}, {110, 100, 230}, {170, 100, 220}, {220, 100, 180}, {170, 130, 90}, {120, 150, 170} }
local SPECIAL = { click = {140, 140, 140}, fx = {235, 235, 235}, cue = {70, 70, 70} }

local function native(rgb) return reaper.ColorToNative(rgb[1], rgb[2], rgb[3]) | 0x1000000 end

-- Colour tracks by major section. Auto: a top-level folder with 2+ sub-folders is a grouping
-- (Orchestra -> Strings, Woodwinds, ...) so each sub-folder is a section; any other top-level
-- folder or track is its own section. `override` forces one folder level for everything
-- (1 = top level, 2 = next, ...). Click / FX RETURN / per-cue folders get fixed neutral colours.
-- Returns the sorted section names.
function M.colour(out, base, override)
    local stack, children = {}, {}
    for _, e in ipairs(out) do
        if not e.special then
            local d = e.depth - base
            stack[d + 1] = e.group or e.name
            for k = #stack, d + 2, -1 do stack[k] = nil end
            e.path = { table.unpack(stack, 1, d + 1) }
            -- packed lanes holding a folder's own stems ("Orchestra" inside "Orchestra") belong to that folder
            if e.group and #e.path >= 2 and e.path[#e.path] == e.path[#e.path - 1] then table.remove(e.path) end
            if #e.path >= 2 then
                children[e.path[1]] = children[e.path[1]] or {}
                children[e.path[1]][e.path[2]] = true
            end
        end
    end
    local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
    local set, names = {}, {}
    for _, e in ipairs(out) do
        if not e.special then
            local depth = (override and override > 0) and override or ((count(children[e.path[1]]) >= 2) and 2 or 1)
            if #e.path >= depth then e.section = e.path[depth]
            elseif not e.folder then e.section = e.path[#e.path] end
            if e.section and not set[e.section] then set[e.section] = true names[#names + 1] = e.section end
        end
    end
    table.sort(names, function(a, b) if a:lower() ~= b:lower() then return a:lower() < b:lower() end return a < b end)
    local idx = {}
    for i, n in ipairs(names) do idx[n] = PALETTE[(i - 1) % #PALETTE + 1] end
    for _, e in ipairs(out) do
        local rgb = e.special and SPECIAL[e.special] or (e.section and idx[e.section])
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

-- Plan the track list. Returns out (flat track list), problems.
function M.plan(cues, layout, variant, pack)
    local out, problems, conflicts = {}, {}, {}
    local function add_item(leaf_items, cue, path, label, name_hint)
        local pos, bwf, len = item_pos(path, name_hint or path)
        if not pos then
            problems[#problems + 1] = cue.code .. ": no timestamp for " .. label .. ", skipped"
        else
            if not bwf then problems[#problems + 1] = cue.code .. ": no BWF time in " .. label .. ", used filename TC" end
            leaf_items[#leaf_items + 1] = { path = path, pos = pos, len = len or 0, label = label }
        end
    end

    if layout == 1 then
        local click = { name = "Click", depth = 0, items = {}, special = "click" }
        local root = new_node()
        local fx = { name = "FX RETURN", depth = 0, items = {}, special = "fx" }
        for _, cue in ipairs(cues) do
            if cue.click then add_item(click.items, cue, cue.click, cue.code .. " CLICK") end
            if cue.fxreturn and variant == "DRY" then add_item(fx.items, cue, cue.fxreturn, cue.code .. " FX RETURN") end
            for _, s in ipairs(cue.stems) do
                local leaf = add_stem(root, cue.code, s, conflicts)
                add_item(leaf.items, cue, s.path, s.file, s.tc or "")
            end
        end
        if #click.items > 0 then out[#out + 1] = click end
        flatten_root(root, 0, out, pack)
        if #fx.items > 0 then out[#out + 1] = fx end
    else
        for _, cue in ipairs(cues) do
            out[#out + 1] = { name = cue.name, depth = 0, folder = true, special = "cue" }
            if cue.click then
                local t = { name = "Click", depth = 1, items = {}, special = "click" }
                add_item(t.items, cue, cue.click, cue.code .. " CLICK")
                out[#out + 1] = t
            end
            local root = new_node()
            for _, s in ipairs(cue.stems) do
                local leaf = add_stem(root, cue.code, s, conflicts)
                add_item(leaf.items, cue, s.path, s.file, s.tc or "")
            end
            flatten_root(root, 1, out, pack)
            if cue.fxreturn and variant == "DRY" then
                local t = { name = "FX RETURN", depth = 1, items = {}, special = "fx" }
                add_item(t.items, cue, cue.fxreturn, cue.code .. " FX RETURN")
                out[#out + 1] = t
            end
        end
    end
    local seen = {}
    for _, c in ipairs(conflicts) do
        if not seen[c] then seen[c] = true problems[#problems + 1] = "name clash: " .. c end
    end
    return out, problems
end

-- Create the planned tracks and items in the open project. Returns tracks, items created.
function M.create(out)
    local offs = reaper.GetProjectTimeOffset(0, false)
    local base = reaper.CountTracks(0)
    local n_items = 0
    for i, e in ipairs(out) do
        reaper.InsertTrackAtIndex(base + i - 1, true)
        local tr = reaper.GetTrack(0, base + i - 1)
        reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", e.name, true)
        if e.color then reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", e.color) end
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
    return #out, n_items
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
    local out, plan_problems = M.plan(cues, opts.layout, opts.variant, opts.pack)
    for _, p in ipairs(plan_problems) do problems[#problems + 1] = p end
    local sections
    if opts.colour then sections = M.colour(out, opts.layout == 2 and 1 or 0, opts.section_depth) end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    local n_tracks, n_items = M.create(out)
    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Build " .. opts.variant:lower() .. " mix session", -1)

    local lines = { string.format("%d tracks, %d items from %d cues (%s, %s%s).", n_tracks, n_items, #cues, opts.variant,
        opts.layout == 1 and "by instrument" or "by cue", opts.pack and ", packed" or ""), "" }
    for _, c in ipairs(cues) do lines[#lines + 1] = c.name .. "  (" .. #c.stems .. " stems)" end
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
    reaper.ShowMessageBox(table.concat(lines, "\n"), "Mix session built", 0)
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
        layout = tonumber(flag("layout", "1")), pack = flag("pack", "0") == "1",
        colour = flag("colour", "1") == "1", sdepth = tonumber(flag("sdepth", "0")) or 0,
        rows = {}, extra = {},
    }
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
            _, st.pack = reaper.ImGui_Checkbox(ctx, "Pack each instrument folder onto as few tracks as possible (like nvk Organize Items)", st.pack)
            _, st.colour = reaper.ImGui_Checkbox(ctx, "Colour tracks by major section (for bus FX)", st.colour)
            if st.colour then
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, 90)
                _, st.sdepth = reaper.ImGui_InputInt(ctx, "section folder level (0 = auto)", st.sdepth)
                if st.sdepth < 0 then st.sdepth = 0 end
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
            if reaper.ImGui_Button(ctx, "Build") then
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
                result = { variant = st.variant, layout = st.layout, pack = st.pack, colour = st.colour, section_depth = st.sdepth, cues = cues }
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Close") then open = false end
        end
        reaper.ImGui_End(ctx)
        if result then
            reaper.SetExtState(EXT_SECTION, "root", st.root, true)
            reaper.SetExtState(EXT_SECTION, "variant", st.variant, true)
            reaper.SetExtState(EXT_SECTION, "layout", tostring(st.layout), true)
            reaper.SetExtState(EXT_SECTION, "pack", st.pack and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "colour", st.colour and "1" or "0", true)
            reaper.SetExtState(EXT_SECTION, "sdepth", tostring(st.sdepth), true)
            if reaper.ImGui_DestroyContext then pcall(reaper.ImGui_DestroyContext, ctx) end
            reaper.defer(function() M.build(result) end)
            return
        end
        if open then reaper.defer(loop) end
    end
    reaper.defer(loop)
end

return M
