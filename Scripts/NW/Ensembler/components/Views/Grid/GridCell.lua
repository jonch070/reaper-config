-- GridCell - The individual cells within the grid

require('types/types')
local DropTarget = require('components/DragDrop/DropTarget')
local FilterInput = require('components/Selectors/FilterInput')
local SectionHandles = require('components/Views/Grid/SectionHandles')

local GridCell = {}

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.UI)
end

-- Configuration
local INSTRUMENT_BUTTON_GAP = 4  -- Gap between instruments (matching cell padding)
local ADD_BUTTON_WIDTH = 16      -- Width of [+] button
local TEXT_PADDING = 8           -- Extra padding for text width calculations

-- Section bounds collection for overlay rendering
-- This gets populated during cell rendering and used for post-render section indicators
GridCell.sectionBounds = {}

---Clear section bounds data (call before starting table render)
function GridCell.clearSectionBounds()
    GridCell.sectionBounds = {}
end

---Helper function to render instrument cells with calculated widths
---@param cellData GridRowColumnData
---@param position VoicePosition|ChordTonePosition
---@param columnWidth integer
function GridCell.render(cellData, position, columnWidth)
    local ctx = State.imgui.ctx

    local cellId = generateCellId(cellData, position)
    local hasInstruments = #cellData.instruments > 0
    local isVoiceCell = position.voice ~= nil
    
    -- Wrap entire cell with DropTarget
    DropTarget.render(ctx,
        --@param payload InstrumentDraggablePayload
        function(isHoverTarget, payload)
            -- Apply hover background to entire cell if hovering with valid payload
            if isHoverTarget and payload then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), 0x464646FF)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 3.0)
            end
            
            -- Start a section for this cell's content
            reaper.ImGui_BeginGroup(ctx)
            
            if hasInstruments then
                -- Add left spacing for section handles
                reaper.ImGui_Dummy(ctx, SectionHandles.WIDTH, 1)
                reaper.ImGui_SameLine(ctx, 0, 0)

                -- Calculate available space for instruments
                local availableSpace = (columnWidth - ADD_BUTTON_WIDTH - INSTRUMENT_BUTTON_GAP - SectionHandles.WIDTH) or columnWidth
                local totalTextWidth = 0
                local textWidths = {}
                
                -- Calculate text width for each instrument
                for i, track in ipairs(cellData.instruments) do
                    local textWidth = reaper.ImGui_CalcTextSize(ctx, track.name)
                    textWidths[i] = textWidth + TEXT_PADDING  -- Add padding to prevent cropping
                    totalTextWidth = totalTextWidth + textWidths[i]
                end
                
                -- Calculate extra space to distribute
                local totalGaps = (#cellData.instruments - 1) * INSTRUMENT_BUTTON_GAP
                local extraSpace = availableSpace - totalTextWidth - totalGaps
                local extraPerInstrument = extraSpace / #cellData.instruments
                
                -- Render instruments horizontally with calculated widths
                for i, instrument in ipairs(cellData.instruments) do
                    if i > 1 then
                        reaper.ImGui_SameLine(ctx, 0, INSTRUMENT_BUTTON_GAP)
                    end
                    
                    -- Calculate button width: text width + proportional extra space
                    local buttonWidth = textWidths[i] + extraPerInstrument
                    
                    -- Wrap instrument button with Draggable
                    local elementId = cellId .. "_" .. instrument.trackData.guid
                    Draggable.render(ctx, 
                        elementId,
                        {   -- Draggable Payload
                            sourceCellId = cellId,
                            instrument = instrument
                        }, 
                        function(isOriginal, isDragging)
                            -- Apply dimming if this is the original being dragged
                            if isOriginal and isDragging then
                                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), 0.4)
                            end
                            
                            if reaper.ImGui_Button(ctx, instrument.name .. "##" .. cellId .. "_track_" .. i, buttonWidth) then
                                -- If they click the instrument, remove it for now as a quick way to handle that currently
                                if (isOriginal and not isDragging) then
                                    Ensemble.removeInstrumentFromCurrentPosition(instrument)
                                end
                            end
                            
                            if isOriginal and isDragging then
                                reaper.ImGui_PopStyleVar(ctx)
                            end
                        end)
                end
                
                -- Add [+] button after instruments
                reaper.ImGui_SameLine(ctx, 0, INSTRUMENT_BUTTON_GAP)
            end
            
            -- Always show [+] button - full column width if empty, fixed ADD_BUTTON_WIDTH if after instruments
            local plusButtonWidth = hasInstruments and ADD_BUTTON_WIDTH or columnWidth
            
            -- Apply styling for [+] button
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 3.0)
            if isHoverTarget then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x464646FF)
            else 
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x2a2a2aFF)
            end
            
            -- Show add button
            local buttonClicked = reaper.ImGui_Button(ctx, '##' .. cellId, plusButtonWidth)
            
            -- Handle button click - set popup to appear
            if buttonClicked then
                debug_log("buttonClicked!")
                -- Reload track cache to ensure fresh data
                ReaperTracks.reloadCache()
                FilterInput.setPopupToAppear({
                    onItemSelected = function(selectedItem)
                        debug_log("callback!")
                        -- Add instrument to appropriate position using itemData
                        local track = selectedItem.itemData
                        local newInstrument = Ensemble.createInstrumentFromTrack(track.track)
                        if isVoiceCell then
                            Ensemble.addInstrumentToSectionAtVoiceAndOctave(newInstrument, cellData.section.sectionId, position.voice, position.octave)
                        else 
                            Ensemble.addInstrumentToSectionAtChordTone(newInstrument, cellData.section.sectionId, position.targetNote, position.chordToneNum)
                        end
                    end,
                    getFilteredList = function(searchQuery)
                        local tracks = ReaperTracks.filter(searchQuery)
                        local items = {}
                        for _, track in ipairs(tracks) do
                            table.insert(items, {
                                name = string.format("%d. %s", track.number, track.name),
                                id = track.guid,
                                itemData = track
                            })
                        end
                        return items
                    end,
                    hintText = "Select an instrument",
                    placeholderText = "Type to search for instruments..."
                })
            end
            
            reaper.ImGui_PopStyleColor(ctx)
            reaper.ImGui_PopStyleVar(ctx)
            
            reaper.ImGui_EndGroup(ctx)
            
            -- Pop hover styling if it was applied
            if isHoverTarget and payload then
                reaper.ImGui_PopStyleVar(ctx)  -- ChildRounding
                reaper.ImGui_PopStyleColor(ctx)  -- ChildBg
            end
        end,
        {
            ---@param payload InstrumentDraggablePayload
            can_accept = function(payload)
                -- Reject if trying to drop on same cell
                return payload and payload.sourceCellId ~= cellId
            end,
            ---@param payload InstrumentDraggablePayload
            on_drop = function(payload)
                debug_log('did drop')
                debug_log(payload)
                if isVoiceCell then
                    Ensemble.moveInstrumentToVoiceOctaveSection(payload.instrument, position.voice, position.octave, cellData.section.sectionId)
                else 
                    Ensemble.moveInstrumentToChordToneSection(payload.instrument, position.targetNote, position.chordToneNum, cellData.section.sectionId)
                end
            end
        }
    )
end

---Collect cell bounds for section indicator rendering
---@param ctx ImGui_Context
---@param sectionId string
---@param voice integer
---@param octave integer
---@param instruments Instrument[]
function GridCell.collectCellBoundsForSection(ctx, sectionId, voice, octave, instruments)
    local minX, minY = reaper.ImGui_GetItemRectMin(ctx)
    local maxX, maxY = reaper.ImGui_GetItemRectMax(ctx)
    
    -- Initialize section bounds if not exists
    if not GridCell.sectionBounds[sectionId] then
        GridCell.sectionBounds[sectionId] = {
            minX = math.huge,
            minY = math.huge,
            maxX = -math.huge,
            maxY = -math.huge,
            cellPositions = {},
            instrumentCount = 0
        }
    end
    
    local bounds = GridCell.sectionBounds[sectionId]
    
    -- Expand bounds to include this cell
    bounds.minX = math.min(bounds.minX, minX)
    bounds.minY = math.min(bounds.minY, minY)
    bounds.maxX = math.max(bounds.maxX, maxX)
    bounds.maxY = math.max(bounds.maxY, maxY)
    
    -- Store individual cell position for later use
    bounds.cellPositions[#bounds.cellPositions + 1] = {
        voice = voice,
        octave = octave,
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        instrumentCount = #instruments
    }
    
    bounds.instrumentCount = bounds.instrumentCount + #instruments
end

---Helper function to calculate column width based on content
---@param ctx ImGui_Context
---@param tableData GridData
---@param sectionId string
---@return integer
function GridCell.calculateColumnWidth(ctx, tableData, sectionId)
    local maxContentWidth = 0
    
    ---@param rows GridVoiceRowData[]|GridChordToneRowData[]
    local calculateMaxWidth = function(rows)
        if rows then 
            for _, rowData in ipairs(rows) do
                for sectionOrder, column in ipairs(rowData.columns) do
                    if column and column.section.sectionId == sectionId and column.instruments and #column.instruments > 0 then
                        -- Calculate total text width for this cell
                        local totalTextWidth = 0
                        for _, instrument in ipairs(column.instruments) do
                            local textWidth = reaper.ImGui_CalcTextSize(ctx, instrument.name)
                            totalTextWidth = totalTextWidth + textWidth + TEXT_PADDING
                        end
                        
                        -- Add gaps between instruments
                        local totalGaps = (#column.instruments - 1) * INSTRUMENT_BUTTON_GAP
                        local cellContentWidth = totalTextWidth + totalGaps
                        
                        maxContentWidth = math.max(maxContentWidth, cellContentWidth)
                    end
                end
            end
        end
        return maxContentWidth
    end 

    -- Check voice and chord rows
    maxContentWidth = calculateMaxWidth(tableData.voiceRows)
    maxContentWidth = calculateMaxWidth(tableData.chordToneRows)
    
    -- Final column width: max content + [+] button + gap + minimum 120px
    local columnWidth = math.max(120, maxContentWidth + ADD_BUTTON_WIDTH + INSTRUMENT_BUTTON_GAP + SectionHandles.WIDTH)
    return columnWidth
end

return GridCell