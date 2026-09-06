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
	local actionDescription = "generateCleanTwoBarForRhythmNoteStems"
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

function lengthOfOneBar()
	return lengthOfQuarterNote() * 4
end

function lengthOfPPQInSeconds(arg)
	local numberOfPulsesPerQuarterNote = 960
	return arg*lengthOfQuarterNote()/numberOfPulsesPerQuarterNote
end

-----

function activeMidiEditor()
  return reaper.MIDIEditor_GetActive()
end

function activeTake()
  return reaper.MIDIEditor_GetTake(activeMidiEditor())
end

function getCurrentNoteChannel()

  if activeMidiEditor() == nil then
    return 0
  end

  return reaper.MIDIEditor_GetSetting_int(activeMidiEditor(), "default_note_chan")
end

function cursorPosition()
  return reaper.GetCursorPosition()
end

function getCursorPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(activeTake(), cursorPosition())
end

function insertEighthNote(position)
	local noteValue = 48
	local noteIsMuted = false
	insertNote(position, lengthOfEighthNote(), noteValue, noteIsMuted)
end

function insertBarNote(position)
	local noteValue = 48
	local noteIsMuted = false
	insertNote(position, lengthOfOneBar(), noteValue, noteIsMuted)
end

function insertSpacerNote(position, ppqArg)
	local noteValue = 45
	local noteIsMuted = true
	insertNote(position, lengthOfPPQInSeconds(ppqArg), noteValue, noteIsMuted)
end

function insertNote(position, length, noteValue, noteIsMuted)

	local keepNotesSelected = false
	local startPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), position)
	local endPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), position+length)

	local channel = getCurrentNoteChannel()
	local velocity = 96
	local noSort = false

	reaper.MIDI_InsertNote(activeTake(), keepNotesSelected, noteIsMuted, startPositionPPQ, endPositionPPQ, channel, noteValue, velocity, noSort)
end

function getCumulativePPQTimeInSeconds(ppqArg)

	if ppqArg < 0 then
		return 0
	end

	local cumulativePPQ = 0

	for i = 0, ppqArg do
		cumulativePPQ = cumulativePPQ + i
	end

	return lengthOfPPQInSeconds(cumulativePPQ)
end

startUndoBlock()

	local cursorPosition = reaper.GetCursorPosition()	
	insertBarNote(cursorPosition)

	local ppqOffset = 0

	for i = 0, 112 do

		local initialPosition = cursorPosition + lengthOfOneBar() + i * (lengthOfEighthNote() + lengthOfOneBar()) + getCumulativePPQTimeInSeconds(ppqOffset-1)

		insertEighthNote(initialPosition)

		if i ~= 0 then
			insertSpacerNote(initialPosition + lengthOfEighthNote(), ppqOffset)
		end

		insertBarNote(initialPosition + lengthOfEighthNote() + lengthOfPPQInSeconds(ppqOffset))

		ppqOffset = ppqOffset + 1
	end

	reaper.UpdateArrange()

endUndoBlock()
