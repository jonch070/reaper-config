-- components/Views/Grid/SectionHandles.lua - Section Drag Handle Component

require('types/types')

local SectionHandles = {}

-- Configuration
local HANDLE_WIDTH = 12                             -- Handle width in pixels
local HANDLE_COLOR = 0xFF0000FF                     -- Color of the handle
local HANDLE_PADDING = 2                            -- Padding around handle
SectionHandles.WIDTH = HANDLE_WIDTH + HANDLE_PADDING  -- Exported handle width that includes padding/space that it takes up

---Render section drag handles as draggable positioned buttons
---@param ctx ImGui_Context
---@param tableGeometry table Table geometry data from Grid rendering
---@param tableData GridData
function SectionHandles.render(ctx, tableGeometry, tableData)

    -- Get the cursor position so we can restore it after we finish running this
    local cursorX, cursorY = reaper.ImGui_GetCursorScreenPos(ctx)
    
    -- Render section drag handle for each section that has multiple instruments
    for sectionId, columnData in pairs(tableGeometry.columns) do
        local totalInstruments = 0
        local allSectionInstruments = {}
        local minY = math.huge
        local maxY = -math.huge
        local linkedElementIds = {}
        
        -- Single loop: count instruments, collect them, collect element IDs, and track Y bounds
        for rowIdx, rowData in ipairs(tableData.voiceRows) do
            for _, column in ipairs(rowData.columns) do
                if column.section.sectionId == sectionId and #column.instruments > 0 then
                    totalInstruments = totalInstruments + #column.instruments
                    
                    -- Collect all instruments for section payload
                    for _, instrument in ipairs(column.instruments) do
                        table.insert(allSectionInstruments, instrument)
                        
                        -- Build element ID same way as GridCell does it
                        local elementId = column.cellId .. "_" .. instrument.trackData.guid
                        table.insert(linkedElementIds, elementId)
                    end
                    
                    -- Track Y bounds from this row
                    local rowGeometry = tableGeometry.rows[rowIdx]
                    if rowGeometry then
                        minY = math.min(minY, rowGeometry.topY)
                        maxY = math.max(maxY, rowGeometry.bottomY)
                    end
                end
            end
        end
        
        -- Note: Chord tone instruments are excluded from group dragging
        
        -- Only render handle if there are multiple instruments in this section
        if totalInstruments > 1 and minY < math.huge and maxY > -math.huge then
            -- Calculate handle position and size (positioned within column boundaries)
            local handleX = columnData.startX
            local handleY = minY + HANDLE_PADDING
            local handleWidth = HANDLE_WIDTH
            local handleHeight = (maxY - minY) - (HANDLE_PADDING * 2)
            
            -- Position the handle button
            reaper.ImGui_SetCursorScreenPos(ctx, handleX, handleY)
            
            -- Wrap handle with Draggable, passing linked elements
            Draggable.render(ctx,
                "section_handle_" .. sectionId,
                { 
                    type = "section",
                    sectionId = sectionId,
                    linkedInstruments = allSectionInstruments 
                },
                function(isOriginal, isDragging)
                    -- Style the button red
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), HANDLE_COLOR)
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF3333FF) -- Lighter red on hover
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFF6666FF)  -- Even lighter when active
                    
                    -- Render the handle button
                    local handleClicked = reaper.ImGui_Button(ctx, "##section_handle_" .. sectionId .. (isOriginal and "" or "_dragcopy" ), handleWidth, handleHeight)
                    
                    -- Pop style colors
                    reaper.ImGui_PopStyleColor(ctx, 3)
                    
                    return handleClicked
                end,
                linkedElementIds  -- Pass linked elements for multi-drag
            )
        end
    end

    -- Restore the cursor position
    reaper.ImGui_SetCursorScreenPos(ctx, cursorX, cursorY)
end

return SectionHandles