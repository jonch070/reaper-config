dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")

function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()
    local action_name = 'rewgs - export tracks to transcribe wet'
    local exports_path = "./exports/" .. parse_project_name().exports_folder_name .. "/renders/"
    local dst_dir = exports_path .. "to transcribe - wet"

    -- gets all tracks marked "to transcribe"
    local tracks_to_transcribe = {}
    for _, track in ipairs(get_all_marked_tracks()) do
        if is_marked(track.name, track_marks.transcribe) then
            -- reaper.ShowConsoleMsg(track.name .. "\n")
            table.insert(tracks_to_transcribe, track)
        end
    end

    -- Remove duplicates from `tracks_to_orchestrate`, if any
    local tracks = remove_duplicates_from_table(tracks_to_transcribe)

    -- ensures that Effects track is unmuted
    for _, track in ipairs(get_all_tracks_as_objects()) do
        if track.name == "Effects" and track.depth == 1 then
            local muted = reaper.SetMediaTrackInfo_Value(track.media_track, "B_MUTE", 0)
        end
    end

    -- TODO: make sure the `misc_text` property of `parsed_project_name` isn't in the name of the resulting assets
    local success = render_stems(tracks, rt_stems, dst_dir)

    reaper.Undo_EndBlock(action_name, -1)

    if success ~= true then
        -- TODO: This is temporary. Handle this better.
        reaper.ShowConsoleMsg("There was a problem printing.")
    end

    return true
end

main()
-- reaper.Main_OnCommand(40004, 0) -- closes Reaper
