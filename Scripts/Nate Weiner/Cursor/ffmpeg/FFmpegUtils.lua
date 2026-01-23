-- FFmpegUtils.lua - Scene detection utilities for Cursor to Cut
-- Author: Nate Weiner (https://nateweiner.com)

local currentScriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")

-- Normalize path separators for cross-platform compatibility
local isWindows = reaper.GetOS():match("Win") ~= nil
if isWindows then
    currentScriptPath = currentScriptPath:gsub("/", "\\")
end

-- Use patterns that work on both platforms
local currentScriptDir = currentScriptPath:match("^(.+)[/\\][^/\\]+$")
local parentDir = currentScriptDir:match("^(.+)[/\\][^/\\]+$")
package.path = package.path .. ";" .. parentDir .. "/?.lua"

-- FFmpegLib is loaded by entry script's NWInit({ libs = [...] })

local FFmpegUtils = {}

-- ============================================================================
-- FRAME-PRECISION UTILITIES
-- ============================================================================

---Quantize seconds to nearest frame boundary
---@param seconds number Time in seconds
---@param fps number Frames per second
---@return number quantized Quantized time in seconds
function FFmpegUtils.quantizeSecondsToFrame(seconds, fps)
    local frameLength = 1 / fps
    return math.floor(seconds / frameLength + 0.5) * frameLength
end

---Calculate frame-based epsilon for floating-point comparisons
---Returns slightly less than one frame length (99%) to ensure times must differ
---by at least one full frame to be considered different
---@param fps number Frames per second
---@return number epsilon Epsilon value in seconds
function FFmpegUtils.getFrameEpsilon(fps)
    return (1 / fps) * 0.99
end

---Check if time A is greater than time B (accounting for frame precision)
---Returns true only if A is at least one frame ahead of B
---@param timeA number Time A in seconds
---@param timeB number Time B in seconds
---@param fps number Video frames per second
---@return boolean result True if A > B by at least one frame
function FFmpegUtils.isTimeGreaterThan(timeA, timeB, fps)
    local epsilon = FFmpegUtils.getFrameEpsilon(fps)
    return timeA > timeB + epsilon
end

---Check if time A is less than time B (accounting for frame precision)
---Returns true only if A is at least one frame before B
---@param timeA number Time A in seconds
---@param timeB number Time B in seconds
---@param fps number Video frames per second
---@return boolean result True if A < B by at least one frame
function FFmpegUtils.isTimeLessThan(timeA, timeB, fps)
    local epsilon = FFmpegUtils.getFrameEpsilon(fps)
    return timeA < timeB - epsilon
end

---Check if two times are equal (accounting for frame precision)
---Returns true if times differ by less than one frame
---@param timeA number Time A in seconds
---@param timeB number Time B in seconds
---@param fps number Video frames per second
---@return boolean result True if times are within one frame of each other
function FFmpegUtils.isTimeEqual(timeA, timeB, fps)
    local epsilon = FFmpegUtils.getFrameEpsilon(fps)
    return math.abs(timeA - timeB) <= epsilon
end

-- ============================================================================
-- SCENE DETECTION
-- ============================================================================

---Start scene detection on a video range
---Launches platform-specific wrapper script in background, returns file paths for status tracking
---@param videoPath string Path to video file
---@param startSourceTime number Start position in video file (SourceTime)
---@param durationSeconds number Duration to process
---@param threshold number Scene detection threshold (e.g., 0.1)
---@param downscaleWidth number Downscale width (0 = disabled)
---@return table|nil jobInfo Job info {outputFile, statusFile, pidFile} or nil on error
---@return string|nil errorMsg Error message if ffmpeg not found
function FFmpegUtils.startSceneDetection(videoPath, startSourceTime, durationSeconds, threshold, downscaleWidth)
    NW.log("FFmpegUtils","=== startSceneDetection called ===")
    NW.log("FFmpegUtils",string.format("videoPath: %s", videoPath))
    NW.log("FFmpegUtils",string.format("startSourceTime: %f, durationSeconds: %f", startSourceTime, durationSeconds))
    NW.log("FFmpegUtils",string.format("threshold: %f, downscaleWidth: %d", threshold, downscaleWidth))

    local ffmpegPath = NW.FFmpegLib.findFfmpeg()
    if not ffmpegPath then
        local errorMsg = "ffmpeg is required but not installed.\n\nPlease install ffmpeg."
        NW.log("FFmpegUtils","ERROR: " .. errorMsg)
        return nil, errorMsg
    end
    NW.log("FFmpegUtils","ffmpegPath: " .. ffmpegPath)

    -- Log platform info (isWindows already set at module load)
    NW.log("FFmpegUtils",string.format("Platform: isWindows=%s", tostring(isWindows)))

    -- Get script directory (this is where FFmpegUtils.lua lives)
    local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
    NW.log("FFmpegUtils","FFmpegUtils scriptPath (raw): " .. (scriptPath or "nil"))

    -- On Windows, path separators from debug.getinfo might be forward slashes
    -- Normalize to backslashes for Windows path operations
    if isWindows then
        scriptPath = scriptPath:gsub("/", "\\")
        NW.log("FFmpegUtils","FFmpegUtils scriptPath (normalized for Windows): " .. scriptPath)
    end

    local scriptDir = scriptPath:match("^(.+)[/\\][^/\\]+$")
    NW.log("FFmpegUtils","scriptDir (wrapper script location): " .. (scriptDir or "nil"))

    -- Choose wrapper script based on platform
    local wrapperScript
    if isWindows then
        wrapperScript = scriptDir .. "\\scene_detect.bat"
    else
        wrapperScript = scriptDir .. "/scene_detect.sh"
    end
    NW.log("FFmpegUtils","wrapperScript: " .. wrapperScript)

    -- Verify wrapper script exists
    local wrapperCheck = io.open(wrapperScript, "r")
    if wrapperCheck then
        wrapperCheck:close()
        NW.log("FFmpegUtils","Wrapper script EXISTS")
    else
        NW.log("FFmpegUtils","ERROR: Wrapper script NOT FOUND at: " .. wrapperScript)
    end

    -- Create temp files (platform-specific temp directory)
    local tempDir
    if isWindows then
        tempDir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Windows\\Temp"
    else
        tempDir = os.getenv("TMPDIR") or "/tmp"
    end
    NW.log("FFmpegUtils","tempDir: " .. tempDir)

    local pathSep = isWindows and "\\" or "/"
    local outputFile = tempDir .. pathSep .. "reaper_scene_" .. os.time() .. "_" .. math.random(1000, 9999) .. ".txt"
    local statusFile = outputFile .. ".status"
    local pidFile = outputFile .. ".pid"
    NW.log("FFmpegUtils","outputFile: " .. outputFile)
    NW.log("FFmpegUtils","statusFile: " .. statusFile)
    NW.log("FFmpegUtils","pidFile: " .. pidFile)

    -- Build command based on platform
    local cmd
    if isWindows then
        -- Windows: use start /B to run in background without new window
        cmd = string.format(
            'start /B "" "%s" "%s" %f %f %f "%s" "%s" %d',
            wrapperScript,
            videoPath,
            startSourceTime,
            durationSeconds,
            threshold,
            outputFile,
            ffmpegPath,
            downscaleWidth
        )
    else
        -- macOS/Linux: use bash with & to run in background
        cmd = string.format(
            'bash "%s" "%s" %f %f %f "%s" "%s" %d &',
            wrapperScript,
            videoPath,
            startSourceTime,
            durationSeconds,
            threshold,
            outputFile,
            ffmpegPath,
            downscaleWidth
        )
    end

    NW.log("FFmpegUtils","=== EXECUTING COMMAND ===")
    NW.log("FFmpegUtils","cmd: " .. cmd)
    NW.log("FFmpegUtils",string.format("Starting scene detection: %.1f-%.1fs (duration: %.1fs)",
        startSourceTime, startSourceTime + durationSeconds, durationSeconds))

    local execResult = os.execute(cmd)
    NW.log("FFmpegUtils","os.execute returned: " .. tostring(execResult))

    NW.log("FFmpegUtils","Returning job info files")
    return {
        outputFile = outputFile,
        statusFile = statusFile,
        pidFile = pidFile
    }
end

---Parse timestamps from ffmpeg output file and quantize to frame boundaries
---Returns timestamps relative to the start of the processed range
---@param outputFile string Path to ffmpeg output file
---@param fps number Video FPS for quantization
---@return table|nil timestamps Array of quantized timestamps (relative to range start), or nil on error
function FFmpegUtils.parseSceneDetectionOutput(outputFile, fps)
    local timestamps = {}
    local file = io.open(outputFile, "r")
    if not file then
        NW.log("FFmpegUtils","ERROR: Could not open output file: " .. outputFile)
        return nil
    end

    for line in file:lines() do
        local time = line:match("pts_time:([%d%.]+)")
        if time then
            local timeNum = tonumber(time)
            if timeNum then
                local quantized = FFmpegUtils.quantizeSecondsToFrame(timeNum, fps)
                table.insert(timestamps, quantized)
            end
        end
    end
    file:close()

    NW.log("FFmpegUtils",string.format("Parsed %d timestamps from output", #timestamps))
    return timestamps
end

---Kill a running ffmpeg process
---@param pidFile string Path to PID file
function FFmpegUtils.killProcess(pidFile)
    NW.log("FFmpegUtils","killProcess called with pidFile: " .. (pidFile or "nil"))
    if not pidFile then
        NW.log("FFmpegUtils","pidFile is nil, returning")
        return
    end

    NW.log("FFmpegUtils","Attempting to open PID file: " .. pidFile)
    local pidF = io.open(pidFile, "r")
    if pidF then
        local pidRaw = pidF:read("*a")
        local pid = pidRaw:match("^%s*(.-)%s*$")
        pidF:close()
        NW.log("FFmpegUtils",string.format("Read PID from file: raw='%s', trimmed='%s'", pidRaw or "nil", pid or "nil"))

        if pid and pid ~= "" then
            NW.log("FFmpegUtils","Killing process " .. pid)

            -- Use platform-appropriate kill command (isWindows set at module load)
            local killCmd
            if isWindows then
                -- Windows: use taskkill with /T to kill process tree (batch script + ffmpeg)
                killCmd = 'taskkill /F /T /PID ' .. pid .. ' >nul 2>&1'
            else
                -- macOS/Linux: use kill
                killCmd = "kill " .. pid .. " 2>/dev/null"
            end
            NW.log("FFmpegUtils","Kill command: " .. killCmd)
            local killResult = os.execute(killCmd)
            NW.log("FFmpegUtils","Kill result: " .. tostring(killResult))
        else
            NW.log("FFmpegUtils","PID is empty or nil, not killing")
        end
    else
        NW.log("FFmpegUtils","Could not open PID file (may not exist yet or already deleted)")
    end
end

return FFmpegUtils
