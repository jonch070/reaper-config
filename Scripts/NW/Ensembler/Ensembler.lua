--local VSDEBUG = dofile("/Users/nate/.vscode/extensions/antoinebalaine.reascript-docs-0.1.15/debugger/LoadDebug.lua")
-- Ensembler - Main Entry Point

-- Get script path for loading modules
local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]

-- Set up module path for components
package.path = script_path .. "?.lua;" .. package.path

-- Load Debug module first and make it global before anything else
Debug = dofile(script_path .. "utils/Debug.lua")

-- Load core modules first
dofile(script_path .. "modules/RetroactiveRecord.lua")  -- Must load before Ensemble (which is required by State/EnsemblePersistence)
dofile(script_path .. "modules/AppController.lua")
dofile(script_path .. "modules/State.lua")
dofile(script_path .. "modules/ReaperTracks.lua")
dofile(script_path .. "modules/EnsemblePersistence.lua")
dofile(script_path .. "modules/INFX.lua")
dofile(script_path .. "modules/QuickBuilder.lua")
dofile(script_path .. "utils/Utils.lua") -- TODO is this still being used or can be integrated?

-- Load UI modules
dofile(script_path .. "components/Views/Main/MainWindow.lua")
dofile(script_path .. "components/DragDrop/Draggable.lua")

-- Check dependencies
if not reaper.ImGui_CreateContext then
    reaper.MB("Missing dependency: ReaImGui extension.\nDownload it via ReaPack ReaTeam extension repository.", "Ensembler Error", 0)
    return false
end

-- Initialize and start application
if AppController then
    local success = AppController.init()
    if success then
        AppController.start()
    else
        reaper.MB("Failed to initialize Ensembler", "Ensembler Error", 0)
    end
else
    reaper.MB("Failed to load AppController module", "Ensembler Error", 0)
end