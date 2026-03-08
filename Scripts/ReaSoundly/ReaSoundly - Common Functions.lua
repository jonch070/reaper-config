local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
json = dofile(script_path .. "/json/json.lua") -- import json library

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')

ReaSoundly = {}

ext_section = "ReaSoundly"

-- Table of import modes, used by the launcher for import prompts and UNDO points
import_modes = {
  [0] = "Import",
  [1] = "Import sequentially",
  [2] = "Import vertically",
  [3] = "Import sequentially on different tracks",
  [4] = "Import as takes",
  [5] = "Import as lanes"
}

local default_actions = {
  { name = "Soundly - Split imported items by segments",                          commands = { "_reasoundly_split_by_segments" } },
  { name = "Soundly - Implode segments into takes",                               commands = { "_reasoundly_segments_to_takes" } },
  { name = "Soundly - Explode segments across tracks",                            commands = { "_reasoundly_segments_to_takes", "_reasoundly_explode_takes_to_tracks" } },
  { name = "Soundly - Explode segments across lanes",                             commands = { "_reasoundly_segments_to_takes", "_reasoundly_explode_takes_to_lanes" } },
  { name = "Soundly - Fit items to time selection (Loop Source)",                 commands = { "_reasoundly_fit_items_to_time_selection_loop" } },
  { name = "Soundly - Fit items to time selection (Duplicate Items)",             commands = { "_reasoundly_fit_items_to_time_selection_duplicate" } },
  { name = "Soundly - Align selected items to project markers in time selection", commands = { "_reasoundly_align_items_to_markers" } },
  { name = "Soundly - Normalize items",                                           commands = { 42460 } },
}

local segment_actions = {
}

for _, action in pairs(default_actions) do
  if string.find(string.lower(action.name), "segments") then
    table.insert(segment_actions, action.name)
  end
end

default_settings = {
  default_import = 0,
  default_action = 1,
  default_action_mode = 0,
  close_after_run = false,
  close_unfocused = false,
  show_footer_toolbar = true,
  ignore_slices = false,
  open_launcher_when_spotting = true,
  open_launcher_paste_it = false,
  history_limit = 10,
  autoplay = false,
  opacity = 255,
  default_fades = false,
  crossfade_dur = 0.1,
}

-- load default settings into settings
settings = {}
for k, v in pairs(default_settings) do
  settings[k] = v
end

function ReaSoundly.SetItemsSelected(items, is_selected)
  for _, v in ipairs(items) do
    reaper.SetMediaItemSelected(v, is_selected)
  end
  reaper.UpdateArrange()
end

function ReaSoundly.GetFileCount()
  local filecount = 0
  if reaper.HasExtState(ext_section, "filecount") then
    filecount = tonumber(reaper.GetExtState(ext_section, "filecount"))
  end

  return filecount
end

function ReaSoundly.GetFiles()
  if reaper.HasExtState(ext_section, "files") then
    local files = reaper.GetExtState(ext_section, "files")
    local data = json.decode(files)

    return data.files
  end

  return {}
end

function ReaSoundly.OverwriteFiles(files)
  reaper.SetExtState(ext_section, "filecount", #files.files, false)   -- save filecount into ext state
  reaper.SetExtState(ext_section, "files", json.encode(files), false) -- save raw json data for later use
end

function ReaSoundly.ImportFiles(mode)
  local filecount = ReaSoundly.GetFileCount()
  local files = ReaSoundly.GetFiles()

  -- if master track is selected, select last track
  if reaper.IsTrackSelected(reaper.GetMasterTrack(0)) then
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_UNSELMASTER"), 0)

    if reaper.CountTracks(0) == 0 then
      reaper.InsertTrackAtIndex(0, false)
    end

    -- select last track
    local track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
    reaper.SetOnlyTrackSelected(track)
  end

  -- if the setting "Options: Trim content behind media items when editing" is enabled, disable it
  local trim_enabled = reaper.GetToggleCommandStateEx(0, 41117) == 1 and true or false
  if trim_enabled then
    reaper.Main_OnCommand(41117, 0)
  end

  reaper.Undo_BeginBlock2(0)

  if filecount > 1 then
    if mode <= 3 then
      -- Import files sequentially and then decide what to do based on the mode
      for i, file in ipairs(files) do
        reaper.InsertMedia(file.filePath, 0)
      end

      local items = {}
      for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(items, item)
      end

      local first_pos = reaper.GetMediaItemInfo_Value(items[1], "D_POSITION")

      if mode == 2 or mode == 3 then -- import vertically
        ReaSoundly.SetItemsSelected(items, false)

        local skips = 1

        for i = 2, #items do
          local item = items[i]
          reaper.SetMediaItemSelected(item, true)

          for j = 1, skips do
            reaper.Main_OnCommand(40118, 0) --Item edit: Move items/envelope points down one track/a bit
          end

          if mode == 2 then reaper.SetMediaItemPosition(item, first_pos, false) end -- set the position to the first item only in mode 2 (vertical align)
          reaper.SetMediaItemSelected(item, false)

          skips = skips + 1
        end

        if mode == 2 then reaper.SetEditCurPos2(0, first_pos, true, false) end
        ReaSoundly.SetItemsSelected(items, true)
      end
    else
      -- import first file
      reaper.InsertMedia(files[1].filePath, 0)

      -- import all other files as takes
      for i = 2, #files do
        reaper.InsertMedia(files[i].filePath, 3)
      end

      if mode == 5 then
        reaper.Main_OnCommand(42635, 0) -- Take: Explode takes on selected tracks to fixed lanes
      end
    end
  else
    -- import only one file non desctructively
    local file = files[1]

    local import_section = true

    if not file.selectionStartTime or not file.selectionStopTime then
      import_section = false
    end

    if import_section then
      local start_time = (file.selectionStartTime / file.audioFileDuration)
      local stop_time = (file.selectionStopTime / file.audioFileDuration)

      reaper.InsertMediaSection(file.filePath, 128, start_time, stop_time, 0) -- flag &128 disables "loop section in item source"
    else
      reaper.InsertMedia(file.filePath, 128)
    end

    local item = reaper.GetSelectedMediaItem(0, 0) -- get last imported item - it is selected by default
    ReaSoundly.SetItemProperties(item, file)
  end

  if trim_enabled then
    reaper.Main_OnCommand(41117, 0)
  end

  reaper.Undo_EndBlock2(0, ("ReaSoundly - %s"):format(import_modes[mode]), 0)
end

function ReaSoundly.SetItemProperties(item, file_data)
  if file_data.effects then
    if file_data.effects.fadeInDuration then
      reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN",
        file_data.effects.fadeInDuration)
      if not settings.default_fades then
        reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", 0)
      end
    end
    if file_data.effects.fadeOutDuration then
      reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN",
        file_data.effects.fadeOutDuration)
      if not settings.default_fades then
        reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", 0)
      end
    end

    -- TODO uncomment if playbackSpeed is accounted back for
    -- if file_data.effects.playbackSpeed then
    --   local take = reaper.GetActiveTake(item)
    --   reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", file_data.effects.playbackSpeed)
    -- end
  end
end

function ReaSoundly.GetNameFromFilePath(file_path)
  return file_path:match("([^\\/]+)$")
end

function ReaSoundly.GetScriptName()
  _, filename = reaper.get_action_context()
  return ReaSoundly.GetNameFromFilePath(filename)
end

function ReaSoundly.BuildFileId(file)
  local id = file.soundlyFileID
  if ReaSoundly.HasSegmentSplits() then
    if file.segmentIndex then
      id = id .. string.format(" S%02d", file.segmentIndex)
    end
  end

  return id
end

function ReaSoundly.CacheImportedItemsById(files)
  local ids = {}
  for _, file in ipairs(files) do
    table.insert(ids, ReaSoundly.BuildFileId(file))
  end
  return ids
end

function ReaSoundly.SelectItemsById(ids, is_selected)
  local items = {}
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetMediaItemTake(item, 0)
    local name = reaper.GetTakeName(take)

    for _, id in ipairs(ids) do
      if string.find(string.lower(name), string.lower(id)) then
        table.insert(items, item)
      end
    end
  end

  ReaSoundly.SetItemsSelected(items, is_selected)
end

function ReaSoundly.CacheSelectedItems()
  local items = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, item)
  end
  return items
end

function ReaSoundly.CacheMarkerLengths(items, files)
  local data = {}

  for _, item in pairs(items) do
    local file, take = ReaSoundly.FindTakeInFiles(files, item)

    if file then
      local id = ReaSoundly.GetNameFromFilePath(file.filePath)
      local marker_values = {}
      local marker_lengths = {}

      -- save marker values in enumerated table
      for _, v in pairs(file.markers) do
        for k, v in pairs(v) do
          -- TODO if we have more markers in the future, we need to differentiate here
          -- save only if markers are "-START" markers and the key is numeric
          if v == "-START" and tonumber(k) then
            table.insert(marker_values, k)
          end
        end
      end

      local source = reaper.GetMediaItemTake_Source(take)
      local file_length = reaper.GetMediaSourceLength(source)
      table.insert(marker_values, file_length)

      for i = 1, #marker_values - 1 do
        local length = marker_values[i + 1] - marker_values[i]
        table.insert(marker_lengths, length)
      end

      data[id] = marker_lengths
    end
  end

  return data
end

function ReaSoundly.FindTakeInFiles(files, item)
  local take = reaper.GetActiveTake(item)
  local take_name = reaper.GetTakeName(take)

  local file
  for i = 1, #files do
    local f = files[i]
    local file_name = ReaSoundly.GetNameFromFilePath(f.filePath)

    if file_name == take_name then
      file = f
      break
    end
  end

  return file, take
end

function ReaSoundly.SplitItemBySegments(item, file)
  local segment_marker = "-START"
  local splits = {}
  table.insert(splits, item)

  -- Disable Loop Source for selected item
  reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 0)
  reaper.SetMediaItemSelected(item, true)

  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local take = reaper.GetActiveTake(item)
  local offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

  for i = 1, #file.markers do
    local marker = file.markers[i]

    for key, data in pairs(marker) do
      if tonumber(key) then -- check if key is a number - this means, it's the position of the marker
        local time = tonumber(key)

        if i == 1 and time > 0 then
          goto continue
        end

        local marker_name = data
        local marker_found = false

        if settings.ignore_slices then
          if string.find(marker_name, segment_marker) then marker_found = true end
        else
          marker_found = marker_name == segment_marker
        end

        if marker_found and item and time > 0 then
          item = reaper.SplitMediaItem(item, item_start + time - offset)
          table.insert(splits, item)
        end
      end

      ::continue::
    end
  end

  return splits
end

function ReaSoundly.HasSegmentMarkers(file)
  if file.markers and #file.markers > 1 then
    return true
  end
  return false
end

function ReaSoundly.HasSegmentSplits()
  if reaper.GetExtState(ext_section, "segment_splits") == "1" then
    return true
  end
  return false
end

function ReaSoundly.HasHandleSize()
  if reaper.HasExtState(ext_section, "handle_size") and tonumber(reaper.GetExtState(ext_section, "handle_size")) > -1 then
    return true
  end
  return false
end

function ReaSoundly.IsSegmentAction(name)
  if table.contains(segment_actions, name) then
    return true
  end
  return false
end

function ReaSoundly.SaveActions()
  reaper.SetExtState(ext_section, "actions", json.encode(data.actions), true)
end

function ReaSoundly.LoadActions()
  local actions = {}

  if reaper.HasExtState(ext_section, "actions") and reaper.GetExtState(ext_section, "actions") ~= "null" then
    actions = json.decode(reaper.GetExtState(ext_section, "actions"))
  else
    -- create default actions for first boot and reset
    for i, set in ipairs(default_actions) do
      table.insert(actions, set)
    end
  end

  return actions
end

function ReaSoundly.ResetActions()
  reaper.DeleteExtState(ext_section, "actions", true)
  data.actions = ReaSoundly.LoadActions()
end

function ReaSoundly.RestoreDefaultActions()
  local restored_actions = {}

  -- Cache custom action ids
  local custom_action_ids = {}

  for id, set in ipairs(data.actions) do
    local found = false
    for i = 1, #default_actions do
      if set.name == default_actions[i].name then
        found = true
      end
    end

    if not found then
      table.insert(custom_action_ids, id)
    end
  end

  -- insert default actions into restored_actions table
  for i = 1, #default_actions do
    table.insert(restored_actions, default_actions[i])
  end

  -- insert custom actions into restored actions table
  for _, id in ipairs(custom_action_ids) do
    table.insert(restored_actions, data.actions[id])
  end

  -- override actions with restored actions
  data.actions = restored_actions
end

function ReaSoundly.GetCommandKey(cmd)
  local key
  -- Check if command is a named command. If so, use the named command as the key
  local rev_cmd = reaper.ReverseNamedCommandLookup(cmd)
  if rev_cmd then key = "_" .. rev_cmd else key = cmd end

  return key
end

function ReaSoundly.QueryActionList()
  local actions = {}
  local rv = -1
  local idx = 0
  local name = ""

  while rv ~= 0 do
    rv, name = reaper.kbd_enumerateActions(0, idx)

    local key = ReaSoundly.GetCommandKey(rv)

    if key then actions[key] = name end
    idx = idx + 1
  end

  return actions
end

function ReaSoundly.LoadSettings()
  for k, v in pairs(settings) do
    if reaper.HasExtState(ext_section, k) then
      local value = reaper.GetExtState(ext_section, k)
      if value == "true" then
        value = true
      elseif value == "false" then
        value = false
      elseif tonumber(value) then
        value = tonumber(value)
      else
        value = nil
      end

      settings[k] = value
    else
      settings[k] = default_settings[k]
    end
  end
end

function ReaSoundly.SaveSettings()
  for k, v in pairs(settings) do
    reaper.SetExtState(ext_section, k, tostring(v), true)
  end
end

function ReaSoundly.HasSettingsUpdate()
  return reaper.HasExtState(ext_section, "update_settings") and reaper.GetExtState(ext_section, "update_settings") == "1"
end

function ReaSoundly.UpdateSettings(val)
  reaper.SetExtState(ext_section, "update_settings", val, false)
end

function ReaSoundly.FactoryReset()
  for k, v in pairs(settings) do
    reaper.DeleteExtState(ext_section, k, true)
  end
  ReaSoundly.ResetActions()
  ReaSoundly.LoadSettings()
end

function ReaSoundly.UpdateSpotHistory(history_count)
  local files = ReaSoundly.GetFiles()

  -- get previous spot history and decode json
  local history = {}
  if reaper.HasExtState(ext_section, "spot_history") and reaper.GetExtState(ext_section, "spot_history") ~= "" then
    history = json.decode(reaper.GetExtState(ext_section, "spot_history"))
  end

  -- add new files to top of history
  for i = 1, #files do
    table.insert(history, 1, files[i])
  end

  -- trim history
  if #history > history_count then
    local diff = #history - history_count
    for i = 1, diff do
      table.remove(history)
    end
  end

  -- write new encoded ext state
  reaper.SetExtState(ext_section, "spot_history", json.encode(history), false)
  reaper.SetExtState(ext_section, "update_history", "1", false)
end

function ReaSoundly.HasSpotHistoryUpdate()
  return reaper.HasExtState(ext_section, "update_history") and reaper.GetExtState(ext_section, "update_history") == "1"
end

function ReaSoundly.LoadSpotHistory()
  if reaper.HasExtState(ext_section, "spot_history") and reaper.GetExtState(ext_section, "spot_history") ~= "" then
    return json.decode(reaper.GetExtState(ext_section, "spot_history"))
  end
  return {}
end

function ReaSoundly.ClearSpotHistory()
  reaper.SetExtState(ext_section, "spot_history", "", false)
end

function ReaSoundly.SaveImportMode(mode)
  reaper.SetExtState(ext_section, "import_mode", mode, false) -- save import mode into ext data, for later usage (e.g. explode scripts)
end

function ReaSoundly.LoadImportMode()
  return reaper.HasExtState(ext_section, "import_mode") and reaper.GetExtState(ext_section, "import_mode") or 0
end

function ReaSoundly.FileExists(file)
  local f = io.open(file, "r")
  if f then
    io.close(f)
    return true
  else
    return false
  end
end

-- Common ImGui functions
ui = {
  window_flags =
      reaper.ImGui_WindowFlags_NoTitleBar(),
  selectable_flags = reaper.ImGui_SelectableFlags_AllowOverlap(),
  page = 1,
  cur_idx = 1,
  shortcut_limit = 9,
  undo_key = 0,
  hover_tints = {},

  item_spacing_x = 15,
  window_rounding = 12,
  window_padding_x = 7,
  window_padding_y = 7,
  frame_padding = 5,
  item_width = 300,

  color = {
    primary_main = reaper.ImGui_ColorConvertDouble4ToU32(0, 0.4, 1, 1),
    primary_hover = reaper.ImGui_ColorConvertDouble4ToU32(0.04, 0.47, 1, 1),
    transparent = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 0),
    gray = reaper.ImGui_ColorConvertDouble4ToU32(0.1, 0.1, 0.1, 1),
    light_gray = reaper.ImGui_ColorConvertDouble4ToU32(0.15, 0.15, 0.15, 1),
    highlight_gray = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1),
    dark_gray = reaper.ImGui_ColorConvertDouble4ToU32(0.06, 0.06, 0.06, 1),
    red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.25, 0.20, 1),
    highlight_red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.30, 0.26, 1),
    green = reaper.ImGui_ColorConvertDouble4ToU32(0.25, 1, 0.20, 1),
    violet = reaper.ImGui_ColorConvertDouble4ToU32(0.72, 0.07, 0.94, 1),
    violet_hover = reaper.ImGui_ColorConvertDouble4ToU32(0.77, 0.1, 0.97, 1),
    white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1),
    light_white = reaper.ImGui_ColorConvertDouble4ToU32(0.75, 0.75, 0.75, 1),
  }
}

ui.font_size = 16
ui.font_size_big = ui.font_size * 1.125
ui.font_size_small = ui.font_size * 0.875

function ui.PushStyles(ctx)
  local style_pushes = {
    function() reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 0, ui.item_spacing_x) end,
    function() reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), ui.window_rounding) end,
    function()
      reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), ui.window_padding_x,
        ui.window_padding_y)
    end,
    function() reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), ui.frame_padding, ui.frame_padding) end,
  }

  for _, v in ipairs(style_pushes) do
    v()
  end

  return #style_pushes
end

function ui.PushColors(ctx)
  local bg_color = reaper.ImGui_ColorConvertDouble4ToU32(0.09, 0.09, 0.09, settings.opacity / 255)
  local color_pushes = {
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), bg_color) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), ui.color.light_gray) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), ui.color.highlight_gray) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), ui.color.gray) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), ui.color.primary_main) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), ui.color.primary_hover) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), ui.color.primary_main) end,
    function() reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), ui.color.light_gray) end,
  }

  for _, v in ipairs(color_pushes) do
    v()
  end

  return #color_pushes
end

function ui.LoadFonts(ctx)
  ui.font_face = script_path .. "/data/Roboto-Medium.ttf"
  ui.font = reaper.ImGui_CreateFontFromFile(ui.font_face)
  reaper.ImGui_Attach(ctx, ui.font)
end

function ui.LoadImages(ctx)
  ui.logo = reaper.ImGui_CreateImage(script_path .. "/data/reasoundly_32.png")
  reaper.ImGui_Attach(ctx, ui.logo)

  ui.img_arrowleft = reaper.ImGui_CreateImage(script_path .. "/data/arrowleft_16.png")
  reaper.ImGui_Attach(ctx, ui.img_arrowleft)

  ui.img_arrowright = reaper.ImGui_CreateImage(script_path .. "/data/arrowright_16.png")
  reaper.ImGui_Attach(ctx, ui.img_arrowright)

  ui.img_undo = reaper.ImGui_CreateImage(script_path .. "/data/undo_16.png")
  reaper.ImGui_Attach(ctx, ui.img_undo)

  ui.img_redo = reaper.ImGui_CreateImage(script_path .. "/data/redo_16.png")
  reaper.ImGui_Attach(ctx, ui.img_redo)

  ui.img_close = reaper.ImGui_CreateImage(script_path .. "/data/close_12.png")
  reaper.ImGui_Attach(ctx, ui.img_close)

  ui.img_checkbox_off = reaper.ImGui_CreateImage(script_path .. "/data/checkbox_off_16.png")
  reaper.ImGui_Attach(ctx, ui.img_checkbox_off)

  ui.img_checkbox_on = reaper.ImGui_CreateImage(script_path .. "/data/checkbox_on_16.png")
  reaper.ImGui_Attach(ctx, ui.img_checkbox_on)

  ui.img_toggle_off = reaper.ImGui_CreateImage(script_path .. "/data/toggle_off_40_20.png")
  reaper.ImGui_Attach(ctx, ui.img_toggle_off)

  ui.img_toggle_on = reaper.ImGui_CreateImage(script_path .. "/data/toggle_on_40_20.png")
  reaper.ImGui_Attach(ctx, ui.img_toggle_on)

  ui.img_radio_off = reaper.ImGui_CreateImage(script_path .. "/data/radio_off_16.png")
  reaper.ImGui_Attach(ctx, ui.img_radio_off)

  ui.img_radio_on = reaper.ImGui_CreateImage(script_path .. "/data/radio_on_16.png")
  reaper.ImGui_Attach(ctx, ui.img_radio_on)

  ui.img_settings = reaper.ImGui_CreateImage(script_path .. "/data/settings_16.png")
  reaper.ImGui_Attach(ctx, ui.img_settings)

  ui.img_play = reaper.ImGui_CreateImage(script_path .. "/data/play_18.png")
  reaper.ImGui_Attach(ctx, ui.img_play)

  ui.img_stop = reaper.ImGui_CreateImage(script_path .. "/data/stop_18.png")
  reaper.ImGui_Attach(ctx, ui.img_stop)

  ui.img_find_similar = reaper.ImGui_CreateImage(script_path .. "/data/find_similar_16.png")
  reaper.ImGui_Attach(ctx, ui.img_find_similar)

  ui.img_history = reaper.ImGui_CreateImage(script_path .. "/data/history_16.png")
  reaper.ImGui_Attach(ctx, ui.img_history)

  ui.img_info = reaper.ImGui_CreateImage(script_path .. "/data/information_16.png")
  reaper.ImGui_Attach(ctx, ui.img_info)
end

function ui.Title(ctx, window_name)
  ui.AdjustCursorPosition(ctx, 4, 4)
  reaper.ImGui_Image(ctx, ui.logo, 20, 20)
  reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x / 2)
  reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_big)
  reaper.ImGui_Text(ctx, ("ReaSoundly - %s"):format(window_name))
  reaper.ImGui_PopFont(ctx)
end

function ui.ShowActionPopup(ctx, action)
  if #action.commands > 0 then
    reaper.ImGui_SameLine(ctx)
    local space_x = reaper.ImGui_GetContentRegionAvail(ctx) - ui.window_padding_x - 70

    reaper.ImGui_Dummy(ctx, space_x, 16)
    reaper.ImGui_SameLine(ctx)

    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small)
    reaper.ImGui_Text(ctx, #action.commands .. " Actions")

    local text = ""
    for _, cmd in ipairs(action.commands) do
      if data.action_list[cmd] then
        text = text .. data.action_list[cmd] .. "\n"
      end
    end
    ui.Tooltip(ctx, text)
    reaper.ImGui_PopFont(ctx)
  end
end

local function PushCheckBoxAndRadioStyles(ctx, padding_x)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), ui.color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), ui.color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), ui.color.transparent)

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), ui.frame_padding, padding_x)

  return 3, 1
end

function ui.CheckBox(ctx, name, value, padding_x)
  local rv = false
  local img = value and ui.img_checkbox_on or ui.img_checkbox_off
  padding_x = padding_x or ui.frame_padding

  local color_pushes, style_pushes = PushCheckBoxAndRadioStyles(ctx, padding_x)

  if reaper.ImGui_ImageButton(ctx, "##" .. name, img, 16, 16) then
    rv = true
  end
  reaper.ImGui_PopStyleColor(ctx, color_pushes)

  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, name)

  reaper.ImGui_PopStyleVar(ctx, style_pushes)

  if reaper.ImGui_IsItemClicked(ctx, 0) then
    rv = true
  end

  if rv then
    value = not value
  end

  return rv, value
end

function ui.Toggle(ctx, name, value, padding_x)
  local rv = false
  local img = value and ui.img_toggle_on or ui.img_toggle_off
  local is_hovered = false
  padding_x = padding_x or ui.frame_padding

  local color_pushes, style_pushes = PushCheckBoxAndRadioStyles(ctx, padding_x)

  if reaper.ImGui_ImageButton(ctx, "##" .. name, img, 30, 15, 0, 0, 1, 1, nil, ui.hover_tints[name]) then
    rv = true
  end
  if reaper.ImGui_IsItemHovered(ctx) then is_hovered = is_hovered or true end

  reaper.ImGui_PopStyleColor(ctx, color_pushes)

  reaper.ImGui_SameLine(ctx)

  reaper.ImGui_Text(ctx, name)
  if reaper.ImGui_IsItemHovered(ctx) then is_hovered = is_hovered or true end

  reaper.ImGui_PopStyleVar(ctx, style_pushes)

  if reaper.ImGui_IsItemClicked(ctx, 0) then
    rv = true
  end

  if rv then
    value = not value
  end

  if is_hovered then ui.hover_tints[name] = ui.color.white else ui.hover_tints[name] = ui.color.light_white end

  return rv, value
end

function ui.PlayStopButton(ctx, name, is_playing, padding_x)
  local rv = false
  local img = is_playing and ui.img_stop or ui.img_play

  local color_pushes = 0
  if is_playing then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), ui.color.red)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), ui.color.red)
    color_pushes = 2
  else
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), ui.color.transparent)
    color_pushes = 1
  end

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), ui.frame_padding, padding_x)

  if reaper.ImGui_ImageButton(ctx, "##" .. name, img, 18, 18) then
    rv = true
  end
  reaper.ImGui_PopStyleColor(ctx, color_pushes)
  reaper.ImGui_PopStyleVar(ctx)

  return rv
end

function ui.RadioButton(ctx, name, value)
  local rv = false
  local img = value and ui.img_radio_on or ui.img_radio_off
  local color_pushes, style_pushes = PushCheckBoxAndRadioStyles(ctx, 0)

  if reaper.ImGui_ImageButton(ctx, "##" .. name, img, 16, 16, 0, 0, 1, 1, nil, ui.hover_tints[name]) then
    rv = true
  end
  ui.UpdateHoverTint(ctx, name)

  reaper.ImGui_PopStyleColor(ctx, color_pushes)
  reaper.ImGui_PopStyleVar(ctx, style_pushes)

  return rv
end

function ui.OptionsButton(ctx)
  reaper.ImGui_SameLine(ctx)
  local space_x = reaper.ImGui_GetContentRegionAvail(ctx) - 16 - ui.window_padding_x * 4

  reaper.ImGui_Dummy(ctx, space_x, 16)
  reaper.ImGui_SameLine(ctx)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), ui.color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), ui.color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), ui.color.transparent)

  local btn = reaper.ImGui_ImageButton(ctx, "##options", ui.img_settings, 16, 16, 0, 0, 1, 1, nil,
    ui.hover_tints["_settings"])
  reaper.ImGui_PopStyleColor(ctx, 3)

  ui.UpdateHoverTint(ctx, "_settings")

  if btn then
    local settings = reaper.NamedCommandLookup("_reasoundly_settings")
    reaper.Main_OnCommand(settings, 0)
  end
end

function ui.CloseButton(ctx)
  reaper.ImGui_SameLine(ctx)
  local space_x = reaper.ImGui_GetContentRegionAvail(ctx) - 16 - ui.window_padding_x

  reaper.ImGui_Dummy(ctx, space_x, 16)
  reaper.ImGui_SameLine(ctx)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), ui.color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), ui.color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), ui.color.transparent)

  local btn = reaper.ImGui_ImageButton(ctx, "##close", ui.img_close, 16, 16, 0, 0, 1, 1, 0, ui.hover_tints["_close"])

  ui.UpdateHoverTint(ctx, "_close")

  reaper.ImGui_PopStyleColor(ctx, 3)

  return btn
end

function ui.UpdateHoverTint(ctx, name)
  if reaper.ImGui_IsItemHovered(ctx) then
    ui.hover_tints[name] = ui.color.white
  else
    ui.hover_tints[name] = ui.color
        .light_white
  end
end

function ui.Tooltip(ctx, text)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 0)

  if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal()) and reaper.ImGui_BeginTooltip(ctx) then
    reaper.ImGui_Text(ctx, text)
    reaper.ImGui_EndTooltip(ctx)
  end

  reaper.ImGui_PopStyleVar(ctx)
end

function ui.HelperTooltip(ctx, text)
  reaper.ImGui_SameLine(ctx, 0, 2)
  reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small)
  reaper.ImGui_TextColored(ctx, ui.color.primary_hover, "?")
  reaper.ImGui_PopFont(ctx)

  ui.Tooltip(ctx, text)
end

function ui.PopupModal(ctx, title, text, btn_color, btn_color_hovered)
  local rv = false

  if btn_color then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), btn_color_hovered)
  end

  if reaper.ImGui_Button(ctx, title) then
    reaper.ImGui_OpenPopup(ctx, title)
  end

  if btn_color then reaper.ImGui_PopStyleColor(ctx, 2) end

  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

  if reaper.ImGui_BeginPopupModal(ctx, title, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(ctx, text)

    if reaper.ImGui_Button(ctx, "Yes", 100) then
      rv = true
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
    if reaper.ImGui_Button(ctx, "No", 100) then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end

  return rv
end

function ui.AdjustCursorPosition(ctx, x, y)
  local cur_x, cur_y = reaper.ImGui_GetCursorPos(ctx)
  reaper.ImGui_SetCursorPos(ctx, cur_x + x, cur_y + y)
end

-- other utility functions
function table.contains(table, value)
  for i, v in ipairs(table) do
    if v == value then return true end
  end

  return false
end
