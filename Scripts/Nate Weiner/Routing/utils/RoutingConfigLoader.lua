-- @description Routing config loader
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 2.0
-- @about
--   Loads user's RoutingConfig.lua, with helpful error if not found.
--   Automatically finds the package root directory.

local RoutingConfigLoader = {}

--- Gets the package root directory by navigating up from utils/
--- @return string packageRoot The package root directory
local function getPackageRoot()
    local info = debug.getinfo(1, "S")
    local scriptPath = info.source:match("^@(.+)$")
    -- Navigate up from utils/ to package root
    local packageRoot = scriptPath:match("^(.+)/utils/[^/]+$")
    return packageRoot or scriptPath:match("^(.+)/[^/]+$")
end

--- Loads the routing configuration
--- @return table|nil config The loaded config, or nil if not found
--- @return string|nil error Error message if config not found
function RoutingConfigLoader.load()
    local packageRoot = getPackageRoot()
    local configPath = packageRoot .. "/RoutingConfig.lua"
    local templatePath = packageRoot .. "/RoutingConfig.template.lua"

    -- Try to load user config
    local configFile = io.open(configPath, "r")
    if configFile then
        configFile:close()

        -- Add to package path if needed
        local oldPath = package.path
        package.path = package.path .. ";" .. packageRoot .. "/?.lua"

        local success, config = pcall(require, "RoutingConfig")

        package.path = oldPath

        if success and config then
            return config, nil
        else
            return nil, "Error loading RoutingConfig.lua: " .. tostring(config)
        end
    end

    -- Config not found - return helpful error
    local errorMsg = [[
RoutingConfig.lua not found.

To set up routing analysis for your template:
1. Find "RoutingConfig.template.lua" in the Routing Doctor folder
2. Copy it to "RoutingConfig.lua" (same folder)
3. Edit the config to match your template's routing structure

Template location: ]] .. templatePath

    return nil, errorMsg
end

--- Shows an error dialog when config is missing
--- @param errorMsg string The error message to display
function RoutingConfigLoader.showError(errorMsg)
    reaper.ShowMessageBox(
        errorMsg,
        "Routing Analysis - Setup Required",
        0  -- OK button only
    )
end

return RoutingConfigLoader
