dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")

function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()
    local action_name = 'rewgs - export stems skinny wet'
    local exports_path = "./exports/" .. parse_project_name().exports_folder_name .. "/renders/"
    local stems = get_skinny_stems(get_all_tracks_as_objects())
    local dst_dir = exports_path .. "stems - " .. stems.which .. " - wet"

    -- ensures that Effects track is unmuted
    for _, track in ipairs(get_all_tracks_as_objects()) do
        if track.name == "Effects" and track.depth == 1 then
            local muted = reaper.SetMediaTrackInfo_Value(track.media_track, "B_MUTE", 0)
        end
    end

    set_bounds_to_items {}
    local success = render_stems(stems, rt_stems, dst_dir)

    reaper.Undo_EndBlock(action_name, -1)

    if success ~= true then
        -- TODO: This is temporary. Handle this better.
        reaper.ShowConsoleMsg("There was a problem printing.")
    end

    return true
end

main()
-- reaper.Main_OnCommand(40004, 0) -- closes Reaper
