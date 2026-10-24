-- @description Write only the multitrack tempo map and all-tracks MIDI file for the cue (no rendering)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "multitrack_dry" }, midi_only = true }
