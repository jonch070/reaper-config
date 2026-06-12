-- EnsembleHeader.lua - Ensemble Name and Save/Load UI

local EnsembleHeader = {}
local EnsemblePresetManager = require('components/Views/Main/EnsemblePresetManager')
local FilterInput = require('components/Selectors/FilterInput')

---Render the ensemble header with name display and save/load controls
---@param ctx ImGui_Context
function EnsembleHeader.render(ctx)
    local ensembleName = State.ensemble.name or "New Ensemble"
    local isModified = State.ensemble.is_modified or false
    
    -- Display ensemble name (clickable for preset browser)
    local displayName = ensembleName .. (isModified and "*" or "")
    
    -- Make ensemble name clickable
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000) -- Transparent
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x33333333) -- Light hover
    
    local nameClicked = reaper.ImGui_Button(ctx, displayName, 0, 0)
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    if nameClicked then
        -- Ensure preset cache is loaded and trigger FilterInput popup
        EnsemblePersistence.ensurePresetCache()
        FilterInput.setPopupToAppear({
            onItemSelected = function(selectedItem)
                local presetName = selectedItem.itemData
                local success = EnsemblePersistence.loadPreset(presetName)
                if success then
                    Debug.log("Loaded ensemble preset: " .. presetName, Debug.FEATURE.UI)
                else
                    Debug.error("Failed to load ensemble preset: " .. presetName, Debug.FEATURE.UI)
                end
            end,
            getFilteredList = function(searchQuery)
                return EnsemblePersistence.filterPresets(searchQuery)
            end,
            isLoading = function()
                return not EnsemblePersistence.isPresetCacheReady()
            end,
            showAllWhenEmpty = true,
            hintText = "Select an ensemble preset",
            placeholderText = "Type to search presets..."
        })
    end
    
    -- Add Save and Save As buttons
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_SameLine(ctx)
    
    if reaper.ImGui_Button(ctx, "Save", 60, 0) then
        EnsemblePresetManager.handleSaveButton()
    end
    
    reaper.ImGui_SameLine(ctx)
    
    if reaper.ImGui_Button(ctx, "Save As", 60, 0) then
        EnsemblePresetManager.openSaveModal()
    end
end

return EnsembleHeader