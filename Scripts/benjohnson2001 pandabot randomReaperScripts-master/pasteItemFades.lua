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
	local actionDescription = "pasteItemFades"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

------

local sectionName = "com.pandabot.CopyAndPasteItemFades"

local positionKey = "position"
local lengthKey = "length"
local fadeInShapeKey = "fadeInShape"
local fadeOutShapeKey = "fadeOutShape"
local fadeInLengthKey = "fadeInLength"
local fadeOutLengthKey = "fadeOutLength"
local startOffsetKey = "startOffset"
local snapOffsetKey = "snapOffset"


local function setValue(key, value)
  reaper.SetProjExtState(activeProjectIndex, sectionName, key, value)
end

local function getValue(key)

  local valueExists, value = reaper.GetProjExtState(activeProjectIndex, sectionName, key)

  if valueExists == 0 then
    return nil
  end

  return value
end

-----

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems == 0 then
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end

startUndoBlock()

	local sourceItemPosition = getValue(positionKey)
	local sourceItemLength = getValue(lengthKey)
	local sourceItemFadeInShape = getValue(fadeInShapeKey)
	local sourceItemFadeOutShape = getValue(fadeOutShapeKey)
	local sourceItemFadeInLength = getValue(fadeInLengthKey)
	local sourceItemFadeOutLength = getValue(fadeOutLengthKey)
	local sourceItemStartOffset = getValue(startOffsetKey)
	local sourceItemSnapOffset = getValue(snapOffsetKey)


	-- print("paste_" .. "sourceItemPosition: " .. sourceItemPosition)
	-- print("paste_" .. "sourceItemLength: " .. sourceItemLength)
	-- print("paste_" .. "sourceItemFadeInShape: " .. sourceItemFadeInShape)
	-- print("paste_" .. "sourceItemFadeOutShape: " .. sourceItemFadeOutShape)
	-- print("paste_" .. "sourceItemFadeInLength: " .. sourceItemFadeInLength)
	-- print("paste_" .. "sourceItemFadeOutLength: " .. sourceItemFadeOutLength)
	-- print("paste_" .. "sourceItemStartOffset: " .. sourceItemStartOffset)
	-- print("paste_" .. "sourceItemSnapOffset: " .. sourceItemSnapOffset)


-- itemLength = sourceItemLength

-- startOffset should be sourceItemSnapOffset

-- same fades


	for i = 0, numberOfSelectedItems - 1 do

		local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
		local takeIndex = 0
		local selectedItemTake = reaper.GetTake(selectedItem, takeIndex)


		reaper.SetMediaItemInfo_Value(selectedItem, "D_LENGTH", sourceItemLength)
		reaper.SetMediaItemInfo_Value(selectedItem, "D_SNAPOFFSET", sourceItemSnapOffset)

		reaper.SetMediaItemInfo_Value(selectedItem, "C_FADEINSHAPE", sourceItemFadeInShape)
		reaper.SetMediaItemInfo_Value(selectedItem, "C_FADEOUTSHAPE", sourceItemFadeOutShape)
		reaper.SetMediaItemInfo_Value(selectedItem, "D_FADEINLEN", sourceItemFadeInLength)
		reaper.SetMediaItemInfo_Value(selectedItem, "D_FADEOUTLEN", sourceItemFadeOutLength)


		local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
		local selectedItemPlaybackRate = reaper.GetMediaItemTakeInfo_Value(selectedItemTake, "D_PLAYRATE")
		local selectedItemTakeStartOffset = reaper.GetMediaItemTakeInfo_Value(selectedItemTake, "D_STARTOFFS")
		reaper.SetMediaItemTakeInfo_Value(selectedItemTake, "D_STARTOFFS", selectedItemTakeStartOffset-sourceItemSnapOffset*selectedItemPlaybackRate)

		reaper.SetMediaItemInfo_Value(selectedItem, "D_POSITION", selectedItemPosition-sourceItemSnapOffset)

	end

endUndoBlock()
