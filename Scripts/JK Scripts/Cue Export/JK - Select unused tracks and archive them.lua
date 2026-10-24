-- @description Select the unused tracks (not already archived), ask, then archive them with HeDa's Archive External
-- @author Jonathan Kawchuk (generated with Claude)
-- Needs HeDa's Track Inspector running. Save the project as a new version first.
local KIND = "external" -- "global" to use HeDa's Archive Global instead
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")
local region, why = export.cue_region()
if not region then return reaper.ShowMessageBox(why, "Archive unused tracks", 0) end
local unused, archived = export.unused_tracks(region, false)
if #unused == 0 then
    return reaper.ShowMessageBox(string.format("Nothing to archive: no unused tracks that aren't already archived (%d already are).", archived), "Archive unused tracks", 0)
end
reaper.Main_OnCommand(40297, 0)
for _, tr in ipairs(unused) do reaper.SetTrackSelected(tr, true) end
reaper.UpdateArrange()
local names = {}
for i = 1, math.min(#unused, 15) do
    local _, name = reaper.GetTrackName(unused[i])
    names[#names + 1] = "  " .. name
end
if #unused > 15 then names[#names + 1] = string.format("  ... and %d more", #unused - 15) end
local answer = reaper.ShowMessageBox(string.format("Archive these %d unused tracks (%s)?\n\n%s\n\nTheir plugins are unloaded and the tracks are muted. Save a new project version first if you haven't.",
    #unused, KIND, table.concat(names, "\n")), "Archive unused tracks", 4)
if answer == 6 then export.heda_archive(KIND) end
