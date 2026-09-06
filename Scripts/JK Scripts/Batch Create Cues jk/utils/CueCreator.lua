-- @description Cue creation workflow orchestration
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Coordinates the batch cue creation workflow:
--   - Creates cue project folders
--   - Generates RPP files using RPPModifier
--   - Optionally enriches with SpotNotes data
--   - Inserts subprojects into video project

local RPPModifier = require("RPPModifier")
local CSVParser = require("CSVParser")

---@class CueCreator
local CueCreator = {}

-- Small offset added after frame-snapping to guard against floating-point
-- precision loss from %.8f formatting. Frame boundaries like 25/30 are
-- repeating decimals (0.83333...) that can truncate to 0.83333333, giving
-- 24.9999999 when multiplied by fps. The epsilon ensures the value stays
-- above the frame boundary after formatting. 0.0001s is well under a single
-- frame at any standard fps (smallest standard frame = 1/240 = 0.00417s).
local FRAME_EPSILON = 0.0001

---Snaps a timecode value to the nearest frame boundary + epsilon
---@param seconds number Timecode in seconds
---@param fps number Frame rate
---@return number snapped Frame-aligned value with epsilon safety margin
local function snapToFrame(seconds, fps)
    return math.floor(seconds * fps + 0.5) / fps + FRAME_EPSILON
end

---Snaps a timecode value to the next frame boundary (ceil) + epsilon.
---Used for PROJOFFS to ensure REAPER doesn't floor it to an earlier frame.
---@param seconds number Timecode in seconds
---@param fps number Frame rate
---@return number snapped Frame-aligned value (ceil) with epsilon safety margin
local function snapToFrameCeil(seconds, fps)
    return math.ceil(seconds * fps) / fps + FRAME_EPSILON
end

---Gets the project frame rate
---@param proj ReaProject The project
---@return number fps Frame rate
local function getProjectFps(proj)
    local fps, _ = reaper.TimeMap_curFrameRate(proj)
    return fps
end

---@class TimemodeFrameRateFields
---@field fpsPreset string Field 2: frame rate preset index (e.g., "0"=23.976, "1"=24, "5"=30)
---@field customFps string Field 4: custom fps value (e.g., "24", "30", "75")
---@field dropFrame string Field 5: drop-frame flag (e.g., "2" for 23.976 drop frame, "0" otherwise)

---Extracts SMPTESYNC line and frame rate fields from TIMEMODE in a project RPP file.
---These are in the project header (first ~30 lines) so we read line-by-line
---and stop early rather than loading the entire file.
---@param projectPath string Path to the RPP file
---@return string? smptesyncLine The SMPTESYNC line content (trimmed)
---@return TimemodeFrameRateFields? timemodeFields Frame rate fields from TIMEMODE
local function extractFrameRateLines(projectPath)
    local file = io.open(projectPath, "r")
    if not file then return nil, nil end

    local smptesync, timemodeFields
    local linesRead = 0

    for line in file:lines() do
        linesRead = linesRead + 1
        local trimmed = line:match("^%s*(.-)%s*$")

        if trimmed:find("^SMPTESYNC%s") then
            smptesync = trimmed
        elseif trimmed:find("^TIMEMODE%s") then
            local fields = {}
            for field in trimmed:gmatch("%S+") do
                fields[#fields + 1] = field
            end
            -- TIMEMODE fields: 1=keyword, 2=ruler, 3=fpsPreset, 4=clock, 5=customFps, 6=dropFrame, ...
            if #fields >= 6 then
                timemodeFields = {
                    fpsPreset = fields[3],
                    customFps = fields[5],
                    dropFrame = fields[6],
                }
            end
        end

        -- Both settings are in the project header, well before tracks
        if smptesync and timemodeFields then break end
        if trimmed:find("^<TRACK") then break end
        if linesRead > 200 then break end
    end

    file:close()
    return smptesync, timemodeFields
end

---REAPER TIMEMODE fps preset index -> fps value
local FPS_PRESETS = {
    ["0"] = 24000 / 1001, -- 23.976
    ["1"] = 24,
    ["2"] = 25,
    ["3"] = 30000 / 1001, -- 29.97
    ["4"] = 30000 / 1001, -- 29.97 drop-frame
    ["5"] = 30,
    ["6"] = 30000 / 1001, -- 30 drop-frame
}

---Decodes HH:MM:SS:FF (colon or semicolon separators) to seconds.
---Drop-frame timecodes are treated as-is (frames divided by fps); the HGG
---workflow uses non-DF colon timecodes.
---@param tc string Timecode string
---@param fps number Frame rate for frame-count conversion
---@return number? seconds Absolute seconds, or nil if not parseable
function CueCreator.timecodeToSeconds(tc, fps)
    if not tc or tc == "" then return nil end
    local h, m, s, f = tc:match("^(%d+)[^%d]+(%d+)[^%d]+(%d+)[^%d]+(%d+)$")
    if not h then return nil end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(f) / fps
end

---Reads the frame rate from a project RPP file header.
---Priority: SMPTESYNC explicit fps -> TIMEMODE preset map -> customFps field.
---@param projectPath string Path to an .rpp file
---@return number? fps Frame rate, or nil if it cannot be determined
function CueCreator.getTemplateFps(projectPath)
    local smptesyncLine, timemodeFields = extractFrameRateLines(projectPath)
    if smptesyncLine then
        local fields = {}
        for field in smptesyncLine:gmatch("%S+") do
            fields[#fields + 1] = field
        end
        local fps = fields[2] and tonumber(fields[2])
        if fps and fps > 0 then return fps end
    end
    if timemodeFields then
        local presetFps = FPS_PRESETS[timemodeFields.fpsPreset]
        if presetFps then return presetFps end
        local custom = timemodeFields.customFps and tonumber(timemodeFields.customFps)
        if custom and custom > 0 then return custom end
    end
    return nil
end

---Synthesizes Region[] from ordered SpotNotes rows so CSV-driven creation
---reuses the entire region pipeline. Names follow "CueID - Title".
---Rows missing valid IN/OUT timecodes are skipped.
---@param notesList SpotNote[] Ordered spotting notes (CSV file order)
---@param fps number Frame rate used to decode timecodes
---@return Region[] regions Synthesized regions
---@return string[] skipped Cue IDs skipped due to missing/invalid timecodes
function CueCreator.regionsFromSpotNotes(notesList, fps)
    local regions, skipped = {}, {}
    for _, note in ipairs(notesList or {}) do
        local startSec = CueCreator.timecodeToSeconds(note.inTimecode, fps)
        local endSec = CueCreator.timecodeToSeconds(note.outTimecode, fps)
        if startSec and endSec and endSec > startSec then
            local name = note.cueId
            if note.title and note.title ~= "" then
                name = name .. " - " .. note.title
            end
            regions[#regions + 1] = {
                name = name,
                startTime = startSec,
                endTime = endSec,
            }
        else
            skipped[#skipped + 1] = note.cueId or "?"
        end
    end
    return regions, skipped
end

---@class CreateCueResult
---@field success boolean
---@field cueId string
---@field projectPath string?
---@field error string?
---@field mediaItem MediaItem? The inserted subproject item (for cleanup on cancel)
---@field mediaTrack MediaTrack? The track the item was inserted on
---@field isRecreation boolean? True if an existing cue was re-created (renamed to _old)

-- ============================================================================
-- FOLDER STRUCTURE
-- ============================================================================

---Sanitizes a string for use as a folder/file name
---@param name string The name to sanitize
---@return string sanitized Safe folder name
local function sanitizeFolderName(name)
    -- Replace problematic characters
    local sanitized = name:gsub('[<>:"/\\|?*]', "-")
    -- Collapse multiple dashes
    sanitized = sanitized:gsub("%-+", "-")
    -- Trim leading/trailing dashes and spaces
    sanitized = sanitized:match("^[%s%-]*(.-)[%s%-]*$") or sanitized
    return sanitized
end

---Creates the cue folder name from region name
---@param regionName string The region name
---@return string folderName The cue folder name
local function createCueFolderName(regionName)
    return sanitizeFolderName(regionName)
end
CueCreator.createCueFolderName = createCueFolderName

---Creates the cue project base name (filename without extension).
---By default the suffix is inserted after the cue ID portion (before " - ") so
---that "CB-m08 - Title" with suffix "_v1a" becomes "CB-m08_v1a - Title".
---When atEnd is true, the suffix is appended to the end of the full name
---instead: "CB-m08 - Title_v1a".
---@param regionName string The region name
---@param suffix string? Optional suffix (e.g., "_v1a")
---@param atEnd boolean? True to place the suffix at the end of the name
---@return string baseName The filename without extension
function CueCreator.createCueBaseName(regionName, suffix, atEnd)
    local sanitized = sanitizeFolderName(regionName)
    local sfx = suffix or ""
    if sfx == "" or atEnd then
        return sanitized .. sfx
    end
    -- Insert suffix before the first " - " separator (cue ID boundary)
    local dashPos = sanitized:find(" %- ")
    if dashPos then
        return sanitized:sub(1, dashPos - 1) .. sfx .. sanitized:sub(dashPos)
    end
    return sanitized .. sfx
end

---Creates the cue project filename.
---@param regionName string The region name
---@param suffix string? Optional suffix (e.g., "_v1a")
---@param atEnd boolean? True to place the suffix at the end of the filename
---@return string fileName The RPP filename
function CueCreator.createCueFileName(regionName, suffix, atEnd)
    return CueCreator.createCueBaseName(regionName, suffix, atEnd) .. ".rpp"
end

-- ============================================================================
-- VIDEO PROJECT INTEGRATION
-- ============================================================================

---Checks if a new item would overlap with existing items on a track
---@param track MediaTrack The track to check
---@param startTime number Start time of the new item
---@param endTime number End time of the new item
---@return boolean hasOverlap True if the new item would overlap existing items
local function wouldOverlapOnTrack(track, startTime, endTime)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemStart + itemLength

        -- Check for overlap: new item starts before existing ends AND new item ends after existing starts
        if startTime < itemEnd and endTime > itemStart then
            return true
        end
    end
    return false
end

---Sets the take name to the filename without extension
---@param take MediaItem_Take The take to rename
local function setTakeNameWithoutExtension(take)
    local takeName = reaper.GetTakeName(take)
    local nameWithoutExt = takeName:match("^(.+)%.[^.]+$") or takeName
    if nameWithoutExt ~= takeName then
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", nameWithoutExt, true)
    end
end

---Inserts a subproject item into the video project
---@param vidProj ReaProject The video project
---@param cueProjectPath string Path to the cue RPP file
---@param startProjectTime number Start position in video project time (seconds)
---@param endProjectTime number End position in video project time (seconds)
---@param cuesTrackName string Name of track to insert subproject on
---@param altCuesTrackName string? Optional alternate track name for overlapping cues
---@return boolean success
---@return string? error
---@return MediaItem? item The inserted media item
---@return MediaTrack? track The track the item was inserted on
local function insertSubproject(vidProj, cueProjectPath, startProjectTime, endProjectTime, cuesTrackName, altCuesTrackName)
    -- Find the cues track
    local cuesTrack = NW.ReaperTracksAndFolders.findTrackByNameExactThenContains(vidProj, cuesTrackName)
    if not cuesTrack then
        return false, "Could not find '" .. cuesTrackName .. "' track"
    end

    -- Check for overlap on primary track
    local targetTrack = cuesTrack
    if wouldOverlapOnTrack(cuesTrack, startProjectTime, endProjectTime) then
        -- Try alt track if specified
        if altCuesTrackName and altCuesTrackName ~= "" then
            local altTrack = NW.ReaperTracksAndFolders.findTrackByNameExactThenContains(vidProj, altCuesTrackName)
            if altTrack then
                targetTrack = altTrack
                NW.log("CueCreator", "  Using alt track due to overlap")
            else
                return false, "Overlap on primary track, but alt track '" .. altCuesTrackName .. "' not found"
            end
        else
            return false, "Would overlap existing item on '" .. cuesTrackName .. "' track (no alt track configured)"
        end
    end

    -- Set cursor to insert position
    reaper.SetEditCurPos(startProjectTime, false, false)

    -- Select the destination track
    reaper.SetOnlyTrackSelected(targetTrack)

    -- Insert the subproject
    local result = reaper.InsertMedia(cueProjectPath, 0)
    if result == 0 then
        return false, "Failed to insert subproject"
    end

    -- Find the newly inserted item by matching its source file path
    local foundItem = nil
    local itemCount = reaper.CountTrackMediaItems(targetTrack)
    for i = itemCount - 1, 0, -1 do
        local item = reaper.GetTrackMediaItem(targetTrack, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            if source then
                local filename = reaper.GetMediaSourceFileName(source)
                if filename == cueProjectPath then
                    -- Set the subproject item's position and length
                    reaper.SetMediaItemPosition(item, startProjectTime, false)
                    local duration = endProjectTime - startProjectTime
                    reaper.SetMediaItemLength(item, duration, false)
                    setTakeNameWithoutExtension(take)
                    reaper.UpdateItemInProject(item)
                    foundItem = item
                    break
                end
            end
        end
    end

    return true, nil, foundItem, targetTrack
end

---Updates an existing subproject item's position and length on the cues track.
---Used during re-creation when the subproject item already exists.
---@param vidProj ReaProject The video project
---@param cueProjectPath string Path to the cue RPP file
---@param startProjectTime number Start position in video project time (seconds)
---@param endProjectTime number End position in video project time (seconds)
---@param cuesTrackName string Name of track to search for subproject
---@param altCuesTrackName string? Optional alternate track name
---@return boolean success
---@return string? error
---@return MediaItem? item The updated media item
---@return MediaTrack? track The track the item is on
local function updateExistingSubproject(vidProj, cueProjectPath, startProjectTime, endProjectTime, cuesTrackName, altCuesTrackName)
    local function findOnTrack(trackName)
        if not trackName or trackName == "" then return nil, nil end
        local track = NW.ReaperTracksAndFolders.findTrackByNameExactThenContains(vidProj, trackName)
        if not track then return nil, nil end
        local itemCount = reaper.CountTrackMediaItems(track)
        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local take = reaper.GetActiveTake(item)
            if take then
                local source = reaper.GetMediaItemTake_Source(take)
                if source then
                    local filename = reaper.GetMediaSourceFileName(source)
                    if filename == cueProjectPath then
                        return item, track
                    end
                end
            end
        end
        return nil, nil
    end

    local item, track = findOnTrack(cuesTrackName)
    if not item and altCuesTrackName then
        item, track = findOnTrack(altCuesTrackName)
    end

    if not item then
        return false, "Existing subproject item not found"
    end

    reaper.SetMediaItemPosition(item, startProjectTime, false)
    local duration = endProjectTime - startProjectTime
    reaper.SetMediaItemLength(item, duration, false)
    local take = reaper.GetActiveTake(item)
    if take then setTakeNameWithoutExtension(take) end
    reaper.UpdateItemInProject(item)

    NW.log("CueCreator", "  Updated existing subproject item position and length")
    return true, nil, item, track
end

-- ============================================================================
-- SPOTTING NOTES → RPP ITEMS
-- ============================================================================

local MARKER_ITEM_LENGTH_SECONDS = 2
local SPOTTING_MARKER_LENGTH_BARS = 2
local REVIEW_ITEM_COLOR = 0x0000FF -- Red (BGR format for REAPER)

---Parses spotting notes text into AdditionalItem array for RPP insertion.
---Converts parser output (timecode strings) into cue project positions using
---the same frame-snap math as MX IN/OUT items.
---@param notesText string Multi-line spotting notes text
---@param mxInTimecodeSeconds number MX IN in absolute timecode seconds
---@param mxOutTimecodeSeconds number MX OUT in absolute timecode seconds
---@param fps number Frame rate
---@param subprojectStartTimecodeSeconds number PROJOFFS value
---@param tempo number BPM for calculating bar-based item lengths
---@param vidProj ReaProject The video project (for parser's framerate lookup)
---@param markerItemLength number Duration used for sequential marker spacing (seconds)
---@return AdditionalItem[] additionalItems
local function parseSpottingNotesForRPP(notesText, mxInTimecodeSeconds, mxOutTimecodeSeconds, fps, subprojectStartTimecodeSeconds, tempo, vidProj, markerItemLength)
    -- Convert timecode seconds back to timecode strings for the parser
    local mxInTimecodeString = reaper.format_timestr_len(mxInTimecodeSeconds, "", 0, 5)
    local mxOutTimecodeString = reaper.format_timestr_len(mxOutTimecodeSeconds, "", 0, 5)

    -- Seed the parser with MX IN as the "last" timecode so that lines without
    -- timecodes start after the MX IN item rather than on top of it
    local markers = NW.SpottingNotesParser.parseSpottingNotes(
        notesText, mxInTimecodeString, mxOutTimecodeString, vidProj, markerItemLength, mxInTimecodeString
    )

    if #markers == 0 then
        NW.log("CueCreator", "  Spotting notes text:\n" .. notesText)
        NW.log("CueCreator", "  No markers parsed from spotting notes")
        return {}
    end

    -- Log the raw notes text and each parsed marker
    NW.log("CueCreator", "  Spotting notes text:\n" .. notesText)
    for i, marker in ipairs(markers) do
        local reviewFlag = marker.needsReview and " [REVIEW]" or ""
        local notePreview = marker.noteText:gsub("\n", " | ")
        NW.log("CueCreator", string.format("  Marker %d: %s  \"%s\"%s",
            i, marker.timecodeString, notePreview, reviewFlag))
    end

    -- Convert markers to cue project positions with frame snapping
    local items = {}
    for _, marker in ipairs(markers) do
        local timecodeSeconds = reaper.parse_timestr_len(marker.timecodeString, 0, 5)
        local position = snapToFrame(timecodeSeconds, fps) - subprojectStartTimecodeSeconds

        table.insert(items, {
            position = position,
            noteText = marker.noteText,
            needsReview = marker.needsReview,
        })
    end

    -- Sort by position
    table.sort(items, function(a, b) return a.position < b.position end)

    -- Calculate default item length: SPOTTING_MARKER_LENGTH_BARS bars at the given tempo (4/4 time)
    local defaultLength = SPOTTING_MARKER_LENGTH_BARS * 4 * 60 / tempo

    -- Apply overlap prevention between spotting note markers
    for i, item in ipairs(items) do
        local length = defaultLength

        if i < #items then
            local gap = items[i + 1].position - item.position
            if gap < defaultLength then
                length = math.max(gap - 0.01, 0.1)
            end
        end

        item.length = length
        item.customColor = item.needsReview and REVIEW_ITEM_COLOR or nil
        item.needsReview = nil  -- Not needed in AdditionalItem
    end

    NW.log("CueCreator", string.format("  Parsed %d spotting note marker(s)", #items))

    return items
end

-- ============================================================================
-- CUE CREATION
-- ============================================================================

---Creates a single cue project from a region
---@param vidProj ReaProject The video project
---@param region Region The region to create a cue from
---@param settings BatchCueSettings Settings for cue creation
---@param spotNotes table<string, SpotNote>? Optional spotting notes map
---@param smptesyncLine string? SMPTESYNC line from video project
---@param timemodeFields TimemodeFrameRateFields? Frame rate fields from video project TIMEMODE
---@return CreateCueResult result
local function createSingleCue(vidProj, region, settings, spotNotes, smptesyncLine, timemodeFields)
    local cueId = region.name
    local result = {
        success = false,
        cueId = cueId,
        projectPath = nil,
        error = nil
    }

    -- ========================================================================
    -- TIME CALCULATIONS
    -- All position math is done here in one place. RPPModifier receives
    -- pre-calculated values and just writes them to the RPP file.
    --
    -- Frame alignment strategy:
    --   1. Snap MX IN/OUT timecodes to their exact frame boundaries
    --   2. Ceil PROJOFFS to the next frame boundary (so REAPER doesn't
    --      floor it to an earlier frame). Bar 3 (or whatever they set their count in to)
    --      may land slightly within
    --      a frame rather than exactly on the boundary — that's acceptable.
    --   3. Snap each item position to the nearest frame in timecode space
    --      (projoffs + position → snap → back-derive position). Every
    --      marker lands cleanly on a frame regardless of bar alignment.
    --
    -- All snap/ceil operations include a small epsilon to guard against
    -- repeating-decimal precision loss after %.8f formatting in the RPP.
    -- ========================================================================

    -- CSV-driven cues use absolute CSV timecodes: no parent timeline offset,
    -- fps resolved from the template (see initProcessing). Region-driven cues
    -- keep the video-project offset and live project fps.
    local vidProjOffset = settings.csvSource and 0 or NW.TimeUtils.getProjectOffset(vidProj)
    local fps = (settings.csvSource and settings.csvFps) or getProjectFps(vidProj)

    -- Step 1: Snap MX IN/OUT to exact frame boundaries in absolute timecode.
    -- Region positions from the video project may have floating-point drift,
    -- so we snap to ensure we're working with exact frame-aligned values.
    local mxInTimecodeSeconds = snapToFrame(region.startTime + vidProjOffset, fps)
    local mxOutTimecodeSeconds = snapToFrame(region.endTime + vidProjOffset, fps)

    -- How many seconds of count-in precede the cue start bar (pure tempo math, 4/4 time)
    -- TODO - Don't hardcode 4/4 here (or if we do, we should write that time sig in when modifying tempo)
    local countInSeconds = (settings.cueStartBar - 1) * 4 * (60 / settings.defaultTempo)

    -- Step 2: Ceil PROJOFFS to the next frame boundary.
    -- REAPER appears to snap PROJOFFS to a frame boundary internally. If we
    -- let it fall between frames, REAPER floors it and all timecodes shift.
    -- Using ceil ensures PROJOFFS lands on the next frame up, preventing
    -- any downward shift. Bar cueStartBar won't be exactly on a frame
    -- boundary, but it will be within a frame of the MX IN timecode.
    local rawProjoffs = mxInTimecodeSeconds - countInSeconds
    local subprojectStartTimecodeSeconds = snapToFrameCeil(rawProjoffs, fps)

    -- Where the subproject item starts in video project time (offset removed)
    local subprojectStartProjectSeconds = subprojectStartTimecodeSeconds - vidProjOffset

    -- Step 3: Snap item positions to frames in timecode space.
    -- Each item's timecode (projoffs + position) is snapped to the nearest
    -- frame, then the position is back-derived. This ensures every marker
    -- lands on a clean frame boundary regardless of where PROJOFFS puts the
    -- bar grid. MX IN may be slightly off from bar cueStartBar, but its
    -- timecode will match the video project region exactly.
    local mxInProjectTime = snapToFrame(mxInTimecodeSeconds, fps) - subprojectStartTimecodeSeconds
    local mxOutProjectTime = snapToFrame(mxOutTimecodeSeconds, fps) - subprojectStartTimecodeSeconds

    -- =END marker position in cue project local time.
    -- endMarkerOffset is an integer number of seconds, so snapping it
    -- preserves frame alignment from MX OUT.
    local endMarkerProjectTime = snapToFrame(
        mxOutTimecodeSeconds + settings.endMarkerOffset, fps
    ) - subprojectStartTimecodeSeconds

    -- Where the subproject item ends in video project time
    local subprojectEndTimecodeSeconds = subprojectStartTimecodeSeconds + endMarkerProjectTime
    local subprojectEndProjectSeconds = subprojectEndTimecodeSeconds - vidProjOffset

    NW.log("CueCreator", string.format("  %s: fps=%.5f  mxIn TC=%.10f  mxOut TC=%.10f",
        cueId, fps, mxInTimecodeSeconds, mxOutTimecodeSeconds))
    NW.log("CueCreator", string.format("  %s: PROJOFFS=%.10f  countIn=%.10f  rawProjoffs=%.10f",
        cueId, subprojectStartTimecodeSeconds, countInSeconds, rawProjoffs))
    NW.log("CueCreator", string.format("  %s: mxIn proj=%.10f  mxOut proj=%.10f  =END proj=%.10f",
        cueId, mxInProjectTime, mxOutProjectTime, endMarkerProjectTime))
    NW.log("CueCreator", string.format("  %s: subproj start=%.10f  end=%.10f (video project time)",
        cueId, subprojectStartProjectSeconds, subprojectEndProjectSeconds))

    -- ========================================================================
    -- PATH + EXISTENCE CHECK
    -- ========================================================================

    local folderName = createCueFolderName(cueId)
    local fileName = CueCreator.createCueFileName(cueId, settings.filenameSuffix, settings.versionTagAtEnd)
    local cueFolderPath = settings.outputFolder .. "/" .. folderName
    local cueProjectPath = cueFolderPath .. "/" .. fileName

    local existingFile = io.open(cueProjectPath, "r")
    if existingFile then
        existingFile:close()
        -- Rename existing file to _old so we can create a fresh one
        local oldFileName = fileName:gsub("%.rpp$", "_old.rpp")
        local oldPath = cueFolderPath .. "/" .. oldFileName
        os.remove(oldPath)
        local ok, renameErr = os.rename(cueProjectPath, oldPath)
        if not ok then
            result.error = "Failed to rename existing cue: " .. (renameErr or "unknown")
            return result
        end
        NW.log("CueCreator", "  Renamed existing cue to: " .. oldPath)
        result.isRecreation = true
    end

    -- ========================================================================
    -- SPOTTING NOTES
    -- ========================================================================

    local mxInText = "MX IN"
    local mxOutText = "MX OUT"
    local additionalItems = nil
    if spotNotes then
        local note = CSVParser.findByCueId(spotNotes, cueId)
        if note then
            if note.inDescription and note.inDescription ~= "" then
                mxInText = "MX IN - " .. note.inDescription
            end
            if note.outDescription and note.outDescription ~= "" then
                mxOutText = "MX OUT - " .. note.outDescription
            end
            if note.notes and note.notes ~= "" then
                additionalItems = parseSpottingNotesForRPP(
                    note.notes,
                    mxInTimecodeSeconds, mxOutTimecodeSeconds,
                    fps, subprojectStartTimecodeSeconds,
                    settings.defaultTempo, vidProj, MARKER_ITEM_LENGTH_SECONDS
                )
            end
        end
    end

    -- ========================================================================
    -- CREATE CUE PROJECT (RPP file)
    -- ========================================================================

    ---@type CueConfig
    local config = {
        tempo = settings.defaultTempo,
        projoffs = subprojectStartTimecodeSeconds,
        mxInProjectTime = mxInProjectTime,
        mxOutProjectTime = mxOutProjectTime,
        endMarkerProjectTime = endMarkerProjectTime,
        markerTrackName = settings.markerTrackName,
        markerItemLength = MARKER_ITEM_LENGTH_SECONDS,
        mxInText = mxInText,
        mxOutText = mxOutText,
        smptesyncLine = smptesyncLine,
        timemodeFields = timemodeFields,
        additionalItems = additionalItems,
    }

    local success, err = RPPModifier.createCueProject(settings.templatePath, cueProjectPath, config)
    if not success then
        result.error = err
        return result
    end

    -- ========================================================================
    -- INSERT SUBPROJECT INTO VIDEO PROJECT (skipped in files-only mode)
    -- ========================================================================

    if not settings.insertItems then
        -- Standalone cue sessions: the RPP is fully self-contained
        -- (timecode alignment, markers). Nothing goes on the timeline.
        NW.log("CueCreator", "  Files-only mode: created " .. fileName)
        result.success = true
        result.projectPath = cueProjectPath
        return result
    end

    if subprojectStartProjectSeconds < 0 then
        result.error = string.format(
            "Cannot create cue: subproject would start %.2f seconds before the video project start " ..
            "(count-in bars extend before time 0). Start the video timecode earlier to make space.",
            math.abs(subprojectStartProjectSeconds)
        )
        result.projectPath = cueProjectPath
        return result
    end

    local mediaItem, mediaTrack
    if result.isRecreation then
        -- Try to update the existing subproject item's position/length
        success, err, mediaItem, mediaTrack = updateExistingSubproject(vidProj, cueProjectPath,
            subprojectStartProjectSeconds, subprojectEndProjectSeconds,
            settings.cuesTrackName, settings.altCuesTrackName)
        if not success then
            -- Existing item not found (may have been manually deleted) - insert fresh
            NW.log("CueCreator", "  Existing subproject item not found, inserting new one")
            success, err, mediaItem, mediaTrack = insertSubproject(vidProj, cueProjectPath,
                subprojectStartProjectSeconds, subprojectEndProjectSeconds,
                settings.cuesTrackName, settings.altCuesTrackName)
        end
    else
        success, err, mediaItem, mediaTrack = insertSubproject(vidProj, cueProjectPath,
            subprojectStartProjectSeconds, subprojectEndProjectSeconds,
            settings.cuesTrackName, settings.altCuesTrackName)
    end
    if not success then
        result.error = "Created RPP but failed to insert subproject: " .. (err or "unknown error")
        result.projectPath = cueProjectPath
        return result
    end

    result.success = true
    result.projectPath = cueProjectPath
    result.mediaItem = mediaItem
    result.mediaTrack = mediaTrack
    return result
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---@class CueProcessingState
---@field vidProj ReaProject
---@field regions Region[]
---@field settings BatchCueSettings
---@field spotNotes table<string, SpotNote>|nil
---@field smptesyncLine string|nil SMPTESYNC line from video project RPP
---@field timemodeFields TimemodeFrameRateFields|nil Frame rate fields from video project TIMEMODE
---@field currentIndex number
---@field results CreateCueResult[]
---@field successCount number
---@field failCount number
---@field onProgress function|nil
---@field onComplete function|nil

---Initializes async cue processing state
---@param vidProj ReaProject The video project
---@param videoProjectPath string Path to the video project RPP file
---@param regions Region[] Regions to create cues from
---@param settings BatchCueSettings Settings for cue creation
---@param onProgress function? Callback: function(current, total, cueId, result)
---@param onComplete function? Callback: function(results, successCount, failCount)
---@return CueProcessingState state Processing state object
function CueCreator.initProcessing(vidProj, videoProjectPath, regions, settings, onProgress, onComplete)
    -- CSV-driven mode: absolute timecodes, standalone files. Frame rate and
    -- the SMPTESYNC/TIMEMODE transplant come from the TEMPLATE project
    -- (there is no meaningful video-project timeline in this mode).
    -- SpotNotes are still loaded normally below - they are the cue source.
    local smptesyncLine, timemodeFields
    if settings.csvSource then
        settings.insertItems = false
        settings.csvFps = CueCreator.getTemplateFps(settings.templatePath) or getProjectFps(vidProj)
        NW.log("CueCreator", string.format("CSV mode: template fps resolved to %.6f",
            settings.csvFps or 0))
        smptesyncLine, timemodeFields = extractFrameRateLines(settings.templatePath)
    else
        -- Extract frame rate settings from video project RPP to transplant into cue projects
        smptesyncLine, timemodeFields = extractFrameRateLines(videoProjectPath)
    end
    if smptesyncLine then
        NW.log("CueCreator", "Video project SMPTESYNC: " .. smptesyncLine)
    end
    if timemodeFields then
        NW.log("CueCreator", string.format("Video project TIMEMODE fps fields: preset=%s customFps=%s dropFrame=%s",
            timemodeFields.fpsPreset, timemodeFields.customFps, timemodeFields.dropFrame))
    end

    -- Load spotting notes if path provided
    local spotNotes = nil
    if settings.spotNotesPath and settings.spotNotesPath ~= "" then
        local notes, err = CSVParser.parse(settings.spotNotesPath)
        if err then
            NW.log("CueCreator", "Warning: Could not load spotting notes: " .. err)
        else
            spotNotes = notes
            NW.log("CueCreator", "Loaded spotting notes")
        end
    end

    return {
        vidProj = vidProj,
        regions = regions,
        settings = settings,
        spotNotes = spotNotes,
        smptesyncLine = smptesyncLine,
        timemodeFields = timemodeFields,
        currentIndex = 0,
        results = {},
        successCount = 0,
        failCount = 0,
        onProgress = onProgress,
        onComplete = onComplete,
    }
end

---Processes the next cue in the queue
---@param state CueProcessingState The processing state
---@return boolean done True if all cues have been processed
function CueCreator.processNext(state)
    state.currentIndex = state.currentIndex + 1

    -- Check if we're done
    if state.currentIndex > #state.regions then
        -- Save video project after all insertions
        if state.successCount > 0 then
            reaper.Main_SaveProject(state.vidProj, false)
        end

        -- Clear template cache to free memory
        RPPModifier.clearTemplateCache()

        -- Call completion callback
        if state.onComplete then
            state.onComplete(state.results, state.successCount, state.failCount)
        end

        return true -- Done
    end

    local region = state.regions[state.currentIndex]

    NW.log("CueCreator", string.format("Creating cue %d/%d: %s",
        state.currentIndex, #state.regions, region.name))

    local result = createSingleCue(
        state.vidProj,
        region,
        state.settings,
        state.spotNotes,
        state.smptesyncLine,
        state.timemodeFields
    )

    table.insert(state.results, result)

    if result.success then
        state.successCount = state.successCount + 1
    else
        state.failCount = state.failCount + 1
        NW.log("CueCreator", "  Error: " .. (result.error or "unknown"))
    end

    -- Call progress callback
    if state.onProgress then
        state.onProgress(state.currentIndex, #state.regions, region.name, result)
    end

    return false -- Not done yet
end

---Gets a summary string of creation results
---@param results CreateCueResult[] Array of results
---@param successCount number Number of successes
---@param failCount number Number of failures
---@return string summary Human-readable summary
function CueCreator.getSummary(results, successCount, failCount)
    local lines = {}

    if successCount > 0 and failCount == 0 then
        table.insert(lines, string.format("Successfully created %d cue(s)!", successCount))
    elseif successCount > 0 and failCount > 0 then
        table.insert(lines, string.format("Created %d cue(s), %d failed.", successCount, failCount))
    else
        table.insert(lines, string.format("Failed to create cues. %d error(s).", failCount))
    end

    -- List failures
    for _, result in ipairs(results) do
        if not result.success then
            table.insert(lines, string.format("\n  %s: %s", result.cueId, result.error or "unknown error"))
        end
    end

    return table.concat(lines, "")
end

---Loads the template into cache (passthrough to RPPModifier)
---Call this before starting batch processing
---@param templatePath string Path to template RPP file
---@return boolean success
---@return string? error
function CueCreator.loadTemplate(templatePath)
    return RPPModifier.loadTemplate(templatePath)
end

---Clears the template cache (passthrough to RPPModifier)
---Call this if processing is cancelled before completion
function CueCreator.clearTemplateCache()
    RPPModifier.clearTemplateCache()
end

---@class ClassifiedRegion
---@field region Region The region
---@field hasExistingCue boolean Whether a subproject item already exists for this region

---Classifies all regions by whether they already have subproject items on the cues tracks.
---@param proj ReaProject The video project
---@param regions Region[] All regions
---@param cuesTrackName string Name of the primary cues track
---@param altCuesTrackName string? Optional alternate cues track name
---@param filenameSuffix string? Suffix appended to cue filenames
---@param versionTagAtEnd boolean? True when the suffix is placed at the end of the filename
---@param opts table|nil Optional controls: { filesOnly=true, outputFolder="..." }
---   When filesOnly is set, detection checks the output folder on disk
---   instead of scanning cues tracks for subproject items.
---@return ClassifiedRegion[] classified All regions with existence status
function CueCreator.classifyRegions(proj, regions, cuesTrackName, altCuesTrackName, filenameSuffix, versionTagAtEnd, opts)
    local existingNames = {}

    if not (opts and opts.filesOnly) then
        local function scanTrack(trackName)
            if not trackName or trackName == "" then return end
            local track = NW.ReaperTracksAndFolders.findTrackByNameExactThenContains(proj, trackName)
            if not track then return end

            local itemCount = reaper.CountTrackMediaItems(track)
            for i = 0, itemCount - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                local take = reaper.GetActiveTake(item)
                if take then
                    local source = reaper.GetMediaItemTake_Source(take)
                    if source then
                        local filename = reaper.GetMediaSourceFileName(source)
                        local baseName = filename:match("([^/\\]+)$")
                        if baseName then
                            baseName = baseName:match("^(.+)%.[^.]+$") or baseName
                            existingNames[baseName:upper()] = true
                        end
                    end
                end
            end
        end

        scanTrack(cuesTrackName)
        scanTrack(altCuesTrackName)
    end

    local classified = {}
    for _, region in ipairs(regions) do
        -- Match against the exact filename the cue would be created with
        local expectedName = CueCreator.createCueBaseName(region.name, filenameSuffix, versionTagAtEnd)
        local hasExistingCue
        if opts and opts.filesOnly then
            local cuePath = (opts.outputFolder or "") .. "/" ..
                createCueFolderName(region.name) .. "/" .. expectedName .. ".rpp"
            local f = io.open(cuePath, "r")
            if f then f:close() hasExistingCue = true end
            hasExistingCue = hasExistingCue == true
        else
            hasExistingCue = existingNames[expectedName:upper()] == true
        end
        table.insert(classified, {
            region = region,
            hasExistingCue = hasExistingCue,
        })
    end

    return classified
end

---Scans cues tracks for existing subproject items and determines which
---regions still need cue projects created.
---@param proj ReaProject The video project
---@param regions Region[] All regions
---@param cuesTrackName string Name of the primary cues track
---@param altCuesTrackName string? Optional alternate cues track name
---@param filenameSuffix string? Suffix appended to cue filenames
---@param versionTagAtEnd boolean? True when the suffix is placed at the end of the filename
---@param opts table|nil Optional controls passed through to classifyRegions
---@return number existingCount Number of regions with existing subproject items
---@return Region[] missingRegions Regions without subproject items on the cues tracks
function CueCreator.findMissingRegions(proj, regions, cuesTrackName, altCuesTrackName, filenameSuffix, versionTagAtEnd, opts)
    local classified = CueCreator.classifyRegions(proj, regions, cuesTrackName, altCuesTrackName, filenameSuffix, versionTagAtEnd, opts)
    local existingCount = 0
    local missing = {}
    for _, cr in ipairs(classified) do
        if cr.hasExistingCue then
            existingCount = existingCount + 1
        else
            table.insert(missing, cr.region)
        end
    end

    return existingCount, missing
end

return CueCreator
