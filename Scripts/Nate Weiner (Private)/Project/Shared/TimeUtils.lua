-- @description Time and position utility functions for REAPER scripts
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Comprehensive time, timecode, and media item position utilities.
--   Provides clear type-safe conversions between different time representations.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

--- @alias ProjectTime number  -- Seconds from project start (bar 1 typically = 0 or negative if count-in)
--- @alias TimecodeSeconds number  -- Absolute timecode in seconds (includes offset)
--- @alias TimecodeString string  -- Validated SMPTE format "HH:MM:SS:FF" (colons only)
--- @alias LooseTimecodeString string  -- Unvalidated timecode input (could be "HH:MM:SS:FF" or "HH.MM.SS.FF")
--- @alias ProjectOffset number  -- The offset value (projtimeoffs) - relationship: TimecodeSeconds = ProjectTime + ProjectOffset
--- @alias SourceTime number  -- Seconds from the start of a media source file (0 = beginning of file)

---@class TimeUtils
local TimeUtils = {}

-- ============================================================================
-- PROJECT OPERATIONS
-- ============================================================================

---Returns the current project
---@return ReaProject
function TimeUtils.getCurrentProject()
    return reaper.EnumProjects(-1)
end

---Gets the project timecode offset
---@param proj ReaProject The project
---@return ProjectOffset The offset in seconds
function TimeUtils.getProjectOffset(proj)
    return reaper.SNM_GetDoubleConfigVarEx(proj, "projtimeoffs", 0)
end

---Sets the project timecode offset (for the current project)
---@param offsetSeconds ProjectOffset The offset in seconds
function TimeUtils.setProjectOffsetInCurrentProject(offsetSeconds)
    reaper.SNM_SetDoubleConfigVar("projtimeoffs", offsetSeconds)
end

---Calculates the timecode offset needed to position a bar at a specific timecode
---@param proj ReaProject The project
---@param barNumber integer The bar number to position (e.g., 5)
---@param targetTimecodeSeconds TimecodeSeconds The target timecode in seconds where the bar should be
---@return ProjectOffset The required timecode offset
function TimeUtils.calculateProjectOffset(proj, barNumber, targetTimecodeSeconds)
    local barProjectTime = TimeUtils.getProjectTimeAtMeasure(proj, barNumber)
    return targetTimecodeSeconds - barProjectTime
end

-- ============================================================================
-- TIMECODE CONVERSIONS
-- ============================================================================

--- Gets the timecode at a given project time position (for a specific project)
--- @param proj ReaProject The project to use for offset
--- @param projectTime ProjectTime The project time in seconds
--- @return TimecodeSeconds The timecode in seconds (includes offset)
function TimeUtils.projectTimeToTimecodeSeconds(proj, projectTime)
    local offsetSeconds = reaper.SNM_GetDoubleConfigVarEx(proj, "projtimeoffs", 0)
    return projectTime + offsetSeconds
end

--- Gets the timecode at a given project time position (uses current project's offset)
--- @param projectTime ProjectTime The project time in seconds
--- @return TimecodeSeconds The timecode in seconds (includes offset)
function TimeUtils.projectTimeToTimecodeSecondsInCurrentProject(projectTime)
    return TimeUtils.projectTimeToTimecodeSeconds(TimeUtils.getCurrentProject(), projectTime)
end

--- Converts project time to SMPTE timecode string (for a specific project)
--- @param proj ReaProject The project to use for offset
--- @param projectTime ProjectTime The project time in seconds
--- @return TimecodeString SMPTE timecode (HH:MM:SS:FF format with colons)
function TimeUtils.projectTimeToTimecodeString(proj, projectTime)
    -- Convert to timecode seconds
    local timecodeSeconds = TimeUtils.projectTimeToTimecodeSeconds(proj, projectTime)

    -- Format as SMPTE using mode 5 (h:m:s:f)
    -- Mode 5 = h:m:s:f (hours:minutes:seconds:frames)
    local timecodeStr = reaper.format_timestr_len(timecodeSeconds, "", 0, 5)

    -- Check if we got a valid result
    if not timecodeStr or timecodeStr == "" or not timecodeStr:match(":") then
        -- Something went wrong with format_timestr_pos, return a fallback
        -- This shouldn't happen but provides a safety net
        return string.format("%.3f", timecodeSeconds)
    end

    -- Already in HH:MM:SS:FF format with colons (not dots)
    return timecodeStr
end

--- Converts project time to SMPTE timecode string (uses current project's offset)
--- @param projectTime ProjectTime The project time in seconds
--- @return TimecodeString SMPTE timecode (HH:MM:SS:FF format with colons)
function TimeUtils.projectTimeToTimecodeStringInCurrentProject(projectTime)
    return TimeUtils.projectTimeToTimecodeString(TimeUtils.getCurrentProject(), projectTime)
end

--- Gets the project time position of a specific measure
--- @param proj ReaProject The project
--- @param measure integer The measure number (1-based, e.g., measure 1 = first bar)
--- @return ProjectTime projectTime The time position in seconds
function TimeUtils.getProjectTimeAtMeasure(proj, measure)
    -- TimeMap2_beatsToTime uses 0-based measure numbering, so subtract 1
    return reaper.TimeMap2_beatsToTime(proj, 0, measure - 1)
end

--- Converts a timecode string to project time (for a specific project)
--- @param proj ReaProject The project to use for offset
--- @param timecodeStr TimecodeString The timecode in HH:MM:SS:FF format
--- @return ProjectTime The project time position in seconds
function TimeUtils.timecodeStringToProjectTime(proj, timecodeStr)
    local offsetSeconds = reaper.SNM_GetDoubleConfigVarEx(proj, "projtimeoffs", 0)
    return reaper.parse_timestr_len(timecodeStr, 0, 5) - offsetSeconds
end

--- Converts a timecode string to project time (uses current project's offset)
--- @param timecodeStr TimecodeString The timecode in HH:MM:SS:FF format
--- @return ProjectTime The project time position in seconds
function TimeUtils.timecodeStringToProjectTimeInCurrentProject(timecodeStr)
    return TimeUtils.timecodeStringToProjectTime(TimeUtils.getCurrentProject(), timecodeStr)
end

-- ============================================================================
-- CURSOR POSITION
-- ============================================================================

--- Gets the edit cursor position in project time
--- @return ProjectTime The cursor position in seconds from project start
function TimeUtils.getCursorPositionInProjectTime()
    return reaper.GetCursorPosition()
end

--- Sets the edit cursor position in project time
--- @param projectTime ProjectTime The position in seconds from project start
--- @param moveView boolean Whether to scroll the arrange view to follow
--- @param seekPlay boolean Whether to seek playback to new position
function TimeUtils.setCursorPositionInProjectTime(projectTime, moveView, seekPlay)
    reaper.SetEditCurPos(projectTime, moveView, seekPlay)
end

-- ============================================================================
-- MEDIA ITEM POSITION (Project Time)
-- ============================================================================

--- Gets a media item's position information in project time
--- @param item MediaItem The media item
--- @return table { startProjectTime: ProjectTime, endProjectTime: ProjectTime, lengthSeconds: number }
function TimeUtils.getMediaItemPositionInProjectTime(item)
    local startProjectTime = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local lengthSeconds = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local endProjectTime = startProjectTime + lengthSeconds

    return {
        startProjectTime = startProjectTime,
        endProjectTime = endProjectTime,
        lengthSeconds = lengthSeconds
    }
end

--- Sets a media item's position in project time
--- @param item MediaItem The media item
--- @param startProjectTime ProjectTime The new start position in seconds from project start
function TimeUtils.setMediaItemPositionInProjectTime(item, startProjectTime)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", startProjectTime)
end

--- Sets a media item's length
--- @param item MediaItem The media item
--- @param lengthSeconds number The new length in seconds
function TimeUtils.setMediaItemLength(item, lengthSeconds)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", lengthSeconds)
end

-- ============================================================================
-- MEDIA ITEM SOURCE TIME
-- ============================================================================

--- Gets the "start in source" offset for a media item's active take
--- This is how many seconds into the source file the item starts playing from
--- @param item MediaItem The media item
--- @return SourceTime|nil The offset in seconds, or nil if no active take
function TimeUtils.getMediaItemSourceOffset(item)
    local take = reaper.GetActiveTake(item)
    if not take then
        return nil
    end

    return reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
end

--- Sets the "start in source" offset for a media item's active take
--- @param item MediaItem The media item
--- @param sourceOffset SourceTime The offset in seconds into the source file
--- @return boolean success True if offset was set, false if no active take
function TimeUtils.setMediaItemSourceOffset(item, sourceOffset)
    local take = reaper.GetActiveTake(item)
    if not take then
        return false
    end

    reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", sourceOffset)
    return true
end

--- Gets the source file length for a media item's active take
--- @param item MediaItem The media item
--- @return number|nil The source length in seconds, or nil if unavailable
function TimeUtils.getMediaItemSourceLength(item)
    local take = reaper.GetActiveTake(item)
    if not take then
        return nil
    end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then
        return nil
    end

    local length, lengthIsQN = reaper.GetMediaSourceLength(source)
    if lengthIsQN then
        -- Length is in quarter notes, need to convert (not implemented here)
        return nil
    end

    return length
end

-- ============================================================================
-- PROJECT TIME ↔ SOURCE TIME CONVERSIONS
-- ============================================================================

--- Converts a project time position to source time for a specific media item
--- @param item MediaItem The media item
--- @param projectTime ProjectTime The project time position
--- @return SourceTime|nil The position in source time, or nil if outside item bounds or no take
function TimeUtils.projectTimeToSourceTime(item, projectTime)
    local itemPos = TimeUtils.getMediaItemPositionInProjectTime(item)

    -- Check if project time is within item bounds
    if projectTime < itemPos.startProjectTime or projectTime > itemPos.endProjectTime then
        return nil
    end

    local sourceOffset = TimeUtils.getMediaItemSourceOffset(item)
    if not sourceOffset then
        return nil
    end

    -- Calculate position relative to item start, then add source offset
    local timeFromItemStart = projectTime - itemPos.startProjectTime
    return sourceOffset + timeFromItemStart
end

--- Converts a source time position to project time for a specific media item
--- @param item MediaItem The media item
--- @param sourceTime SourceTime The position in source time
--- @return ProjectTime|nil The position in project time, or nil if outside source bounds or no take
function TimeUtils.sourceTimeToProjectTime(item, sourceTime)
    local sourceOffset = TimeUtils.getMediaItemSourceOffset(item)
    if not sourceOffset then
        return nil
    end

    local sourceLength = TimeUtils.getMediaItemSourceLength(item)
    if not sourceLength then
        return nil
    end

    -- Check if source time is within source bounds
    if sourceTime < 0 or sourceTime > sourceLength then
        return nil
    end

    local itemPos = TimeUtils.getMediaItemPositionInProjectTime(item)

    -- Calculate time from source start, subtract offset, add to item start
    local timeFromSourceStart = sourceTime - sourceOffset
    return itemPos.startProjectTime + timeFromSourceStart
end

--- Gets the source time range that a media item covers
--- @param item MediaItem The media item
--- @return table|nil { startSourceTime: SourceTime, endSourceTime: SourceTime } or nil if no take
function TimeUtils.getMediaItemSourceTimeRange(item)
    local sourceOffset = TimeUtils.getMediaItemSourceOffset(item)
    if not sourceOffset then
        return nil
    end

    local itemPos = TimeUtils.getMediaItemPositionInProjectTime(item)
    local startSourceTime = sourceOffset
    local endSourceTime = sourceOffset + itemPos.lengthSeconds

    return {
        startSourceTime = startSourceTime,
        endSourceTime = endSourceTime
    }
end

-- ============================================================================
-- CROSS-PROJECT CONVERSIONS (Using Timecode Bridge)
-- ============================================================================

--- Converts timecode seconds to project time (helper for cross-project conversions)
--- @param proj ReaProject The project to convert to
--- @param timecodeSeconds TimecodeSeconds The timecode in seconds
--- @return ProjectTime The project time position in seconds
local function timecodeSecondsToProjectTime(proj, timecodeSeconds)
    local offsetSeconds = reaper.SNM_GetDoubleConfigVarEx(proj, "projtimeoffs", 0)
    return timecodeSeconds - offsetSeconds
end

--- Converts a project time position to source time across different projects
--- Uses timecode as the bridge between projects (timecode is the universal reference)
--- @param cursorProject ReaProject The project containing the cursor
--- @param cursorProjectTime ProjectTime The cursor position in the cursor project
--- @param videoItem MediaItem The video item (may be in different project)
--- @param videoProject ReaProject The project containing the video item
--- @return SourceTime|nil The position in source time, or nil if conversion failed
function TimeUtils.crossProjectTimeToSourceTime(cursorProject, cursorProjectTime, videoItem, videoProject)
    -- If same project, use direct conversion
    if cursorProject == videoProject then
        return TimeUtils.projectTimeToSourceTime(videoItem, cursorProjectTime)
    end

    -- Different projects - use timecode bridge
    -- Step 1: Convert cursor project time to timecode (absolute reference)
    local timecodeSeconds = TimeUtils.projectTimeToTimecodeSeconds(cursorProject, cursorProjectTime)

    -- Step 2: Convert timecode to project time in video project
    local videoProjectTime = timecodeSecondsToProjectTime(videoProject, timecodeSeconds)

    -- Step 3: Convert video project time to source time
    return TimeUtils.projectTimeToSourceTime(videoItem, videoProjectTime)
end

--- Converts a source time position to project time across different projects
--- Uses timecode as the bridge between projects
--- @param videoItem MediaItem The video item
--- @param videoProject ReaProject The project containing the video item
--- @param sourceTime SourceTime The position in source time
--- @param targetProject ReaProject The target project for the result
--- @return ProjectTime|nil The position in target project time, or nil if conversion failed
function TimeUtils.crossProjectSourceTimeToProjectTime(videoItem, videoProject, sourceTime, targetProject)
    -- If same project, use direct conversion
    if videoProject == targetProject then
        return TimeUtils.sourceTimeToProjectTime(videoItem, sourceTime)
    end

    -- Different projects - use timecode bridge
    -- Step 1: Convert source time to project time in video project
    local videoProjectTime = TimeUtils.sourceTimeToProjectTime(videoItem, sourceTime)
    if not videoProjectTime then
        return nil
    end

    -- Step 2: Convert video project time to timecode (absolute reference)
    local timecodeSeconds = TimeUtils.projectTimeToTimecodeSeconds(videoProject, videoProjectTime)

    -- Step 3: Convert timecode to project time in target project
    return timecodeSecondsToProjectTime(targetProject, timecodeSeconds)
end

return TimeUtils
