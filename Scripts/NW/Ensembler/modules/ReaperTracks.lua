-- ReaperTracks.lua - Track Management

require('types/types')
local Cache = require('modules/Cache')
ReaperTracks = {}

--------------------------------------------------------------------------------
-- Track Cache
--------------------------------------------------------------------------------

-- Track cache for search performance
local trackCache = Cache.create(function()
    ---@type TrackCacheTrack[]
    local tracks = {}
    local track_count = reaper.CountTracks(0)

    -- Stack to track currently open folders (used for parent tracking)
    ---@type TrackCacheTrack[]
    local folderStack = {}

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local retval, name = reaper.GetTrackName(track)
        local guid = reaper.GetTrackGUID(track)
        local color = reaper.GetTrackColor(track)
        local isVisible = reaper.IsTrackVisible(track, false) -- false = TCP visibility
        local folderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        -- If no custom color, use default
        if color == 0 then
            color = 0x808080FF -- Gray default
        end

        -- Copy current folder stack to get this track's parents
        ---@type TrackCacheTrack[]
        local parentFolders = {}
        for _, parent in ipairs(folderStack) do
            table.insert(parentFolders, parent)
        end

        -- Create track cache entry
        ---@type TrackCacheTrack
        local trackEntry = {
            guid = guid,
            name = name,
            number = i + 1,
            color = color,
            track = track,
            isVisible = isVisible,
            parentFolders = parentFolders
        }

        table.insert(tracks, trackEntry)

        -- Update folder stack based on folder depth
        if folderDepth == 1 then
            -- This track is a folder parent, push it onto the stack
            table.insert(folderStack, trackEntry)
        elseif folderDepth < 0 then
            -- Close folder(s) - pop from stack
            for j = 1, math.abs(folderDepth) do
                table.remove(folderStack)
            end
        end
    end

    Debug.log("Track cache loaded: " .. #tracks .. " tracks", Debug.FEATURE.TRACKS)
    return tracks
end)

---Ensure track cache is loaded for search performance
function ReaperTracks.ensureCache()
    trackCache:ensureCache()
end

---Check if track cache is ready
---@return boolean ready
function ReaperTracks.isCacheReady()
    return trackCache.cache ~= nil
end

---Clear track cache to free memory
function ReaperTracks.clearCache()
    trackCache:clear()
end

---Force reload track cache immediately
function ReaperTracks.reloadCache()
    trackCache:reload()
end

--------------------------------------------------------------------------------
-- Querying
--------------------------------------------------------------------------------

---Find track by GUID
---@param guid string
---@return MediaTrack|nil
function ReaperTracks.get_by_guid(guid)
    local track_count = reaper.CountTracks(0)
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        if track and reaper.GetTrackGUID(track) == guid then
            return track
        end
    end
    return nil
end

---Find track by exact name match (uses filter and returns first exact match)
---@param trackName string
---@return TrackCacheTrack|nil
function ReaperTracks.findByName(trackName)
    local results = ReaperTracks.filter(trackName)

    -- Return first exact match
    for _, track in ipairs(results) do
        if track.name == trackName then
            return track
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Searching
--------------------------------------------------------------------------------

---Helper function to check if any parent folder matches the query
---@param parentFolders TrackCacheTrack[]
---@param query_lower string
---@param starts_with boolean If true, check if folder starts with query; if false, check if it contains query
---@return boolean matches
local function anyParentFolderMatches(parentFolders, query_lower, starts_with)
    for _, parent in ipairs(parentFolders) do
        local parent_name_lower = parent.name:lower()
        if starts_with then
            if parent_name_lower:sub(1, #query_lower) == query_lower then
                return true
            end
        else
            if parent_name_lower:find(query_lower, 1, true) then
                return true
            end
        end
    end
    return false
end

---Filter tracks based on search query
---@param query string
---@return TrackCacheTrack[]
function ReaperTracks.filter(query)
    -- Get cached data (loads if needed)
    local allTracks = trackCache:getData()

    if not query or query == "" then
        return {}
    end

    ---@type TrackCacheTrack[]
    local filtered = {}
    local query_lower = query:lower()
    for _, track in ipairs(allTracks) do
        local name_lower = track.name:lower()
        local trackNameMatches = name_lower:find(query_lower, 1, true)
        local parentFolderMatches = anyParentFolderMatches(track.parentFolders, query_lower, false)

        -- Match if:
        -- 1. Track name contains query, OR
        -- 2. Any parent folder name contains query
        -- AND track is not already assigned to ensemble
        if not State.ensemble.isTrackGuidInEnsemble(track.guid) and
           (trackNameMatches or parentFolderMatches) then
            filtered[#filtered+1] = track
        end
    end

    -- Sort by 5-tier priority:
    -- 1. TCP visibility (visible first)
    -- 2. Track name starts with query
    -- 3. Track name contains query
    -- 4. Any parent folder starts with query
    -- 5. Any parent folder contains query
    -- Within each tier, sort by track number (project order)
    table.sort(filtered, function(a, b)
        -- Tier 1: TCP visibility
        if a.isVisible ~= b.isVisible then
            return a.isVisible -- true comes before false
        end

        local a_name_lower = a.name:lower()
        local b_name_lower = b.name:lower()

        -- Tier 2: Track name starts with query
        local a_name_starts = a_name_lower:sub(1, #query_lower) == query_lower
        local b_name_starts = b_name_lower:sub(1, #query_lower) == query_lower
        if a_name_starts ~= b_name_starts then
            return a_name_starts
        end

        -- Tier 3: Track name contains query (both must contain to be in filtered list)
        -- If we're here, either both start with query or neither does
        -- If both start, they're equal on tier 2, continue to track number
        -- If neither starts, both contain (tier 3), continue to tier 4

        -- Tier 4: Any parent folder starts with query
        local a_folder_starts = anyParentFolderMatches(a.parentFolders, query_lower, true)
        local b_folder_starts = anyParentFolderMatches(b.parentFolders, query_lower, true)
        if a_folder_starts ~= b_folder_starts then
            return a_folder_starts
        end

        -- Tier 5: Any parent folder contains query
        local a_folder_contains = anyParentFolderMatches(a.parentFolders, query_lower, false)
        local b_folder_contains = anyParentFolderMatches(b.parentFolders, query_lower, false)
        if a_folder_contains ~= b_folder_contains then
            return a_folder_contains
        end

        -- Final tiebreaker: Track number (project order)
        return a.number < b.number
    end)
    return filtered
end


--------------------------------------------------------------------------------
-- Selection Management
--------------------------------------------------------------------------------

---Check if a track is "disabled" (all FX are offline)
---@param track MediaTrack
---@return boolean isDisabled True if all FX are offline (track is disabled)
local function isTrackDisabled(track)
    local fx_count = reaper.TrackFX_GetCount(track)

    -- No FX means track is not disabled (nothing to disable)
    if fx_count == 0 then
        return false
    end

    -- Check if all FX are offline
    for fx_idx = 0, fx_count - 1 do
        local is_offline = reaper.TrackFX_GetOffline(track, fx_idx)
        if not is_offline then
            -- Found an online FX, track is not disabled
            return false
        end
    end

    -- All FX are offline, track is disabled
    return true
end

---Ensure all selected tracks are visible and enabled
---This checks the currently selected tracks and enables any that are disabled
local function ensureSelectedTracksVisibleAndEnabled()
    -- Collect tracks that need to be enabled
    local disabled_tracks = {}
    local selected_count = reaper.CountSelectedTracks(0)

    for i = 0, selected_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)

        -- Ensure track is visible in TCP (arrange view)
        reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)

        -- Ensure track is visible in MCP (mixer)
        reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)

        -- Check if track is disabled (all FX offline)
        if isTrackDisabled(track) then
            table.insert(disabled_tracks, track)
        end
    end

    -- If any tracks are disabled, enable them using the custom action
    if #disabled_tracks > 0 then
        -- Save current selection state
        local saved_selection = {}
        for i = 0, selected_count - 1 do
            saved_selection[#saved_selection + 1] = reaper.GetSelectedTrack(0, i)
        end

        -- Clear selection and select only disabled tracks
        reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks

        for _, track in ipairs(disabled_tracks) do
            reaper.SetTrackSelected(track, true)
        end

        -- Call custom action to enable tracks (toggles FX online and unlocks)
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_4fecd71ecbb240acb246f1f80c1ac6f1"), 0)

        -- Clear selection and restore original selection
        reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks

        for _, track in ipairs(saved_selection) do
            reaper.SetTrackSelected(track, true)
        end
    end
end

-- Sync Reaper track selection with ensemble
-- IMPORTANT: This function ensures that only ensemble tracks are selected without
-- disrupting playback or recording. The previous approach of "deselect all, then reselect"
-- could interfere with auto-arm settings during recording, causing stuck notes and
-- broken recording continuity. This smarter approach only changes selection when needed.
function ReaperTracks.sync_track_selection()
    -- Get all currently selected tracks to check against
    local currently_selected = {}
    local selected_count = reaper.CountSelectedTracks(0)
    for i = 0, selected_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        currently_selected[track] = true
    end
    
    -- Ensure all ensemble tracks are selected and remove them from the check list
    for _, instrument in ipairs(State.ensemble.getAllInstruments()) do
        local track = instrument.trackData.reaperTrack
        if not currently_selected[track] then
            reaper.SetTrackSelected(track, true)
        end
        -- Remove from check list so we don't deselect it later
        currently_selected[track] = nil
    end

    -- Deselect any remaining tracks that shouldn't be selected
    for track, _ in pairs(currently_selected) do
        reaper.SetTrackSelected(track, false)
    end

    -- Ensure selected tracks (now all ensemble tracks) are visible and enabled
    ensureSelectedTracksVisibleAndEnabled()
end

-- Check if track selection has changed externally
function ReaperTracks.doesReaperSelectedTracksMatchEnsemble()
    -- Get all of the instruments in the Ensemble
    local instruments = State.ensemble.getAllInstruments()

    -- First check if the number of selected tracks matches the number of instruments
    local track_count = reaper.CountSelectedTracks(0)
    if (#instruments ~= track_count) then 
        return false 
    end

    -- Else If it does match, now we'll need to look to confirm the selected tracks are the same as ours

    -- Make a look-up table based on guid from the current instruments
    local instrumentsByGUID = {}
    for _, instrument in ipairs(instruments) do 
        instrumentsByGUID[instrument.trackData.guid] = instrument
    end 
    
    -- Iterate through the Reaper selection and look to see if we have any tracks that aren't in ours
    -- (This only works because we checked that the count of selected tracks is equal, otherwise it could miss some)
    for i = 0, track_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local guid = reaper.GetTrackGUID(track)
        if instrumentsByGUID[guid] == nil then 
            return false
        end 
    end

    -- If we get here, then the selection should be the same
    return true
end

return ReaperTracks