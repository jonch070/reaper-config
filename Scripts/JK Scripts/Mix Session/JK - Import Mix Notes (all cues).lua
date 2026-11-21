-- @description Import mix notes from every cue session into this session (Picture / Beat / Orch-Mix / Utility tracks)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_mixnotes.lua").run()
