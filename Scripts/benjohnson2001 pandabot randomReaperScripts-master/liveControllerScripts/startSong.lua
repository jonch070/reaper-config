-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "startSong"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function transportRecordAction()

	local commandId = 1013
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

		local numberOfTracks = reaper.CountTracks(activeProjectIndex)

		for i = 0, numberOfTracks-1 do
			
			local track = reaper.GetTrack(activeProjectIndex, i)
			local _, trackName = reaper.GetTrackName(track)

			if string.match(string.lower(trackName), "vocal") then
				-- reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 1.0)
				reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1.0)
			else
				reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 0.0)
			end
		end

		transportRecordAction()
	end

endUndoBlock()
