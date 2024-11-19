-- Function to unselect all tracks hidden in both TCP and MCP in Reaper
function unselectHiddenTracks()
    local project = reaper.EnumProjects(-1, "")
    if project then
        local trackCount = reaper.CountTracks(project)

        for i = 0, trackCount - 1 do
            local track = reaper.GetTrack(project, i)
            if track then
                local _, isHiddenTCP = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
                local _, isHiddenMCP = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINMIXER")
                
                if isHiddenTCP == 0 and isHiddenMCP == 0 then
                    reaper.SetTrackSelected(track, false)
                end
            end
        end
    end
end

-- Run the function
unselectHiddenTracks()

