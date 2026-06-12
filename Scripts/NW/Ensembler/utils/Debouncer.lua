-- Debouncer.lua - Utility for debouncing function calls

local Debouncer = {}

-- Storage for pending debounced calls
local pendingCalls = {}

---Debounce a function call - will reschedule if called again before delay expires
---@param key string Unique identifier for this debounced operation
---@param delaySeconds number Delay in seconds before function executes
---@param fn function Function to execute after delay
function Debouncer.debounce(key, delaySeconds, fn)
    -- Cancel any existing pending call for this key
    if pendingCalls[key] then
        -- Clear the existing defer
        pendingCalls[key] = nil
    end
    
    -- Schedule the new call
    local startTime = reaper.time_precise()
    
    local function checkAndExecute()
        local elapsed = reaper.time_precise() - startTime
        
        if elapsed >= delaySeconds then
            -- Time expired, execute the function
            pendingCalls[key] = nil
            fn()
        else
            -- Not enough time passed, reschedule
            if pendingCalls[key] then -- Only reschedule if not cancelled
                reaper.defer(checkAndExecute)
            end
        end
    end
    
    -- Mark as pending and start the timer
    pendingCalls[key] = true
    reaper.defer(checkAndExecute)
end

---Cancel a pending debounced call
---@param key string The key of the debounced call to cancel
function Debouncer.cancel(key)
    pendingCalls[key] = nil
end

---Check if a debounced call is pending
---@param key string The key to check
---@return boolean
function Debouncer.isPending(key)
    return pendingCalls[key] ~= nil
end

return Debouncer