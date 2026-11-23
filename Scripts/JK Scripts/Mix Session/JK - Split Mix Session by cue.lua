-- @description Split a combined mix session (.RPP) into one session per cue (the source file is not changed)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_mixsplit.lua").run()
