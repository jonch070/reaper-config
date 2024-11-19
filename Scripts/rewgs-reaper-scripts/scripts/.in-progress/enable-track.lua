-- FIXME: track enable unmutes all items on the track even if they were muted before it was disabled!


-- command ids
track = {
    -- mute = 40730,
    unmute = 40731,
    -- set_all_fx_offline = 40535,
    set_all_fx_online = 40536,
}


function enable_track()
    reaper.Undo_BeginBlock(1)
    reaper.PreventUIRefresh(1)

    reaper.Main_OnCommand(track.unmute, 0)
    reaper.Main_OnCommand(track.set_all_fx_online, 0)

    local num_tracks = reaper.CountSelectedTracks(0)

    for i = 0, num_tracks - 1 do
        local selected_track = reaper.GetSelectedTrack(0, i)
        local num_items = reaper.CountTrackMediaItems(selected_track, i)

        for j = 0, num_items - 1 do
            item = reaper.GetTrackMediaItem(selected_track, j)
            reaper.SetMediaItemInfo_Value(item, 'C_LOCK', 0)
            reaper.SetMediaItemInfo_Value(item, 'B_MUTE', 0)
        end
    end

    reaper.Undo_EndBlock('enable-track', -1)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
end

enable_track()
