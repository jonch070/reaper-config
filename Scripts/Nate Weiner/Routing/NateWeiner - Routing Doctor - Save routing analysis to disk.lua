-- @description Routing Doctor: Save routing analysis to disk
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 3.1
-- @about
--   Analyzes routing for every track in the project and outputs
--   the results to a log file for debugging routing issues.

-- ============================================================================
-- SETUP
-- ============================================================================

-- Bootstrap NW environment
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
local sharedPath = scriptPath:match("^(.+)[/\\][^/\\]+$") .. "/Shared/"
package.path = package.path .. ";" .. sharedPath .. "?.lua"

require("NWInit")({
    debug = false,
    requires = { "SWS" },
    libs = { "ReaperTracksAndFolders" },
})
if not NW then return end

-- Load package-local utils
package.path = package.path .. ";" .. NW.scriptDir .. "/utils/?.lua"

local RoutingAnalysis = require("RoutingAnalysis")
local RoutingConfigLoader = require("RoutingConfigLoader")

-- Load routing configuration
local routingConfig, configError = RoutingConfigLoader.load()
if not routingConfig then
    RoutingConfigLoader.showError(configError or "Unknown error loading config")
    return
end

-- Analysis output folder (relative to package folder)
local ANALYSIS_FOLDER = NW.scriptDir .. "/analysis/"

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Opens a file for writing
--- @param path string
--- @return file*|nil
local function openLogFile(path)
    local file = io.open(path, "w")
    if not file then
        reaper.ShowConsoleMsg("ERROR: Could not open log file: " .. path .. "\n")
        return nil
    end
    return file
end

--- Writes a line to the log file
--- @param file file*
--- @param line string
local function writeLine(file, line)
    file:write(line .. "\n")
end

-- ============================================================================
-- CONFIGURATION SUMMARY
-- ============================================================================

--- Formats a tracks() config item for display, showing folder context
--- @param proj ReaProject
--- @param tracksItem table A tracks() result from config
--- @return string formatted display string
local function formatTracksItem(proj, tracksItem)
    if not tracksItem or tracksItem.type ~= "tracks" then
        return "(invalid)"
    end

    local parts = {}

    for _, item in ipairs(tracksItem.items or {}) do
        if item.type == "folder" then
            -- Folder reference - show as "FolderName: child1, child2, ..."
            local folderTrack = RoutingAnalysis.findFolderTrack(proj, item.name)
            if folderTrack then
                local children = RoutingAnalysis.getFolderChildren(proj, folderTrack)
                local childNames = {}
                for _, child in ipairs(children) do
                    local childName = RoutingAnalysis.getTrackName(child)
                    local include = true

                    if item.matchPattern and not childName:match(item.matchPattern) then
                        include = false
                    end
                    if include and item.excludePattern and childName:match(item.excludePattern) then
                        include = false
                    end

                    if include then
                        table.insert(childNames, childName)
                    end
                end

                if #childNames > 0 then
                    table.insert(parts, item.name .. ": " .. table.concat(childNames, ", "))
                else
                    table.insert(parts, item.name .. ": (no matches)")
                end
            else
                table.insert(parts, item.name .. ": (folder not found)")
            end

        elseif item.type == "name" then
            table.insert(parts, item.name)

        elseif item.type == "master" then
            table.insert(parts, "Master")
        end
    end

    return #parts > 0 and table.concat(parts, "; ") or "(empty)"
end

--- Builds a human-readable summary of the routing config
--- @param proj ReaProject
--- @param config table The routing config
--- @return string summary
local function buildConfigSummary(proj, config)
    local lines = {}

    table.insert(lines, "ROUTING CONFIGURATION:")

    -- Target chain
    if config.targetChain and #config.targetChain > 0 then
        table.insert(lines, "  Target Chain (" .. #config.targetChain .. " steps):")
        for step, tracksItem in ipairs(config.targetChain) do
            table.insert(lines, string.format("    Step %d: %s", step, formatTracksItem(proj, tracksItem)))
        end
    end

    -- Parallel paths
    if config.parallelPaths and #config.parallelPaths > 0 then
        table.insert(lines, "  Parallel Paths:")
        for _, tracksItem in ipairs(config.parallelPaths) do
            table.insert(lines, "    - " .. formatTracksItem(proj, tracksItem))
        end
    end

    -- Ignore list
    if config.ignore and #config.ignore > 0 then
        table.insert(lines, "  Ignored:")
        for _, tracksItem in ipairs(config.ignore) do
            table.insert(lines, "    - " .. formatTracksItem(proj, tracksItem))
        end
    end

    return table.concat(lines, "\n")
end

-- ============================================================================
-- TRACK NUMBER LOOKUP
-- ============================================================================

-- Cache for track name -> track number mapping (built once per run)
local trackNumberCache = {}

--- Builds the track number cache for the project
--- @param proj ReaProject
local function buildTrackNumberCache(proj)
    trackNumberCache = {}
    local trackCount = reaper.CountTracks(proj)
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(proj, i)
        local name = RoutingAnalysis.getTrackName(track)
        local num = RoutingAnalysis.getTrackNumber(track)
        -- Store track number by name (if duplicate names, last one wins - but we also store by pointer)
        trackNumberCache[name] = num
        trackNumberCache[tostring(track)] = num
    end
end

--- Gets track number from cache by name
--- @param name string
--- @return integer|nil
local function getTrackNumberByName(name)
    return trackNumberCache[name]
end

--- Formats a path with track numbers
--- @param pathInfo table Path info from routing results
--- @return string formatted path
local function formatPathWithNumbers(pathInfo)
    local pathParts = {}
    for idx, name in ipairs(pathInfo.path) do
        if idx > 1 then  -- Skip self (first element)
            local num = getTrackNumberByName(name)
            if num then
                table.insert(pathParts, string.format("%d:%s", num, name))
            else
                table.insert(pathParts, name)
            end
        end
    end

    local label = ""
    if pathInfo.type == "chain" then
        local stepLabel = pathInfo.chainStep and string.format(" (step %d)", pathInfo.chainStep) or ""
        label = pathInfo.viaParallel and stepLabel .. " [via parallel]" or stepLabel .. " [direct]"
    elseif pathInfo.type == "master" then
        label = " [-> Master]"
    elseif pathInfo.type == "dead_end" then
        label = " [dead end]"
    end

    local pathStr = #pathParts > 0 and table.concat(pathParts, " -> ") or "(direct)"
    return "-> " .. pathStr .. label
end

-- ============================================================================
-- MAIN ANALYSIS
-- ============================================================================

--- Gets the project name without extension
--- @param projPath string Full path to the project file
--- @return string projectName The project filename without extension
local function getProjectName(projPath)
    local filename = projPath:match("([^/\\]+)%.RPP$") or projPath:match("([^/\\]+)%.rpp$")
    return filename or "unknown"
end

--- Builds the log file path with project name and datetime
--- @return string logFilePath Full path to the log file
local function buildLogFilePath()
    local _, projPath = reaper.EnumProjects(-1)
    local projectName = getProjectName(projPath or "")
    local datetime = os.date("%Y-%m-%d_%H-%M-%S")
    return ANALYSIS_FOLDER .. "routingAnalysis-" .. projectName .. "-" .. datetime .. ".txt"
end

--- Ensures the analysis folder exists
local function ensureAnalysisFolderExists()
    reaper.RecursiveCreateDirectory(ANALYSIS_FOLDER, 0)
end

local function logAllTrackRouting()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("=== Logging All Track Routing ===\n")

    local proj = reaper.EnumProjects(-1)
    local trackCount = reaper.CountTracks(proj)

    if trackCount == 0 then
        reaper.ShowConsoleMsg("ERROR: No tracks in project.\n")
        return
    end

    -- Build track number cache
    buildTrackNumberCache(proj)

    -- Ensure output folder exists and build log file path
    ensureAnalysisFolderExists()
    local logFilePath = buildLogFilePath()

    -- Open log file
    local logFile = openLogFile(logFilePath)
    if not logFile then return end

    -- Write header
    writeLine(logFile, "===============================================================================")
    writeLine(logFile, "TEMPLATE ROUTING ANALYSIS")
    writeLine(logFile, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    writeLine(logFile, "Total Tracks: " .. trackCount)
    writeLine(logFile, "===============================================================================")
    writeLine(logFile, "")

    -- Write config summary
    writeLine(logFile, buildConfigSummary(proj, routingConfig))
    writeLine(logFile, "")
    writeLine(logFile, string.rep("=", 79))
    writeLine(logFile, "")

    -- Analyze each track
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(proj, i)
        local analysis = RoutingAnalysis.analyzeTrack(proj, track, routingConfig)

        -- Header for this track
        local folderIndicator = analysis.isFolder and " [FOLDER]" or ""
        writeLine(logFile, string.format("%d:%s%s", analysis.trackNumber, analysis.trackName, folderIndicator))
        writeLine(logFile, "  Category: " .. analysis.categorization.category)

        -- Handle skipped tracks
        if analysis.skipReason then
            writeLine(logFile, "  (Skipped - " .. analysis.skipReason .. ")")
            writeLine(logFile, "")
            goto continue
        end

        -- Get direct routing info (sends and parent)
        local sends = RoutingAnalysis.getTrackSends(track)
        local parentTrack, sendsToParent = RoutingAnalysis.getParentRouting(track)

        -- Show parent send status
        if parentTrack then
            local parentNum = RoutingAnalysis.getTrackNumber(parentTrack)
            local parentName = RoutingAnalysis.getTrackName(parentTrack)
            local parentStatus = sendsToParent and "ON" or "OFF"
            writeLine(logFile, string.format("  Parent: %d:%s [%s]", parentNum, parentName, parentStatus))
        else
            local parentStatus = sendsToParent and "ON -> Master" or "OFF"
            writeLine(logFile, string.format("  Parent: (none - top level) [%s]", parentStatus))
        end

        -- Show sends (including muted ones for diagnostic purposes)
        if #sends > 0 then
            local sendStrs = {}
            for _, send in ipairs(sends) do
                local destNum = RoutingAnalysis.getTrackNumber(send.track)
                local status = send.muted and " [MUTED]" or ""
                table.insert(sendStrs, string.format("%d:%s%s", destNum, send.name, status))
            end
            writeLine(logFile, "  Sends: " .. table.concat(sendStrs, ", "))
        end

        -- Show routing paths from analysis results
        if analysis.results and #analysis.results.paths > 0 then
            writeLine(logFile, "  Routing Paths:")
            for _, pathInfo in ipairs(analysis.results.paths) do
                writeLine(logFile, "    " .. formatPathWithNumbers(pathInfo))
            end
        else
            writeLine(logFile, "  Routing Paths: (none)")
        end

        -- Summary of chain entries
        if analysis.directChainEntryCount > 0 then
            writeLine(logFile, "  Chain Entries (step 1): " .. table.concat(analysis.directChainEntryList, ", "))
        end

        -- Show parallel paths encountered
        if analysis.results and next(analysis.results.parallelPaths) then
            local parallelNames = {}
            for name, _ in pairs(analysis.results.parallelPaths) do
                table.insert(parallelNames, name)
            end
            table.sort(parallelNames)
            writeLine(logFile, "  Via Parallel: " .. table.concat(parallelNames, ", "))
        end

        -- Warnings
        if analysis.results and analysis.results.goesToMaster then
            writeLine(logFile, "  ! Goes to Master")
        end

        -- Verdict based on problems
        if #analysis.problems == 0 then
            writeLine(logFile, "  ✓ OK")
        else
            for _, problem in ipairs(analysis.problems) do
                if problem == "orphaned" then
                    local deadEndTrackName = RoutingAnalysis.findDeadEndTrack(analysis.results)
                    if deadEndTrackName then
                        local deadEndTrackNum = getTrackNumberByName(deadEndTrackName)
                        local deadEndDisplay = deadEndTrackNum
                            and string.format("%d:%s", deadEndTrackNum, deadEndTrackName)
                            or deadEndTrackName
                        writeLine(logFile, "  ❌ ORPHANED -> ends at " .. deadEndDisplay)
                    else
                        writeLine(logFile, "  ❌ ORPHANED (dead end)")
                    end
                elseif problem == "duplicate" then
                    writeLine(logFile, "  ❌ DUPLICATE (" .. analysis.directChainEntryCount .. " chain entries)")
                elseif problem == "skipped_chain_step" then
                    writeLine(logFile, "  ❌ SKIPPED CHAIN STEP (went directly to step " .. (analysis.skippedToStep or "?") .. ")")
                elseif problem == "master_leak" then
                    writeLine(logFile, "  ❌ MASTER LEAK (routes to both chain and master)")
                end
            end
        end

        writeLine(logFile, "")

        ::continue::
    end

    -- Close file
    logFile:close()

    reaper.ShowConsoleMsg("Log written to: " .. logFilePath .. "\n")
    reaper.ShowConsoleMsg("Total tracks analyzed: " .. trackCount .. "\n")
end

-- Run
logAllTrackRouting()
