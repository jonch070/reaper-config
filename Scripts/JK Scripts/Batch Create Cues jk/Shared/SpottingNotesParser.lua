-- @description Spotting Notes Parser
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.1
-- @about
--   Parses spotting notes text into timeline markers for REAPER.
--   Handles incomplete timecodes, sequential placement, and complex multi-timecode lines.
--   See: documents/Spotting Notes Parsing Spec.md

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

--- @class SpottingNoteMarker
--- @field timecodeString TimecodeString The SMPTE timecode position (HH:MM:SS:FF)
--- @field noteText string The note text for the marker
--- @field duration number Duration in seconds
--- @field needsReview boolean Whether this marker should be flagged for manual review

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local TIMECODE_BUFFER_SECONDS = 10  -- seconds (for validating timecodes outside MX range)
local MARKER_OVERLAP_SECONDS = 0  -- seconds (configurable if markers should overlap)

-- ============================================================================
-- TIMECODE NORMALIZATION HELPERS
-- ============================================================================

--- PHASE 1: Normalizes format to colon-separated components
--- Converts dots to colons, splits digit strings, tracks missing components
--- @param looseTimecodeStr LooseTimecodeString Raw timecode string
--- @return table|nil components Array of number components, or nil if invalid format
--- @return boolean|nil hasMissingPrefix True if timecode started with separator (e.g., ":23:45")
--- @return boolean|nil hasMissingSuffix True if timecode ended with separator (e.g., "01:23:")
local function normalizeTimecodeFormat(looseTimecodeStr)
    -- Clean up qualifiers and whitespace
    local cleaned = looseTimecodeStr:gsub("%s+", "")
    cleaned = cleaned:gsub("ish$", "")
    cleaned = cleaned:gsub("^around", "")
    cleaned = cleaned:gsub("^~", "")
    cleaned = cleaned:gsub("~$", "")
    cleaned = cleaned:gsub("%-$", "")  -- Remove trailing hyphen

    -- Check for missing components (leading/trailing separators)
    local hasMissingPrefix = cleaned:match("^[%.:]") ~= nil
    local hasMissingSuffix = cleaned:match("[%.:]$") ~= nil

    -- Normalize separators: dots to colons
    -- Fix double dots BEFORE converting to colons (e.g., "01.13..52.19" -> "01.13.52.19")
    cleaned = cleaned:gsub("%.%.+", ".")
    cleaned = cleaned:gsub("%.", ":")
    cleaned = cleaned:gsub("::+", ":")

    -- Remove leading/trailing colons NOW (after we've recorded them)
    cleaned = cleaned:gsub("^:", "")
    cleaned = cleaned:gsub(":$", "")

    local components = {}

    if cleaned:match(":") then
        -- Has separators - split into parts
        for part in cleaned:gmatch("([^:]+)") do
            local num = tonumber(part)
            if not num then return nil end  -- Invalid component
            table.insert(components, num)
        end
    else
        -- No separators - parse digit string
        local len = #cleaned

        if len == 8 then
            -- HHMMSSFF
            table.insert(components, tonumber(cleaned:sub(1, 2)))
            table.insert(components, tonumber(cleaned:sub(3, 4)))
            table.insert(components, tonumber(cleaned:sub(5, 6)))
            table.insert(components, tonumber(cleaned:sub(7, 8)))
        elseif len == 7 then
            -- 0HMMSSFF - add leading zero
            table.insert(components, tonumber("0" .. cleaned:sub(1, 1)))
            table.insert(components, tonumber(cleaned:sub(2, 3)))
            table.insert(components, tonumber(cleaned:sub(4, 5)))
            table.insert(components, tonumber(cleaned:sub(6, 7)))
        elseif len == 6 then
            -- Could be HHMMSS or MMSSFF - can't tell yet, treat as 3 components
            table.insert(components, tonumber(cleaned:sub(1, 2)))
            table.insert(components, tonumber(cleaned:sub(3, 4)))
            table.insert(components, tonumber(cleaned:sub(5, 6)))
        else
            return nil  -- Invalid length
        end
    end

    if #components < 2 or #components > 4 then
        return nil  -- Invalid number of components
    end

    return components, hasMissingPrefix, hasMissingSuffix
end

--- PHASE 2: Completes incomplete timecode by inferring missing components
--- @param components table Array of 2-4 number components
--- @param hasMissingPrefix boolean|nil Whether leading component is missing
--- @param hasMissingSuffix boolean|nil Whether trailing component is missing
--- @param mxInTimecodeString TimecodeString MX IN for range validation
--- @param mxOutTimecodeString TimecodeString MX OUT for range validation
--- @param lastValidTimecodeString TimecodeString|nil Last valid timecode for hour inference
--- @param fps number Project framerate
--- @return TimecodeString|nil normalizedTimecodeString Normalized SMPTE timecode or nil if invalid
local function inferMissingTimecodeComponents(components, hasMissingPrefix, hasMissingSuffix, mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString, fps)
    -- Helper to validate a timecode candidate against range
    local function tryTimecode(testH, testM, testS, testF)
        -- Validate component ranges
        if not (testH >= 0 and testH < 100 and
                testM >= 0 and testM < 60 and
                testS >= 0 and testS < 60 and
                testF >= 0 and testF < fps) then
            return nil
        end

        -- Build and validate against MX range
        local testTC = string.format("%02d:%02d:%02d:%02d", testH, testM, testS, testF)
        local tcSeconds = reaper.parse_timestr_len(testTC, 0, 5)
        local mxInSeconds = reaper.parse_timestr_len(mxInTimecodeString, 0, 5)
        local mxOutSeconds = reaper.parse_timestr_len(mxOutTimecodeString, 0, 5)

        if tcSeconds >= (mxInSeconds - TIMECODE_BUFFER_SECONDS) and
           tcSeconds <= (mxOutSeconds + TIMECODE_BUFFER_SECONDS) then
            return testTC
        end

        return nil
    end

    -- Helper to infer hour from context
    local function inferHour()
        if lastValidTimecodeString then
            return tonumber(lastValidTimecodeString:match("^(%d+):"))
        else
            return tonumber(mxInTimecodeString:match("^(%d+):"))
        end
    end

    if #components == 4 then
        -- Complete timecode - just validate
        return tryTimecode(components[1], components[2], components[3], components[4])

    elseif #components == 3 then
        -- Three components - one missing

        -- If first component is 01 or 02, likely HH:MM:SS (missing FF)
        if components[1] <= 2 then
            local result = tryTimecode(components[1], components[2], components[3], 0)
            if result then return result end
        end

        -- Try as MM:SS:FF (missing HH) - infer hour
        local inferredH = inferHour()
        local result = tryTimecode(inferredH, components[1], components[2], components[3])
        if result then return result end

        -- Fallback: Try HH:MM:SS with f=0 (even if first component > 2)
        result = tryTimecode(components[1], components[2], components[3], 0)
        if result then return result end

        return nil

    elseif #components == 2 then
        -- Two components - two missing
        local inferredH = inferHour()

        -- Try MM:SS (missing HH and FF)
        local result = tryTimecode(inferredH, components[1], components[2], 0)
        if result then return result end

        -- Try SS:FF (missing HH and MM)
        result = tryTimecode(inferredH, 0, components[1], components[2])
        if result then return result end

        -- Try HH:MM (missing SS and FF) - unlikely but possible
        result = tryTimecode(components[1], components[2], 0, 0)
        if result then return result end

        return nil
    end

    return nil
end

--- Converts a loose timecode string (with dots or missing components) to proper SMPTE format
--- @param looseTimecodeStr LooseTimecodeString Timecode with dots, missing frames, etc
--- @param mxInTimecodeString TimecodeString MX IN for range validation
--- @param mxOutTimecodeString TimecodeString MX OUT for range validation
--- @param lastValidTimecodeString TimecodeString|nil Last valid timecode for hour inference
--- @param proj ReaProject The project (for framerate)
--- @return TimecodeString|nil normalizedTimecodeString Normalized SMPTE timecode or nil if invalid
local function normalizeLooseTimecodeString(looseTimecodeStr, mxInTimecodeString, mxOutTimecodeString, lastValidTimecodeString, proj)
    -- Get project framerate
    local fps = reaper.TimeMap_curFrameRate(proj)

    -- Phase 1: Normalize format to colon-separated components
    local components, hasMissingPrefix, hasMissingSuffix = normalizeTimecodeFormat(looseTimecodeStr)
    if not components then
        return nil
    end

    -- Phase 2: Infer missing components and validate
    -- (inferMissingTimecodeComponents handles both complete and incomplete timecodes)
    return inferMissingTimecodeComponents(
        components,
        hasMissingPrefix,
        hasMissingSuffix,
        mxInTimecodeString,
        mxOutTimecodeString,
        lastValidTimecodeString,
        fps
    )
end

--- Finds all timecode-like patterns in a line of text
--- @param line string The line to search
--- @return table matches Array of {timecodeStr=string, startPos=number, endPos=number}
local function findTimecodeStringsInLine(line)
    local matches = {}

    -- Pattern 1: Full SMPTE with separators (HH:MM:SS:FF or HH.MM.SS.FF)
    for startPos, tc, endPos in line:gmatch("()(%d%d?[:.:]%d%d[:.:]%d%d[:.:]%d%d)()") do
        table.insert(matches, {timecodeStr = tc, startPos = startPos, endPos = endPos})
    end

    -- Pattern 2: Missing frames (HH:MM:SS or HH.MM.SS) - with optional trailing separator
    for startPos, tc, endPos in line:gmatch("()(%d%d?[:.:]%d%d[:.:]%d%d[:.:]?)()") do
        -- Check not already matched by Pattern 1
        local found = false
        for _, match in ipairs(matches) do
            if startPos >= match.startPos and startPos < match.endPos then
                found = true
                break
            end
        end
        if not found then
            table.insert(matches, {timecodeStr = tc, startPos = startPos, endPos = endPos})
        end
    end

    -- Pattern 3: No separators (6-8 digits)
    for startPos, tc, endPos in line:gmatch("()(%d%d%d%d%d%d%d?%d?)()") do
        if #tc >= 6 and #tc <= 8 then
            -- Check not already matched by Pattern 1 or 2
            local found = false
            for _, match in ipairs(matches) do
                if startPos >= match.startPos and startPos < match.endPos then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(matches, {timecodeStr = tc, startPos = startPos, endPos = endPos})
            end
        end
    end

    -- Sort matches by position in the line (earliest first)
    table.sort(matches, function(a, b) return a.startPos < b.startPos end)

    return matches
end

-- ============================================================================
-- TEXT POSITION ANALYSIS
-- ============================================================================

--- Checks if a line contains only a timecode (and optional qualifiers like "ish")
--- @param line string The line to check
--- @param timecodeMatches table Array of timecode matches
--- @return boolean isStandalone True if line contains only timecode + qualifiers
local function isStandaloneTimecode(line, timecodeMatches)
    if #timecodeMatches ~= 1 then
        return false
    end

    -- Remove the timecode and qualifiers
    local withoutTC = line:gsub(timecodeMatches[1].timecodeStr, "")
    withoutTC = withoutTC:gsub("ish", "")
    withoutTC = withoutTC:gsub("around", "")
    withoutTC = withoutTC:gsub("~", "")
    withoutTC = withoutTC:gsub("%s+", "")
    withoutTC = withoutTC:gsub("[%.:]", "")
    withoutTC = withoutTC:gsub("%-", "")

    return withoutTC == ""
end

--- Extracts note text based on timecode position in line
--- @param line string The full line
--- @param tcMatch table Timecode match with startPos and endPos
--- @return string noteText The extracted note text
--- @return boolean hasTextBefore Whether there's text before the timecode
--- @return boolean hasTextAfter Whether there's text after the timecode
local function extractNoteTextFromLine(line, tcMatch)
    local beforeText = line:sub(1, tcMatch.startPos - 1):match("^%s*(.-)%s*$")
    local afterText = line:sub(tcMatch.endPos):match("^%s*(.-)%s*$")

    -- Check if there's meaningful text (not just punctuation)
    -- Only strip punctuation marks, keep qualifier words like "ish" and "around"
    local beforeCleaned = beforeText:gsub("~", ""):gsub("%s+", ""):gsub("[%.:]", ""):gsub("%-$", "")
    local afterCleaned = afterText:gsub("~", ""):gsub("%s+", ""):gsub("^[%.:]", ""):gsub("^%-", "")

    local hasTextBefore = beforeCleaned ~= ""
    local hasTextAfter = afterCleaned ~= ""

    if hasTextBefore and hasTextAfter then
        -- Text on both sides - keep full line (including the timecode for context)
        return line, hasTextBefore, hasTextAfter
    elseif hasTextAfter then
        -- Timecode at start - extract just the text after, removing leading punctuation
        local text = afterText:gsub("^[%.:%- ]+", "")
        return text, hasTextBefore, hasTextAfter
    elseif hasTextBefore then
        -- Timecode at end - extract just the text before, removing trailing punctuation
        local text = beforeText:gsub("[%.:%- ]+$", "")
        return text, hasTextBefore, hasTextAfter
    else
        -- Only timecode - use the timecode string itself
        return tcMatch.timecodeStr, hasTextBefore, hasTextAfter
    end
end

-- ============================================================================
-- SEQUENTIAL MARKER HELPERS
-- ============================================================================

--- Calculates the next sequential timecode position
--- @param lastTimecodeString TimecodeString|nil Last marker timecode
--- @param mxInTimecodeString TimecodeString MX IN timecode (fallback)
--- @param markerItemLength number Duration of each marker item in seconds
--- @param proj ReaProject The project
--- @return TimecodeString nextTimecodeString The calculated timecode
local function calculateNextSequentialTimecodeString(lastTimecodeString, mxInTimecodeString, markerItemLength, proj)
    if not lastTimecodeString then
        return mxInTimecodeString
    end

    -- Parse last timecode to seconds, add duration, convert back
    local lastSeconds = reaper.parse_timestr_len(lastTimecodeString, 0, 5)
    local nextSeconds = lastSeconds + markerItemLength - MARKER_OVERLAP_SECONDS
    local nextTimecodeString = reaper.format_timestr_len(nextSeconds, "", 0, 5)

    return nextTimecodeString
end

--- Creates a sequential marker (for lines without timecodes or invalid timecodes)
--- @param noteText string The note text
--- @param lastTimecodeString TimecodeString|nil Last valid timecode
--- @param mxInTimecodeString TimecodeString MX IN timecode
--- @param markerItemLength number Duration of each marker item in seconds
--- @param needsReview boolean Whether to flag for review
--- @param proj ReaProject The project
--- @return SpottingNoteMarker marker The created marker
local function createSequentialMarker(noteText, lastTimecodeString, mxInTimecodeString, markerItemLength, needsReview, proj)
    local timecodeString = calculateNextSequentialTimecodeString(lastTimecodeString, mxInTimecodeString, markerItemLength, proj)

    return {
        timecodeString = timecodeString,
        noteText = noteText,
        duration = markerItemLength,
        needsReview = needsReview
    }
end

-- ============================================================================
-- MAIN PARSING FUNCTION
-- ============================================================================

--- Parses CueDB spotting notes into an array of marker definitions
--- @param spottingNotesText string Multi-line spotting notes text
--- @param mxInTimecodeString TimecodeString MX IN timecode (HH:MM:SS:FF)
--- @param mxOutTimecodeString TimecodeString MX OUT timecode (HH:MM:SS:FF)
--- @param proj ReaProject The REAPER project (for framerate)
--- @param markerItemLength number Duration of each marker item in seconds
--- @param initialLastTimecodeString TimecodeString|nil Optional seed for sequential positioning. When set, the first line without a timecode starts after this position + markerItemLength instead of at MX IN. Useful when MX IN already has an item on the track.
--- @return SpottingNoteMarker[] markers Array of marker definitions
local function parseSpottingNotes(spottingNotesText, mxInTimecodeString, mxOutTimecodeString, proj, markerItemLength, initialLastTimecodeString)
    local markers = {}
    local lastValidTimecodeString = initialLastTimecodeString  -- For calculating sequential positions and hour inference
    local pendingTimecodeString = nil  -- For standalone timecodes awaiting next line
    local pendingTimecodeLine = nil  -- Original line with qualifiers (e.g., "01053922ish")
    local useNextLineForPendingTimecode = false

    -- Split into lines
    local lines = {}
    for line in spottingNotesText:gmatch("([^\r\n]*)[\r\n]?") do
        if line ~= "" then
            table.insert(lines, line)
        end
    end

    for _, line in ipairs(lines) do
        -- Skip empty lines (whitespace only)
        if line:match("^%s*$") then
            goto continue
        end

        -- Handle pending standalone timecode from previous line
        if useNextLineForPendingTimecode and pendingTimecodeString then
            -- Combine original timecode line (with qualifiers) and current line
            local combinedText = pendingTimecodeLine and (pendingTimecodeLine .. "\n" .. line) or line
            table.insert(markers, {
                timecodeString = pendingTimecodeString,
                noteText = combinedText,
                duration = markerItemLength,
                needsReview = false
            })
            lastValidTimecodeString = pendingTimecodeString
            useNextLineForPendingTimecode = false
            pendingTimecodeString = nil
            pendingTimecodeLine = nil
            goto continue
        end

        -- Find all timecode patterns in this line
        local timecodeMatches = findTimecodeStringsInLine(line)

        -- Case: No timecodes found - create sequential marker
        if #timecodeMatches == 0 then
            local marker = createSequentialMarker(line, lastValidTimecodeString, mxInTimecodeString, markerItemLength, false, proj)
            table.insert(markers, marker)
            lastValidTimecodeString = marker.timecodeString
            goto continue
        end

        -- Case: Line contains only a standalone timecode
        if isStandaloneTimecode(line, timecodeMatches) then
            local normalizedTimecodeString = normalizeLooseTimecodeString(
                timecodeMatches[1].timecodeStr,
                mxInTimecodeString,
                mxOutTimecodeString,
                lastValidTimecodeString,
                proj
            )

            if normalizedTimecodeString then
                -- Valid - save for next line, preserving original line with qualifiers
                pendingTimecodeString = normalizedTimecodeString
                pendingTimecodeLine = line  -- Store original line (e.g., "01053922ish")
                useNextLineForPendingTimecode = true
            else
                -- Invalid - create sequential marker flagged for review
                local marker = createSequentialMarker(line, lastValidTimecodeString, mxInTimecodeString, markerItemLength, true, proj)
                table.insert(markers, marker)
                lastValidTimecodeString = marker.timecodeString
            end
            goto continue
        end

        -- Case: Line has timecode(s) with text
        local firstMatch = timecodeMatches[1]
        local normalizedTimecodeString = normalizeLooseTimecodeString(
            firstMatch.timecodeStr,
            mxInTimecodeString,
            mxOutTimecodeString,
            lastValidTimecodeString,
            proj
        )

        if not normalizedTimecodeString then
            -- First timecode is invalid - create sequential marker flagged for review
            local marker = createSequentialMarker(line, lastValidTimecodeString, mxInTimecodeString, markerItemLength, true, proj)
            table.insert(markers, marker)
            lastValidTimecodeString = marker.timecodeString
            goto continue
        end

        -- We have a valid timecode - determine note text based on position
        local noteText, hasTextBefore, hasTextAfter

        if #timecodeMatches == 1 then
            -- Single timecode - extract text based on position
            noteText, hasTextBefore, hasTextAfter = extractNoteTextFromLine(line, firstMatch)

            table.insert(markers, {
                timecodeString = normalizedTimecodeString,
                noteText = noteText,
                duration = markerItemLength,
                needsReview = not (hasTextBefore or hasTextAfter)  -- Flag if only timecode
            })
        else
            -- Multiple timecodes
            -- Check if first timecode is at the very start (no text before)
            local beforeText = line:sub(1, firstMatch.startPos - 1):match("^%s*(.-)%s*$")
            local beforeCleaned = beforeText:gsub("~", ""):gsub("%s+", ""):gsub("[%.:]", ""):gsub("%-$", "")
            local timecodeAtStart = beforeCleaned == ""

            -- If timecode is at start without qualifier, extract text after it
            -- Otherwise keep full line
            if timecodeAtStart then
                -- Extract just the text after the first timecode
                noteText, _, _ = extractNoteTextFromLine(line, firstMatch)
            else
                -- Keep full line
                noteText = line
            end

            table.insert(markers, {
                timecodeString = normalizedTimecodeString,
                noteText = noteText,
                duration = markerItemLength,
                needsReview = false
            })
        end

        lastValidTimecodeString = normalizedTimecodeString

        ::continue::
    end

    -- Handle orphaned standalone timecode at end
    if useNextLineForPendingTimecode and pendingTimecodeString then
        -- Use original line if available (preserves qualifiers), otherwise use normalized timecode
        local noteText = pendingTimecodeLine or pendingTimecodeString
        table.insert(markers, {
            timecodeString = pendingTimecodeString,
            noteText = noteText,
            duration = markerItemLength,
            needsReview = true  -- Flag for review
        })
    end

    return markers
end

-- ============================================================================
-- MODULE EXPORTS
-- ============================================================================

local SpottingNotesParser = {
    parseSpottingNotes = parseSpottingNotes,
}

return SpottingNotesParser
