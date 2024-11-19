-- Export every non-parent/folder track
-- Put in file name: name of skinny stem (i.e. folder track that outputs to Music Sub Mix)

dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")
local p = parse_project_name()

function check_if_ancestor(args)
    local all_tracks = args.all_tracks
    local current_child = args.child
    local potential_ancestor = args.potential_ancestor

    local child_parent_name = get_parent_track_name(current_child.parent)
    if child_parent_name ~= nil then
        if current_child.parent == potential_ancestor.media_track then
            return true
        else
            for _, track in ipairs(all_tracks) do
                if track.media_track == current_child.parent then
                    local new_args = {
                        all_tracks = all_tracks,
                        child = track,
                        potential_ancestor = potential_ancestor,
                    }
                    local retval = check_if_ancestor(new_args)
                    return retval
                end
            end
        end
    end
    return false
end

function get_relatives(all_tracks, children, potential_ancestors)
    local relatives = {}
    for _, c in ipairs(children) do
        for _, p in ipairs(potential_ancestors) do
            local args = {
                all_tracks = all_tracks,
                child = c,
                potential_ancestor = p,
            }
            local retval = check_if_ancestor(args)
            if retval then
                -- reaprint(tostring(retval))
                -- reaprint("\t" .. c.name)
                -- reaprint("\t" .. p.name)
                local relation = { c, p }
                table.insert(relatives, relation)
            end
        end
    end
    return relatives
end

function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()

    local action_name = 'rewgs - export all child tracks - wet'

    local exports_path = "./exports/" .. parse_project_name().exports_folder_name .. "/renders/"
    local export_type = "wet"
    local dst_dir = exports_path .. "multitrack - " .. export_type

    mute_effects()

    local all_tracks = get_all_tracks_as_objects()
    local child_tracks = get_all_child_tracks({ "Movie", "Effects" })
    local skinny_stems = get_skinny_stems(all_tracks)

    -- returns a table of tables
    -- each inner table is a pair of a child track and its skinny stem
    local relatives = get_relatives(all_tracks, child_tracks, skinny_stems)
    -- for _, r in ipairs(relatives) do
    --     reaprint(r[1].name .. ", " .. r[2].name)
    -- end

    -- adds the skinny stem field to each track in child_tracks
    for _, track in ipairs(child_tracks) do
        for _, r in ipairs(relatives) do
            if track.media_track == r[1].media_track then
                -- $skinny stem - $parent - $track - $wet/dry - $project - $starttc
                local skinny_stem_name = r[2].name
                local track_name = track.name:match '^%s*(.*%S)' or '' -- strips trailing and leading whitespace
                local file_name = skinny_stem_name .. names.delimiter
                    .. get_parent_track_name(track.parent) .. names.delimiter
                    .. track_name .. names.delimiter
                    .. export_type .. names.delimiter
                    .. p.project_code .. names.delimiter
                    .. p.cue_number .. names.delimiter
                    .. p.cue_name .. names.delimiter
                    .. p.cue_version .. names.delimiter .. "$starttc"
                -- reaper.ShowConsoleMsg(file_name .. "\n")

                local success = render_multitrack(all_tracks, track, rt_multitrack, dst_dir, file_name)
                if success ~= true then
                    -- TODO: This is temporary. Handle this better.
                    reaper.ShowConsoleMsg("There was a problem printing" .. track.name .. "\n")
                end
            end
        end
    end

    reaper.Undo_EndBlock(action_name, -1)
    -- return true
end

main()
-- reaper.Main_OnCommand(40004, 0) -- closes Reaper
