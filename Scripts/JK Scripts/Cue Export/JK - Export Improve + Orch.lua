-- @description Export both the IMPROVE and ORCH packages for the cue in one go
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "improve", "orch" } }
