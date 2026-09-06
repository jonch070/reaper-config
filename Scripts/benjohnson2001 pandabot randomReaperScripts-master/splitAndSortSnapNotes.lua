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
	local actionDescription = "splitAndSortSnapNotes"
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

function lengthOfOneBar()
	return lengthOfQuarterNote()*4
end

function lengthOfPPQInSeconds(arg)
	local numberOfPulsesPerQuarterNote = 960
	return arg*lengthOfQuarterNote()/numberOfPulsesPerQuarterNote
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

function extendBySixteenthNotes()

	local commandId = reaper.NamedCommandLookup("_RS8803e4d7748937a8007b3ae438a72a06d83f1174")
	reaper.Main_OnCommand(commandId, 0)
end

function extendByOneHundredTwentyEighthNotes()

	local commandId = reaper.NamedCommandLookup("_RS565b2e47b74342346d72ae0984829d80013cd1fc")
	reaper.Main_OnCommand(commandId, 0)
end


-----


local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()


	-- local numberOfSixteenthNotesForLeadTone = 2
	-- local numberOfSixteenthNotesForLeadTone = 4
	-- local numberOfSixteenthNotesForLeadTone = 12
	-- local numberOfSixteenthNotesForLeadTone = 8
	-- local numberOfSixteenthNotesForLeadTone = 16
	-- local numberOfSixteenthNotesForLeadTone = 17
	local numberOfSixteenthNotesForLeadTone = 65
	local spacerLength = 8 * lengthOfSixteenthNote()
	-- local numberOfNotes = 19
	-- local numberOfNotes = 16
	-- local numberOfNotes = 9
	-- local numberOfNotes = 12
	-- local numberOfNotes = 8
	-- local numberOfNotes = 12
	local numberOfNotes = 12
	local selectedItems = getSelectedItems()

	for i = 0, #selectedItems do

		local allItemsFromSplit = {}
		allItemsFromSplit[0] = selectedItems[i]

		for j = 0, numberOfNotes do

			
			-- local attackNoteLength = j+1

			if j == 0 then

				local selectedItemPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION")

				-- local splitPosition = selectedItemPosition + lengthOfOneBar() - lengthOfPPQInSeconds(attackNoteLength+1)
				local splitPosition = selectedItemPosition + lengthOfOneBar()

				-- deleting one bar minus 2 ppq at start
				local newItem = reaper.SplitMediaItem(allItemsFromSplit[j], splitPosition)
				local trackOfNewItem = reaper.GetMediaItemTrack(allItemsFromSplit[j])
				reaper.DeleteTrackMediaItem(trackOfNewItem, allItemsFromSplit[j])
				

				-- add snap offset
				-- reaper.SetMediaItemInfo_Value(newItem, "D_SNAPOFFSET", lengthOfPPQInSeconds(attackNoteLength+1))

				allItemsFromSplit[j] = newItem

				-- move the items over to the left to align with the grid
				local currentPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION")
				reaper.SetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION", currentPosition - 6 * lengthOfSixteenthNote())

			elseif j == numberOfNotes then

				local selectedItemPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j-1], "D_POSITION")

				-- local previousAttackNoteLength = (j+1) - 1
				-- local splitPosition = selectedItemPosition + lengthOfPPQInSeconds(previousAttackNoteLength) + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote()
				local splitPosition = selectedItemPosition + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote()

				local newItem = reaper.SplitMediaItem(allItemsFromSplit[j-1], splitPosition)
				local newItemPosition = reaper.GetMediaItemInfo_Value(newItem, "D_POSITION")

				-- delete spacer
				local trackOfNewItem = reaper.GetMediaItemTrack(newItem)
				reaper.DeleteTrackMediaItem(trackOfNewItem, newItem)

				-- add snap offset
				-- reaper.SetMediaItemInfo_Value(newItem2, "D_SNAPOFFSET", lengthOfPPQInSeconds(attackNoteLength+1))

			else

				local selectedItemPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j-1], "D_POSITION")

				-- local previousAttackNoteLength = (j+1) - 1
				-- local splitPosition = selectedItemPosition + lengthOfPPQInSeconds(previousAttackNoteLength) + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote()
				local splitPosition = selectedItemPosition + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote()

				local newItem = reaper.SplitMediaItem(allItemsFromSplit[j-1], splitPosition)
				local newItemPosition = reaper.GetMediaItemInfo_Value(newItem, "D_POSITION")

				-- local secondSplitPosition = newItemPosition + spacerLength - lengthOfPPQInSeconds(attackNoteLength)
				local secondSplitPosition = newItemPosition + spacerLength
				local newItem2 = reaper.SplitMediaItem(newItem, secondSplitPosition)

				-- delete spacer
				local trackOfNewItem = reaper.GetMediaItemTrack(newItem)
				reaper.DeleteTrackMediaItem(trackOfNewItem, newItem)

				-- add snap offset
				-- reaper.SetMediaItemInfo_Value(newItem2, "D_SNAPOFFSET", lengthOfPPQInSeconds(attackNoteLength+1))

				allItemsFromSplit[j] = newItem2

				-- move the items over to the left to align with the grid
				local currentPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION")
				reaper.SetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION", currentPosition - 6 * lengthOfSixteenthNote())

			end

		end
	end




	--extendBySixteenthNotes()
	reaper.UpdateArrange()

endUndoBlock()






				-- print("j: " .. j)
				-- print("position: " .. tostring(selectedItemPosition))
				-- print("length: " .. tostring(selectedItemLength))
				-- print("\n")
				-- print(lengthOfPPQInSeconds(j))
