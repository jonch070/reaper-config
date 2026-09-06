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
	local actionDescription = "chopUpLongNotesAccordingToMidi"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end


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

-----

local numberOfSelectedItems = reaper.CountSelectedMediaItems(activeProjectIndex)

if numberOfSelectedItems ~= 2 then
	print("please select 2 items")
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end


local takeIndex = 0

local firstItem = reaper.GetSelectedMediaItem(activeProjectIndex, 0)
local secondItem = reaper.GetSelectedMediaItem(activeProjectIndex, 1)

local firstItemTake = reaper.GetTake(firstItem, takeIndex)
local secondItemTake = reaper.GetTake(secondItem, takeIndex)

local midiItem = nil
local audioItem = nil

if reaper.TakeIsMIDI(firstItemTake) and not reaper.TakeIsMIDI(secondItemTake) then

	midiItem = firstItem
	audioItem = secondItem

elseif not reaper.TakeIsMIDI(firstItemTake) and reaper.TakeIsMIDI(secondItemTake) then

	midiItem = secondItem
	audioItem = firstItem
else

	print("please select 1 audio item and 1 midi item")
	reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
	return
end



----

MidiNote = {}
MidiNote.__index = MidiNote

function MidiNote:new(position, duration)

  local self = {}
  setmetatable(self, MidiNote)

  self.position = position
  self.duration = duration

  return self
end


--

startUndoBlock()

	local midiNotes = {}

	unselectAllItems()
	reaper.SetMediaItemSelected(midiItem, true)

	openMidiEditor()

	local _, numberOfNotes = reaper.MIDI_CountEvts(activeTake())

	for i = 0, numberOfNotes-1 do

		local _, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(activeTake(), i)

		local startPositionInSeconds =  reaper.MIDI_GetProjTimeFromPPQPos(activeTake(), startppqpos)
		local endPositionInSeconds =  reaper.MIDI_GetProjTimeFromPPQPos(activeTake(), endppqpos)
		local durationInSeconds = endPositionInSeconds-startPositionInSeconds

		table.insert(midiNotes, MidiNote:new(startPositionInSeconds, durationInSeconds))

	end

	closeMidiEditor()


	-- print("numberOfMidiNotes: " .. #midiNotes)




	unselectAllItems()
	reaper.SetMediaItemSelected(audioItem, true)


	local theCurrentAudioItem = nil

	for m = 1, #midiNotes do

		local midiNote = midiNotes[m]

		if m == 1 then
			reaper.SetMediaItemInfo_Value(audioItem, "D_POSITION", midiNote.position)
			theCurrentAudioItem = reaper.SplitMediaItem(audioItem, midiNote.position + midiNote.duration)
		else

			if theCurrentAudioItem == nil then
				return
			end

			reaper.SetMediaItemInfo_Value(theCurrentAudioItem, "D_POSITION", midiNote.position)
			theCurrentAudioItem = reaper.SplitMediaItem(theCurrentAudioItem, midiNote.position + midiNote.duration)
		end
	end

endUndoBlock()
