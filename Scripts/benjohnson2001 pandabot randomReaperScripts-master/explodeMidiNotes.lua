local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "explodeMidi"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function activeTake()
  return reaper.GetTake(selectedMediaItem(), 0)
end

function table.doesNotContain(table, element)
	for _, value in pairs(table) do
		if value == element then
			return false
		end
	end
	return true
end

function selectedMediaItem()
	return reaper.GetSelectedMediaItem(activeProjectIndex, 0)
end

function trackOfSelectedMediaItem()
	return reaper.GetMediaItem_Track(selectedMediaItem())
end

function trackNumberOfSelectedMediaItem()
	return reaper.GetMediaTrackInfo_Value(trackOfSelectedMediaItem(), "IP_TRACKNUMBER")
end

function insertTrack()
	reaper.InsertTrackAtIndex(trackNumberOfSelectedMediaItem(), false)
end

----

MidiNote = {}
MidiNote.__index = MidiNote

function MidiNote:new(selected, muted, startppqpos, endppqpos, channel, pitch, velocity)

  local self = {}
  setmetatable(self, MidiNote)

  self.selected = selected
  self.muted = muted
  self.startppqpos = startppqpos
  self.endppqpos = endppqpos
  self.channel = channel
  self.pitch = pitch
  self.velocity = velocity

  return self
end

----

local noteNames = {}
noteNames[127] = "G9"
noteNames[126] = "F#9"
noteNames[125] = "F9"
noteNames[124] = "E9"
noteNames[123] = "D#9"
noteNames[122] = "D9"
noteNames[121] = "C#9"
noteNames[120] = "C9"
noteNames[119] = "B8"
noteNames[118] = "A#8"
noteNames[117] = "A8"
noteNames[116] = "G#8"
noteNames[115] = "G8"
noteNames[114] = "F#8"
noteNames[113] = "F8"
noteNames[112] = "E8"
noteNames[111] = "D#8"
noteNames[110] = "D8"
noteNames[109] = "C#8"
noteNames[108] = "C8"
noteNames[107] = "B7"
noteNames[106] = "A#7"
noteNames[105] = "A7"
noteNames[104] = "G#7"
noteNames[103] = "G7"
noteNames[102] = "F#7"
noteNames[101] = "F7"
noteNames[100] = "E7"
noteNames[99] = "D#7"
noteNames[98] = "D7"
noteNames[97] = "C#7"
noteNames[96] = "C7"
noteNames[95] = "B6"
noteNames[94] = "A#6"
noteNames[93] = "A6"
noteNames[92] = "G#6"
noteNames[91] = "G6"
noteNames[90] = "F#6"
noteNames[89] = "F6"
noteNames[88] = "E6"
noteNames[87] = "D#6"
noteNames[86] = "D6"
noteNames[85] = "C#6"
noteNames[84] = "C6"
noteNames[83] = "B5"
noteNames[82] = "A#5"
noteNames[81] = "A5"
noteNames[80] = "G#5"
noteNames[79] = "G5"
noteNames[78] = "F#5"
noteNames[77] = "F5"
noteNames[76] = "E5"
noteNames[75] = "D#5"
noteNames[74] = "D5"
noteNames[73] = "C#5"
noteNames[72] = "C5"
noteNames[71] = "B4"
noteNames[70] = "A#4"
noteNames[69] = "A4"
noteNames[68] = "G#4"
noteNames[67] = "G4"
noteNames[66] = "F#4"
noteNames[65] = "F4"
noteNames[64] = "E4"
noteNames[63] = "D#4"
noteNames[62] = "D4"
noteNames[61] = "C#4"
noteNames[60] = "C4"
noteNames[59] = "B3"
noteNames[58] = "A#3"
noteNames[57] = "A3"
noteNames[56] = "G#3"
noteNames[55] = "G3"
noteNames[54] = "F#3"
noteNames[53] = "F3"
noteNames[52] = "E3"
noteNames[51] = "D#3"
noteNames[50] = "D3"
noteNames[49] = "C#3"
noteNames[48] = "C3"
noteNames[47] = "B2"
noteNames[46] = "A#2"
noteNames[45] = "A2"
noteNames[44] = "G#2"
noteNames[43] = "G2"
noteNames[42] = "F#2"
noteNames[41] = "F2"
noteNames[40] = "E2"
noteNames[39] = "D#2"
noteNames[38] = "D2"
noteNames[37] = "C#2"
noteNames[36] = "C2"
noteNames[35] = "B1"
noteNames[34] = "A#1"
noteNames[33] = "A1"
noteNames[32] = "G#1"
noteNames[31] = "G1"
noteNames[30] = "F#1"
noteNames[29] = "F1"
noteNames[28] = "E1"
noteNames[27] = "D#1"
noteNames[26] = "D1"
noteNames[25] = "C#1"
noteNames[24] = "C1"
noteNames[23] = "B0"
noteNames[22] = "A#0"
noteNames[21] = "A0"

function greaterThan(a, b)
	return a > b
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

function getItemPpq(item)
	local ppqLine = string.match(itemStateChunk(item), "HASDATA.*QN")
	return split(ppqLine, " ")[3]
end

function itemStateChunk(item)
	local stringArg = ""
	local isUndo = false
	local _, itemStateChunk = reaper.GetItemStateChunk(item, stringArg, isUndo)
	return itemStateChunk
end

function setPpq(item, newPpq)
	local originalItemStateChunk = itemStateChunk(item)
	local newItemStateChunk = string.gsub(originalItemStateChunk, "HASDATA 1 960 QN", "HASDATA 1 " .. newPpq .. " QN")
	reaper.SetItemStateChunk(item, newItemStateChunk, false)
end


function toggleLoopItemSource()
	local commandId = 40636
	reaper.Main_OnCommand(commandId, 0)
end


-----------------------------------------


startUndoBlock()


	local mainItem = selectedMediaItem()

	-- read the midi data
	local midiNotes = {}
	local pitches = {}

	local _, numberOfNotes = reaper.MIDI_CountEvts(activeTake())

	for i = 0, numberOfNotes-1 do

	  local _, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(activeTake(), i)
	  
	  if table.doesNotContain(midiNotes, pitch) then
		table.insert(midiNotes, pitch)
		midiNotes[pitch] = {}
	  end
	  
	  table.insert(midiNotes[pitch], MidiNote:new(selected, muted, startppqpos, endppqpos, channel, pitch, velocity))
		
	  if table.doesNotContain(pitches, pitch) then
		table.insert(pitches, pitch)
	  end
	end
	
	local startTime = reaper.GetMediaItemInfo_Value(selectedMediaItem(), "D_POSITION")
	local length = reaper.GetMediaItemInfo_Value(selectedMediaItem(), "D_LENGTH")
	local endTime = startTime + length
	local itemPpq = getItemPpq(selectedMediaItem())

    -- insert tracks
	insertTrack()
	for i = 1, #pitches do
		insertTrack()
	end
	insertTrack()
	

	-- name the tracks
	table.sort(pitches, greaterThan)
	for i = 1, #pitches do
		local track = reaper.GetTrack(activeProjectIndex, trackNumberOfSelectedMediaItem() + i)
		reaper.GetSetMediaTrackInfo_String(track, "P_NAME", noteNames[pitches[i]], true)
	end


	-- add items to tracks
	for i = 1, #pitches do
		local track = reaper.GetTrack(activeProjectIndex, trackNumberOfSelectedMediaItem() + i)
		local mediaItem = reaper.CreateNewMIDIItemInProj(track, startTime, endTime, false)
		local take = reaper.GetTake(mediaItem, 0)
		setPpq(mediaItem, itemPpq)
	
		for j = 1, #midiNotes[pitches[i]] do
			local midiNote = midiNotes[pitches[i]][j]
			reaper.MIDI_InsertNote(take, midiNote.selected, midiNote.muted, midiNote.startppqpos, midiNote.endppqpos, midiNote.channel, midiNote.pitch, midiNote.velocity, false)
		end
		
		reaper.SetMediaItemSelected(mediaItem, true)
		toggleLoopItemSource()
		toggleLoopItemSource()
		reaper.SetMediaItemSelected(mediaItem, false)
	end

reaper.SetMediaItemSelected(mainItem, true)

endUndoBlock()
reaper.UpdateArrange()
