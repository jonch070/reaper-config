-- @noindex

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
	local actionDescription = "applyRhythmGuitarTimingTricks"
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

function lengthOfSixtyFourthNote()
	return lengthOfThirtySecondNote()/2
end

function lengthOfHundredTwentyEighthNote()
	return lengthOfSixtyFourthNote()/2
end

-----

function getSelectedItems()

	local selectedItems = {}

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

	for i = 0, numberOfSelectedItems - 1 do
		selectedItems[i] = reaper.GetSelectedMediaItem(activeProjectIndex, i)
	end

	return selectedItems
end

function numberIsOdd(arg)
	return arg % 2 ~= 0
end

function numberIsNotAnInteger(arg)
  return arg ~= math.floor(arg)
end

function getNumberOfBars()

	local firstSelectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, 0)
	local trackOfFirstSelectedItem = reaper.GetMediaItem_Track(firstSelectedItem)
	local numberOfItemsOnTrack = reaper.CountTrackMediaItems(trackOfFirstSelectedItem)

	local numberOfSelectedItemsOnTrack = 0

	for i = 0, numberOfItemsOnTrack - 1 do
		local itemOnTrack = reaper.GetTrackMediaItem(trackOfFirstSelectedItem, i)

		if reaper.IsMediaItemSelected(itemOnTrack) then
			numberOfSelectedItemsOnTrack = numberOfSelectedItemsOnTrack + 1
		end
	end

	if numberIsOdd(numberOfSelectedItemsOnTrack) then
		return nil
	end

	local numberOfBars = numberOfSelectedItemsOnTrack / 4

	if numberIsNotAnInteger(numberOfBars) then
		return nil
	end

	return numberOfBars
end

function valueDoesNotExist(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return false
        end
    end

    return true
end

function getTracksOfSelectedItems()

	tracksOfSelectedItems = {}
	trackIndexes = {}

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local trackOfSelectedItem = reaper.GetMediaItem_Track(selectedItem)
		local trackIndex = reaper.GetMediaTrackInfo_Value(trackOfSelectedItem, "IP_TRACKNUMBER")

		if valueDoesNotExist(trackIndexes, trackIndex) then
			table.insert(trackIndexes, trackIndex)
			table.insert(tracksOfSelectedItems, trackOfSelectedItem)
		end
	end



	return tracksOfSelectedItems
end

function getSelectedTrackItems(trackArg)

	local numberOfItemsOnTrack = reaper.CountTrackMediaItems(trackArg)

	local selectedTrackItems = {}

	for i = 0, numberOfItemsOnTrack - 1 do

		local itemOnTrack = reaper.GetTrackMediaItem(trackArg, i)

		if reaper.IsMediaItemSelected(itemOnTrack) then
			table.insert(selectedTrackItems, itemOnTrack)
		end
	end

	return selectedTrackItems
end

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

local numberOfBars = getNumberOfBars()

if numberOfBars == nil then
	print("something went wrong, either:\n\n1. There are an odd number of selected items on the first track\n\nor\n\n2. The number of bars isn't an integer value (for example if it's 1.5 bars")
	return
end

function moveItemToTheLeftOneTwentyEighthNote(itemArg)

	local currentPosition = reaper.GetMediaItemInfo_Value(itemArg, "D_POSITION")
	reaper.SetMediaItemInfo_Value(itemArg, "D_POSITION", currentPosition-lengthOfHundredTwentyEighthNote())
end

function altDragToTheRightOneTwentyEighthNote(itemArg)

	local currentLength = reaper.GetMediaItemInfo_Value(itemArg, "D_LENGTH")
	reaper.SetMediaItemInfo_Value(itemArg, "D_LENGTH", currentLength+lengthOfHundredTwentyEighthNote())


	local takeIndex = 0
	local itemTake = reaper.GetTake(itemArg, takeIndex)
	local currentPlayrate = reaper.GetMediaItemTakeInfo_Value(itemTake, "D_PLAYRATE")

	local originalItemLength = lengthOfEighthNote() + 2*lengthOfHundredTwentyEighthNote()
	local newPlayrate = currentPlayrate * originalItemLength / (originalItemLength + lengthOfHundredTwentyEighthNote())
	reaper.SetMediaItemTakeInfo_Value(itemTake, "D_PLAYRATE", newPlayrate)
end

function applyTimingTricks(firstRowItems, secondRowItems, barIndex)

	local thirdItemInBar = firstRowItems[barIndex*4 + 2]
	local fourthItemInBar = secondRowItems[barIndex*4 + 2]
	local fifthItemInBar = firstRowItems[barIndex*4 + 3]
	local sixthItemInBar = secondRowItems[barIndex*4 + 3]
	local seventhItemInBar = firstRowItems[barIndex*4 + 4]

	moveItemToTheLeftOneTwentyEighthNote(thirdItemInBar)
	moveItemToTheLeftOneTwentyEighthNote(fourthItemInBar)
	moveItemToTheLeftOneTwentyEighthNote(fifthItemInBar)
	moveItemToTheLeftOneTwentyEighthNote(sixthItemInBar)
	moveItemToTheLeftOneTwentyEighthNote(seventhItemInBar)

	altDragToTheRightOneTwentyEighthNote(seventhItemInBar)
end


startUndoBlock()

	local tracksOfSelectedItems = getTracksOfSelectedItems()

	local firstRowItems = getSelectedTrackItems(tracksOfSelectedItems[1])
	local secondRowItems = getSelectedTrackItems(tracksOfSelectedItems[2])
	local thirdRowItems = getSelectedTrackItems(tracksOfSelectedItems[3])
	local fourthRowItems = getSelectedTrackItems(tracksOfSelectedItems[4])
	
	for barIndex = 0, numberOfBars - 1 do

		if numberIsOdd(barIndex) then
			applyTimingTricks(thirdRowItems, fourthRowItems, barIndex)
		else
			applyTimingTricks(firstRowItems, secondRowItems, barIndex)
		end
	end


	reaper.UpdateArrange()
endUndoBlock()






				-- print("j: " .. j)
				-- print("position: " .. tostring(selectedItemPosition))
				-- print("length: " .. tostring(selectedItemLength))
				-- print("\n")
				-- print(lengthOfPPQInSeconds(j))
