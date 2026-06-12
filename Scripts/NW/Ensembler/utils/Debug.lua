-- Debug.lua - Scoped and leveled debug logging
require('types/types')

local Debug = {}

--------------------------------------------------------------------------------
-- Feature Scope Constants (Bitwise Flags)
--------------------------------------------------------------------------------
-- Each feature is a power of 2 so they can be combined with bitwise OR (|)
-- To add a new feature:
--   1. Add a new entry using the next power of 2 (double the last value)
--   2. Add the corresponding name to FEATURE_NAMES below
--   3. Update the DebugFeature type alias in types/types.lua
--
-- Example: To add "MIDI" feature, use value 128 (next power of 2 after 64)
--   MIDI = 128
--------------------------------------------------------------------------------
Debug.FEATURE = {
    PERSISTENCE =   1,      -- 2^0 = 1
    QUICK_BUILDER = 2,      -- 2^1 = 2
    TRACKS =        4,      -- 2^2 = 4
    UTILS =         8,      -- 2^3 = 8
    ENSEMBLE =      16,     -- 2^4 = 16
    JSFX =          32,     -- 2^5 = 32
    UI =            64,     -- 2^6 = 64
    RETRO =         128,    -- 2^7 = 128

    -- Placeholder for future features (uncomment and rename as needed):
    -- FEATURE_9 =  256,    -- 2^8 = 256
    -- FEATURE_10 = 512,    -- 2^9 = 512
    -- FEATURE_11 = 1024,   -- 2^10 = 1024
    -- FEATURE_12 = 2048,   -- 2^11 = 2048
}

-- Feature names for display in console output
local FEATURE_NAMES = {
    [1] = "PERSISTENCE",
    [2] = "QUICK_BUILDER",
    [4] = "TRACKS",
    [8] = "UTILS",
    [16] = "ENSEMBLE",
    [32] = "JSFX",
    [64] = "UI",
    [128] = "RETRO",

    -- Add corresponding names when adding new features:
    -- [256] = "FEATURE_9",
}

local LEVEL_ORDER = {
    DEBUG = 1,
    WARN = 2,
    ERROR = 3
}

---Check if a log should be displayed based on filters
---@param feature number Bitwise feature flag
---@param level DebugLevel
---@return boolean
local function shouldLog(feature, level)
    if not State.config.DEBUG_ENABLED then
        return false
    end

    -- Check level threshold
    local minLevel = LEVEL_ORDER[State.config.DEBUG_LEVEL] or 1
    local msgLevel = LEVEL_ORDER[level] or 1
    if msgLevel < minLevel then
        return false
    end

    -- Check feature filter (0 = show all features)
    if State.config.DEBUG_FEATURES ~= 0 then
        -- Use bitwise AND to check if this feature is enabled
        if (State.config.DEBUG_FEATURES & feature) == 0 then
            return false
        end
    end

    return true
end

---Get feature name for display
---@param feature number Bitwise feature flag
---@return string
local function getFeatureName(feature)
    return FEATURE_NAMES[feature] or "UNKNOWN"
end

---Format output for console
---@param message string|table
---@return string
local function formatMessage(message)
    if type(message) == "table" then
        return State.table_to_string(message)
    else
        return tostring(message)
    end
end

---Core logging function
---@param message string|table Message to log
---@param feature number Bitwise feature flag
local function logToConsole(message, feature)
    local output = formatMessage(message)
    local featureName = getFeatureName(feature)
    reaper.ShowConsoleMsg(string.format("[%s] %s\n", featureName, output))
end

---Core logging function (DEBUG level)
---@param message string|table Message to log
---@param feature number Bitwise feature flag
function Debug.log(message, feature)
    if not shouldLog(feature, "DEBUG") then
        return
    end

    logToConsole(message, feature)
end

---Log at WARN level
---@param message string|table
---@param feature number Bitwise feature flag
function Debug.warn(message, feature)
    if not shouldLog(feature, "WARN") then
        return
    end

    logToConsole(message, feature)
end

---Log at ERROR level
---@param message string|table
---@param feature number Bitwise feature flag
function Debug.error(message, feature)
    if not shouldLog(feature, "ERROR") then
        return
    end

    logToConsole(message, feature)
end

return Debug
