--[[
   * ReaScript Name: Move selected items to individual tracks with matching channels
   * Lua script for Cockos REAPER
   * Author: JK
   * Licence: GPL v3
   * Version: 2.0
   *
   * Moves each selected item to its own new track.
   * New tracks match the source media channel count and are named after the active take.
   * Folder structure rules:
   *   - Source always becomes a folder parent with new tracks as its children
   *   - If source is already a folder parent, new tracks are appended as children
   * Only newly created tracks are affected -- existing tracks are never pulled into folders.
--]]

-- Find the 0-based index of the last child of a folder, and return it plus the
-- depth value of that closing track. Returns (last_child_idx, closing_depth).
local function find_folder_end(folder_idx_0based)
    local total = reaper.CountTracks(0)
    local depth = 1 -- the folder parent contributes +1
    for i = folder_idx_0based + 1, total - 1 do
        local tr = reaper.GetTrack(0, i)
        local d = math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH"))
        depth = depth + d
        if depth <= 0 then
            return i, d
        end
    end
    return folder_idx_0based, 0 -- fallback: no children found
end

function main()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then
        reaper.ShowMessageBox("No items selected.", "Move Items to Individual Tracks", 0)
        return
    end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- 1. Collect item info before making any changes
    local items = {}
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)

        local name = "Unnamed"
        local channels = 2 -- sensible default

        if take then
            local _, tname = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if tname and tname ~= "" then name = tname end

            local source = reaper.GetMediaItemTake_Source(take)
            if source then
                local nch = reaper.GetMediaSourceNumChannels(source)
                if nch > 0 then channels = nch end
            end
        end

        items[#items + 1] = { item = item, name = name, channels = channels }
    end

    -- 2. Determine source track and folder context
    local src_track = reaper.GetMediaItem_Track(items[1].item)
    local src_depth = math.floor(reaper.GetMediaTrackInfo_Value(src_track, "I_FOLDERDEPTH"))
    local src_idx = math.floor(reaper.GetMediaTrackInfo_Value(src_track, "IP_TRACKNUMBER")) - 1 -- 0-based

    local insert_idx   -- 0-based index where first new track will be created
    local last_depth = 0 -- folder depth to assign to the last new track

    if src_depth == 1 then
        -----------------------------------------------------------------
        -- CASE B: Source is already a top-level folder parent.
        -- Append new tracks as children at the end of the existing folder.
        -----------------------------------------------------------------
        local last_child_idx, closing_d = find_folder_end(src_idx)

        if last_child_idx > src_idx then
            -- Existing last child was closing the folder -- remove one level of closing
            -- so our last new track can take over that duty.
            local closing_track = reaper.GetTrack(0, last_child_idx)
            reaper.SetMediaTrackInfo_Value(closing_track, "I_FOLDERDEPTH", closing_d + 1)
            insert_idx = last_child_idx + 1
        else
            -- Folder has no children yet; insert right after the parent.
            insert_idx = src_idx + 1
        end

        last_depth = -1 -- close the folder

    else
        -----------------------------------------------------------------
        -- Source is not already a folder parent.
        -- Make it one; new tracks become its children.
        -- last_depth compensates: changing depth from src_depth to 1
        -- opens (1 - src_depth) extra levels that must be closed.
        -----------------------------------------------------------------
        reaper.SetMediaTrackInfo_Value(src_track, "I_FOLDERDEPTH", 1)
        insert_idx = src_idx + 1
        last_depth = src_depth - 1 -- e.g. was 0 → -1, was -1 → -2
    end

    -- 3. Create new tracks and move items
    for i, info in ipairs(items) do
        local idx = insert_idx + i - 1
        reaper.InsertTrackAtIndex(idx, false)
        local new_track = reaper.GetTrack(0, idx)

        reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", info.name, true)
        reaper.SetMediaTrackInfo_Value(new_track, "I_NCHAN", info.channels)

        -- Only the last new track gets the folder-closing depth
        if i == #items then
            reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", last_depth)
        end
        -- All other new tracks keep the default depth of 0 (normal child)

        reaper.MoveMediaItemToTrack(info.item, new_track)
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Move selected items to individual tracks", -1)
end

main()
