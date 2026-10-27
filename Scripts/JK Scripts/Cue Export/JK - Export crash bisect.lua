-- @description Crash bisect: each run applies one more render change, then opens the render dialog (do not save the project)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")
local SECTION = "JK_ExportBisect2"
local stage = (tonumber(reaper.GetExtState(SECTION, "stage")) or 0) + 1
if stage > 3 then stage = 1 end
reaper.SetExtState(SECTION, "stage", tostring(stage), true) -- stored first: the next run moves on even after a crash

local region = export.cue_region()
local function set(k, v) reaper.GetSetProjectInfo(0, k, v, true) end
local what = { "render source 524416 + time selection, no tracks selected", "+ the UNMUTED marked tracks selected",
    "+ the MUTED marked tracks selected too" }
export.trace("BISECT stage " .. stage .. ": " .. what[stage])
set("RENDER_SETTINGS", 524416) set("RENDER_BOUNDSFLAG", 2)
if stage >= 2 then
    reaper.Main_OnCommand(40297, 0)
    for _, tr in ipairs(export.marked_tracks(export.jobs.orch.marks)) do
        local muted = reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") == 1
        if (not muted) or stage >= 3 then reaper.SetTrackSelected(tr, true) end
    end
end
export.trace("BISECT stage " .. stage .. " about to open render")
reaper.Main_OnCommand(42230, 0)
export.trace("BISECT stage " .. stage .. " returned")
reaper.ShowMessageBox("Stage " .. stage .. " (" .. what[stage] .. ") did not crash. Run again for the next stage; do not save the project.", "Crash bisect", 0)
