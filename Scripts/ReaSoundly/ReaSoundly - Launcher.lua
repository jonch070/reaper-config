local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Utilities.lua')
if not ReaSoundly.CheckDependencies() then return end -- exit early when dependencies do not exist

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

local ctx = reaper.ImGui_CreateContext('ReaSoundly - Launcher')

-- disable keyboard navigation
local config_flags = reaper.ImGui_ConfigFlags_None()
reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_Flags(), config_flags)

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d+"))

if version >= 7.03 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

data = {
  version = "0.9.1 (beta)",
  action_list = nil,
  actions = {},
  ids = {},
  selected_items = {},
  selected_item_count = 0,
  has_segment_markers = false,
  has_segment_splits = false,
  has_handle_size = false,
  proj_state_changes = 0,
  last_cur_pos = 0,
  disabled_actions = {},
  update_settings = false,
  hovered_action_idx = -1,
  history_cmd = nil,
  findsimilar_cmd = nil,
}

local function Init()
  -- get files and filecount
  data.filecount = ReaSoundly.GetFileCount()
  data.files = ReaSoundly.GetFiles()
  data.has_segment_splits = ReaSoundly.HasSegmentSplits()
  data.has_handle_size = ReaSoundly.HasHandleSize()

  ui.LoadFonts(ctx)
  ui.LoadImages(ctx)

  data.actions = ReaSoundly.LoadActions()
  data.action_list = ReaSoundly.QueryActionList()

  ReaSoundly.LoadSettings()

  data.history_cmd = reaper.NamedCommandLookup("_reasoundly_history")
  data.findsimilar_cmd = reaper.NamedCommandLookup("_reasoundly_find_similar")
end

local function Selectable(idx, name)
  local label
  if idx <= ui.shortcut_limit then label = ("\t%d\t%s"):format(idx, name) else label = ("\t\t%s"):format(name) end
  local sel = reaper.ImGui_Selectable(ctx, label, ui.cur_idx == idx, ui.selectable_flags)
  return sel
end

local function IsActionDisabled(idx, action)
  -- disable selection if there are no selected items
  -- or if the action is a segment action and there are splits

  local segments_checked = data.has_segment_splits or not data.has_segment_markers or data.has_handle_size

  local is_disabled = (data.selected_item_count == 0) or
      ((ReaSoundly.IsSegmentAction)(action.name) and segments_checked)

  data.disabled_actions[idx] = is_disabled
  return is_disabled
end

local function KeyboardNavigation(upper_limit)
  local pressed = false
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) then
    ui.cur_idx = ui.cur_idx + 1
    pressed = true
  end

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) then
    ui.cur_idx = ui.cur_idx - 1
    pressed = true
  end

  if pressed then
    if ui.cur_idx < 1 then ui.cur_idx = 1 end
    if ui.cur_idx > upper_limit then ui.cur_idx = upper_limit end
  end

  -- Redo/Undo navigation
  if (reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow()))
      or (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z())) then
    ui.undo_key = -1
  end

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow())
      or (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Y()))
      or (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z())) then
    ui.undo_key = 1
  end
end

local function ExecuteActionChain(action)
  reaper.Undo_BeginBlock2(0)

  for _, cmd in ipairs(action.commands) do
    if tonumber(cmd) then
      reaper.Main_OnCommand(cmd, 0)
    else
      reaper.Main_OnCommand(reaper.NamedCommandLookup(cmd), 0)
    end
  end

  reaper.Undo_EndBlock2(0, ("ReaSoundly - %s"):format(action.name), 0)
end

local function CountSelectedItems()
  local count = 0
  for _, v in pairs(data.selected_items) do
    if v then
      count = count + 1
    end
  end
  return count
end

local function ResetSelectedItemTable(val)
  data.selected_items = {}
  for _, v in pairs(data.ids) do
    data.selected_items[v] = val
  end

  data.selected_item_count = CountSelectedItems()
end

local function CheckSelectedItemsForSegments()
  data.has_segment_markers = false
  if data.has_segment_splits then
    return
  end

  if data.has_handle_size then
    return
  end

  for _, file in pairs(data.files) do
    local is_selected = data.selected_items[file.soundlyFileID]
    if is_selected and ReaSoundly.HasSegmentMarkers(file) then
      data.has_segment_markers = true
      break
    end
  end
end

local function ExecuteImport(mode)
  data.last_cur_pos = reaper.GetCursorPositionEx(0)

  ReaSoundly.ImportFiles(mode)
  ui.cur_idx = 1

  if settings.default_action_mode == 0 then
    ui.page = 2
    ui.cur_idx = 1
  elseif settings.default_action_mode == 1 then
    ui.open = false
    ExecuteActionChain(data.actions[settings.default_action])
  else
    ui.open = false
  end

  data.ids = ReaSoundly.CacheImportedItemsById(data.files)
  ResetSelectedItemTable(true)
  CheckSelectedItemsForSegments()

  ReaSoundly.SaveImportMode(mode)
end

local function UndoButton()
  return reaper.ImGui_ImageButton(ctx, "##Undo", ui.img_undo, 14, 14) or ui.undo_key == -1
end

local function RedoButton()
  return reaper.ImGui_ImageButton(ctx, "##Redo", ui.img_redo, 14, 14) or ui.undo_key == 1
end

local function SelectImportedItems()
  local color = data.has_segment_splits and ui.color.violet or ui.color.primary_main
  local hover_color = data.has_segment_splits and ui.color.violet_hover or ui.color.primary_hover
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover_color)

  if reaper.ImGui_Button(ctx, ("%d imported Items ..."):format(data.filecount)) then
    reaper.ImGui_OpenPopup(ctx, "##Select imported items")
  end

  reaper.ImGui_PopStyleColor(ctx, 2)

  if reaper.ImGui_BeginPopup(ctx, "##Select imported items") then
    local btn_pressed = -1
    if reaper.ImGui_SmallButton(ctx, "Select all") then
      btn_pressed = 1
    end

    reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

    if reaper.ImGui_SmallButton(ctx, "Unselect all") then
      btn_pressed = 0
    end

    if btn_pressed ~= -1 then
      local state = btn_pressed == 1 and true or false
      ResetSelectedItemTable(state)
      ReaSoundly.SelectItemsById(data.ids, state)
      CheckSelectedItemsForSegments()
    end

    for _, file in pairs(data.files) do
      local id = ReaSoundly.BuildFileId(file)
      local is_selected = data.selected_items[id]
      local rv, val = ui.CheckBox(ctx, ReaSoundly.GetNameFromFilePath(file.filePath), is_selected, 0)

      if rv then
        ReaSoundly.SelectItemsById({ id }, val)
        data.selected_items[id] = val
        CheckSelectedItemsForSegments()
        data.selected_item_count = CountSelectedItems()
      end
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

local function UpdateSelectedItems()
  -- update selected files based on selected media items
  data.proj_state_changes = reaper.GetProjectStateChangeCount(0)
  if data.proj_state_changes > 0 then
    data.selected_items = {}
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local file = ReaSoundly.FindTakeInFiles(data.files, item)

      if file then
        data.selected_items[ReaSoundly.BuildFileId(file)] = true
      end
    end

    data.selected_item_count = CountSelectedItems()

    data.proj_state_changes = 0
  end
end

local function RenderImportPage()
  if data.filecount > 1 then
    ui.Title(ctx, "Import")

    reaper.ImGui_SameLine(ctx)

    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_big)
    local import_type = data.has_segment_splits and "Segments" or "Files"
    local heading_color = data.has_segment_splits and ui.color.violet or ui.color.primary_hover

    -- capitalize first letter of import type
    reaper.ImGui_TextColored(ctx, heading_color,
      (" %d %s"):format(data.filecount, import_type))
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small)

      local text = ""
      for _, v in ipairs(data.files) do
        text = text .. ReaSoundly.GetNameFromFilePath(v.filePath) .. "\n"
      end
      ui.Tooltip(ctx, text)

      reaper.ImGui_PopFont(ctx)
    end

    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

    ui.OptionsButton(ctx)
    if ui.CloseButton(ctx) then ui.open = false end

    for i, name in ipairs(import_modes) do
      local sel = Selectable(i, name)

      local keypressed
      if i <= 5 then
        keypressed = reaper.ImGui_IsKeyPressed(ctx, reaper["ImGui_Key_" .. i]())
      end

      if sel or keypressed then
        ExecuteImport(i)
      end
    end

    KeyboardNavigation(#import_modes)

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow()) then
      ExecuteImport(ui.cur_idx)
    end
  else
    ExecuteImport(0) -- execute import for one file
  end
end

local function ToolbarButton(name, img, cmd)
  if cmd == 0 then return end

  local btn
  if not img then
    btn = reaper.ImGui_Button(ctx, name)
  else
    local w_text = reaper.ImGui_CalcTextSize(ctx, name)
    local padding = 10
    -- btn = reaper.ImGui_ImageButton(ctx, ("##%s"):format(name), img, 16 + w_text, 16)
    btn = reaper.ImGui_Button(ctx, ("##%s"):format(name), 16 + w_text + (padding * 3), 32)
    local x, y = reaper.ImGui_GetItemRectMin(ctx)
    local drawlist = reaper.ImGui_GetWindowDrawList(ctx)
    x = x + padding
    y = y + padding
    reaper.ImGui_DrawList_AddImage(drawlist, img, x, y, x + 16, y + 16)
    reaper.ImGui_DrawList_AddText(drawlist, x + 16 + padding, y, ui.color.white, name)
  end

  if btn then
    reaper.Main_OnCommand(cmd, 0)
  end

  reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
end

local function RenderActionsPage()
  ui.Title(ctx, "Actions")

  reaper.ImGui_PushFont(ctx, ui.font, ui.font_size)

  local last_undo = reaper.Undo_CanUndo2(0)
  local last_redo = reaper.Undo_CanRedo2(0)

  local is_last_undo
  -- check if the last undo is ReaSoundly import
  if last_undo then
    is_last_undo = string.find(last_undo, "ReaSoundly") and string.find(last_undo, "Import")
  end

  reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x * 2)

  reaper.ImGui_BeginDisabled(ctx, data.filecount == 1 and is_last_undo ~= nil)

  if UndoButton() then
    reaper.Undo_DoUndo2(0)
    ui.undo_key = 0
    if is_last_undo then
      ui.reimport = true -- use this variable to enable import page when undoing in silent mode
      ui.page = 1
      ui.cur_idx = 1
      reaper.SetEditCurPos2(0, data.last_cur_pos, false, false)
    end
  end

  if is_last_undo and data.filecount > 1 then
    ui.Tooltip(ctx, "Back to Import Page")
  else
    ui.Tooltip(ctx, ('Undo "%s"'):format(last_undo))
  end

  reaper.ImGui_EndDisabled(ctx)

  reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

  local can_redo = last_redo and true or false
  reaper.ImGui_BeginDisabled(ctx, not can_redo)

  if RedoButton() then
    reaper.Undo_DoRedo2(0)
    ui.undo_key = 0
  end
  ui.Tooltip(ctx, ('Redo "%s"'):format(last_redo))

  reaper.ImGui_EndDisabled(ctx)

  reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

  SelectImportedItems()

  reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

  reaper.ImGui_PopFont(ctx)

  ui.OptionsButton(ctx)
  if ui.CloseButton(ctx) then ui.open = false end

  data.disabled_actions = {}

  local child_height = 0
  if settings.show_footer_toolbar then
    child_height = -reaper.ImGui_GetFrameHeightWithSpacing(ctx) * 1.5
  end

  if reaper.ImGui_BeginChild(ctx, "Action Chains", 0, child_height, 2) then
    for i, action in ipairs(data.actions) do
      local is_disabled = IsActionDisabled(i, action)

      reaper.ImGui_BeginDisabled(ctx, is_disabled)

      local sel = Selectable(i, action.name)

      if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
        data.hovered_action_idx = i
      end

      reaper.ImGui_EndDisabled(ctx)

      ui.ShowActionPopup(ctx, action)

      if i == ui.shortcut_limit then
        reaper.ImGui_Separator(ctx)
        ui.is_default_hovered = false
      end

      if not is_disabled then
        local keypressed
        if i <= ui.shortcut_limit then
          keypressed = reaper.ImGui_IsKeyPressed(ctx, reaper["ImGui_Key_" .. i]())
        end

        if sel or keypressed then
          ui.cur_idx = i
          ExecuteActionChain(action)
          if settings.close_after_run then
            ui.open = false
          end
        end
      end
    end
    reaper.ImGui_EndChild(ctx)
  end

  KeyboardNavigation(#data.actions)

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter())
      and not data.disabled_actions[ui.cur_idx] then
    ExecuteActionChain(data.actions[ui.cur_idx])
  end

  if settings.show_footer_toolbar then
    -- Additional toolbar
    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small)

    reaper.ImGui_Separator(ctx)
    ToolbarButton("Find Similar", ui.img_find_similar, data.findsimilar_cmd)
    ui.Tooltip(ctx, "Find sounds in Soundly similar to the selected items.")
    ToolbarButton("History", ui.img_history, data.history_cmd)
    ui.Tooltip(ctx, "Runs ReaSoundly History")

    reaper.ImGui_PopFont(ctx)

    local space_x = reaper.ImGui_GetContentRegionAvail(ctx) - ui.window_padding_x - 100

    -- Show Version number in Footer
    reaper.ImGui_Dummy(ctx, space_x, 0)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small * 0.8)
    reaper.ImGui_Text(ctx, ("Version %s"):format(data.version))
    reaper.ImGui_PopFont(ctx)
  end
end

local function Loop()
  -- Update action list and settings if they've changed
  if ReaSoundly.HasSettingsUpdate() then
    data.actions = ReaSoundly.LoadActions()
    data.action_list = ReaSoundly.QueryActionList()

    ReaSoundly.LoadSettings()
    ReaSoundly.UpdateSettings(0)
  end

  UpdateSelectedItems()

  local viewport = reaper.ImGui_GetMainViewport(ctx)
  local x, y = reaper.ImGui_Viewport_GetCenter(viewport)
  local w, h = reaper.ImGui_Viewport_GetSize(viewport)
  local dpi = reaper.ImGui_GetWindowDpiScale(ctx)

  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_FirstUseEver(), 0.5, 0.5)
  reaper.ImGui_SetNextWindowSize(ctx, (w / 3) * dpi, (h / 3) * dpi, reaper.ImGui_Cond_FirstUseEver())

  local style_pushes = ui.PushStyles(ctx)
  local color_pushes = ui.PushColors(ctx)

  visible, ui.open = reaper.ImGui_Begin(ctx, "ReaSoundly - Launcher", false, ui.window_flags)
  if visible then
    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size)

    -- data.update_settings = false

    if ui.page == 1 then -- Import Page
      if settings.default_import == 0 or ui.reimport then
        RenderImportPage()
      else
        ExecuteImport(settings.default_import)
      end
    elseif ui.page == 2 then -- Actions Page
      -- if settings.default_action_mode == 1 then

      --   ui.open = false
      -- elseif settings.default_action_mode == 2 then
      --   ui.open = false
      -- end

      RenderActionsPage()
    end

    -- Handle window close when unfocused on action page
    if not reaper.ImGui_IsWindowFocused(ctx) and settings.close_unfocused and ui.page == 2 then
      ui.open = false
    end

    -- Handle window close when escape is pressed
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
      ui.open = false
    end

    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PopStyleVar(ctx, style_pushes)
    reaper.ImGui_PopStyleColor(ctx, color_pushes)

    -- Save settings if they've changed
    if data.update_settings then
      ReaSoundly.SaveSettings()
      ReaSoundly.UpdateSettings(1)
      data.update_settings = false
    end

    reaper.ImGui_End(ctx)
  end

  if ui.open then
    reaper.defer(Loop)
  end
end

function Exit()
  ReaSoundly.SaveSettings()
end

Init()

-- if there is no data, there is no need to call the launcher. Inform the user and exit
if not data.files or data.filecount == 0 then
  reaper.ShowMessageBox(
    "There are no files cached from Soundly.\nPlease import some files first using the ReaSoundly option in Soundly.",
    "ReaSoundly", 0)
  return
end

reaper.defer(Loop)
reaper.atexit(Exit)
