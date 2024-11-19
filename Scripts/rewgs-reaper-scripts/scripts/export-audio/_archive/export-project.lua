function get_all_track_names()
    local num_tracks = reaper.CountTracks(0)

    local track_names = {}
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track, "")
        table.insert(track_names, track_name)
    end

    return track_names
end


function get_all_track_names_marked_for_orchestration()
    local all_track_names = get_all_track_names()

    local mark = '#'
    local marked = {}
    for i = 1, #all_track_names do
        local track_name = all_track_names[i]
        if is_marked(track_name, mark) then
            table.insert(marked, track_name)
        end
    end

    for i = 1, #marked do
        local m = marked[i]
        reaper.ShowConsoleMsg(m)
    end
end

-- checks if a track is marked for orchestration with `#` 
function is_marked(subject)
    local mark = '#'
    start_index, end_index = string.find(subject, mark)
    if start_index ~= nil and end_index ~= nil then
        return true
    else
        return false
    end
end

function show_only_tracks_marked_for_orchestration()
    local action_name = "Show only tracks marked for orchestration"
    reaper.Undo_BeginBlock()

    local num_tracks = reaper.CountTracks(0)

    local all_tracks = {}
    for i = 0, num_tracks do
        local track = reaper.GetTrack(0, i)
        table.insert(all_tracks, track)
    end

    for i = 0, #all_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)
        if not is_marked(track_name, mark) then
            reaper.SetMediaTrackInfo_Value(track, 'B_SHOWINTCP', 0)
            reaper.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end
    end

    reaper.TrackList_AdjustWindows(1)

    reaper.Undo_EndBlock(action_name, -1)
end


function export_project()
    local num_tracks = reaper.CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track, "")
        -- reaper.ShowConsoleMsg(track_name)
    end
end


function main()
    show_only_tracks_marked_for_orchestration()
end


main()
