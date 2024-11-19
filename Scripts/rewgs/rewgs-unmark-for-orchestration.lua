function is_child(track)
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then 
        return false 
    else 
        return true 
    end
end


function is_marked(subject, pattern)
    start_index, end_index = string.find(subject, pattern)
    if start_index ~= nil and end_index ~= nil then
        return true
    else
        return false
    end
end


function remote_mark_from_track_name()
    local action_name = 'mark-for-orchestration'
    local mark = '#'

    reaper.Undo_BeginBlock()
    reaper.ClearConsole()

    local num_tracks = reaper.CountSelectedTracks(0)
  
    for i = 0, num_tracks - 1 do
        local selected_track = reaper.GetSelectedTrack(0, i)

        -- avoids folders; only appends `#` to children
        if is_child(selected_track) then
            local has_name, selected_track_name = reaper.GetTrackName(selected_track)
            if is_marked(selected_track_name, mark) then
                local new_name = selected_track_name:gsub(mark .. " ", "")
                reaper.GetSetMediaTrackInfo_String(selected_track, "P_NAME", new_name, true)
            end
        end
    end

    reaper.Undo_EndBlock(action_name, -1)
end

remote_mark_from_track_name()
