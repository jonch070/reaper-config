-- MainWindow.lua - Main UI Component

MainWindow = {}

local GridView = require('components/Views/Grid/GridView')
local EnsemblerKeyboard = require('components/Keyboard/EnsemblerKeyboard')
local EnsembleHeader = require('components/Views/Main/EnsembleHeader')
local EnsemblePresetManager = require('components/Views/Main/EnsemblePresetManager')
local TabView = require('components/Views/TabView')
local TransformView = require('components/Views/Transform/TransformView')
local QuickBuilderView = require('components/Views/QuickBuilder/QuickBuilderView')
local ModalManager = require('components/Modals/ModalManager')

-- Configuration
local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 700

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

---Render the main window (including ImGui window setup)
---@param ctx ImGui_Context
---@return boolean windowShouldStayOpen
function MainWindow.render(ctx)
    -- Set window properties
    reaper.ImGui_SetNextWindowSize(ctx, WINDOW_WIDTH, WINDOW_HEIGHT, 
        reaper.ImGui_Cond_FirstUseEver())
    
    -- Main window
    local visible, open = reaper.ImGui_Begin(ctx, "Ensembler", true, reaper.ImGui_WindowFlags_NoCollapse())

    if visible then
        State.ui.window_focused = reaper.ImGui_IsWindowFocused(ctx)
        
        -- Render main window content
        MainWindow.renderContent(ctx)

        -- Render all modals
        ModalManager.renderAllModals(ctx)

        -- IMPORTANT: Handle end-of-frame processing for custom drag/drop
        -- Must be called right before ImGui_End to ensure proper z-order
        Draggable.end_of_frame(ctx)
        reaper.ImGui_End(ctx)
    end
    
    return open
end

---Render the main window content
---@param ctx ImGui_Context
function MainWindow.renderContent(ctx)
    local contentX, contentY = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- Layout calculations
    -- Main content at top + Keyboard at bottom (50px tall)
    local keyboardHeight = 50
    local spacing = 10
    local mainContentHeight = contentY - keyboardHeight - spacing

    -- Header
    EnsembleHeader.render(ctx)
    
    reaper.ImGui_Separator(ctx)
    
    -- Main content area with tabs
    TabView.render(ctx, {
        {
            id = "grid",
            name = "Grid",
            renderFunction = GridView.render
        },
        {
            id = "transform",
            name = "Transform",
            renderFunction = TransformView.render
        },
        {
            id = "quickbuilder",
            name = "Quick Build",
            renderFunction = QuickBuilderView.render
        }
    })
    
    -- Action buttons (Clear All, Reset)
    MainWindow.renderActionButtons(ctx)

    -- Keyboard
    EnsemblerKeyboard.render(ctx, contentX - 10, keyboardHeight - 10, "horizontal")

    -- Footer spacing
    reaper.ImGui_Spacing(ctx)
    
    -- Bottom controls: Divisi mode and controls
    reaper.ImGui_Separator(ctx)
end

--------------------------------------------------------------------------------
-- Sub-components
--------------------------------------------------------------------------------

---Render divisi mode controls
---@param ctx ImGui_Context
function MainWindow.renderDivisiControls(ctx)
    reaper.ImGui_Text(ctx, "Divisi Mode:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushItemWidth(ctx, 150)
    
    local divisiModes = "Bottom-up\0Top-down\0Fill voices\0"
    local changed, newMode = reaper.ImGui_Combo(ctx, "##divisi_mode", 
        State.ensemble.divisi_mode, divisiModes)
    
    if changed then
        State.ensemble.divisi_mode = newMode
        State.ensemble.is_modified = true
        State.ensemble.wasUpdated()
    end
    
    reaper.ImGui_PopItemWidth(ctx)
end

---Render action buttons (Clear All, Reset)
---@param ctx ImGui_Context
function MainWindow.renderActionButtons(ctx)
        
    if reaper.ImGui_Button(ctx, "Clear All", 80, 0) then
        -- TODO Presets integration
        -- if PresetsUI.is_ensemble_worth_saving() then
        --     State.ui.unsaved_dialog_context = "clear_all"
        --     State.ui.show_unsaved_dialog = true
        -- else
            State.ensemble.clear()
        -- end
    end
    
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Reset", 80, 0) then
        -- TODO Presets integration
        -- if PresetsUI.is_ensemble_worth_saving() then
        --     State.ui.unsaved_dialog_context = "reset"
        --     State.ui.show_unsaved_dialog = true
        -- else
            State.reset()
        -- end
    end
end

return MainWindow