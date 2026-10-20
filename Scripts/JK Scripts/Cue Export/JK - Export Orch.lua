-- @description Export REC/TR-marked tracks: stems + MIDI + master + mix minus for the cue
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "orch" } }
