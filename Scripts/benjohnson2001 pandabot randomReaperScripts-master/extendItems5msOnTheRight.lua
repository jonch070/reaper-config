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
	local actionDescription = "extendItems5msOnTheRight"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

-----

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()

	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
		local selectedItemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

		reaper.SetMediaItemInfo_Value(selectedItem, "D_LENGTH", selectedItemLength + 0.005)
		reaper.SetMediaItemInfo_Value(selectedItem, "D_FADEOUTLEN", 0.005)

		local fadeOutShape = 4
		reaper.SetMediaItemInfo_Value(selectedItem, "C_FADEOUTSHAPE", fadeOutShape)
	end

endUndoBlock()
