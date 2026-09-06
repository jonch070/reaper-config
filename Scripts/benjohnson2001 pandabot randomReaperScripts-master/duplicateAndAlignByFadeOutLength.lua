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
	local actionDescription = "duplicateAndAlignBySnapOffset"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

-----

function duplicateItems()

	local commandId = 41295
  reaper.Main_OnCommand(commandId, 0)
end

function getFadeOutLengthOfFirstItem()

	local indexOfFirstItem = 0
	local firstItem = reaper.GetSelectedMediaItem(activeProjectIndex, indexOfFirstItem)
	return reaper.GetMediaItemInfo_Value(firstItem, "D_FADEOUTLEN")
end


local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()

	duplicateItems()

	local offsetAmount = getFadeOutLengthOfFirstItem()

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
		reaper.SetMediaItemInfo_Value(selectedItem, "D_POSITION", selectedItemPosition-offsetAmount)
	end

	reaper.UpdateArrange()

endUndoBlock()
