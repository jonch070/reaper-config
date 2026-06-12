-- SectionHeaderButton.lua - Section Header with Menu Component

local SectionMenuManager = require('components/Views/Grid/SectionMenuManager')

local SectionHeaderButton = {}

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.UI)
end

---Render the dropdown menu
---@param ctx ImGui_Context
---@param section Section
---@param popupId string
local function renderMenu(ctx, section, popupId)
    if reaper.ImGui_BeginPopup(ctx, popupId) then
        if reaper.ImGui_Selectable(ctx, 'Save Section as Template') then
            SectionMenuManager.openSaveModal(section)
        end
        
        if reaper.ImGui_Selectable(ctx, 'Load Section Template') then
            SectionMenuManager.openTemplateLoader(section)
        end
        
        if reaper.ImGui_Selectable(ctx, 'Rename Section') then
            SectionMenuManager.openRenameModal(section)
        end
        
        -- Check if section has instruments before offering clear
        local hasInstruments = #Ensemble.getFlatInstrumentsForSection(section.sectionId) > 0
        
        if not hasInstruments then
            reaper.ImGui_BeginDisabled(ctx)
        end
        
        if reaper.ImGui_Selectable(ctx, 'Clear Section') then
            if hasInstruments then
                SectionMenuManager.openClearModal(section)
            end
        end
        
        if not hasInstruments then
            reaper.ImGui_EndDisabled(ctx)
        end
        
        reaper.ImGui_Separator(ctx)
        
        if reaper.ImGui_Selectable(ctx, 'Delete Section') then
            local hasInstruments = #Ensemble.getFlatInstrumentsForSection(section.sectionId) > 0
            if hasInstruments then
                -- Show confirmation for sections with instruments
                SectionMenuManager.openDeleteModal(section)
            else
                -- Delete empty sections immediately
                local success = Ensemble.deleteSection(section.sectionId)
                if success then
                    debug_log("Deleted empty section: " .. section.name)
                else
                    debug_log("Failed to delete section: " .. section.name)
                end
            end
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
end

---Render the "Add Section" menu
---@param ctx ImGui_Context
---@param popupId string
local function renderAddSectionMenu(ctx, popupId)
    if reaper.ImGui_BeginPopup(ctx, popupId) then
        if reaper.ImGui_Selectable(ctx, 'Load Section Template') then
            -- Open template browser without creating section yet
            SectionMenuManager.openTemplateLoaderForNewSection()
        end
        
        if reaper.ImGui_Selectable(ctx, 'Create New Section') then
            State.ensemble.createSection(State.config.DEFAULT_SECTION_NAME)
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
end

---Render section header button (assumes it's being called within a table context)
---@param ctx ImGui_Context
---@param section Section
---@param width number
---@return boolean clicked True if header was clicked
function SectionHeaderButton.render(ctx, section, width)
    local headerClicked = reaper.ImGui_Button(ctx, section.name .. "##" .. section.sectionId, width)
    
    -- Capture button position for FilterInput positioning
    if headerClicked then
        SectionMenuManager.setSectionButtonPosition(section.sectionId, Utils.getItemRect(ctx))
    end
    
    local popupId = 'section_menu_' .. section.sectionId
    
    -- Open menu on click
    if headerClicked then
        reaper.ImGui_OpenPopup(ctx, popupId)
    end
    
    -- Render menu
    renderMenu(ctx, section, popupId)
    
    return headerClicked
end

---Render add section button with template loading support
---@param ctx ImGui_Context
---@param width number
---@return boolean clicked True if button was clicked
function SectionHeaderButton.renderAddButton(ctx, width)
    local addClicked = reaper.ImGui_Button(ctx, "Add Section", width)
    
    -- Capture button position for FilterInput positioning  
    if addClicked then
        SectionMenuManager.setSectionButtonPosition("add_section", Utils.getItemRect(ctx))
    end
    
    local popupId = 'add_section_menu'
    
    -- Open menu on click
    if addClicked then
        reaper.ImGui_OpenPopup(ctx, popupId)
    end
    
    -- Render add section menu
    renderAddSectionMenu(ctx, popupId)
    
    return addClicked
end

return SectionHeaderButton