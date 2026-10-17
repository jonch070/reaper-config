local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
local V = dofile(dir .. "JK_voices_lib.lua")
local n, ignore_muted = V.prompt_n("Select Nth voice from bottom")
if n then V.select_voice(false, n, ignore_muted) end
