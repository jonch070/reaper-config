-- @description Write only the IMPROVE multichannel MIDI file for the cue (no rendering)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "improve" }, midi_only = true }
