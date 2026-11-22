-- @description Orch playalong: just _MASTER, _CLICK and _TEMPO MAP.mid for the cue (no REC/TR marks needed, no stems, mix minus or MIDI parts)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
dofile(script_path .. "jk_export.lua").run { jobs = { "orch_playalong" }, midi = false }
