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
	local actionDescription = "splitAndSortEighthNoteStems"
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

function extendByOneHundredTwentyEighthNotes()

	local commandId = reaper.NamedCommandLookup("_RS565b2e47b74342346d72ae0984829d80013cd1fc")
	reaper.Main_OnCommand(commandId, 0)
end



local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()

	local numberOfNotes = 114
	-- local numberOfNotes = 301
	local selectedItems = getSelectedItems()

	for i = 0, #selectedItems do

		local allItemsFromSplit = {}
		allItemsFromSplit[0] = selectedItems[i]

		for j = 0, numberOfNotes - 1 do

			if j == 0 then

				local selectedItemPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION")
				-- local newItem = reaper.SplitMediaItem(allItemsFromSplit[j], selectedItemPosition + lengthOfEighthNote())
				local newItem = reaper.SplitMediaItem(allItemsFromSplit[j], selectedItemPosition + lengthOfEighthNote())
				allItemsFromSplit[j+1] = newItem

				-- at this point:
				-- allItemsFromSplit[0] is eighth note
				-- allItemsFromSplit[1] is the rest of the item

				local firstItemPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[0], "D_POSITION")
				reaper.SetMediaItemInfo_Value(allItemsFromSplit[0], "D_POSITION", firstItemPosition - lengthOfQuarterNote()) -- separate the notes so you can hear what they sound like alone

			else

				local selectedItemPosition = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j], "D_POSITION")
				local selectedItemLength = reaper.GetMediaItemInfo_Value(allItemsFromSplit[j], "D_LENGTH")
				local newItem = reaper.SplitMediaItem(allItemsFromSplit[j], selectedItemPosition + lengthOfEighthNote())

				-- at this point when j=1:
				-- allItemsFromSplit[1] is the second eighth note
				-- newItem is the rest of the item

				local newItemPosition = reaper.GetMediaItemInfo_Value(newItem, "D_POSITION")
				local newItem2 = reaper.SplitMediaItem(newItem, newItemPosition + lengthOfPPQInSeconds(j))
				
				-- at this point:
				-- newItem2 is the rest of the item
				-- newItem is just relese volume noise that should be discarded

				allItemsFromSplit[j+1] = newItem2
				local trackOfNewItem = reaper.GetMediaItemTrack(newItem)
				reaper.DeleteTrackMediaItem(trackOfNewItem, newItem)


				-- move the items over to the left to align with the grid
				local newItem2Position = reaper.GetMediaItemInfo_Value(newItem2, "D_POSITION")
				-- reaper.SetMediaItemInfo_Value(newItem2, "D_POSITION", newItem2Position - lengthOfPPQInSeconds(j))
				reaper.SetMediaItemInfo_Value(newItem2, "D_POSITION", newItem2Position - lengthOfPPQInSeconds(j) + lengthOfQuarterNote()) -- separate the notes so you can hear what they sound like alone

			end
		end
	end

	extendByOneHundredTwentyEighthNotes()
	reaper.UpdateArrange()

endUndoBlock()






				-- print("j: " .. j)
				-- print("position: " .. tostring(selectedItemPosition))
				-- print("length: " .. tostring(selectedItemLength))
				-- print("\n")
				-- print(lengthOfPPQInSeconds(j))
