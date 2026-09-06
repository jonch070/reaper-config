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
	local actionDescription = "generateSnapNotes"
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

function lengthOfSixteenthNote()
	return lengthOfEighthNote()/2
end

function lengthOfThirtySecondNote()
	return lengthOfSixteenthNote()/2
end

function lengthOfSixtyFourthNote()
	return lengthOfThirtySecondNote()/2
end

function lengthOfHundredTwentyEighthNote()
	return lengthOfSixtyFourthNote()/2
end

-----

function activeMidiEditor()
  return reaper.MIDIEditor_GetActive()
end

function activeTake()
  return reaper.MIDIEditor_GetTake(activeMidiEditor())
end

function activeMediaItem()
  return reaper.GetMediaItemTake_Item(activeTake())
end

function mediaItemStartPosition()
  return reaper.GetMediaItemInfo_Value(activeMediaItem(), "D_POSITION")
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

function insertLeadToneNote(startPosition, numberOfSixteenthNotes)

	local noteIsMuted = false
	local noteNumber = 49
	local velocity = 117
	insertNote(startPosition, startPosition + numberOfSixteenthNotes*lengthOfSixteenthNote(), noteNumber, noteIsMuted, velocity)
end

function insertAttackNote(startPosition, endPosition)

	local noteIsMuted = false
	local noteNumber = 52
	local velocity = 96
	insertNote(startPosition, endPosition, noteNumber, noteIsMuted, velocity)
end

function insertSpacerNote(startPosition, endPosition)

	local noteIsMuted = true
	local noteNumber = 45
	local velocity = 96
	insertNote(startPosition, endPosition, noteNumber, noteIsMuted, velocity)
end

function insertNote(startPosition, endPosition, noteNumber, noteIsMuted, velocity)

	local startPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), startPosition)
	local endPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), endPosition)

	local keepNotesSelected = false
	local channel = getCurrentNoteChannel()
	local noSort = false

	reaper.MIDI_InsertNote(activeTake(), keepNotesSelected, noteIsMuted, startPositionPPQ, endPositionPPQ, channel, noteNumber, velocity, noSort)
end

function moveCursorPositionToTheRight(numberOfSixteenthNotesForLeadTone)

	local numberOfSixteenthNotes = numberOfSixteenthNotesForLeadTone + 8

  local moveTimeSelection = false
  reaper.MoveEditCursor(numberOfSixteenthNotes * lengthOfSixteenthNote(), moveTimeSelection)
end

function channelMessageForCCEvents()

	-- 176 is the midi command number for channel 1 CC messages
	return 176
end

function insertCC(position, value)

	local isSelected = false
	local isMuted = false
	local ppqPosition = reaper.MIDI_GetPPQPosFromProjTime(activeTake(), position)
	local channelNumber = 1
	local channelNumberIndex = channelNumber - 1
	local ccNumber =  112

	reaper.MIDI_InsertCC(activeTake(), isSelected, isMuted, ppqPosition, channelMessageForCCEvents(), channelNumberIndex, ccNumber, value)
end




startUndoBlock()


	insertCC(mediaItemStartPosition(), 127)

	local numberOfSixteenthNotesForLeadTone = 65

	for i = 1, 12 do
	-- for i = 1, 200 do

		local cursorPosition = reaper.GetCursorPosition()

		local lengthOfAttackNote = lengthOfSixteenthNote()
		local attackNoteStartPosition = cursorPosition - lengthOfAttackNote
		local attackNoteEndPosition = cursorPosition
		insertAttackNote(attackNoteStartPosition, attackNoteEndPosition)
		insertLeadToneNote(attackNoteEndPosition, numberOfSixteenthNotesForLeadTone)

		local leadToneNoteEndPosition = attackNoteEndPosition + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote()
		insertCC(leadToneNoteEndPosition + lengthOfQuarterNote(), 0)
		insertCC(leadToneNoteEndPosition + lengthOfQuarterNote() + lengthOfHundredTwentyEighthNote()/4, 127)


		local spacerNoteEndPosition = attackNoteEndPosition + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote() + 2*lengthOfQuarterNote()
		insertSpacerNote(attackNoteEndPosition + numberOfSixteenthNotesForLeadTone * lengthOfSixteenthNote(), spacerNoteEndPosition)

		moveCursorPositionToTheRight(numberOfSixteenthNotesForLeadTone)
	end

	reaper.UpdateArrange()

endUndoBlock()






			-- local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(activeTake(), 0)
			-- print("retval: " .. tostring(retval))
			-- print("selected: " .. tostring(selected))
			-- print("muted: " .. tostring(muted))
			-- print("cc_pos: " .. tostring(cc_pos))
			-- print("chanmsg: " .. tostring(chanmsg))
			-- print("chan: " .. tostring(chan))
			-- print("msg2: " .. tostring(msg2))
			-- print("msg3: " .. tostring(msg3))