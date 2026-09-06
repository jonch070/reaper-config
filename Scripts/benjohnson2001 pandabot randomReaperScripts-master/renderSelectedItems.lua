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
	local actionDescription = "renderSelectedItems"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

--

local sectionName = "com.pandabot.renderSelectedItems" 

function setValue(key, value)
  reaper.SetProjExtState(activeProjectIndex, sectionName, key, value)
end

function getValue(key, defaultValue)

  local valueExists, value = reaper.GetProjExtState(activeProjectIndex, sectionName, key)

  if valueExists == 0 then
    setValue(key, defaultValue)
    return defaultValue
  end

  return value
end

--

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

function lengthOfSixtyFourthNote()
	return lengthOfThirtySecondNote()/2
end

function lengthOfHundredTwentyEighthNote()
	return lengthOfSixtyFourthNote()/2
end


-----

function unsoloAllTracks()

	local commandId = 40340
  reaper.Main_OnCommand(commandId, 0)
end

function soloTracksOfSelectedItems()

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local trackOfSelectedItem = reaper.GetMediaItem_Track(selectedItem)

		local trackIsMuted = reaper.GetMediaTrackInfo_Value(trackOfSelectedItem, "B_MUTE")
		local trackIsNotMuted = (trackIsMuted == 0.0)

		if trackIsNotMuted then
			reaper.SetMediaTrackInfo_Value(trackOfSelectedItem, "I_SOLO", 1)
		end
	end
end

function maxInt()

	-- I don't know if this is actually the maximum integer value, but it's big enough
	return 2^31 - 1
end

function getStartPosition()

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

	local startPosition = maxInt()

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")

		if selectedItemPosition < startPosition then
			startPosition = selectedItemPosition
		end
	end

	return startPosition
end

function getEndPosition()

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

	local endPosition = -1

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
		local selectedItemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

		if selectedItemPosition + selectedItemLength > endPosition then
			endPosition = selectedItemPosition + selectedItemLength
		end
	end

	return endPosition
end

function setTimeSelection(startPosition, endPosition)

	local isSet = true
	local isLoop = false
	local allowAutoseek = false
	reaper.GetSet_LoopTimeRange2(activeProjectIndex, isSet, isLoop, startPosition, endPosition, allowAutoseek)
end

function getFileNameAndNumberOfTimesToRender()

	local numberOfInputs = 2
	local defaultInputs = getValue("fileName", "") .. "," .. getValue("numberOfTimesToRender", 1)
	local userComplied, userInputs =  reaper.GetUserInputs("render selected items", numberOfInputs, "File name:,number of times to render:,extrawidth=100", defaultInputs)
	fileName, numberOfTimesToRender = userInputs:match("([^,]+),([^,]+)")
	return userComplied, fileName, tonumber(numberOfTimesToRender)
end

-----


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

	local outputPath = "/Users/panda/Desktop/" .. fileName .. ".wav"


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


local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()

	unsoloAllTracks()
	soloTracksOfSelectedItems()
	reaper.UpdateArrange()

	local bufferSpace = lengthOfQuarterNote()
	local userComplied, fileName, numberOfTimesToRender = getFileNameAndNumberOfTimesToRender()

	if userComplied then

		setValue("fileName", fileName)
		setValue("numberOfTimesToRender", numberOfTimesToRender)

		for i = 0, numberOfTimesToRender - 1 do

			local startPosition = reaper.BR_GetClosestGridDivision(getStartPosition() - i*lengthOfEighthNote()) - bufferSpace
			local endPosition = reaper.BR_GetClosestGridDivision(getEndPosition()) + bufferSpace

			setTimeSelection(startPosition, endPosition)
			render(fileName)
		end
	end

endUndoBlock()



	-- print("userComplied: " .. tostring(userComplied))
	-- print("fileName: " .. tostring(fileName))
	-- print("numberOfTimesToRender: " .. tostring(numberOfTimesToRender))
