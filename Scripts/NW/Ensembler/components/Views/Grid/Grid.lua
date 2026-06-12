-- Grid.lua - The Grid itself

require('types/types')
local GridCell = require('components/Views/Grid/GridCell')
local SectionHandles = require('components/Views/Grid/SectionHandles')
local SectionHeaderButton = require('components/Views/Grid/SectionHeaderButton')
local SectionMenuManager = require('components/Views/Grid/SectionMenuManager')
local ChordToneLabel = require('components/Views/Grid/ChordToneLabel')

local Grid = {}

-- Configuration
local TABLE_FLAGS = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_SizingFixedFit()
local OCTAVE_COLUMN_WIDTH = 120
local PATTERN_COLUMN_WIDTH = 20

-- Table geometry tracking for section handles
local tableGeometry = {
    rows = {},      -- [rowIndex] = { topY, bottomY }
    columns = {}    -- [sectionId] = { startX, width }
}

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

---Render the main table
---@param options? any Optional rendering options
function Grid.render(options)
    local ctx = State.imgui.ctx

    local tableData = Grid.getDataForGrid()
    local sortedSections = tableData.sortedSections
    
    -- Clear table geometry before starting table render
    tableGeometry.rows = {}
    tableGeometry.columns = {}
    
    -- Calculate number of columns: octave + pattern + sections + add section UI column
    local numColumns = 2 + #sortedSections + 1
    
    if reaper.ImGui_BeginTable(ctx, 'ensembler_prototype_table', numColumns, TABLE_FLAGS) then
        -- Calculate column widths for each section
        local sectionColumnWidths = {}
        for _, section in ipairs(sortedSections) do
            sectionColumnWidths[section.sectionId] = GridCell.calculateColumnWidth(ctx, tableData, section.sectionId)
        end
        
        -----
        -- Column and Headers
        -----

        -- Setup columns with explicit widths
        reaper.ImGui_TableSetupColumn(ctx, '', reaper.ImGui_TableColumnFlags_WidthFixed(), OCTAVE_COLUMN_WIDTH)  -- Octave column
        reaper.ImGui_TableSetupColumn(ctx, '', reaper.ImGui_TableColumnFlags_WidthFixed(), PATTERN_COLUMN_WIDTH)  -- Pattern column
        
        -- Setup section columns and record column positions
        for i, section in ipairs(sortedSections) do
            local columnWidth = sectionColumnWidths[section.sectionId]
            reaper.ImGui_TableSetupColumn(ctx, section.name, reaper.ImGui_TableColumnFlags_WidthFixed(), columnWidth)
        end
        
        -- Setup Add Section UI column (not part of data layer)
        reaper.ImGui_TableSetupColumn(ctx, '', reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
        
        -- Custom header row
        reaper.ImGui_TableNextRow(ctx, reaper.ImGui_TableRowFlags_Headers())
        reaper.ImGui_TableSetColumnIndex(ctx, 0)
        -- Empty header for Octave column
        reaper.ImGui_TableSetColumnIndex(ctx, 1)
        -- Empty header for Pattern column  
        
        -- Render section headers and record column positions
        for i, section in ipairs(sortedSections) do
            local columnIndex = 1 + i  -- +1 because we have octave and pattern columns
            reaper.ImGui_TableSetColumnIndex(ctx, columnIndex)
            
            -- Use the SectionHeaderButton component
            SectionHeaderButton.render(ctx, section, sectionColumnWidths[section.sectionId])
            
            -- Record column position after header is rendered
            local columnStartX = reaper.ImGui_GetCursorScreenPos(ctx)
            tableGeometry.columns[section.sectionId] = {
                startX = columnStartX,
                width = sectionColumnWidths[section.sectionId]
            }
        end
        
        -- Add Section header
        reaper.ImGui_TableSetColumnIndex(ctx, 1 + #sortedSections + 1)
        SectionHeaderButton.renderAddButton(ctx, 120)

        -----
        -- Voice Rows
        -----
        
        -- Generate voice table rows dynamically
        local pattern = generatePattern(tableData.voiceCount)
        local patternIndex = 1
        
        for rowIdx, rowData in ipairs(tableData.voiceRows) do
            -- TODO Revisit this code, it's kinda sloppy 
            reaper.ImGui_TableNextRow(ctx)

            reaper.ImGui_TableSetBgColor(ctx, reaper.ImGui_TableBgTarget_RowBg0(), 0x363636FF, -1)
            
            -- Record row Y position
            local _, rowTopY = reaper.ImGui_GetCursorScreenPos(ctx)
            
            -- Column 1: Octave labels (only in middle row of each octave section)
            reaper.ImGui_TableSetColumnIndex(ctx, 0)
            local rowInSection = ((rowIdx - 1) % tableData.voiceCount) + 1
            if rowInSection == math.ceil(tableData.voiceCount / 2) then  -- Middle voice of the octave
                if rowData.position.octave == 0 then  -- "as played" octave
                    -- Special handling for "as played" octave - render clickable voice count
                    if reaper.ImGui_Button(ctx, tostring(tableData.voiceCount) .. "##voice_selector_" .. rowIdx) then
                        reaper.ImGui_OpenPopup(ctx, "voice_selector")
                    end
                    reaper.ImGui_SameLine(ctx, 0, 4)  -- Small gap
                    reaper.ImGui_Text(ctx, "playable voices")
                    
                    -- Render voice selector popup immediately after button
                    renderVoiceSelector(ctx, tableData.voiceCount, 
                        function(newVoiceCount)
                            Ensemble.redistributeVoices(newVoiceCount)
                        end
                    )
                else
                    -- Regular octave labels
                    local octaveLabel = rowData.position.octave > 0 and ("+" .. rowData.position.octave .. " oct") or (rowData.position.octave .. " oct")
                    reaper.ImGui_Text(ctx, octaveLabel)
                end
            else
                reaper.ImGui_Text(ctx, "")
            end
            
            -- Column 2: Pattern values
            reaper.ImGui_TableSetColumnIndex(ctx, 1)
            reaper.ImGui_Text(ctx, pattern[patternIndex])
            
            -- Section columns: Render cells for each section
            for i, column in ipairs(rowData.columns) do
                reaper.ImGui_TableSetColumnIndex(ctx, 1 + i)  -- +1 because we have octave and pattern columns
                
                -- Render the cell
                GridCell.render(column, rowData.position, sectionColumnWidths[column.section.sectionId])
            end
            
            -- Add Section column (UI only - empty cells for voice rows)
            reaper.ImGui_TableSetColumnIndex(ctx, 1 + #sortedSections + 1)
            reaper.ImGui_Text(ctx, "")
            
            -- Record row bottom Y position
            local _, rowBottomY = reaper.ImGui_GetCursorScreenPos(ctx)
            tableGeometry.rows[rowIdx] = {
                topY = rowTopY,
                bottomY = rowBottomY
            }
            
            -- Advance pattern
            -- TODO - I don't like the name "pattern" here
            patternIndex = patternIndex + 1
            if patternIndex > tableData.voiceCount then
                patternIndex = 1
            end
        end
        
        -- Spacer row
        reaper.ImGui_TableNextRow(ctx)
        for col = 0, numColumns - 1 do
            reaper.ImGui_TableSetColumnIndex(ctx, col)
            reaper.ImGui_Text(ctx, "")
        end

        -----
        -- Chord Tone Rows
        -----
        
        for chordIdx, chordRowData in ipairs(tableData.chordToneRows) do
            reaper.ImGui_TableNextRow(ctx)
            
            -- Octave column: interactive chord tone label
            reaper.ImGui_TableSetColumnIndex(ctx, 0)
            local rowId = "chord_" .. chordIdx
            ChordToneLabel.render(
                ctx,
                chordRowData.position.targetNote,
                chordRowData.position.chordToneNum,
                rowId,
                function(oldTargetNote, oldChordToneNum, newChordToneNum)
                    -- Handle chord tone type change
                    Ensemble.modifyChordToneNumber(oldTargetNote, oldChordToneNum, newChordToneNum)
                end,
                function(oldTargetNote, oldChordToneNum, newTargetNote)
                    -- Handle target note change
                    Ensemble.modifyChordToneTargetNote(oldTargetNote, oldChordToneNum, newTargetNote)
                end,
                function(targetNote, chordToneNum)
                    -- Handle remove chord tone
                    Ensemble.removeChordTonePosition(targetNote, chordToneNum)
                end
            )
            
            -- Pattern column: empty for chord tones
            reaper.ImGui_TableSetColumnIndex(ctx, 1)
            reaper.ImGui_Text(ctx, "")
            
            -- Section columns: Render chord tone cells for each section
            for i, column in ipairs(chordRowData.columns) do
                reaper.ImGui_TableSetColumnIndex(ctx, 1 + i)  -- +1 because we have octave and pattern columns
                
                -- Render the cell
                GridCell.render(column, chordRowData.position, sectionColumnWidths[column.section.sectionId])
            end
            
            -- Add Section column (UI only - empty cells for chord tones)
            reaper.ImGui_TableSetColumnIndex(ctx, 1 + #sortedSections + 1)
            reaper.ImGui_Text(ctx, "")
        end
        
        reaper.ImGui_EndTable(ctx)
    end
    
    -- Render section drag handles after table is complete
    SectionHandles.render(ctx, tableGeometry, tableData)
end

--------------------------------------------------------------------------------
-- Data Processing
--------------------------------------------------------------------------------

---Generate UI data structure for the table renderer
---@return GridData
function Grid.getDataForGrid()
    local voiceCount = State.ensemble.getVoiceConfig()
    local sortedSections = State.ensemble.getActiveSectionsSorted()
    local numVisibleOctavesPositive, numVisibleOctavesNegative = State.ensemble.getOctaveRanges()
    
    -- Generate voice rows data using dynamic octave ranges
    local voiceRows = {}
    
    -- Iterate from +numVisibleOctavesPositive down to -numVisibleOctavesNegative
    for octave = numVisibleOctavesPositive, -numVisibleOctavesNegative, -1 do
        -- Iterate voices in reverse order (voice 3, 2, 1 for 3 voices)
        for voice = voiceCount, 1, -1 do
            ---@type GridVoiceRowData
            local rowData = {
                position = {
                    voice = voice,
                    octave = octave
                },
                columns = {}
            }
            
            -- Generate column data for each section
            for _, section in ipairs(sortedSections) do
                ---@type GridRowColumnData
                local columnData = {
                    section = section,
                    instruments = State.ensemble.getInstrumentsForVoiceOctaveSection(voice, octave, section.sectionId),
                    cellId = generateCellId({section = section}, {voice = voice, octave = octave})
                }
                rowData.columns[#rowData.columns+1] = columnData
            end
            
            table.insert(voiceRows, rowData)
        end
    end
    
    -- Generate chord tone rows data
    local chordToneRows = {}

    -- Use a sorted list of chord tones and then build the columns with instruments
    local sortedChordTones = State.ensemble.getSortedChordTones()
    for _, chordTonePosition in ipairs(sortedChordTones) do
        -- Generate column data for each section
        ---@type GridChordToneRowData
        local rowData = {
            position = chordTonePosition,
            columns = {}
        }

        for _, section in ipairs(sortedSections) do
            ---@type GridRowColumnData
            local columnData = {
                section = section,
                instruments = State.ensemble.getInstrumentsForChordToneTargetAndSection(chordTonePosition.targetNote, chordTonePosition.chordToneNum, section.sectionId),
                cellId = generateCellId({section = section}, chordTonePosition)
            }
            rowData.columns[#rowData.columns+1] = columnData
        end
        
        table.insert(chordToneRows, rowData)
    end
    
    return {
        sortedSections = sortedSections,
        voiceRows = voiceRows,
        chordToneRows = chordToneRows,
        voiceCount = voiceCount,
        numVisibleOctavesPositive = numVisibleOctavesPositive,
        numVisibleOctavesNegative = numVisibleOctavesNegative
    }
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

---Generate pattern values for a given voice count
---@param voiceCount integer
---@return string[]
function generatePattern(voiceCount)
    local pattern = {}
    for i = voiceCount, 1, -1 do  -- Count down from voiceCount to 1
        pattern[voiceCount - i + 1] = tostring(i)
    end
    return pattern
end

---Generate chord tone label based on target note and chord tone number
---@param targetNote string
---@param chordToneNum integer
---@return string
function generateChordToneLabel(targetNote, chordToneNum)
    local chordToneNames = {
        [0] = "Root",
        [4] = "Third", 
        [7] = "Fifth",
        [10] = "7th"
    }
    
    local chordToneName = chordToneNames[chordToneNum] or "Tone " .. chordToneNum
    return chordToneName .. " near " .. targetNote
end

---Generate cell identifier for consistent referencing
---@param cellData table Cell data containing section info
---@param position VoicePosition|ChordTonePosition Position info
---@return string
function generateCellId(cellData, position)
    local cellIdSuffix = "_" .. cellData.section.sectionId
    if position.voice then
        return position.voice .. "_" .. position.octave .. cellIdSuffix
    else 
        return position.targetNote .. "_" .. position.chordToneNum .. cellIdSuffix
    end
end

--------------------------------------------------------------------------------
-- Other
--------------------------------------------------------------------------------

---Render voice selector popup
---@param ctx ImGui_Context
---@param currentVoiceCount integer
---@param onVoiceSelected function
function renderVoiceSelector(ctx, currentVoiceCount, onVoiceSelected)
    if reaper.ImGui_BeginPopup(ctx, "voice_selector") then
        reaper.ImGui_SeparatorText(ctx, "Voices")
        for i = 1, 10 do
            if reaper.ImGui_Selectable(ctx, tostring(i)) then
                onVoiceSelected(i)
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
end

return Grid