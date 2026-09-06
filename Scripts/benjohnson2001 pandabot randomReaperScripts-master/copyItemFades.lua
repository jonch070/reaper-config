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
	local actionDescription = "copyItemFades"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

---

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

	local selectedItem = reaper.GetSelectedMediaItem(activeProjectIndex, 0)
	local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
	local selectedItemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
	local selectedItemFadeInShape = reaper.GetMediaItemInfo_Value(selectedItem, "C_FADEINSHAPE")
	local selectedItemFadeOutShape = reaper.GetMediaItemInfo_Value(selectedItem, "C_FADEOUTSHAPE")
	local selectedItemFadeInLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_FADEINLEN")
	local selectedItemFadeOutLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_FADEOUTLEN")
	local selectedItemStartOffset = reaper.GetMediaItemInfo_Value(selectedItem, "D_STARTOFFS")
	local selectedItemSnapOffset = reaper.GetMediaItemInfo_Value(selectedItem, "D_SNAPOFFSET")

	setValue(positionKey, selectedItemPosition)
	setValue(lengthKey, selectedItemLength)
	setValue(fadeInShapeKey, selectedItemFadeInShape)
	setValue(fadeOutShapeKey, selectedItemFadeOutShape)
	setValue(fadeInLengthKey, selectedItemFadeInLength)
	setValue(fadeOutLengthKey, selectedItemFadeOutLength)
	setValue(startOffsetKey, selectedItemStartOffset)
	setValue(snapOffsetKey, selectedItemSnapOffset)

	-- print("copy_" .. "selectedItemPosition: " .. selectedItemPosition)
	-- print("copy_" .. "selectedItemLength: " .. selectedItemLength)
	-- print("copy_" .. "selectedItemFadeInShape: " .. selectedItemFadeInShape)
	-- print("copy_" .. "selectedItemFadeOutShape: " .. selectedItemFadeOutShape)
	-- print("copy_" .. "selectedItemFadeInLength: " .. selectedItemFadeInLength)
	-- print("copy_" .. "selectedItemFadeOutLength: " .. selectedItemFadeOutLength)
	-- print("copy_" .. "selectedItemStartOffset: " .. selectedItemStartOffset)
	-- print("copy_" .. "selectedItemSnapOffset: " .. selectedItemSnapOffset)

endUndoBlock()
