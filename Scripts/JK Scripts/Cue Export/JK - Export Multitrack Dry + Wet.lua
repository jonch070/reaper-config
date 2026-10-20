-- @description Export every lowest-level track via master, dry (Effects muted) then wet
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "multitrack_dry", "multitrack_wet" } }
