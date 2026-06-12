-- SectionTemplateUpgradePaths.lua - Section Template Data Migrations
-- Manages version upgrades for section template data

local SectionTemplateUpgradePaths = {}

local UpgradePathManager = require('modules/upgradePaths/UpgradePathManager')

-- Current section template version
-- Increment this when making breaking changes to template data structure
local CURRENT_VERSION = 2

-- Template migrations (version number as key)
-- Each migration function takes data from previous version and returns upgraded data
-- Add detailed comments for each migration describing what changed and why
local MIGRATIONS = {
    -- Example: When we need to add a migration from v6 to v7:
    -- [7] = function(data)
    --     -- [App v0.3.0] Restructured instrument transforms
    --     -- Breaking change: Moved velocity/cc transforms into nested table
    --     return data
    -- end,
}

---Migrate template data if needed
---@param data SectionTemplate The template data to migrate
---@return SectionTemplate|nil upgradedData The migrated data, or nil if migration failed
---@return boolean didUpgrade Whether migration occurred
function SectionTemplateUpgradePaths.migrateIfNeeded(data)
    return UpgradePathManager.migrate(data, CURRENT_VERSION, MIGRATIONS, "template")
end

---Get the current template version
---@return integer version Current version number
function SectionTemplateUpgradePaths.getCurrentVersion()
    return CURRENT_VERSION
end

return SectionTemplateUpgradePaths
