ReaSoundly = {}

local function InsertState(state)
  if state then
    return "(installed)"
  end
  return "(missing)"
end

-- Common Functions for Launcher and Settings
function ReaSoundly.CheckDependencies()
  -- Check if required extensions/packages are installed
  local reapack_exists = reaper.APIExists("ReaPack_AboutRepository")
  local imgui_exists = reaper.APIExists("ImGui_GetVersion")
  local sws_exists = reaper.APIExists("CF_GetSWSVersion")
  local js_exists = reaper.APIExists("JS_ReaScriptAPI_Version")


  if not sws_exists or not reapack_exists then
    local message = "ReaSoundly requires the following extensions:\n"
    message = message ..
        "SWS Extension " .. InsertState(sws_exists) .. " - Please install it from https://www.sws-extension.org/\n"
    message = message .. "ReaPack " .. InsertState(reapack_exists) .. " - Please install it from https://reapack.com/\n"
    reaper.ShowMessageBox(message, "ReaSoundly - Missing Dependencies", 0)
    return false
  end

  if not imgui_exists or not js_exists then
    local message = "ReaSoundly requires the following packages:\n"
    message = message .. "ReaImGui " .. InsertState(imgui_exists) .. "\n"
    message = message .. "JS ReaScript Api " .. InsertState(js_exists) .. "\n"
    message = message .. "\nDo you want to install them now via ReaPack?"
    if reaper.ShowMessageBox(message, "ReaSoundly - Missing Packages", 4) == 6 then
      reaper.ReaPack_BrowsePackages("ReaImGui OR js ReaScript")
    end
    return false
  end

  return true
end
