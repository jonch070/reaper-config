-- AppController.lua - Application Lifecycle Management

AppController = {}

-- Local references for performance
local ctx = nil
local ImGui = reaper.ImGui_CreateContext and reaper or nil

-- Configuration
local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 700

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

---Initialize the application
---@return boolean success
function AppController.init()
    if not ImGui then
        return false
    end

    -- Initialize state
    State.init()

    -- Attach to shared memory for JSFX communication
    reaper.gmem_attach("ensembler")
    debug_log("Attached to gmem 'ensembler'")

    -- Create ImGui context
    ctx = ImGui.ImGui_CreateContext('Ensembler')
    State.imgui.ctx = ctx

    -- Try to create custom font
    State.imgui.font = ImGui.ImGui_CreateFont('sans-serif', 14)
    if State.imgui.font then
        ImGui.ImGui_Attach(ctx, State.imgui.font)
    end

    -- Try to load temp state
    if not EnsemblePersistence.loadTempState() then
        -- No temp state, initialize with default ensemble
        State.ensemble.initializeDefaultEnsemble()
    end
    
    -- Set toolbar button state
    State.set_toolbar_button_state(1)
    
    debug_log("AppController initialized")
    return true
end

---Start the application
---@return boolean success
function AppController.start()
    if not ctx then
        if not AppController.init() then
            return false
        end
    end

    -- Indicate the window should be open and start the loop
    State.ui.window_open = true
    AppController.loop()
    return true
end

--------------------------------------------------------------------------------
-- Main Application Loop
--------------------------------------------------------------------------------

---Main application loop - handles lifecycle and UI rendering
function AppController.loop()
    -- Check if we should close after dialog
    if State.ui.close_after_dialog then
        State.ui.close_after_dialog = false
        AppController.deactivateEnsemble()
        return
    end

    -- Render window if it should be open
    local windowShouldStayOpen = true
    if State.ui.window_open then
        windowShouldStayOpen = MainWindow.render(ctx)
        
        -- Handle window close via X button
        if not windowShouldStayOpen then
            State.ui.window_open = false
            State.set_toolbar_button_state(0)
        end
    end
    
    -- Check for external track selection changes (monitoring for deactivation)
    if State.ensemble.is_active and not ReaperTracks.doesReaperSelectedTracksMatchEnsemble() then
        -- User changed selection outside of our control - deactivate ensemble
        AppController.deactivateEnsemble()
        return
    end

    -- Continue loop if ensemble is still active
    if State.ensemble.is_active then
        RetroactiveRecord.poll()
        reaper.defer(AppController.loop)
    else
        -- Ensemble inactive - stop completely
        State.set_toolbar_button_state(0)
    end
end

--------------------------------------------------------------------------------
-- Ensemble Lifecycle Management
--------------------------------------------------------------------------------

---Deactivate the ensemble and handle cleanup
function AppController.deactivateEnsemble()
    State.ui.window_open = false

    if State.ensemble.is_active then
        INFX.cleanup_all_tracks()
        State.ensemble.is_active = false
    end

    State.set_toolbar_button_state(0)
    EnsemblePersistence.saveTempState()
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

---Cleanup function for application exit
function AppController.cleanup()
    -- Don't deactivate on cleanup - ensemble stays active
    State.set_toolbar_button_state(0)
end

-- Register cleanup on exit
reaper.atexit(AppController.cleanup)

return AppController