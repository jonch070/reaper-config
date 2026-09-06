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
	local actionDescription = "alignItemsAccordingToMidi"
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

local midiItem = nil
local midiItemIndex = nil
local takeIndex = 0

local audioItems = {}

for i = 0, numberOfSelectedItems - 1 do

	local theItem = reaper.GetSelectedMediaItem(activeProjectIndex, i)
	local theItemTake = reaper.GetTake(theItem, takeIndex)

	if reaper.TakeIsMIDI(theItemTake) then

			if midiItem ~= nil then
				print("please select just one midi item")
				reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)
				return
			end

		midiItem = theItem
		midiItemIndex = i
	else
		table.insert(audioItems, theItem)
	end
end

if midiItem == nil then
	print("please select a midi item")
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

	for m = 1, #midiNotes do

		

		local midiNote = midiNotes[m]

		local audioItem = audioItems[m]

		if audioItem == nil then
			endUndoBlock()
			return
		end

		unselectAllItems()
		reaper.SetMediaItemSelected(audioItem, true)
		reaper.SetMediaItemInfo_Value(audioItem, "D_POSITION", midiNote.position)
	end



	-- move the unused audio items to the right

	local lastMidiNote = midiNotes[#midiNotes]
	local rightBoundary = lastMidiNote.position + lastMidiNote.duration

	for j = 1, #audioItems do

		if j > #midiNotes then

			unselectAllItems()

			local audioItem = audioItems[j]
			unselectAllItems()
			reaper.SetMediaItemSelected(audioItem, true)

			local audioItemPosition = reaper.GetMediaItemInfo_Value(audioItem, "D_POSITION")
			local newPosition = rightBoundary + audioItemPosition

			reaper.SetMediaItemInfo_Value(audioItem, "D_POSITION", newPosition)
		end
	end


endUndoBlock()
