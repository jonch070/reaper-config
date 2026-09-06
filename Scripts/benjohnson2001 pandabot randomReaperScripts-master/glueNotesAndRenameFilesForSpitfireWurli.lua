-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "glueNotesAndRenameFilesForSpitfireWurli"
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

function getNoteName(noteIndex)

	if noteIndex == 0 then
		return "A1"
	elseif noteIndex == 1 then
		return "A#1"
	elseif noteIndex == 2 then
		return "B1"
	elseif noteIndex == 3 then
		return "C2"
	elseif noteIndex == 4 then
		return "C#2"
	elseif noteIndex == 5 then
		return "D2"
	elseif noteIndex == 6 then
		return "D#2"
	elseif noteIndex == 7 then
		return "E2"
	elseif noteIndex == 8 then
		return "F2"
	elseif noteIndex == 9 then
		return "F#2"
	elseif noteIndex == 10 then
		return "G2"
	elseif noteIndex == 11 then
		return "G#2"
	elseif noteIndex == 12 then
		return "A2"
	elseif noteIndex == 13 then
		return "A#2"
	elseif noteIndex == 14 then
		return "B2"
	elseif noteIndex == 15 then
		return "C3"
	elseif noteIndex == 16 then
		return "C#3"
	elseif noteIndex == 17 then
		return "D3"
	elseif noteIndex == 18 then
		return "D#3"
	elseif noteIndex == 19 then
		return "E3"
	elseif noteIndex == 20 then
		return "F3"
	elseif noteIndex == 21 then
		return "F#3"
	elseif noteIndex == 22 then
		return "G3"
	elseif noteIndex == 23 then
		return "G#3"
	elseif noteIndex == 24 then
		return "A3"
	elseif noteIndex == 25 then
		return "A#3"
	elseif noteIndex == 26 then
		return "B3"
	elseif noteIndex == 27 then
		return "C4"
	elseif noteIndex == 28 then
		return "C#4"
	elseif noteIndex == 29 then
		return "D4"
	elseif noteIndex == 30 then
		return "D#4"
	elseif noteIndex == 31 then
		return "E4"
	elseif noteIndex == 32 then
		return "F4"
	elseif noteIndex == 33 then
		return "F#4"
	elseif noteIndex == 34 then
		return "G4"
	elseif noteIndex == 35 then
		return "G#4"
	elseif noteIndex == 36 then
		return "A4"
	elseif noteIndex == 37 then
		return "A#4"
	elseif noteIndex == 38 then
		return "B4"
	elseif noteIndex == 39 then
		return "C5"
	elseif noteIndex == 40 then
		return "C#5"
	elseif noteIndex == 41 then
		return "D5"
	elseif noteIndex == 42 then
		return "D#5"
	elseif noteIndex == 43 then
		return "E5"
	elseif noteIndex == 44 then
		return "F5"
	elseif noteIndex == 45 then
		return "F#5"
	elseif noteIndex == 46 then
		return "G5"
	elseif noteIndex == 47 then
		return "G#5"
	elseif noteIndex == 48 then
		return "A5"
	elseif noteIndex == 49 then
		return "A#5"
	elseif noteIndex == 50 then
		return "B5"
	elseif noteIndex == 51 then
		return "C6"
	elseif noteIndex == 52 then
		return "C#6"
	elseif noteIndex == 53 then
		return "D6"
	elseif noteIndex == 54 then
		return "D#6"
	elseif noteIndex == 55 then
		return "E6"
	elseif noteIndex == 56 then
		return "F6"
	elseif noteIndex == 57 then
		return "F#6"
	elseif noteIndex == 58 then
		return "G6"
	elseif noteIndex == 59 then
		return "G#6"
	elseif noteIndex == 60 then
		return "A6"
	elseif noteIndex == 61 then
		return "A#6"
	elseif noteIndex == 62 then
		return "B6"
	elseif noteIndex == 63 then
		return "C7"
	end
end

function getVariationSuffix(arg)

	if arg == 1 then
		return "A"
	elseif arg == 2 then
		return "B"
	elseif arg == 3 then
		return "C"
	elseif arg == 4 then
		return "D"
	else
		error("don't recognize " .. arg .. " for getting a suffix")
	end
end

function removeReapeaks()

	local workingDirectory = reaper.GetProjectPath("") .. "/peaks"
	local p = io.popen('find "' .. workingDirectory .. '" -type f')
 	for file in p:lines() do

 		if string.match(file, "glued") and string.match(file, "reapeaks") then
			os.remove(file)
 		end
 	end
end


startUndoBlock()

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
		
		unselectAllItems()
		reaper.SetMediaItemSelected(items[i], true)
		glueItems()

		local workingDirectory = reaper.GetProjectPath("")
		local gluedFileNameIndex = 1
		local gluedFileNames = {}
		local p = io.popen('find "' .. workingDirectory .. '" -type f')
   	for file in p:lines() do

   		if string.match(file, "glued") and not string.match(file, "reapeaks") then
   			table.insert(gluedFileNames, file)
   			gluedFileNameIndex = gluedFileNameIndex + 1
   		end
   	end

   	for m = 1, #gluedFileNames do

   		local fileNameOfGluedItem = gluedFileNames[m]
   		local prefix = "spitfireWurli_"
   		local variationSuffix = getVariationSuffix((i % 4) + 1)

   		local targetFileName = prefix .. getNoteName(noteIndex) .. "_" .. trackName .. "_" .. variationSuffix .. ".wav"
   		os.rename(fileNameOfGluedItem, workingDirectory .. "/" .. targetFileName)
   	end

   	removeReapeaks()

   	if (i+1) % 4 == 0 then
			noteIndex = noteIndex + 1
   	end
	end

	--

endUndoBlock()