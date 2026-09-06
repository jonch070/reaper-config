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
noteNames[81] = "open triangle"
noteNames[80] = "mute triangle"
noteNames[79] = "open cuica"
noteNames[78] = "mute cuica"
noteNames[77] = "low wood block"
noteNames[76] = "hi wood block"
noteNames[75] = "claves"
noteNames[74] = "long guiro"
noteNames[73] = "short guiro"
noteNames[72] = "long whistle"
noteNames[71] = "short whistle"
noteNames[70] = "maracas"
noteNames[69] = "cabasa"
noteNames[68] = "low agogo"
noteNames[67] = "high agogo"
noteNames[66] = "low timbale"
noteNames[65] = "high timbale"
noteNames[64] = "low conga"
noteNames[63] = "open hi conga"
noteNames[62] = "mute hi conga"
noteNames[61] = "low bongo"
noteNames[60] = "hi bongo"
noteNames[59] = "ride cymbal 2"
noteNames[58] = "vibraslap"
noteNames[57] = "crash cymbal 2"
noteNames[56] = "cowbell"
noteNames[55] = "splash cymbal"
noteNames[54] = "tambourine"
noteNames[53] = "ride bell"
noteNames[52] = "chinese cymbal"
noteNames[51] = "ride cymbal 1"
noteNames[50] = "high tom"
noteNames[49] = "crash cymbal 1"
noteNames[48] = "hi-mid tom"
noteNames[47] = "low-mid tom"
noteNames[46] = "open hihat"
noteNames[45] = "low tom"
noteNames[44] = "pedal hihat"
noteNames[43] = "high floor tom"
noteNames[42] = "closed hihat"
noteNames[41] = "low floor tom"
noteNames[40] = "electric snare"
noteNames[39] = "hand clap"
noteNames[38] = "acoustic snare"
noteNames[37] = "side stick"
noteNames[36] = "bass drum"
noteNames[35] = "acoustic bass drum"


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
