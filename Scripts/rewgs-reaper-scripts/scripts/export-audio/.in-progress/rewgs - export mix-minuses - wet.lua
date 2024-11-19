dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")

function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()
    local action_name = 'rewgs - export mix minuses wet'
    local exports_path = "./exports/" .. parse_project_name().exports_folder_name .. "/renders/"
    local dst_dir = exports_path .. "mix minuses - wet"

    -- ensures that Effects track is unmuted
    for _, track in ipairs(get_all_tracks_as_objects()) do
        if track.name == "Effects" and track.depth == 1 then
            local effects_muted = reaper.SetMediaTrackInfo_Value(track.media_track, "B_MUTE", 0)
        end
    end

    -- FIXME: need to get this to work before moving forward
    -- local children_of_skinny_stems = get_children_of_skinny_stems(get_all_tracks_as_objects())
    -- for i, child in ipairs(children_of_skinny_stems) do
    --     reaper.ShowConsoleMsg(child)
    -- end

    -- Prints a mix minus for each stem
    -- for _, stem in ipairs(stems) do
    --     if stem.num_media_items < 0 then
    --         -- local minus_muted = reaper.SetMediaTrackInfo_Value(track.media_track, "B_MUTE", 1)
    --         local file_name_add = " minus " .. stem.name
    --         reaper.ShowConsoleMsg(file_name_add .. "\n")
    --         -- local success = render_mix_minus(rt_mix_minus, dst_dir, file_name_add)

    --         -- if success ~= true then
    --             -- TODO: This is temporary. Handle this better.
    --             -- reaper.ShowConsoleMsg("There was a problem printing.")
    --         -- end

    --         -- local minus_unmuted = reaper.SetMediaTrackInfo_Value(track.media_track, "B_MUTE", 0)
    --     end
    -- end

    reaper.Undo_EndBlock(action_name, -1)
    -- return true
end

main()
-- reaper.Main_OnCommand(40004, 0) -- closes Reaper
