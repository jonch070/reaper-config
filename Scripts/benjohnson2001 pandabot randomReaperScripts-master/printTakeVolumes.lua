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
	local actionDescription = "glueNotesAndRenameFilesForRockStandard"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
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

startUndoBlock()

	local items = getArrayOfItems()

	for i = 0, #items do

			local takeIndex = 0
			local itemTake = reaper.GetTake(items[i], takeIndex)
			local itemTakeVolume = reaper.GetMediaItemTakeInfo_Value(itemTake, "D_VOL")

			print(itemTakeVolume)
	end

endUndoBlock()