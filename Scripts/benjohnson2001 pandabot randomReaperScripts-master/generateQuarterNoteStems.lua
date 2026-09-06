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
	local actionDescription = "generateQuarterNoteStems"
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

function insertQuarterNote(startPosition, ppqOffset)

	local cumulativeOffset = 0

	for i = 0, ppqOffset do
		cumulativeOffset = cumulativeOffset + i
	end

	local keepNotesSelected = false
	local noteIsMuted = false
	local startPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), startPosition) + cumulativeOffset
	local endPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), startPosition+lengthOfQuarterNote()) + cumulativeOffset

	local channel = getCurrentNoteChannel()
	local note = 49
	local velocity = 96
	local noSort = false

	reaper.MIDI_InsertNote(activeTake(), keepNotesSelected, noteIsMuted, startPositionPPQ, endPositionPPQ, channel, note, velocity, noSort)
end

function insertSpacerNote(startPosition, lengthInPPQ)

	local cumulativeOffset = 0

	for i = 0, lengthInPPQ-1 do
		cumulativeOffset = cumulativeOffset + i
	end

	local startPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), startPosition) + cumulativeOffset
	local endPositionPPQ = startPositionPPQ + lengthInPPQ

	local keepNotesSelected = false
	local noteIsMuted = true
	local channel = getCurrentNoteChannel()
	local note = 45
	local velocity = 96
	local noSort = false

	reaper.MIDI_InsertNote(activeTake(), keepNotesSelected, noteIsMuted, startPositionPPQ, endPositionPPQ, channel, note, velocity, noSort)
end

startUndoBlock()

	local cursorPosition = reaper.GetCursorPosition()
	local ppqOffset = 0
	insertQuarterNote(cursorPosition, ppqOffset)

	local initialPosition = cursorPosition + lengthOfQuarterNote()

	for i = 0, 300 do

		insertQuarterNote(initialPosition + i*lengthOfQuarterNote(), i)
		insertSpacerNote(initialPosition + (i+1)*lengthOfQuarterNote(), (i+1))
	end

	reaper.UpdateArrange()

endUndoBlock()
