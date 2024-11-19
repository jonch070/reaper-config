-- Initialize random seed based on the current time
math.randomseed(reaper.time_precise())

function main()
    -- Count the number of selected items
    local itemCount = reaper.CountSelectedMediaItems(0)
    
    if itemCount == 0 then
        reaper.ShowMessageBox("No items selected.", "Error", 0)
        return
    end

    -- Begin undo block
    reaper.Undo_BeginBlock()
    
    -- Loop through all selected items
    for i = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        
        -- Get the number of tracks
        local trackCount = reaper.CountTracks(0)
        
        if trackCount > 0 then
            -- Generate a random track index
            local randomTrackIndex = math.random(0, trackCount - 1)
            local track = reaper.GetTrack(0, randomTrackIndex)
            
            -- Move the item to the random track
            reaper.MoveMediaItemToTrack(item, track)
        end
    end

    -- End undo block
    reaper.Undo_EndBlock("Randomize Track Assignment", -1)
    
    -- Update the arrangement view
    reaper.UpdateArrange()
end

-- Run the main function
main()

