-- State.lua - Global State Management
-- Shared state and configuration for all modules

require('types/types')
local Ensemble = require('modules/Ensemble')

State = {}

-- Configuration constants
State.config = {
    -- Debug logging configuration
    DEBUG_ENABLED = false,
    DEBUG_LEVEL = "DEBUG",  -- "DEBUG" | "WARN" | "ERROR"
    DEBUG_FEATURES = Debug.FEATURE.JSFX | Debug.FEATURE.TRACKS,     -- 0 = show all features

    -- Examples of feature filtering (combine with bitwise OR |):
    -- Show only PERSISTENCE:
    --   DEBUG_FEATURES = Debug.FEATURE.PERSISTENCE
    -- Show PERSISTENCE and JSFX:
    --   DEBUG_FEATURES = Debug.FEATURE.PERSISTENCE | Debug.FEATURE.JSFX
    -- Show UI, ENSEMBLE, and TRACKS:
    --   DEBUG_FEATURES = Debug.FEATURE.UI | Debug.FEATURE.ENSEMBLE | Debug.FEATURE.TRACKS

    MAX_VOICES = 10,
    FX_NAME = "JS: Ensembler Filter",
    EXTSTATE_SECTION = "Ensembler",
    PRESET_PATH = reaper.GetResourcePath() .. "/Scripts/NW/Ensembler/presets/",
    CONFIG_PATH = reaper.GetResourcePath() .. "/Scripts/NW/Ensembler/config/",
    DEFAULT_ENSEMBLE_NAME = "New Ensemble",
    DEFAULT_SECTION_NAME = "New Section",
    
    -- FIXED: Updated parameter mapping to use indices 0-17 (all within ReaScript's visible range)
    JSFX_PARAM_MAP = {
        -- Configuration parameters (ReaScript control)
        voice_number = 0,                -- slider1
        total_voices = 1,                -- slider2
        divisi_mode = 2,                 -- slider3  
        transposition = 3,               -- slider4
        debug_mode = 4,                  -- slider5
        note_on_count = 5,               -- slider6 (read-only)
        note_off_count = 6,              -- slider7 (read-only)
        chord_tone = 7,                  -- slider8
        chord_tone_anchor_note = 8,      -- slider9
        
        -- Read-only status parameters (ReaScript readable) - FIXED: moved to lower indices
        my_voiced_note = 9,              -- slider10 (was slider20)
        is_master_reporter = 10,         -- slider11 (was slider21)
        chord_root = 11,                 -- slider12 (was slider22)
        chord_quality = 12,              -- slider13 (was slider23)
        unassigned_notes_low = 13,       -- slider14
        unassigned_notes_high = 14,      -- slider15
        unassigned_notes_high2 = 15,     -- slider16
        unassigned_notes_high3 = 16,     -- slider17

        -- GMEM coordination (set by Lua)
        instrument_slot_number = 17,     -- slider18 - sequential slot number for GMEM addressing
                                         --            Used by both transform system (zones 1000-7199)
                                         --            and retroactive recording (zones 100,000-499,999)
        project_time_offset = 18,        -- slider19 - project timecode offset for retroactive timing
        transform_update_trigger = 19    -- slider20 - increments on each transform write to trigger @slider
    },
    -- Available chord tones configuration (values are semitones from root)
    CHORD_TONES = {
        {value = 0, name = "Root"},
        {value = 4, name = "Third"}, 
        {value = 7, name = "Fifth"},
        {value = 10, name = "7th"}
    },
    
    -- Default transform columns
    DEFAULT_TRANSFORM_COLUMNS = {"velocity", "cc1", "cc11"},

    -- Note names for display and conversion
    NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"},

    -- Transform type constants (must match JSFX)
    TRANSFORM_TYPE = {
        NONE = 0,
        SCALE = 1,
        FIXED = 2,
        IGNORE = 3
    }
}

-- Parameter ID mapping for transforms (must match JSFX)
State.PARAMETER_TO_ID = {
    velocity = 0
}
-- Build CC parameter mapping (cc1 = 1, cc2 = 2, etc.)
for i = 1, 127 do
    State.PARAMETER_TO_ID["cc" .. i] = i
end

---Get transform type ID from transformer type string
---@param transformType string "scale", "fixed", "ignore", or "none"
---@return number typeId
function State.getTransformTypeId(transformType)
    if transformType == "scale" then
        return State.config.TRANSFORM_TYPE.SCALE
    elseif transformType == "fixed" then
        return State.config.TRANSFORM_TYPE.FIXED
    elseif transformType == "ignore" then
        return State.config.TRANSFORM_TYPE.IGNORE
    else
        return State.config.TRANSFORM_TYPE.NONE
    end
end

-- Keep config structure intact
local original_config_structure = {
    CHORD_TONES = State.config.CHORD_TONES
}

-- Ensemble state
State.ensemble = Ensemble

-- UI state
State.ui = {
    
    -- Focus management for chord tone dropdowns
    focus_chord_tone_dropdown = {}, -- per lane focus state for chord tone selector
    focus_target_note_dropdown = {}, -- per lane focus state for target note selector
    
    show_save_dialog = false,
    show_load_dialog = false,
    show_unsaved_dialog = false,
    close_after_dialog = false,
    save_error = nil,
    save_feedback_time = 0,
    preset_filter = "",  -- Filter for load dialog
    hovered_voice = 0,
    window_focused = false,
    window_open = true,

    last_midi_poll = 0,
    
    -- Filter popup state
    ---@type FilterPopupState|nil
    activeFilterPopup = nil,
    
    -- Callback for active filter popup
    ---@type function|nil
    activeFilterPopupCallback = nil
}

-- ImGui context and resources
State.imgui = {
    ctx = nil,
    font = nil,
    font_small = nil
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

-- Initialize function
function State.init()
    State.ensemble.is_active = true
    
    -- Initialize UI state arrays
    for i = 1, State.config.MAX_VOICES do
        -- Initialize focus arrays for chord tone dropdowns
        -- TODO IS THIS USED ANYMORE?
        State.ui.focus_chord_tone_dropdown[i] = false
        State.ui.focus_target_note_dropdown[i] = false
    end
end

function State.reset() 
    State.init()
    EnsemblePersistence.clearTempState()
    -- TODO load Ensemble default preset instead of this
    State.ensemble.initializeDefaultEnsemble()
    -- Close window so it starts fresh next time
    State.ui.window_open = false
end


--------------------------------------------------------------------------------
-- Debugging
--------------------------------------------------------------------------------

-- Table to string utility (used by Debug module)
function State.table_to_string(tbl, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    local result = "{\n"
    
    for key, value in pairs(tbl) do
        local key_str = type(key) == "string" and '"' .. key .. '"' or tostring(key)
        
        if type(value) == "table" then
            result = result .. spacing .. "  " .. key_str .. " = " .. State.table_to_string(value, indent + 1) .. ",\n"
        elseif type(value) == "function" then
            -- Skip functions as requested
        elseif type(value) == "string" then
            result = result .. spacing .. "  " .. key_str .. ' = "' .. value .. '",\n'
        else
            result = result .. spacing .. "  " .. key_str .. " = " .. tostring(value) .. ",\n"
        end
    end
    
    result = result .. spacing .. "}"
    return result
end

-- Temporary backwards compatibility stubs (remove after migration complete)
-- This allows old debug_log() calls to still work during gradual migration
function State.debug_log(message)
    Debug.log(message, Debug.FEATURE.ENSEMBLE)
end

function debug_log(message)
    Debug.log(message, Debug.FEATURE.ENSEMBLE)
end

--------------------------------------------------------------------------------
-- Reaper State
-- TODO feels like this should be somewhere else but not sure where yet
--------------------------------------------------------------------------------

-- Get toolbar button state for toggle
function State.set_toolbar_button_state(state)
    local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, state or 0)
    reaper.RefreshToolbar2(sec, cmd)
end

return State