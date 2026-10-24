-- @description Select the tracks that do nothing in the cue (muted, or no items and no routing), skipping tracks already archived
-- @author Jonathan Kawchuk (generated with Claude)
-- Selection only: nothing is archived or deleted.
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")
local region, why = export.cue_region()
if not region then return reaper.ShowMessageBox(why, "Unused tracks", 0) end
local unused, archived = export.unused_tracks(region, false)
export.select_and_report(unused, "Unused tracks (excluding archived)",
    string.format("Unused in this cue, not archived. (%d more unused tracks are already archived and were skipped.)\nNothing was archived or deleted.", archived))
