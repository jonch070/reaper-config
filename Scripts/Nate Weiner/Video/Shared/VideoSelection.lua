-- VideoSelection.lua - Smart video selection utilities
-- Handles auto-selection and user prompting for video items
-- Author: Nate Weiner (https://nateweiner.com)

-- Load dependencies via NW global (set up by entry script's NWInit)
NW.requirePeerLib("ReaperUtils")

---@class VideoSelection
local VideoSelection = {}

---Find a video on a track named "Video" from a list of video items
---@param videoItems table Array of video item entries
---@return table|nil The video item on a "Video" track, or nil if none found
local function findVideoOnVideoTrack(videoItems)
    for _, videoInfo in ipairs(videoItems) do
        if videoInfo.trackName:lower() == "video" then
            return videoInfo
        end
    end
    return nil
end

---Check if a media item contains video content
---@param item MediaItem
---@return boolean
local function isVideoItem(item)
    local takeCount = reaper.CountTakes(item)
    for i = 0, takeCount - 1 do
        local take = reaper.GetTake(item, i)
        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            if source then
                local sourceType = reaper.GetMediaSourceType(source)
                if sourceType and (sourceType:upper():find("VIDEO") or sourceType:upper():find("MP4") or sourceType:upper():find("MOV")) then
                    return true
                end
            end
        end
    end
    return false
end

---Get all unique video items in the project
---@param project ReaProject|number The project to search (defaults to current project)
---@return table Array of {item, path, track, trackName} entries
local function getAllVideoItems(project)
    project = project or 0
    local itemCount = reaper.CountMediaItems(project)
    local videoItems = {}
    local seenPaths = {}

    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(project, i)
        if item and isVideoItem(item) then
            local take = reaper.GetActiveTake(item) or reaper.GetTake(item, 0)
            if take then
                local source = reaper.GetMediaItemTake_Source(take)
                if source then
                    local videoPath = reaper.GetMediaSourceFileName(source)
                    local track = reaper.GetMediaItem_Track(item)
                    local trackName = ""
                    if track then
                        local _, name = reaper.GetTrackName(track)
                        trackName = name or "Untitled Track"
                    end

                    -- Only add unique video paths (avoid duplicates from same source)
                    if videoPath and not seenPaths[videoPath] then
                        seenPaths[videoPath] = true
                        table.insert(videoItems, {
                            item = item,
                            path = videoPath,
                            track = track,
                            trackName = trackName
                        })
                    end
                end
            end
        end
    end

    return videoItems
end

---Get the topmost non-muted video item at the cursor position
---@param cursorPos number
---@return MediaItem|nil
---@return MediaTrack|nil
local function getVideoItemAtCursor(cursorPos)
    local project = 0
    local itemCount = reaper.CountMediaItems(project)

    local topMostVideoItem = nil
    local topMostTrack = nil
    local highestTrackNumber = -1

    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(project, i)
        if item and isVideoItem(item) then
            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local itemEnd = itemStart + itemLength

            if cursorPos >= itemStart and cursorPos < itemEnd then
                local track = reaper.GetMediaItem_Track(item)
                if track then
                    local isMuted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
                    if not isMuted then
                        local trackNumber = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
                        if trackNumber > highestTrackNumber then
                            highestTrackNumber = trackNumber
                            topMostVideoItem = item
                            topMostTrack = track
                        end
                    end
                end
            end
        end
    end

    return topMostVideoItem, topMostTrack
end

---Get video item using smart selection logic
---Priority: 1) Video at cursor, 2) Only video in project, 3) Video on "Video" track, 4) Check parent project
---@return MediaItem|nil Selected video item
---@return string|nil Video file path
---@return ReaProject|nil Project containing the video item
---@return string|nil Selection method ("cursor", "auto", "auto-parent", "video-track", "video-track-parent") or error message
function VideoSelection.getVideoItem()
    NW.log("VideoSelection","=== VideoSelection.getVideoItem ===")

    local currentProject, currentProjectPath = reaper.EnumProjects(-1)
    local cursorPos = reaper.GetCursorPosition()
    NW.log("VideoSelection",string.format("currentProjectPath: '%s'", currentProjectPath or "nil"))
    NW.log("VideoSelection",string.format("cursorPos: %.3f", cursorPos))

    -- Strategy 1: Try to get video at cursor position (in current project)
    NW.log("VideoSelection","Strategy 1: Checking for video at cursor")
    local itemAtCursor, _ = getVideoItemAtCursor(cursorPos)
    if itemAtCursor then
        local take = reaper.GetActiveTake(itemAtCursor) or reaper.GetTake(itemAtCursor, 0)
        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            if source then
                local videoPath = reaper.GetMediaSourceFileName(source)
                NW.log("VideoSelection","Found video at cursor: " .. (videoPath or "nil"))
                return itemAtCursor, videoPath, currentProject, "cursor"
            end
        end
    end
    NW.log("VideoSelection","No video at cursor")

    -- Strategy 2: Get all videos in current project
    NW.log("VideoSelection","Strategy 2: Getting all videos in project")
    local allVideos = getAllVideoItems(currentProject)
    NW.log("VideoSelection",string.format("Found %d video(s) in project", #allVideos))
    for i, v in ipairs(allVideos) do
        NW.log("VideoSelection",string.format("  Video %d: path='%s', track='%s'", i, v.path or "nil", v.trackName or "nil"))
    end

    if #allVideos == 1 then
        NW.log("VideoSelection","Single video found, using it")
        return allVideos[1].item, allVideos[1].path, currentProject, "auto"
    end

    if #allVideos > 1 then
        -- Multiple videos - look for one on a "Video" track
        NW.log("VideoSelection","Multiple videos, looking for 'Video' track")
        local videoTrackItem = findVideoOnVideoTrack(allVideos)
        if videoTrackItem then
            NW.log("VideoSelection","Found video on 'Video' track: " .. (videoTrackItem.path or "nil"))
            return videoTrackItem.item, videoTrackItem.path, currentProject, "video-track"
        end
        NW.log("VideoSelection","No video on 'Video' track, returning error")
        return nil, nil, nil, "Multiple videos found. Please position cursor on the video you want to use."
    end

    -- Strategy 3: No videos in current project, check parent project
    NW.log("VideoSelection","Strategy 3: Checking parent project")
    if not currentProjectPath or currentProjectPath == "" then
        NW.log("VideoSelection","No project path, cannot check parent")
        return nil, nil, nil, "No video items found in project"
    end

    local parentProject = NW.ReaperUtils.findParentProject(currentProjectPath)
    if not parentProject then
        NW.log("VideoSelection","No parent project found")
        return nil, nil, nil, "No video items found in current project or parent projects"
    end
    NW.log("VideoSelection","Found parent project, searching for videos")

    -- Search parent project for videos
    local parentVideos = getAllVideoItems(parentProject)
    NW.log("VideoSelection",string.format("Found %d video(s) in parent project", #parentVideos))

    if #parentVideos == 0 then
        return nil, nil, nil, "No video items found in parent project"
    end

    if #parentVideos == 1 then
        NW.log("VideoSelection","Single video in parent, using it: " .. (parentVideos[1].path or "nil"))
        return parentVideos[1].item, parentVideos[1].path, parentProject, "auto-parent"
    end

    -- Multiple videos in parent project - look for one on a "Video" track
    NW.log("VideoSelection","Multiple videos in parent, looking for 'Video' track")
    local videoTrackItem = findVideoOnVideoTrack(parentVideos)
    if videoTrackItem then
        NW.log("VideoSelection","Found video on 'Video' track in parent: " .. (videoTrackItem.path or "nil"))
        return videoTrackItem.item, videoTrackItem.path, parentProject, "video-track-parent"
    end

    NW.log("VideoSelection","No video on 'Video' track in parent, returning error")
    return nil, nil, nil, "Multiple videos found in parent project. Please position cursor on the video you want to use."
end

---Get the source video file path from a media item
---@param item MediaItem
---@return string|nil
function VideoSelection.getVideoFilePath(item)
    local take = reaper.GetActiveTake(item)
    if not take then
        take = reaper.GetTake(item, 0)
    end

    if take then
        local source = reaper.GetMediaItemTake_Source(take)
        if source then
            return reaper.GetMediaSourceFileName(source)
        end
    end

    return nil
end

return VideoSelection
