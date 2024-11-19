dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")

function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()
    local action_name = 'rewgs - export skinny stems'

    local parsed_project_name = parse_project_name()
    local exports_folder = parsed_project_name.exports_folder_name
    local dst_dir = "./exports/" .. exports_folder .. "/renders/" .. "mixes"

    set_bounds_to_items {}
    local success = render_mix(rt_master_mp3, dst_dir)

    reaper.Undo_EndBlock(action_name, -1)

    if success ~= true then
        -- TODO: This is temporary. Handle this better.
        reaper.ShowConsoleMsg("There was a problem printing.")
    end

    return true
end

main()
-- reaper.Main_OnCommand(40004, 0) -- closes Reaper
