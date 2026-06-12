-- TransformerCell.lua - Individual transformer cell component

require('types/types')
local Knob = require('components/UI/Knob')
local Debouncer = require('utils/Debouncer')

local TransformerCell = {}

---Create unique debounce key for transformer updates
---@param rowData TransformRowData
---@param parameter TransformParameter
---@return string
local function getDebounceKey(rowData, parameter)
    local id = rowData.type == "section" and rowData.source.sectionId or rowData.source.trackData.guid
    return "transformer_update_" .. id .. "_" .. parameter
end

---Get transformer for this cell
---@param rowData TransformRowData
---@param parameter TransformParameter
---@return Transformer|nil
local function getTransformer(rowData, parameter)
    if rowData.type == "section" then
        return State.ensemble.getSectionTransformer(rowData.source.sectionId, parameter)
    else
        local instrumentId = rowData.source.trackData.guid
        return State.ensemble.getInstrumentTransformer(instrumentId, parameter)
    end
end

---Set transformer for this cell (without triggering update - for UI responsiveness)
---@param rowData TransformRowData
---@param parameter TransformParameter
---@param transformer Transformer|nil
local function setTransformer(rowData, parameter, transformer)
    if rowData.type == "section" then
        State.ensemble.setSectionTransformerNoUpdate(rowData.source.sectionId, parameter, transformer)
    else
        local instrumentId = rowData.source.trackData.guid
        State.ensemble.setInstrumentTransformerNoUpdate(instrumentId, parameter, transformer)
    end
end

---Set transformer and trigger appropriate update (immediate for menu actions, debounced for knobs)
---@param rowData TransformRowData
---@param parameter TransformParameter
---@param transformer Transformer|nil
---@param useDebouncing boolean Whether to debounce the update (true for knob changes, false for menu actions)
local function setTransformerAndUpdate(rowData, parameter, transformer, useDebouncing)
    setTransformer(rowData, parameter, transformer)
    
    if useDebouncing then
        -- Debounce ensemble update (for knob changes)
        local debounceKey = getDebounceKey(rowData, parameter)
        Debouncer.debounce(debounceKey, 0.2, function()
            State.ensemble.wasUpdated()
        end)
    else
        -- Immediate update (for menu actions)
        State.ensemble.wasUpdated()
    end
end

---Render a transformer cell
---@param ctx ImGui_Context
---@param rowData TransformRowData
---@param parameter TransformParameter
---@param width number
function TransformerCell.render(ctx, rowData, parameter, width)
    local cellId = "cell_" .. (rowData.type == "section" and rowData.source.sectionId or rowData.source.trackData.guid) .. "_" .. parameter
    local transformer = getTransformer(rowData, parameter)

    -- Get actual available space in the table cell
    local availableWidth = reaper.ImGui_GetContentRegionAvail(ctx)
    local knobDiameter = 25
    local buttonWidth = knobDiameter
    
    -- Calculate center offset based on actual available space
    local centerOffset = math.max(0, (availableWidth - buttonWidth) * 0.5) - 9.5 -- TODO not sure what I'm doing wrong here that requires this 9.5 value, need to figure it out later
    
    -- Begin group to capture clicks on entire cell area
    reaper.ImGui_BeginGroup(ctx)
    
    if not transformer then
        -- No transformer - show placeholder button
        reaper.ImGui_Dummy(ctx, centerOffset, 1)
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "○##" .. cellId, buttonWidth, 20) then
            reaper.ImGui_OpenPopup(ctx, "transformer_menu_" .. cellId)
        end
        
        -- Render transformer type selection menu
        if reaper.ImGui_BeginPopup(ctx, "transformer_menu_" .. cellId) then
            if reaper.ImGui_Selectable(ctx, "Scale") then
                setTransformerAndUpdate(rowData, parameter, {type = "scale", value = 1.0}, false)
            end
            if reaper.ImGui_Selectable(ctx, "Fixed") then
                setTransformerAndUpdate(rowData, parameter, {type = "fixed", value = 127}, false)
            end
            -- Only show Ignore option for CC parameters (not velocity)
            if parameter ~= "velocity" then
                if reaper.ImGui_Selectable(ctx, "Ignore") then
                    setTransformerAndUpdate(rowData, parameter, {type = "ignore", value = 0}, false)
                end
            end
            reaper.ImGui_EndPopup(ctx)
        end
    else
        -- Has transformer - show appropriate UI
        if transformer.type == "ignore" then
            -- Center "IGN" text
            local textWidth = reaper.ImGui_CalcTextSize(ctx, "IGN")
            local textCenterOffset = math.max(0, (availableWidth - textWidth) * 0.5)
            reaper.ImGui_Dummy(ctx, textCenterOffset, 1)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, "IGN")
        elseif transformer.type == "scale" then
            -- Center scale knob
            reaper.ImGui_Dummy(ctx, centerOffset, 1)
            reaper.ImGui_SameLine(ctx)
            
            Knob.render(ctx, cellId .. "_scale", "scale", transformer.value, 
                function(newKnobValue)
                    setTransformerAndUpdate(rowData, parameter, {type = "scale", value = newKnobValue}, true)
                end,
                {
                    diameter = knobDiameter,
                    labelFormatter = function(value)
                        return string.format("%.0f%%", value * 100)
                    end
                }
            )
        elseif transformer.type == "fixed" then
            -- Center fixed knob
            reaper.ImGui_Dummy(ctx, centerOffset, 1)
            reaper.ImGui_SameLine(ctx)
            
            Knob.render(ctx, cellId .. "_fixed", "fixed", transformer.value / 127,
                function(newKnobValue)
                    -- Convert knob value (0-1) to MIDI value (0-127) for storage
                    local midiValue = Utils.round(newKnobValue * 127)
                    setTransformerAndUpdate(rowData, parameter, {type = "fixed", value = midiValue}, true)
                end,
                {
                    defaultValue = 1.0,
                    diameter = knobDiameter,
                    labelFormatter = function(value)
                        return string.format("%d", Utils.round(value * 127))
                    end
                }
            )
        end
    end
    
    -- End group and check for right-click on entire cell
    reaper.ImGui_EndGroup(ctx)
    
    -- Right-click detection on the entire grouped cell area
    if transformer and reaper.ImGui_IsItemClicked(ctx, 1) then  -- Right click on existing transformer
        reaper.ImGui_OpenPopup(ctx, "transformer_menu_" .. cellId)
    end
    
    -- Render transformer modification menu (only for existing transformers)
    if transformer and reaper.ImGui_BeginPopup(ctx, "transformer_menu_" .. cellId) then
        if reaper.ImGui_Selectable(ctx, "Change to Scale") then
            setTransformerAndUpdate(rowData, parameter, {type = "scale", value = 1.0}, false)
        end
        if reaper.ImGui_Selectable(ctx, "Change to Fixed") then
            setTransformerAndUpdate(rowData, parameter, {type = "fixed", value = 127}, false)
        end
        -- Only show Ignore option for CC parameters (not velocity)
        if parameter ~= "velocity" then
            if reaper.ImGui_Selectable(ctx, "Change to Ignore") then
                setTransformerAndUpdate(rowData, parameter, {type = "ignore", value = 0}, false)
            end
        end
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Selectable(ctx, "Remove Transformer") then
            setTransformerAndUpdate(rowData, parameter, nil, false)
        end
        reaper.ImGui_EndPopup(ctx)
    end
end

return TransformerCell