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
	local actionDescription = "setNotesToBe9680"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

-----

function activeMidiEditor()
  return reaper.MIDIEditor_GetActive()
end

function activeTake()
  return reaper.MIDIEditor_GetTake(activeMidiEditor())
end

function unselectAllItems()

	local commandId = 40289
  reaper.Main_OnCommand(commandId, 0)
end

function openMidiEditor()

	local commandId = 40153
  reaper.Main_OnCommand(commandId, 0)
end

function closeMidiEditor()
	local commandId = 2
	reaper.MIDIEditor_OnCommand(activeMidiEditor(), commandId)
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

function noteIsOnStrongBeatForEighthNote(startppqpos)

	local projectTimeAtNoteStartPosition = reaper.MIDI_GetProjTimeFromPPQPos(activeTake(), startppqpos)
	local quarterNotePosition = reaper.TimeMap2_timeToBeats(activeProjectIndex, projectTimeAtNoteStartPosition)
	local quarterNotePositionDecimalPart = quarterNotePosition % 1

	if (0 <= quarterNotePositionDecimalPart and quarterNotePositionDecimalPart < 0.1) then
		return true
	else
		return false
	end
end

startUndoBlock()

	local items = getArrayOfItems()

	for i = 0, #items do

		local item = items[i]
		unselectAllItems()
		reaper.SetMediaItemSelected(items[i], true)

		openMidiEditor()

		local _, numberOfNotes = reaper.MIDI_CountEvts(activeTake())

		for j = 0, numberOfNotes-1 do

			local _, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(activeTake(), j)

			local newVelocity = nil

			if noteIsOnStrongBeatForEighthNote(startppqpos) then
				newVelocity = 96
			else
				newVelocity = 80
			end

			reaper.MIDI_SetNote(activeTake(), j, selected, muted, startppqpos, endppqpos, channel, pitch, newVelocity)
		end

		closeMidiEditor()
	end


	reaper.UpdateArrange()

endUndoBlock()
