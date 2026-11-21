-- @description Select the multitrack tracks for the cue, mute the Effects folder and apply the dry render preset
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").multitrack_setup("dry")
