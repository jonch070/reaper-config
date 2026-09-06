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
	local actionDescription = "combineVertical"
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

-----

function getSelectedItems()

	local selectedItems = {}

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

	for i = 0, numberOfSelectedItems - 1 do
		selectedItems[i] = reaper.GetSelectedMediaItem(activeProjectIndex, i)
	end

	return selectedItems

end

function getTrackNumberOfTrackWithTheLowestItem()

	local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)
	local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, numberOfSelectedItems-1)
	local trackOfSelectedItem = reaper.GetMediaItem_Track(selectedItem)
	return reaper.GetMediaTrackInfo_Value(trackOfSelectedItem, "IP_TRACKNUMBER")

end

function getTargetTrack()

	local trackNumberOfTrackWithTheLowestItem = getTrackNumberOfTrackWithTheLowestItem()
	local trackNumber = trackNumberOfTrackWithTheLowestItem + 2
	return reaper.GetTrack(activeProjectIndex, trackNumber)
end

function muteTrackOfItem(item)
	local trackOfItem = reaper.GetMediaItem_Track(item)
	reaper.SetMediaTrackInfo_Value(trackOfItem, "B_MUTE", 1.0)
end


local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()


	local selectedItems = getSelectedItems()
	local targetTrack = getTargetTrack()
	local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItems[0], "D_POSITION")

	for i = 0, #selectedItems do

		muteTrackOfItem(selectedItems[i])
		reaper.MoveMediaItemToTrack(selectedItems[i], targetTrack)
		reaper.SetMediaItemInfo_Value(selectedItems[i], "D_POSITION", selectedItemPosition + i*lengthOfEighthNote())
	end
	
	reaper.UpdateArrange()

endUndoBlock()






				-- print("j: " .. j)
				-- print("position: " .. tostring(selectedItemPosition))
				-- print("length: " .. tostring(selectedItemLength))
				-- print("\n")
				-- print(lengthOfPPQInSeconds(j))
