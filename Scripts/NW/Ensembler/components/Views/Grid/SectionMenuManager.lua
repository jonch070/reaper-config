-- SectionMenuManager.lua - Centralized Section Modal Management

local SectionTemplates = require('modules/SectionTemplates')
local Modal = require('components/Modals/Modal')
local ModalManager = require('components/Modals/ModalManager')
local FilterInput = require('components/Selectors/FilterInput')

local SectionMenuManager = {}

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.UI)
end

-- Store template name for overwrite confirmation
---@type string|nil
local pendingTemplateName = nil
---@type Section|nil
local pendingSection = nil

-- Store template load confirmation data
---@type string|nil
local pendingLoadTemplateName = nil
---@type Section|nil
local pendingLoadSection = nil


-- Store section header button positions for FilterInput positioning
---@type table<string, Rect>
local sectionButtonPositions = {}

---Set pending template data for overwrite confirmation
---@param section Section
---@param templateName string
local function setPendingTemplate(section, templateName)
    pendingSection = section
    pendingTemplateName = templateName
end

---Clear pending template data
local function clearPendingTemplate()
    pendingSection = nil
    pendingTemplateName = nil
end

---Set pending load template data for confirmation
---@param section Section
---@param templateName string
local function setPendingLoadTemplate(section, templateName)
    pendingLoadSection = section
    pendingLoadTemplateName = templateName
end

---Clear pending load template data
local function clearPendingLoadTemplate()
    pendingLoadSection = nil
    pendingLoadTemplateName = nil
end

-- Modal ID helper functions
---@param sectionId string
---@return string
local function getSaveModalId(sectionId)
    return 'save_template_' .. sectionId
end

---@param sectionId string
---@return string
local function getOverwriteModalId(sectionId)
    return 'overwrite_template_' .. sectionId
end

---@param sectionId string
---@return string
local function getRenameModalId(sectionId)
    return 'rename_section_' .. sectionId
end

---@param sectionId string
---@return string
local function getClearModalId(sectionId)
    return 'clear_section_' .. sectionId
end

---@param sectionId string
---@return string
local function getLoadTemplateConfirmModalId(sectionId)
    return 'confirm_load_template_' .. sectionId
end

---@param sectionId string
---@return string
local function getDeleteModalId(sectionId)
    return 'delete_section_' .. sectionId
end


---Store section button position for FilterInput positioning
---@param sectionId string
---@param rect Rect
function SectionMenuManager.setSectionButtonPosition(sectionId, rect)
    sectionButtonPositions[sectionId] = rect
end

-- Public functions for SectionHeaderButton to call
---Open save template modal for section
---@param section Section
function SectionMenuManager.openSaveModal(section)
    setPendingTemplate(section, section.name)
    ModalManager.openPopupOnNextFrame(getSaveModalId(section.sectionId))
end

---Open rename modal for section
---@param section Section
function SectionMenuManager.openRenameModal(section)
    pendingSection = section
    ModalManager.openPopupOnNextFrame(getRenameModalId(section.sectionId))
end

---Open clear modal for section
---@param section Section
function SectionMenuManager.openClearModal(section)
    pendingSection = section
    ModalManager.openPopupOnNextFrame(getClearModalId(section.sectionId))
end

---Open delete modal for section
---@param section Section
function SectionMenuManager.openDeleteModal(section)
    pendingSection = section
    ModalManager.openPopupOnNextFrame(getDeleteModalId(section.sectionId))
end

---Generic template browser opener
---@param onItemSelected fun(templateName: string): nil Callback when template is selected
---@param positionKey? string Key for button position (defaults to "add_section")
local function openTemplateLoader(onItemSelected, positionKey)
    positionKey = positionKey or "add_section"
    
    -- Ensure template cache is loaded and open FilterInput browser
    SectionTemplates.ensureCache()
    FilterInput.setPopupToAppear({
        onItemSelected = function(selectedItem)
            onItemSelected(selectedItem.itemData)
        end,
        getFilteredList = function(searchQuery)
            return SectionTemplates.filter(searchQuery)
        end,
        isLoading = function()
            return not SectionTemplates.isCacheReady()
        end,
        showAllWhenEmpty = true,
        hintText = "Select a template",
        placeholderText = "Type to search templates..."
    }, sectionButtonPositions[positionKey])
end

---Open template browser for new section (creates section on template selection)
function SectionMenuManager.openTemplateLoaderForNewSection()
    openTemplateLoader(function(templateName)
        -- Create new section and load template into it
        local newSection = State.ensemble.createSection(templateName)
        local success = SectionTemplates.load(templateName, newSection.sectionId)
        if success then
            debug_log("Created new section and loaded template: " .. templateName)
        else
            debug_log("Failed to load template into new section: " .. templateName)
        end
        -- Clear cache when done
        SectionTemplates.clearCache()
    end)
end

---Open template browser for existing section
---@param section Section
function SectionMenuManager.openTemplateLoader(section)
    openTemplateLoader(function(templateName)
        -- Check if section has instruments before loading
        local existingInstruments = Ensemble.getFlatInstrumentsForSection(section.sectionId)
        if #existingInstruments > 0 then
            -- Store pending load data for confirmation modal
            setPendingLoadTemplate(section, templateName)
            -- Queue the confirmation modal to open on next frame
            ModalManager.openPopupOnNextFrame(getLoadTemplateConfirmModalId(section.sectionId))
            debug_log("Queued confirmation modal to open")
        else
            -- Load directly if section is empty
            local success = SectionTemplates.load(templateName, section.sectionId)
            if success then
                -- Update section name to match template name
                section.name = templateName
                Ensemble.wasUpdated()
                debug_log("Loaded template: " .. templateName)
            else
                debug_log("Failed to load template: " .. templateName)
            end
            -- Clear cache when done
            SectionTemplates.clearCache()
        end
    end, section.sectionId)
end

---Shared save function for template saving
---@param sectionId string
---@param templateName string
local function saveSectionIdAsTemplate(sectionId, templateName)
    local success = SectionTemplates.save(sectionId, templateName)
    if success then
        debug_log("Saved section template: " .. templateName)
        -- Clear cache so next load shows updated template list
        SectionTemplates.clearCache()
    else
        debug_log("Failed to save section template: " .. templateName)
    end
end

---Render save template modal
---@param ctx ImGui_Context
local function renderSaveModal(ctx)
    if not pendingSection then return end
    
    local modalId = getSaveModalId(pendingSection.sectionId)
    
    Modal.renderTextInput(ctx, modalId, 'Save Section Template', 'Enter name for section template:', {
        confirmText = "Save",
        initialText = pendingSection.name,
        onConfirm = function(templateName)
            -- Check if template already exists
            if SectionTemplates.templateExists(templateName) then
                -- Store pending data for overwrite confirmation
                setPendingTemplate(pendingSection, templateName)
                -- Queue overwrite confirmation modal
                ModalManager.openPopupOnNextFrame(getOverwriteModalId(pendingSection.sectionId))
            else
                -- Save directly if template doesn't exist
                saveSectionIdAsTemplate(pendingSection.sectionId, templateName)
            end
        end,
        onCancel = function()
            debug_log("Save template cancelled")
        end
    })
end

---Render rename section modal
---@param ctx ImGui_Context
local function renderRenameModal(ctx)
    if not pendingSection then return end
    
    local modalId = getRenameModalId(pendingSection.sectionId)
    
    Modal.renderTextInput(ctx, modalId, 'Rename Section', 'Enter new name for section:', {
        confirmText = "Rename",
        initialText = pendingSection.name,
        onConfirm = function(newName)
            pendingSection.name = newName
            Ensemble.wasUpdated() -- Trigger update to save changes
            debug_log("Renamed section to: " .. newName)
        end,
        onCancel = function()
            debug_log("Rename cancelled")
        end
    })
end

---Render clear section modal
---@param ctx ImGui_Context
local function renderClearModal(ctx)
    if not pendingSection then return end
    
    local modalId = getClearModalId(pendingSection.sectionId)
    local message = 'Clear all instruments from "' .. pendingSection.name .. '"?\nThis operation cannot be undone.'
    
    Modal.renderConfirmation(ctx, modalId, 'Clear Section', message, {
        confirmText = "Clear",
        onConfirm = function()
            -- Clear all instruments from this section
            local allInstruments = Ensemble.getAllInstruments()
            for i = #allInstruments, 1, -1 do
                local instrument = allInstruments[i]
                if instrument.position.sectionId == pendingSection.sectionId then
                    Ensemble.removeInstrumentFromCurrentPosition(instrument)
                end
            end
            debug_log("Cleared section: " .. pendingSection.name)
        end,
        onCancel = function()
            debug_log("Clear cancelled")
        end
    })
end

---Render overwrite template confirmation modal
---@param ctx ImGui_Context
local function renderOverwriteModal(ctx)
    if not pendingSection then return end
    
    local modalId = getOverwriteModalId(pendingSection.sectionId)
    local message = 'Template "' .. (pendingTemplateName or "") .. '" already exists.\nOverwrite existing template?'

    Modal.renderConfirmation(ctx, modalId, 'Overwrite Template', message, {
        confirmText = "Overwrite",
        onConfirm = function()
            -- Use stored pending data to save
            saveSectionIdAsTemplate(pendingSection.sectionId, pendingTemplateName)
            clearPendingTemplate()
        end,
        onCancel = function()
            clearPendingTemplate()
            debug_log("Overwrite cancelled")
            -- Queue save modal to reopen
            ModalManager.openPopupOnNextFrame(getSaveModalId(pendingSection.sectionId))
        end
    })
end

---Render load template confirmation modal
---@param ctx ImGui_Context
local function renderLoadTemplateConfirmModal(ctx)
    if not pendingLoadSection then return end
    
    local modalId = getLoadTemplateConfirmModalId(pendingLoadSection.sectionId)
    local message = 'This will replace all instruments in "' .. pendingLoadSection.name .. '".\nContinue?'
    
    Modal.renderConfirmation(ctx, modalId, 'Load Template', message, {
        confirmText = "Continue",
        onConfirm = function()
            -- Load the pending template
            if pendingLoadSection and pendingLoadTemplateName then
                local success = SectionTemplates.load(pendingLoadTemplateName, pendingLoadSection.sectionId)
                if success then
                    -- Update section name to match template name
                    pendingLoadSection.name = pendingLoadTemplateName
                    Ensemble.wasUpdated() -- Trigger update to save changes
                    debug_log("Loaded template: " .. pendingLoadTemplateName)
                else
                    debug_log("Failed to load template: " .. pendingLoadTemplateName)
                end
            end
            clearPendingLoadTemplate()
            -- Clear cache when done
            SectionTemplates.clearCache()
        end,
        onCancel = function()
            clearPendingLoadTemplate()
            -- Clear cache when cancelled
            SectionTemplates.clearCache()
            debug_log("Template load cancelled")
        end
    })
end

---Render delete section confirmation modal
---@param ctx ImGui_Context
local function renderDeleteModal(ctx)
    if not pendingSection then return end
    
    local modalId = getDeleteModalId(pendingSection.sectionId)
    local message = 'Delete section "' .. pendingSection.name .. '"?\n\nThis cannot be undone.'
    
    Modal.renderConfirmation(ctx, modalId, 'Delete Section', message, {
        confirmText = "Delete",
        onConfirm = function()
            local success = Ensemble.deleteSection(pendingSection.sectionId)
            if success then
                debug_log("Deleted section: " .. pendingSection.name)
            else
                debug_log("Failed to delete section: " .. pendingSection.name)
            end
        end,
        onCancel = function()
            debug_log("Delete section cancelled")
        end
    })
end


-- Register all section modals with ModalManager
ModalManager.addModalRenderer(function(ctx)
    renderSaveModal(ctx)
    renderRenameModal(ctx) 
    renderClearModal(ctx)
    renderOverwriteModal(ctx)
    renderLoadTemplateConfirmModal(ctx)
    renderDeleteModal(ctx)
end)

return SectionMenuManager