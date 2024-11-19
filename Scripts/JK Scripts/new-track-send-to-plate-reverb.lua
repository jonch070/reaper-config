function get_track_num_by_name(track_name)
    local num_tracks = reaper.CountTracks(0)
    local current_track_number = nil

    for i = 0, num_tracks - 1 do
        local current_track = reaper.GetTrack(0, i)
        local _, current_track_name = reaper.GetSetMediaTrackInfo_String(current_track, "P_NAME", "", false)
        current_track_number = reaper.GetMediaTrackInfo_Value(current_track, 'IP_TRACKNUMBER')
      
        if current_track_name == track_name then
            return current_track
        end
    end
end


function insert_new_track_with_send(send_dst)
    if send_dst == nil then
        return
    end

    reaper.Main_OnCommand(40001, 0)

    local num_tracks = reaper.CountTracks(0)
    local num_tracks_w_blank_name = nil

    for i = 0, num_tracks - 1 do
        local current_track = reaper.GetTrack(0, i)
        local _, current_track_name = reaper.GetSetMediaTrackInfo_String(current_track, "P_NAME", "", false)
        local current_track_number = reaper.GetMediaTrackInfo_Value(current_track, 'IP_TRACKNUMBER')
      
        if current_track_name == "" then
            local send_index = reaper.CreateTrackSend(current_track, get_track_num_by_name(send_dst))
            reaper.SetTrackSendInfo_Value(current_track, 0, send_index, "D_VOL", 1.0) -- Set send volume to unity (1.0)
            reaper.SetTrackSendInfo_Value(current_track, 0, send_index, "I_SENDMODE", 0) -- Set send mode to post-fader
            break
        end
    end
end


insert_new_track_with_send("Plate Reverb")


-- -- Main function to handle new track creation
-- function main()
--   local _, _, sectionID, commandID = reaper.get_action_context()
  
--   -- Check if the command is for creating a new track
--   if sectionID == -1 and commandID == reaper.NamedCommandLookup("_SWS_INSNEWTRK") then
--     find_track()
--   else
--     reaper.defer(main)
--   end
-- end

-- Run the main function
-- main()
