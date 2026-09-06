-- @noindex

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "glueNotesAndRenameFiles"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
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

--

function unselectAllItems()

	local commandId = 40289
  reaper.Main_OnCommand(commandId, 0)
end

function glueItems()

	local commandId = 41588
  reaper.Main_OnCommand(commandId, 0)
end

function getFileNameOfGluedItem(trackName)

	if trackName == "[8]" then
		return "wurlieNotes-001-glued.wav"
	elseif trackName == "[23]" then
		return "wurlieNotes-002-glued.wav"
	elseif trackName == "[38]" then
		return "wurlieNotes-003-glued.wav"
	elseif trackName == "[53]" then
		return "wurlieNotes-004-glued.wav"
	elseif trackName == "[68]" then
		return "wurlieNotes-005-glued.wav"
	elseif trackName == "[85]" then
		return "wurlieNotes-006-glued.wav"
	elseif trackName == "[101]" then
		return "wurlieNotes-007-glued.wav"
	elseif trackName == "[115]" then
		return "wurlieNotes-008-glued.wav"
	elseif trackName == "[124]" then
		return "wurlieNotes-009-glued.wav"
	elseif trackName == "[127]" then
		return "wurlieNotes-010-glued.wav"
	end
end

function getFileNameOfGluedItemForBass(trackName)

	if trackName == "[8]" then
		return "wurlieBassNotes-001-glued.wav"
	elseif trackName == "[23]" then
		return "wurlieBassNotes-002-glued.wav"
	elseif trackName == "[38]" then
		return "wurlieBassNotes-003-glued.wav"
	elseif trackName == "[53]" then
		return "wurlieBassNotes-004-glued.wav"
	elseif trackName == "[68]" then
		return "wurlieBassNotes-005-glued.wav"
	elseif trackName == "[85]" then
		return "wurlieBassNotes-006-glued.wav"
	elseif trackName == "[101]" then
		return "wurlieBassNotes-007-glued.wav"
	elseif trackName == "[115]" then
		return "wurlieBassNotes-008-glued.wav"
	elseif trackName == "[124]" then
		return "wurlieBassNotes-009-glued.wav"
	elseif trackName == "[127]" then
		return "wurlieBassNotes-010-glued.wav"
	end
end

function getTargetFileName(noteIndex, trackName)

	if noteIndex == 0 then
		return "A1_" .. trackName .. ".wav"
	elseif noteIndex == 1 then
		return "A#1_" .. trackName .. ".wav"
	elseif noteIndex == 2 then
		return "B1_" .. trackName .. ".wav"
	elseif noteIndex == 3 then
		return "C2_" .. trackName .. ".wav"
	elseif noteIndex == 4 then
		return "C#2_" .. trackName .. ".wav"
	elseif noteIndex == 5 then
		return "D2_" .. trackName .. ".wav"
	elseif noteIndex == 6 then
		return "D#2_" .. trackName .. ".wav"
	elseif noteIndex == 7 then
		return "E2_" .. trackName .. ".wav"
	elseif noteIndex == 8 then
		return "F2_" .. trackName .. ".wav"
	elseif noteIndex == 9 then
		return "F#2_" .. trackName .. ".wav"
	elseif noteIndex == 10 then
		return "G2_" .. trackName .. ".wav"
	elseif noteIndex == 11 then
		return "G#2_" .. trackName .. ".wav"
	elseif noteIndex == 12 then
		return "A2_" .. trackName .. ".wav"
	elseif noteIndex == 13 then
		return "A#2_" .. trackName .. ".wav"
	elseif noteIndex == 14 then
		return "B2_" .. trackName .. ".wav"
	elseif noteIndex == 15 then
		return "C3_" .. trackName .. ".wav"
	elseif noteIndex == 16 then
		return "C#3_" .. trackName .. ".wav"
	elseif noteIndex == 17 then
		return "D3_" .. trackName .. ".wav"
	elseif noteIndex == 18 then
		return "D#3_" .. trackName .. ".wav"
	elseif noteIndex == 19 then
		return "E3_" .. trackName .. ".wav"
	elseif noteIndex == 20 then
		return "F3_" .. trackName .. ".wav"
	elseif noteIndex == 21 then
		return "F#3_" .. trackName .. ".wav"
	elseif noteIndex == 22 then
		return "G3_" .. trackName .. ".wav"
	elseif noteIndex == 23 then
		return "G#3_" .. trackName .. ".wav"
	elseif noteIndex == 24 then
		return "A3_" .. trackName .. ".wav"
	elseif noteIndex == 25 then
		return "A#3_" .. trackName .. ".wav"
	elseif noteIndex == 26 then
		return "B3_" .. trackName .. ".wav"
	elseif noteIndex == 27 then
		return "C4_" .. trackName .. ".wav"
	elseif noteIndex == 28 then
		return "C#4_" .. trackName .. ".wav"
	elseif noteIndex == 29 then
		return "D4_" .. trackName .. ".wav"
	elseif noteIndex == 30 then
		return "D#4_" .. trackName .. ".wav"
	elseif noteIndex == 31 then
		return "E4_" .. trackName .. ".wav"
	elseif noteIndex == 32 then
		return "F4_" .. trackName .. ".wav"
	elseif noteIndex == 33 then
		return "F#4_" .. trackName .. ".wav"
	elseif noteIndex == 34 then
		return "G4_" .. trackName .. ".wav"
	elseif noteIndex == 35 then
		return "G#4_" .. trackName .. ".wav"
	elseif noteIndex == 36 then
		return "A4_" .. trackName .. ".wav"
	elseif noteIndex == 37 then
		return "A#4_" .. trackName .. ".wav"
	elseif noteIndex == 38 then
		return "B4_" .. trackName .. ".wav"
	elseif noteIndex == 39 then
		return "C5_" .. trackName .. ".wav"
	elseif noteIndex == 40 then
		return "C#5_" .. trackName .. ".wav"
	elseif noteIndex == 41 then
		return "D5_" .. trackName .. ".wav"
	elseif noteIndex == 42 then
		return "D#5_" .. trackName .. ".wav"
	elseif noteIndex == 43 then
		return "E5_" .. trackName .. ".wav"
	elseif noteIndex == 44 then
		return "F5_" .. trackName .. ".wav"
	elseif noteIndex == 45 then
		return "F#5_" .. trackName .. ".wav"
	elseif noteIndex == 46 then
		return "G5_" .. trackName .. ".wav"
	elseif noteIndex == 47 then
		return "G#5_" .. trackName .. ".wav"
	elseif noteIndex == 48 then
		return "A5_" .. trackName .. ".wav"
	elseif noteIndex == 49 then
		return "A#5_" .. trackName .. ".wav"
	elseif noteIndex == 50 then
		return "B5_" .. trackName .. ".wav"
	elseif noteIndex == 51 then
		return "C6_" .. trackName .. ".wav"
	elseif noteIndex == 52 then
		return "C#6_" .. trackName .. ".wav"
	elseif noteIndex == 53 then
		return "D6_" .. trackName .. ".wav"
	elseif noteIndex == 54 then
		return "D#6_" .. trackName .. ".wav"
	elseif noteIndex == 55 then
		return "E6_" .. trackName .. ".wav"
	elseif noteIndex == 56 then
		return "F6_" .. trackName .. ".wav"
	elseif noteIndex == 57 then
		return "F#6_" .. trackName .. ".wav"
	elseif noteIndex == 58 then
		return "G6_" .. trackName .. ".wav"
	elseif noteIndex == 59 then
		return "G#6_" .. trackName .. ".wav"
	elseif noteIndex == 60 then
		return "A6_" .. trackName .. ".wav"
	elseif noteIndex == 61 then
		return "A#6_" .. trackName .. ".wav"
	elseif noteIndex == 62 then
		return "B6_" .. trackName .. ".wav"
	elseif noteIndex == 63 then
		return "C7_" .. trackName .. ".wav"
	end
end

function getTargetFileNameForBass(noteIndex, trackName)

	if noteIndex == 0 then
		return "bass_A1_" .. trackName .. ".wav"
	elseif noteIndex == 1 then
		return "bass_A#1_" .. trackName .. ".wav"
	elseif noteIndex == 2 then
		return "bass_B1_" .. trackName .. ".wav"
	elseif noteIndex == 3 then
		return "bass_C2_" .. trackName .. ".wav"
	elseif noteIndex == 4 then
		return "bass_C#2_" .. trackName .. ".wav"
	elseif noteIndex == 5 then
		return "bass_D2_" .. trackName .. ".wav"
	elseif noteIndex == 6 then
		return "bass_D#2_" .. trackName .. ".wav"
	elseif noteIndex == 7 then
		return "bass_E2_" .. trackName .. ".wav"
	elseif noteIndex == 8 then
		return "bass_F2_" .. trackName .. ".wav"
	elseif noteIndex == 9 then
		return "bass_F#2_" .. trackName .. ".wav"
	elseif noteIndex == 10 then
		return "bass_G2_" .. trackName .. ".wav"
	elseif noteIndex == 11 then
		return "bass_G#2_" .. trackName .. ".wav"
	elseif noteIndex == 12 then
		return "bass_A2_" .. trackName .. ".wav"
	elseif noteIndex == 13 then
		return "bass_A#2_" .. trackName .. ".wav"
	elseif noteIndex == 14 then
		return "bass_B2_" .. trackName .. ".wav"
	elseif noteIndex == 15 then
		return "bass_C3_" .. trackName .. ".wav"
	elseif noteIndex == 16 then
		return "bass_C#3_" .. trackName .. ".wav"
	elseif noteIndex == 17 then
		return "bass_D3_" .. trackName .. ".wav"
	elseif noteIndex == 18 then
		return "bass_D#3_" .. trackName .. ".wav"
	elseif noteIndex == 19 then
		return "bass_E3_" .. trackName .. ".wav"
	elseif noteIndex == 20 then
		return "bass_F3_" .. trackName .. ".wav"
	elseif noteIndex == 21 then
		return "bass_F#3_" .. trackName .. ".wav"
	elseif noteIndex == 22 then
		return "bass_G3_" .. trackName .. ".wav"
	elseif noteIndex == 23 then
		return "bass_G#3_" .. trackName .. ".wav"
	elseif noteIndex == 24 then
		return "bass_A3_" .. trackName .. ".wav"
	elseif noteIndex == 25 then
		return "bass_A#3_" .. trackName .. ".wav"
	elseif noteIndex == 26 then
		return "bass_B3_" .. trackName .. ".wav"
	elseif noteIndex == 27 then
		return "bass_C4_" .. trackName .. ".wav"
	elseif noteIndex == 28 then
		return "bass_C#4_" .. trackName .. ".wav"
	elseif noteIndex == 29 then
		return "bass_D4_" .. trackName .. ".wav"
	elseif noteIndex == 30 then
		return "bass_D#4_" .. trackName .. ".wav"
	elseif noteIndex == 31 then
		return "bass_E4_" .. trackName .. ".wav"
	elseif noteIndex == 32 then
		return "bass_F4_" .. trackName .. ".wav"
	elseif noteIndex == 33 then
		return "bass_F#4_" .. trackName .. ".wav"
	elseif noteIndex == 34 then
		return "bass_G4_" .. trackName .. ".wav"
	elseif noteIndex == 35 then
		return "bass_G#4_" .. trackName .. ".wav"
	elseif noteIndex == 36 then
		return "bass_A4_" .. trackName .. ".wav"
	elseif noteIndex == 37 then
		return "bass_A#4_" .. trackName .. ".wav"
	elseif noteIndex == 38 then
		return "bass_B4_" .. trackName .. ".wav"
	elseif noteIndex == 39 then
		return "bass_C5_" .. trackName .. ".wav"
	elseif noteIndex == 40 then
		return "bass_C#5_" .. trackName .. ".wav"
	elseif noteIndex == 41 then
		return "bass_D5_" .. trackName .. ".wav"
	elseif noteIndex == 42 then
		return "bass_D#5_" .. trackName .. ".wav"
	elseif noteIndex == 43 then
		return "bass_E5_" .. trackName .. ".wav"
	elseif noteIndex == 44 then
		return "bass_F5_" .. trackName .. ".wav"
	elseif noteIndex == 45 then
		return "bass_F#5_" .. trackName .. ".wav"
	elseif noteIndex == 46 then
		return "bass_G5_" .. trackName .. ".wav"
	elseif noteIndex == 47 then
		return "bass_G#5_" .. trackName .. ".wav"
	elseif noteIndex == 48 then
		return "bass_A5_" .. trackName .. ".wav"
	elseif noteIndex == 49 then
		return "bass_A#5_" .. trackName .. ".wav"
	elseif noteIndex == 50 then
		return "bass_B5_" .. trackName .. ".wav"
	elseif noteIndex == 51 then
		return "bass_C6_" .. trackName .. ".wav"
	elseif noteIndex == 52 then
		return "bass_C#6_" .. trackName .. ".wav"
	elseif noteIndex == 53 then
		return "bass_D6_" .. trackName .. ".wav"
	elseif noteIndex == 54 then
		return "bass_D#6_" .. trackName .. ".wav"
	elseif noteIndex == 55 then
		return "bass_E6_" .. trackName .. ".wav"
	elseif noteIndex == 56 then
		return "bass_F6_" .. trackName .. ".wav"
	elseif noteIndex == 57 then
		return "bass_F#6_" .. trackName .. ".wav"
	elseif noteIndex == 58 then
		return "bass_G6_" .. trackName .. ".wav"
	elseif noteIndex == 59 then
		return "bass_G#6_" .. trackName .. ".wav"
	elseif noteIndex == 60 then
		return "bass_A6_" .. trackName .. ".wav"
	elseif noteIndex == 61 then
		return "bass_A#6_" .. trackName .. ".wav"
	elseif noteIndex == 62 then
		return "bass_B6_" .. trackName .. ".wav"
	elseif noteIndex == 63 then
		return "bass_C7_" .. trackName .. ".wav"
	end
end

-- function sleep(arg) 
-- 	local sec = tonumber(os.clock() + arg); 
-- 	while (os.clock() < sec) do 
-- 	end 
-- end

function getPositionAtBar(arg)

	local tpos = 0
	return reaper.TimeMap2_beatsToTime(activeProjectIndex, tpos, arg-1)
end

startUndoBlock()

	local destinationTrackIndex = 27
	local destinationBarNumber = 39

	-- print(getPositionAtBar(destinationBarNumber))
	-- print(getPositionAtBar(destinationBarNumber+12))

	-- if true then
	-- 	return
	-- end

	local workingDirectory = reaper.GetProjectPath("") .. "/"
	local items = getArrayOfItems()

	local noteIndex = 0
	local trackIndex = 0
	local previousTrackName = "[8]"
	for i = 0, #items do

		local trackOfItem = reaper.GetMediaItem_Track(items[i])
		local _, trackName = reaper.GetTrackName(trackOfItem)

		if trackName ~= previousTrackName then
			noteIndex = 0
			trackIndex = trackIndex + 1
			previousTrackName = trackName
		end

		local fileNameOfGluedItem = getFileNameOfGluedItem(trackName)
		-- local fileNameOfGluedItem = getFileNameOfGluedItemForBass(trackName)
		
		unselectAllItems()
		reaper.SetMediaItemSelected(items[i], true)
		glueItems()

		local targetFileName = getTargetFileName(noteIndex, trackName)
		-- local targetFileName = getTargetFileNameForBass(noteIndex, trackName)

		os.rename(workingDirectory .. fileNameOfGluedItem, workingDirectory .. targetFileName)
		os.remove(workingDirectory .. fileNameOfGluedItem .. ".reapeaks")

		local doNotMoveTheEditCursor = 0
		local useTheLengthOfTheSourceFile = -1
		ultraschall.InsertMediaItemFromFile(workingDirectory .. targetFileName, destinationTrackIndex + trackIndex, getPositionAtBar(destinationBarNumber + noteIndex*12), useTheLengthOfTheSourceFile, doNotMoveTheEditCursor)

		noteIndex = noteIndex + 1
	end

	--

endUndoBlock()