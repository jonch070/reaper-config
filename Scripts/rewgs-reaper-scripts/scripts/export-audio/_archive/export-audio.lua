function create_named_audio_click_track()
    local new_name = "Click"

    -- 'Insert click source' (i.e. print click to audio)
    reaper.Main_OnCommand(40013, 0)
  
    -- 'Track: Select all tracks'
    reaper.Main_OnCommand(40296, 0)

    local total_num_tracks = reaper.CountTracks(0)
    local num_selected_tracks = reaper.CountSelectedTracks(0)

    for i = 0, num_selected_tracks - 1 do
        local selected_track = reaper.GetSelectedTrack(0, i)
        local has_name, track_name = reaper.GetTrackName(selected_track)

        if track_name == "Track " .. tostring(total_num_tracks) then
            reaper.GetSetMediaTrackInfo_String(selected_track, "P_NAME", new_name, true)
        end
    end
end


function main()
    -- Transport: Stop
    reaper.Main_OnCommand(1016, 0)

    -- 'Script: Track Visibility - Show all tracks.lua'
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSdf5deea70710b2bb6a464cbab98fb628980c0ab1"), 0)
    
    -- 'Item: Select all items'
    reaper.Main_OnCommand(40182, 0)
    
    -- 'Time selection: Set time selection to items'
    reaper.Main_OnCommand(40290, 0)

    create_named_audio_click_track()

    -- 'Script: Track Visibility - Show only tracks with items.lua'
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS18025988e0ed4e2830abe9a10d91e47698d54b71"), 0)

    -- Track: Unselect (clear selection of) all tracks
    reaper.Main_OnCommand(40297, 0)

    -- Item: Unselect (clear selection of) all items
    reaper.Main_OnCommand(40289, 0)

    -- Transport: Go to start of project
    reaper.Main_OnCommand(40042, 0)
end


main()
