local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "JK_voices_lib.lua").select_voice(false, 1, true)
