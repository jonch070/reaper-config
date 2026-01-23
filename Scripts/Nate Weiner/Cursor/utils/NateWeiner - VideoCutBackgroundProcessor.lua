-- VideoCutBackgroundProcessor.lua - Background orchestration for video cut navigation
-- Main defer loop that handles jump requests, scanning, and background filling
-- Author: Nate Weiner (https://nateweiner.com)

-- Bootstrap NW environment
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
local sharedPath = scriptPath:match("^(.+)[/\\][^/\\]+$"):match("^(.+)[/\\][^/\\]+$") .. "/Shared/"
package.path = package.path .. ";" .. sharedPath .. "?.lua"

require("NWInit")({
    debug = false,
    feature = "CursorToCut",
    libs = { "VideoSelection", "FFmpegLib", "TimeUtils" },
})
if not NW then return end

-- Add local paths for this package's modules
local parentDir = NW.scriptDir:match("^(.+)[/\\][^/\\]+$")
package.path = package.path .. ";" .. NW.scriptDir .. "/?.lua"
package.path = package.path .. ";" .. parentDir .. "/?.lua"
package.path = package.path .. ";" .. parentDir .. "/ffmpeg/?.lua"

local VideoCutConfig = require("config")
local VideoCutScanner = require("VideoCutScanner")
local VideoCutCache = require("VideoCutCache")
local FFmpegUtils = require("FFmpegUtils")

-- Shorthand config references (for readability)
local SCENE_THRESHOLD = VideoCutConfig.SCENE_THRESHOLD
local DOWNSCALE_WIDTH = VideoCutConfig.DOWNSCALE_WIDTH
local NAVIGATION_SEARCH_CHUNK_SIZE = VideoCutConfig.NAVIGATION_SEARCH_CHUNK_SIZE
local BACKGROUND_FILL_CHUNK_SIZE = VideoCutConfig.BACKGROUND_FILL_CHUNK_SIZE
local MAX_SEARCH_DISTANCE = VideoCutConfig.MAX_SEARCH_DISTANCE
local HEARTBEAT_UPDATE_INTERVAL = VideoCutConfig.HEARTBEAT_UPDATE_INTERVAL
local ENABLE_PROCESSING_WINDOW = VideoCutConfig.ENABLE_PROCESSING_WINDOW
local PROCESSING_WINDOW_SIZE = VideoCutConfig.PROCESSING_WINDOW_SIZE

---@class JumpRequest
---@field direction string "next" or "previous"
---@field timestamp number When the request was made

---@class SearchState
---@field direction string "next" or "previous"
---@field searchedDistance number How far we've searched
---@field maxDistance number Maximum search distance

---@class VideoContext
---@field videoPath string Path to video file
---@field videoItem MediaItem Video item reference
---@field videoProject ReaProject Project containing the video item
---@field cursorProject ReaProject Project where the cursor is (may differ from videoProject)
---@field sourceLengthSeconds number Total source length
---@field fps number Video FPS

---@class VideoCutState
---@field processorActive boolean Whether processor is running
---@field pendingJumpRequest JumpRequest|nil Pending jump request
---@field searchingForJumpRequest boolean Whether we're currently searching
---@field searchState SearchState|nil Current search state
---@field currentVideo VideoContext|nil Current video context
---@field loopCounter number Loop iteration counter for heartbeat updates
---@field ffmpegUnavailable boolean|nil Set to true if ffmpeg is not available

-- Log startup path information for debugging
NW.log("Processor", "=== BackgroundProcessor startup ===")
NW.log("Processor", "scriptDir: " .. (NW.scriptDir or "nil"))
NW.log("Processor", "parentDir: " .. (parentDir or "nil"))

---Check for new jump requests from ExtState
---Called each loop iteration to pick up requests from jump scripts
local function checkForNewJumpRequests()
    local state = _G.NW_VideoCutState

    -- Only check if we don't already have a pending request
    if state.pendingJumpRequest then
        return
    end

    local direction = reaper.GetExtState("NW_VideoCut", "pendingJumpDirection")
    local timestamp = reaper.GetExtState("NW_VideoCut", "pendingJumpTimestamp")

    if direction ~= "" then
        NW.log("Processor", string.format("Found new jump request in ExtState: direction=%s", direction))
        state.pendingJumpRequest = {
            direction = direction,
            timestamp = tonumber(timestamp) or 0
        }
        -- Clear ExtState so we don't re-process
        reaper.SetExtState("NW_VideoCut", "pendingJumpDirection", "", false)
        reaper.SetExtState("NW_VideoCut", "pendingJumpTimestamp", "", false)
    end
end

---Initialize global state if needed
---Uses both _G (for this script instance) and ExtState (for cross-script communication)
local function initGlobalState()
    if not _G.NW_VideoCutState then
        ---@type VideoCutState
        _G.NW_VideoCutState = {
            processorActive = false,
            pendingJumpRequest = nil,
            searchingForJumpRequest = false,
            searchState = nil,
            currentVideo = nil,
            loopCounter = 0,
            ffmpegUnavailable = false
        }
    end

    -- Check for initial jump request from ExtState (set by jump scripts)
    checkForNewJumpRequests()
end

---Get current video context from cursor position
---@return VideoContext|nil Video context
---@return string|nil Error message if context could not be obtained
local function getCurrentVideoContext()
    local videoItem, videoPath, videoProject, selectionMethod = NW.VideoSelection.getVideoItem()
    if not videoItem or not videoPath or not videoProject then
        return nil, selectionMethod or "No video item found"
    end

    -- Get the current (cursor) project
    local cursorProject = reaper.EnumProjects(-1)

    local sourceLengthSeconds = NW.TimeUtils.getMediaItemSourceLength(videoItem)
    if not sourceLengthSeconds then
        return nil, "Could not get video source length"
    end

    -- Try to get FPS from cache first (avoids running ffprobe every time)
    local fps = nil
    local cache = VideoCutCache.load(videoProject, videoPath)
    if cache and cache.settings and cache.settings.fps then
        fps = cache.settings.fps
        NW.log("Processor", string.format("Using cached FPS: %.3f", fps))
    else
        -- Cache doesn't exist or doesn't have FPS, run ffprobe
        local errorMsg
        fps, errorMsg = NW.FFmpegLib.getVideoFPS(videoPath)
        if not fps then
            return nil, errorMsg or "Could not detect video FPS"
        end
        NW.log("Processor", string.format("Detected FPS via ffprobe: %.3f", fps))
    end

    return {
        videoPath = videoPath,
        videoItem = videoItem,
        videoProject = videoProject,
        cursorProject = cursorProject,
        sourceLengthSeconds = sourceLengthSeconds,
        fps = fps
    }
end

---Find cut in cached data relative to cursor
---Returns cut only if there's an uninterrupted cached range between cursor and cut
---@param cache table Cache data
---@param videoItem MediaItem Video item for time conversion
---@param videoProject ReaProject Project containing the video item
---@param cursorProject ReaProject Project where cursor is
---@param cursorProjectTime number Cursor position in ProjectTime
---@param direction string "next" or "previous"
---@return number|nil Cut position in ProjectTime (in cursor project), or nil if none found
local function findCutInCache(cache, videoItem, videoProject, cursorProject, cursorProjectTime, direction)
    if not cache or not cache.cuts or #cache.cuts == 0 then
        return nil
    end

    -- Convert cursor to source time (using cross-project conversion)
    local cursorSourceTime = NW.TimeUtils.crossProjectTimeToSourceTime(cursorProject, cursorProjectTime, videoItem, videoProject)
    if not cursorSourceTime then
        return nil
    end

    -- Find the appropriate cut (using frame-precision comparison to avoid floating-point issues)
    local fps = cache.settings.fps
    local candidateCutSourceTime = nil
    for _, cutSourceTime in ipairs(cache.cuts) do
        if direction == "next" then
            if FFmpegUtils.isTimeGreaterThan(cutSourceTime, cursorSourceTime, fps) then
                if not candidateCutSourceTime or cutSourceTime < candidateCutSourceTime then
                    candidateCutSourceTime = cutSourceTime
                end
            end
        else -- previous
            if FFmpegUtils.isTimeLessThan(cutSourceTime, cursorSourceTime, fps) then
                if not candidateCutSourceTime or cutSourceTime > candidateCutSourceTime then
                    candidateCutSourceTime = cutSourceTime
                end
            end
        end
    end

    if not candidateCutSourceTime then
        return nil
    end

    -- Check if there's an uninterrupted cached range between cursor and cut
    local rangeStart, rangeEnd
    if direction == "next" then
        rangeStart = cursorSourceTime
        rangeEnd = candidateCutSourceTime
    else
        rangeStart = candidateCutSourceTime
        rangeEnd = cursorSourceTime
    end

    -- Check if this entire range is cached
    if not VideoCutCache.isRangeCached(cache, rangeStart, rangeEnd) then
        NW.log("Processor", string.format("Cut found at %.1fs but range not fully cached", candidateCutSourceTime))
        return nil
    end

    -- Convert to project time (in cursor project using cross-project conversion)
    return NW.TimeUtils.crossProjectSourceTimeToProjectTime(videoItem, videoProject, candidateCutSourceTime, cursorProject)
end

---Check if cache extends to the end of video in a given direction
---@param cache table Cache data
---@param cursorSourceTime number Cursor position in SourceTime
---@param direction string "next" or "previous"
---@param sourceLengthSeconds number Total source length
---@return boolean True if cache extends to the end in that direction
local function cacheExtendsToEnd(cache, cursorSourceTime, direction, sourceLengthSeconds)
    if not cache or not cache.processed_ranges then
        return false
    end

    if direction == "next" then
        -- Check if any range extends from cursor to end of video
        for _, range in ipairs(cache.processed_ranges) do
            if range[1] <= cursorSourceTime and range[2] >= sourceLengthSeconds then
                return true
            end
        end
    else -- previous
        -- Check if any range extends from start of video to cursor
        for _, range in ipairs(cache.processed_ranges) do
            if range[1] <= 0 and range[2] >= cursorSourceTime then
                return true
            end
        end
    end

    return false
end

---Find the nearest cut in the requested direction from cursor
---@param cuts table Array of cut SourceTimes
---@param cursorSourceTime number Cursor position in SourceTime
---@param direction string "next" or "previous"
---@param fps number Video frames per second (for frame-precision comparison)
---@return number|nil Cut SourceTime, or nil if none found
local function findNearestCutInDirection(cuts, cursorSourceTime, direction, fps)
    local foundCut = nil

    for _, cutSourceTime in ipairs(cuts) do
        if direction == "next" then
            if FFmpegUtils.isTimeGreaterThan(cutSourceTime, cursorSourceTime, fps) then
                if not foundCut or cutSourceTime < foundCut then
                    foundCut = cutSourceTime
                end
            end
        elseif direction == "previous" then
            if FFmpegUtils.isTimeLessThan(cutSourceTime, cursorSourceTime, fps) then
                if not foundCut or cutSourceTime > foundCut then
                    foundCut = cutSourceTime
                end
            end
        end
    end

    return foundCut
end

---Clear the jump request state
local function clearJumpRequest()
    local state = _G.NW_VideoCutState
    state.pendingJumpRequest = nil
    state.searchingForJumpRequest = false
    state.searchState = nil
end

---Jump to video boundary (start or end)
---@param direction string "next" or "previous"
---@param logPrefix string Prefix for log message (e.g., "No next cut found")
local function jumpToVideoBoundary(direction, logPrefix)
    local state = _G.NW_VideoCutState

    if direction == "next" then
        local endSourceTime = state.currentVideo.sourceLengthSeconds
        local endProjectTime = NW.TimeUtils.crossProjectSourceTimeToProjectTime(
            state.currentVideo.videoItem,
            state.currentVideo.videoProject,
            endSourceTime,
            state.currentVideo.cursorProject
        )
        if endProjectTime then
            -- SetEditCurPos operates on the active project (which is cursorProject)
            NW.TimeUtils.setCursorPositionInProjectTime(endProjectTime, true, true)
            NW.log("Processor", string.format("%s, jumped to end of video at %.2fs project time", logPrefix, endProjectTime))
            reaper.UpdateTimeline()
        end
    else -- previous
        local startSourceTime = 0
        local startProjectTime = NW.TimeUtils.crossProjectSourceTimeToProjectTime(
            state.currentVideo.videoItem,
            state.currentVideo.videoProject,
            startSourceTime,
            state.currentVideo.cursorProject
        )
        if startProjectTime then
            -- Ensure we don't go to negative project time
            startProjectTime = math.max(0, startProjectTime)
            -- SetEditCurPos operates on the active project (which is cursorProject)
            NW.TimeUtils.setCursorPositionInProjectTime(startProjectTime, true, true)
            NW.log("Processor", string.format("%s, jumped to start of video at %.2fs project time", logPrefix, startProjectTime))
            reaper.UpdateTimeline()
        end
    end
end

---Jump to a cut and clear the jump request state
---@param cutSourceTime number Cut position in SourceTime
---@param logMessage string Message to log
local function jumpToCutAndClearRequest(cutSourceTime, logMessage)
    local state = _G.NW_VideoCutState

    local cutProjectTime = NW.TimeUtils.crossProjectSourceTimeToProjectTime(
        state.currentVideo.videoItem,
        state.currentVideo.videoProject,
        cutSourceTime,
        state.currentVideo.cursorProject
    )
    if cutProjectTime then
        -- SetEditCurPos operates on the active project (which is cursorProject)
        NW.TimeUtils.setCursorPositionInProjectTime(cutProjectTime, true, true)
        NW.log("Processor", logMessage)
        reaper.UpdateTimeline()
    end

    clearJumpRequest()
end

---Handle first cut found callback (for "next" direction optimization)
---Called as soon as first cut(s) are detected, even if job still running
---@param firstCuts table Array of first cuts found
local function handleFirstCutFound(firstCuts)
    local state = _G.NW_VideoCutState

    if not state.pendingJumpRequest or not state.searchState then
        return
    end

    -- Only works for "next" direction
    if state.searchState.direction ~= "next" then
        return
    end

    -- Find nearest cut after cursor
    -- GetCursorPosition returns position in the active project (which is cursorProject)
    local cursorProjectTime = NW.TimeUtils.getCursorPositionInProjectTime()
    local cursorSourceTime = NW.TimeUtils.crossProjectTimeToSourceTime(
        state.currentVideo.cursorProject,
        cursorProjectTime,
        state.currentVideo.videoItem,
        state.currentVideo.videoProject
    )
    if not cursorSourceTime then
        return
    end

    local foundCut = findNearestCutInDirection(firstCuts, cursorSourceTime, "next", state.currentVideo.fps)
    if foundCut then
        local foundCutProjectTime = NW.TimeUtils.crossProjectSourceTimeToProjectTime(
            state.currentVideo.videoItem,
            state.currentVideo.videoProject,
            foundCut,
            state.currentVideo.cursorProject
        ) or 0
        jumpToCutAndClearRequest(foundCut, string.format("Jumped to cut at %.2fs project time (from firstCutCallback)", foundCutProjectTime))
    end
end

---Filter gaps to only those within the processing window around cursor
---Used to limit background fill to a specific range around the user's working area
---@param gaps table Array of gaps {start, end}
---@param cursorSourceTime number Cursor position in SourceTime
---@param windowSize number Total window size in seconds (centered on cursor)
---@param sourceLengthSeconds number Total video length (for bounds checking)
---@param fps number Video FPS for quantization
---@return table Filtered gaps within window (clipped to window bounds)
local function filterGapsToWindow(gaps, cursorSourceTime, windowSize, sourceLengthSeconds, fps)
    if not gaps or #gaps == 0 then
        return {}
    end

    -- Calculate window bounds (centered on cursor)
    local halfWindow = windowSize / 2
    local windowStart = math.max(0, cursorSourceTime - halfWindow)
    local windowEnd = math.min(sourceLengthSeconds, cursorSourceTime + halfWindow)

    -- Quantize window bounds to frame boundaries to match quantized cache ranges
    -- This prevents floating-point precision issues that can create zero-length gaps
    windowStart = FFmpegUtils.quantizeSecondsToFrame(windowStart, fps)
    windowEnd = FFmpegUtils.quantizeSecondsToFrame(windowEnd, fps)

    NW.log("Processor", string.format("Processing window: %.1f-%.1fs (cursor at %.1fs, window size %.1fs)",
        windowStart, windowEnd, cursorSourceTime, windowSize))

    local filteredGaps = {}
    for _, gap in ipairs(gaps) do
        -- Include gap if it overlaps with window at all
        if gap[2] > windowStart and gap[1] < windowEnd then
            -- Clip gap to window bounds
            -- This second quantization shouldn't be needed, it implies the gaps aren't quantized so that is falling through somewhere before this
            local clippedStart = FFmpegUtils.quantizeSecondsToFrame(math.max(gap[1], windowStart), fps)
            local clippedEnd = FFmpegUtils.quantizeSecondsToFrame(math.min(gap[2], windowEnd), fps)

            -- Only include gaps with non-zero length after clipping
            -- Even with quantization, boundaries can align perfectly creating zero-length gaps
            if clippedEnd > clippedStart then
                table.insert(filteredGaps, {clippedStart, clippedEnd})
                NW.log("Processor", string.format("  Including gap %.1f-%.1fs (clipped to %.1f-%.1fs)",
                    gap[1], gap[2], clippedStart, clippedEnd))
            else
                NW.log("Processor", string.format("  Excluding gap %.1f-%.1fs (clipped to %.1f-%.1fs, zero-length after clipping)",
                    gap[1], gap[2], clippedStart, clippedEnd))
            end
        else
            NW.log("Processor", string.format("  Excluding gap %.1f-%.1fs (outside window)", gap[1], gap[2]))
        end
    end

    return filteredGaps
end

---Handle search result callback
---Called when job completes with all cuts found
---@param cutsFound table|nil Array of cuts found, or nil on error
---@param error string|nil Error message if any
local function handleSearchResult(cutsFound, error)
    local state = _G.NW_VideoCutState

    -- Check if jump was already handled by firstCutCallback
    if not state.pendingJumpRequest or not state.searchingForJumpRequest then
        NW.log("Processor", "Jump already handled by firstCutCallback, skipping handleSearchResult")
        return
    end

    if error then
        NW.log("Processor", "Search error: " .. error)
        reaper.ShowMessageBox("Scene detection failed: " .. error, "Error", 0)
        clearJumpRequest()
        return
    end

    if not cutsFound then
        NW.log("Processor", "Search returned no results")
        clearJumpRequest()
        return
    end

    -- Find nearest cut in requested direction
    -- GetCursorPosition returns position in the active project (which is cursorProject)
    local cursorProjectTime = NW.TimeUtils.getCursorPositionInProjectTime()
    local cursorSourceTime = NW.TimeUtils.crossProjectTimeToSourceTime(
        state.currentVideo.cursorProject,
        cursorProjectTime,
        state.currentVideo.videoItem,
        state.currentVideo.videoProject
    )
    if not cursorSourceTime then
        clearJumpRequest()
        return
    end

    local direction = state.searchState.direction
    local foundCut = findNearestCutInDirection(cutsFound, cursorSourceTime, direction, state.currentVideo.fps)

    if foundCut then
        local foundCutProjectTime = NW.TimeUtils.crossProjectSourceTimeToProjectTime(
            state.currentVideo.videoItem,
            state.currentVideo.videoProject,
            foundCut,
            state.currentVideo.cursorProject
        ) or 0
        jumpToCutAndClearRequest(foundCut, string.format("Jumped to cut at %.2fs project time", foundCutProjectTime))
        return
    end

    -- No cut found in this chunk, continue searching
    state.searchState.searchedDistance = state.searchState.searchedDistance + NAVIGATION_SEARCH_CHUNK_SIZE

    if state.searchState.searchedDistance >= MAX_SEARCH_DISTANCE then
        -- Exhausted search
        reaper.ShowMessageBox("No cut found within 2 minutes", "Info", 0)
        clearJumpRequest()
        return
    end

    -- Queue next search chunk
    local nextChunkStart, nextChunkEnd
    if direction == "next" then
        nextChunkStart = cursorSourceTime + state.searchState.searchedDistance
        nextChunkEnd = math.min(nextChunkStart + NAVIGATION_SEARCH_CHUNK_SIZE, state.currentVideo.sourceLengthSeconds)

        -- Check if we've reached the end of the video
        if nextChunkStart >= state.currentVideo.sourceLengthSeconds then
            -- No more video to search, jump to end of video
            jumpToVideoBoundary("next", "No next cut found")
            clearJumpRequest()
            return
        end
    else -- previous
        nextChunkEnd = cursorSourceTime - state.searchState.searchedDistance
        nextChunkStart = math.max(0, nextChunkEnd - NAVIGATION_SEARCH_CHUNK_SIZE)

        -- Check if we've reached the beginning of the video
        if nextChunkEnd <= 0 then
            -- No more video to search, jump to start of video
            jumpToVideoBoundary("previous", "No previous cut found")
            clearJumpRequest()
            return
        end
    end

    NW.log("Processor", string.format("Continuing search: %.1f-%.1fs (searched %.1fs so far)",
        nextChunkStart, nextChunkEnd, state.searchState.searchedDistance))

    local continueJobSpec = {
        videoPath = state.currentVideo.videoPath,
        videoItem = state.currentVideo.videoItem,
        project = state.currentVideo.videoProject,
        fps = state.currentVideo.fps,
        startSourceTime = nextChunkStart,
        endSourceTime = nextChunkEnd,
        threshold = SCENE_THRESHOLD,
        downscaleWidth = DOWNSCALE_WIDTH,
        priority = "high",
        callback = handleSearchResult
    }

    -- Add firstCutCallback for "next" direction to enable immediate jumping
    if direction == "next" then
        continueJobSpec.firstCutCallback = handleFirstCutFound
    end

    VideoCutScanner.addJob(continueJobSpec)
end

---Validate that stored project references are still valid
---@param videoProject ReaProject The video project
---@param cursorProject ReaProject The cursor project
---@return boolean valid True if both projects are still open
local function areProjectsStillValid(videoProject, cursorProject)
    -- Check if projects are still in the enumeration
    local foundVideo = false
    local foundCursor = false

    local projIdx = 0
    while true do
        local proj = reaper.EnumProjects(projIdx)
        if not proj then
            break
        end

        if proj == videoProject then
            foundVideo = true
        end
        if proj == cursorProject then
            foundCursor = true
        end

        -- Early exit if both found
        if foundVideo and foundCursor then
            return true
        end

        projIdx = projIdx + 1
    end

    return foundVideo and foundCursor
end

---Phase 1: Process pending jump request
local function processJumpRequest()
    local state = _G.NW_VideoCutState

    if not state.pendingJumpRequest or state.searchingForJumpRequest then
        return
    end

    local direction = state.pendingJumpRequest.direction
    NW.log("Processor", string.format("Processing %s jump request", direction))

    -- Get current context
    local context, error = getCurrentVideoContext()
    if not context then
        reaper.ShowMessageBox(error, "Error", 0)
        clearJumpRequest()
        return
    end

    -- Store context
    state.currentVideo = context

    -- Load cache
    local cache = VideoCutCache.load(context.videoProject, context.videoPath)
    if not cache or not VideoCutCache.isValid(cache, SCENE_THRESHOLD, DOWNSCALE_WIDTH) then
        NW.log("Processor", "Creating new cache")
        cache = VideoCutCache.createNew(context.videoPath, SCENE_THRESHOLD, DOWNSCALE_WIDTH, context.fps)
        VideoCutCache.save(context.videoProject, context.videoPath, cache)
    end

    -- Check for cached cut
    -- GetCursorPosition returns position in the active project (which is cursorProject)
    local cursorProjectTime = NW.TimeUtils.getCursorPositionInProjectTime()
    local cutProjectTime = findCutInCache(cache, context.videoItem, context.videoProject, context.cursorProject, cursorProjectTime, direction)

    if cutProjectTime then
        -- Found cut in cache, jump to it
        -- SetEditCurPos operates on the active project (which is cursorProject)
        NW.TimeUtils.setCursorPositionInProjectTime(cutProjectTime, true, true)
        NW.log("Processor", string.format("Jumped to cached cut at %.2fs project time", cutProjectTime))
        reaper.UpdateTimeline()
        clearJumpRequest()
        return
    end

    -- No cached cut found, check if cache is complete in that direction
    local cursorSourceTime = NW.TimeUtils.crossProjectTimeToSourceTime(context.cursorProject, cursorProjectTime, context.videoItem, context.videoProject)
    if not cursorSourceTime then
        reaper.ShowMessageBox("Cursor is not within video item bounds", "Error", 0)
        clearJumpRequest()
        return
    end

    if cacheExtendsToEnd(cache, cursorSourceTime, direction, context.sourceLengthSeconds) then
        -- Cache is complete, no cut exists - jump to end/start of video
        jumpToVideoBoundary(direction, "No cut found (cache complete)")
        clearJumpRequest()
        return
    end

    -- Cache incomplete, start searching
    NW.log("Processor", "Cache incomplete, starting search")
    state.searchingForJumpRequest = true
    state.searchState = {
        direction = direction,
        searchedDistance = 0,
        maxDistance = MAX_SEARCH_DISTANCE
    }

    -- Queue first search chunk
    local chunkStart, chunkEnd
    if direction == "next" then
        chunkStart = cursorSourceTime
        chunkEnd = math.min(chunkStart + NAVIGATION_SEARCH_CHUNK_SIZE, context.sourceLengthSeconds)
    else -- previous
        chunkEnd = cursorSourceTime
        chunkStart = math.max(0, chunkEnd - NAVIGATION_SEARCH_CHUNK_SIZE)
    end

    -- For "next" direction, use firstCutCallback for immediate jumping
    local jobSpec = {
        videoPath = context.videoPath,
        videoItem = context.videoItem,
        project = context.videoProject,
        fps = context.fps,
        startSourceTime = chunkStart,
        endSourceTime = chunkEnd,
        threshold = SCENE_THRESHOLD,
        downscaleWidth = DOWNSCALE_WIDTH,
        priority = "high",
        callback = handleSearchResult
    }

    -- Add firstCutCallback for "next" direction to enable immediate jumping
    if direction == "next" then
        jobSpec.firstCutCallback = handleFirstCutFound
    end

    VideoCutScanner.addJob(jobSpec)
end

---Phase 3: Queue background fill if no active jobs
local function queueBackgroundFill()
    local state = _G.NW_VideoCutState

    if not state.currentVideo then
        return
    end

    -- Load cache
    local cache = VideoCutCache.load(state.currentVideo.videoProject, state.currentVideo.videoPath)
    if not cache then
        return
    end

    -- Get cursor position
    -- GetCursorPosition returns position in the active project (which is cursorProject)
    local cursorProjectTime = NW.TimeUtils.getCursorPositionInProjectTime()
    local cursorSourceTime = NW.TimeUtils.crossProjectTimeToSourceTime(
        state.currentVideo.cursorProject,
        cursorProjectTime,
        state.currentVideo.videoItem,
        state.currentVideo.videoProject
    )
    if not cursorSourceTime then
        return
    end

    -- Find all gaps in cache
    local allGaps = VideoCutCache.findAllGaps(cache, state.currentVideo.sourceLengthSeconds)

    -- Filter gaps to processing window if enabled
    local eligibleGaps = allGaps
    if ENABLE_PROCESSING_WINDOW then
        eligibleGaps = filterGapsToWindow(
            allGaps,
            cursorSourceTime,
            PROCESSING_WINDOW_SIZE,
            state.currentVideo.sourceLengthSeconds,
            state.currentVideo.fps
        )
        NW.log("Processor", string.format("Processing window: filtered %d total gaps to %d gaps within window",
            #allGaps, #eligibleGaps))
    end

    -- Select nearest gap from eligible gaps
    local uncachedRange = VideoCutCache.selectNearestGap(
        eligibleGaps,
        cursorSourceTime,
        BACKGROUND_FILL_CHUNK_SIZE
    )

    if uncachedRange then
        NW.log("Processor", string.format("Queueing background fill: %.1f-%.1fs", uncachedRange[1], uncachedRange[2]))
        VideoCutScanner.addJob({
            videoPath = state.currentVideo.videoPath,
            videoItem = state.currentVideo.videoItem,
            project = state.currentVideo.videoProject,
            fps = state.currentVideo.fps,
            startSourceTime = uncachedRange[1],
            endSourceTime = uncachedRange[2],
            threshold = SCENE_THRESHOLD,
            downscaleWidth = DOWNSCALE_WIDTH,
            priority = "low",
            callback = nil  -- No callback for background fill
        })
    else
        if ENABLE_PROCESSING_WINDOW then
            NW.log("Processor", "No gaps within processing window (window fully cached)")
        else
            NW.log("Processor", "No gaps found (video fully cached)")
        end
    end
end

---Shutdown the background processor and clear all state
local function shutdownProcessor()
    local state = _G.NW_VideoCutState
    NW.log("Processor", "Background processor shutting down")

    state.processorActive = false
    state.currentVideo = nil

    -- Clear ExtState flags so new processor can start
    reaper.SetExtState("NW_VideoCut", "processorActive", "false", false)
    reaper.SetExtState("NW_VideoCut", "lastHeartbeat", "", false)
end

---Phase 4: Decide whether to keep running
---@return boolean shouldContinue True if processor should keep running
local function shouldKeepRunning()
    local state = _G.NW_VideoCutState

    -- Keep running if there's a pending jump request
    if state.pendingJumpRequest then
        return true
    end

    -- Keep running if scanner has jobs
    if VideoCutScanner.hasActiveJobs() then
        return true
    end

    -- Nothing left to do
    return false
end

---Main background loop
local function backgroundLoop()
    local state = _G.NW_VideoCutState

    -- Check if ffmpeg is unavailable - if so, shut down immediately
    if state.ffmpegUnavailable then
        NW.log("Processor", "ffmpeg unavailable")
        shutdownProcessor()
        return
    end

    -- Validate that stored projects are still open (if we have stored context)
    if state.currentVideo then
        if not areProjectsStillValid(state.currentVideo.videoProject, state.currentVideo.cursorProject) then
            NW.log("Processor", "One or more projects were closed")

            -- If user is waiting for a jump, show error
            if state.pendingJumpRequest then
                reaper.ShowMessageBox("Project was closed while processing video cuts", "Error", 0)
                clearJumpRequest()
            end

            shutdownProcessor()
            return
        end
    end

    -- Update loop counter and heartbeat
    state.loopCounter = state.loopCounter + 1
    if state.loopCounter % HEARTBEAT_UPDATE_INTERVAL == 0 then
        reaper.SetExtState("NW_VideoCut", "lastHeartbeat", tostring(reaper.time_precise()), false)
    end

    -- Check for new jump requests from ExtState
    checkForNewJumpRequests()

    NW.log("Processor", "=== Background Loop Iteration ===")
    NW.log("Processor", string.format("State: processorActive=%s, pendingJumpRequest=%s, searchingForJumpRequest=%s",
        tostring(state.processorActive),
        state.pendingJumpRequest and string.format("(direction=%s)", state.pendingJumpRequest.direction) or "nil",
        tostring(state.searchingForJumpRequest)))
    NW.log("Processor", string.format("State: currentVideo=%s, searchState=%s",
        state.currentVideo and "set" or "nil",
        state.searchState and string.format("(direction=%s, distance=%.1f)", state.searchState.direction, state.searchState.searchedDistance) or "nil"))

    -- Phase 1: Handle pending jump request
    if state.pendingJumpRequest and not state.searchingForJumpRequest then
        NW.log("Processor", "Phase 1: Processing jump request")
        processJumpRequest()
    else
        NW.log("Processor", string.format("Phase 1: Skipping (pendingJumpRequest=%s, searchingForJumpRequest=%s)",
            tostring(state.pendingJumpRequest ~= nil),
            tostring(state.searchingForJumpRequest)))
    end

    -- Phase 2: Process active scan jobs
    NW.log("Processor", "Phase 2: Processing scanner jobs")
    VideoCutScanner.process()

    -- Phase 3: Queue background fill (only if no active jobs)
    local hasJobs = VideoCutScanner.hasActiveJobs()
    NW.log("Processor", string.format("Phase 3: hasActiveJobs=%s", tostring(hasJobs)))
    if not hasJobs then
        NW.log("Processor", "Phase 3: Queueing background fill")
        queueBackgroundFill()
    else
        NW.log("Processor", "Phase 3: Skipping background fill (jobs active)")
    end

    -- Phase 4: Decide whether to continue
    local keepRunning = shouldKeepRunning()
    NW.log("Processor", string.format("Phase 4: shouldKeepRunning=%s", tostring(keepRunning)))
    if keepRunning then
        reaper.defer(backgroundLoop)
    else
        shutdownProcessor()
    end
end

---Main entry point
local function main()
    NW.log("Processor", "main() called")

    -- Check if processor is already running via ExtState
    local processorActive = reaper.GetExtState("NW_VideoCut", "processorActive")
    if processorActive == "true" then
        NW.log("Processor", "Background processor already running (ExtState check)")
        return
    end

    initGlobalState()

    local state = _G.NW_VideoCutState

    NW.log("Processor", string.format("After initGlobalState: pendingJumpRequest=%s",
        state.pendingJumpRequest and string.format("(direction=%s)", state.pendingJumpRequest.direction) or "nil"))

    NW.log("Processor", "Starting background processor")
    state.processorActive = true
    reaper.SetExtState("NW_VideoCut", "processorActive", "true", false)
    reaper.SetExtState("NW_VideoCut", "lastHeartbeat", tostring(reaper.time_precise()), false)

    -- Start the loop
    reaper.defer(backgroundLoop)
end

-- Execute
main()
