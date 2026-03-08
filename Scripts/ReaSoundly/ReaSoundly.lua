--version:0.9.1 Beta

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Utilities.lua')
if not ReaSoundly.CheckDependencies() then return end -- exit early when dependencies do not exist

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

args = script_path .. "/ReaSoundly.data"
json = dofile(script_path .. "/json/json.lua")

f = io.open(args)
if f then
  buf = f:read("*all")
  f:close()
else
  reaper.ShowMessageBox(
    "There is no valid data from Soundly.\nPlease import some files first using the ReaSoundly option in Soundly.",
    "ReaSoundly", 0)
  return
end

data = json.decode(buf)

if data then
  reaper.SetExtState(ext_section, "filecount", #data.files, false) -- save filecount into ext state
  reaper.SetExtState(ext_section, "files", buf, false)             -- save raw json data for later use
  reaper.SetExtState(ext_section, "segment_mode", data.segmentMode, false)
  reaper.SetExtState(ext_section, "segment_splits", data.segmentSplits, false)
  reaper.SetExtState(ext_section, "handle_size", data.handleSizeUsed, false)

  ReaSoundly.LoadSettings()

  -- Update Spot history in REAPER
  ReaSoundly.UpdateSpotHistory(settings.history_limit)

  if settings.open_launcher_when_spotting then
    -- check if "copy media on import" setting is toggled
    local is_enabled = reaper.GetToggleCommandState(40263) -- Options: When importing, copy imported media to project media directory

    if is_enabled == 0 and data.storageEnabled == 0 then
      local message =
      "It seems you've disabled Audio Storage in Soundly and the copying of media files into your project media directory\n"
      message = message .. "If you continue, imported files will not be copied to your project media directory\n"
      message = message ..
          "It is recommended that you enable the copying of media files to your project media directory.\n"
      message = message .. "\nDo you want to enable copying files in REAPER now?"

      local choice = reaper.ShowMessageBox(message, "ReaSoundly - Audio Storage Warning", 4)
      if choice == 6 then
        reaper.Main_OnCommand(40263, 0) -- Options: When importing, copy imported media to project media directory
      end
    end

    -- call the launcher
    local launcher = reaper.NamedCommandLookup("_reasoundly_launcher")
    reaper.Main_OnCommand(launcher, 0)
  end
end
