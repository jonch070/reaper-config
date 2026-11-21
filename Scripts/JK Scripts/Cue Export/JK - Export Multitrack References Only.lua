-- @description Multitrack references only: _MASTER REF, _CLICK, _TEMPO MAP.mid, _MIDI.mid at the top of <project> MULTITRACK/ (no stems, no FX RETURN, no IMPROVE/ORCH)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "multitrack_dry" }, multitrack_no_stems = true }
