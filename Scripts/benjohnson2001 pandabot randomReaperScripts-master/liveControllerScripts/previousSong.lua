-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "previousSong"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function previousProjectTabAction()

	local commandId = 40862
  reaper.Main_OnCommand(commandId, 0)
end

function songIsPlaying()
	return reaper.GetPlayState() > 0
end

function songIsNotPlaying()
	return (not songIsPlaying())
end

startUndoBlock()

	if songIsNotPlaying() then
		previousProjectTabAction()
	end

endUndoBlock()
