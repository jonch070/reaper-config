-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "removeSnapOffsetAndRestorePosition"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function getNumberOfSelectedItems()
	return reaper.CountSelectedMediaItems(activeProjectIndex)
end

startUndoBlock()

	local numberOfSelectedItems = getNumberOfSelectedItems()

	for i = 0, numberOfSelectedItems - 1 do

		local item = reaper.GetSelectedMediaItem(activeProjectIndex, i)

		local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local itemSnapOffset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
		local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", itemPosition + itemSnapOffset)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", itemLength - 1/48000)
    reaper.UpdateArrange() 
	end




endUndoBlock()
