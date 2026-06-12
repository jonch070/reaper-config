-- components/ChordToneSelector.lua - Chord Tone Selection Component

require('types/types')
local ScrollableDropdown = require('components/Selectors/ScrollableDropdown')

local ChordToneSelector = {}

-- Internal state for focus management
local focusState = {}

---Get chord tone name from semitone value
---@param chordToneNum integer Chord tone in semitones (0,4,7,10)
---@return string chordToneName
local function getChordToneName(chordToneNum)
    for _, chordTone in ipairs(State.config.CHORD_TONES) do
        if chordTone.value == chordToneNum then
            return chordTone.name
        end
    end
    return "Unknown"
end

---Render chord tone selector button with popup
---@param ctx ImGui_Context
---@param elementId string Unique identifier for this selector instance
---@param currentChordToneNum integer Current chord tone value in semitones
---@param onSelection function Callback when new chord tone is selected: function(newChordToneNum: integer)
---@param onRemove? function Optional callback when remove is clicked: function()
---@return integer|nil selectedChordTone New chord tone value or nil if no selection
function ChordToneSelector.render(ctx, elementId, currentChordToneNum, onSelection, onRemove)
    local selectedChordTone = nil
    
    -- Show current chord tone name as button
    local currentName = getChordToneName(currentChordToneNum)
    local buttonId = currentName .. "##chord_tone_" .. elementId
    
    local buttonClicked = reaper.ImGui_Button(ctx, buttonId, 0, 0)
    
    -- Capture button position for popup placement
    local buttonMinX, buttonMinY = reaper.ImGui_GetItemRectMin(ctx)
    local buttonMaxX, buttonMaxY = reaper.ImGui_GetItemRectMax(ctx)
    
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Click to select chord tone")
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
        reaper.ImGui_OpenPopup(ctx, "chord_tone_select_" .. elementId)
        popupOpened = true
        
        -- Clear focus flag
        focusState[elementId] = false
    end
    
    -- Chord tone selection popup
    if reaper.ImGui_BeginPopup(ctx, "chord_tone_select_" .. elementId) then
        reaper.ImGui_SeparatorText(ctx, "Select Chord Tone")
        
        -- Use ScrollableDropdown component for the chord tone list
        ScrollableDropdown.render(ctx, {
            dropdown_id = "chord_tone_" .. elementId,
            items = State.config.CHORD_TONES,
            current_value = currentChordToneNum,
            format_item = function(chordTone) return chordTone.name end,
            get_item_value = function(chordTone) return chordTone.value end,
            child_height = 120, -- Smaller height since fewer items
            dropdown_just_opened = popupOpened,
            on_selection = function(selectedValue)
                if selectedValue == "escape" or selectedValue == "action" then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                else
                    -- Always close popup and set selection, even if same value
                    selectedChordTone = selectedValue
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end,
            action_button_label = onRemove and "Remove" or nil,
            on_action = onRemove and function()
                reaper.ImGui_CloseCurrentPopup(ctx)
                onRemove()
            end or nil
        })
        
        reaper.ImGui_EndPopup(ctx)
    end
    
    -- Call callback if selection was made
    if selectedChordTone and onSelection then
        onSelection(selectedChordTone)
    end
    
    return selectedChordTone
end

---Request focus for a chord tone selector on next render
---@param elementId string Element to focus
function ChordToneSelector.requestFocus(elementId)
    focusState[elementId] = true
end

return ChordToneSelector