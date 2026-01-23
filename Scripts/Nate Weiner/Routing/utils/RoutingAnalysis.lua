-- @description Routing analysis utilities for stem routing validation
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Core routing analysis logic for validating track routing to stems.
--   Used by both the test script (single track) and Check Routing (full project).

local RoutingAnalysis = {}

-- ============================================================================
-- DEFAULT CONFIG
-- ============================================================================

--- @class RoutingAnalysisConfig
--- @field targetChain table[] Array of tracks() items defining the signal chain
--- @field parallelPaths table[] Array of tracks() items for parallel routes (reverbs, FX)
--- @field ignore table[] Array of tracks() items to skip during analysis
--- @field ignoreEmptyTopLevelTracks boolean Whether to skip empty top-level tracks

--- Default config used when no user config is provided
--- In practice, users should always provide a RoutingConfig.lua
local DEFAULT_CONFIG = {
    targetChain = {},
    parallelPaths = {},
    ignore = {},
    ignoreEmptyTopLevelTracks = true,
}

-- ============================================================================
-- CONFIGURATION RESOLVER 
-- ============================================================================

--- Resolves a tracks() config item to actual track MediaTracks or names
--- @param proj ReaProject
--- @param tracksItem table A tracks() result from config
--- @return table Array of {track: MediaTrack, name: string} or {name: string} for pattern matches
function RoutingAnalysis.resolveTracks(proj, tracksItem)
    if not tracksItem or tracksItem.type ~= "tracks" then
        return {}
    end

    local resolved = {}
    local trackCount = reaper.CountTracks(proj)

    for _, item in ipairs(tracksItem.items or {}) do
        if item.type == "name" then
            -- Find track by exact name
            for i = 0, trackCount - 1 do
                local track = reaper.GetTrack(proj, i)
                local name = RoutingAnalysis.getTrackName(track)
                if name == item.name then
                    table.insert(resolved, { track = track, name = name })
                    break
                end
            end

        elseif item.type == "folder" then
            -- Find folder and get its children
            local folderTrack = RoutingAnalysis.findFolderTrack(proj, item.name)
            if folderTrack then
                local children = RoutingAnalysis.getFolderChildren(proj, folderTrack)
                for _, child in ipairs(children) do
                    local childName = RoutingAnalysis.getTrackName(child)
                    local include = true

                    -- Apply matchPattern filter
                    if item.matchPattern and not childName:match(item.matchPattern) then
                        include = false
                    end

                    -- Apply excludePattern filter
                    if include and item.excludePattern and childName:match(item.excludePattern) then
                        include = false
                    end

                    if include then
                        table.insert(resolved, { track = child, name = childName })
                    end
                end
            end

        elseif item.type == "master" then
            local masterTrack = reaper.GetMasterTrack(proj)
            if masterTrack then
                table.insert(resolved, { track = masterTrack, name = "Master" })
            end
        end
    end

    return resolved
end

--- Gets direct children of a folder track
--- @param proj ReaProject
--- @param folderTrack MediaTrack
--- @return table Array of MediaTrack
function RoutingAnalysis.getFolderChildren(proj, folderTrack)
    local children = {}
    local trackCount = reaper.CountTracks(proj)
    local folderIdx = math.floor(reaper.GetMediaTrackInfo_Value(folderTrack, "IP_TRACKNUMBER")) - 1
    local folderDepth = reaper.GetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH")

    if folderDepth < 1 then
        return children  -- Not a folder
    end

    local currentDepth = folderDepth
    for i = folderIdx + 1, trackCount - 1 do
        local track = reaper.GetTrack(proj, i)
        local trackDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        -- Check if this is a direct child
        local parent = reaper.GetParentTrack(track)
        if parent == folderTrack then
            table.insert(children, track)
        end

        -- Track depth to know when we've exited the folder
        currentDepth = currentDepth + trackDepth
        if currentDepth <= 0 then
            break
        end
    end

    return children
end

--- Checks if a track matches any item in a tracks() config
--- @param proj ReaProject
--- @param track MediaTrack
--- @param tracksItem table A tracks() result from config
--- @return boolean matches
function RoutingAnalysis.trackMatchesConfig(proj, track, tracksItem)
    if not tracksItem or tracksItem.type ~= "tracks" then
        return false
    end

    local trackName = RoutingAnalysis.getTrackName(track)

    for _, item in ipairs(tracksItem.items or {}) do
        if item.type == "name" then
            if trackName == item.name then
                return true
            end

        elseif item.type == "folder" then
            local folderTrack = RoutingAnalysis.findFolderTrack(proj, item.name)
            if folderTrack then
                -- Check if track is the folder itself
                if track == folderTrack then
                    return true
                end
                -- Check if track is inside this folder
                if RoutingAnalysis.isTrackInFolder(proj, track, folderTrack) then
                    -- Apply pattern filters
                    local include = true
                    if item.matchPattern and not trackName:match(item.matchPattern) then
                        include = false
                    end
                    if include and item.excludePattern and trackName:match(item.excludePattern) then
                        include = false
                    end
                    if include then
                        return true
                    end
                end
            end

        elseif item.type == "master" then
            local masterTrack = reaper.GetMasterTrack(proj)
            if track == masterTrack then
                return true
            end
        end
    end

    return false
end

--- Checks if a track matches any tracks() in an array (like ignore or parallelPaths)
--- @param proj ReaProject
--- @param track MediaTrack
--- @param tracksArray table Array of tracks() results
--- @return boolean matches
function RoutingAnalysis.trackMatchesAnyConfig(proj, track, tracksArray)
    if not tracksArray then
        return false
    end
    for _, tracksItem in ipairs(tracksArray) do
        if RoutingAnalysis.trackMatchesConfig(proj, track, tracksItem) then
            return true
        end
    end
    return false
end

--- Gets the chain step index for a track (1-based), or nil if not in chain
--- @param proj ReaProject
--- @param track MediaTrack
--- @param config table The routing config with targetChain
--- @return integer|nil stepIndex
function RoutingAnalysis.getChainStepIndex(proj, track, config)
    if not config or not config.targetChain then
        return nil
    end
    for i, tracksItem in ipairs(config.targetChain) do
        if RoutingAnalysis.trackMatchesConfig(proj, track, tracksItem) then
            return i
        end
    end
    return nil
end

-- ============================================================================
-- UTILITY FUNCTIONS (delegated to shared library)
-- ============================================================================

RoutingAnalysis.getTrackName = NW.ReaperTracksAndFolders.getTrackName
RoutingAnalysis.getTrackNumber = NW.ReaperTracksAndFolders.getTrackNumber

-- ============================================================================
-- TRACK CONTENT ANALYSIS
-- ============================================================================

--- Checks if a media item has actual audio/MIDI content (not just an empty item with notes)
--- @param item MediaItem
--- @return boolean hasContent True if item has actual media content
function RoutingAnalysis.itemHasContent(item)
    local takeCount = reaper.CountTakes(item)
    if takeCount == 0 then
        return false  -- Empty item (no takes = marker item)
    end

    -- Check if any take has actual source media
    for i = 0, takeCount - 1 do
        local take = reaper.GetTake(item, i)
        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            if source then
                local sourceType = reaper.GetMediaSourceType(source)
                -- Empty items have no source or a special empty source type
                if sourceType ~= "" and sourceType ~= "EMPTY" then
                    return true
                end
            end
        end
    end

    return false
end

--- Checks if a track has any actual content (audio/MIDI items, not just marker items)
--- @param track MediaTrack
--- @return boolean hasContent True if track has content
--- @return integer totalItems Total number of items on track
--- @return integer contentItems Number of items with actual content
function RoutingAnalysis.trackHasContent(track)
    local itemCount = reaper.CountTrackMediaItems(track)
    if itemCount == 0 then
        return false, 0, 0
    end

    local contentItems = 0
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        if RoutingAnalysis.itemHasContent(item) then
            contentItems = contentItems + 1
        end
    end

    return contentItems > 0, itemCount, contentItems
end

RoutingAnalysis.isTopLevelTrack = NW.ReaperTracksAndFolders.isTopLevel
RoutingAnalysis.isFolder = NW.ReaperTracksAndFolders.isFolder

--- Checks if a track is an "information track" (video, markers, notes - not a routing problem)
--- Criteria: top-level, not a folder, no receives, parent send OFF, no sends or only sends to ignored tracks
--- @param track MediaTrack
--- @param config RoutingAnalysisConfig|nil Optional config to check if sends go to ignored tracks
--- @return boolean isInformationTrack
function RoutingAnalysis.isInformationTrack(track, config)
    -- Must be top-level
    if not RoutingAnalysis.isTopLevelTrack(track) then
        return false
    end

    -- Must not be a folder
    if RoutingAnalysis.isFolder(track) then
        return false
    end

    -- Must have no receives
    local hasReceives = RoutingAnalysis.trackHasReceives(track)
    if hasReceives then
        return false
    end

    -- Must have parent send OFF
    local _, sendsToParent = RoutingAnalysis.getParentRouting(track)
    if sendsToParent then
        return false
    end

    -- Check sends: either no sends, or only sends to ignored tracks
    local sends = RoutingAnalysis.getTrackSends(track)
    local activeSends = {}
    for _, send in ipairs(sends) do
        if not send.muted then
            table.insert(activeSends, send)
        end
    end

    if #activeSends == 0 then
        return true  -- No sends = dead end information track
    end

    -- If we have config, check if all sends go to ignored tracks
    if config and config.ignore then
        local proj = reaper.EnumProjects(-1)  -- Current project
        for _, send in ipairs(activeSends) do
            if send.track then
                local destCategorization = RoutingAnalysis.categorizeTrack(proj, send.track, config)
                if destCategorization.category ~= "ignored" then
                    return false  -- Has a send to something that's not ignored
                end
            end
        end
        return true  -- All sends go to ignored tracks
    end

    -- Without config, any active sends disqualify this as an information track
    return false
end

--- Checks if a track is an "organizational folder" (grouping only, not a routing problem)
--- Criteria: folder + no receives + no content + no sends + parent send OFF
--- These folders exist purely for visual organization - their children route independently
--- @param track MediaTrack
--- @return boolean isOrganizationalFolder
function RoutingAnalysis.isOrganizationalFolder(track)
    -- Must be a folder
    if not RoutingAnalysis.isFolder(track) then
        return false
    end

    -- Must have no receives (no audio flowing into this folder)
    local hasReceives = RoutingAnalysis.trackHasReceives(track)
    if hasReceives then
        return false
    end

    -- Must have no content
    local hasContent = RoutingAnalysis.trackHasContent(track)
    if hasContent then
        return false
    end

    -- Must have no sends
    local sends = RoutingAnalysis.getTrackSends(track)
    local hasActiveSends = false
    for _, send in ipairs(sends) do
        if not send.muted then
            hasActiveSends = true
            break
        end
    end
    if hasActiveSends then
        return false
    end

    -- Must have parent send OFF
    local _, sendsToParent = RoutingAnalysis.getParentRouting(track)
    if sendsToParent then
        return false
    end

    return true
end

--- Checks if a track has any receives (other tracks sending to it OR children routing via parent send)
--- @param track MediaTrack
--- @return boolean hasReceives True if track has receives
--- @return integer receiveCount Number of receives (explicit sends only, not parent routing)
function RoutingAnalysis.trackHasReceives(track)
    -- Check explicit sends (via routing matrix)
    local numReceives = reaper.GetTrackNumSends(track, -1)  -- category -1 = receives
    if numReceives > 0 then
        return true, numReceives
    end

    -- Check if any direct children have parent send ON (routing through this folder)
    local trackIdx = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) - 1
    local trackCount = reaper.CountTracks(0)
    local folderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

    -- Only check children if this is a folder
    if folderDepth >= 1 then
        local currentDepth = folderDepth
        for i = trackIdx + 1, trackCount - 1 do
            local childTrack = reaper.GetTrack(0, i)
            local childDepth = reaper.GetMediaTrackInfo_Value(childTrack, "I_FOLDERDEPTH")

            -- Check if this is a direct child (depth decreased by exactly the folder depth we're tracking)
            local childParent = reaper.GetParentTrack(childTrack)
            if childParent == track then
                -- This is a direct child - check if it sends to parent
                local sendsToParent = reaper.GetMediaTrackInfo_Value(childTrack, "B_MAINSEND") == 1
                if sendsToParent then
                    return true, 0  -- Has implicit receive from child
                end
            end

            -- Track folder depth to know when we've exited this folder
            currentDepth = currentDepth + childDepth
            if currentDepth <= 0 then
                break  -- Exited the folder
            end
        end
    end

    return false, 0
end

-- ============================================================================
-- FOLDER DETECTION
-- ============================================================================

--- Finds a folder track by name
--- @param proj ReaProject
--- @param folderName string
--- @return MediaTrack|nil
function RoutingAnalysis.findFolderTrack(proj, folderName)
    local trackCount = reaper.CountTracks(proj)
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(proj, i)
        local name = RoutingAnalysis.getTrackName(track)
        if name == folderName then
            local folderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if folderDepth >= 1 then
                return track
            end
        end
    end
    return nil
end

RoutingAnalysis.isTrackInFolder = NW.ReaperTracksAndFolders.isTrackInFolder

-- ============================================================================
-- TRACK CATEGORIZATION
-- ============================================================================

--- @class TrackCategorization
--- @field category "chain"|"parallel"|"ignored"|"source" The category type
--- @field chainStep integer|nil If category is "chain", which step (1-indexed)

--- Categorizes a track based on the new config system
--- @param proj ReaProject
--- @param track MediaTrack
--- @param config RoutingAnalysisConfig
--- @return TrackCategorization categorization
function RoutingAnalysis.categorizeTrack(proj, track, config)
    config = config or DEFAULT_CONFIG

    -- Check if track is in targetChain (and which step)
    local chainStep = RoutingAnalysis.getChainStepIndex(proj, track, config)
    if chainStep then
        return { category = "chain", chainStep = chainStep }
    end

    -- Check if track is in parallelPaths
    if RoutingAnalysis.trackMatchesAnyConfig(proj, track, config.parallelPaths) then
        return { category = "parallel", chainStep = nil }
    end

    -- Check if track is in ignore list
    if RoutingAnalysis.trackMatchesAnyConfig(proj, track, config.ignore) then
        return { category = "ignored", chainStep = nil }
    end

    -- Everything else is a source track that needs routing analysis
    return { category = "source", chainStep = nil }
end

-- ============================================================================
-- ROUTING ANALYSIS
-- ============================================================================

--- Gets all direct sends from a track (excluding muted)
--- @param track MediaTrack
--- @return table Array of {track, name, muted}
function RoutingAnalysis.getTrackSends(track)
    local sends = {}
    local numSends = reaper.GetTrackNumSends(track, 0)  -- category 0 = sends

    for i = 0, numSends - 1 do
        -- P_DESTTRACK returns a reaper.userdata, need to use BR extension
        local destTrack = reaper.BR_GetMediaTrackSendInfo_Track(track, 0, i, 1)  -- 1 = destination track
        local isMuted = reaper.GetTrackSendInfo_Value(track, 0, i, "B_MUTE") == 1

        if destTrack and reaper.ValidatePtr(destTrack, "MediaTrack*") then
            table.insert(sends, {
                track = destTrack,
                name = RoutingAnalysis.getTrackName(destTrack),
                muted = isMuted
            })
        end
    end

    return sends
end

--- Gets the parent track (if B_MAINSEND is enabled)
--- @param track MediaTrack
--- @return MediaTrack|nil parentTrack
--- @return boolean sendsToParent
function RoutingAnalysis.getParentRouting(track)
    local sendsToParent = reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND") == 1
    local parentTrack = reaper.GetParentTrack(track)

    return parentTrack, sendsToParent
end

--- @class RoutingResults
--- @field chainEntries table<integer, table<string, boolean>> Chain steps reached, indexed by step number
--- @field directChainEntries table<integer, table<string, boolean>> Chain steps via direct (non-parallel) paths
--- @field parallelChainEntries table<integer, table<string, boolean>> Chain steps via parallel paths only
--- @field parallelPaths table<string, boolean> Parallel path tracks encountered
--- @field goesToMaster boolean Whether track routes to master
--- @field paths table Array of path info for display

--- Traces routing from a track to find where it enters the target chain
--- @param proj ReaProject
--- @param startTrack MediaTrack
--- @param config RoutingAnalysisConfig
--- @param ancestry table|nil Track pointers in current path (for cycle detection)
--- @param pathNames table|nil Track names in current path (for debugging)
--- @param depth number|nil Current recursion depth
--- @param isParallelPath boolean|nil Whether we're currently tracing through a parallel path
--- @return RoutingResults results
function RoutingAnalysis.traceRouting(proj, startTrack, config, ancestry, pathNames, depth, isParallelPath)
    config = config or DEFAULT_CONFIG
    depth = depth or 0
    isParallelPath = isParallelPath or false

    -- Defensive nil check
    local emptyResults = {
        chainEntries = {},
        directChainEntries = {},
        parallelChainEntries = {},
        parallelPaths = {},
        goesToMaster = false,
        paths = {}
    }

    if not startTrack or not reaper.ValidatePtr(startTrack, "MediaTrack*") then
        return emptyResults
    end

    ancestry = ancestry or {}
    pathNames = pathNames or {}

    local trackName = RoutingAnalysis.getTrackName(startTrack)
    local trackPtr = tostring(startTrack)

    -- Check if this track is already in our current path (cycle detection)
    if ancestry[trackPtr] then
        return emptyResults
    end

    -- Add this track to the ancestry for this path
    local newAncestry = {}
    for k, v in pairs(ancestry) do newAncestry[k] = v end
    newAncestry[trackPtr] = true

    -- Add to path names for debugging
    local newPathNames = {}
    for _, p in ipairs(pathNames) do table.insert(newPathNames, p) end
    table.insert(newPathNames, trackName)

    local results = {
        chainEntries = {},        -- All chain steps reached, by step index
        directChainEntries = {},  -- Chain steps via direct paths
        parallelChainEntries = {},-- Chain steps via parallel paths
        parallelPaths = {},       -- Parallel path tracks encountered
        goesToMaster = false,
        paths = {}
    }

    local categorization = RoutingAnalysis.categorizeTrack(proj, startTrack, config)

    -- If we've reached a chain step, record it
    if categorization.category == "chain" then
        local step = categorization.chainStep
        local entryName = trackName

        -- Initialize step tables if needed
        results.chainEntries[step] = results.chainEntries[step] or {}
        results.chainEntries[step][entryName] = true

        if isParallelPath then
            results.parallelChainEntries[step] = results.parallelChainEntries[step] or {}
            results.parallelChainEntries[step][entryName] = true
        else
            results.directChainEntries[step] = results.directChainEntries[step] or {}
            results.directChainEntries[step][entryName] = true
        end

        table.insert(results.paths, {
            type = "chain",
            chainStep = step,
            path = newPathNames,
            destination = entryName,
            viaParallel = isParallelPath
        })
        return results
    end

    -- If we've reached a parallel path, mark it and continue tracing
    local nowOnParallelPath = isParallelPath
    if categorization.category == "parallel" then
        results.parallelPaths[trackName] = true
        nowOnParallelPath = true
    end

    -- Helper to merge results from recursive calls
    local function mergeResults(childResults)
        for step, entries in pairs(childResults.chainEntries) do
            results.chainEntries[step] = results.chainEntries[step] or {}
            for name, _ in pairs(entries) do
                results.chainEntries[step][name] = true
            end
        end
        for step, entries in pairs(childResults.directChainEntries) do
            results.directChainEntries[step] = results.directChainEntries[step] or {}
            for name, _ in pairs(entries) do
                results.directChainEntries[step][name] = true
            end
        end
        for step, entries in pairs(childResults.parallelChainEntries) do
            results.parallelChainEntries[step] = results.parallelChainEntries[step] or {}
            for name, _ in pairs(entries) do
                results.parallelChainEntries[step][name] = true
            end
        end
        for name, _ in pairs(childResults.parallelPaths) do
            results.parallelPaths[name] = true
        end
        if childResults.goesToMaster then
            results.goesToMaster = true
        end
        for _, p in ipairs(childResults.paths) do
            table.insert(results.paths, p)
        end
    end

    -- Trace through sends
    local sends = RoutingAnalysis.getTrackSends(startTrack)
    for _, send in ipairs(sends) do
        if not send.muted and send.track then
            local sendResults = RoutingAnalysis.traceRouting(
                proj, send.track, config, newAncestry, newPathNames, depth + 1, nowOnParallelPath
            )
            mergeResults(sendResults)
        end
    end

    -- Trace through parent folder routing
    local parentTrack, sendsToParent = RoutingAnalysis.getParentRouting(startTrack)
    if sendsToParent then
        if parentTrack then
            local parentResults = RoutingAnalysis.traceRouting(
                proj, parentTrack, config, newAncestry, newPathNames, depth + 1, isParallelPath
            )
            mergeResults(parentResults)
        else
            -- Top-level track with parent send ON goes to master
            results.goesToMaster = true
            table.insert(results.paths, {type = "master", path = newPathNames})
        end
    end

    -- If no paths were found, this is a dead end
    if #results.paths == 0 then
        table.insert(results.paths, {type = "dead_end", path = newPathNames})
    end

    return results
end

-- ============================================================================
-- TRACK ANALYSIS (SINGLE TRACK)
-- ============================================================================

--- @class TrackAnalysis
--- @field track MediaTrack The analyzed track
--- @field trackName string Track name
--- @field trackNumber integer 1-based track number
--- @field categorization TrackCategorization Track categorization result
--- @field hasContent boolean Whether track has actual content
--- @field isTopLevel boolean Whether track is top-level
--- @field isFolder boolean Whether track is a folder
--- @field hasReceives boolean Whether track has receives from other tracks
--- @field results RoutingResults|nil Full routing trace results
--- @field problems table Array of problem strings
--- @field skipReason string|nil Reason to skip this track, if any
--- @field directChainEntryCount integer Number of chain step 1 entries via direct path
--- @field directChainEntryList table Array of chain step 1 entry names (direct)
--- @field skippedToStep integer|nil If track skipped chain step 1, which step it went to

--- Analyzes a single track for routing problems
--- @param proj ReaProject
--- @param track MediaTrack
--- @param config RoutingAnalysisConfig
--- @return TrackAnalysis analysis
function RoutingAnalysis.analyzeTrack(proj, track, config)
    config = config or DEFAULT_CONFIG

    local trackName = RoutingAnalysis.getTrackName(track)
    local trackNumber = RoutingAnalysis.getTrackNumber(track)
    local categorization = RoutingAnalysis.categorizeTrack(proj, track, config)
    local hasContent = RoutingAnalysis.trackHasContent(track)
    local isTopLevel = RoutingAnalysis.isTopLevelTrack(track)
    local isFolder = RoutingAnalysis.isFolder(track)
    local hasReceives = RoutingAnalysis.trackHasReceives(track)

    local analysis = {
        track = track,
        trackName = trackName,
        trackNumber = trackNumber,
        categorization = categorization,
        hasContent = hasContent,
        isTopLevel = isTopLevel,
        isFolder = isFolder,
        hasReceives = hasReceives,
        results = nil,
        problems = {},
        skipReason = nil,
        directChainEntryCount = 0,
        directChainEntryList = {},
    }

    -- Skip non-source tracks (chain, parallel, ignored)
    if categorization.category ~= "source" then
        analysis.skipReason = categorization.category
        return analysis
    end

    -- Skip empty top-level non-folder tracks if configured
    if config.ignoreEmptyTopLevelTracks ~= false then
        if isTopLevel and not hasContent and not isFolder then
            analysis.skipReason = "empty top-level"
            return analysis
        end
    end

    -- Skip information tracks (video, markers, notes - top level with no routing)
    if RoutingAnalysis.isInformationTrack(track, config) then
        analysis.skipReason = "information track"
        return analysis
    end

    -- Skip organizational folders (grouping only, children route independently)
    if RoutingAnalysis.isOrganizationalFolder(track) then
        analysis.skipReason = "organizational folder"
        return analysis
    end

    -- Trace routing
    local results = RoutingAnalysis.traceRouting(proj, track, config)
    analysis.results = results

    -- Count direct entries to chain step 1 (the expected entry point)
    local directChainEntryList = {}
    local step1Entries = results.directChainEntries[1]
    if step1Entries then
        for entryName, _ in pairs(step1Entries) do
            table.insert(directChainEntryList, entryName)
        end
    end
    table.sort(directChainEntryList)
    analysis.directChainEntryCount = #directChainEntryList
    analysis.directChainEntryList = directChainEntryList

    -- Check if track skipped step 1 and went directly to a later step
    local skippedToLaterStep = false
    local laterStepReached = nil
    for step = 2, #(config.targetChain or {}) do
        if results.directChainEntries[step] then
            skippedToLaterStep = true
            laterStepReached = step
            break
        end
    end

    -- Detect problems
    if #directChainEntryList == 0 then
        if skippedToLaterStep then
            -- Went directly to a later chain step (e.g., direct to FULL MIX)
            table.insert(analysis.problems, "skipped_chain_step")
            analysis.skippedToStep = laterStepReached
        else
            -- No chain entry at all
            table.insert(analysis.problems, "orphaned")
        end
    elseif #directChainEntryList > 1 then
        table.insert(analysis.problems, "duplicate")
    end

    -- Check for master leak (goes to master AND has valid chain routing)
    if results.goesToMaster and #directChainEntryList > 0 then
        table.insert(analysis.problems, "master_leak")
    end

    return analysis
end

-- ============================================================================
-- PROJECT ANALYSIS (ALL TRACKS)
-- ============================================================================

--- @class ProjectAnalysis
--- @field totalTracks integer Total tracks in project
--- @field analyzedCount integer Tracks that were analyzed (source tracks)
--- @field skippedCount integer Tracks that were skipped
--- @field problemCount integer Tracks with problems
--- @field cleanCount integer Tracks with correct routing
--- @field problems table {orphaned: table, duplicate: table, skipped_chain_step: table, master_leak: table}
--- @field clean table Array of clean TrackAnalysis
--- @field skipped table Array of skipped TrackAnalysis

--- Analyzes all tracks in a project for routing problems
--- @param proj ReaProject
--- @param config RoutingAnalysisConfig
--- @return ProjectAnalysis analysis
function RoutingAnalysis.analyzeProject(proj, config)
    config = config or DEFAULT_CONFIG

    local analysis = {
        totalTracks = reaper.CountTracks(proj),
        analyzedCount = 0,
        skippedCount = 0,
        problemCount = 0,
        cleanCount = 0,
        problems = {
            orphaned = {},
            duplicate = {},
            skipped_chain_step = {},
            master_leak = {},
        },
        clean = {},
        skipped = {},
    }

    -- Analyze each track
    for i = 0, analysis.totalTracks - 1 do
        local track = reaper.GetTrack(proj, i)
        local trackAnalysis = RoutingAnalysis.analyzeTrack(proj, track, config)

        if trackAnalysis.skipReason then
            analysis.skippedCount = analysis.skippedCount + 1
            table.insert(analysis.skipped, trackAnalysis)
        else
            analysis.analyzedCount = analysis.analyzedCount + 1

            if #trackAnalysis.problems > 0 then
                analysis.problemCount = analysis.problemCount + 1

                -- Categorize by problem type
                for _, problem in ipairs(trackAnalysis.problems) do
                    if analysis.problems[problem] then
                        table.insert(analysis.problems[problem], trackAnalysis)
                    end
                end
            else
                analysis.cleanCount = analysis.cleanCount + 1
                table.insert(analysis.clean, trackAnalysis)
            end
        end
    end

    return analysis
end

-- ============================================================================
-- ROOT CAUSE DETECTION
-- ============================================================================

--- Finds the root cause track for a duplicate routing problem
--- Looks for where paths diverge to multiple chain entries
--- @param analysis TrackAnalysis The track analysis with problems
--- @return string|nil rootCauseName Name of the root cause track
function RoutingAnalysis.findDuplicateRootCause(analysis)
    if not analysis.results or not analysis.results.paths then
        return nil
    end

    local directPaths = {}
    for _, pathInfo in ipairs(analysis.results.paths) do
        -- Collect paths that reach chain step 1 via direct (non-parallel) routes
        if pathInfo.type == "chain" and pathInfo.chainStep == 1 and not pathInfo.viaParallel then
            table.insert(directPaths, pathInfo.path)
        end
    end

    if #directPaths < 2 then
        return nil
    end

    -- Find where paths diverge to different chain entries
    local minLen = math.huge
    for _, path in ipairs(directPaths) do
        minLen = math.min(minLen, #path)
    end

    for pos = 1, minLen do
        local tracksAtPos = {}
        for _, path in ipairs(directPaths) do
            tracksAtPos[path[pos]] = true
        end

        local uniqueCount = 0
        for _ in pairs(tracksAtPos) do
            uniqueCount = uniqueCount + 1
        end

        if uniqueCount == 1 and pos < minLen then
            local nextTracksAtPos = {}
            for _, path in ipairs(directPaths) do
                if path[pos + 1] then
                    nextTracksAtPos[path[pos + 1]] = true
                end
            end

            local nextUniqueCount = 0
            for _ in pairs(nextTracksAtPos) do
                nextUniqueCount = nextUniqueCount + 1
            end

            if nextUniqueCount > 1 then
                return directPaths[1][pos]
            end
        end
    end

    return nil
end

--- Finds the root cause track for an orphaned routing problem
--- Looks for the earliest track in the path that's also in the problem set
--- Also walks up the parent chain to find orphaned parent folders
--- @param analysis TrackAnalysis The track analysis with problems
--- @param problemTrackNames table<string, boolean> Set of all problem track names
--- @return string|nil rootCauseName Name of the root cause track
function RoutingAnalysis.findOrphanedRootCause(analysis, problemTrackNames)
    -- First check paths if they exist
    if analysis.results and analysis.results.paths then
        for _, pathInfo in ipairs(analysis.results.paths) do
            local path = pathInfo.path
            -- Start from position 2 (skip self at position 1)
            for pos = 2, #path do
                local trackName = path[pos]
                if problemTrackNames[trackName] then
                    return trackName
                end
            end
        end
    end

    -- Walk up the parent chain to find orphaned parent folders
    -- Only follow the chain while tracks actually route to their parent
    -- If a track has parent send disabled, it's an independent problem
    if analysis.track then
        local currentTrack = analysis.track
        local visited = {[tostring(currentTrack)] = true}

        -- Check if current track sends to parent
        local _, sendsToParent = RoutingAnalysis.getParentRouting(currentTrack)
        if not sendsToParent then
            return nil  -- This track doesn't route to parent, so parent can't be root cause
        end

        while true do
            local parentTrack = reaper.GetParentTrack(currentTrack)
            if not parentTrack then
                break  -- Reached top level
            end

            -- Prevent infinite loops
            local parentPtr = tostring(parentTrack)
            if visited[parentPtr] then
                break
            end
            visited[parentPtr] = true

            local parentName = RoutingAnalysis.getTrackName(parentTrack)
            if problemTrackNames[parentName] then
                return parentName
            end

            -- Check if this parent sends to its parent before continuing
            local _, parentSendsToParent = RoutingAnalysis.getParentRouting(parentTrack)
            if not parentSendsToParent then
                break  -- Parent doesn't route upward, stop here
            end

            currentTrack = parentTrack
        end
    end

    return nil
end

--- Finds the ultimate root cause by following the chain
--- If A's root cause is B, and B's root cause is C, returns C
--- @param trackName string Starting track name
--- @param immediateRootCauses table<string, string> Map of track -> immediate root cause
--- @param visited table<string, boolean> Tracks already visited (cycle detection)
--- @return string ultimateRootCause The deepest root cause in the chain
local function findUltimateRootCause(trackName, immediateRootCauses, visited)
    visited = visited or {}

    -- Cycle detection
    if visited[trackName] then
        return trackName
    end
    visited[trackName] = true

    local immediateCause = immediateRootCauses[trackName]
    if immediateCause and immediateCause ~= trackName then
        return findUltimateRootCause(immediateCause, immediateRootCauses, visited)
    end

    return trackName
end

--- Groups problem tracks by their root cause
--- @param problemTracks table Array of TrackAnalysis objects with the same problem type
--- @param problemType string The type of problem ("orphaned", "duplicate", etc.)
--- @return table groups Array of {rootCauseName, rootCauseAnalysis, affected}
function RoutingAnalysis.groupByRootCause(problemTracks, problemType)
    -- Build a map of track name -> analysis for quick lookup
    local analysisByName = {}
    local problemTrackNames = {}
    for _, analysis in ipairs(problemTracks) do
        analysisByName[analysis.trackName] = analysis
        problemTrackNames[analysis.trackName] = true
    end

    -- First pass: find immediate root cause for each track
    local immediateRootCauses = {}
    for _, analysis in ipairs(problemTracks) do
        local rootCauseName

        if problemType == "duplicate" then
            rootCauseName = RoutingAnalysis.findDuplicateRootCause(analysis)
        elseif problemType == "orphaned" then
            rootCauseName = RoutingAnalysis.findOrphanedRootCause(analysis, problemTrackNames)
        end

        if rootCauseName and rootCauseName ~= analysis.trackName then
            immediateRootCauses[analysis.trackName] = rootCauseName
        end
    end

    -- Second pass: resolve to ultimate root causes
    local rootCauseMap = {}  -- ultimateRootCauseName -> {rootCauseAnalysis, affectedTracks}
    local noRootCause = {}   -- tracks that are their own root cause

    for _, analysis in ipairs(problemTracks) do
        local ultimateCause = findUltimateRootCause(analysis.trackName, immediateRootCauses, {})

        if ultimateCause ~= analysis.trackName then
            if not rootCauseMap[ultimateCause] then
                rootCauseMap[ultimateCause] = {
                    rootCauseName = ultimateCause,
                    rootCauseAnalysis = analysisByName[ultimateCause],
                    affected = {}
                }
            end
            table.insert(rootCauseMap[ultimateCause].affected, analysis)
        else
            table.insert(noRootCause, analysis)
        end
    end

    -- Build final groups
    local groups = {}

    for _, analysis in ipairs(noRootCause) do
        if rootCauseMap[analysis.trackName] then
            local group = rootCauseMap[analysis.trackName]
            group.rootCauseAnalysis = analysis
            table.insert(groups, group)
            rootCauseMap[analysis.trackName] = nil
        else
            table.insert(groups, {
                rootCauseName = analysis.trackName,
                rootCauseAnalysis = analysis,
                affected = {}
            })
        end
    end

    for _, group in pairs(rootCauseMap) do
        table.insert(groups, group)
    end

    table.sort(groups, function(a, b)
        local aNum = a.rootCauseAnalysis and a.rootCauseAnalysis.trackNumber or 999999
        local bNum = b.rootCauseAnalysis and b.rootCauseAnalysis.trackNumber or 999999
        return aNum < bNum
    end)

    return groups
end

-- ============================================================================
-- DEAD END DETECTION
-- ============================================================================

--- Finds where routing terminates for an orphaned track
--- Returns the track name where the dead end occurs (for "ends at X" messaging)
--- @param results RoutingResults The routing trace results
--- @return string|nil deadEndTrackName Name of the track where routing dies, or nil if it's the track itself
function RoutingAnalysis.findDeadEndTrack(results)
    if not results or not results.paths then
        return nil
    end

    for _, pathInfo in ipairs(results.paths) do
        if pathInfo.type == "dead_end" and #pathInfo.path > 1 then
            -- Explicit dead_end path - last element is where it stops
            return pathInfo.path[#pathInfo.path]
        elseif pathInfo.type == "chain" and pathInfo.viaParallel and #pathInfo.path > 1 then
            -- Parallel path that reached chain - find the last track before parallel
            -- This helps identify where direct routing ended
            local lastBeforeParallel = nil
            for i = 2, #pathInfo.path - 1 do  -- Skip self and final destination
                lastBeforeParallel = pathInfo.path[i]
            end
            if lastBeforeParallel then
                return lastBeforeParallel
            end
        end
    end

    return nil
end

-- ============================================================================
-- OUTPUT FORMATTING
-- ============================================================================

--- Formats a routing path for display
--- @param pathInfo table {type, path, destination, viaParallel, chainStep}
--- @return string formatted path string
function RoutingAnalysis.formatPath(pathInfo)
    local pathStr = table.concat(pathInfo.path, " → ")
    if pathInfo.type == "chain" then
        local label = pathInfo.viaParallel and " [via parallel]" or " [direct]"
        local stepLabel = pathInfo.chainStep and string.format(" (step %d)", pathInfo.chainStep) or ""
        return "→ " .. pathStr .. stepLabel .. label
    elseif pathInfo.type == "master" then
        return "→ " .. pathStr .. " → Master [leak]"
    elseif pathInfo.type == "dead_end" then
        return "→ " .. pathStr .. " [dead end]"
    end
    return "→ " .. pathStr
end

--- Formats all paths from routing results
--- @param results RoutingResults
--- @return table Array of formatted path strings
function RoutingAnalysis.formatAllPaths(results)
    local formatted = {}
    for _, pathInfo in ipairs(results.paths) do
        table.insert(formatted, RoutingAnalysis.formatPath(pathInfo))
    end
    return formatted
end

return RoutingAnalysis
