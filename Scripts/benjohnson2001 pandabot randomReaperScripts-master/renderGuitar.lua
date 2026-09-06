-- @noindex

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function emptyFunctionToPreventAutomaticCreationOfUndoPoint()
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "renderGuitar"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function currentBpm()
	local timePosition = 0
	return reaper.TimeMap2_GetDividedBpmAtTime(activeProjectIndex, timePosition)
end

function lengthOfQuarterNote()
	return 60/currentBpm()
end

function lengthOfEighthNote()
	return lengthOfQuarterNote()/2
end

function lengthOfSixteenthNote()
	return lengthOfEighthNote()/2
end

function lengthOfThirtySecondNote()
	return lengthOfSixteenthNote()/2
end

function lengthOfPPQInSeconds(arg)
	local numberOfPulsesPerQuarterNote = 960
	return arg*lengthOfQuarterNote()/numberOfPulsesPerQuarterNote
end

function setTimeSelection(startPosition, endPosition)

	local isSet = true
	local isLoop = false
	local allowAutoseek = false
	reaper.GetSet_LoopTimeRange2(activeProjectIndex, isSet, isLoop, startPosition, endPosition, allowAutoseek)
end

----

function thirtyTwoBitsFloatingPoint()
	return 3
end

function largeFilesAreAutoWavSlashWave64()
	return 0
end

function writeBwfIsCheckedAndIncludeProjectFilenameIsUnchecked()
	return 1
end

function doNotIncludeMarkersOrRegions()
	return 0
end

function doNotEmbedTempo()
	-- returning false means tempo will not be embedded
	return false
end

function currentProjectPath()
	return nil
end

function startOfTimeSelection()
	return -2
end

function endOfTimeSelection()
	return -2
end

function doNotOverwriteWithoutAsking()
	-- returning false means it will not overwrite without asking
	return false
end

function closeTheRenderWindowWhenDone()
	return true
end

function silentlyIncreaseTheFilenameIfItAlreadyExists()
	return true
end


function render(fileName)

	local outputPath = "/Users/panda/Desktop/" .. fileName


	local renderConfigurationString = ultraschall.CreateRenderCFG_WAV(thirtyTwoBitsFloatingPoint(),
																																	largeFilesAreAutoWavSlashWave64(),
																																	writeBwfIsCheckedAndIncludeProjectFilenameIsUnchecked(),
																																	doNotIncludeMarkersOrRegions(),
																																	doNotEmbedTempo())

	local secondaryRenderConfigurationString = nil

	ultraschall.RenderProject(currentProjectPath(),
														outputPath,
														startOfTimeSelection(),
														endOfTimeSelection(),
														doNotOverwriteWithoutAsking(),
														closeTheRenderWindowWhenDone(),
														silentlyIncreaseTheFilenameIfItAlreadyExists(),
														renderConfigurationString,
														secondaryRenderConfigurationString)
end


----

local fileName = "wurlieRhythmVerse_"
local fileExtension = ".wav"

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()

	local bufferSpace = lengthOfEighthNote()

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
		local selectedItemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

		local numberOfStems = 32

		for j = 0, numberOfStems - 1 do

			local startPosition = selectedItemPosition-j*lengthOfSixteenthNote()
			-- local startPosition = selectedItemPosition-lengthOfPPQInSeconds(j)
			local endPosition = selectedItemPosition+selectedItemLength + bufferSpace
			setTimeSelection(startPosition, endPosition)

			render(fileName .. tostring(j+1) .. fileExtension)
		end
	end

endUndoBlock()

