-- Write first video track's first item name to file
-- Run this as a startup action or background script

function WriteItemNameToFile()
    -- Get first track (index 0)
    local track = reaper.GetTrack(0, 0)

    if track then
        -- Get first item on track
        local item = reaper.GetTrackMediaItem(track, 0)

        if item then
            local take = reaper.GetActiveTake(item)
            if take then
                local source = reaper.GetMediaItemTake_Source(take)
                local filename = reaper.GetMediaSourceFileName(source, "")

                -- Extract just the filename without path
                local name = filename:match("([^/\\]+)$") or filename

                -- Write to file in REAPER resource path
                local filepath = reaper.GetResourcePath() .. "/video_item_name.txt"
                local file = io.open(filepath, "w")
                if file then
                    file:write(name)
                    file:close()
                end
            end
        end
    end

    -- Run continuously
    reaper.defer(WriteItemNameToFile)
end

WriteItemNameToFile()
