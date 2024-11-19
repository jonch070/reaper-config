dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")

local function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()
    local action_name = 'rewgs - export MIDI for orchestration'

    local mark = track_marks.record

    -- File: Save copy of project (automatically increment project name)
    -- reaper.Main_OnCommand(42346, 0)

    -- Get all tracks marked for orchestration
    local tracks_to_export = {}
    for _, track in ipairs(get_all_marked_tracks()) do
        -- Don't need to export MIDI for tracks marked to transcribe, as those are audio tracks.
        -- Leave this here for breadcrumbs in case anything breaks.
        -- if is_marked(track.name, track_marks.record) or is_marked(track.name, track_marks.transcribe) then
        if is_marked(track.name, mark) then
            table.insert(tracks_to_export, track)
        end
    end

    if #tracks_to_export == 0 then
        reaper.ShowConsoleMsg("There are no tracks marked " .. mark .. ". Please try again.")
    else
        -- debug
        -- for _, track in ipairs(tracks_to_export) do
        --     reaper.ShowConsoleMsg(track.name)
        -- end

        -- Remove duplicates from `tracks_to_export`, if any
        local tracks = remove_duplicates_from_table(tracks_to_export)
        -- debug
        -- for _, track in ipairs(tracks) do
        --     reaper.ShowConsoleMsg(track.name)
        -- end

        -- TODO
        -- deactivate humanization MIDI plugins
        -- Item: apply track/take fx to items (midi output)

        -- Check for empty or muted MIDI regions; delete
        -- for _, track in ipairs(tracks) do
            -- reaper.ShowConsoleMsg(track.name)
        --     local items = track.muted_media_items
        --     for _, item in ipairs(items) do
        --         -- FIXME: Why isn't this working?
        --         local deleted = reaper.DeleteTrackMediaItem(track.media_track, item.media_item)
        --         reaper.ShowConsoleMsg(tostring(deleted))
        --     end
        -- end

        set_bounds_to_items {}
        export_marked_tracks(tracks_to_export)

        -- TODO
        -- change the name of the new .rpp -- replace `_1` with ` - to orch` (perhaps replace misc text?)
    end


    reaper.Undo_EndBlock(action_name, -1)
end

main()
