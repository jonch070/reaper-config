-- @noindex

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "makeWurlieNotesEighthNotesAndPutThemCloserTogether"
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

function lengthOfOneBar()
	return lengthOfQuarterNote() * 4
end

function lengthOfOneMilliSecond()
	return 0.001
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

function getNumberOfSelectedItems()
	return reaper.CountSelectedMediaItems(activeProjectIndex)
end

function getArrayOfItems()

	local arrayOfItems = {}

	local numberOfSelectedItems = getNumberOfSelectedItems()

	for i = 0, numberOfSelectedItems - 1 do
		arrayOfItems[i] = reaper.GetSelectedMediaItem(activeProjectIndex, i)
	end

	return arrayOfItems
end

--

startUndoBlock()

	local items = getArrayOfItems()

	local noteIndex = 0
	local trackIndex = 0
	local previousTrackName = "labels"

	for i = 0, #items do

		local trackOfItem = reaper.GetMediaItem_Track(items[i])
		local _, trackName = reaper.GetTrackName(trackOfItem)

		if trackName ~= previousTrackName then
			noteIndex = 0
			trackIndex = trackIndex + 1
			previousTrackName = trackName
		end

		local itemPosition = reaper.GetMediaItemInfo_Value(items[i], "D_POSITION")
		reaper.SetMediaItemInfo_Value(items[i], "D_LENGTH", lengthOfEighthNote() + 5*lengthOfOneMilliSecond())
		reaper.SetMediaItemInfo_Value(items[i], "D_FADEOUTLEN", 5*lengthOfOneMilliSecond())

		local fadeOutShape = 4
		reaper.SetMediaItemInfo_Value(items[i], "C_FADEOUTSHAPE", fadeOutShape)

		if noteIndex ~= 0 then
			reaper.SetMediaItemInfo_Value(items[i], "D_POSITION", itemPosition + noteIndex * (-12*lengthOfOneBar() + lengthOfEighthNote() + lengthOfQuarterNote()))
		end

		noteIndex = noteIndex + 1
	end

	--

endUndoBlock()