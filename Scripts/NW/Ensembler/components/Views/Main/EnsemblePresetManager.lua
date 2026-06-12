-- EnsemblePresetManager.lua - Centralized Ensemble Preset Modal Management

local Modal = require('components/Modals/Modal')
local ModalManager = require('components/Modals/ModalManager')

local EnsemblePresetManager = {}

local debug_log = State.debug_log

-- Store preset name for overwrite confirmation
---@type string|nil
local pendingPresetName = nil


---Set pending preset data for overwrite confirmation
---@param presetName string
local function setPendingPreset(presetName)
    pendingPresetName = presetName
end

---Clear pending preset data
local function clearPendingPreset()
    pendingPresetName = nil
end

-- Modal ID helper functions
local function getSaveModalId()
    return 'save_ensemble_preset'
end

local function getOverwriteModalId()
    return 'overwrite_ensemble_preset'
end


-- Public functions for EnsembleHeader to call
---Open save preset modal
function EnsemblePresetManager.openSaveModal()
    local currentName = State.ensemble.name or State.config.DEFAULT_ENSEMBLE_NAME
    
    -- Default to current name unless it's the default name
    local initialText = ""
    if currentName ~= State.config.DEFAULT_ENSEMBLE_NAME then
        initialText = currentName
    end
    
    setPendingPreset(initialText)
    ModalManager.openPopupOnNextFrame(getSaveModalId())
end

---Handle save button logic (save directly or open save as)
function EnsemblePresetManager.handleSaveButton()
    if EnsemblePersistence.isDefaultName() then
        -- Name is default, force Save As
        EnsemblePresetManager.openSaveModal()
    else
        -- Save directly to current name
        local currentName = State.ensemble.name
        local success = EnsemblePersistence.savePreset(currentName)
        if success then
            debug_log("Saved ensemble preset: " .. currentName)
        else
            debug_log("Failed to save ensemble preset: " .. currentName)
        end
    end
end

---Open preset browser for loading
function EnsemblePresetManager.openPresetBrowser()
    State.ui.show_preset_browser = true
end

---Shared save function for preset saving
---@param presetName string
local function saveEnsemblePreset(presetName)
    local success = EnsemblePersistence.savePreset(presetName)
    if success then
        debug_log("Saved ensemble preset: " .. presetName)
        -- Clear preset cache so next browser load shows updated list
        EnsemblePersistence.clearPresetCache()
    else
        debug_log("Failed to save ensemble preset: " .. presetName)
    end
end

---Render save preset modal
---@param ctx ImGui_Context
local function renderSaveModal(ctx)
    local modalId = getSaveModalId()
    
    Modal.renderTextInput(ctx, modalId, 'Save Ensemble Preset', 'Enter name for ensemble preset:', {
        confirmText = "Save",
        initialText = pendingPresetName or "",
        onConfirm = function(presetName)
            -- Check if preset already exists
            if EnsemblePersistence.presetExists(presetName) then
                -- Store pending data for overwrite confirmation
                setPendingPreset(presetName)
                -- Queue overwrite confirmation modal
                ModalManager.openPopupOnNextFrame(getOverwriteModalId())
            else
                -- Save directly if preset doesn't exist
                saveEnsemblePreset(presetName)
            end
        end,
        onCancel = function()
            clearPendingPreset()
            debug_log("Save preset cancelled")
        end
    })
end

---Render overwrite preset confirmation modal
---@param ctx ImGui_Context
local function renderOverwriteModal(ctx)
    local modalId = getOverwriteModalId()
    local message = 'Preset "' .. (pendingPresetName or "") .. '" already exists.\nOverwrite existing preset?'

    Modal.renderConfirmation(ctx, modalId, 'Overwrite Preset', message, {
        confirmText = "Overwrite",
        onConfirm = function()
            -- Use stored pending data to save
            saveEnsemblePreset(pendingPresetName)
            clearPendingPreset()
        end,
        onCancel = function()
            clearPendingPreset()
            debug_log("Overwrite cancelled")
            -- Queue save modal to reopen
            ModalManager.openPopupOnNextFrame(getSaveModalId())
        end
    })
end

-- Register all ensemble preset modals with ModalManager
ModalManager.addModalRenderer(function(ctx)
    renderSaveModal(ctx)
    renderOverwriteModal(ctx)
end)

return EnsemblePresetManager