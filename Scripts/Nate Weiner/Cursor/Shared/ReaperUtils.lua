-- ReaperUtils.lua - General REAPER API utilities
-- Author: Nate Weiner (https://nateweiner.com)

---@class ReaperUtils
local ReaperUtils = {}

---Find a command ID by searching for a pattern in action names
---@param pattern string Lua pattern to match against action names (e.g. "MyScript%.lua" or "VideoCut")
---@param sectionID integer? Section to search (default: 0 for Main). See SectionFromUniqueID docs for values.
---@return integer|nil commandID The command ID (integer) if found, nil otherwise
---@return string|nil commandIDString The named command ID string (e.g. "_RS123...") if found, nil otherwise
function ReaperUtils.findActionByName(pattern, sectionID)
    sectionID = sectionID or 0  -- Default to Main section

    local section = reaper.SectionFromUniqueID(sectionID)
    if not section then
        return nil, nil
    end

    local idx = 0
    while true do
        local cmdID, name = reaper.kbd_enumerateActions(section, idx)
        if cmdID == 0 then
            break  -- No more actions
        end

        if name and name:match(pattern) then
            -- Found it! Get the named command ID string
            local namedID = reaper.ReverseNamedCommandLookup(cmdID)
            local commandIDString = nil
            if namedID and namedID ~= "" then
                commandIDString = "_" .. namedID
            end
            return cmdID, commandIDString
        end

        idx = idx + 1
    end

    return nil, nil
end

---Execute an action by searching for it by name pattern
---@param pattern string Lua pattern to match against action names
---@param sectionID integer? Section to search (default: 0 for Main)
---@param flag integer? Flag for Main_OnCommand (default: 0)
---@return boolean success True if action was found and executed, false otherwise
function ReaperUtils.Main_OnCommandByName(pattern, sectionID, flag)
    flag = flag or 0
    local cmdID = ReaperUtils.findActionByName(pattern, sectionID)

    if cmdID and cmdID > 0 then
        reaper.Main_OnCommand(cmdID, flag)
        return true
    end

    return false
end

---Common section IDs for convenience
ReaperUtils.SECTION_MAIN = 0
ReaperUtils.SECTION_MAIN_ALT_RECORDING = 100
ReaperUtils.SECTION_MIDI_EDITOR = 32060
ReaperUtils.SECTION_MIDI_EVENT_LIST = 32061
ReaperUtils.SECTION_MIDI_INLINE = 32062
ReaperUtils.SECTION_MEDIA_EXPLORER = 32063

-- ============================================================================
-- PROJECT UTILITIES
-- ============================================================================

---Normalize path for comparison (handles case sensitivity and path separators)
---@param path string Path to normalize
---@return string normalizedPath
local function normalizePath(path)
    -- Convert to lowercase for case-insensitive comparison on macOS/Windows
    -- Replace backslashes with forward slashes for consistency
    local normalized = path:lower():gsub("\\", "/")
    return normalized
end

---Find the parent project that contains the current project as a subproject item
---Searches all open projects to find one that has the given project embedded as a subproject
---@param currentProjectPath string Full path to current project
---@return ReaProject|nil parentProject The parent project if found
function ReaperUtils.findParentProject(currentProjectPath)
    if not currentProjectPath or currentProjectPath == "" then
        return nil
    end

    local normalizedCurrentPath = normalizePath(currentProjectPath)

    -- Enumerate all open projects
    local projIdx = 0
    while true do
        local proj, projPath = reaper.EnumProjects(projIdx)
        if not proj then
            break
        end

        -- Skip the current project itself
        if projPath ~= currentProjectPath then
            -- Search for subproject item matching our current project
            local trackCount = reaper.CountTracks(proj)
            for trackIdx = 0, trackCount - 1 do
                local track = reaper.GetTrack(proj, trackIdx)
                local itemCount = reaper.CountTrackMediaItems(track)

                for itemIdx = 0, itemCount - 1 do
                    local item = reaper.GetTrackMediaItem(track, itemIdx)
                    local take = reaper.GetActiveTake(item)

                    if take then
                        local source = reaper.GetMediaItemTake_Source(take)
                        if source then
                            local sourceFile = reaper.GetMediaSourceFileName(source)
                            local normalizedSourceFile = normalizePath(sourceFile)

                            -- Compare full normalized paths
                            if normalizedSourceFile == normalizedCurrentPath then
                                -- Found parent project containing our subproject
                                return proj
                            end
                        end
                    end
                end
            end
        end

        projIdx = projIdx + 1
    end

    return nil
end

---Check if the current project is a subproject of another open project
---@return boolean isSubproject True if current project is embedded in another open project
---@return ReaProject|nil parentProject The parent project if found
function ReaperUtils.isSubproject()
    local _, currentProjectPath = reaper.EnumProjects(-1)
    if not currentProjectPath or currentProjectPath == "" then
        return false, nil
    end
    local parentProject = ReaperUtils.findParentProject(currentProjectPath)
    return parentProject ~= nil, parentProject
end

return ReaperUtils
