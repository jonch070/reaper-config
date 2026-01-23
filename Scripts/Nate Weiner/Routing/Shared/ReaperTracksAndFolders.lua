-- ReaperTracksAndFolders.lua - Track finding and folder hierarchy utilities
-- Author: Nate Weiner (https://nateweiner.com)

---@class ReaperTracksAndFolders
local ReaperTracksAndFolders = {}

-- ============================================================================
-- TRACK FINDING
-- ============================================================================

---@class TrackSearchOptions
---@field contains boolean? If true, use substring match instead of exact match (default: false)

---Gets the name of a track
---@param track MediaTrack
---@return string name Track name, or "Track N" if unnamed
function ReaperTracksAndFolders.getTrackName(track)
    local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if name == "" then
        local idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        return "Track " .. math.floor(idx)
    end
    return name
end

---Gets the 1-based track number
---@param track MediaTrack
---@return integer trackNumber 1-based track number
function ReaperTracksAndFolders.getTrackNumber(track)
    return math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
end

---Finds a track by name in the given project
---@param proj ReaProject The project to search in (use 0 for current project)
---@param trackName string The name of the track to find
---@param options TrackSearchOptions? Search options
---@return MediaTrack|nil track The track if found, nil otherwise
function ReaperTracksAndFolders.findTrackByName(proj, trackName, options)
    options = options or {}
    local trackCount = reaper.CountTracks(proj)

    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(proj, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if options.contains then
            if name:find(trackName, 1, true) then
                return track
            end
        else
            if name == trackName then
                return track
            end
        end
    end
    return nil
end

-- ============================================================================
-- FOLDER DETECTION
-- ============================================================================

---Checks if a track is a folder (has children)
---@param track MediaTrack
---@return boolean isFolder True if track is a folder parent
function ReaperTracksAndFolders.isFolder(track)
    local folderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    return folderDepth >= 1
end

---Checks if a track is inside a specific folder
---Uses running depth sum to determine folder boundaries
---@param proj ReaProject The project (use 0 for current project)
---@param track MediaTrack The track to check
---@param folderTrack MediaTrack The folder track to check against
---@return boolean isInFolder True if track is inside the folder
function ReaperTracksAndFolders.isTrackInFolder(proj, track, folderTrack)
    if not folderTrack then return false end

    local folderIdx = ReaperTracksAndFolders.getTrackNumber(folderTrack) - 1
    local trackIdx = ReaperTracksAndFolders.getTrackNumber(track) - 1

    -- Track must come after the folder
    if trackIdx <= folderIdx then return false end

    -- Walk from folder to find its extent using running depth sum
    local folderDepth = reaper.GetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH")
    local currentDepth = folderDepth
    local trackCount = reaper.CountTracks(proj)

    for i = folderIdx + 1, trackCount - 1 do
        local t = reaper.GetTrack(proj, i)
        if i == trackIdx then
            return currentDepth > 0
        end
        local depth = reaper.GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        currentDepth = currentDepth + depth
        if currentDepth <= 0 then
            return false  -- Folder ended before we reached the track
        end
    end

    return false
end

-- ============================================================================
-- FOLDER CONTENTS
-- ============================================================================

---Gets all tracks within a folder (all descendants)
---@param proj ReaProject The project (use 0 for current project)
---@param folderTrack MediaTrack The folder track
---@return MediaTrack[] tracks Array of all tracks inside the folder
function ReaperTracksAndFolders.getAllTracksInFolder(proj, folderTrack)
    local tracks = {}

    local folderDepth = reaper.GetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH")
    if folderDepth <= 0 then
        return tracks  -- Not a folder
    end

    local folderIdx = ReaperTracksAndFolders.getTrackNumber(folderTrack) - 1
    local currentDepth = folderDepth
    local idx = folderIdx + 1
    local trackCount = reaper.CountTracks(proj)

    while idx < trackCount and currentDepth > 0 do
        local track = reaper.GetTrack(proj, idx)
        table.insert(tracks, track)

        local trackFolderDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        currentDepth = currentDepth + trackFolderDepth

        idx = idx + 1
    end

    return tracks
end

---Gets all tracks within a named folder
---@param proj ReaProject The project (use 0 for current project)
---@param folderName string Name of the folder track
---@return MediaTrack[]|nil tracks Array of MediaTrack objects, or nil if folder not found
---@return string|nil error Error message if folder not found
function ReaperTracksAndFolders.getTracksInFolder(proj, folderName)
    local folderTrack = ReaperTracksAndFolders.findTrackByName(proj, folderName)
    if not folderTrack then
        return nil, "Folder '" .. folderName .. "' not found"
    end

    local folderDepth = reaper.GetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH")
    if folderDepth <= 0 then
        return nil, "Track '" .. folderName .. "' is not a folder"
    end

    return ReaperTracksAndFolders.getAllTracksInFolder(proj, folderTrack), nil
end

---Gets immediate children of a folder (not grandchildren)
---@param folderTrack MediaTrack The folder track
---@return MediaTrack[] children Array of immediate child tracks
function ReaperTracksAndFolders.getImmediateChildren(folderTrack)
    local children = {}
    local folderIdx = ReaperTracksAndFolders.getTrackNumber(folderTrack) - 1
    local totalTracks = reaper.CountTracks(0)

    local parentDepth = reaper.GetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH")
    if parentDepth <= 0 then
        return children  -- Not a folder
    end

    local currentDepth = parentDepth
    for i = folderIdx + 1, totalTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local trackDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        -- Add track if at immediate child level (before processing depth change)
        if currentDepth == parentDepth then
            table.insert(children, track)
        end

        -- Update depth after checking
        currentDepth = currentDepth + trackDepth

        if currentDepth <= 0 then
            break  -- Exited folder
        end
    end

    return children
end

---Finds a track by name within a specific folder
---@param proj ReaProject The project (use 0 for current project)
---@param folderName string Name of the folder to search in
---@param trackName string Name of the track to find
---@param options TrackSearchOptions? Search options
---@return MediaTrack|nil track The track if found, nil otherwise
---@return string|nil error Error message if folder not found
function ReaperTracksAndFolders.findTrackByNameInFolder(proj, folderName, trackName, options)
    options = options or {}

    local tracks, err = ReaperTracksAndFolders.getTracksInFolder(proj, folderName)
    if not tracks then
        return nil, err
    end

    for _, track in ipairs(tracks) do
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if options.contains then
            if name:find(trackName, 1, true) then
                return track, nil
            end
        else
            if name == trackName then
                return track, nil
            end
        end
    end

    return nil, nil
end

-- ============================================================================
-- FOLDER HIERARCHY
-- ============================================================================

---Gets all parent folders of a track (ancestors)
---@param track MediaTrack The track to find parents for
---@return MediaTrack[] parents Array of parent folders, topmost first
function ReaperTracksAndFolders.getParentFolders(track)
    local parents = {}
    local current = track

    while true do
        current = reaper.GetParentTrack(current)
        if not current then
            break
        end
        table.insert(parents, 1, current)  -- Insert at beginning (topmost first)
    end

    return parents
end

---Checks if a track is top-level (not inside any folder)
---@param track MediaTrack
---@return boolean isTopLevel True if track has no parent folder
function ReaperTracksAndFolders.isTopLevel(track)
    return reaper.GetParentTrack(track) == nil
end

return ReaperTracksAndFolders
