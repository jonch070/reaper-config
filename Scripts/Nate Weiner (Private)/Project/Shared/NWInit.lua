-- NWInit.lua - Unified initialization for NW REAPER scripts
-- Author: Nate Weiner (https://nateweiner.com)
--
-- Sets up a global NW table that provides:
--   NW.log(msg) or NW.log(feature, msg) - Debug logging
--   NW.run(fn) - Wraps function in undo block
--   NW.scriptPath - Path to the entry-point script
--   NW.scriptDir - Directory containing the entry-point script
--   NW.isWindows() - Returns true if running on Windows
--   NW.requirePeerLib(name) - For shared libraries to load other shared libraries (see below)
--   NW.<LibName> - Loaded shared libraries (e.g., NW.FFmpegLib)
--
-- Usage:
--   require("NWInit")({
--       debug = false,                      -- Enable debug logging (default: false)
--       feature = "MyFeature",              -- Debug prefix (default: script filename)
--       requires = { "SWS", "FFmpeg" },     -- Dependency checks
--       libs = { "VideoSelection" },        -- Shared libraries to load
--       undo = "My action description",     -- Undo block text (nil = script handles its own)
--   })
--   if not NW then return end  -- Bail if dependency check failed
--
--   local function main()
--       NW.log("Doing something")
--       local item = NW.VideoSelection.getVideoItem()
--   end
--
--   NW.run(main)

-- Global NW declaration for Lua language server
---@type NWGlobal
NW = NW

---@class NWGlobal
---@field scriptPath string Path to the entry-point script
---@field scriptDir string Directory containing the entry-point script
---@field log fun(featureOrMsg: any, msg?: any) Debug logging function (accepts strings, tables, or any value)
---@field run fun(fn: function) Wrap function in undo block and execute
---@field isWindows fun(): boolean Returns true if running on Windows
---@field requirePeerLib fun(libName: string): any For shared libs that depend on other shared libs
-- Shared libraries (loaded via libs parameter or requirePeerLib)
---@field ReaperTracksAndFolders? ReaperTracksAndFolders Track finding and folder hierarchy utilities
---@field ReaperUtils? ReaperUtils Action lookup, subproject detection utilities
---@field ReaperItems? ReaperItems Media item utilities
---@field ReaperMarkers? ReaperMarkers Marker and region utilities
---@field TimeUtils? TimeUtils Time/timecode/position conversion utilities
---@field FileUtils? FileUtils File system utilities
---@field FFmpegLib? FFmpegLib FFmpeg/ffprobe discovery and video utilities
---@field KeypressLib? KeypressLib Key press detection for repeat-while-held actions
---@field VideoSelection? VideoSelection Smart video item selection utilities
---@field PersonalConfig? PersonalConfig Personal configuration constants
---@field PersonalUtils? PersonalUtils Personal utility functions

local EXTSTATE_SECTION = "NW_Debug"
local EXTSTATE_KEY = "enabled"

---Check if global debug logging is enabled via ExtState
---@return boolean
local function isGlobalDebugEnabled()
    return reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_KEY) == "true"
end

---Format a value for logging (handles tables)
---@param value any
---@return string
local function formatValue(value)
    if type(value) == "table" then
        local parts = {}
        for k, v in pairs(value) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(value)
    end
end

---Extract script filename from path and truncate for use as debug prefix
---@param scriptPath string
---@return string
local function getDefaultFeature(scriptPath)
    -- Extract filename without extension
    local filename = scriptPath:match("([^/\\]+)%.lua$") or "Script"
    -- Truncate to 15 chars if needed
    if #filename > 15 then
        filename = filename:sub(1, 15)
    end
    return filename
end

---Normalize path separators for current OS
---@param path string
---@return string normalizedPath
local function normalizePath(path)
    local osName = reaper.GetOS()
    if osName:match("Win") then
        path = path:gsub("/", "\\")
    end
    return path
end

---Show dependency error and return false
---@param name string Dependency name
---@param installHint string Installation instructions
---@return boolean always false
local function showDependencyError(name, installHint)
    reaper.ShowMessageBox(
        string.format("This script requires %s.\n\n%s", name, installHint),
        name .. " Required",
        0
    )
    return false
end

---Check if SWS extension is installed
---@return boolean
local function checkSWS()
    if reaper.SNM_GetIntConfigVar then
        return true
    end
    return showDependencyError(
        "SWS Extension",
        "Please install SWS from: https://www.sws-extension.org/"
    )
end

---Check if js_ReaScriptAPI is installed
---@return boolean
local function checkJsReaScriptAPI()
    if reaper.JS_VKeys_GetState then
        return true
    end
    return showDependencyError(
        "js_ReaScriptAPI Extension",
        "Please install js_ReaScriptAPI from ReaPack."
    )
end

---Check if FFmpeg is installed
---@return boolean
local function checkFFmpeg()
    -- We need to load FFmpegLib to check, but it might not be loaded yet
    -- Use a simple path-based check instead
    local osName = reaper.GetOS()
    local isWindows = osName:match("Win") ~= nil

    local checkPaths
    if isWindows then
        checkPaths = {
            "C:\\Program Files\\ffmpeg\\bin\\ffprobe.exe",
            "C:\\Program Files (x86)\\ffmpeg\\bin\\ffprobe.exe",
            "C:\\ProgramData\\chocolatey\\bin\\ffprobe.exe",
        }
    else
        checkPaths = {
            "/usr/local/bin/ffprobe",
            "/opt/homebrew/bin/ffprobe",
            "/usr/bin/ffprobe",
        }
    end

    -- Check common paths
    for _, path in ipairs(checkPaths) do
        local f = io.open(path, "r")
        if f then
            f:close()
            return true
        end
    end

    -- Try which/where command
    local whichCmd = isWindows and "where ffprobe 2>NUL" or "which ffprobe 2>/dev/null"
    local handle = io.popen(whichCmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result:match("%S") then
            return true
        end
    end

    -- Not found
    local installHint
    if isWindows then
        installHint = "Install via:\n  - winget install ffmpeg\n  - choco install ffmpeg\n  - scoop install ffmpeg"
    elseif osName:match("OSX") or osName:match("macOS") then
        installHint = "Install via:\n  - brew install ffmpeg"
    else
        installHint = "Install via your package manager:\n  - apt install ffmpeg\n  - dnf install ffmpeg"
    end

    return showDependencyError("FFmpeg", installHint .. "\n\nAfter installing, restart REAPER.")
end

---Check if ReaImGui is installed
---@return boolean
local function checkReaImGui()
    if reaper.ImGui_CreateContext then
        return true
    end
    return showDependencyError(
        "ReaImGui Extension",
        "Please install ReaImGui from ReaPack."
    )
end

---Check if Ultraschall API is installed and load it
---@return boolean
local function checkUltraschall()
    -- Already loaded?
    if ultraschall then
        return true
    end

    -- Try to load it
    local ultraschallPath = reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua"
    local f = io.open(ultraschallPath, "r")
    if f then
        f:close()
        dofile(ultraschallPath)
        if ultraschall then
            return true
        end
    end
    return showDependencyError(
        "Ultraschall API",
        "Please install Ultraschall API from ReaPack."
    )
end

-- Dependency checker map
local dependencyCheckers = {
    SWS = checkSWS,
    FFmpeg = checkFFmpeg,
    js_ReaScriptAPI = checkJsReaScriptAPI,
    ReaImGui = checkReaImGui,
    Ultraschall = checkUltraschall,
}

-- ============================================================================
-- MODULE EXPORTS (for scripts that need debug toggle without full init)
-- ============================================================================

local NWInit = {}

---Check if global debugging is enabled
---@return boolean
function NWInit.isDebugEnabled()
    return isGlobalDebugEnabled()
end

---Enable global debugging via ExtState
function NWInit.enableDebug()
    reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, "true", true)
end

---Disable global debugging via ExtState
function NWInit.disableDebug()
    reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, "false", true)
end

---Toggle global debugging via ExtState
---@return boolean newState The new enabled state
function NWInit.toggleDebug()
    local current = isGlobalDebugEnabled()
    local newState = not current
    reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, tostring(newState), true)
    return newState
end

-- ============================================================================
-- MAIN INITIALIZATION
-- ============================================================================

---Initialize NW global
---@param opts? table Configuration options
---@return NWGlobal|nil NW global or nil if dependency check failed
local function init(opts)
    opts = opts or {}

    -- Get script path from caller (2 levels up: this function <- require <- entry script)
    local scriptPath = debug.getinfo(2, "S").source:match("^@(.+)$")
    if not scriptPath then
        reaper.ShowMessageBox("NWInit: Could not determine script path", "Error", 0)
        return nil
    end

    scriptPath = normalizePath(scriptPath)
    local scriptDir = scriptPath:match("^(.+)[/\\][^/\\]+$")

    -- Set up package.path for shared utilities and local modules
    local sharedPath = scriptPath:match("^(.+)[/\\]Scripts[/\\]") .. "/Scripts/Shared/"
    sharedPath = normalizePath(sharedPath)
    package.path = package.path .. ";" .. sharedPath .. "?.lua"
    package.path = package.path .. ";" .. scriptDir .. "/?.lua"
    package.path = package.path .. ";" .. scriptDir .. "/utils/?.lua"

    -- Check dependencies
    if opts.requires then
        for _, dep in ipairs(opts.requires) do
            local checker = dependencyCheckers[dep]
            if checker then
                if not checker() then
                    _G.NW = nil
                    return nil
                end
            else
                reaper.ShowMessageBox(
                    string.format("NWInit: Unknown dependency '%s'", dep),
                    "Configuration Error",
                    0
                )
                _G.NW = nil
                return nil
            end
        end
    end

    -- Determine debug settings
    local debugEnabled = opts.debug or false
    if not debugEnabled then
        -- Check global ExtState for prod mode
        debugEnabled = isGlobalDebugEnabled()
    end

    local defaultFeature = opts.feature or getDefaultFeature(scriptPath)
    local undoText = opts.undo

    -- Create NW global with all fields defined upfront
    ---@type NWGlobal
    local NW = {
        scriptPath = scriptPath,
        scriptDir = scriptDir,

        ---Check if running on Windows
        ---@return boolean
        isWindows = function()
            return reaper.GetOS():match("Win") ~= nil
        end,

        ---Log a debug message
        ---@param featureOrMsg string Either the feature name (if 2 args) or the message (if 1 arg)
        ---@param msg? string The message (if feature provided as first arg)
        log = function(featureOrMsg, msg)
            if not debugEnabled then return end

            local feature, message
            if msg then
                feature = featureOrMsg
                message = msg
            else
                feature = defaultFeature
                message = featureOrMsg
            end

            reaper.ShowConsoleMsg("[" .. feature .. "] " .. formatValue(message) .. "\n")
        end,

        ---Run a function wrapped in an undo block (if undo text configured)
        ---@param fn function The main function to execute
        run = function(fn)
            if undoText then
                reaper.Undo_BeginBlock()
            end

            fn()

            if undoText then
                reaper.Undo_EndBlock(undoText, -1)
            end
        end,

        ---Load a peer shared library on demand and cache it on NW global.
        ---
        ---⚠️ THIS IS ONLY FOR USE IN Scripts/Shared/*.lua FILES ⚠️
        ---
        ---Use this when a shared library needs to depend on another shared library.
        ---For example, if VideoSelection.lua needs ReaperUtils:
        ---
        ---   -- In Scripts/Shared/VideoSelection.lua
        ---   NW.requirePeerLib("ReaperUtils")
        ---   function VideoSelection.foo()
        ---       NW.ReaperUtils.doSomething()
        ---   end
        ---
        ---DO NOT use this in:
        ---  - Entry-point scripts (use NWInit's `libs` parameter instead)
        ---  - Package-local utils (declare dependencies in entry script's NWInit)
        ---
        ---The build system only scans Scripts/Shared/ for requirePeerLib calls.
        ---Using it elsewhere means dependencies won't be included in built packages.
        ---
        ---@param libName string Name of the library (e.g., "ReaperUtils")
        ---@return any lib The loaded library module
        requirePeerLib = function(libName)
            -- Return cached version if already loaded
            if _G.NW and _G.NW[libName] then
                return _G.NW[libName]
            end

            -- Load the library
            local ok, lib = pcall(require, libName)
            if not ok then
                error(string.format("NW.requirePeerLib: Failed to load library '%s'\n%s", libName, tostring(lib)))
            end

            -- Cache on NW global (NW will be set after this table is assigned to _G.NW)
            -- We use rawset to avoid triggering any metamethods
            if _G.NW then
                _G.NW[libName] = lib
            end

            return lib
        end,
    }

    -- Set global before loading libs so that shared libraries can use NW.requirePeerLib()
    _G.NW = NW

    -- Load requested libraries
    if opts.libs then
        for _, libName in ipairs(opts.libs) do
            local ok, lib = pcall(require, libName)
            if ok then
                NW[libName] = lib
            else
                reaper.ShowMessageBox(
                    string.format("NWInit: Failed to load library '%s'\n\n%s", libName, tostring(lib)),
                    "Library Load Error",
                    0
                )
                _G.NW = nil
                return nil
            end
        end
    end

    return NW
end

-- Make NWInit callable as a function while also exposing module methods
-- Usage: require("NWInit")({...}) for full init
-- Usage: require("NWInit").toggleDebug() for just debug toggle
setmetatable(NWInit, { __call = function(_, opts) return init(opts) end })

return NWInit
