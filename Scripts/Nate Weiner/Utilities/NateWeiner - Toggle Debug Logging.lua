-- NW_Toggle Debug Logging.lua
-- Toggles debug logging for all NW scripts (via ExtState)
-- Author: Nate Weiner (https://nateweiner.com)
--
-- For users who installed scripts via ReaPack:
-- Run this action to enable/disable debug logging, then reproduce your issue.
-- Debug output appears in the ReaScript console (Actions > Show ReaScript console).

local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
local sharedPath = scriptPath:match("^(.+)[/\\][^/\\]+$") .. "/Shared/"
package.path = package.path .. ";" .. sharedPath .. "?.lua"

local NWInit = require("NWInit")

local newState = NWInit.toggleDebug()
local stateText = newState and "ENABLED" or "DISABLED"

reaper.MB(
    "Debug logging is now " .. stateText .. ".\n\n" ..
    "Debug output will appear in the ReaScript console.\n" ..
    "(Actions > Show ReaScript console)",
    "NW Debug Logging",
    0
)
