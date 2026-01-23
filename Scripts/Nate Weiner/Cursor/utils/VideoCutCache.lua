-- VideoCutCache.lua - Cache management for video scene cuts
-- Stores cut data in project ExtState using Lua table serialization
--
-- IMPORTANT: All timestamp values in the cache are in SourceTime (seconds from video file start)
--   - cache.cuts[] contains SourceTime values
--   - cache.processed_ranges[] contains [startSourceTime, endSourceTime] pairs
--
-- Author: Nate Weiner (https://nateweiner.com)

local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")

-- Normalize path separators for cross-platform compatibility
local isWindows = reaper.GetOS():match("Win") ~= nil
if isWindows then
    scriptPath = scriptPath:gsub("/", "\\")
end

-- Use patterns that work on both platforms
local scriptDir = scriptPath:match("^(.+)[/\\][^/\\]+$")
local parentDir = scriptDir:match("^(.+)[/\\][^/\\]+$")
package.path = package.path .. ";" .. parentDir .. "/?.lua"

local VideoCutConfig = require("config")

local VideoCutCache = {}

-- Shorthand config references
local EXTSTATE_SECTION = VideoCutConfig.EXTSTATE_SECTION
local KEY_PREFIX = VideoCutConfig.KEY_PREFIX

---Escape string for safe serialization
---@param str string String to escape
---@return string
local function escapeString(str)
    return str:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
end

---Serialize a Lua value to string
---@param value any Value to serialize
---@param indent? number Indentation level
---@return string
local function serializeValue(value, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)

    if type(value) == "nil" then
        return "nil"
    elseif type(value) == "boolean" then
        return tostring(value)
    elseif type(value) == "number" then
        return tostring(value)
    elseif type(value) == "string" then
        return '"' .. escapeString(value) .. '"'
    elseif type(value) == "table" then
        local result = "{\n"
        for k, v in pairs(value) do
            local key_str
            if type(k) == "string" then
                key_str = '["' .. escapeString(k) .. '"]'
            else
                key_str = "[" .. tostring(k) .. "]"
            end
            result = result .. spacing .. "  " .. key_str .. " = " .. serializeValue(v, indent + 1) .. ",\n"
        end
        result = result .. spacing .. "}"
        return result
    else
        return "nil"
    end
end

---Convert table to string for storage
---@param data table Data to serialize
---@return string
local function tableToString(data)
    return "return " .. serializeValue(data)
end

---Convert string back to table
---@param stringData string Serialized data
---@return table|nil
local function stringToTable(stringData)
    if not stringData or stringData == "" then
        return nil
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local success, loadedFunc = pcall(load, stringData)
    if not success or not loadedFunc then
        return nil
    end

    local executeSuccess, data = pcall(loadedFunc)
    if not executeSuccess then
        return nil
    end

    return data
end

---Generate cache key from video path
---@param videoPath string Full path to video file
---@return string
local function getCacheKey(videoPath)
    -- Sanitize path (replace non-alphanumeric with underscore)
    local key = KEY_PREFIX .. videoPath:gsub("[^%w]", "_")

    -- If key is too long, truncate and add hash suffix
    if #key > 200 then
        local hash = 0
        for i = 1, #videoPath do
            hash = (hash * 31 + string.byte(videoPath, i)) % 2147483647
        end
        key = key:sub(1, 190) .. "_" .. tostring(hash)
    end

    return key
end

---Get the project that contains the video item
---@param videoItem MediaItem The video item
---@return ReaProject|nil
function VideoCutCache.getProjectForItem(videoItem)
    if not videoItem then
        return nil
    end

    local track = reaper.GetMediaItem_Track(videoItem)
    if not track then
        return nil
    end

    return reaper.GetItemProjectContext(videoItem)
end

---Load cache for a video from project ExtState
---@param project ReaProject The project to load from
---@param videoPath string Path to video file
---@return table|nil Cache data or nil if not found
function VideoCutCache.load(project, videoPath)
    if not project or not videoPath then
        NW.log("Cache","Load failed: missing project or videoPath")
        return nil
    end

    local key = getCacheKey(videoPath)
    NW.log("Cache","Loading cache with key: " .. key:sub(1, 20) .. "...")

    ---@diagnostic disable-next-line: redundant-return-value
    local success, stateData = reaper.GetProjExtState(project, EXTSTATE_SECTION, key)

    if success ~= 1 or stateData == "" then
        NW.log("Cache","No cache found (success=" .. tostring(success) .. ", data empty=" .. tostring(stateData == "") .. ")")
        return nil
    end

    local cache = stringToTable(stateData)
    if cache then
        NW.log("Cache","Cache loaded: " .. #cache.cuts .. " cuts, " .. #cache.processed_ranges .. " ranges")
    else
        NW.log("Cache","Cache deserialization failed")
    end

    return cache
end

---Save cache for a video to project ExtState
---@param project ReaProject The project to save to
---@param videoPath string Path to video file
---@param cacheData table Cache data to save
---@return boolean success
function VideoCutCache.save(project, videoPath, cacheData)
    if not project or not videoPath or not cacheData then
        NW.log("Cache","Save failed: missing parameters")
        return false
    end

    local key = getCacheKey(videoPath)
    local serialized = tableToString(cacheData)

    NW.log("Cache","Saving cache: " .. #cacheData.cuts .. " cuts, " .. #cacheData.processed_ranges .. " ranges")
    reaper.SetProjExtState(project, EXTSTATE_SECTION, key, serialized)
    return true
end

---Create a new empty cache entry
---@param videoPath string Path to video file
---@param threshold number Scene detection threshold
---@param downscaleWidth number Downscale width (0 = disabled)
---@param fps number Video frames per second
---@return table New cache entry
function VideoCutCache.createNew(videoPath, threshold, downscaleWidth, fps)
    return {
        video_path = videoPath,
        cuts = {},
        processed_ranges = {},
        settings = {
            threshold = threshold,
            downscale_width = downscaleWidth,
            fps = fps
        },
        last_updated = os.time()
    }
end

---Check if a cache entry is valid (settings match, file not modified)
---@param cache table Cache entry
---@param threshold number Current threshold
---@param downscaleWidth number Current downscale width
---@return boolean valid
function VideoCutCache.isValid(cache, threshold, downscaleWidth)
    if not cache or not cache.settings then
        NW.log("Cache","Cache invalid: missing cache or settings")
        return false
    end

    -- Check if settings match (FPS is inherent to video and doesn't invalidate cache)
    if cache.settings.threshold ~= threshold or
       cache.settings.downscale_width ~= downscaleWidth then
        NW.log("Cache","Cache invalid: settings mismatch (thresh=" .. cache.settings.threshold .. " vs " .. threshold ..
            ", scale=" .. cache.settings.downscale_width .. " vs " .. downscaleWidth .. ")")
        return false
    end

    NW.log("Cache","Cache valid")
    return true
end

---Check if a time range is already processed (uses SourceTime)
---@param cache table Cache entry
---@param startSourceTime SourceTime Start time in source time
---@param endSourceTime SourceTime End time in source time
---@return boolean cached
function VideoCutCache.isRangeCached(cache, startSourceTime, endSourceTime)
    if not cache or not cache.processed_ranges then
        return false
    end

    NW.log("Cache",tableToString(cache.processed_ranges))
    

    for _, range in ipairs(cache.processed_ranges) do
        NW.log("Cache", tostring(range[2]))
        NW.log("Cache", tostring(endSourceTime))
        NW.log("Cache", "?")
        if range[1] <= startSourceTime and range[2] >= endSourceTime then
            NW.log("Cache",string.format("Range %.1f-%.1f source time cached (found in %.1f-%.1f)",
                startSourceTime, endSourceTime, range[1], range[2]))
            return true
        end
    end

    NW.log("Cache",string.format("Range %.1f-%.1f source time NOT cached", startSourceTime, endSourceTime))
    return false
end

---Get cuts within a time range (uses SourceTime)
---@param cache table Cache entry
---@param startSourceTime SourceTime Start time in source time
---@param endSourceTime SourceTime End time in source time
---@return table Array of cut timestamps in SourceTime
function VideoCutCache.getCutsInRange(cache, startSourceTime, endSourceTime)
    if not cache or not cache.cuts then
        return {}
    end

    local cuts = {}
    for _, timestamp in ipairs(cache.cuts) do
        if timestamp >= startSourceTime and timestamp <= endSourceTime then
            table.insert(cuts, timestamp)
        end
    end

    return cuts
end

---Merge overlapping or adjacent ranges
---@param ranges table Array of {start, end} ranges
local function mergeRanges(ranges)
    if #ranges <= 1 then
        return
    end

    -- Sort by start time
    table.sort(ranges, function(a, b) return a[1] < b[1] end)

    local merged = {}
    local current = ranges[1]

    for i = 2, #ranges do
        local range = ranges[i]
        -- If ranges overlap or are adjacent (within 1 second)
        if range[1] <= current[2] + 1 then
            -- Merge by extending current range
            current[2] = math.max(current[2], range[2])
        else
            -- No overlap, save current and move to next
            table.insert(merged, current)
            current = range
        end
    end

    table.insert(merged, current)

    -- Replace original ranges with merged ones
    for i = #ranges, 1, -1 do
        table.remove(ranges, i)
    end
    for _, range in ipairs(merged) do
        table.insert(ranges, range)
    end
end

---Add new cuts to cache (all values in SourceTime)
---@param cache table Cache entry
---@param newCuts table Array of new cut timestamps in SourceTime
---@param rangeStartSourceTime SourceTime Start of processed range
---@param rangeEndSourceTime SourceTime End of processed range
function VideoCutCache.addCuts(cache, newCuts, rangeStartSourceTime, rangeEndSourceTime)
    if not cache then
        return
    end

    -- Add new cuts (avoiding duplicates)
    local addedCount = 0
    for _, cut in ipairs(newCuts) do
        local exists = false
        for _, existing in ipairs(cache.cuts) do
            if math.abs(existing - cut) < 0.01 then -- within 10ms
                exists = true
                break
            end
        end
        if not exists then
            table.insert(cache.cuts, cut)
            addedCount = addedCount + 1
        end
    end

    -- Sort cuts
    table.sort(cache.cuts)

    -- Add processed range
    NW.log("Cache",string.format("Adding range %.1f-%.1f source time to processed_ranges", rangeStartSourceTime, rangeEndSourceTime))
    table.insert(cache.processed_ranges, {rangeStartSourceTime, rangeEndSourceTime})
    mergeRanges(cache.processed_ranges)

    NW.log("Cache",string.format("After merge: %d ranges, added %d new cuts", #cache.processed_ranges, addedCount))
    for i, range in ipairs(cache.processed_ranges) do
        NW.log("Cache",string.format("  Range %d: %.1f-%.1f", i, range[1], range[2]))
    end

    cache.last_updated = os.time()
end

---Delete cache for a video
---@param project ReaProject The project
---@param videoPath string Path to video file
function VideoCutCache.delete(project, videoPath)
    if not project or not videoPath then
        return
    end

    local key = getCacheKey(videoPath)
    reaper.SetProjExtState(project, EXTSTATE_SECTION, key, "")
end

---Find all uncached gaps in the video
---@param cache table Cache entry
---@param sourceLengthSeconds number Total length of source video
---@return table Array of gaps {start, end}, sorted by position
function VideoCutCache.findAllGaps(cache, sourceLengthSeconds)
    if not cache or not cache.processed_ranges or #cache.processed_ranges == 0 then
        -- No cache at all, entire video is a gap
        return {{0, sourceLengthSeconds}}
    end

    local gaps = {}
    local ranges = cache.processed_ranges

    -- Sort ranges by start position (should already be sorted from mergeRanges, but be safe)
    table.sort(ranges, function(a, b) return a[1] < b[1] end)

    -- Check for gap at the beginning
    if ranges[1][1] > 0 then
        table.insert(gaps, {0, ranges[1][1]})
    end

    -- Check for gaps between ranges
    for i = 1, #ranges - 1 do
        local currentEnd = ranges[i][2]
        local nextStart = ranges[i + 1][1]
        if currentEnd < nextStart then
            table.insert(gaps, {currentEnd, nextStart})
        end
    end

    -- Check for gap at the end
    if ranges[#ranges][2] < sourceLengthSeconds then
        table.insert(gaps, {ranges[#ranges][2], sourceLengthSeconds})
    end

    return gaps
end

---Select the nearest gap to the cursor for background filling
---Prioritizes gaps that end after (or include) cursor, then gaps before cursor
---@param gaps table Array of gaps {start, end}
---@param cursorSourceTime number Current cursor position in SourceTime
---@param maxChunkSize number Maximum chunk size in seconds
---@return table|nil Selected gap {start, end}, limited to maxChunkSize, or nil if no gaps
function VideoCutCache.selectNearestGap(gaps, cursorSourceTime, maxChunkSize)
    if not gaps or #gaps == 0 then
        return nil
    end

    -- First priority: gaps that end after cursor (includes gaps containing cursor)
    -- These are "forward" gaps - we want the one that starts earliest
    local bestForwardGap = nil
    local bestForwardStart = math.huge

    for _, gap in ipairs(gaps) do
        if gap[2] > cursorSourceTime and gap[1] < bestForwardStart then
            bestForwardGap = gap
            bestForwardStart = gap[1]
        end
    end

    if bestForwardGap then
        -- Limit the gap to maxChunkSize, starting from max(gap start, cursor)
        local chunkStart = math.max(bestForwardGap[1], cursorSourceTime)
        local chunkEnd = math.min(bestForwardGap[2], chunkStart + maxChunkSize)
        return {chunkStart, chunkEnd}
    end

    -- Second priority: gaps that end before cursor (backward gaps)
    -- We want the one that ends latest (closest to cursor)
    local bestBackwardGap = nil
    local bestBackwardEnd = -math.huge

    for _, gap in ipairs(gaps) do
        if gap[2] <= cursorSourceTime and gap[2] > bestBackwardEnd then
            bestBackwardGap = gap
            bestBackwardEnd = gap[2]
        end
    end

    if bestBackwardGap then
        -- Limit the gap to maxChunkSize, ending at min(gap end, cursor)
        local chunkEnd = math.min(bestBackwardGap[2], cursorSourceTime)
        local chunkStart = math.max(bestBackwardGap[1], chunkEnd - maxChunkSize)
        return {chunkStart, chunkEnd}
    end

    return nil
end

---Get the next uncached range for background filling
---Prioritizes gaps forward from cursor, then backward from cursor
---Returns chunks up to maxChunkSize, respecting existing cached ranges
---@param cache table Cache entry
---@param cursorSourceTime number Current cursor position in SourceTime
---@param sourceLengthSeconds number Total length of source video
---@param maxChunkSize number Maximum chunk size in seconds (e.g., 60)
---@return table|nil Range {startSourceTime, endSourceTime} or nil if fully cached
function VideoCutCache.getNextUncachedRange(cache, cursorSourceTime, sourceLengthSeconds, maxChunkSize)
    -- Find all gaps in the cache
    local gaps = VideoCutCache.findAllGaps(cache, sourceLengthSeconds)

    -- Select the nearest gap to cursor
    local selectedGap = VideoCutCache.selectNearestGap(gaps, cursorSourceTime, maxChunkSize)

    if selectedGap then
        NW.log("Cache",string.format("Found gap: %.1f-%.1fs", selectedGap[1], selectedGap[2]))
        return selectedGap
    end

    -- No gaps found, fully cached
    NW.log("Cache","Video fully cached")
    return nil
end

return VideoCutCache
