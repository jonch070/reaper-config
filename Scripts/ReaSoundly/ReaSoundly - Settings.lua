local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Utilities.lua')
if not ReaSoundly.CheckDependencies() then return end -- exit early when dependencies do not exist

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d+"))

if version >= 7.03 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

local ctx = reaper.ImGui_CreateContext('ReaSoundly - Settings')

data = {
  actions = {},
}

map = {
  import_modes = "Ask Everytime\0",
  action_modes = "Show Action Chains\0Apply selected action silently\0Do Nothing\0"
}

function string.split(input, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(input, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local function Init()
  ui.LoadFonts(ctx)
  ui.LoadImages(ctx)

  data.action_list = ReaSoundly.QueryActionList()
  data.actions = ReaSoundly.LoadActions()

  ui.page = 0

  map.import_modes = map.import_modes .. table.concat(import_modes, "\0", 1, #import_modes)
  map.import_modes = map.import_modes .. "\0"

  ReaSoundly.LoadSettings()
end

local function Selectable(idx, name)
  local label
  label = ("\t%d\t%s"):format(idx, name)

  local sel = reaper.ImGui_Selectable(ctx, label, false, ui.selectable_flags)
  return sel
end

local function DragAndDrop(idx, table, element)
  if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
    reaper.ImGui_SetDragDropPayload(ctx, "DND_ACTIONS", tostring(idx))
    reaper.ImGui_Text(ctx, "Swap")
    reaper.ImGui_EndDragDropSource(ctx)
  end

  if reaper.ImGui_BeginDragDropTarget(ctx) then
    local rv, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_ACTIONS")
    if rv then
      local target_idx = tonumber(payload)
      -- swap actions
      table[idx] = table[target_idx]
      table[target_idx] = element
    end
    reaper.ImGui_EndDragDropTarget(ctx)
  end
end

local function Loop()
  if ReaSoundly.HasSettingsUpdate() then
    ReaSoundly.LoadSettings()
    ReaSoundly.UpdateSettings(0)
  end

  local viewport = reaper.ImGui_GetMainViewport(ctx)
  local x, y = reaper.ImGui_Viewport_GetCenter(viewport)
  local w, h = reaper.ImGui_Viewport_GetSize(viewport)
  local dpi = reaper.ImGui_GetWindowDpiScale(ctx)

  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_FirstUseEver(), 0.5, 0.5)
  reaper.ImGui_SetNextWindowSize(ctx, (w / 3) * dpi, (h / 2) * dpi, reaper.ImGui_Cond_FirstUseEver())

  local style_pushes = ui.PushStyles(ctx)
  local color_pushes = ui.PushColors(ctx)

  visible, ui.open = reaper.ImGui_Begin(ctx, "ReaSoundly - Settings", false, ui.window_flags)

  if visible then
    local title = "Settings"
    if ui.page > 0 then
      title = ("Edit Action Chain %d"):format(ui.page)
    end

    ui.Title(ctx, title)

    if ui.CloseButton(ctx) then ui.open = false end

    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size)

    if ui.page <= 0 then
      if reaper.ImGui_BeginChild(ctx, "Settings", 0, 0) then
        reaper.ImGui_Text(ctx, "Import Settings")

        rv, settings.default_fades = ui.Toggle(ctx, "Use REAPER default fades", settings.default_fades, 0)
        ui.HelperTooltip(ctx,
          "ReaSoundly uses linear fades. If this setting is enabled, the default fade shapes set in REAPER's preferences will be used.")

        reaper.ImGui_Text(ctx, "When importing multiple files:")
        reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
        reaper.ImGui_SetNextItemWidth(ctx, ui.item_width)
        ui.AdjustCursorPosition(ctx, 0, -5)
        rv, settings.default_import = reaper.ImGui_Combo(ctx, "##import_modes", settings.default_import,
          map.import_modes)

        if settings.default_import ~= 0 then
          reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
          reaper.ImGui_Image(ctx, ui.img_info, 16, 16)
          ui.Tooltip(ctx,
            "With this setting, the Import Page will not show up.\nYou can change this settings in the 'ReaSoundly - Settings' script.")
        end

        reaper.ImGui_Separator(ctx)

        reaper.ImGui_Text(ctx, "Action Chains")
        ui.HelperTooltip(ctx, "Click on an Action Chain to edit it.")

        reaper.ImGui_Text(ctx, "After import:")
        reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
        reaper.ImGui_SetNextItemWidth(ctx, ui.item_width)
        ui.AdjustCursorPosition(ctx, 0, -5)
        rv, settings.default_action_mode = reaper.ImGui_Combo(ctx, "##action_modes", settings.default_action_mode,
          map.action_modes)

        if settings.default_action_mode ~= 0 then
          reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
          reaper.ImGui_Image(ctx, ui.img_info, 16, 16)
          ui.Tooltip(ctx,
            "With this setting, the Actions Page will not show up.\nYou can change this settings in the 'ReaSoundly - Settings' script.")
        end

        for idx, action in ipairs(data.actions) do
          reaper.ImGui_Dummy(ctx, 5, 0)
          reaper.ImGui_SameLine(ctx)

          if settings.default_action_mode == 1 then
            local rv = ui.RadioButton(ctx, action.name, settings.default_action == idx)

            if rv then
              settings.default_action = idx
            end

            reaper.ImGui_SameLine(ctx, 0)
          end
          local sel = Selectable(idx, action.name)
          DragAndDrop(idx, data.actions, action)

          ui.ShowActionPopup(ctx, action)

          if sel then
            ui.page = idx
          end
        end

        if reaper.ImGui_Button(ctx, "\t+\t") then
          local idx = #data.actions + 1
          local set = {}
          set.name = ("Unnamed Action Chain %d"):format(idx)
          set.commands = {}
          table.insert(data.actions, set)
        end
        ui.Tooltip(ctx, "Add new Action Chain")

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "Launcher Settings")

        rv, settings.open_launcher_when_spotting = ui.Toggle(ctx, "Open Launcher when spotting files from Soundly",
          settings.open_launcher_when_spotting, 0)
        ui.HelperTooltip(ctx, "Opens the ReaSoundly launcher when spotting files from Soundly")

        rv, settings.close_after_run = ui.Toggle(ctx, "Close Launcher after executing an Action Chain",
          settings.close_after_run, 0)
        ui.HelperTooltip(ctx, "Automatically close the Launcher after executing an Action Chain from the list")

        rv, settings.close_unfocused = ui.Toggle(ctx, "Close Launcher when not focused", settings.close_unfocused, 0)
        ui.HelperTooltip(ctx, "Automatically close the Launcher when the Launcher window is not focused")

        rv, settings.show_footer_toolbar = ui.Toggle(ctx, "Show toolbar in Launcher footer",
          settings.show_footer_toolbar, 0)
        ui.HelperTooltip(ctx,
          "Toggle the visibility of the footer toolbar (Paste It, Find Similar, etc.) in the Launcher")

        local opacity = (settings.opacity / 255)
        reaper.ImGui_SetNextItemWidth(ctx, ui.item_width)
        rv, opacity = reaper.ImGui_SliderDouble(ctx, "Window Opacity##Window Opacity", opacity, 0.5, 1, "%.2f")

        if rv then
          settings.opacity = (opacity * 255)
        end

        reaper.ImGui_Separator(ctx)

        reaper.ImGui_Text(ctx, "Miscellaneous Settings")

        rv, settings.ignore_slices = ui.Toggle(ctx, "Treat all Cue Markers as Segments", settings.ignore_slices, 0)
        ui.HelperTooltip(ctx, "This option treats Soundly's Segments and Split markers equally.")

        if ui.PopupModal(ctx, "Restore default Action Chains", "Do you want to restore ReaSoundly's default Action Chains?\nThis will not overwrite your current Action Chains.") then
          ReaSoundly.RestoreDefaultActions()
        end
        ui.Tooltip(ctx, "Restore to default Actions Chains provided by Soundly")

        if ui.PopupModal(ctx, "Factory Reset", "Do you want to reset ReaSoundly to factory settings?", ui.color.red, ui.color.highlight_red) then
          ReaSoundly.FactoryReset()
        end
        ui.Tooltip(ctx, "Reset ReaSoundly to factory settings")

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "Action-specific Settings")

        reaper.ImGui_SetNextItemWidth(ctx, ui.item_width)
        rv, settings.crossfade_dur = reaper.ImGui_InputDouble(ctx, "Crossfade Duration (s)##CrossfadeDuration",
          settings.crossfade_dur, 0.05,
          0.05, "%.3f")
        if settings.crossfade_dur < 0 then settings.crossfade_dur = 0 end

        ui.HelperTooltip(ctx,
          "This setting is used for actions such as 'ReaSoundly - Fit items to time selection (Duplicate Items)'")

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "History Settings")

        reaper.ImGui_SetNextItemWidth(ctx, ui.item_width)
        rv, settings.history_limit = reaper.ImGui_InputInt(ctx, "History Limit##HistoryLimit", settings.history_limit, 1)
        if settings.history_limit < 1 then settings.history_limit = 1 end

        reaper.ImGui_EndChild(ctx)
      end
    else
      local go_back = false
      local delete = false

      if reaper.ImGui_ImageButton(ctx, "##back", ui.img_arrowleft, 16, 16) then
        go_back = true
      end
      ui.Tooltip(ctx, "Go Back")

      reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

      local action = data.actions[ui.page]
      rv, action.name = reaper.ImGui_InputText(ctx, "Name", action.name)

      reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

      if ui.PopupModal(ctx, "Delete", "Do you want to delete this Action Chain?", ui.color.red, ui.color.highlight_red) then
        delete = true
      end
      ui.Tooltip(ctx, "Delete this Action Chain")

      reaper.ImGui_Separator(ctx)

      reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small)

      if reaper.ImGui_Button(ctx, "Add Actions ...") then
        reaper.PromptForAction(1, 0, 0)
      end
      ui.HelperTooltip(ctx, "This will open REAPER's action list. Double click actions to add them to the Action Chain.")

      local avail_x = reaper.ImGui_GetContentRegionAvail(ctx)
      reaper.ImGui_SameLine(ctx, 0, avail_x - 175)
      reaper.ImGui_Text(ctx, #action.commands .. " Actions")
      ui.HelperTooltip(ctx, "Remove actions with left mouse button")

      local window_flags = reaper.ImGui_WindowFlags_HorizontalScrollbar()

      local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
      if reaper.ImGui_BeginChild(ctx, "Defined Actions", avail_x, avail_y, 1, window_flags) then
        for i, cmd in ipairs(action.commands) do
          if reaper.ImGui_Selectable(ctx, ("%d\t%s##%d"):format(i, data.action_list[cmd], i), false, ui.selectable_flags) then
            table.remove(action.commands, i)
          end

          DragAndDrop(i, action.commands, cmd)
        end

        reaper.ImGui_EndChild(ctx)
      end

      local cmd = reaper.PromptForAction(0, 0, 0)

      if cmd > 0 then
        local key = ReaSoundly.GetCommandKey(cmd)
        table.insert(action.commands, key)
      end

      if delete then
        go_back = true
        table.remove(data.actions, ui.page)
      end

      if go_back then
        if #action.name == 0 then
          action.name = ("Unnamed Action Chain %d"):format(ui.page)
        end
        ui.page = 0
        reaper.PromptForAction(-1, 0, 0)
        ReaSoundly.SaveActions()
      end

      reaper.ImGui_PopFont(ctx)
    end

    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PopStyleVar(ctx, style_pushes)
    reaper.ImGui_PopStyleColor(ctx, color_pushes)

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
      ui.open = false
    end

    reaper.ImGui_End(ctx)
  end
  if ui.open then
    reaper.defer(Loop)
  end
end

local function Exit()
  reaper.PromptForAction(-1, 0, 0)
  ReaSoundly.SaveActions()
  ReaSoundly.SaveSettings()

  -- Update soundly/update_settings ext state
  ReaSoundly.UpdateSettings(1)
end

Init()

reaper.defer(Loop)
reaper.atexit(Exit)
