-- EnsembleUpgradePaths.lua - Ensemble State Data Migrations
-- Manages version upgrades for ensemble state data (presets and temp state)

local EnsembleUpgradePaths = {}

local UpgradePathManager = require('modules/upgradePaths/UpgradePathManager')

-- Current ensemble state version
-- Increment this when making breaking changes to ensemble data structure
local CURRENT_VERSION = 6

-- Ensemble state migrations (version number as key)
-- Each migration function takes data from previous version and returns upgraded data
-- Add detailed comments for each migration describing what changed and why
local MIGRATIONS = {
    -- Example: When we need to add a migration from v6 to v7:
    -- [7] = function(data)
    --     -- [App v0.3.0] Added color field for sections
    --     -- Breaking change: UI now expects sections to have color property
    --     for _, section in ipairs(data.sections) do
    --         section.color = "#FFFFFF"  -- Default white
    --     end
    --     return data
    -- end,
}

---Migrate ensemble state data if needed
---@param data EnsembleSaveState The ensemble data to migrate
---@return EnsembleSaveState|nil upgradedData The migrated data, or nil if migration failed
---@return boolean didUpgrade Whether migration occurred
function EnsembleUpgradePaths.migrateIfNeeded(data)
    return UpgradePathManager.migrate(data, CURRENT_VERSION, MIGRATIONS, "ensemble")
end

---Get the current ensemble state version
---@return integer version Current version number
function EnsembleUpgradePaths.getCurrentVersion()
    return CURRENT_VERSION
end

return EnsembleUpgradePaths
