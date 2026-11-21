-- @description IMPROVE + ORCH exports plus the multitrack references (MASTER REF, CLICK, tempo map, MIDI); no multitrack stems
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "improve", "orch", "multitrack_dry" }, multitrack_no_stems = true }
