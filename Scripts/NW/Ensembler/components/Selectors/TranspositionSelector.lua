-- components/TranspositionSelector.lua - Transposition Selection Component

local TranspositionSelector = {}

-- State is accessed as a global
local Utils = Utils
local ScrollableDropdown = require('components/ScrollableDropdown')
local ImGui = reaper.ImGui_CreateContext and reaper or nil

-- Generate octave transposition options
local function generate_octave_options()
    local octave_options = {
        {value = 7, label = "+7 Octaves"},
        {value = 6, label = "+6 Octaves"}, 
        {value = 5, label = "+5 Octaves"},
        {value = 4, label = "+4 Octaves"},
        {value = 3, label = "+3 Octaves"},
        {value = 2, label = "+2 Octaves"},
        {value = 1, label = "+1 Octave"},
        {value = -1, label = "-1 Octave"},
        {value = -2, label = "-2 Octaves"},
        {value = -3, label = "-3 Octaves"},
        {value = -4, label = "-4 Octaves"},
        {value = -5, label = "-5 Octaves"},
        {value = -6, label = "-6 Octaves"},
        {value = -7, label = "-7 Octaves"}
    }
    return octave_options
end

-- Check if octave combination already exists
local function octave_already_exists(octave_value, lane_voice, existing_lanes)
    for _, existing_lane in ipairs(existing_lanes) do
        -- Check for voice lanes only
        if existing_lane.lane.type == "voice" and 
           existing_lane.lane.voice_number == lane_voice and 
           existing_lane.transposition == (octave_value * 12) then
            return true
        end
    end
    return false
end

-- Render transposition selector (button + popup)
function TranspositionSelector.render(ctx, lane_idx, lane_voice, existing_lanes)
    local selected_octave = nil
    
    -- Show "Double Voice" button for main voices (transposition = 0)
    local popup_opened = false
    if ImGui.ImGui_Button(ctx, "Double Voice##double_" .. lane_idx, 100, 0) then
        -- Open octave selection popup
        ImGui.ImGui_OpenPopup(ctx, "octave_select_" .. lane_idx)
        popup_opened = true
    end
    
    if ImGui.ImGui_IsItemHovered(ctx) then
        ImGui.ImGui_SetTooltip(ctx, "Create transposed copy of this voice")
    end
    
    -- Octave selection popup
    if ImGui.ImGui_BeginPopup(ctx, "octave_select_" .. lane_idx) then
        ImGui.ImGui_SeparatorText(ctx, "Select Octave Transposition")
        
        -- Use ScrollableDropdown component for the octave list
        local octave_options = generate_octave_options()
        local result = ScrollableDropdown.render(ctx, {
            dropdown_id = "octave_" .. lane_idx,
            items = octave_options,
            current_value = "no_current_selection", -- Use a sentinel value that won't match any item
            format_item = function(option) 
                -- Check if this option already exists and gray it out
                local already_exists = octave_already_exists(option.value, lane_voice, existing_lanes)
                if already_exists then
                    return option.label .. " (exists)"
                else
                    return option.label
                end
            end,
            get_item_value = function(option) return option.value end,
            child_height = 200,
            dropdown_just_opened = popup_opened, -- Only true when popup actually opens
            on_selection = function(selected_value)
                if selected_value == "escape" then
                    ImGui.ImGui_CloseCurrentPopup(ctx)
                else
                    -- Check if this combination already exists
                    local already_exists = octave_already_exists(selected_value, lane_voice, existing_lanes)
                    if not already_exists then
                        selected_octave = selected_value
                        ImGui.ImGui_CloseCurrentPopup(ctx)
                    end
                    -- If already exists, just ignore the selection (could add tooltip feedback)
                end
            end
        })
        
        ImGui.ImGui_EndPopup(ctx)
    end
    
    return selected_octave
end

return TranspositionSelector