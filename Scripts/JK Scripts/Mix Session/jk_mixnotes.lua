-- Mix notes: collect the note-only items ("empty items" with item notes) from every
-- cue session's RPP and recreate them, conglomerated across cues, on four tracks of the
-- open mix session. Works on the .rpp text, so the cue sessions are never opened.
--
-- Position: a cue session's time 0 is the cue start; its PROJOFFS is that start in film
-- seconds (verified on HGG 1M07: PROJOFFS + item position = the TC written in the notes).
-- So an item lands at (cue PROJOFFS + position - mix session PROJOFFS), i.e. at film time.
local M = {}

M.TRACKS = { "Picture Markers", "Beat Markers", "Orch-Mix Markers", "Utility + To-Do" }
M.DEFAULT_ROOT = "/Users/jonathankawchuk/Documents/Projects/Film/Hunt for the Grey Ghost/HGG Reaper Projects"
local EXT_SECTION, TAG = "JK_MixNotes", "JK_MIXNOTE"

local wanted = {}
for _, n in ipairs(M.TRACKS) do wanted[n:lower()] = n end

local function unquote(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local q = s:sub(1, 1)
    if (q == '"' or q == "'" or q == "`") and s:sub(-1) == q and #s >= 2 then s = s:sub(2, -2) end
    return s
end

-- Parse one RPP. Returns { projoffs = seconds, tracks = {[name] = {color = n}}, items = {...} }
-- items: { track, pos, len, color, text } for items with no media source and some notes text.
function M.parse_rpp(path)
    local f = io.open(path, "r")
    if not f then return nil, "cannot open " .. path end
    local res = { projoffs = 0, tracks = {}, items = {} }
    local stack, trk, item = {}, nil, nil
    for line in f:lines() do
        local c = line:match("^%s*(%S)")
        if c == "<" then
            local tag = line:match("^%s*<([%w_]+)")
            local parent = stack[#stack]
            stack[#stack + 1] = tag
            if tag == "TRACK" and parent == "REAPER_PROJECT" then
                trk = { name = nil, color = nil }
            elseif tag == "ITEM" and parent == "TRACK" and trk then
                item = { pos = 0, len = 0, notes = {}, has_source = false, track = trk }
            elseif item then
                if tag == "SOURCE" and not line:match("^%s*<SOURCE%s+EMPTY") then item.has_source = true end
                if tag == "NOTES" and parent == "ITEM" then item.in_notes = true end
            end
        elseif c == ">" and line:match("^%s*>%s*$") then
            local tag = table.remove(stack)
            if tag == "ITEM" and item then
                if not item.has_source and item.track.name then
                    local text = table.concat(item.notes, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
                    local key = wanted[item.track.name:lower()]
                    if key and text ~= "" then
                        res.items[#res.items + 1] = { track = key, pos = item.pos, len = item.len, color = item.color, text = text }
                        res.tracks[key] = res.tracks[key] or { color = item.track.color }
                    end
                end
                item = nil
            elseif tag == "NOTES" and item then
                item.in_notes = false
            elseif tag == "TRACK" then
                trk = nil
            end
        elseif item then
            if item.in_notes then
                local t = line:match("^%s*|(.*)$")
                if t then item.notes[#item.notes + 1] = t end
            elseif stack[#stack] == "ITEM" then
                local k, v = line:match("^%s*(%u+)%s+(%S+)")
                if k == "POSITION" then item.pos = tonumber(v) or 0
                elseif k == "LENGTH" then item.len = tonumber(v) or 0
                elseif k == "COLOR" then item.color = tonumber(v) end
            end
        elseif trk then
            if stack[#stack] == "TRACK" then
                if not trk.name then
                    local v = line:match("^%s*NAME%s+(.*)$")
                    if v then trk.name = unquote(v) end
                end
                local pc = line:match("^%s*PEAKCOL%s+(%d+)")
                if pc then trk.color = tonumber(pc) end
            end
        elseif #stack == 1 then
            local v = line:match("^%s*PROJOFFS%s+(%S+)")
            if v then res.projoffs = tonumber(v) or 0 end
        end
    end
    f:close()
    return res
end

local function version_key(name)
    local a, b, c = name:match("[vV](%d+)%.(%d+)%.(%d+)")
    if not a then return 0 end
    return tonumber(a) * 1e8 + tonumber(b) * 1e4 + tonumber(c)
end

-- Newest-versioned RPP in one cue folder (file names start with the cue code)
function M.newest_rpp(dir, code)
    local best, bestkey
    local j = 0
    while true do
        local file = reaper.EnumerateFiles(dir, j)
        if not file then break end
        j = j + 1
        if file:match("%.[Rr][Pp][Pp]$") and file:sub(1, #code) == code then
            local k = version_key(file)
            if not best or k > bestkey or (k == bestkey and file > best) then best, bestkey = file, k end
        end
    end
    return best
end

-- Newest-versioned RPP in each cue folder (<root>/<cue>/...). Returns { {code, path, name}, ... }
function M.find_cues(root)
    local cues = {}
    local i = 0
    while true do
        local dir = reaper.EnumerateSubdirectories(root, i)
        if not dir then break end
        i = i + 1
        local code = dir:match("^(%d+M%d+)")
        if code then
            local best = M.newest_rpp(root .. "/" .. dir, code)
            if best then cues[#cues + 1] = { code = code, dir = dir, file = best, path = root .. "/" .. dir .. "/" .. best } end
        end
    end
    table.sort(cues, function(a, b) return a.code < b.code end)
    return cues
end

local function find_track(name)
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, n = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if n:lower() == name:lower() then return tr end
    end
end

local function clear_previous(tr)
    local removed = 0
    for i = reaper.CountTrackMediaItems(tr) - 1, 0, -1 do
        local it = reaper.GetTrackMediaItem(tr, i)
        local _, tag = reaper.GetSetMediaItemInfo_String(it, "P_EXT:" .. TAG, "", false)
        if tag ~= "" then reaper.DeleteTrackMediaItem(tr, it) removed = removed + 1 end
    end
    return removed
end

-- film seconds of a note in a cue session, as a position in the mix session
local function cue_pos_to_mix(cue_projoffs, item_pos, mix_offs)
    return cue_projoffs + item_pos - mix_offs
end

-- Parse the given cues and (re)create their note items in the open project.
-- cues: from find_cues. opts.tracks = set of note track names to import (default all four).
-- Returns report string, per-track counts, total.
function M.import(cues, opts)
    local use = opts and opts.tracks
    local mix_offs = reaper.GetProjectTimeOffset(0, false)
    local by_track, report, problems, total = {}, {}, {}, 0
    local colors, first = {}, nil
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local mix_tracks = {}
    for _, name in ipairs(M.TRACKS) do
        if not use or use[name] then mix_tracks[name] = find_track(name) end
    end
    for _, tr in pairs(mix_tracks) do clear_previous(tr) end

    for _, cue in ipairs(cues) do
        local res, err = M.parse_rpp(cue.path)
        if not res then
            problems[#problems + 1] = cue.code .. ": " .. err
        else
            local seen, n = {}, 0
            for _, it in ipairs(res.items) do
                local key = it.track .. "|" .. string.format("%.3f", it.pos) .. "|" .. it.text
                if not seen[key] and (not use or use[it.track]) then
                    seen[key] = true
                    if not mix_tracks[it.track] then
                        reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
                        local tr = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
                        reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", it.track, true)
                        local col = res.tracks[it.track] and res.tracks[it.track].color
                        if col then reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", col) end
                        mix_tracks[it.track] = tr
                    end
                    local pos = cue_pos_to_mix(res.projoffs, it.pos, mix_offs)
                    if pos < 0 then
                        problems[#problems + 1] = cue.code .. ": note before project start, skipped: " .. it.text:sub(1, 40)
                    else
                        local item = reaper.AddMediaItemToTrack(mix_tracks[it.track])
                        reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
                        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", it.len > 0.01 and it.len or 0.2)
                        if it.color then reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", it.color) end
                        reaper.GetSetMediaItemInfo_String(item, "P_NOTES", cue.code .. ": " .. it.text, true)
                        reaper.GetSetMediaItemInfo_String(item, "P_EXT:" .. TAG, cue.code, true)
                        if not first or pos < first then first = pos end
                        by_track[it.track] = (by_track[it.track] or 0) + 1
                        n, total = n + 1, total + 1
                    end
                end
            end
            report[#report + 1] = string.format("%s  %s  (%d notes found in the file, %d placed)", cue.code, cue.file, #res.items, n)
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Import mix notes from cue sessions", -1)

    local lines = { string.format("%d notes from %d cues.", total, #cues), "" }
    for _, name in ipairs(M.TRACKS) do lines[#lines + 1] = string.format("%-18s %d", name, by_track[name] or 0) end
    lines[#lines + 1] = ""
    for _, l in ipairs(report) do lines[#lines + 1] = l end
    if #problems > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Problems:"
        for _, p in ipairs(problems) do lines[#lines + 1] = "  " .. p end
    end
    return table.concat(lines, "\n"), by_track, total, first, problems
end

-- Entry point for the action script.
function M.run()
    local root = reaper.GetExtState(EXT_SECTION, "root")
    if root == "" then root = M.DEFAULT_ROOT end
    if reaper.EnumerateSubdirectories(root, 0) == nil then
        local ok, picked = reaper.JS_Dialog_BrowseForFolder("Folder holding the cue folders (1M01 - ..., 1M02 - ...)", root)
        if ok ~= 1 or not picked or picked == "" then return end
        root = picked
    end
    reaper.SetExtState(EXT_SECTION, "root", root, true)
    local cues = M.find_cues(root)
    if #cues == 0 then
        reaper.ShowMessageBox("No cue folders with an RPP found in:\n" .. root, "Mix notes", 0)
        return
    end
    reaper.ShowMessageBox(M.import(cues), "Mix notes imported", 0)
end

return M
