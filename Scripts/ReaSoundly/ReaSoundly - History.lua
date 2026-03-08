local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Utilities.lua')
if not ReaSoundly.CheckDependencies() then return end -- exit early when dependencies do not exist

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

local ctx = reaper.ImGui_CreateContext("ReaSoundly - History")

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d+"))

if version >= 7.03 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

data = {
  history = {},
  added_files = {},
  file_source = nil,
  preview = false,
}

local function Init()
  ui.LoadFonts(ctx)
  ui.LoadImages(ctx)

  ReaSoundly.LoadSettings()
  -- load history
  data.history = ReaSoundly.LoadSpotHistory()
end

local function Selectable(idx, name, added, file_exists)
  local label = ("%d\t%s##%d"):format(idx, name, idx)
  local col_pushes = 0

  if added then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), ui.color.green)
    col_pushes = col_pushes + 1
  end
  if not file_exists then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), ui.color.highlight_red)
    col_pushes = col_pushes + 1
  end

  local sel = reaper.ImGui_Selectable(ctx, label, idx == ui.cur_idx,
    ui.selectable_flags | reaper.ImGui_SelectableFlags_AllowDoubleClick())

  if file_exists then
    ui.Tooltip(ctx, "Use enter or double-click an entry to import the selected file.")
  else
    ui.Tooltip(ctx, "The file has been deleted or moved.")
  end

  reaper.ImGui_PopStyleColor(ctx, col_pushes)

  return sel
end

local function Loop()
  if ReaSoundly.HasSpotHistoryUpdate() then
    data.history = ReaSoundly.LoadSpotHistory()
    reaper.SetExtState("ReaSoundly", "update_history", "0", false)
  end

  local x, y = reaper.GetMousePosition()

  local viewport = reaper.ImGui_GetMainViewport(ctx)
  local w, h = reaper.ImGui_Viewport_GetSize(viewport)
  local dpi = reaper.ImGui_GetWindowDpiScale(ctx)

  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Once(), 0, 0)
  reaper.ImGui_SetNextWindowSize(ctx, 0, 0, reaper.ImGui_Cond_Always())

  local w, h = reaper.ImGui_GetWindowSize(ctx)

  local style_pushes = ui.PushStyles(ctx)
  local color_pushes = ui.PushColors(ctx)

  visible, ui.open = reaper.ImGui_Begin(ctx, "ReaSoundly - History", true)
  if visible then
    reaper.ImGui_PushFont(ctx, ui.font, ui.font_size_small)

    -- Autoplay toggle
    rv, settings.autoplay = ui.Toggle(ctx, "Autoplay", settings.autoplay, 0)
    if rv then
      reaper.Xen_StopSourcePreview(-1)
      ui.playing_idx = 0
    end

    reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

    rv, settings.open_launcher_paste_it = ui.Toggle(ctx, "Open ReaSoundly Launcher after import",
      settings.open_launcher_paste_it, 0)

    reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)

    ui.AdjustCursorPosition(ctx, 0, -5)

    if reaper.ImGui_Button(ctx, "Clear History") then
      ReaSoundly.ClearSpotHistory()
      data.file_source = nil
      data.preview = false
      data.history = ReaSoundly.LoadSpotHistory()
    end

    -- if data.file_source then
    --   local label = data.preview and "Stop Preview" or "Start Preview"
    --   if reaper.ImGui_Button(ctx, label) then
    --     if not data.preview then
    --       reaper.Xen_StartSourcePreview(data.file_source, 1, false, 0)
    --       data.preview = true
    --     else
    --       reaper.Xen_StopSourcePreview(-1)
    --       data.preview = false
    --     end
    --   end
    -- end

    for i, file in ipairs(data.history) do
      local file_name = ReaSoundly.GetNameFromFilePath(file.filePath)

      -- check if file is already added
      local added = false
      for _, v in ipairs(data.added_files) do
        if v == file.filePath then
          added = true
          break
        end
      end

      -- disable elements if file is missing
      local file_exists = ReaSoundly.FileExists(file.filePath)

      -- reaper.ImGui_BeginDisabled(ctx, not file_exists)

      if ui.PlayStopButton(ctx, ("Play %d"):format(i), i == ui.playing_idx, 0) and file_exists then
        reaper.Xen_StopSourcePreview(-1)
        if ui.playing_idx == i then
          ui.playing_idx = 0
        else
          ui.playing_idx = i
          data.file_source = reaper.PCM_Source_CreateFromFile(file.filePath)
          reaper.Xen_StartSourcePreview(data.file_source, 1, false, 0)
        end
      end

      reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
      local sel = Selectable(i, file_name, added, file_exists)

      if sel and file_exists then
        -- TODO update detail display
        ui.cur_idx = i

        if settings.autoplay then
          reaper.Xen_StopSourcePreview(-1)
          ui.playing_idx = i
          data.file_source = reaper.PCM_Source_CreateFromFile(file.filePath)
          reaper.Xen_StartSourcePreview(data.file_source, 1, false, 0)
        end

        if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
          -- if Open Launcher is set, overwrite the file import data and open the launcher
          if settings.open_launcher_paste_it then
            ReaSoundly.OverwriteFiles({ ["files"] = { file } })

            local launcher = reaper.NamedCommandLookup("_reasoundly_launcher")
            reaper.Main_OnCommand(launcher, 0)
          else
            -- Insert File at cursor position
            reaper.InsertMedia(file.filePath, 0)
            table.insert(data.added_files, file.filePath)
          end
        end
      end

      -- reaper.ImGui_EndDisabled(ctx)

      -- if not file_exists then
      --   reaper.ImGui_SameLine(ctx, 0, ui.item_spacing_x)
      --   reaper.ImGui_TextColored(ctx, ui.color.highlight_red, ("!"))
      --   ui.Tooltip(ctx, "The file has been deleted or moved")
      -- end
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

function Exit()
  reaper.Xen_StopSourcePreview(-1)
  ReaSoundly.SaveSettings()
end

Init()

-- -- if there is no data, there is no need to call the launcher. Inform the user and exit
-- if not data.files or data.filecount == 0 then
--     reaper.ShowMessageBox(
--         "There are no files cached from Soundly.\nPlease import some files first using the ReaSoundly option in Soundly.",
--         "ReaSoundly", 0)
--     return
-- end

reaper.defer(Loop)
reaper.atexit(Exit)
