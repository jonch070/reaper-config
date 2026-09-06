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
	local actionDescription = "adjustStartOffset"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function split(inputString, separator)

	if separator == nil then
		separator = "%s"
	end
	
	local t = {}
	for str in string.gmatch(inputString, "([^" .. separator .. "]+)") do
		table.insert(t, str)
	end
	
	return t
end

-----

startUndoBlock()

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

local midiItem = nil
local midiItemIndex = nil
local takeIndex = 0

local audioItems = {}

for i = 0, numberOfSelectedItems - 1 do

	local theItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
	local theItemTake = reaper.GetTake(theItem, takeIndex)
	local _, startOffsetString = reaper.GetMediaFileMetadata(reaper.GetMediaItemTake_Source(theItemTake), "Generic:StartOffset")

	if (startOffsetString ~= "") then

		local startOffset = split(startOffsetString, ":")[1] * 60 + split(startOffsetString, ":")[2]

		local currentPosition = reaper.GetMediaItemInfo_Value(theItem, "D_POSITION")
		local currentLength = reaper.GetMediaItemInfo_Value(theItem, "D_LENGTH")
		print("startOffset: " .. startOffset)
		print("currentPosition: " .. currentPosition)
		print("currentLength: " .. currentLength)

		reaper.SetMediaItemInfo_Value(theItem, "D_LENGTH", currentLength + startOffset)
		reaper.SetMediaItemInfo_Value(theItem, "D_POSITION", currentPosition + startOffset)
	end
end



endUndoBlock()
