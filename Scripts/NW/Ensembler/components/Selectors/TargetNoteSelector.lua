-- components/TargetNoteSelector.lua - Target Note Selection Component

require('types/types')
local ScrollableDropdown = require('components/Selectors/ScrollableDropdown')

local TargetNoteSelector = {}

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.UI)
end

-- Internal state for focus management
local focusState = {}

---Get note name from MIDI number (matching INFX.noteToMidi convention)
---@param midiNote integer MIDI note number (0-127)
---@return string noteName Note name with octave (e.g. "C0")
local function getNoteName(midiNote)
    if midiNote < 0 or midiNote > 127 then
        debug_log("Error: MIDI note " .. midiNote .. " is out of range (0-127)")
        return "Invalid"
    end
    
    local noteClass = midiNote % 12
    local octave = math.floor(midiNote / 12) - 1  -- C4 = MIDI 60, so octave = 60/12 - 1 = 4

    return State.config.NOTE_NAMES[noteClass + 1] .. octave
end

---Generate extended MIDI range for chord tone targets
---@return table[] noteList Array of {midi: integer, name: string} objects
local function generateMidiRange()
    local notes = {}
    -- Generate from C0 to C10 for chord tone targeting (MIDI 0 to 120)
    for midiNote = 120, 0, -1 do
        table.insert(notes, {
            midi = midiNote,
            name = getNoteName(midiNote)
        })
    end
    return notes
end

---Render target note selector button with popup
---@param ctx ImGui_Context
---@param elementId string Unique identifier for this selector instance
---@param currentMidiNote integer Current MIDI note value
---@param onSelection function Callback when new note is selected: function(newMidiNote: integer)
---@return integer|nil selectedMidiNote New MIDI note value or nil if no selection
function TargetNoteSelector.render(ctx, elementId, currentMidiNote, onSelection)
    local selectedMidiNote = nil
    
    -- Show current note name as button
    local currentName = getNoteName(currentMidiNote)
    local buttonId = currentName .. "##target_note_" .. elementId
    
    local buttonClicked = reaper.ImGui_Button(ctx, buttonId, 0, 0)
    
    -- Capture button position for popup placement
    local buttonMinX, buttonMinY = reaper.ImGui_GetItemRectMin(ctx)
    local buttonMaxX, buttonMaxY = reaper.ImGui_GetItemRectMax(ctx)
    
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Click to select target note")
    end
    
    local popupOpened = false
    
    -- Check for auto-focus request or button click
    local shouldOpenPopup = buttonClicked or (focusState[elementId] == true)
    
    if shouldOpenPopup then
        -- Calculate popup position
        local buttonWidth = buttonMaxX - buttonMinX
        local buttonHeight = buttonMaxY - buttonMinY
        local popupX = buttonMinX + (buttonWidth * 0.5)
        local popupY = buttonMinY + (buttonHeight * 0.6)
        
        -- Set popup position and open
        reaper.ImGui_SetNextWindowPos(ctx, popupX, popupY)
        reaper.ImGui_OpenPopup(ctx, "target_note_select_" .. elementId)
        popupOpened = true
        
        -- Clear focus flag
        focusState[elementId] = false
    end
    
    -- Target note selection popup
    if reaper.ImGui_BeginPopup(ctx, "target_note_select_" .. elementId) then
        reaper.ImGui_SeparatorText(ctx, "Select Target Note")
        
        -- Use ScrollableDropdown component for the note list
        local notes = generateMidiRange()
        ScrollableDropdown.render(ctx, {
            dropdown_id = "target_note_" .. elementId,
            items = notes,
            current_value = currentMidiNote,
            format_item = function(note) return note.name end,
            get_item_value = function(note) return note.midi end,
            child_height = 200,
            dropdown_just_opened = popupOpened,
            on_selection = function(selectedValue)
                if selectedValue == "escape" then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                else
                    -- Always close popup and set selection, even if same value
                    selectedMidiNote = selectedValue
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
        })
        
        reaper.ImGui_EndPopup(ctx)
    end
    
    -- Call callback if selection was made
    if selectedMidiNote and onSelection then
        onSelection(selectedMidiNote)
    end
    
    return selectedMidiNote
end

---Request focus for a target note selector on next render
---@param elementId string Element to focus
function TargetNoteSelector.requestFocus(elementId)
    focusState[elementId] = true
end

return TargetNoteSelector