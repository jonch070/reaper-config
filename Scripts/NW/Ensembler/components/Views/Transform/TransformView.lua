-- TransformView.lua - CC/Velocity Transform Table View

require('types/types')

local TransformerCell = require('components/Views/Transform/TransformerCell')
local Modal = require('components/Modals/Modal')
local ModalManager = require('components/Modals/ModalManager')

local TransformView = {}

-- State for confirmation dialogs
---@type TransformParameter|nil
local pendingClearParameter = nil

---Get modal ID for clear confirmation
---@param parameter TransformParameter
---@return string
local function getClearModalId(parameter)
    return "clear_transformers_" .. parameter
end

---Open clear all transformers modal
---@param parameter TransformParameter
function TransformView.openClearModal(parameter)
    pendingClearParameter = parameter
    ModalManager.openPopupOnNextFrame(getClearModalId(parameter))
end

---Render clear all transformers confirmation modal
---@param ctx ImGui_Context
local function renderClearModal(ctx)
    if not pendingClearParameter then return end
    
    local modalId = getClearModalId(pendingClearParameter)
    local parameterName = pendingClearParameter == "velocity" and "Velocity" or pendingClearParameter:upper()
    local message = 'Clear all ' .. parameterName .. ' transformers?\nThis operation cannot be undone.'
    
    Modal.renderConfirmation(ctx, modalId, 'Clear All Transformers', message, {
        confirmText = "Clear",
        onConfirm = function()
            State.ensemble.clearAllTransformersForParameter(pendingClearParameter)
            pendingClearParameter = nil
        end,
        onCancel = function()
            pendingClearParameter = nil
        end
    })
end

-- Configuration
local NAME_COLUMN_WIDTH = 200
local TRANSFORM_COLUMN_WIDTH = 42
local PARAMETER_OPTIONS_HEIGHT = 260
local MAX_TRANSFORM_PARAMETERS = 10

---Get complete list of transform parameters (velocity + cc1-cc127)
---@return TransformParameter[]
local function getParameterList()
    local parameters = {"velocity"}
    for i = 1, 127 do
        table.insert(parameters, "cc" .. i)
    end
    return parameters
end

---Get parameter availability status
---@param activeColumns TransformParameter[]
---@return table<TransformParameter, boolean> parameterAvailability Map of parameter to whether it's available (not in use)
local function getParameterAvailability(activeColumns)
    local allParameters = getParameterList()
    local activeSet = {}
    
    -- Create lookup set for active columns
    for _, parameter in ipairs(activeColumns) do
        activeSet[parameter] = true
    end
    
    -- Create availability map
    local parameterAvailability = {}
    for _, parameter in ipairs(allParameters) do
        parameterAvailability[parameter] = not activeSet[parameter]
    end
    
    return parameterAvailability
end

---Get all sections and instruments for the rows
---@return TransformRowData[]
local function getRowData()
    local sections = State.ensemble.getActiveSectionsSorted()
    local rowData = {}
    
    for _, section in ipairs(sections) do
        -- Add section row
        table.insert(rowData, {
            type = "section",
            source = section,
            name = section.name
        })
        
        -- Add instrument rows (sorted by the new function)
        local instruments = State.ensemble.getInstrumentsForSection(section.sectionId)
        for _, instrument in ipairs(instruments) do
            table.insert(rowData, {
                type = "instrument",
                source = instrument,
                name = instrument.name -- Keep original name
            })
        end
    end
    
    return rowData
end

---Render parameter list menu with disabled unavailable options
---@param ctx ImGui_Context
---@param menuId string Unique ID for the menu/popup
---@param headerText string Header text to display
---@param parameterAvailability table<TransformParameter, boolean>
---@param onParameterSelected fun(parameter: TransformParameter): nil Callback when parameter is selected
local function renderParameterListMenu(ctx, menuId, headerText, parameterAvailability, onParameterSelected)
    -- Set max height for the popup
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 0, 0, 400, PARAMETER_OPTIONS_HEIGHT)
    if reaper.ImGui_BeginPopup(ctx, menuId) then
        reaper.ImGui_Text(ctx, headerText)
        reaper.ImGui_Separator(ctx)
        
        -- Show all parameters
        local allParameters = getParameterList()
        for _, parameter in ipairs(allParameters) do
            local displayName = parameter == "velocity" and "Velocity" or parameter:upper()
            local isAvailable = parameterAvailability[parameter]
            
            if not isAvailable then
                reaper.ImGui_BeginDisabled(ctx)
            end
            
            if reaper.ImGui_Selectable(ctx, displayName) then
                if isAvailable then
                    onParameterSelected(parameter)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
            
            if not isAvailable then
                reaper.ImGui_EndDisabled(ctx)
            end
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
end

---Render parameter list submenu with disabled unavailable options
---@param ctx ImGui_Context
---@param menuLabel string Label for the submenu
---@param parameterAvailability table<TransformParameter, boolean>
---@param onParameterSelected fun(parameter: TransformParameter): nil Callback when parameter is selected
local function renderParameterListSubmenu(ctx, menuLabel, parameterAvailability, onParameterSelected)
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 0, 0, 400, PARAMETER_OPTIONS_HEIGHT)
    if reaper.ImGui_BeginMenu(ctx, menuLabel) then
        -- Show all parameters
        local allParameters = getParameterList()
        for _, parameter in ipairs(allParameters) do
            local displayName = parameter == "velocity" and "Velocity" or parameter:upper()
            local isAvailable = parameterAvailability[parameter]
            
            if not isAvailable then
                reaper.ImGui_BeginDisabled(ctx)
            end
            
            if reaper.ImGui_Selectable(ctx, displayName) then
                if isAvailable then
                    onParameterSelected(parameter)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
            
            if not isAvailable then
                reaper.ImGui_EndDisabled(ctx)
            end
        end
        reaper.ImGui_EndMenu(ctx)
    end
end

---Render column header menu
---@param ctx ImGui_Context
---@param columnIndex number
---@param column TransformParameter
---@param columns TransformParameter[]
local function renderColumnHeaderMenu(ctx, columnIndex, column, columns)
    local popupId = "column_menu_" .. column
    if reaper.ImGui_BeginPopup(ctx, popupId) then
        -- Change to another parameter
        local parameterAvailability = getParameterAvailability(columns)
        renderParameterListSubmenu(ctx, "Change to...", parameterAvailability, function(parameter)
            -- Migrate all existing transformers from old parameter to new parameter
            State.ensemble.migrateTransformersToNewParameter(column, parameter)
            
            -- If changing TO velocity, clear any ignore transforms for this parameter
            -- (velocity can't be ignored, so remove any ignore transforms that may have migrated)
            if parameter == "velocity" then
                State.ensemble.clearTransformerTypeForParameter(parameter, "ignore")
            end
            
            -- Replace the column
            local oldParameter = columns[columnIndex]
            State.ensemble.replaceTransformParameter(oldParameter, parameter)
        end)
        
        -- Clear all transformers in this parameter
        local hasTransformers = State.ensemble.parameterHasTransformers(column)
        if not hasTransformers then
            reaper.ImGui_BeginDisabled(ctx)
        end
        
        if reaper.ImGui_Selectable(ctx, "Clear all transformers") then
            if hasTransformers then
                TransformView.openClearModal(column)
            end
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
        if not hasTransformers then
            reaper.ImGui_EndDisabled(ctx)
        end
        
        -- Remove parameter
        if reaper.ImGui_Selectable(ctx, "Remove parameter") then
            -- Clear all transformers for this parameter first
            State.ensemble.clearAllTransformersForParameter(column)
            
            -- Remove this column from active columns
            local column = columns[columnIndex]
            State.ensemble.removeTransformParameter(column)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
end

---Render column headers
---@param ctx ImGui_Context
---@param columns TransformParameter[]
local function renderColumnHeaders(ctx, columns)
    -- Name column header (empty)
    reaper.ImGui_TableSetupColumn(ctx, "", reaper.ImGui_TableColumnFlags_WidthFixed(), NAME_COLUMN_WIDTH)
    
    -- Transform columns
    for _, column in ipairs(columns) do
        reaper.ImGui_TableSetupColumn(ctx, "", reaper.ImGui_TableColumnFlags_WidthFixed(), TRANSFORM_COLUMN_WIDTH)
    end
    
    -- Add column button
    reaper.ImGui_TableSetupColumn(ctx, "", reaper.ImGui_TableColumnFlags_WidthFixed(), 30)
    
    reaper.ImGui_TableHeadersRow(ctx)
    
    -- Handle clicks on existing column headers
    for i, column in ipairs(columns) do
        reaper.ImGui_TableSetColumnIndex(ctx, i)
        local columnName = column == "velocity" and "Vel" or column:upper()
        if reaper.ImGui_Button(ctx, columnName .. "##header_" .. column, TRANSFORM_COLUMN_WIDTH, 20) then
            reaper.ImGui_OpenPopup(ctx, "column_menu_" .. column)
        end
        renderColumnHeaderMenu(ctx, i, column, columns)
    end
    
    -- Handle add column button in header
    reaper.ImGui_TableSetColumnIndex(ctx, #columns + 1)
    local atMaxParameters = #columns >= MAX_TRANSFORM_PARAMETERS
    
    if atMaxParameters then
        reaper.ImGui_BeginDisabled(ctx)
    end
    
    if reaper.ImGui_Button(ctx, "+##add_column_header", 25, 20) then
        if not atMaxParameters then
            reaper.ImGui_OpenPopup(ctx, "add_column_popup")
        end
    end
    
    if atMaxParameters then
        reaper.ImGui_EndDisabled(ctx)
        -- Show tooltip explaining the limit
        if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
            reaper.ImGui_SetTooltip(ctx, "Maximum " .. MAX_TRANSFORM_PARAMETERS .. " parameters allowed")
        end
    end
    
    -- Render add column popup (only if not at limit)
    if not atMaxParameters then
        local parameterAvailability = getParameterAvailability(columns)
        renderParameterListMenu(ctx, "add_column_popup", "Add Parameter:", parameterAvailability, function(parameter)
            State.ensemble.addTransformParameter(parameter)
        end)
    end
end

-- Register all transform view modals with ModalManager
ModalManager.addModalRenderer(function(ctx)
    renderClearModal(ctx)
end)

---Render the transform view table
---@param ctx ImGui_Context
function TransformView.render(ctx)
    local columns = State.ensemble.getActiveTransformColumns()
    local rowData = getRowData()
    
    -- Calculate column count: Name + Transform columns + Add button
    local columnCount = 1 + #columns + 1
    
    -- Inline table flags
    local tableFlags = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_SizingFixedFit()
    
    if reaper.ImGui_BeginTable(ctx, "transform_table", columnCount, tableFlags) then
        renderColumnHeaders(ctx, columns)
        
        -- Render rows
        for _, row in ipairs(rowData) do
            reaper.ImGui_TableNextRow(ctx)
            
            -- Name column
            reaper.ImGui_TableSetColumnIndex(ctx, 0)
            
            -- Add indentation for instruments using ImGui spacing
            if row.type == "instrument" then
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_SameLine(ctx)
            end
            
            local nameColor = row.type == "section" and 0xFFFFFFFF or 0xCCCCCCFF
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), nameColor)
            reaper.ImGui_Text(ctx, row.name)
            reaper.ImGui_PopStyleColor(ctx)
            
            -- Transform columns
            for i, parameter in ipairs(columns) do
                reaper.ImGui_TableSetColumnIndex(ctx, i)
                TransformerCell.render(ctx, row, parameter, TRANSFORM_COLUMN_WIDTH)
            end
        end
        
        reaper.ImGui_EndTable(ctx)
    end
end

return TransformView