-- Move selected items to random selected track
-- Each selected item is moved to a randomly chosen track from the selected tracks
-- Author: JK

local function main()
    local trackCount = reaper.CountSelectedTracks(0)
    local itemCount = reaper.CountSelectedMediaItems(0)

    if trackCount < 2 then
        reaper.ShowMessageBox("Select at least 2 tracks to randomize across.", "Move to Random Track", 0)
        return
    end
    if itemCount == 0 then
        reaper.ShowMessageBox("No items selected.", "Move to Random Track", 0)
        return
    end

    local tracks = {}
    for i = 0, trackCount - 1 do
        tracks[i + 1] = reaper.GetSelectedTrack(0, i)
    end

    local items = {}
    for i = 0, itemCount - 1 do
        items[i + 1] = reaper.GetSelectedMediaItem(0, i)
    end

    math.randomseed(os.time())

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for _, item in ipairs(items) do
        local target = tracks[math.random(#tracks)]
        reaper.MoveMediaItemToTrack(item, target)
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Move selected items to random selected track", -1)
end

main()
