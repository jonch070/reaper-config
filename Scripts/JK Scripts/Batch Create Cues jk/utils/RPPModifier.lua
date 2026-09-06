-- @description RPP file modification utilities for batch cue creation
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Handles direct RPP file manipulation for creating cue projects.
--   Copies template RPP and modifies tempo, offset, markers, and items.

---@class RPPModifier
local RPPModifier = {}

-- ============================================================================
-- TEMPLATE CACHING
-- ============================================================================

local cachedTemplatePath = nil
local cachedTemplateContent = nil
local cachedAnalysis = nil ---@type TemplateAnalysis?

---@class TemplateAnalysis
---@field tempoStart number? Byte index where TEMPO header number begins
---@field tempoEnd number? Byte index where TEMPO header number ends
---@field tempoEnvStart number? Byte index where TEMPOENVEX PT tempo begins
---@field tempoEnvEnd number? Byte index where TEMPOENVEX PT tempo ends
---@field projoffsStart number? Byte index where PROJOFFS number begins
---@field projoffsEnd number? Byte index where PROJOFFS number ends
---@field hasEndMarker boolean? Whether the template has an =END marker
---@field endMarkerStart number? Byte index of =END position number start (if exists)
---@field endMarkerEnd number? Byte index of =END position number end (if exists)
---@field endMarkerInsertPos number? Byte position to insert new =END marker line (if no =END)
---@field endMarkerInsertPrefix string? Text to prepend before the marker line at insertion
---@field smptesyncStart number? Byte index where SMPTESYNC line content begins (at keyword)
---@field smptesyncEnd number? Byte index where SMPTESYNC line content ends (before newline)
---@field timemodeStart number? Byte index where TIMEMODE line content begins (at keyword)
---@field timemodeEnd number? Byte index where TIMEMODE line content ends (before newline)
---@field trackCache table<string, number|false>? Lazy cache: trackName -> closing > byte position, or false if not found

---Pre-analyzes the cached template to find byte positions of all edit targets
---@param content string Template content
---@return TemplateAnalysis
local function analyzeTemplate(content)
    local a = {}
    local stepStart = reaper.time_precise()

    -- TEMPO number position
    local s = content:find("TEMPO%s+[%d%.]+")
    if s then
        local numStart, numEnd = content:find("[%d%.]+", s + 5)
        a.tempoStart = numStart
        a.tempoEnd = numEnd
    end

    -- TEMPOENVEX PT line: the tempo envelope overrides the header TEMPO in REAPER
    -- Format: PT <time> <tempo> <shape> ...
    local tempoEnvPos = content:find("<TEMPOENVEX", 1, true)
    if tempoEnvPos then
        local ptPos = content:find("%s+PT%s+[%d%.%-]+%s+[%d%.]+", tempoEnvPos)
        if ptPos then
            -- Skip past "PT <time> " to find the tempo value
            local _, afterTime = content:find("PT%s+[%d%.%-]+%s+", ptPos)
            if afterTime then
                local numStart, numEnd = content:find("[%d%.]+", afterTime + 1)
                if numStart then
                    a.tempoEnvStart = numStart
                    a.tempoEnvEnd = numEnd
                end
            end
        end
    end

    -- PROJOFFS number position
    s = content:find("PROJOFFS%s+[%d%.%-]+")
    if s then
        local numStart, numEnd = content:find("[%d%.%-]+", s + 8)
        a.projoffsStart = numStart
        a.projoffsEnd = numEnd
    end

    -- =END marker
    local endPos = content:find(' =END ', 1, true)
    a.hasEndMarker = endPos ~= nil

    if endPos then
        -- Find the position number to replace
        local lineStart = endPos
        while lineStart > 1 and content:byte(lineStart - 1) ~= 10 do
            lineStart = lineStart - 1
        end
        local _, afterIndex = content:find("MARKER%s+%d+%s+", lineStart)
        if afterIndex then
            local numStart, numEnd = content:find("[%d%.%-]+", afterIndex + 1)
            if numStart and numStart <= endPos then
                a.endMarkerStart = numStart
                a.endMarkerEnd = numEnd
            end
        end
    else
        -- Find insertion point for new =END marker
        local trackPos = content:find("<TRACK", 1, true)
        if trackPos then
            local lastMarkerLineEnd = nil
            local searchPos = 1
            while searchPos < trackPos do
                local ms = content:find("\n%s*MARKER%s+", searchPos)
                if not ms or ms >= trackPos then break end
                local lineEnd = content:find("\n", ms + 1)
                if lineEnd then
                    lastMarkerLineEnd = lineEnd
                    searchPos = lineEnd + 1
                else
                    break
                end
            end

            if lastMarkerLineEnd then
                -- Insert after the last MARKER line's newline
                a.endMarkerInsertPos = lastMarkerLineEnd + 1
                a.endMarkerInsertPrefix = ""
            else
                -- No markers exist, insert before first <TRACK
                a.endMarkerInsertPos = trackPos
                a.endMarkerInsertPrefix = ""
            end
        end
    end

    -- SMPTESYNC line (frame rate and SMPTE sync settings)
    local smptesyncPos = content:find("SMPTESYNC%s+")
    if smptesyncPos then
        local lineEnd = content:find("\n", smptesyncPos) or #content + 1
        a.smptesyncStart = smptesyncPos
        a.smptesyncEnd = lineEnd - 1
        -- Trim trailing whitespace
        while a.smptesyncEnd > a.smptesyncStart and content:byte(a.smptesyncEnd) <= 32 do
            a.smptesyncEnd = a.smptesyncEnd - 1
        end
    end

    -- TIMEMODE line (timecode display format and frame rate)
    local timemodePos = content:find("TIMEMODE%s+")
    if timemodePos then
        local lineEnd = content:find("\n", timemodePos) or #content + 1
        a.timemodeStart = timemodePos
        a.timemodeEnd = lineEnd - 1
        while a.timemodeEnd > a.timemodeStart and content:byte(a.timemodeEnd) <= 32 do
            a.timemodeEnd = a.timemodeEnd - 1
        end
    end

    a.trackCache = {}

    local elapsed = (reaper.time_precise() - stepStart) * 1000
    NW.log("RPPModifier", string.format("Template analyzed in %.2f ms", elapsed))

    -- Debug: log what was found
    if a.tempoStart then
        NW.log("RPPModifier", string.format("  TEMPO header at [%d-%d]: '%s'", a.tempoStart, a.tempoEnd, content:sub(a.tempoStart, a.tempoEnd)))
    else
        NW.log("RPPModifier", "  TEMPO header: not found")
    end
    if a.tempoEnvStart then
        NW.log("RPPModifier", string.format("  TEMPOENVEX PT at [%d-%d]: '%s'", a.tempoEnvStart, a.tempoEnvEnd, content:sub(a.tempoEnvStart, a.tempoEnvEnd)))
    else
        NW.log("RPPModifier", "  TEMPOENVEX PT: not found")
    end
    if a.projoffsStart then
        NW.log("RPPModifier", string.format("  PROJOFFS at [%d-%d]: '%s'", a.projoffsStart, a.projoffsEnd, content:sub(a.projoffsStart, a.projoffsEnd)))
    else
        NW.log("RPPModifier", "  PROJOFFS: not found")
    end
    NW.log("RPPModifier", string.format("  =END marker: %s", a.hasEndMarker and "found" or "not found (will insert)"))
    if a.smptesyncStart then
        NW.log("RPPModifier", string.format("  SMPTESYNC at [%d-%d]: '%s'", a.smptesyncStart, a.smptesyncEnd, content:sub(a.smptesyncStart, a.smptesyncEnd)))
    end
    if a.timemodeStart then
        NW.log("RPPModifier", string.format("  TIMEMODE at [%d-%d]: '%s'", a.timemodeStart, a.timemodeEnd, content:sub(a.timemodeStart, a.timemodeEnd)))
    end

    return a
end

---Finds the byte position of a track's closing > line in the template
---Results are cached per track name in the analysis table
---@param content string Template content
---@param trackName string Name of track to find
---@param analysis TemplateAnalysis
---@return number|nil insertPos Byte position of the closing > line, or nil if track not found
local function analyzeTrack(content, trackName, analysis)
    -- Return cached result
    local cached = analysis.trackCache[trackName]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    -- Find the track name using plain string search
    local namePos = content:find('NAME "' .. trackName .. '"', 1, true)

    if not namePos then
        -- Partial match fallback
        local searchPos = 1
        while true do
            local s = content:find('NAME "', searchPos, true)
            if not s then break end
            local nameEnd = content:find('"', s + 6, true)
            if nameEnd then
                local foundName = content:sub(s + 6, nameEnd - 1)
                if foundName:find(trackName, 1, true) then
                    namePos = s
                    break
                end
                searchPos = nameEnd + 1
            else
                break
            end
        end
    end

    if not namePos then
        NW.log("RPPModifier", "Warning: Track '" .. trackName .. "' not found in template - items won't be inserted")
        analysis.trackCache[trackName] = false
        return nil
    end

    -- Scan forward from NAME line to find the track's closing >
    local depth = 1
    local pos = (content:find("\n", namePos) or #content) + 1

    while pos <= #content do
        local lineEnd = content:find("\n", pos) or (#content + 1)
        local firstChar = content:find("%S", pos)
        if firstChar and firstChar < lineEnd then
            local ch = content:byte(firstChar)
            if ch == 60 then -- '<'
                local nextCh = content:byte(firstChar + 1)
                if nextCh and nextCh >= 65 and nextCh <= 90 then
                    depth = depth + 1
                end
            elseif ch == 62 then -- '>'
                local afterClose = content:find("%S", firstChar + 1)
                if not afterClose or afterClose >= lineEnd then
                    depth = depth - 1
                    if depth == 0 then
                        analysis.trackCache[trackName] = pos
                        return pos
                    end
                end
            end
        end
        pos = lineEnd + 1
    end

    NW.log("RPPModifier", "Warning: Could not find track end for '" .. trackName .. "' - items won't be inserted")
    analysis.trackCache[trackName] = false
    return nil
end

---Applies a sorted list of non-overlapping edits to a string in a single pass
---@param content string Original string
---@param edits table[] Array of {startPos, endPos, replacement} sorted by startPos
---@return string result Modified string
local function applyEdits(content, edits)
    if #edits == 0 then return content end

    local parts = {}
    local cursor = 1

    for _, edit in ipairs(edits) do
        if edit[1] > cursor then
            parts[#parts + 1] = content:sub(cursor, edit[1] - 1)
        end
        parts[#parts + 1] = edit[2]
        cursor = edit[3] + 1
    end

    if cursor <= #content then
        parts[#parts + 1] = content:sub(cursor)
    end

    return table.concat(parts)
end

---Loads and caches a template file (call once before batch processing)
---@param templatePath string Path to template RPP file
---@return boolean success
---@return string? error
function RPPModifier.loadTemplate(templatePath)
    if cachedTemplatePath == templatePath and cachedTemplateContent then
        NW.log("RPPModifier", "Template already cached")
        return true
    end

    NW.log("RPPModifier", "Loading template into cache: " .. templatePath)
    local startTime = reaper.time_precise()

    local templateFile = io.open(templatePath, "r")
    if not templateFile then
        return false, "Could not open template file: " .. templatePath
    end
    cachedTemplateContent = templateFile:read("*all")
    templateFile:close()

    cachedTemplatePath = templatePath

    local elapsed = (reaper.time_precise() - startTime) * 1000
    local sizeMB = #cachedTemplateContent / (1024 * 1024)
    NW.log("RPPModifier", string.format("Template cached: %.1f MB in %.0f ms", sizeMB, elapsed))

    cachedAnalysis = analyzeTemplate(cachedTemplateContent)

    return true
end

---Clears the cached template (call after batch processing completes)
function RPPModifier.clearTemplateCache()
    cachedTemplatePath = nil
    cachedTemplateContent = nil
    cachedAnalysis = nil
    collectgarbage("collect")
    NW.log("RPPModifier", "Template cache cleared")
end

-- ============================================================================
-- GUID GENERATION
-- ============================================================================

---Generates a random hex string of specified length
---@param length number Number of hex characters
---@return string hex Random hex string
local function randomHex(length)
    local chars = "0123456789ABCDEF"
    local result = ""
    for _ = 1, length do
        local idx = math.random(1, 16)
        result = result .. chars:sub(idx, idx)
    end
    return result
end

---Generates a REAPER-style GUID
---@return string guid Format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
function RPPModifier.generateGUID()
    return string.format("{%s-%s-%s-%s-%s}",
        randomHex(8), randomHex(4), randomHex(4), randomHex(4), randomHex(12))
end

-- ============================================================================
-- RPP MODIFICATION
-- ============================================================================

---Creates an item block for the RPP file
---@param position number Position in seconds
---@param length number Length in seconds
---@param noteText string Text for item notes
---@param customColor number|nil Optional custom color in REAPER BGR format (e.g., 0x0000FF for red)
---@return string itemBlock The complete ITEM block
local function createItemBlock(position, length, noteText, customColor)
    local guid = RPPModifier.generateGUID()
    -- Escape any special characters in noteText and handle multi-line
    local escapedNote = noteText:gsub("\n", "\n        |")

    local colorLine = ""
    if customColor then
        colorLine = string.format("\n      COLOR %d B", customColor | 0x1000000)
    end

    return string.format([[    <ITEM
      POSITION %.8f
      SNAPOFFS 0
      LENGTH %.8f
      LOOP 1
      ALLTAKES 0
      FADEIN 0 0.01 0 0 0 0 0
      FADEOUT 0 0.01 0 0 0 0 0
      MUTE 0 0
      SEL 0
      IGUID %s
      IID 1
      <NOTES
        |%s
      >
      IMGRESOURCEFLAGS 8%s
    >]], position, length, guid, escapedNote, colorLine)
end

---@class AdditionalItem
---@field position number Position in cue project local time (seconds)
---@field length number Length in seconds
---@field noteText string Text for item notes
---@field customColor number|nil Optional color in REAPER BGR format (e.g., 0x0000FF for red)

---@class CueConfig
---@field tempo number BPM
---@field projoffs number PROJOFFS value (timecode seconds at cue project time 0)
---@field mxInProjectTime number MX IN position in cue project local time (seconds)
---@field mxOutProjectTime number MX OUT position in cue project local time (seconds)
---@field endMarkerProjectTime number =END marker position in cue project local time (seconds)
---@field markerTrackName string Name of track for MX IN/OUT items
---@field markerItemLength number Length of marker items in seconds
---@field mxInText string|nil Optional text for MX IN item (default "MX IN")
---@field mxOutText string|nil Optional text for MX OUT item (default "MX OUT")
---@field smptesyncLine string|nil Full SMPTESYNC line from video project (replaces template's)
---@field timemodeFields TimemodeFrameRateFields|nil Frame rate fields to merge into template's TIMEMODE
---@field additionalItems AdditionalItem[]|nil Optional additional items to insert on marker track

---Copies template RPP and modifies it to create a cue project.
---Uses single-pass edit collection: all modifications are applied in one
---table.concat call to avoid creating multiple ~315 MB intermediate strings.
---@param templatePath string Path to template RPP file
---@param destPath string Destination path for new cue project
---@param config CueConfig Configuration for the cue
---@return boolean success True if successful
---@return string? error Error message if failed
function RPPModifier.createCueProject(templatePath, destPath, config)
    -- Use cached template if available, otherwise read from disk
    local content
    local analysis = cachedAnalysis
    if cachedTemplateContent and cachedTemplatePath == templatePath then
        content = cachedTemplateContent
    else
        local templateFile = io.open(templatePath, "r")
        if not templateFile then
            return false, "Could not open template file: " .. templatePath
        end
        content = templateFile:read("*all")
        templateFile:close()
        -- Analyze on the fly if not using cached template
        analysis = analyzeTemplate(content)
    end

    if not analysis then
        return false, "Template analysis not available"
    end

    -- Ensure destination directory exists
    NW.FileUtils.ensureParentDirectory(destPath)

    -- All positions are pre-calculated by CueCreator
    NW.log("RPPModifier", string.format("  PROJOFFS=%.10f  mxIn=%.10f  mxOut=%.10f  =END=%.10f",
        config.projoffs, config.mxInProjectTime, config.mxOutProjectTime, config.endMarkerProjectTime))

    -- ========================================================================
    -- Collect all edits as {startPos, replacement, endPos} referencing the
    -- original template. Positions never drift because we splice once at the end.
    -- ========================================================================
    local edits = {}

    -- 1. TEMPO header replacement
    local tempoStr = string.format("%.2f", config.tempo)
    if analysis.tempoStart then
        edits[#edits + 1] = {
            analysis.tempoStart,
            tempoStr,
            analysis.tempoEnd
        }
    end

    -- 1b. TEMPOENVEX PT tempo replacement (envelope overrides header in REAPER)
    if analysis.tempoEnvStart then
        edits[#edits + 1] = {
            analysis.tempoEnvStart,
            string.format("%.10f", config.tempo),
            analysis.tempoEnvEnd
        }
    end

    -- 2. PROJOFFS replacement
    if analysis.projoffsStart then
        edits[#edits + 1] = {
            analysis.projoffsStart,
            string.format("%.8f", config.projoffs),
            analysis.projoffsEnd
        }
    end

    -- 3. =END marker: replace existing position or insert new marker line
    if analysis.endMarkerStart then
        edits[#edits + 1] = {
            analysis.endMarkerStart,
            string.format("%.8f", config.endMarkerProjectTime),
            analysis.endMarkerEnd
        }
    elseif analysis.endMarkerInsertPos then
        local markerLine = string.format('  MARKER 900 %.8f =END 0 0 1 B %s 0\n',
            config.endMarkerProjectTime, RPPModifier.generateGUID())
        edits[#edits + 1] = {
            analysis.endMarkerInsertPos,
            (analysis.endMarkerInsertPrefix or "") .. markerLine,
            analysis.endMarkerInsertPos - 1  -- zero-width insertion
        }
    end

    -- 4. SMPTESYNC replacement (frame rate from video project)
    if config.smptesyncLine and analysis.smptesyncStart then
        edits[#edits + 1] = {
            analysis.smptesyncStart,
            config.smptesyncLine,
            analysis.smptesyncEnd
        }
    end

    -- 5. TIMEMODE merge: replace only frame rate fields (2, 4, 5) from the video
    -- project while preserving the template's ruler and clock display settings
    if config.timemodeFields and analysis.timemodeStart then
        local templateTimemode = content:sub(analysis.timemodeStart, analysis.timemodeEnd)
        local fields = {}
        for field in templateTimemode:gmatch("%S+") do
            fields[#fields + 1] = field
        end
        if #fields >= 6 then
            fields[3] = config.timemodeFields.fpsPreset
            fields[5] = config.timemodeFields.customFps
            fields[6] = config.timemodeFields.dropFrame
            edits[#edits + 1] = {
                analysis.timemodeStart,
                table.concat(fields, " "),
                analysis.timemodeEnd
            }
        end
    end

    -- 6. Track item insertion
    local trackInsertPos = analyzeTrack(content, config.markerTrackName, analysis)
    if trackInsertPos then
        local itemBlocks = {}
        itemBlocks[#itemBlocks + 1] = createItemBlock(
            config.mxInProjectTime, config.markerItemLength, config.mxInText or "MX IN")
        itemBlocks[#itemBlocks + 1] = createItemBlock(
            config.mxOutProjectTime, config.markerItemLength, config.mxOutText or "MX OUT")

        -- Additional items (e.g., spotting note markers)
        if config.additionalItems then
            for _, item in ipairs(config.additionalItems) do
                itemBlocks[#itemBlocks + 1] = createItemBlock(
                    item.position, item.length, item.noteText, item.customColor)
            end
        end

        local insertStr = table.concat(itemBlocks, "\n") .. "\n"
        edits[#edits + 1] = {
            trackInsertPos,
            insertStr,
            trackInsertPos - 1  -- zero-width insertion
        }
    end

    -- Sort edits by position (ascending)
    table.sort(edits, function(a, b) return a[1] < b[1] end)

    -- Apply all edits in a single pass
    local result = applyEdits(content, edits)

    -- Write to destination
    local destFile = io.open(destPath, "w")
    if not destFile then
        return false, "Could not write to destination: " .. destPath
    end
    destFile:write(result)
    destFile:close()

    NW.log("RPPModifier", "Created cue project: " .. destPath)
    return true, nil
end

return RPPModifier
