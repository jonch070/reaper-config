-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "increaseVocalVolume"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function addPurestGainToEndOfTrack(track, indexOfLastFxInstance)

	-- If instantiate is <= -1000, it is used for the insertion position (-1000 is first item in chain, -1001 is second, etc)
	local instantiate = -1000 - indexOfLastFxInstance - 1
	local recFX = false

	reaper.TrackFX_AddByName(track, "PurestGain", recFX, instantiate)
end



startUndoBlock()

	local numberOfTracks = reaper.CountTracks(activeProjectIndex)

	for i = 0, numberOfTracks-1 do
		
		local track = reaper.GetTrack(activeProjectIndex, i)
		local _, trackName = reaper.GetTrackName(track)

		if string.match(string.lower(trackName), "vocal") then
			
			local numberOfFxInstances = reaper.TrackFX_GetCount(track)
			local indexOfLastFxInstance = numberOfFxInstances - 1
			local _, fxNameOfLastFxInstance = reaper.TrackFX_GetFXName(track, indexOfLastFxInstance, "")

			if not string.match(fxNameOfLastFxInstance, "PurestGain") then
				addPurestGainToEndOfTrack(track, indexOfLastFxInstance)
				numberOfFxInstances = reaper.TrackFX_GetCount(track)
				indexOfLastFxInstance = numberOfFxInstances - 1
			end

			local parameterIndex = 0
			local currentGainValue = reaper.TrackFX_GetParamNormalized(track, indexOfLastFxInstance, parameterIndex)
			local halfDbIncrement = 0.00625

			local newGainValue = string.format("%.6f", currentGainValue + halfDbIncrement)
			reaper.TrackFX_SetParamNormalized(track, indexOfLastFxInstance, parameterIndex, newGainValue)
		end
	end

endUndoBlock()
