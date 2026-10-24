-- @description Select the tracks that do nothing in the cue (muted, or no items and no routing), archived ones included
-- @author Jonathan Kawchuk (generated with Claude)
-- Selection only: nothing is archived or deleted.
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")
local region, why = export.cue_region()
if not region then return reaper.ShowMessageBox(why, "Unused tracks", 0) end
local unused, archived = export.unused_tracks(region, true)
export.select_and_report(unused, "Unused tracks (including archived)",
    string.format("Unused in this cue, archived tracks included (%d of them are archived).\nNothing was archived or deleted.", archived))
