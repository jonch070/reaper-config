-- @description Batch Create Cues from Regions
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Batch-creates cue subprojects from regions in a video project.
--   Uses direct RPP file modification for speed (no project tab opening).
--   Automatically inserts subprojects into the video project.
--
--   Features:
--   - Creates cue folders and RPP files from a template
--   - Sets timecode offset so MX IN lands at configured bar
--   - Creates MX IN/OUT marker items
--   - Optionally reads descriptions from SpotNotes CSV
--   - Inserts subprojects into video project at correct positions

-- ============================================================================
-- DEPENDENCIES
-- ============================================================================

-- Enable for debugging in VSCode
--local VSDEBUG = dofile("/Users/nate/.vscode/extensions/antoinebalaine.reascript-docs-0.1.16/debugger/LoadDebug.lua")

-- Bootstrap NW environment
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
local sharedPath = scriptPath:match("^(.+)[/\\][^/\\]+$") .. "/Shared/"
package.path = package.path .. ";" .. sharedPath .. "?.lua"

require("NWInit")({
    debug = true,
    requires = { "SWS", "ReaImGui" },
    libs = { "TimeUtils", "ReaperUtils", "ReaperTracksAndFolders", "FileUtils", "SpottingNotesParser" },
})
if not NW then return end

-- Load local utils
local utilsPath = NW.scriptDir .. "utils/"
package.path = package.path .. ";" .. utilsPath .. "?.lua"

local UI = require("UI")
local CueCreator = require("CueCreator")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local videoProj = nil
local videoProjectPath = nil

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
    -- Get current project
    videoProj, videoProjectPath = reaper.EnumProjects(-1)
    if not videoProjectPath or videoProjectPath == "" then
        reaper.ShowMessageBox("Please save your project before using this script.", "Error", 0)
        return
    end

    NW.log("Starting Batch Create Cues")
    NW.log("Video project: " .. videoProjectPath)

    -- Start the UI
    UI.run(videoProj, videoProjectPath, {
        getRegions = function()
            return NW.ReaperUtils.getAllRegions(videoProj)
        end,

        classifyRegions = function(regions, cuesTrackName, altCuesTrackName, filenameSuffix)
            return CueCreator.classifyRegions(videoProj, regions, cuesTrackName, altCuesTrackName, filenameSuffix)
        end,

        onSubmit = function(settings, regionsToProcess)
            reaper.Undo_BeginBlock()

            NW.log(string.format("Processing %d selected regions", #regionsToProcess))

            -- Defer so UI can show progress view before heavy work begins
            reaper.defer(function()
                -- Initialize async processing (parses CSV if provided)
                local state = CueCreator.initProcessing(
                    videoProj,
                    videoProjectPath,
                    regionsToProcess,
                    settings,
                    -- Progress callback (called AFTER each cue is processed)
                    function(current, total, cueId, result)
                        UI.setProgress(current, total)
                        -- Add to progress log (show filename with suffix)
                        local displayName = cueId .. (settings.filenameSuffix or "")
                        UI.addLogEntry(displayName, result.success, result.error, result.isRecreation)
                        -- Track created cues for potential cleanup
                        if result.success and result.projectPath then
                            UI.addCreatedFile(result.projectPath, result.mediaItem, result.mediaTrack)
                        end
                        -- Update to show next cue (if any remaining)
                        if current < total then
                            UI.setCurrentCue(regionsToProcess[current + 1].name)
                        end
                    end,
                    -- Completion callback
                    function(_, _, failCount)
                        UI.processingComplete()

                        if failCount == 0 then
                            reaper.Undo_EndBlock("Batch Create Cues", -1)
                        else
                            reaper.Undo_EndBlock("Batch Create Cues (partial)", -1)
                        end
                        -- Results are shown in the progress log - no modal needed
                    end
                )

                -- Process cues one at a time using defer
                local function processLoop()
                    -- Check for cancellation
                    if UI.isCancelRequested() then
                        -- User cancelled - prompt for cleanup
                        local createdCues = UI.getCreatedFiles()
                        if #createdCues > 0 then
                            local response = reaper.ShowMessageBox(
                                string.format("Cancel batch creation?\n\n%d cue(s) were already created. Delete them?",
                                    #createdCues),
                                "Cancel Batch Create",
                                4  -- Yes/No
                            )
                            if response == 6 then  -- Yes
                                for _, cue in ipairs(createdCues) do
                                    -- Remove subproject item from video project
                                    if cue.mediaItem and cue.mediaTrack then
                                        reaper.DeleteTrackMediaItem(cue.mediaTrack, cue.mediaItem)
                                    end
                                    -- Delete the RPP file
                                    os.remove(cue.filePath)
                                    -- Try to remove empty parent folder
                                    local folderPath = cue.filePath:match("^(.+)[/\\][^/\\]+$")
                                    if folderPath then
                                        os.remove(folderPath)
                                    end
                                end
                                reaper.UpdateArrange()
                            end
                        end

                        reaper.Undo_EndBlock("Batch Create Cues (cancelled)", -1)
                        CueCreator.clearTemplateCache()
                        UI.processingComplete()
                        UI.addLogEntry("---", false, "Cancelled by user")
                        return  -- Stop processing
                    end

                    local done = CueCreator.processNext(state)
                    if not done then
                        reaper.defer(processLoop)
                    end
                end

                -- Load template in a defer so UI can show loading status
                UI.setStatus("Loading template...", 0, #regionsToProcess)

                reaper.defer(function()
                    local success, err = CueCreator.loadTemplate(settings.templatePath)
                    if not success then
                        UI.addLogEntry("---", false, "Failed to load template: " .. (err or "unknown"))
                        UI.processingComplete()
                        reaper.Undo_EndBlock("Batch Create Cues (failed)", -1)
                        return
                    end

                    -- Set initial cue name and start processing
                    if #regionsToProcess > 0 then
                        UI.setCurrentCue(regionsToProcess[1].name)
                    end

                    reaper.defer(processLoop)
                end)
            end)
        end
    })
end

main()
