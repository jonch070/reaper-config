-- Set project frame rate from video.lua
-- Detects video frame rate and updates REAPER project settings to match
-- Author: Nate Weiner (https://nateweiner.com)

-- Bootstrap NW environment
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
local sharedPath = scriptPath:match("^(.+)[/\\][^/\\]+$") .. "/Shared/"
package.path = package.path .. ";" .. sharedPath .. "?.lua"

require("NWInit")({
    debug = false,
    requires = { "SWS", "FFmpeg" },
    libs = { "VideoSelection", "FFmpegLib" },
    undo = "Set project frame rate from video",
})
if not NW then return end

-- Frame rate mapping: detected FPS -> {projfrbase, projfrdrop}
-- projfrdrop: 0 = integer, 1 = 29.97 drop-frame, 2 = non-integer variant
local FRAME_RATE_MAP = {
    -- 24 fps variants
    { fps = 23.976, base = 24, drop = 2, label = "23.976 fps" },
    { fps = 24.0,   base = 24, drop = 0, label = "24 fps" },
    -- 25 fps (PAL)
    { fps = 25.0,   base = 25, drop = 0, label = "25 fps" },
    -- 30 fps variants
    { fps = 29.97,  base = 30, drop = 2, label = "29.97 fps (non-drop)" },
    { fps = 30.0,   base = 30, drop = 0, label = "30 fps" },
    -- 50 fps (PAL high frame rate)
    { fps = 50.0,   base = 50, drop = 0, label = "50 fps" },
    -- 60 fps variants
    { fps = 59.94,  base = 60, drop = 2, label = "59.94 fps" },
    { fps = 60.0,   base = 60, drop = 0, label = "60 fps" },
}

---Find the closest matching frame rate entry
---@param detectedFps number
---@return table|nil Entry from FRAME_RATE_MAP, or nil if no close match
local function findMatchingFrameRate(detectedFps)
    local tolerance = 0.05
    local bestMatch = nil
    local bestDiff = tolerance

    NW.log(string.format("Finding closest match for detected FPS: %.6f", detectedFps))

    for _, entry in ipairs(FRAME_RATE_MAP) do
        local diff = math.abs(detectedFps - entry.fps)
        local isBetter = diff < bestDiff
        NW.log(string.format("  Comparing to %s (%.3f): diff=%.6f, better=%s",
            entry.label, entry.fps, diff, tostring(isBetter)))
        if isBetter then
            bestDiff = diff
            bestMatch = entry
        end
    end

    if bestMatch then
        NW.log(string.format("  -> Best match: %s (diff=%.6f)", bestMatch.label, bestDiff))
    else
        NW.log("  -> No match within tolerance")
    end

    return bestMatch
end

---Get current project frame rate
---@return number fps Current project frame rate
local function getCurrentProjectFps()
    local fps, _ = reaper.TimeMap_curFrameRate(0)
    return fps
end

---Set project frame rate using SWS functions
---@param base number projfrbase value
---@param drop number projfrdrop value
---@return boolean success
local function setProjectFrameRate(base, drop)
    reaper.SNM_SetIntConfigVar("projfrbase", base)
    reaper.SNM_SetIntConfigVar("projfrdrop", drop)
    reaper.MarkProjectDirty(0)
    return true
end

---Format FPS for display
---@param fps number
---@return string
local function formatFps(fps)
    if fps == math.floor(fps) then
        return string.format("%d", fps)
    else
        return string.format("%.3f", fps)
    end
end

---Main entry point
local function main()
    -- Find video item
    local videoItem, videoPath, _, selectionMethod = NW.VideoSelection.getVideoItem()

    if not videoItem or not videoPath then
        return
    end

    NW.log("Video path: " .. videoPath)
    NW.log("Selection method: " .. (selectionMethod or "unknown"))

    -- Get video FPS
    local detectedFps, fpsError = NW.FFmpegLib.getVideoFPS(videoPath)
    NW.log(string.format("FFmpegLib.getVideoFPS returned: fps=%s, error=%s",
        detectedFps and string.format("%.6f", detectedFps) or "nil",
        fpsError or "nil"))
    if not detectedFps then
        reaper.ShowMessageBox(
            "Could not detect video frame rate.\n\n" .. (fpsError or "Unknown error"),
            "Detection Failed",
            0
        )
        return
    end

    -- Find matching frame rate
    local frameRateEntry = findMatchingFrameRate(detectedFps)
    if not frameRateEntry then
        reaper.ShowMessageBox(
            string.format(
                "Detected frame rate (%.3f fps) is not a standard video frame rate.\n\n" ..
                "Supported rates: 23.976, 24, 25, 29.97, 30, 50, 59.94, 60 fps",
                detectedFps
            ),
            "Unsupported Frame Rate",
            0
        )
        return
    end

    -- Check if already matching
    local currentFps = getCurrentProjectFps()
    if math.abs(currentFps - frameRateEntry.fps) < 0.01 then
        return
    end

    -- Set the frame rate
    local success = setProjectFrameRate(frameRateEntry.base, frameRateEntry.drop)
    if not success then
        reaper.ShowMessageBox("Failed to set project frame rate.", "Error", 0)
        return
    end

    -- Get the video filename for the message
    local videoFilename = videoPath:match("([^/\\]+)$") or "video"

    reaper.ShowMessageBox(
        string.format(
            "Project frame rate updated to %s\n\n" ..
            "Video: %s\n" ..
            "Previous: %s fps",
            frameRateEntry.label,
            videoFilename,
            formatFps(currentFps)
        ),
        "Frame Rate Updated",
        0
    )
end

NW.run(main)
