-- JK - Import Notes to Project from SpotNotes.lua
-- Imports spotting notes directly into the CURRENT project as empty, note-only media
-- items. No subprojects, no template, nothing written to disk. Two input modes:
--
--   1. SpotNotes CSV export (Cue ID, Title, Type, IN, IN Description, OUT,
--      OUT Description, Duration, Notes columns).
--   2. Pasted plain-text notes on the clipboard, formatted like:
--
--        PROJECT: Perfectly Human Sizzle
--        VERSION: PerfectlyHuman_Sizzle_RoughtCut_V03 [26-07-02]
--        START: 09:59:30:00
--        FPS: 23.976
--        DATE: 07/10/2026
--        <freeform project-level notes...>
--        --
--        ID: 1m01
--        IN: 09:59:35:09
--        OUT: 10:00:35:02
--        temp: ANW4698_004_Edges-Of-Earth.wav
--        10:00:17:21 need a mic drop moment here
--        --
--        ID: 1m02
--        IN: 10:00:33:05
--        OUT: 10:02:11:04
--        ...
--
--      Blocks are separated by a line containing only "--". The first block is the
--      header (PROJECT/VERSION/START/FPS/DATE fields, plus any other lines as
--      general project notes); every block after that is a cue (ID/IN/OUT fields,
--      plus any other lines as that cue's notes).
--
-- Inspired by Nate Weiner's "Batch Create Cues" script, which builds two kinds of
-- items inside generated cue subprojects: MX IN/OUT markers spanning each cue region,
-- and per-line spotting-note items parsed out of the Notes column. This script reuses
-- that same item shape and the same timecode-parsing logic, but drops the items
-- straight onto tracks in the project that's already open:
--
--   CuesA / CuesB    - one item per cue spanning IN -> OUT, noted with the cue ID,
--                     title/type, and IN/OUT descriptions. A cue that would overlap
--                     the previous one on "CuesA" falls through to "CuesB" -- the
--                     same primary/alt-track idea Nate's script uses for overlapping
--                     cues (this data's cues do overlap: e.g. 1m02 ends after 1m03
--                     starts).
--   Picture Markers - one short item per timecoded line found in each cue's notes
--                     (e.g. "10:02:12:05 lets bring in a percussive line"),
--                     positioned at that timecode. Lines that couldn't be resolved to
--                     a timecode are still placed (sequentially, after the cue's IN
--                     point) and flagged red so nothing is silently dropped.
--
-- Track names (CuesA / CuesB / Picture Markers) are matched exactly against any
-- existing track in the project first, so a template that already has these tracks
-- built (in whatever order/folder) gets reused instead of duplicated. Only creates
-- new tracks, appended at the end, if no exact name match is found.
--
-- All items are "empty" items (no take/source) with their text set as Item Notes
-- (P_NOTES) -- open Item Properties (F2), or hover, to read them. Same trick Nate's
-- script uses for MX IN/OUT and spotting-note items.
--
-- Run it, choose CSV file or paste-from-clipboard, done.

-- ============================================================================
-- CONFIG DEFAULTS
-- ============================================================================
local CUES_TRACK_A_NAME = "CuesA"
local CUES_TRACK_B_NAME = "CuesB"
local NOTES_TRACK_NAME  = "Picture Markers"

local DEFAULT_NOTE_ITEM_LENGTH_SECONDS = 2      -- prefilled default in the runtime prompt
local NOTE_ITEM_MIN_LENGTH             = 0.05   -- floor when shrinking to avoid overlap
local TIMECODE_BUFFER_SECONDS          = 10     -- seconds of slack for validating timecodes outside a cue's IN/OUT range
local REVIEW_ITEM_COLOR                = reaper.ColorToNative(255, 60, 60) | 0x1000000 -- red, flagged for review

local EXT_NS = "JK_SpottingNotesImport"

-- Set once per run by promptForRunOptions() in main()
local noteItemLength = DEFAULT_NOTE_ITEM_LENGTH_SECONDS
local includeCueIdInNotes = false

local SCRIPT_TITLE = "Import Notes to Project from SpotNotes"

-- ============================================================================
-- SHARED STRING HELPERS
-- ============================================================================

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function normalizeTimecode(tc)
    if not tc or tc == "" then return "" end
    return tc:gsub("%.", ":")
end

-- ============================================================================
-- TIMECODE CONVERSION
-- Always trust the CURRENT project's own timecode/fps and start-offset settings
-- (Project Settings) for actual placement math -- both in CSV mode and in paste
-- mode. A pasted header's FPS/START are used only as a sanity check (warn on
-- mismatch) EXCEPT when the project has no start offset configured yet (0), in
-- which case the pasted START is adopted as a convenience so cues don't all
-- land at some huge, meaningless project time.
-- ============================================================================

local activeOffsetSeconds = nil  -- set only when the project has no start offset configured yet; nil = use the project's real configured start offset

local function currentFps()
    return reaper.TimeMap_curFrameRate(0)
end

---Converts "HH:MM:SS:FF" to seconds, using the project's real timecode settings.
local function tcToSeconds(tc)
    return reaper.parse_timestr_len(tc, 0, 5)
end

---Converts seconds to "HH:MM:SS:FF", using the project's real timecode settings.
local function secondsToTc(sec)
    return reaper.format_timestr_len(sec, "", 0, 5)
end

local function timecodeStringToProjectTime(timecodeStr)
    local offsetSeconds = activeOffsetSeconds or reaper.GetProjectTimeOffset(0, false)
    return tcToSeconds(timecodeStr) - offsetSeconds
end

-- ============================================================================
-- CSV PARSING (ported from Nate Weiner's CSVParser.lua)
-- ============================================================================

local function parseCSVLine(line)
    local fields = {}
    local inQuotes = false
    local currentField = ""
    local i = 1
    while i <= #line do
        local char = line:sub(i, i)
        if char == '"' then
            if inQuotes and line:sub(i + 1, i + 1) == '"' then
                currentField = currentField .. '"'
                i = i + 1
            else
                inQuotes = not inQuotes
            end
        elseif char == ',' and not inQuotes then
            table.insert(fields, currentField)
            currentField = ""
        else
            currentField = currentField .. char
        end
        i = i + 1
    end
    table.insert(fields, currentField)
    return fields
end

local function readCSVFile(csvPath)
    local file = io.open(csvPath, "r")
    if not file then return {}, {} end
    local content = file:read("*all")
    file:close()

    local rows, headers = {}, {}
    local currentLine = ""
    local inQuotes = false
    local isFirstRow = true

    local i = 1
    while i <= #content do
        local char = content:sub(i, i)
        if char == '"' then
            currentLine = currentLine .. char
            if content:sub(i + 1, i + 1) == '"' then
                currentLine = currentLine .. '"'
                i = i + 1
            else
                inQuotes = not inQuotes
            end
        elseif char == '\n' and not inQuotes then
            currentLine = currentLine:gsub("\r$", "")
            if currentLine ~= "" then
                local fields = parseCSVLine(currentLine)
                if isFirstRow then
                    headers = fields
                    isFirstRow = false
                else
                    table.insert(rows, fields)
                end
            end
            currentLine = ""
        elseif char == '\r' then
            -- skip, handled at the following \n
        else
            currentLine = currentLine .. char
        end
        i = i + 1
    end
    if currentLine ~= "" then
        currentLine = currentLine:gsub("\r$", "")
        local fields = parseCSVLine(currentLine)
        if isFirstRow then headers = fields else table.insert(rows, fields) end
    end
    return rows, headers
end

local function findHeaderIndex(headers, name)
    local lowerName = name:lower()
    for i, header in ipairs(headers) do
        if trim(header):lower() == lowerName then return i end
    end
    return nil
end

---Parses a SpotNotes-style CSV into an ordered array of cue rows (file order preserved).
---Supports two CSV column layouts:
---  - Classic: Cue ID, Title, Type, IN, IN Description, OUT, OUT Description, Duration, Notes
---  - Cue sheet: Cue ID, Group, Title, Status, Omit, Music In, Music Out, Spotting In, Spotting Out, Dur, ...
---@param csvPath string
---@return table[]? cues
---@return string? err
local function parseSpotNotesCSV(csvPath)
    local rows, headers = readCSVFile(csvPath)
    if #headers == 0 then
        return nil, "Could not read CSV file or file is empty: " .. csvPath
    end

    local idx = {
        cueId    = findHeaderIndex(headers, "Cue ID"),
        title    = findHeaderIndex(headers, "Title"),
        cueType  = findHeaderIndex(headers, "Type"),
        inTC     = findHeaderIndex(headers, "IN") or findHeaderIndex(headers, "Music In"),
        inDesc   = findHeaderIndex(headers, "IN Description"),
        outTC    = findHeaderIndex(headers, "OUT") or findHeaderIndex(headers, "Music Out"),
        outDesc  = findHeaderIndex(headers, "OUT Description"),
        duration = findHeaderIndex(headers, "Duration") or findHeaderIndex(headers, "Dur"),
        notes    = findHeaderIndex(headers, "Notes"),
        omit     = findHeaderIndex(headers, "Omit"),
    }
    if not idx.cueId then return nil, "CSV missing required 'Cue ID' column" end
    if not idx.inTC then return nil, "CSV missing required 'IN' or 'Music In' column" end
    if not idx.outTC then return nil, "CSV missing required 'OUT' or 'Music Out' column" end

    local cues = {}
    for _, row in ipairs(rows) do
        local cueId = trim(row[idx.cueId])
        if cueId ~= "" then
            if idx.omit and trim(row[idx.omit]):lower() == "true" then
                goto continueRow
            end
            table.insert(cues, {
                cueId       = cueId,
                title       = idx.title and trim(row[idx.title]) or "",
                cueType     = idx.cueType and trim(row[idx.cueType]) or "",
                inTimecode  = normalizeTimecode(trim(row[idx.inTC])),
                inDesc      = idx.inDesc and trim(row[idx.inDesc]) or "",
                outTimecode = normalizeTimecode(trim(row[idx.outTC])),
                outDesc     = idx.outDesc and trim(row[idx.outDesc]) or "",
                duration    = idx.duration and trim(row[idx.duration]) or "",
                notes       = idx.notes and trim(row[idx.notes]) or "",
            })
            ::continueRow::
        end
    end
    return cues, nil
end

-- ============================================================================
-- PASTED-TEXT PARSING
-- Splits pasted text on "--" separator lines into a header block plus one block
-- per cue, then pulls known "KEY: value" fields out of each block (leaving
-- everything else as notes text).
-- ============================================================================

local function splitOnDashSeparator(text)
    local blocks = {}
    local current = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if trim(line) == "--" then
            table.insert(blocks, table.concat(current, "\n"))
            current = {}
        else
            table.insert(current, line)
        end
    end
    table.insert(blocks, table.concat(current, "\n"))
    return blocks
end

---Pulls whitelisted "KEY: value" lines out of a block of text.
---@param blockText string
---@param allowedKeys table<string, boolean> uppercase key names to recognize
---@return table<string, string> fields uppercase key -> trimmed value
---@return string remainingText every other non-blank line, in order
local function extractFields(blockText, allowedKeys)
    local fields = {}
    local remaining = {}
    for line in (blockText .. "\n"):gmatch("(.-)\n") do
        if trim(line) ~= "" then
            local key, val = line:match("^%s*(%a+)%s*:%s*(.-)%s*$")
            local keyUpper = key and key:upper()
            if keyUpper and allowedKeys[keyUpper] then
                fields[keyUpper] = trim(val)
            else
                table.insert(remaining, line)
            end
        end
    end
    return fields, table.concat(remaining, "\n")
end

---Parses pasted spotting notes text (see file header for the expected format).
---@param text string
---@return table? parsed { header = {...}, cues = {...} }
---@return string? err
local function parsePastedNotesText(text)
    local blocks = splitOnDashSeparator(text)
    if #blocks < 2 then
        return nil, "Couldn't find any '--'-separated cue blocks in the pasted text."
    end

    local headerFields, generalNotes = extractFields(blocks[1],
        { PROJECT = true, VERSION = true, START = true, FPS = true, DATE = true })
    local header = {
        project      = headerFields.PROJECT,
        version      = headerFields.VERSION,
        start        = (headerFields.START and headerFields.START ~= "") and normalizeTimecode(headerFields.START) or nil,
        fps          = tonumber(headerFields.FPS),
        date         = headerFields.DATE,
        generalNotes = generalNotes,
    }

    local cues = {}
    for i = 2, #blocks do
        local cueFields, notesText = extractFields(blocks[i], { ID = true, IN = true, OUT = true })
        local cueId = trim(cueFields.ID or "")
        if cueId ~= "" then
            table.insert(cues, {
                cueId       = cueId,
                title       = "",
                cueType     = "",
                inTimecode  = normalizeTimecode(trim(cueFields.IN or "")),
                inDesc      = "",
                outTimecode = normalizeTimecode(trim(cueFields.OUT or "")),
                outDesc     = "",
                duration    = "",
                notes       = notesText,
            })
        end
    end

    return { header = header, cues = cues }, nil
end

-- ============================================================================
-- SPOTTING NOTES TEXT PARSER (ported from Nate Weiner's SpottingNotesParser.lua)
-- Finds embedded timecodes inside a cue's multi-line notes text and turns each
-- line into a {timecodeString, noteText, needsReview} marker.
-- ============================================================================

local function normalizeTimecodeFormat(looseTimecodeStr)
    local cleaned = looseTimecodeStr:gsub("%s+", "")
    cleaned = cleaned:gsub("ish$", "")
    cleaned = cleaned:gsub("^around", "")
    cleaned = cleaned:gsub("^~", "")
    cleaned = cleaned:gsub("~$", "")
    cleaned = cleaned:gsub("%-$", "")

    local hasMissingPrefix = cleaned:match("^[%.:]") ~= nil
    local hasMissingSuffix = cleaned:match("[%.:]$") ~= nil

    cleaned = cleaned:gsub("%.%.+", ".")
    cleaned = cleaned:gsub("%.", ":")
    cleaned = cleaned:gsub("::+", ":")
    cleaned = cleaned:gsub("^:", "")
    cleaned = cleaned:gsub(":$", "")

    local components = {}
    if cleaned:match(":") then
        for part in cleaned:gmatch("([^:]+)") do
            local num = tonumber(part)
            if not num then return nil end
            table.insert(components, num)
        end
    else
        local len = #cleaned
        if len == 8 then
            table.insert(components, tonumber(cleaned:sub(1, 2)))
            table.insert(components, tonumber(cleaned:sub(3, 4)))
            table.insert(components, tonumber(cleaned:sub(5, 6)))
            table.insert(components, tonumber(cleaned:sub(7, 8)))
        elseif len == 7 then
            table.insert(components, tonumber("0" .. cleaned:sub(1, 1)))
            table.insert(components, tonumber(cleaned:sub(2, 3)))
            table.insert(components, tonumber(cleaned:sub(4, 5)))
            table.insert(components, tonumber(cleaned:sub(6, 7)))
        elseif len == 6 then
            table.insert(components, tonumber(cleaned:sub(1, 2)))
            table.insert(components, tonumber(cleaned:sub(3, 4)))
            table.insert(components, tonumber(cleaned:sub(5, 6)))
        else
            return nil
        end
    end

    if #components < 2 or #components > 4 then return nil end
    return components, hasMissingPrefix, hasMissingSuffix
end

local function inferMissingTimecodeComponents(components, hasMissingPrefix, hasMissingSuffix,
        mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString, fps)
    local function tryTimecode(testH, testM, testS, testF)
        if not (testH >= 0 and testH < 100 and testM >= 0 and testM < 60 and
                testS >= 0 and testS < 60 and testF >= 0 and testF < fps) then
            return nil
        end
        local testTC = string.format("%02d:%02d:%02d:%02d", testH, testM, testS, testF)
        local tcSeconds = tcToSeconds(testTC)
        local mxInSeconds = tcToSeconds(mxInTimecodeString)
        local mxOutSeconds = tcToSeconds(mxOutTimecodeString)
        if tcSeconds >= (mxInSeconds - TIMECODE_BUFFER_SECONDS) and
           tcSeconds <= (mxOutSeconds + TIMECODE_BUFFER_SECONDS) then
            return testTC
        end
        return nil
    end

    local function inferHour()
        if lastValidTimecodeString then
            return tonumber(lastValidTimecodeString:match("^(%d+):"))
        else
            return tonumber(mxInTimecodeString:match("^(%d+):"))
        end
    end

    if #components == 4 then
        return tryTimecode(components[1], components[2], components[3], components[4])
    elseif #components == 3 then
        if components[1] <= 2 then
            local result = tryTimecode(components[1], components[2], components[3], 0)
            if result then return result end
        end
        local inferredH = inferHour()
        local result = tryTimecode(inferredH, components[1], components[2], components[3])
        if result then return result end
        result = tryTimecode(components[1], components[2], components[3], 0)
        if result then return result end
        return nil
    elseif #components == 2 then
        local inferredH = inferHour()
        local result = tryTimecode(inferredH, components[1], components[2], 0)
        if result then return result end
        result = tryTimecode(inferredH, 0, components[1], components[2])
        if result then return result end
        result = tryTimecode(components[1], components[2], 0, 0)
        if result then return result end
        return nil
    end
    return nil
end

local function normalizeLooseTimecodeString(looseTimecodeStr, mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString)
    local fps = currentFps()
    local components, hasMissingPrefix, hasMissingSuffix = normalizeTimecodeFormat(looseTimecodeStr)
    if not components then return nil end
    return inferMissingTimecodeComponents(components, hasMissingPrefix, hasMissingSuffix,
        mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString, fps)
end

local function findTimecodeStringsInLine(line)
    local matches = {}

    for startPos, tc, endPos in line:gmatch("()(%d%d?[:.:]%d%d[:.:]%d%d[:.:]%d%d)()") do
        table.insert(matches, { timecodeStr = tc, startPos = startPos, endPos = endPos })
    end

    for startPos, tc, endPos in line:gmatch("()(%d%d?[:.:]%d%d[:.:]%d%d[:.:]?)()") do
        local found = false
        for _, match in ipairs(matches) do
            if startPos >= match.startPos and startPos < match.endPos then found = true; break end
        end
        if not found then
            table.insert(matches, { timecodeStr = tc, startPos = startPos, endPos = endPos })
        end
    end

    for startPos, tc, endPos in line:gmatch("()(%d%d%d%d%d%d%d?%d?)()") do
        if #tc >= 6 and #tc <= 8 then
            local found = false
            for _, match in ipairs(matches) do
                if startPos >= match.startPos and startPos < match.endPos then found = true; break end
            end
            if not found then
                table.insert(matches, { timecodeStr = tc, startPos = startPos, endPos = endPos })
            end
        end
    end

    table.sort(matches, function(a, b) return a.startPos < b.startPos end)
    return matches
end

local function isStandaloneTimecode(line, timecodeMatches)
    if #timecodeMatches ~= 1 then return false end
    local withoutTC = line:gsub(timecodeMatches[1].timecodeStr, "")
    withoutTC = withoutTC:gsub("ish", "")
    withoutTC = withoutTC:gsub("around", "")
    withoutTC = withoutTC:gsub("~", "")
    withoutTC = withoutTC:gsub("%s+", "")
    withoutTC = withoutTC:gsub("[%.:]", "")
    withoutTC = withoutTC:gsub("%-", "")
    return withoutTC == ""
end

local function extractNoteTextFromLine(line, tcMatch)
    local beforeText = line:sub(1, tcMatch.startPos - 1):match("^%s*(.-)%s*$")
    local afterText = line:sub(tcMatch.endPos):match("^%s*(.-)%s*$")

    local beforeCleaned = beforeText:gsub("~", ""):gsub("%s+", ""):gsub("[%.:]", ""):gsub("%-$", "")
    local afterCleaned = afterText:gsub("~", ""):gsub("%s+", ""):gsub("^[%.:]", ""):gsub("^%-", "")

    local hasTextBefore = beforeCleaned ~= ""
    local hasTextAfter = afterCleaned ~= ""

    if hasTextBefore and hasTextAfter then
        return line, hasTextBefore, hasTextAfter
    elseif hasTextAfter then
        local text = afterText:gsub("^[%.:%- ]+", "")
        return text, hasTextBefore, hasTextAfter
    elseif hasTextBefore then
        local text = beforeText:gsub("[%.:%- ]+$", "")
        return text, hasTextBefore, hasTextAfter
    else
        return tcMatch.timecodeStr, hasTextBefore, hasTextAfter
    end
end

local function calculateNextSequentialTimecodeString(lastTimecodeString, mxInTimecodeString, markerItemLength)
    if not lastTimecodeString then return mxInTimecodeString end
    local lastSeconds = tcToSeconds(lastTimecodeString)
    local nextSeconds = lastSeconds + markerItemLength
    return secondsToTc(nextSeconds)
end

local function createSequentialMarker(noteText, lastTimecodeString, mxInTimecodeString, markerItemLength, needsReview)
    local timecodeString = calculateNextSequentialTimecodeString(lastTimecodeString, mxInTimecodeString, markerItemLength)
    return {
        timecodeString = timecodeString,
        noteText = noteText,
        duration = markerItemLength,
        needsReview = needsReview,
    }
end

---Parses a cue's notes text into an array of {timecodeString, noteText, needsReview} markers.
---@param spottingNotesText string
---@param mxInTimecodeString string HH:MM:SS:FF
---@param mxOutTimecodeString string HH:MM:SS:FF
---@param markerItemLength number seconds, used for sequential fallback spacing
---@return table[] markers
local function parseSpottingNotes(spottingNotesText, mxInTimecodeString, mxOutTimecodeString, markerItemLength)
    local markers = {}
    local lastValidTimecodeString = mxInTimecodeString
    local pendingTimecodeString = nil
    local pendingTimecodeLine = nil
    local useNextLineForPendingTimecode = false

    local lines = {}
    for line in spottingNotesText:gmatch("([^\r\n]*)[\r\n]?") do
        if line ~= "" then table.insert(lines, line) end
    end

    for _, line in ipairs(lines) do
        if line:match("^%s*$") then goto continue end

        if useNextLineForPendingTimecode and pendingTimecodeString then
            local combinedText = pendingTimecodeLine and (pendingTimecodeLine .. "\n" .. line) or line
            table.insert(markers, {
                timecodeString = pendingTimecodeString,
                noteText = combinedText,
                duration = markerItemLength,
                needsReview = false,
            })
            lastValidTimecodeString = pendingTimecodeString
            useNextLineForPendingTimecode = false
            pendingTimecodeString = nil
            pendingTimecodeLine = nil
            goto continue
        end

        local timecodeMatches = findTimecodeStringsInLine(line)

        if #timecodeMatches == 0 then
            local marker = createSequentialMarker(line, lastValidTimecodeString, mxInTimecodeString, markerItemLength, false)
            table.insert(markers, marker)
            lastValidTimecodeString = marker.timecodeString
            goto continue
        end

        if isStandaloneTimecode(line, timecodeMatches) then
            local normalizedTimecodeString = normalizeLooseTimecodeString(
                timecodeMatches[1].timecodeStr, mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString)
            if normalizedTimecodeString then
                pendingTimecodeString = normalizedTimecodeString
                pendingTimecodeLine = line
                useNextLineForPendingTimecode = true
            else
                local marker = createSequentialMarker(line, lastValidTimecodeString, mxInTimecodeString, markerItemLength, true)
                table.insert(markers, marker)
                lastValidTimecodeString = marker.timecodeString
            end
            goto continue
        end

        local firstMatch = timecodeMatches[1]
        local normalizedTimecodeString = normalizeLooseTimecodeString(
            firstMatch.timecodeStr, mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString)

        if not normalizedTimecodeString then
            local marker = createSequentialMarker(line, lastValidTimecodeString, mxInTimecodeString, markerItemLength, true)
            table.insert(markers, marker)
            lastValidTimecodeString = marker.timecodeString
            goto continue
        end

        local noteText, hasTextBefore, hasTextAfter
        if #timecodeMatches == 1 then
            noteText, hasTextBefore, hasTextAfter = extractNoteTextFromLine(line, firstMatch)
            table.insert(markers, {
                timecodeString = normalizedTimecodeString,
                noteText = noteText,
                duration = markerItemLength,
                needsReview = not (hasTextBefore or hasTextAfter),
            })
        else
            local beforeText = line:sub(1, firstMatch.startPos - 1):match("^%s*(.-)%s*$")
            local beforeCleaned = beforeText:gsub("~", ""):gsub("%s+", ""):gsub("[%.:]", ""):gsub("%-$", "")
            local timecodeAtStart = beforeCleaned == ""
            if timecodeAtStart then
                noteText = select(1, extractNoteTextFromLine(line, firstMatch))
            else
                noteText = line
            end
            table.insert(markers, {
                timecodeString = normalizedTimecodeString,
                noteText = noteText,
                duration = markerItemLength,
                needsReview = false,
            })
        end

        lastValidTimecodeString = normalizedTimecodeString
        ::continue::
    end

    if useNextLineForPendingTimecode and pendingTimecodeString then
        table.insert(markers, {
            timecodeString = pendingTimecodeString,
            noteText = pendingTimecodeLine or pendingTimecodeString,
            duration = markerItemLength,
            needsReview = true,
        })
    end

    return markers
end

-- ============================================================================
-- REAPER TRACK / ITEM HELPERS
-- ============================================================================

local function findTrackByName(name)
    local trackCount = reaper.CountTracks(0)
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if trackName == name then return track end
    end
    return nil
end

local function getOrCreateTrack(name)
    local track = findTrackByName(name)
    if track then return track end
    local idx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(idx, true)
    track = reaper.GetTrack(0, idx)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
    return track
end

local function wouldOverlapOnTrack(track, startTime, endTime)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if startTime < itemEnd and endTime > itemStart then return true end
    end
    return false
end

---Creates an empty (take-less) item with its text set as Item Notes.
local function createEmptyNoteItem(track, position, length, noteText, customColor)
    local item = reaper.AddMediaItemToTrack(track)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", math.max(length, 0.01))
    reaper.GetSetMediaItemInfo_String(item, "P_NOTES", noteText, true)
    if customColor then
        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", customColor)
    end
    return item
end

-- ============================================================================
-- IMPORT (shared by both CSV and paste modes)
-- ============================================================================

local function buildCueNoteText(cue)
    local lines = { cue.cueId .. (cue.title ~= "" and (" - " .. cue.title) or "") }
    if cue.cueType ~= "" then table.insert(lines, "Type: " .. cue.cueType) end
    if cue.inDesc ~= "" then table.insert(lines, "IN: " .. cue.inDesc) end
    if cue.outDesc ~= "" then table.insert(lines, "OUT: " .. cue.outDesc) end
    if cue.duration ~= "" then table.insert(lines, "Duration: " .. cue.duration) end
    return table.concat(lines, "\n")
end

---Runs the full import: creates CuesA/CuesB items for each cue and Picture Markers items for
---every timecoded (or sequentially-placed) line found in their notes text.
---@param cues table[]
---@param extraNoteBlocks table[]? optional {label, notes, anchorTimecode} blocks (paste mode's project-level notes)
---@return number cuesOnA
---@return number cuesOnB
---@return number cuesSkipped
---@return number notesCreated
---@return number notesFlagged
local function runImport(cues, extraNoteBlocks)
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local cuesTrackA, cuesTrackB, notesTrack
    local cuesOnA, cuesOnB, cuesSkipped = 0, 0, 0
    local allNoteMarkers = {} -- { position, noteText, needsReview }

    for _, block in ipairs(extraNoteBlocks or {}) do
        if block.notes ~= "" and block.anchorTimecode then
            local markers = parseSpottingNotes(block.notes, block.anchorTimecode, block.anchorTimecode, noteItemLength)
            for _, marker in ipairs(markers) do
                local noteText = includeCueIdInNotes and string.format("[%s] %s", block.label, marker.noteText) or marker.noteText
                table.insert(allNoteMarkers, {
                    position = timecodeStringToProjectTime(marker.timecodeString),
                    noteText = noteText,
                    needsReview = marker.needsReview,
                })
            end
        end
    end

    for _, cue in ipairs(cues) do
        if cue.inTimecode == "" or cue.outTimecode == "" then
            reaper.ShowConsoleMsg(string.format("[Spotting Notes] Skipping %s: missing IN or OUT timecode\n", cue.cueId))
            cuesSkipped = cuesSkipped + 1
            goto continueCue
        end

        local startTime = timecodeStringToProjectTime(cue.inTimecode)
        local endTime = timecodeStringToProjectTime(cue.outTimecode)
        if not startTime or not endTime or endTime <= startTime then
            reaper.ShowConsoleMsg(string.format("[Spotting Notes] Skipping %s: invalid IN/OUT range\n", cue.cueId))
            cuesSkipped = cuesSkipped + 1
            goto continueCue
        end

        cuesTrackA = cuesTrackA or getOrCreateTrack(CUES_TRACK_A_NAME)
        local targetTrack = cuesTrackA
        local targetIsB = false
        if wouldOverlapOnTrack(cuesTrackA, startTime, endTime) then
            cuesTrackB = cuesTrackB or getOrCreateTrack(CUES_TRACK_B_NAME)
            targetTrack = cuesTrackB
            targetIsB = true
        end

        createEmptyNoteItem(targetTrack, startTime, endTime - startTime, buildCueNoteText(cue))
        if targetIsB then cuesOnB = cuesOnB + 1 else cuesOnA = cuesOnA + 1 end

        if cue.notes ~= "" then
            local markers = parseSpottingNotes(cue.notes, cue.inTimecode, cue.outTimecode, noteItemLength)
            for _, marker in ipairs(markers) do
                local noteText = includeCueIdInNotes and string.format("[%s] %s", cue.cueId, marker.noteText) or marker.noteText
                table.insert(allNoteMarkers, {
                    position = timecodeStringToProjectTime(marker.timecodeString),
                    noteText = noteText,
                    needsReview = marker.needsReview,
                })
            end
        end

        ::continueCue::
    end

    -- Sort note markers chronologically and shrink lengths to avoid overlap
    -- (mirrors the gap-based overlap prevention in Nate's CueCreator).
    table.sort(allNoteMarkers, function(a, b) return a.position < b.position end)
    local notesCreated, notesFlagged = 0, 0
    if #allNoteMarkers > 0 then
        notesTrack = getOrCreateTrack(NOTES_TRACK_NAME)
        for i, marker in ipairs(allNoteMarkers) do
            local length = noteItemLength
            if i < #allNoteMarkers then
                local gap = allNoteMarkers[i + 1].position - marker.position
                if gap < length then
                    length = math.max(gap - 0.01, NOTE_ITEM_MIN_LENGTH)
                end
            end
            local color = nil
            if marker.needsReview then
                color = REVIEW_ITEM_COLOR
                notesFlagged = notesFlagged + 1
            end
            createEmptyNoteItem(notesTrack, marker.position, length, marker.noteText, color)
            notesCreated = notesCreated + 1
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock(SCRIPT_TITLE, -1)

    return cuesOnA, cuesOnB, cuesSkipped, notesCreated, notesFlagged
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function importFromClipboard()
    if not reaper.CF_GetClipboard then
        reaper.ShowMessageBox(
            "Reading pasted notes from the clipboard requires the SWS Extension.\nGet it at: https://www.sws-extension.org",
            SCRIPT_TITLE, 0)
        return
    end

    local text = reaper.CF_GetClipboard()
    if not text or trim(text) == "" then
        reaper.ShowMessageBox("Clipboard is empty. Copy your spotting notes text, then run this again.", SCRIPT_TITLE, 0)
        return
    end

    local parsed, err = parsePastedNotesText(text)
    if not parsed then
        reaper.ShowMessageBox(err or "Failed to parse pasted notes", SCRIPT_TITLE, 0)
        return
    end
    if #parsed.cues == 0 then
        reaper.ShowMessageBox(
            "No cue blocks found. Expected '--' separated blocks, each starting with 'ID: <cue id>'.",
            SCRIPT_TITLE, 0)
        return
    end

    activeOffsetSeconds = nil
    local realOffset = reaper.GetProjectTimeOffset(0, false)
    local realFps = currentFps()

    if parsed.header.fps and math.abs(parsed.header.fps - realFps) > 0.01 then
        reaper.ShowConsoleMsg(string.format(
            "[Spotting Notes] Note: pasted FPS (%.3f) differs from this project's frame rate (%.3f). Using the project's frame rate for placement.\n",
            parsed.header.fps, realFps))
    end

    if parsed.header.start then
        local headerStartSeconds = tcToSeconds(parsed.header.start)
        if math.abs(realOffset) < 0.5 then
            -- Project has no start offset configured yet -- adopt the pasted START so
            -- cues don't all land at some huge, meaningless project time.
            activeOffsetSeconds = headerStartSeconds
            reaper.ShowConsoleMsg(string.format(
                "[Spotting Notes] This project has no start offset configured -- using the pasted START (%s) as the offset for this import.\n",
                parsed.header.start))
        elseif math.abs(headerStartSeconds - realOffset) > 0.5 then
            reaper.ShowConsoleMsg(string.format(
                "[Spotting Notes] Note: pasted START (%s) differs from this project's configured start offset (%s). Using the project's configured offset.\n",
                parsed.header.start, secondsToTc(realOffset)))
        end
    end

    local extraNoteBlocks = {}
    if parsed.header.generalNotes ~= "" then
        table.insert(extraNoteBlocks, {
            label = "PROJECT",
            notes = parsed.header.generalNotes,
            -- Anchor at whatever offset this import actually used (not necessarily the
            -- literal pasted START -- the project's configured offset wins when set).
            anchorTimecode = secondsToTc(activeOffsetSeconds or realOffset),
        })
    end

    local cuesOnA, cuesOnB, cuesSkipped, notesCreated, notesFlagged = runImport(parsed.cues, extraNoteBlocks)

    reaper.ShowConsoleMsg(string.format(
        "[Spotting Notes] Pasted from clipboard%s. %d cue(s) on '%s', %d on '%s', %d skipped. %d note item(s) created (%d flagged for review).\n",
        parsed.header.project and (" (" .. parsed.header.project .. ")") or "",
        cuesOnA, CUES_TRACK_A_NAME, cuesOnB, CUES_TRACK_B_NAME, cuesSkipped, notesCreated, notesFlagged))
end

local function importFromCSVFile()
    local lastPath = reaper.GetExtState(EXT_NS, "last_csv_path")
    local initialPath = (lastPath ~= "" and lastPath) or ((os.getenv("HOME") or "") .. "/Downloads/")

    local ok, csvPath = reaper.GetUserFileNameForRead(initialPath, "Import Spotting Notes CSV", "csv")
    if not ok or not csvPath or csvPath == "" then return end
    reaper.SetExtState(EXT_NS, "last_csv_path", csvPath, true)

    local cues, err = parseSpotNotesCSV(csvPath)
    if not cues then
        reaper.ShowMessageBox(err or "Failed to parse CSV", SCRIPT_TITLE, 0)
        return
    end
    if #cues == 0 then
        reaper.ShowMessageBox("No cue rows found in CSV (need a non-empty 'Cue ID' column).", SCRIPT_TITLE, 0)
        return
    end

    activeOffsetSeconds = nil

    local cuesOnA, cuesOnB, cuesSkipped, notesCreated, notesFlagged = runImport(cues, nil)

    reaper.ShowConsoleMsg(string.format(
        "[Spotting Notes] %d cue(s) on '%s', %d on '%s', %d skipped. %d note item(s) created (%d flagged for review).\n",
        cuesOnA, CUES_TRACK_A_NAME, cuesOnB, CUES_TRACK_B_NAME, cuesSkipped, notesCreated, notesFlagged))
end

---Prompts once per run for: input source, note item duration, and whether to prefix
---each note with its cue ID (or "PROJECT" for header notes).
---@return boolean? useClipboard nil if the user cancelled
---@return number noteDuration
---@return boolean includeCueId
local function promptForRunOptions()
    local defaults = string.format("n,%g,n", DEFAULT_NOTE_ITEM_LENGTH_SECONDS)
    local ok, csv = reaper.GetUserInputs(SCRIPT_TITLE, 3,
        "Paste from clipboard instead of CSV? (y/n),Note item duration (sec),Prefix notes with cue ID? (y/n)",
        defaults)
    if not ok then return nil end

    local fields = {}
    for field in (csv .. ","):gmatch("(.-),") do
        table.insert(fields, field)
    end

    local useClipboard = trim(fields[1] or ""):lower():match("^[y1]") ~= nil
    local noteDuration = tonumber(fields[2])
    if not noteDuration or noteDuration <= 0 then noteDuration = DEFAULT_NOTE_ITEM_LENGTH_SECONDS end
    local includeCueId = trim(fields[3] or ""):lower():match("^[y1]") ~= nil

    return useClipboard, noteDuration, includeCueId
end

local function main()
    local useClipboard, noteDuration, includeCueId = promptForRunOptions()
    if useClipboard == nil then return end -- cancelled

    noteItemLength = noteDuration
    includeCueIdInNotes = includeCueId

    if useClipboard then
        importFromClipboard()
    else
        importFromCSVFile()
    end
end

main()
