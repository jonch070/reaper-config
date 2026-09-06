-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "increaseMonitoringVolume"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function addPurestGainToMonitoringFxChainIfItDoesNotExist(masterTrack)

	local alwaysCreateANewEffect = -1
	local onlyQueryTheFirstInstanceOfTheEffect = 0
	local onlyAddAnInstanceIfEffectIsNotFound = 1
	local recFX = true

	reaper.TrackFX_AddByName(masterTrack, "PurestGain", recFX, onlyAddAnInstanceIfEffectIsNotFound)
end

startUndoBlock()

	local masterTrack = reaper.GetMasterTrack(activeProjectIndex)
	addPurestGainToMonitoringFxChainIfItDoesNotExist(masterTrack)

	local fxIndex = 0
	local parameterIndex = 0
	local currentGainValue = reaper.TrackFX_GetParamNormalized(masterTrack, fxIndex|0x1000000, parameterIndex)
	local halfDbIncrement = 0.00625

	local newGainValue = string.format("%.6f", currentGainValue + halfDbIncrement)
	reaper.TrackFX_SetParamNormalized(masterTrack, fxIndex|0x1000000, parameterIndex, newGainValue)

endUndoBlock()
