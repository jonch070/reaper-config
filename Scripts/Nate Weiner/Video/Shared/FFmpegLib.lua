-- FFmpegLib.lua - FFmpeg/FFprobe discovery and video utilities
-- Author: Nate Weiner (https://nateweiner.com)

---@class FFmpegLib
local FFmpegLib = {}

-- ============================================================================
-- EXECUTABLE DISCOVERY
-- ============================================================================

---Find an executable by name across common installation paths
---@param execName string Name of executable (e.g., "ffmpeg", "ffprobe")
---@return string|nil path Path to executable or nil if not found
local function findExecutable(execName)
    local osName = reaper.GetOS()
    local isWindows = osName:match("Win") ~= nil

    NW.log("FFmpegLib", string.format("Finding executable '%s' on OS: %s (isWindows=%s)", execName, osName, tostring(isWindows)))

    local possiblePaths
    local whichCmd

    if isWindows then
        local exeName = execName .. ".exe"
        local localAppData = os.getenv("LOCALAPPDATA") or ""
        local userProfile = os.getenv("USERPROFILE") or ""
        NW.log("FFmpegLib", string.format("Windows env vars: LOCALAPPDATA='%s', USERPROFILE='%s'", localAppData, userProfile))

        possiblePaths = {
            "C:\\Program Files\\ffmpeg\\bin\\" .. exeName,
            "C:\\Program Files (x86)\\ffmpeg\\bin\\" .. exeName,
            "C:\\ProgramData\\chocolatey\\bin\\" .. exeName,
            localAppData .. "\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg\\bin\\" .. exeName,
            userProfile .. "\\scoop\\apps\\ffmpeg\\current\\bin\\" .. exeName,
        }
        whichCmd = "where " .. execName .. " 2>NUL"
    else
        possiblePaths = {
            "/usr/local/bin/" .. execName,
            "/opt/homebrew/bin/" .. execName,
            "/usr/bin/" .. execName,
        }
        whichCmd = "which " .. execName .. " 2>/dev/null"
    end

    -- Check common paths first
    for _, path in ipairs(possiblePaths) do
        NW.log("FFmpegLib", "Checking path: " .. path)
        local testFile = io.open(path, "r")
        if testFile then
            testFile:close()
            NW.log("FFmpegLib", "FOUND at: " .. path)
            return path
        end
    end

    -- Fall back to system path search
    NW.log("FFmpegLib", "Running system search command: " .. whichCmd)
    local handle = io.popen(whichCmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        result = result:match("^%s*(.-)%s*$")
        NW.log("FFmpegLib", "System search result: '" .. (result or "nil") .. "'")
        if result and result ~= "" then
            return result
        end
    else
        NW.log("FFmpegLib", "Failed to run system search command")
    end

    NW.log("FFmpegLib", "Executable NOT FOUND: " .. execName)
    return nil
end

---Find ffmpeg executable path
---@return string|nil path Path to ffmpeg or nil if not found
function FFmpegLib.findFfmpeg()
    return findExecutable("ffmpeg")
end

---Find ffprobe executable path
---@return string|nil path Path to ffprobe or nil if not found
function FFmpegLib.findFfprobe()
    return findExecutable("ffprobe")
end

---Check if ffmpeg/ffprobe is installed
---@return boolean installed True if ffprobe is available
function FFmpegLib.isInstalled()
    return FFmpegLib.findFfprobe() ~= nil
end

---Show a user-friendly error message when ffmpeg is not installed
---@param featureName string|nil Optional name of feature requiring ffmpeg (e.g., "Video FPS detection")
function FFmpegLib.showNotInstalledError(featureName)
    local feature = featureName and (featureName .. " requires") or "This feature requires"
    local osName = reaper.GetOS()
    local installHint

    if osName:match("Win") then
        installHint = "Install via:\n  - winget install ffmpeg\n  - choco install ffmpeg\n  - scoop install ffmpeg"
    elseif osName:match("OSX") or osName:match("macOS") then
        installHint = "Install via:\n  - brew install ffmpeg"
    else
        installHint = "Install via your package manager:\n  - apt install ffmpeg\n  - dnf install ffmpeg"
    end

    local msg = string.format(
        "%s ffmpeg, which is not installed.\n\n%s\n\nAfter installing, restart REAPER.",
        feature,
        installHint
    )

    reaper.ShowMessageBox(msg, "FFmpeg Required", 0)
end

-- ============================================================================
-- VIDEO PROPERTIES
-- ============================================================================

---Get video frame rate using ffprobe
---@param videoPath string Path to video file
---@return number|nil fps FPS as decimal (e.g., 29.97, 30, 24), or nil on error
---@return string|nil errorMsg Error message if failed
function FFmpegLib.getVideoFPS(videoPath)
    local ffprobePath = FFmpegLib.findFfprobe()
    if not ffprobePath then
        return nil, "ffmpeg/ffprobe is not installed"
    end

    local osName = reaper.GetOS()
    local isWindows = osName:match("Win") ~= nil
    local nullDevice = isWindows and "NUL" or "/dev/null"

    local cmd = string.format(
        '"%s" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "%s" 2>%s',
        ffprobePath,
        videoPath,
        nullDevice
    )

    NW.log("FFmpegLib", "Running ffprobe command: " .. cmd)

    local handle = io.popen(cmd)
    if not handle then
        return nil, "Could not run ffprobe"
    end

    local result = handle:read("*a")
    handle:close()
    result = result:match("^%s*(.-)%s*$")

    NW.log("FFmpegLib", "Raw ffprobe output: '" .. (result or "nil") .. "'")

    if not result or result == "" then
        return nil, "No output from ffprobe - file may not be a valid video"
    end

    -- Parse fraction (e.g., "30000/1001" for 29.97 or "30/1" for 30)
    local num, denom = result:match("(%d+)/(%d+)")
    if num and denom then
        local fps = tonumber(num) / tonumber(denom)
        NW.log("FFmpegLib", string.format("Parsed fraction: %s/%s = %.6f fps", num, denom, fps))
        return fps
    end

    return nil, "Could not parse frame rate: " .. result
end

return FFmpegLib
