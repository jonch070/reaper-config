-- VideoCutScanner.lua - Job queue and scanner for video cut detection
-- Manages ffmpeg scene detection jobs with callbacks
-- Author: Nate Weiner (https://nateweiner.com)

local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")

-- Normalize path separators for cross-platform compatibility
local isWindows = reaper.GetOS():match("Win") ~= nil
if isWindows then
    scriptPath = scriptPath:gsub("/", "\\")
end

-- Use patterns that work on both platforms
local scriptDir = scriptPath:match("^(.+)[/\\][^/\\]+$")
local parentDir = scriptDir:match("^(.+)[/\\][^/\\]+$")
package.path = package.path .. ";" .. parentDir .. "/?.lua"
package.path = package.path .. ";" .. parentDir .. "/ffmpeg/?.lua"

local FFmpegUtils = require("FFmpegUtils")
local VideoCutCache = require("VideoCutCache")

local VideoCutScanner = {}

-- Module state
local activeJob = nil
local jobQueue = {}

---Add a job to the scanner queue
---@param jobSpec table Job specification with fields:
---  - videoPath: string - Path to video file
---  - videoItem: MediaItem - Video item for context
---  - project: ReaProject - Project for cache storage
---  - fps: number - Video FPS
---  - startSourceTime: number - Start of range to scan (SourceTime)
---  - endSourceTime: number - End of range to scan (SourceTime)
---  - threshold: number - Scene detection threshold
---  - downscaleWidth: number - Downscale width for performance
---  - priority: string - "high" or "low" (high = navigation, low = background fill)
---  - firstCutCallback: function|nil - Optional callback(firstCuts) called when first cut(s) found (for "next" direction optimization)
---  - callback: function|nil - Optional callback(allCuts) when job completes
function VideoCutScanner.addJob(jobSpec)
    -- Validate required fields
    if not jobSpec.videoPath or not jobSpec.videoItem or not jobSpec.project or
       not jobSpec.fps or not jobSpec.startSourceTime or not jobSpec.endSourceTime or
       not jobSpec.threshold or not jobSpec.downscaleWidth then
        NW.log("Scanner","ERROR: Invalid job spec - missing required fields")
        return
    end

    local priority = jobSpec.priority or "low"

    NW.log("Scanner",string.format("Adding %s priority job: %.1f-%.1fs source time",
        priority, jobSpec.startSourceTime, jobSpec.endSourceTime))

    -- If this is a high priority job and there are active/queued jobs, cancel them
    -- This allows navigation requests to preempt background fill jobs
    if priority == "high" and (activeJob ~= nil or #jobQueue > 0) then
        VideoCutScanner.cancelAllNonPriorityJobs()
    end

    -- Create job entry
    local job = {
        videoPath = jobSpec.videoPath,
        videoItem = jobSpec.videoItem,
        project = jobSpec.project,
        fps = jobSpec.fps,
        startSourceTime = jobSpec.startSourceTime,
        endSourceTime = jobSpec.endSourceTime,
        threshold = jobSpec.threshold,
        downscaleWidth = jobSpec.downscaleWidth,
        priority = priority,
        firstCutCallback = jobSpec.firstCutCallback,
        callback = jobSpec.callback,
        lastReadPosition = 0,
        cutsFoundSoFar = {},
        firstCutCallbackFired = false
    }

    -- Add to queue based on priority
    if priority == "high" then
        -- High priority jobs go to front
        table.insert(jobQueue, 1, job)
    else
        -- Low priority jobs go to back
        table.insert(jobQueue, job)
    end

    NW.log("Scanner",string.format("Queue size: %d jobs (%d active)", #jobQueue, activeJob and 1 or 0))
end

---Start processing a job
---@param job table Job to process
local function startJob(job)
    NW.log("Scanner",string.format("Starting job: %.1f-%.1fs source time",
        job.startSourceTime, job.endSourceTime))

    local durationSeconds = job.endSourceTime - job.startSourceTime
    local jobInfo, errorMsg = FFmpegUtils.startSceneDetection(
        job.videoPath,
        job.startSourceTime,
        durationSeconds,
        job.threshold,
        job.downscaleWidth
    )

    if not jobInfo then
        NW.log("Scanner","ERROR: Failed to start scene detection")

        -- Set global flag to prevent further processing attempts
        if _G.NW_VideoCutState then
            _G.NW_VideoCutState.ffmpegUnavailable = true
            NW.log("Scanner","Setting ffmpegUnavailable flag to prevent further processing")
        end

        -- Call callback with error (use specific error message if available)
        if job.callback then
            job.callback(nil, errorMsg or "Failed to start ffmpeg")
        end
        return false
    end

    -- Save job info for status checking
    job.outputFile = jobInfo.outputFile
    job.statusFile = jobInfo.statusFile
    job.pidFile = jobInfo.pidFile
    job.startTime = reaper.time_precise()

    activeJob = job
    return true
end

---Try to parse new cuts from output file incrementally
---@param job table Active job to parse
---@return table|nil Array of new cuts found (absolute SourceTime), or nil if no new data
local function tryIncrementalParse(job)
    if not job.outputFile then
        return nil
    end

    -- Try to open output file
    local file = io.open(job.outputFile, "r")
    if not file then
        -- File doesn't exist yet
        return nil
    end

    -- Seek to last read position
    file:seek("set", job.lastReadPosition)

    -- Read any new content
    local newContent = file:read("*a")

    -- Update last read position
    job.lastReadPosition = file:seek()
    file:close()

    if not newContent or newContent == "" then
        -- No new data
        return nil
    end

    -- Parse timestamps from new content
    local newTimestamps = {}
    for line in newContent:gmatch("[^\r\n]+") do
        local time = line:match("pts_time:([%d%.]+)")
        if time then
            -- Quantize to frame boundary (relative to range start)
            local relativeTime = tonumber(time)
            if relativeTime then
                local quantized = FFmpegUtils.quantizeSecondsToFrame(relativeTime, job.fps)
                -- Convert to absolute SourceTime
                local absoluteSourceTime = job.startSourceTime + quantized
                table.insert(newTimestamps, absoluteSourceTime)
            end
        end
    end

    if #newTimestamps > 0 then
        NW.log("Scanner",string.format("Incrementally parsed %d new cut(s)", #newTimestamps))
    end

    return newTimestamps
end

---Check status of active job and process results if complete
---@return boolean jobStillActive True if job is still processing
local function checkActiveJob()
    if not activeJob then
        return false
    end

    NW.log("Scanner","=== checkActiveJob ===")
    NW.log("Scanner",string.format("Job files: output='%s'", activeJob.outputFile or "nil"))
    NW.log("Scanner",string.format("           status='%s'", activeJob.statusFile or "nil"))
    NW.log("Scanner",string.format("           pid='%s'", activeJob.pidFile or "nil"))

    -- Try incremental parsing (works even while job is still processing)
    local newCuts = tryIncrementalParse(activeJob)
    if newCuts and #newCuts > 0 then
        -- Add to accumulated cuts
        for _, cut in ipairs(newCuts) do
            table.insert(activeJob.cutsFoundSoFar, cut)
        end

        -- Update cache immediately with new cuts
        local cache = VideoCutCache.load(activeJob.project, activeJob.videoPath)
        if cache then
            -- Extend processed range up to the last cut found
            local lastCutTime = newCuts[#newCuts]
            local quantizedStart = FFmpegUtils.quantizeSecondsToFrame(activeJob.startSourceTime, activeJob.fps)
            local quantizedEnd = FFmpegUtils.quantizeSecondsToFrame(lastCutTime, activeJob.fps)

            VideoCutCache.addCuts(cache, newCuts, quantizedStart, quantizedEnd)
            VideoCutCache.save(activeJob.project, activeJob.videoPath, cache)
            NW.log("Scanner",string.format("Updated cache with %d cut(s), range now %.1f-%.1fs",
                #newCuts, quantizedStart, quantizedEnd))
        end

        -- Fire firstCutCallback if present and not already fired
        if activeJob.firstCutCallback and not activeJob.firstCutCallbackFired then
            activeJob.firstCutCallbackFired = true
            NW.log("Scanner","Firing firstCutCallback with initial cuts")
            activeJob.firstCutCallback(newCuts)
        end
    end

    -- Check status file
    NW.log("Scanner","Checking status file: " .. (activeJob.statusFile or "nil"))
    local statusF = io.open(activeJob.statusFile, "r")
    if not statusF then
        -- Status file doesn't exist yet, still starting up
        NW.log("Scanner","Status file does not exist yet (job still starting)")
        return true
    end

    local statusRaw = statusF:read("*a")
    local status = statusRaw:match("^%s*(.-)%s*$")
    statusF:close()
    NW.log("Scanner",string.format("Status file content: raw='%s', trimmed='%s'", statusRaw or "nil", status or "nil"))

    if status == "processing" then
        -- Still running
        NW.log("Scanner","Job status: processing")
        return true
    elseif status == "error" then
        -- ffmpeg failed
        NW.log("Scanner","ERROR: ffmpeg failed for job (status file says 'error')")

        -- Try to read the output file for error details
        local errorFile = io.open(activeJob.outputFile, "r")
        if errorFile then
            local errorContent = errorFile:read("*a")
            errorFile:close()
            NW.log("Scanner","Output file content (may contain ffmpeg error):")
            NW.log("Scanner",errorContent:sub(1, 1000))  -- First 1000 chars
        end

        -- Clean up
        pcall(os.remove, activeJob.outputFile)
        pcall(os.remove, activeJob.statusFile)
        pcall(os.remove, activeJob.pidFile)

        -- Call callback with error
        if activeJob.callback then
            activeJob.callback(nil, "ffmpeg error")
        end

        activeJob = nil
        return false
    elseif status == "done" then
        NW.log("Scanner","Job status: done")
        -- Job complete, process any remaining results
        local elapsed = reaper.time_precise() - activeJob.startTime
        NW.log("Scanner",string.format("Job complete in %.1fs", elapsed))

        -- Try one more incremental parse to get any final cuts
        local finalNewCuts = tryIncrementalParse(activeJob)
        if finalNewCuts and #finalNewCuts > 0 then
            for _, cut in ipairs(finalNewCuts) do
                table.insert(activeJob.cutsFoundSoFar, cut)
            end
        end

        -- All cuts found = accumulated cuts during processing
        local allCuts = activeJob.cutsFoundSoFar

        -- Update cache with final complete range
        local cache = VideoCutCache.load(activeJob.project, activeJob.videoPath)
        if cache then
            -- Mark the FULL requested range as processed
            local quantizedStart = FFmpegUtils.quantizeSecondsToFrame(activeJob.startSourceTime, activeJob.fps)
            local quantizedEnd = FFmpegUtils.quantizeSecondsToFrame(activeJob.endSourceTime, activeJob.fps)

            -- Add all cuts (some may already be in cache from incremental updates, addCuts handles duplicates)
            VideoCutCache.addCuts(cache, allCuts, quantizedStart, quantizedEnd)
            VideoCutCache.save(activeJob.project, activeJob.videoPath, cache)
            NW.log("Scanner",string.format("Job complete: %d total cuts in range %.1f-%.1fs",
                #allCuts, quantizedStart, quantizedEnd))
        end

        -- Call main callback with all results
        if activeJob.callback then
            activeJob.callback(allCuts)
        end

        -- Clean up
        pcall(os.remove, activeJob.outputFile)
        pcall(os.remove, activeJob.statusFile)
        pcall(os.remove, activeJob.pidFile)

        activeJob = nil
        return false
    end

    return true
end

---Process active job and queue
---Should be called regularly from background loop
function VideoCutScanner.process()
    -- Check active job
    if activeJob then
        local stillActive = checkActiveJob()
        if stillActive then
            -- Job still running, nothing more to do
            return
        end
        -- Job finished, fall through to start next job
    end

    -- Start next job from queue
    if #jobQueue > 0 then
        local nextJob = table.remove(jobQueue, 1)
        startJob(nextJob)
    end
end

---Check if scanner has active jobs or queued jobs
---@return boolean hasJobs True if there are jobs to process
function VideoCutScanner.hasActiveJobs()
    return activeJob ~= nil or #jobQueue > 0
end

---Kill a single job and clean up its files
---@param job table Job to kill
local function killJob(job)
    if not job then
        return
    end

    NW.log("Scanner",string.format("Killing %s priority job: %.1f-%.1fs",
        job.priority, job.startSourceTime, job.endSourceTime))

    -- Kill the ffmpeg process
    if job.pidFile then
        FFmpegUtils.killProcess(job.pidFile)
    end

    -- Clean up temp files
    pcall(os.remove, job.outputFile)
    pcall(os.remove, job.statusFile)
    pcall(os.remove, job.pidFile)
end

---Cancel all jobs and clean up
function VideoCutScanner.cancelAll()
    NW.log("Scanner","Canceling all jobs")

    -- Kill active job
    if activeJob then
        killJob(activeJob)
        activeJob = nil
    end

    -- Clear queue
    jobQueue = {}

    NW.log("Scanner","All jobs canceled")
end

---Cancel all non-priority jobs to make way for a priority job
---This kills any active background fill jobs and clears low-priority queued jobs
---Used when a high-priority navigation request needs immediate processing
function VideoCutScanner.cancelAllNonPriorityJobs()
    NW.log("Scanner","Canceling all non-priority jobs for priority request")

    -- Kill active job only if it's low priority
    -- Don't kill high-priority jobs (they might be in the middle of completion)
    if activeJob and activeJob.priority == "low" then
        killJob(activeJob)
        activeJob = nil
        NW.log("Scanner","Killed active low-priority job")
    elseif activeJob then
        NW.log("Scanner",string.format("Active job is high priority, not killing (priority=%s)", activeJob.priority))
    end

    -- Clear only low-priority queued jobs, keep high-priority ones
    local canceledCount = 0
    local newQueue = {}
    for _, job in ipairs(jobQueue) do
        if job.priority == "high" then
            table.insert(newQueue, job)
        else
            canceledCount = canceledCount + 1
        end
    end
    jobQueue = newQueue

    NW.log("Scanner",string.format("Canceled %d low-priority queued job(s), kept %d high-priority", canceledCount, #newQueue))
end

return VideoCutScanner
