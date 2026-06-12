-- SectionTemplates.lua - Section Template Save/Load Management

local DataSerialization = require('utils/DataSerialization')
local FileUtils = require('utils/FileUtils')
local Cache = require('modules/Cache')
local SectionTemplateUpgradePaths = require('modules/upgradePaths/SectionTemplateUpgradePaths')

SectionTemplates = {}

---Get templates directory path
---@return string templatesPath
local function getTemplatesPath()
    return State.config.PRESET_PATH .. "templates/"
end

---Get full file path for template
---@param templateName string Name of template
---@return string filePath
local function getTemplateFilePath(templateName)
    return getTemplatesPath() .. templateName .. ".lua"
end

-- Template cache for search performance
local templateCache = Cache.create(function()
    local templateNames = SectionTemplates.loadList()
    local cacheEntries = {}
    
    for _, templateName in ipairs(templateNames) do
        local template = DataSerialization.loadFromFile(getTemplateFilePath(templateName))
        local instrumentNames = {}
        
        if template and template.instruments then
            for _, instrument in ipairs(template.instruments) do
                if instrument.name then
                    table.insert(instrumentNames, instrument.name)
                end
            end
        end
        
        table.insert(cacheEntries, {
            name = templateName,
            instrumentNames = instrumentNames
        })
    end
    
    return cacheEntries
end)

---Save template to file
---@param template SectionTemplate Template data to save
---@param templateName string Name of template
---@return boolean success
local function saveTemplateToFile(template, templateName)
    local file_path = getTemplateFilePath(templateName)

    if DataSerialization.saveToFile(template, file_path) then
        Debug.log("Saved section template to " .. file_path, Debug.FEATURE.PERSISTENCE)
        return true
    else
        Debug.error("Failed to save section template to " .. file_path, Debug.FEATURE.PERSISTENCE)
        return false
    end
end

---Ensure template directory exists
function SectionTemplates.ensureDirectory()
    FileUtils.ensureDirectory(getTemplatesPath())
end

---Ensure template cache is loaded for search performance
function SectionTemplates.ensureCache()
    templateCache:ensureCache()
end

---Check if template cache is ready
---@return boolean ready
function SectionTemplates.isCacheReady()
    -- With the new cache system, we can always consider it "ready"
    -- since getData() will load synchronously if needed
    return true
end

---Clear template cache to free memory
function SectionTemplates.clearCache()
    templateCache:clear()
end

---Load template list from directory
---@return string[] templateNames
function SectionTemplates.loadList()
    SectionTemplates.ensureDirectory()
    local templateList = FileUtils.enumerateFiles(getTemplatesPath(), "lua")
    Debug.log("Loaded " .. #templateList .. " section templates", Debug.FEATURE.PERSISTENCE)
    return templateList
end

---Save section as template
---@param sectionId string Section identifier to save
---@param templateName string Name for the template
---@return boolean success
function SectionTemplates.save(sectionId, templateName)
    if not sectionId or not templateName then
        Debug.warn("Invalid parameters for saving section template", Debug.FEATURE.PERSISTENCE)
        return false
    end

    SectionTemplates.ensureDirectory()

    -- Get flat instruments for this section
    local sectionInstruments = Ensemble.getFlatInstrumentsForSection(sectionId)

    if #sectionInstruments == 0 then
        Debug.warn("No instruments found in section, cannot save empty template", Debug.FEATURE.PERSISTENCE)
        return false
    end
    
    -- Create template data structure
    local template = {
        name = templateName,
        originalVoiceCount = Ensemble.getVoiceConfig(),
        instruments = sectionInstruments,
        version = SectionTemplateUpgradePaths.getCurrentVersion(),
        metadata = {
            createdDate = os.time()
        }
    }

    return saveTemplateToFile(template, templateName)
end

---Load template into section
---@param templateName string Name of template to load
---@param targetSectionId string Section identifier to load into
---@return boolean success
function SectionTemplates.load(templateName, targetSectionId)
    if not templateName or not targetSectionId then
        Debug.warn("Invalid parameters for loading section template", Debug.FEATURE.PERSISTENCE)
        return false
    end

    local file_path = getTemplateFilePath(templateName)

    -- Load using shared serialization utility
    local template = DataSerialization.loadFromFile(file_path)
    if not template then
        Debug.error("Failed to load section template: " .. templateName, Debug.FEATURE.PERSISTENCE)
        return false
    end

    -- Run migrations if needed
    local upgradedTemplate, didUpgrade = SectionTemplateUpgradePaths.migrateIfNeeded(template)

    if not upgradedTemplate then
        -- Migration failed (likely newer version)
        Debug.error("Failed to migrate template: " .. templateName, Debug.FEATURE.PERSISTENCE)
        return false
    end

    -- Save migrated data back to file if it was upgraded
    if didUpgrade then
        saveTemplateToFile(upgradedTemplate, templateName)
    end

    -- Use the upgraded template for loading
    template = upgradedTemplate

    -- Check if target section has instruments (for confirmation prompt)
    local existingInstruments = Ensemble.getFlatInstrumentsForSection(targetSectionId)
    if #existingInstruments > 0 then
        -- TODO: Show confirmation dialog - "This will replace all instruments in [Section Name]. Continue?"
        Debug.log("Target section has instruments - should show confirmation dialog", Debug.FEATURE.PERSISTENCE)
    end
    
    -- Clear target section by removing all its instruments
    local allInstruments = Ensemble.getAllInstruments()
    for i = #allInstruments, 1, -1 do
        local instrument = allInstruments[i]
        if instrument.position.sectionId == targetSectionId then
            Ensemble.removeInstrumentFromCurrentPosition(instrument)
        end
    end
    
    -- Get current voice count for redistribution
    local currentVoiceCount = Ensemble.getVoiceConfig()
    local templateVoiceCount = template.originalVoiceCount or currentVoiceCount
    
    -- Redistribute instruments if voice counts don't match
    ---@type InstrumentFlat[]
    local instrumentsToLoad = template.instruments or {}
    if templateVoiceCount ~= currentVoiceCount then
        -- Translate each instrument's position to the new voice count
        for _, instrument in ipairs(instrumentsToLoad) do
            instrument.position = Ensemble.translateVoicePositionToNewNumVoices(
                instrument.position,
                templateVoiceCount,
                currentVoiceCount
            )
        end
    end
    
    -- Load instruments into target section
    for _, instrumentData in ipairs(instrumentsToLoad) do
        -- Create instrument from template data
        local newInstrument = Ensemble.createInstrumentFromLoadData({
            name = instrumentData.name,
            trackGuid = instrumentData.trackGuid,
            position = instrumentData.position
        })
        
        -- TODO: Handle missing tracks gracefully
        
        -- Add to target section
        if instrumentData.position.voice then
            Ensemble.addInstrumentToSectionAtVoiceAndOctave(
                newInstrument,
                targetSectionId,
                instrumentData.position.voice.voice,
                instrumentData.position.voice.octave
            )
        elseif instrumentData.position.chordTone then
            Ensemble.addInstrumentToSectionAtChordTone(
                newInstrument,
                targetSectionId,
                instrumentData.position.chordTone.targetNote,
                instrumentData.position.chordTone.chordToneNum
            )
        end
    end

    Debug.log("Loaded section template: " .. templateName .. " into section: " .. targetSectionId, Debug.FEATURE.PERSISTENCE)
    return true
end

---Check if template exists
---@param templateName string Name of template to check
---@return boolean exists
function SectionTemplates.templateExists(templateName)
    local file_path = getTemplateFilePath(templateName)
    return FileUtils.fileExists(file_path)
end

---Filter templates by search query with prioritized sorting
---@param searchQuery string Search text to filter by
---@return FilterInputItem[] filteredTemplates Array of template FilterInputItem objects
function SectionTemplates.filter(searchQuery)
    -- Get cached data (loads if needed)
    local cacheEntries = templateCache:getData()
    
    -- Convert cache entries to FilterInputItem objects
    local allTemplateItems = {}
    for _, cacheEntry in ipairs(cacheEntries) do
        table.insert(allTemplateItems, {
            name = cacheEntry.name,
            id = cacheEntry.name,  -- Template name is unique
            itemData = cacheEntry.name
        })
    end
    
    -- If no search query, return all templates alphabetically sorted
    if not searchQuery or searchQuery == "" then
        table.sort(allTemplateItems, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
        return allTemplateItems
    end
    
    local queryLower = searchQuery:lower()
    local frontMatches = {}      -- Templates starting with query
    local containsMatches = {}   -- Templates containing query (not at start)
    local instrumentMatches = {} -- Templates with matching instrument names
    
    for i, cacheEntry in ipairs(cacheEntries) do
        local templateItem = allTemplateItems[i]
        local nameLower = cacheEntry.name:lower()
        
        -- Check for front match (starts with query)
        local frontMatch = nameLower:find("^" .. queryLower:gsub("([^%w])", "%%%1"))
        if frontMatch then
            table.insert(frontMatches, templateItem)
            goto continue -- Skip other checks for this template
        end
        
        -- Check for contains match (query anywhere in name, but not at start)
        local containsMatch = nameLower:find(queryLower, 1, true)
        if containsMatch then
            table.insert(containsMatches, templateItem)
            goto continue -- Skip instrument search for this template
        end
        
        -- Search cached instrument names (only if template name didn't match)
        for _, instrumentName in ipairs(cacheEntry.instrumentNames) do
            if instrumentName:lower():find(queryLower, 1, true) then
                table.insert(instrumentMatches, templateItem)
                break -- Found match, don't need to check more instruments
            end
        end
        
        ::continue::
    end
    
    -- Combine all results
    local result = {}
    for _, template in ipairs(frontMatches) do
        table.insert(result, template)
    end
    for _, template in ipairs(containsMatches) do
        table.insert(result, template)
    end
    for _, template in ipairs(instrumentMatches) do
        table.insert(result, template)
    end

    -- Sort alphabetically
    table.sort(result, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return result
end

---Delete template file
---@param templateName string Name of template to delete
function SectionTemplates.delete(templateName)
    local file_path = getTemplateFilePath(templateName)
    FileUtils.deleteFile(file_path)
    Debug.log("Deleted section template: " .. templateName, Debug.FEATURE.PERSISTENCE)
end

return SectionTemplates