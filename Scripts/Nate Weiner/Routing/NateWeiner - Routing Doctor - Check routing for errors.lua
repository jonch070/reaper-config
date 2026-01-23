-- @description Routing Doctor: Check routing for errors
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 2.1
-- @about
--   Analyzes all tracks in the project for routing problems:
--   - Orphaned tracks (not routed to target chain)
--   - Duplicate routing (routed to multiple chain entries)
--   - Skipped chain step (bypassing step 1 of chain)
--   - Master leaks (also routes to master in addition to chain)

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

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Logs a message to the console
--- @param msg string
local function log(msg)
    reaper.ShowConsoleMsg(msg .. "\n")
end

--- Creates a horizontal separator line
--- @param char string|nil Character to use (default "━")
--- @param width integer|nil Width (default 50)
--- @return string
local function separator(char, width)
    char = char or "━"
    width = width or 50
    return string.rep(char, width)
end

-- ============================================================================
-- OUTPUT FORMATTING
-- ============================================================================

--- Gets all sends for a track (both active and muted)
--- @param track MediaTrack
--- @return table Array of {name, trackNum, muted}
local function getAllSends(track)
    local sends = {}
    local numSends = reaper.GetTrackNumSends(track, 0)

    for i = 0, numSends - 1 do
        local destTrack = reaper.BR_GetMediaTrackSendInfo_Track(track, 0, i, 1)
        local isMuted = reaper.GetTrackSendInfo_Value(track, 0, i, "B_MUTE") == 1
        if destTrack and reaper.ValidatePtr(destTrack, "MediaTrack*") then
            local destName = RoutingAnalysis.getTrackName(destTrack)
            local destNum = RoutingAnalysis.getTrackNumber(destTrack)
            table.insert(sends, {
                name = destName,
                trackNum = destNum,
                muted = isMuted
            })
        end
    end

    return sends
end

--- Formats a send for display
--- @param send table {name, trackNum, muted}
--- @return string
local function formatSend(send)
    local status = send.muted and " [MUTED]" or ""
    return string.format("%d:%s%s", send.trackNum, send.name, status)
end

--- Gets the direct and parallel chain entries from routing results
--- @param results table RoutingResults
--- @return table directEntries Array of chain entry names (step 1, direct path)
--- @return table parallelEntries Array of chain entry names reached only via parallel path
local function getChainEntryInfo(results)
    local directEntries = {}
    local parallelEntries = {}

    if results then
        -- Get step 1 direct entries
        local step1Direct = results.directChainEntries and results.directChainEntries[1]
        if step1Direct then
            for name, _ in pairs(step1Direct) do
                table.insert(directEntries, name)
            end
        end
        table.sort(directEntries)

        -- Get step 1 parallel entries (that aren't also direct)
        local step1Parallel = results.parallelChainEntries and results.parallelChainEntries[1]
        if step1Parallel then
            for name, _ in pairs(step1Parallel) do
                if not (step1Direct and step1Direct[name]) then
                    table.insert(parallelEntries, name)
                end
            end
        end
        table.sort(parallelEntries)
    end

    return directEntries, parallelEntries
end

--- Outputs a problem section with root cause grouping
--- @param title string Section title
--- @param tracks table Array of TrackAnalysis
--- @param problemType string The problem type for grouping logic
local function outputProblemSection(title, tracks, problemType)
    if #tracks == 0 then return end

    -- Group by root cause
    local groups = RoutingAnalysis.groupByRootCause(tracks, problemType)

    -- Count unique root causes for the header
    log(title .. ": " .. #groups .. " root cause(s), " .. #tracks .. " affected track(s)")
    log("")

    for _, group in ipairs(groups) do
        local rootAnalysis = group.rootCauseAnalysis
        local affectedCount = #group.affected

        if rootAnalysis then
            local track = rootAnalysis.track

            -- Header with track number and name
            log(string.format('   • Track %d: "%s"', rootAnalysis.trackNumber, rootAnalysis.trackName))

            -- Show parent routing status
            local parentTrack, sendsToParent = RoutingAnalysis.getParentRouting(track)
            if parentTrack then
                local parentNum = RoutingAnalysis.getTrackNumber(parentTrack)
                local parentName = RoutingAnalysis.getTrackName(parentTrack)
                local parentStatus = sendsToParent and "ON" or "OFF"
                log(string.format("     Parent: %d:%s [%s]", parentNum, parentName, parentStatus))
            else
                local parentStatus = sendsToParent and "ON → Master" or "OFF"
                log(string.format("     Parent: (top level) [%s]", parentStatus))
            end

            -- Show sends (including muted ones)
            local sends = getAllSends(track)
            if #sends > 0 then
                log("     Sends:")
                for _, send in ipairs(sends) do
                    log("       → " .. formatSend(send))
                end
            end

            -- Show chain entry routing summary
            local directEntries, parallelEntries = getChainEntryInfo(rootAnalysis.results)
            if #directEntries > 0 then
                log("     Direct chain entries: " .. table.concat(directEntries, ", "))
            end
            if #parallelEntries > 0 then
                log("     Via parallel only: " .. table.concat(parallelEntries, ", "))
            end

            -- Explain why it's a problem
            if problemType == "orphaned" then
                -- Find where routing terminates
                local deadEndTrackName = RoutingAnalysis.findDeadEndTrack(rootAnalysis.results)

                if #parallelEntries > 0 and #directEntries == 0 then
                    log("     ⚠ Only parallel path exists - direct signal has no route to chain")
                elseif deadEndTrackName and deadEndTrackName ~= rootAnalysis.trackName then
                    log("     ⚠ Routing ends at: " .. deadEndTrackName)
                elseif #sends == 0 and not sendsToParent then
                    log("     ⚠ No routing configured (no sends, parent send OFF)")
                elseif #sends > 0 then
                    local allMuted = true
                    for _, send in ipairs(sends) do
                        if not send.muted then allMuted = false break end
                    end
                    if allMuted and not sendsToParent then
                        log("     ⚠ All sends muted, parent send OFF")
                    end
                end
            elseif problemType == "duplicate" then
                log("     ⚠ Routes to multiple chain entries - should only go to one")
            elseif problemType == "skipped_chain_step" then
                local skippedTo = rootAnalysis.skippedToStep or "?"
                log(string.format("     ⚠ Bypassed step 1, went directly to step %s", skippedTo))
            end

            -- Show affected children count
            if affectedCount > 0 then
                log(string.format("     ↳ + %d child track(s) affected", affectedCount))
            end
        else
            -- Root cause track wasn't in problem list (edge case)
            log(string.format('   • Root cause: "%s"', group.rootCauseName))
            log(string.format("     ↳ %d track(s) affected", affectedCount))
        end

        log("")
    end
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function checkRouting()
    reaper.ClearConsole()
    log("=== Routing Doctor ===\n")

    local proj = reaper.EnumProjects(-1)
    local totalTracks = reaper.CountTracks(proj)

    log(string.format("Scanning %d tracks...\n", totalTracks))

    -- Run analysis with loaded config
    local analysis = RoutingAnalysis.analyzeProject(proj, routingConfig)

    -- Show config info
    local chainSteps = routingConfig.targetChain and #routingConfig.targetChain or 0
    log(string.format("Config: %d chain step(s) defined", chainSteps))
    log("")
    log(separator())
    log("")

    -- Check if there are any problems
    local hasProblems = analysis.problemCount > 0

    if hasProblems then
        log(string.format("PROBLEMS FOUND: %d\n", analysis.problemCount))

        outputProblemSection("❌ ORPHANED (not routed to chain)", analysis.problems.orphaned, "orphaned")
        outputProblemSection("❌ DUPLICATE (routed to multiple chain entries)", analysis.problems.duplicate, "duplicate")
        outputProblemSection("❌ SKIPPED CHAIN STEP (bypassed step 1)", analysis.problems.skipped_chain_step, "skipped_chain_step")
        outputProblemSection("⚠️  MASTER LEAK (also routes to Master)", analysis.problems.master_leak, "master_leak")
    else
        log("✅ ALL CLEAR — No routing problems found!\n")
    end

    -- Summary
    log(separator())
    log("")
    log("SUMMARY")
    log(string.format("  Source tracks analyzed: %d", analysis.analyzedCount))
    log(string.format("  ✓ Correctly routed: %d", analysis.cleanCount))
    log(string.format("  ⏭ Skipped: %d (chain/parallel/ignored/utility)", analysis.skippedCount))
    if hasProblems then
        log(string.format("  ❌ Problems: %d", analysis.problemCount))
    end
    log("")
    log(separator())
end

-- Run
checkRouting()
