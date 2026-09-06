-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "transposeItems"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function insertNewTrackAtEndOfTrackList()

	local commandId = 40702
  reaper.Main_OnCommand(commandId, 0)
end

MatrixCell = {}
MatrixCell.__index = MatrixCell

function MatrixCell:new(m, n, item)

  local self = {}
  setmetatable(self, MatrixCell)

  self.m = m
  self.n = n
  self.item = item

  return self
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

local function getTrackNumber(item)

		local trackOfItem = reaper.GetMediaItem_Track(item)
		local trackNumber = reaper.GetMediaTrackInfo_Value(trackOfItem, "IP_TRACKNUMBER")

		return trackNumber
end

startUndoBlock()

	local numberOfSelectedItems = getNumberOfSelectedItems()


	local arrayOfMatrixCells = {}

	local m = 0
	local n = 0

	local previousTrackNumber = nil
	local startingTrackNumber = nil
	local startingItemPosition = nil
	local itemLength = nil

	for i = 0, numberOfSelectedItems - 1 do

		local item = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local trackOfItem = reaper.GetMediaItem_Track(item)
		local trackNumber = reaper.GetMediaTrackInfo_Value(trackOfItem, "IP_TRACKNUMBER")
		
		if i == 0 then
			startingTrackNumber = trackNumber
			startingItemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		end

		if trackNumber ~= previousTrackNumber then
			n = 1
			m = m + 1
		end

		arrayOfMatrixCells[i] = MatrixCell:new(m, n, item)

		n = n + 1
		previousTrackNumber = trackNumber
	end

	for j = 0, #arrayOfMatrixCells do

		local cell = arrayOfMatrixCells[j]

		-- 1,4 needs to go to 4,1

		local delta = cell.n - cell.m

		local currentTrackNumber = getTrackNumber(cell.item)

		-- print("currentTrackNumber: " .. currentTrackNumber)
		-- print("currentTrackNumber + delta: " .. currentTrackNumber + delta)


		local destinationTrackIndex = currentTrackNumber + delta - 1
		local destinationTrack = reaper.GetTrack(activeProjectIndex, destinationTrackIndex)

		if destinationTrack == nil then
			insertNewTrackAtEndOfTrackList()
			destinationTrack = reaper.GetTrack(activeProjectIndex, destinationTrackIndex)
		end

		local currentItemPosition = reaper.GetMediaItemInfo_Value(cell.item, "D_POSITION")
		local itemLength = reaper.GetMediaItemInfo_Value(cell.item, "D_LENGTH")

		local newItemPosition = currentItemPosition - itemLength*delta

		reaper.SetMediaItemInfo_Value(cell.item, "D_POSITION", newItemPosition)

		local result = reaper.MoveMediaItemToTrack(cell.item, destinationTrack)
		reaper.UpdateArrange()

	end



endUndoBlock()