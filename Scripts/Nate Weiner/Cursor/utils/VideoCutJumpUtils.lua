-- VideoCutJumpUtils.lua - Shared utilities for video cut navigation
-- Common logic for checking processor liveness and queueing jump requests
-- Author: Nate Weiner (https://nateweiner.com)

local VideoCutConfig = require("config")
-- ReaperUtils is loaded by entry script's NWInit({ libs = [...] })

local VideoCutJumpUtils = {}

-- Shorthand config references
local HEARTBEAT_TIMEOUT = VideoCutConfig.HEARTBEAT_TIMEOUT

---Check if background processor is actually alive
---@return boolean isAlive True if processor is running and responsive
local function isProcessorAlive()
    local processorActive = reaper.GetExtState("NW_VideoCut", "processorActive")
    NW.log("JumpUtils", string.format("[Liveness Check] processorActive='%s'", processorActive))

    if processorActive ~= "true" then
        NW.log("JumpUtils", "[Liveness Check] Flag is not 'true', processor not active")
        return false
    end

    -- Check heartbeat
    local lastHeartbeatStr = reaper.GetExtState("NW_VideoCut", "lastHeartbeat")
    NW.log("JumpUtils", string.format("[Liveness Check] lastHeartbeat='%s'", lastHeartbeatStr))

    if lastHeartbeatStr == "" then
        -- No heartbeat means processor died or was killed before writing heartbeat
        -- This is stale state - consider it dead
        NW.log("JumpUtils", "[Liveness Check] No heartbeat found - stale state, processor is DEAD")
        return false
    end

    local lastHeartbeat = tonumber(lastHeartbeatStr)
    if not lastHeartbeat then
        NW.log("JumpUtils", "[Liveness Check] Invalid heartbeat timestamp")
        return false
    end

    local now = reaper.time_precise()
    local age = now - lastHeartbeat
    NW.log("JumpUtils", string.format("[Liveness Check] Heartbeat age: %.2fs (timeout: %.2fs)", age, HEARTBEAT_TIMEOUT))

    local isAlive = age < HEARTBEAT_TIMEOUT
    NW.log("JumpUtils", string.format("[Liveness Check] Processor is %s", isAlive and "ALIVE" or "DEAD"))
    return isAlive
end

---Queue a jump request and start processor if needed
---@param direction string "next" or "previous"
---@param logPrefix string Prefix for console messages (e.g., "[Jump Next]")
function VideoCutJumpUtils.queueJumpRequest(direction, logPrefix)
    NW.log("JumpUtils", logPrefix .. " Setting pendingJumpRequest via ExtState")

    -- Set pending jump request via ExtState (persists across script boundaries)
    reaper.SetExtState("NW_VideoCut", "pendingJumpDirection", direction, false)
    reaper.SetExtState("NW_VideoCut", "pendingJumpTimestamp", tostring(reaper.time_precise()), false)

    -- Check if processor is actually alive (not just a stale flag)
    if not isProcessorAlive() then
        NW.log("JumpUtils", logPrefix .. " Starting background processor")
        -- Clear stale state if present
        reaper.SetExtState("NW_VideoCut", "processorActive", "false", false)
        reaper.SetExtState("NW_VideoCut", "lastHeartbeat", "", false)

        -- Find and execute the background processor by name
        NW.log("JumpUtils", logPrefix .. " Calling ReaperUtils.Main_OnCommandByName('VideoCutBackgroundProcessor')")
        local success = NW.ReaperUtils.Main_OnCommandByName("VideoCutBackgroundProcessor")
        NW.log("JumpUtils", logPrefix .. " Main_OnCommandByName returned: " .. tostring(success))
        if not success then
            NW.log("JumpUtils", logPrefix .. " ERROR: Could not find or execute VideoCutBackgroundProcessor")
            reaper.ShowMessageBox(
                "Could not find VideoCutBackgroundProcessor script.\n\n" ..
                "Please ensure the script is installed and registered in Actions.",
                "Video Cuts Error",
                0
            )
        end
    else
        NW.log("JumpUtils", logPrefix .. " Processor already active, request queued")
    end
end

return VideoCutJumpUtils
