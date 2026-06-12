-- UpgradePathManager.lua - Generic Data Version Migration Engine
-- Provides reusable migration logic for any data type that needs versioning

local UpgradePathManager = {}

---Run migrations on data from old version to current version
---@param data table The data to migrate
---@param currentVersion integer Target version (e.g., 6)
---@param migrations table<integer, function> Migration functions keyed by version number
---@param dataTypeName string Type of data being migrated (for logging)
---@return table|nil upgradedData The migrated (or original) data, or nil if migration failed
---@return boolean didUpgrade Whether migration occurred
function UpgradePathManager.migrate(data, currentVersion, migrations, dataTypeName)
    -- Validate data has version
    if not data.version then
        Debug.error(
            "Cannot load " .. dataTypeName .. " - missing version field. Data may be corrupted.",
            Debug.FEATURE.PERSISTENCE
        )
        return nil, false
    end

    local dataVersion = tonumber(data.version)

    -- Check if already at current version
    if dataVersion == currentVersion then
        Debug.log("Data already at current version " .. currentVersion, Debug.FEATURE.PERSISTENCE)
        return data, false
    end

    -- Check if data is from a newer version
    if dataVersion > currentVersion then
        Debug.error(
            "Cannot load " .. dataTypeName .. " from newer version (saved: " .. dataVersion ..
            ", current: " .. currentVersion .. "). Please update Ensembler.",
            Debug.FEATURE.PERSISTENCE
        )
        return nil, false
    end

    -- Data is from older version - run migrations
    Debug.log("Migrating " .. dataTypeName .. " from v" .. dataVersion .. " to v" .. currentVersion, Debug.FEATURE.PERSISTENCE)

    local upgradedData = data
    local migrationsRun = 0

    -- Run each migration in sequence from dataVersion+1 to currentVersion
    for version = dataVersion + 1, currentVersion do
        local migrationFunc = migrations[version]

        if migrationFunc then
            Debug.log("  Running migration to v" .. version, Debug.FEATURE.PERSISTENCE)
            upgradedData = migrationFunc(upgradedData)

            -- Update version number after each migration step
            upgradedData.version = version

            migrationsRun = migrationsRun + 1
        end
    end

    -- Always update version to current
    upgradedData.version = currentVersion

    if migrationsRun > 0 then
        Debug.log("Successfully migrated " .. dataTypeName .. " (" .. migrationsRun .. " migrations applied)", Debug.FEATURE.PERSISTENCE)
    else
        Debug.log("No migrations needed between v" .. dataVersion .. " and v" .. currentVersion .. ", updating version number only", Debug.FEATURE.PERSISTENCE)
    end

    -- Always return true for didUpgrade since we at minimum updated the version number
    return upgradedData, true
end

return UpgradePathManager
