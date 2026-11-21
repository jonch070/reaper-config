-- @description Build a mix session from the cues' WET multitrack stems (appends to the open project)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_mixbuild.lua").pick("WET")
