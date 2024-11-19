-- Get the number of selected items
local itemCount = reaper.CountSelectedMediaItems(0)

-- Function to handle time-stretching for a single item
local function stretchItemToNext(item)
    local track = reaper.GetMediaItem_Track(item)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemIndex = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    local nextItem = nil
    local j = itemIndex + 1

    -- Find the next item on the track
    while true do
        local testItem = reaper.GetTrackMediaItem(track, j)
        if not testItem then break end -- No more items

        local nextItemPosition = reaper.GetMediaItemInfo_Value(testItem, "D_POSITION")
        if nextItemPosition > itemStart then
            nextItem = testItem
            break
        end
        j = j + 1
    end

    -- Stretch the current item to the start of the next item
    if nextItem then
        local nextItemStart = reaper.GetMediaItemInfo_Value(nextItem, "D_POSITION")
        reaper.SetEditCurPos(nextItemStart, false, false)
        reaper.Main_OnCommand(40513, 0)  -- Time-stretch selected area of items to edit cursor
    end
end

-- Prepare to time-stretch items
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    reaper.SetOnlyTrackSelected(track) -- Ensure only the current track is selected
    reaper.Main_OnCommand(40289, 0)  -- Unselect all items
    reaper.SetMediaItemSelected(item, true)  -- Select the current item
    stretchItemToNext(item)
end

-- Restore selection and update
reaper.Main_OnCommand(40297, 0)  -- Unselect all tracks
for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    reaper.SetMediaItemSelected(item, true)  -- Restore item selection
end
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Stretch selected items to next items", -1)
reaper.UpdateArrange()


