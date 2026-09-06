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

---Finds a track by name, trying exact match first then falling back to contains
---@param proj ReaProject The project to search in (use 0 for current project)
---@param trackName string The name of the track to find
---@return MediaTrack|nil track The track if found, nil otherwise
function ReaperTracksAndFolders.findTrackByNameExactThenContains(proj, trackName)
    return ReaperTracksAndFolders.findTrackByName(proj, trackName)
        or ReaperTracksAndFolders.findTrackByName(proj, trackName, { contains = true })
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

-- ============================================================================
-- FOLDER BOUNDARIES
-- ============================================================================

---Finds the last track inside a folder (the track whose depth delta closes it)
---@param folderTrack MediaTrack A folder track (I_FOLDERDEPTH >= 1)
---@return MediaTrack|nil lastTrack The last track inside the folder
---@return integer|nil lastIdx 0-based index of the last track
function ReaperTracksAndFolders.findLastTrackInFolder(folderTrack)
    local folderIdx = ReaperTracksAndFolders.getTrackNumber(folderTrack) - 1
    local currentDepth = reaper.GetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH")
    if currentDepth <= 0 then return nil, nil end

    local trackCount = reaper.CountTracks(0)
    for i = folderIdx + 1, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        currentDepth = currentDepth + reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if currentDepth <= 0 then
            return track, i
        end
    end

    return nil, nil
end

-- ============================================================================
-- FOLDER MUTATION
-- ============================================================================

---Appends tracks as immediate children at the end of a folder.
---Handles all folder depth arithmetic internally.
---The folder track must already be a folder (I_FOLDERDEPTH >= 1).
---Preserves track selection state.
---@param folderTrack MediaTrack The folder to append tracks into
---@param tracks MediaTrack[] Array of tracks to move into the folder
---@return boolean success True if tracks were moved successfully
function ReaperTracksAndFolders.appendTracksToFolder(folderTrack, tracks)
    if #tracks == 0 then return false end
    if not ReaperTracksAndFolders.isFolder(folderTrack) then return false end

    -- Save current selection
    local savedSelection = {}
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
        table.insert(savedSelection, reaper.GetSelectedTrack(0, i))
    end

    -- Find the last track in the folder and steal one closing level
    local lastTrack, lastIdx = ReaperTracksAndFolders.findLastTrackInFolder(folderTrack)
    local insertIdx
    if lastTrack then
        local lastDepth = reaper.GetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH")
        reaper.SetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH", lastDepth + 1)
        insertIdx = lastIdx + 1
    else
        -- Empty folder or unclosed folder — insert right after the folder track
        insertIdx = ReaperTracksAndFolders.getTrackNumber(folderTrack)
    end

    -- Move tracks to the insertion point without folder depth adjustment
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    for _, track in ipairs(tracks) do
        reaper.SetTrackSelected(track, true)
    end
    reaper.ReorderSelectedTracks(insertIdx, 0)

    -- Set depths: all tracks get 0, last one closes the folder
    for i, track in ipairs(tracks) do
        if i == #tracks then
            reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", -1)
        else
            reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
        end
    end

    -- Restore selection
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    for _, track in ipairs(savedSelection) do
        reaper.SetTrackSelected(track, true)
    end

    return true
end

---Creates a new subfolder at the end of a parent track and moves tracks into it.
---Works whether the parent is already a folder or a plain track.
---If the parent is not a folder, it is converted to one atomically —
---the subfolder and tracks are inserted in the same operation so
---neighboring tracks are never absorbed.
---Preserves track selection state.
---@param parentTrack MediaTrack The parent track (folder or plain)
---@param name string Name for the new subfolder
---@param tracks MediaTrack[] Array of tracks to move into the new subfolder
---@return MediaTrack|nil subfolderTrack The created subfolder track, or nil on failure
function ReaperTracksAndFolders.createSubfolderWithTracks(parentTrack, name, tracks)
    if #tracks == 0 then return nil end

    -- Save current selection
    local savedSelection = {}
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
        table.insert(savedSelection, reaper.GetSelectedTrack(0, i))
    end

    local isFolder = ReaperTracksAndFolders.isFolder(parentTrack)
    local parentIdx = ReaperTracksAndFolders.getTrackNumber(parentTrack) - 1
    local insertIdx

    if isFolder then
        -- Parent is already a folder: insert after its last child
        -- Steal one closing level so the parent stays open for our new content
        local lastTrack, lastIdx = ReaperTracksAndFolders.findLastTrackInFolder(parentTrack)
        if lastTrack then
            local lastDepth = reaper.GetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH")
            reaper.SetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH", lastDepth + 1)
            insertIdx = lastIdx + 1
        else
            insertIdx = parentIdx + 1
        end
    else
        -- Parent is not a folder: convert it to one and insert right after
        -- No need to adjust the next track — the -2 on the last moved track
        -- will close both the subfolder and the parent before reaching neighbors
        reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
        insertIdx = parentIdx + 1
    end

    -- Insert the subfolder track
    reaper.InsertTrackAtIndex(insertIdx, true)
    local subfolderTrack = reaper.GetTrack(0, insertIdx)
    reaper.GetSetMediaTrackInfo_String(subfolderTrack, "P_NAME", name, true)
    reaper.SetMediaTrackInfo_Value(subfolderTrack, "I_FOLDERDEPTH", 1)
    reaper.SetMediaTrackInfo_Value(subfolderTrack, "B_MAINSEND", 1)

    -- Move tracks after the subfolder (no folder depth adjustment)
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    for _, track in ipairs(tracks) do
        reaper.SetTrackSelected(track, true)
    end
    reaper.ReorderSelectedTracks(insertIdx + 1, 0)

    -- Set depths: all get 0, last one closes both subfolder and parent (-2)
    for i, track in ipairs(tracks) do
        if i == #tracks then
            reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", -2)
        else
            reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
        end
    end

    -- Restore selection
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    for _, track in ipairs(savedSelection) do
        reaper.SetTrackSelected(track, true)
    end

    return subfolderTrack
end

return ReaperTracksAndFolders
