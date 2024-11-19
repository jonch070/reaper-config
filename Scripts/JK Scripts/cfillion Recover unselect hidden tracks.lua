function enumSelectedTracksReverse()
  local i = reaper.CountSelectedTracks(0)
  return function()
    i = i - 1
    return reaper.GetSelectedTrack(0, i)
  end
end

local TCP = 1 << 9
local MCP = 1 << 10

local modes = {
  ['TCP'        ] = TCP,
  ['MCP'        ] = MCP,
  ['MCP and TCP'] = TCP | MCP,
}

local scriptName = ({reaper.get_action_context()})[2]:match("([^/\\_]+)%.lua$")
local mode = modes[scriptName:match("in (.+)$")]
assert(mode, 'Invalid filename, cannot deduce what to do.')

reaper.Undo_BeginBlock()

for track in enumSelectedTracksReverse() do
  local state = reaper.GetMediaTrackInfo_Value(track, 'I_TCPY') -- Get TCP state in Reaper 6

  if state & mode == mode then
    reaper.SetTrackSelected(track, false)
  end
end

reaper.Undo_EndBlock(scriptName, 1)

