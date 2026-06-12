-- EnsemblePersistence.lua - Ensemble State Persistence Management
-- Handles saving/loading of ensemble state to both temporary ExtState and preset files

EnsemblePersistence = {}

local DataSerialization = require('utils/DataSerialization')
local FileUtils = require('utils/FileUtils')
local Cache = require('modules/Cache')
local RetroactiveRecord = require('modules/RetroactiveRecord')
local EnsembleUpgradePaths = require('modules/upgradePaths/EnsembleUpgradePaths')

-- Configuration
local TEMP_ENSEMBLE_KEY = "temp_ensemble"

-- Cache for preset filtering
local presetCache = Cache.create(function()
    local presetNames = EnsemblePersistence.loadPresetList()
    local cacheEntries = {}
    
    for _, presetName in ipairs(presetNames) do
        table.insert(cacheEntries, {
            name = presetName,
            id = presetName,
            itemData = presetName
        })
    end
    
    return cacheEntries
end)

--------------------------------------------------------------------------------
-- Save Data Preparation
--------------------------------------------------------------------------------

---Prepare ensemble state for saving with metadata
---@param isPreset boolean? If true, exclude runtime flags like is_modified
---@return EnsembleSaveState
local function getDataToSave()
    local saveData = State.ensemble.getStateForSaving()
    saveData.createdDate = os.time()
    saveData.version = EnsembleUpgradePaths.getCurrentVersion()

    return saveData
end

---Load ensemble data into state
---@param ensembleState EnsembleSaveState
---@return boolean success
local function loadEnsembleData(ensembleState)
    if not ensembleState then
        return false
    end

    -- Clear retroactive recording buffers when loading new ensemble
    RetroactiveRecord.clearAllBuffers()

    -- Load ensemble state (handles name, is_modified, wasUpdated internally)
    State.ensemble.loadEnsemble(ensembleState)

    return true
end

--------------------------------------------------------------------------------
-- Directory and File Path Helpers
--------------------------------------------------------------------------------

---Get ensemble presets directory path
---@return string
local function getPresetsDirectory()
    return State.config.PRESET_PATH
end

---Get full file path for preset
---@param presetName string
---@return string
local function getPresetFilePath(presetName)
    return getPresetsDirectory() .. presetName .. ".lua"
end

---Ensure presets directory exists
local function ensureDirectory()
    local path = getPresetsDirectory()
    FileUtils.ensureDirectory(path)
end

--------------------------------------------------------------------------------
-- Temporary State Persistence (ExtState)
--------------------------------------------------------------------------------

---Save state data to project ExtState
---@param stateToSave EnsembleSaveState
local function saveTempStateToProjectExtState(stateToSave)
    Debug.log("Temp state to save", Debug.FEATURE.PERSISTENCE)
    Debug.log(stateToSave, Debug.FEATURE.PERSISTENCE)

    local stateString = DataSerialization.tableToString(stateToSave)
    reaper.SetProjExtState(0, State.config.EXTSTATE_SECTION, TEMP_ENSEMBLE_KEY, stateString)
end

---Save current ensemble state to project ExtState
---@return boolean success
function EnsemblePersistence.saveTempState()
    local stateToSave = getDataToSave()
    saveTempStateToProjectExtState(stateToSave)
    return true
end

---Load ensemble state from project ExtState
---@return boolean success
function EnsemblePersistence.loadTempState()
    local retval, stateString = reaper.GetProjExtState(0, State.config.EXTSTATE_SECTION, TEMP_ENSEMBLE_KEY)

    if retval == 0 or stateString == "" then
        Debug.log("No temp state found", Debug.FEATURE.PERSISTENCE)
        return false
    end
    Debug.log("Loaded temp state string", Debug.FEATURE.PERSISTENCE)
    Debug.log(stateString, Debug.FEATURE.PERSISTENCE)

    local stateToLoad = DataSerialization.stringToTable(stateString)
    if not stateToLoad then
        Debug.error("Failed to parse temp state", Debug.FEATURE.PERSISTENCE)
        return false
    end
    Debug.log("Loaded temp state table", Debug.FEATURE.PERSISTENCE)
    Debug.log(stateToLoad, Debug.FEATURE.PERSISTENCE)

    -- Run migrations if needed
    local upgradedData, didUpgrade = EnsembleUpgradePaths.migrateIfNeeded(stateToLoad)

    if not upgradedData then
        Debug.error("Failed to migrate temp state", Debug.FEATURE.PERSISTENCE)
        return false
    end

    -- Save migrated temp state back if it was upgraded
    if didUpgrade then
        saveTempStateToProjectExtState(upgradedData)
        Debug.log("Saved migrated temp state", Debug.FEATURE.PERSISTENCE)
    end

    -- Load into state
    if loadEnsembleData(upgradedData) then
        Debug.log("Loaded temp state", Debug.FEATURE.PERSISTENCE)
        return true
    else
        return false
    end
end

---Clear temporary state from project ExtState
function EnsemblePersistence.clearTempState()
    reaper.SetProjExtState(0, State.config.EXTSTATE_SECTION, TEMP_ENSEMBLE_KEY, "")
    Debug.log("Cleared temp state", Debug.FEATURE.PERSISTENCE)
end

--------------------------------------------------------------------------------
-- Ensemble Preset Persistence (Files)
--------------------------------------------------------------------------------

---Save ensemble state to preset file
---@param ensembleState EnsembleSaveState State to save
---@param presetName string Name of preset
---@return boolean success
local function savePresetToFile(ensembleState, presetName)
    local filePath = getPresetFilePath(presetName)

    if DataSerialization.saveToFile(ensembleState, filePath) then
        Debug.log("Saved ensemble preset to " .. filePath, Debug.FEATURE.PERSISTENCE)
        return true
    else
        Debug.error("Failed to save ensemble preset to " .. filePath, Debug.FEATURE.PERSISTENCE)
        return false
    end
end

---Check if current ensemble name is the default name
---@return boolean
function EnsemblePersistence.isDefaultName()
    local currentName = State.ensemble.name or State.config.DEFAULT_ENSEMBLE_NAME
    return currentName == State.config.DEFAULT_ENSEMBLE_NAME
end

---Save ensemble as preset file
---@param presetName string Name for the preset
---@return boolean success
function EnsemblePersistence.savePreset(presetName)
    if not presetName or presetName == "" then
        Debug.warn("Invalid preset name for saving", Debug.FEATURE.PERSISTENCE)
        return false
    end
    
    ensureDirectory()
    
    -- Get ensemble state with metadata (exclude runtime flags for presets)
    local ensembleState = getDataToSave(true)
    ensembleState.name = presetName -- Replace the name with what was given by user
    ensembleState.is_modified = nil -- Do not save this for preset files

    if savePresetToFile(ensembleState, presetName) then
        -- Update ensemble name and clear modified flag
        State.ensemble.name = presetName    -- Replace the ensemble name with the new name
        State.ensemble.is_modified = false  -- It's saved, no longer modified
        -- Clear cache so next load shows updated preset list
        EnsemblePersistence.clearPresetCache()
        return true
    else
        return false
    end
end

---Load ensemble preset from file
---@param presetName string Name of preset to load
---@return boolean success
function EnsemblePersistence.loadPreset(presetName)
    if not presetName then
        Debug.warn("Invalid preset name for loading", Debug.FEATURE.PERSISTENCE)
        return false
    end

    local filePath = getPresetFilePath(presetName)

    -- Load using shared serialization utility
    local ensembleState = DataSerialization.loadFromFile(filePath)
    if not ensembleState then
        Debug.error("Failed to load ensemble preset: " .. presetName, Debug.FEATURE.PERSISTENCE)
        return false
    end

    -- Run migrations if needed
    local upgradedData, didUpgrade = EnsembleUpgradePaths.migrateIfNeeded(ensembleState)

    if not upgradedData then
        Debug.error("Failed to migrate ensemble preset: " .. presetName, Debug.FEATURE.PERSISTENCE)
        return false
    end

    -- Save migrated preset back to file if it was upgraded
    if didUpgrade then
        savePresetToFile(upgradedData, presetName)
    end

    -- Load into state
    if loadEnsembleData(upgradedData) then
        Debug.log("Loaded ensemble preset: " .. presetName, Debug.FEATURE.PERSISTENCE)
        -- Clear modified flag since we just loaded a saved preset
        -- loadEnsembleData will call wasUpdated which will set is_modified to true, we have to override that here
        State.ensemble.is_modified = false
        return true
    else
        Debug.warn("Failed to load ensemble preset: " .. presetName, Debug.FEATURE.PERSISTENCE)
        return false
    end
end

---Check if preset file exists
---@param presetName string Name of preset to check
---@return boolean exists
function EnsemblePersistence.presetExists(presetName)
    local filePath = getPresetFilePath(presetName)
    return FileUtils.fileExists(filePath)
end

---Load list of available preset names
---@return string[] presetNames
function EnsemblePersistence.loadPresetList()
    ensureDirectory()
    local presetNames = {}
    
    -- Get all Lua files in presets directory
    local files = FileUtils.enumerateFiles(getPresetsDirectory(), "lua")
    for _, presetName in ipairs(files) do
        table.insert(presetNames, presetName)
    end
    
    -- Sort alphabetically
    table.sort(presetNames)

    Debug.log("Found " .. #presetNames .. " ensemble presets", Debug.FEATURE.PERSISTENCE)
    return presetNames
end

--------------------------------------------------------------------------------
-- Preset Cache for FilterInput Integration
--------------------------------------------------------------------------------

---Ensure preset cache is loaded for filtering
function EnsemblePersistence.ensurePresetCache()
    presetCache:ensureCache()
end

---Check if preset cache is ready
---@return boolean ready
function EnsemblePersistence.isPresetCacheReady()
    -- With the new cache system, we can always consider it "ready"
    -- since getData() will load synchronously if needed
    return true
end

---Clear preset cache
function EnsemblePersistence.clearPresetCache()
    presetCache:clear()
end

---Filter presets by search query for FilterInput
---@param searchQuery string Search text to filter by
---@return FilterInputItem[] filteredPresets Array of preset FilterInputItem objects
function EnsemblePersistence.filterPresets(searchQuery)
    -- Get cached data (loads if needed)
    local cacheEntries = presetCache:getData()
    
    if not searchQuery or searchQuery == "" then
        return cacheEntries
    end
    
    local filteredResults = {}
    local searchLower = searchQuery:lower()
    
    -- Priority sorting: name matches first
    local frontMatches = {}
    local containsMatches = {}
    
    for _, preset in ipairs(cacheEntries) do
        local nameLower = preset.name:lower()
        
        if nameLower:sub(1, #searchLower) == searchLower then
            table.insert(frontMatches, preset)
        elseif nameLower:find(searchLower, 1, true) then
            table.insert(containsMatches, preset)
        end
    end
    
    -- Combine results in priority order
    for _, preset in ipairs(frontMatches) do
        table.insert(filteredResults, preset)
    end
    for _, preset in ipairs(containsMatches) do
        table.insert(filteredResults, preset)
    end
    
    return filteredResults
end

return EnsemblePersistence