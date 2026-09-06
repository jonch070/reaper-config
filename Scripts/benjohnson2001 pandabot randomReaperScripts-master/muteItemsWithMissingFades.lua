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
	local actionDescription = "muteItemsWithMissingFades"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

-----

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end


function leftFadeIsNotPresent(startOffset, fadeInLength)

	if startOffset == 0 then
		return false
	end

	return fadeInLength == 0
end

function rightFadeIsNotPresent(fadeOutLength)

	return fadeOutLength == 0
end


local numberOfMutedItems = 0

startUndoBlock()

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local fadeInLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_FADEINLEN")
		local fadeOutLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_FADEOUTLEN")

		local takeIndex = 0
		local selectedItemTake = reaper.GetTake(selectedItem, takeIndex)
		local startOffset = reaper.GetMediaItemTakeInfo_Value(selectedItemTake, "D_STARTOFFS")


		if leftFadeIsNotPresent(startOffset, fadeInLength) or rightFadeIsNotPresent(fadeOutLength) then

			numberOfMutedItems = numberOfMutedItems + 1
			reaper.SetMediaItemInfo_Value(selectedItem, "B_MUTE", 1.0)
		end
	end

endUndoBlock()

print("numberOfMutedItems: " .. numberOfMutedItems)
reaper.UpdateArrange()