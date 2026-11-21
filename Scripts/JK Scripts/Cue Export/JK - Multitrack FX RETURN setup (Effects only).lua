-- @description Unmute and select the Effects folder (source 128) for the FX RETURN render
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").multitrack_setup("fx")
