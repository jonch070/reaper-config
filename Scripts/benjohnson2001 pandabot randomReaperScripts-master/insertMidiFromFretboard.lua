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
	local actionDescription = "insertMidiFromFretboard"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function getNoteNumber(arg)

	if arg == "B8" then
		return 119
	elseif arg == "A#8" then
		return 118
	elseif arg == "A8" then
		return 117
	elseif arg == "G#8" then
		return 116
	elseif arg == "G8" then
		return 115
	elseif arg == "F#8" then
		return 114
	elseif arg == "F8" then
		return 113
	elseif arg == "E8" then
		return 112
	elseif arg == "D#8" then
		return 111
	elseif arg == "D8" then
		return 110
	elseif arg == "C#8" then
		return 109
	elseif arg == "C8" then
		return 108
	elseif arg == "B7" then
		return 107
	elseif arg == "A#7" then
		return 106
	elseif arg == "A7" then
		return 105
	elseif arg == "G#7" then
		return 104
	elseif arg == "G7" then
		return 103
	elseif arg == "F#7" then
		return 102
	elseif arg == "F7" then
		return 101
	elseif arg == "E7" then
		return 100
	elseif arg == "D#7" then
		return 99
	elseif arg == "D7" then
		return 98
	elseif arg == "C#7" then
		return 97
	elseif arg == "C7" then
		return 96
	elseif arg == "B6" then
		return 95
	elseif arg == "A#6" then
		return 94
	elseif arg == "A6" then
		return 93
	elseif arg == "G#6" then
		return 92
	elseif arg == "G6" then
		return 91
	elseif arg == "F#6" then
		return 90
	elseif arg == "F6" then
		return 89
	elseif arg == "E6" then
		return 88
	elseif arg == "D#6" then
		return 87
	elseif arg == "D6" then
		return 86
	elseif arg == "C#6" then
		return 85
	elseif arg == "C6" then
		return 84
	elseif arg == "B5" then
		return 83
	elseif arg == "A#5" then
		return 82
	elseif arg == "A5" then
		return 81
	elseif arg == "G#5" then
		return 80
	elseif arg == "G5" then
		return 79
	elseif arg == "F#5" then
		return 78
	elseif arg == "F5" then
		return 77
	elseif arg == "E5" then
		return 76
	elseif arg == "D#5" then
		return 75
	elseif arg == "D5" then
		return 74
	elseif arg == "C#5" then
		return 73
	elseif arg == "C5" then
		return 72
	elseif arg == "B4" then
		return 71
	elseif arg == "A#4" then
		return 70
	elseif arg == "A4" then
		return 69
	elseif arg == "G#4" then
		return 68
	elseif arg == "G4" then
		return 67
	elseif arg == "F#4" then
		return 66
	elseif arg == "F4" then
		return 65
	elseif arg == "E4" then
		return 64
	elseif arg == "D#4" then
		return 63
	elseif arg == "D4" then
		return 62
	elseif arg == "C#4" then
		return 61
	elseif arg == "C4" then
		return 60
	elseif arg == "B3" then
		return 59
	elseif arg == "A#3" then
		return 58
	elseif arg == "A3" then
		return 57
	elseif arg == "G#3" then
		return 56
	elseif arg == "G3" then
		return 55
	elseif arg == "F#3" then
		return 54
	elseif arg == "F3" then
		return 53
	elseif arg == "E3" then
		return 52
	elseif arg == "D#3" then
		return 51
	elseif arg == "D3" then
		return 50
	elseif arg == "C#3" then
		return 49
	elseif arg == "C3" then
		return 48
	elseif arg == "B2" then
		return 47
	elseif arg == "A#2" then
		return 46
	elseif arg == "A2" then
		return 45
	elseif arg == "G#2" then
		return 44
	elseif arg == "G2" then
		return 43
	elseif arg == "F#2" then
		return 42
	elseif arg == "F2" then
		return 41
	elseif arg == "E2" then
		return 40
	elseif arg == "D#2" then
		return 39
	elseif arg == "D2" then
		return 38
	elseif arg == "C#2" then
		return 37
	elseif arg == "C2" then
		return 36
	elseif arg == "B1" then
		return 35
	elseif arg == "A#1" then
		return 34
	elseif arg == "A1" then
		return 33
	elseif arg == "G#1" then
		return 32
	elseif arg == "G1" then
		return 31
	elseif arg == "F#1" then
		return 30
	elseif arg == "F1" then
		return 29
	elseif arg == "E1" then
		return 28
	elseif arg == "D#1" then
		return 27
	elseif arg == "D1" then
		return 26
	elseif arg == "C#1" then
		return 25
	elseif arg == "C1" then
		return 24		
	else
		print("couldn't find the note " .. arg)
	end
end

function activeMidiEditor()
  return reaper.MIDIEditor_GetActive()
end

function activeTake()
  return reaper.MIDIEditor_GetTake(activeMidiEditor())
end

function activeMediaItem()
  return reaper.GetMediaItemTake_Item(activeTake())
end

function getNumberOfNotes()

  local _, numberOfNotes = reaper.MIDI_CountEvts(activeTake())
  return numberOfNotes
end


local function cursorPosition()
  return reaper.GetCursorPosition()
end

function getCursorPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(activeTake(), cursorPosition())
end

function getMidiEndPositionPPQ()

  local startPosition = reaper.GetCursorPosition()
  local startPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), startPosition)
  local endPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), startPosition+gridUnitLength())
  return endPositionPPQ
end

function mediaItemStartPosition()
  return reaper.GetMediaItemInfo_Value(activeMediaItem(), "D_POSITION")
end

function mediaItemStartPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(activeTake(), mediaItemStartPosition())
end

function mediaItemStartPositionQN()
  return reaper.MIDI_GetProjQNFromPPQPos(activeTake(), mediaItemStartPositionPPQ())
end

function gridUnitLength()

  local gridLengthQN = reaper.MIDI_GetGrid(activeTake())
  local mediaItemPlusGridLengthPPQ = reaper.MIDI_GetPPQPosFromProjQN(activeTake(), mediaItemStartPositionQN() + gridLengthQN)
  local mediaItemPlusGridLength = reaper.MIDI_GetProjTimeFromPPQPos(activeTake(), mediaItemPlusGridLengthPPQ)
  return mediaItemPlusGridLength - mediaItemStartPosition()
end

local function noteLength()

  return gridUnitLength()
end

function deleteNote(noteIndex)
  reaper.MIDI_DeleteNote(activeTake(), noteIndex)
end

function deleteExistingNotesInNextInsertionTimePeriod()

	local tolerance = 0.000001

  local insertionStartTime = cursorPosition()
  local insertionEndTime = insertionStartTime + noteLength()

  local numberOfNotes = getNumberOfNotes()

  for noteIndex = numberOfNotes-1, 0, -1 do

    local _, _, _, noteStartPositionPPQ = reaper.MIDI_GetNote(activeTake(), noteIndex)
    local noteStartTime = reaper.MIDI_GetProjTimeFromPPQPos(activeTake(), noteStartPositionPPQ)

    if noteStartTime + tolerance >= insertionStartTime and noteStartTime + tolerance <= insertionEndTime then
      deleteNote(noteIndex)
    end
  end
end

function getCurrentNoteChannel(channelArg)

  if channelArg ~= nil then
    return channelArg
  end

  if activeMidiEditor() == nil then
    return 0
  end

  return reaper.MIDIEditor_GetSetting_int(activeMidiEditor(), "default_note_chan")
end

function getCurrentVelocity()

  if activeMidiEditor() == nil then
    return 96
  end

  return reaper.MIDIEditor_GetSetting_int(activeMidiEditor(), "default_note_vel")
end

function insertMidiNote(note)

	local noteIsMuted = false
	local startPosition = getCursorPositionPPQ()
	local endPosition = getMidiEndPositionPPQ()

	local channel = getCurrentNoteChannel()
	local velocity = getCurrentVelocity()
	local noSort = false
	local keepNotesSelected = false

	reaper.MIDI_InsertNote(activeTake(), keepNotesSelected, noteIsMuted, startPosition, endPosition, channel, note, velocity, noSort)
end

function noteNumber(arg, stringNumber)

	if stringNumber == 1 then

		if arg == 0 then return getNoteNumber("E1") end
		if arg == 1 then return getNoteNumber("F1") end
		if arg == 2 then return getNoteNumber("F#1") end
		if arg == 3 then return getNoteNumber("G1") end
		if arg == 4 then return getNoteNumber("G#1") end
		if arg == 5 then return getNoteNumber("A1") end
		if arg == 6 then return getNoteNumber("A#1") end
		if arg == 7 then return getNoteNumber("B1") end
		if arg == 8 then return getNoteNumber("C2") end
		if arg == 9 then return getNoteNumber("C#2") end
		if arg == 10 then return getNoteNumber("D2") end
		if arg == 11 then return getNoteNumber("D#2") end
		if arg == 12 then return getNoteNumber("E2") end
		if arg == 13 then return getNoteNumber("F2") end
		if arg == 14 then return getNoteNumber("F#2") end
		if arg == 15 then return getNoteNumber("G2") end
		if arg == 16 then return getNoteNumber("G#2") end
		if arg == 17 then return getNoteNumber("A2") end
		if arg == 18 then return getNoteNumber("A#2") end
		if arg == 19 then return getNoteNumber("B2") end
		if arg == 20 then return getNoteNumber("C3") end
		if arg == 21 then return getNoteNumber("C#3") end
		if arg == 22 then return getNoteNumber("D3") end
		if arg == 23 then return getNoteNumber("D#3") end
		if arg == 24 then return getNoteNumber("E3") end

	elseif stringNumber == 2 then

		if arg == 0 then return getNoteNumber("A2") end
		if arg == 1 then return getNoteNumber("A#2") end
		if arg == 2 then return getNoteNumber("B2") end
		if arg == 3 then return getNoteNumber("C3") end
		if arg == 4 then return getNoteNumber("C#3") end
		if arg == 5 then return getNoteNumber("D3") end
		if arg == 6 then return getNoteNumber("D#3") end
		if arg == 7 then return getNoteNumber("E3") end
		if arg == 8 then return getNoteNumber("F3") end
		if arg == 9 then return getNoteNumber("F#3") end
		if arg == 10 then return getNoteNumber("G3") end
		if arg == 11 then return getNoteNumber("G#3") end
		if arg == 12 then return getNoteNumber("A3") end
		if arg == 13 then return getNoteNumber("A#3") end
		if arg == 14 then return getNoteNumber("B3") end
		if arg == 15 then return getNoteNumber("C4") end
		if arg == 16 then return getNoteNumber("C#4") end
		if arg == 17 then return getNoteNumber("D4") end
		if arg == 18 then return getNoteNumber("D#4") end
		if arg == 19 then return getNoteNumber("E4") end
		if arg == 20 then return getNoteNumber("F4") end
		if arg == 21 then return getNoteNumber("F#4") end
		if arg == 22 then return getNoteNumber("G4") end
		if arg == 23 then return getNoteNumber("G#4") end
		if arg == 24 then return getNoteNumber("A4") end

	elseif stringNumber == 3 then

		if arg == 0 then return getNoteNumber("D3") end
		if arg == 1 then return getNoteNumber("D#3") end
		if arg == 2 then return getNoteNumber("E3") end
		if arg == 3 then return getNoteNumber("F3") end
		if arg == 4 then return getNoteNumber("F#3") end
		if arg == 5 then return getNoteNumber("G3") end
		if arg == 6 then return getNoteNumber("G#3") end
		if arg == 7 then return getNoteNumber("A3") end
		if arg == 8 then return getNoteNumber("A#3") end
		if arg == 9 then return getNoteNumber("B3") end
		if arg == 10 then return getNoteNumber("C4") end
		if arg == 11 then return getNoteNumber("C#4") end
		if arg == 12 then return getNoteNumber("D4") end
		if arg == 13 then return getNoteNumber("D#4") end
		if arg == 14 then return getNoteNumber("E4") end
		if arg == 15 then return getNoteNumber("F4") end
		if arg == 16 then return getNoteNumber("F#4") end
		if arg == 17 then return getNoteNumber("G4") end
		if arg == 18 then return getNoteNumber("G#4") end
		if arg == 19 then return getNoteNumber("A4") end
		if arg == 20 then return getNoteNumber("A#4") end
		if arg == 21 then return getNoteNumber("B4") end
		if arg == 22 then return getNoteNumber("C5") end
		if arg == 23 then return getNoteNumber("C#5") end
		if arg == 24 then return getNoteNumber("D5") end

	elseif stringNumber == 4 then

		if arg == 0 then return getNoteNumber("G3") end
		if arg == 1 then return getNoteNumber("G#3") end
		if arg == 2 then return getNoteNumber("A3") end
		if arg == 3 then return getNoteNumber("A#3") end
		if arg == 4 then return getNoteNumber("B3") end
		if arg == 5 then return getNoteNumber("C4") end
		if arg == 6 then return getNoteNumber("C#4") end
		if arg == 7 then return getNoteNumber("D4") end
		if arg == 8 then return getNoteNumber("D#4") end
		if arg == 9 then return getNoteNumber("E4") end
		if arg == 10 then return getNoteNumber("F4") end
		if arg == 11 then return getNoteNumber("F#4") end
		if arg == 12 then return getNoteNumber("G4") end
		if arg == 13 then return getNoteNumber("G#4") end
		if arg == 14 then return getNoteNumber("A4") end
		if arg == 15 then return getNoteNumber("A#4") end
		if arg == 16 then return getNoteNumber("B4") end
		if arg == 17 then return getNoteNumber("C5") end
		if arg == 18 then return getNoteNumber("C#5") end
		if arg == 19 then return getNoteNumber("D5") end
		if arg == 20 then return getNoteNumber("D#5") end
		if arg == 21 then return getNoteNumber("E5") end
		if arg == 22 then return getNoteNumber("F5") end
		if arg == 23 then return getNoteNumber("F#5") end
		if arg == 24 then return getNoteNumber("G5") end

	elseif stringNumber == 5 then

		if arg == 0 then return getNoteNumber("B3") end
		if arg == 1 then return getNoteNumber("C4") end
		if arg == 2 then return getNoteNumber("C#4") end
		if arg == 3 then return getNoteNumber("D4") end
		if arg == 4 then return getNoteNumber("D#4") end
		if arg == 5 then return getNoteNumber("E4") end
		if arg == 6 then return getNoteNumber("F4") end
		if arg == 7 then return getNoteNumber("F#4") end
		if arg == 8 then return getNoteNumber("G4") end
		if arg == 9 then return getNoteNumber("G#4") end
		if arg == 10 then return getNoteNumber("A4") end
		if arg == 11 then return getNoteNumber("A#4") end
		if arg == 12 then return getNoteNumber("B4") end
		if arg == 13 then return getNoteNumber("C5") end
		if arg == 14 then return getNoteNumber("C#5") end
		if arg == 15 then return getNoteNumber("D5") end
		if arg == 16 then return getNoteNumber("D#5") end
		if arg == 17 then return getNoteNumber("E5") end
		if arg == 18 then return getNoteNumber("F5") end
		if arg == 19 then return getNoteNumber("F#5") end
		if arg == 20 then return getNoteNumber("G5") end
		if arg == 21 then return getNoteNumber("G#5") end
		if arg == 22 then return getNoteNumber("A5") end
		if arg == 23 then return getNoteNumber("A#5") end
		if arg == 24 then return getNoteNumber("B5") end

	elseif stringNumber == 6 then

		if arg == 0 then return getNoteNumber("E4") end
		if arg == 1 then return getNoteNumber("F4") end
		if arg == 2 then return getNoteNumber("F#4") end
		if arg == 3 then return getNoteNumber("G4") end
		if arg == 4 then return getNoteNumber("G#4") end
		if arg == 5 then return getNoteNumber("A4") end
		if arg == 6 then return getNoteNumber("A#4") end
		if arg == 7 then return getNoteNumber("B4") end
		if arg == 8 then return getNoteNumber("C5") end
		if arg == 9 then return getNoteNumber("C#5") end
		if arg == 10 then return getNoteNumber("D5") end
		if arg == 11 then return getNoteNumber("D#5") end
		if arg == 12 then return getNoteNumber("E5") end
		if arg == 13 then return getNoteNumber("F5") end
		if arg == 14 then return getNoteNumber("F#5") end
		if arg == 15 then return getNoteNumber("G5") end
		if arg == 16 then return getNoteNumber("G#5") end
		if arg == 17 then return getNoteNumber("A5") end
		if arg == 18 then return getNoteNumber("A#5") end
		if arg == 19 then return getNoteNumber("B5") end
		if arg == 20 then return getNoteNumber("C6") end
		if arg == 21 then return getNoteNumber("C#6") end
		if arg == 22 then return getNoteNumber("D6") end
		if arg == 23 then return getNoteNumber("D#6") end
		if arg == 24 then return getNoteNumber("E6") end

	end
end 

function insertNote(arg, stringNumber)

	if arg == "x" or arg == "X" then
		return
	end

	insertMidiNote(noteNumber(tonumber(arg), stringNumber))
end


startUndoBlock()

	local numberOfInputs = 1
	local defaultInputs = ""
	local userComplied, userInputs =  reaper.GetUserInputs("enter guitar fretboard numbers, x for no play", numberOfInputs, "frets:,extrawidth=100", defaultInputs)

	if not userComplied then
		return
	end

	local firstFret = string.sub(userInputs, 1, 1);
	local secondFret = string.sub(userInputs, 2, 2);
	local thirdFret = string.sub(userInputs, 3, 3);
	local fourthFret = string.sub(userInputs, 4, 4);
	local fifthFret = string.sub(userInputs, 5, 5);
	local sixthFret = string.sub(userInputs, 6, 6);

	deleteExistingNotesInNextInsertionTimePeriod()

	insertNote(firstFret, 1)
	insertNote(secondFret, 2)
	insertNote(thirdFret, 3)
	insertNote(fourthFret, 4)
	insertNote(fifthFret, 5)
	insertNote(sixthFret, 6)

endUndoBlock()


