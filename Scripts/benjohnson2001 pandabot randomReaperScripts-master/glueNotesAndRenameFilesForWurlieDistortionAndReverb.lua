-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "glueNotesAndRenameFilesForWurlieDistortionAndReverb"
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

function removeReapeaks()

	local workingDirectory = reaper.GetProjectPath("") .. "/peaks"
	local p = io.popen('find "' .. workingDirectory .. '" -type f')
 	for file in p:lines() do

 		if string.match(file, "glued") and string.match(file, "reapeaks") then
			os.remove(file)
 		end
 	end
end

function getCorrespondingValue(arg)

   if arg == 0 then
      return "00"
   elseif arg == 1 then
      return "01"
   elseif arg == 2 then
      return "02"
   elseif arg == 3 then
      return "03"
   elseif arg == 4 then
      return "04"
   elseif arg == 5 then
      return "05"
   elseif arg == 6 then
      return "06"
   elseif arg == 7 then
      return "07"
   elseif arg == 8 then
      return "08"
   elseif arg == 9 then
      return "09"
   elseif arg == 10 then
      return "10"
  end
end

startUndoBlock()

	local workingDirectory = reaper.GetProjectPath("") .. "/"
	local items = getArrayOfItems()

	local previousTrackName = "[8]"

   local distortionIndex = 0
   local reverbIndex = 0

	for i = 0, #items do

		local trackOfItem = reaper.GetMediaItem_Track(items[i])
		local _, trackName = reaper.GetTrackName(trackOfItem)

		if trackName ~= previousTrackName then
         distortionIndex = 0
         reverbIndex = 0
		end

      if (reverbIndex+1) % 12 == 0 then
         reverbIndex = 0
         distortionIndex = distortionIndex + 1
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

   		local targetFileName = trackName .. "_d" .. getCorrespondingValue(distortionIndex) .. "_r" .. getCorrespondingValue(reverbIndex) .. ".wav"
   		os.rename(fileNameOfGluedItem, workingDirectory .. "/" .. targetFileName)
   	end

   	removeReapeaks()

      reverbIndex = reverbIndex + 1
      previousTrackName = trackName
	end

	--

endUndoBlock()