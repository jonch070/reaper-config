-- @description Undo the multitrack setup: unmute Effects, restore master sends
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local n = dofile(script_path .. "jk_export.lua").multitrack_reset()
reaper.ShowMessageBox(n .. " track settings restored.", "Multitrack reset", 0)
