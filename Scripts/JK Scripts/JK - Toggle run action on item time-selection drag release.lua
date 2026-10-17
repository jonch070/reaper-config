-- Toggle: when ON, dragging on a media item and releasing the left mouse button
-- runs the custom action below (only if the time selection changed during the drag).
-- Requires js_ReaScriptAPI.

local ACTION_ID = "_1938c50187ec47469b4973f3f708bbf6"

if not reaper.JS_Mouse_GetState then
  reaper.MB("This script needs the js_ReaScriptAPI extension (install via ReaPack).", "Missing extension", 0)
  return
end

local _, _, section, cmd = reaper.get_action_context()
local action = reaper.NamedCommandLookup(ACTION_ID)

local was_down, started_on_item = false, false
local ts_start, ts_end

local DEBUG = false -- prints to the ReaScript console; set false when working

local function log(msg)
  if DEBUG then reaper.ShowConsoleMsg(msg .. "\n") end
end

if action == 0 then log("Action ID not found: " .. ACTION_ID) end

local function loop()
  local down = reaper.JS_Mouse_GetState(1) & 1 == 1

  if down and not was_down then
    local x, y = reaper.GetMousePosition()
    started_on_item = reaper.GetItemFromPoint(x, y, false) ~= nil
    ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    log("down  on_item=" .. tostring(started_on_item))
  elseif not down and was_down then
    local s, e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local changed = s ~= ts_start or e ~= ts_end
    log("up    on_item=" .. tostring(started_on_item) .. " ts_changed=" .. tostring(changed))
    if started_on_item and changed then
      reaper.Main_OnCommand(action, 0)
    end
    started_on_item = false
  end

  was_down = down
  reaper.defer(loop)
end

reaper.SetToggleCommandState(section, cmd, 1)
reaper.RefreshToolbar2(section, cmd)

reaper.atexit(function()
  reaper.SetToggleCommandState(section, cmd, 0)
  reaper.RefreshToolbar2(section, cmd)
end)

loop()
