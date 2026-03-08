-- Move item at cursor to nearest video cut
-- Shifts all selected items so the moment under the edit cursor aligns with the nearest video cut
-- Reads from Nate Weiner's video cut cache (run his "Move edit cursor to next video cut" first)
-- Author: JK

-- Must match Nate Weiner's config.lua values
local EXTSTATE_SECTION = "VideoSceneCuts"
local KEY_PREFIX = "VSC_1"

local function getCacheKey(videoPath)
    local key = KEY_PREFIX .. videoPath:gsub("[^%w]", "_")
    if #key > 200 then
        local hash = 0
        for i = 1, #videoPath do
            hash = (hash * 31 + string.byte(videoPath, i)) % 2147483647
        end
        key = key:sub(1, 190) .. "_" .. tostring(hash)
    end
    return key
end

local function loadCache(project, videoPath)
    local key = getCacheKey(videoPath)
    local success, stateData = reaper.GetProjExtState(project, EXTSTATE_SECTION, key)
    if success ~= 1 or stateData == "" then return nil end
    local fn = load(stateData)
    if not fn then return nil end
    local ok, data = pcall(fn)
    return ok and data or nil
end

local function isVideoItem(item)
    local take = reaper.GetActiveTake(item) or reaper.GetTake(item, 0)
    if not take then return false end
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return false end
    local t = reaper.GetMediaSourceType(source)
    if not t then return false end
    t = t:upper()
    return t:find("VIDEO") ~= nil or t:find("MP4") ~= nil or t:find("MOV") ~= nil
end

-- Returns a video item at the cursor, or the only video item in the project
local function findVideoItem(cursor)
    local project = reaper.EnumProjects(-1)
    local itemCount = reaper.CountMediaItems(0)
    local allVideos = {}

    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(0, i)
        if item and isVideoItem(item) then
            local take = reaper.GetActiveTake(item) or reaper.GetTake(item, 0)
            local source = take and reaper.GetMediaItemTake_Source(take)
            local path = source and reaper.GetMediaSourceFileName(source)
            if path then
                local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                if cursor >= pos and cursor < pos + len then
                    return item, path, project
                end
                table.insert(allVideos, { item = item, path = path })
            end
        end
    end

    if #allVideos == 1 then
        return allVideos[1].item, allVideos[1].path, project
    end

    return nil, nil, nil
end

local function main()
    if reaper.CountSelectedMediaItems(0) == 0 then return end

    local cursor = reaper.GetCursorPosition()

    local videoItem, videoPath, project = findVideoItem(cursor)
    if not videoItem then
        reaper.ShowMessageBox(
            "No video item found.\n\nPlace the cursor over a video item, or ensure only one video item exists in the project.",
            "Move to Video Cut", 0)
        return
    end

    local cache = loadCache(project, videoPath)
    if not cache or not cache.cuts or #cache.cuts == 0 then
        reaper.ShowMessageBox(
            "No video cut cache found for this video.\n\nRun \"NateWeiner - Move edit cursor to next video cut\" first to build the cache.",
            "Move to Video Cut", 0)
        return
    end

    -- Convert cursor project time to source time
    local take = reaper.GetActiveTake(videoItem) or reaper.GetTake(videoItem, 0)
    local itemPos = reaper.GetMediaItemInfo_Value(videoItem, "D_POSITION")
    local startOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playRate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if playRate == 0 then playRate = 1 end

    local cursorSourceTime = startOffset + (cursor - itemPos) * playRate

    -- Find nearest cut in source time
    local nearestCutSrc = nil
    local nearestDist = math.huge
    for _, cutSrc in ipairs(cache.cuts) do
        local dist = math.abs(cutSrc - cursorSourceTime)
        if dist < nearestDist then
            nearestDist = dist
            nearestCutSrc = cutSrc
        end
    end

    if not nearestCutSrc then return end

    -- Convert cut source time back to project time and calculate offset
    local cutProjectTime = itemPos + (nearestCutSrc - startOffset) / playRate
    local offset = cutProjectTime - cursor

    if math.abs(offset) < 0.0001 then return end

    local count = reaper.CountSelectedMediaItems(0)
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + offset)
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Move item at cursor to nearest video cut", -1)
end

main()
