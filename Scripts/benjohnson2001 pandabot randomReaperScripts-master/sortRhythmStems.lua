-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "sortStems"
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

function getNumberOfSelectedItems()
	return reaper.CountSelectedMediaItems(activeProjectIndex)
end

function extendByOneHundredTwentyEighthNotes()

	local commandId = reaper.NamedCommandLookup("_RS565b2e47b74342346d72ae0984829d80013cd1fc")
	reaper.Main_OnCommand(commandId, 0)
end

--

function getArrayOfTracks()

	local arrayOfTracks = {}

	local numberOfSelectedItems = getNumberOfSelectedItems()

	for i = 0, numberOfSelectedItems - 1 do
		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		arrayOfTracks[i] = reaper.GetMediaItem_Track(selectedItem)
	end

	return arrayOfTracks
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

function getLongestItemLength(numberOfStems)

	local longestItemLength = -1
	local numberOfSelectedItems = getNumberOfSelectedItems()

	for i = 0, numberOfSelectedItems-1, numberOfStems do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

		if selectedItemLength > longestItemLength then
			longestItemLength = selectedItemLength
		end
	end

	return longestItemLength
end


function alignItems(numberOfStems)

	local numberOfSelectedItems = getNumberOfSelectedItems()
	local longestItemLength = getLongestItemLength(numberOfStems)

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
		local selectedItemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
		local timeShiftAmount = longestItemLength-selectedItemLength

		reaper.SetMediaItemInfo_Value(selectedItem, "D_POSITION", selectedItemPosition+timeShiftAmount)
	end
end


function moveItemsToNewTracks(numberOfStems)

	local numberOfSelectedItems = getNumberOfSelectedItems()
	local stemGroup = 0
	local numberOfStemGroups = math.floor(numberOfSelectedItems/numberOfStems)

	local tracks = getArrayOfTracks()
	local items = getArrayOfItems()

	for trackIndex = 0, #tracks do

		local itemIndex = stemGroup + (trackIndex%numberOfStemGroups)*numberOfStems

		reaper.MoveMediaItemToTrack(items[itemIndex], tracks[trackIndex])

		if ((trackIndex+1) % numberOfStemGroups == 0) then
			stemGroup = stemGroup + 1
		end
	end
end


function addBufferTracks(numberOfStems)

	local tracks = getArrayOfTracks()
	local numberOfSelectedItems = getNumberOfSelectedItems()
	local numberOfStemGroups = math.floor(numberOfSelectedItems/numberOfStems)
	local trackIndexOffset = 0

	for i = 0, #tracks do

--		print(trackIndex)
		if ((i+1) % numberOfStemGroups == 0) then
--print("bam")

			local trackIndex = reaper.GetMediaTrackInfo_Value(tracks[i], "IP_TRACKNUMBER")
			local wantTrackDefaults = true
			reaper.InsertTrackAtIndex(trackIndex, wantTrackDefaults)
			reaper.InsertTrackAtIndex(trackIndex, wantTrackDefaults)
		end
	end
end


function muteSelectedTracks()
	local tracks = getArrayOfTracks()

	for i = 0, #tracks do
		reaper.SetMediaTrackInfo_Value(tracks[i], "B_MUTE", 1)
	end
end

function addSomeTracksAtTheEnd()

	local numberOfTracksToAdd = 2

	for i = 0, numberOfTracksToAdd-1 do
		local numberOfTracks = reaper.GetNumTracks()
		local wantTrackDefaults = true
		reaper.InsertTrackAtIndex(numberOfTracks, wantTrackDefaults)
	end
end

function alignNotesToBe(lengthArg)

	local items = getArrayOfItems()
	local positionOfFirstItem = reaper.GetMediaItemInfo_Value(items[0], "D_POSITION")
	local lengthOfFirstItem = reaper.GetMediaItemInfo_Value(items[0], "D_LENGTH")

	for i = 0, #items do
		
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(items[i], "D_POSITION")
		local selectedItemLength = reaper.GetMediaItemInfo_Value(items[i], "D_LENGTH")
		reaper.SetMediaItemInfo_Value(items[i], "D_POSITION", positionOfFirstItem)
		reaper.SetMediaItemInfo_Value(items[i], "D_LENGTH", lengthArg)

		local takeIndex = 0
		local selectedItemTake = reaper.GetTake(items[i], takeIndex)
		local selectedItemTakeStartOffset = reaper.GetMediaItemTakeInfo_Value(selectedItemTake, "D_STARTOFFS")

		local amountToShiftTheStartOffset = selectedItemLength-lengthOfFirstItem
		reaper.SetMediaItemTakeInfo_Value(selectedItemTake, "D_STARTOFFS", amountToShiftTheStartOffset)
	end
end

function moveItemsOntoTracksForEightColumns(numberOfStems)

	local numberOfSelectedItems = getNumberOfSelectedItems()
	local stemGroup = 0
	local numberOfStemGroups = math.floor(numberOfSelectedItems/numberOfStems)

	local tracks = getArrayOfTracks()
	local items = getArrayOfItems()

	local numberOfColumns = 8
	columnIndex = 0
	rowIndex = 0
	for trackIndex = 0, #tracks do

		local itemIndex = trackIndex

		if columnIndex % numberOfColumns == 0 then
			columnIndex = 0
			rowIndex = rowIndex + 1
		end

		if columnIndex ~= 0 then
			local selectedItemPosition = reaper.GetMediaItemInfo_Value(items[itemIndex], "D_POSITION")
			reaper.SetMediaItemInfo_Value(items[itemIndex], "D_POSITION", selectedItemPosition + columnIndex*(lengthOfEighthNote() + lengthOfQuarterNote()))
			reaper.MoveMediaItemToTrack(items[itemIndex], tracks[trackIndex-columnIndex])
			reaper.DeleteTrack(tracks[trackIndex])
		end

		columnIndex = columnIndex + 1
	end

end

local numberOfStems = 20

startUndoBlock()

	alignItems(numberOfStems)
	moveItemsToNewTracks(numberOfStems)
	addBufferTracks(numberOfStems)
	alignNotesToBe(lengthOfEighthNote())
	moveItemsOntoTracksForEightColumns(numberOfStems)
	muteSelectedTracks()
	extendByOneHundredTwentyEighthNotes()

endUndoBlock()