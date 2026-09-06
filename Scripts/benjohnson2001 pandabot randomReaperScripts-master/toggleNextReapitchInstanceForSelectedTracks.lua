-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "toggleNextReapitchInstanceForSelectedTracks"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function trackHasReapitch(track)
	return reaper.TrackFX_GetByName(track, "ReaPitch", false) ~= -1
end

startUndoBlock()

	local numberOfTracks = reaper.CountSelectedTracks(activeProjectIndex)

	for i = 0, numberOfTracks-1 do
		
		local track = reaper.GetSelectedTrack(activeProjectIndex, i)

		if trackHasReapitch(track) then

			local numberOfFxInstances = reaper.TrackFX_GetCount(track)
			local trackHasBeenNotProcessed = true

			for j = 0, numberOfFxInstances-1 do
				
				local _, fxName = reaper.TrackFX_GetFXName(track, j, "")

				if fxName == "VST: ReaPitch (Cockos)" and reaper.TrackFX_GetEnabled(track, j) and trackHasBeenNotProcessed then
					reaper.TrackFX_SetEnabled(track, j, false)
					reaper.TrackFX_SetEnabled(track, j+1, true)
					trackHasBeenNotProcessed = false
				end
			end

			 
		end
	end

endUndoBlock()