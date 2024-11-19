dofile(reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua")

-- https://forums.cockos.com/showthread.php?t=267360
-- https://github.com/mavriq-dev/Mavriq-Lua-Batteries
-- ReaPack repo: https://raw.githubusercontent.com/mavriq-dev/public-reascripts/master/index.xml
dofile(reaper.GetResourcePath() .. "/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Batteries/batteries_header.lua")
-- FIXME: for some reason the following line is crashing Reaper???
-- local lfs = require("lfs")

-- OLD way of importing my own modules
-- This is a function that enables single-line, relative path imports of other lua files.
-- Written by Xenakios in this thread: https://forums.cockos.com/showthread.php?t=174073
-- local function reaDoFile(file)
--     local info = debug.getinfo(1, 'S')
--     local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]] -- should this not be local?
--     dofile(script_path .. file)
-- end
-- reaDoFile("modules/file-hierarchy.lua")
-- reaDoFile("modules/helper-functions.lua")
-- reaDoFile("modules/render-tables.lua")
-- reaDoFile("modules/render-functions.lua")

-- NEW way of importing my own modules
dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")


local project_name_delimiter = " - "
-- local project_name = reaper.GetProjectName(0)
-- local project_path = get_current_project_path() -- full path, including .rpp project name
-- local project_dir = get_current_project_path():gsub(project_name, "") -- full path, minus .rpp project name
local file_naming_convention = "$project - $starttc"


-- This script will create a folder called "exports." This table defines which delivery folders
-- are inside of it, and what assets they will contain.
-- Sub-tables will be folders (e.g. client, orchestration), and strings are asset export jobs.
local deliveries_old = {
    archive = {
        "all_tracks_dry",
        "all_tracks_wet",
        "click",
        "master_mp3",
        "master_wav",
        "midi_track",
        "track_templates",
        "video"
    },
    client = {
        "master_mp3",
        "master_wav",
        "video"
    },
    engineer = {
        "click",
        "master_mp3",
        "master_wav",
        "midi_tempo_track_only",
        "wide_stems"
    },
    mx_edit = {
        "click",
        "master_mp3",
        "master_wav",
        "midi_tempo_track_only",
        "wide_stems"
    },
    orchestration = {
        "click",
        "master_mp3",
        "master_wav",
        "midi_orch_tracks_only",
        "skinny_stems"
    },
    session_musicians = {
        "click",
        "master_mp3",
        "master_wav",
        "midi_all_tracks",
        "skinny_stems"
    }
}


function export_audio_old(deliveries, file_naming_convention)
    for recipient, jobs in pairs(deliveries) do
        local dst_dir = "./exports/" .. tostring(recipient)
        for i, job in ipairs(jobs) do
            -- if job == "click" then
            -- FIXME:
            -- need render job for this
            -- need to mute click for all other jobs
            -- need to export not to /stems/ dir, instead needs to be on same level as mixes
            -- create_named_audio_click_track()
            if job == "master_wav" then
                render_master_wav(dst_dir, file_naming_convention)
            elseif job == "master_mp3" then
                render_master_mp3(dst_dir, file_naming_convention)
            elseif job == "skinny_stems" then
                dst_dir = "./deliveries/" .. tostring(recipient) .. "/stems/"
                render_skinny_stems(recipient, dst_dir, file_naming_convention)
                -- elseif job == "wide_stems" then
                --     dst_dir = "./deliveries/" .. tostring(recipient) .. "/stems/"
                --     render_wide_stems(recipient, dst_dir, file_naming_convention)
            end
            -- elseif job == "video" then render_video(dst_dir) then
        end
    end
end

function render_assets(all_tracks, project_name_object)
    local dst_dir = "./exports/" .. project_name_object.exports_folder_name .. "/renders/"
    -- local dst_dir = "./all-renders/" .. project_name .. "/"
    local renders = {
        -- render(all_tracks_dry, dst_dir, file_naming_convention),
        -- render(all_tracks_wet, dst_dir, file_naming_convention),
        -- render(click, dst_dir, file_naming_convention),
        render_mix(rt_master_mp3, dst_dir, file_naming_convention),
        render_mix(rt_master_wav, dst_dir, file_naming_convention),
        render_stems(get_skinny_stems(all_tracks), rt_stems, dst_dir, file_naming_convention),
        render_stems(get_wide_stems(all_tracks), rt_stems, dst_dir, file_naming_convention),
        -- render_regions(get_unmuted_regions(all_tracks), rt_regions, dst_dir, file_naming_convention),
        -- render(video, dst_dir, file_naming_convention)
    }

    -- `job` represents the current element of the table being looped over;
    -- lua allows you to call it by adding `()` if the element is a function
    for i, job in ipairs(renders) do
        job()
    end
end

function package_deliveries(project_dir)
    -- This function copies any renders made by render_assets() and copies them to the appropriate
    -- folder, i.e. we can define who gets what and collect everything they need.
    --
    -- TODO:
    -- Zip folders.
    -- Copy to Dropbox folder.

    local deliveries = {
        client = {
            "master_mp3",
            "master_wav",
            -- "video"
        },
        -- collaborators = {
        --     "",
        -- }
        engineer = {
            -- "click",
            "master_mp3",
            "master_wav",
            -- "midi_tempo_track_only",
            -- "wide_stems"
        },
        mx_edit = {
            "click",
            "master_mp3",
            "master_wav",
            "all_regions",
            -- "midi_tempo_track_only",
            -- "wide_stems"
        },
        orchestration = {
            -- "click",
            "master_mp3",
            "master_wav",
            -- "midi_orch_tracks_only",
            -- "skinny_stems"
        },
        session_musicians = {
            -- "click",
            "master_mp3",
            "master_wav",
            -- "midi_all_tracks",
            -- "skinny_stems"
        }
    }

    -- TODO: check if exists
    local deliveries_dir = project_dir .. "/deliveries/"
    lfs.mkdir(deliveries_dir)

    for recipient, assets in pairs(deliveries) do
        -- TODO: check if exists
        local dst_dir = deliveries_dir .. tostring(recipient)
        lfs.mkdir(dst_dir)
    end

    -- TODO: pick up here!
    -- for i, asset in ipairs(delivery) do
    -- end
end

function main()
    reaper.Undo_BeginBlock()
    reaper.ClearConsole()
    local action_name = 'rewgs - export all audio deliveries'

    -- NOTE: these are required for anything that follows. Do not delete!
    local all_tracks = get_all_tracks_as_objects()
    local project_name_object = parse_project_name(project_name, project_name_delimiter)

    -- debugging for spitting out regions for mx edit...
    -- for i, track in ipairs(all_tracks) do
    --     if track.num_media_items > 0 then
    --         local media_items = track.unmuted_media_items
    --         if media_items ~= nil then
    --             -- reaper.ShowConsoleMsg(track.name .. "'s unmuted_media_items property is NOT nil!\n")
    --             for i, media_item in ipairs(media_items) do
    --                 for key, value in pairs(media_item) do
    --                     reaper.ShowConsoleMsg("Key: " .. key .. "; value: " .. value .. "\n")
    --                 end
    --             end
    --         else
    --             reaper.ShowConsoleMsg(track.name .. "'s unmuted_media_items property is nil!\n")
    --         end
    --     end
    -- end

    render_assets(all_tracks, project_name_object)

    -- for item in lfs.dir(lfs.currentdir()) do
    --     reaper.ShowConsoleMsg(item)
    -- end
    -- reaper.ShowConsoleMsg(project_dir)
    -- package_deliveries(project_dir)

    reaper.Undo_EndBlock(action_name, -1)
end

main()
-- reaper.Main_OnCommand(40004, 0) -- closes Reaper
