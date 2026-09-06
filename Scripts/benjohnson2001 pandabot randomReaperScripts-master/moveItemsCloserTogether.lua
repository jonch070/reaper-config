-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "moveItemsCloserTogether"
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
	return lengthOfQuarterNote()*4
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

	local previousItemPosition = nil
	local previousItemLength = nil
	local bufferSpace = lengthOfOneBar()

	for i = 0, #items do

		local currentItem = items[i]

		if i ~= 0 then
			reaper.SetMediaItemInfo_Value(currentItem, "D_POSITION", previousItemPosition + previousItemLength + bufferSpace)
		end

		local currentItemPosition = reaper.GetMediaItemInfo_Value(currentItem, "D_POSITION")
		local currentItemLength = reaper.GetMediaItemInfo_Value(currentItem, "D_LENGTH")

		previousItemPosition = currentItemPosition
		previousItemLength = currentItemLength
	end

	--

endUndoBlock()