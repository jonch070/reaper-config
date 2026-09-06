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
	local actionDescription = "glueNotesAndRenameFilesForRockStandard"
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


function doesNotHaveKey(table, arg)

	for index, value in pairs(table) do

		if index == tostring(arg) then
			return false
		end
	end
	
	return true
end

function doesNotHaveValue(table, arg)

	for index, value in pairs(table) do

		if value == arg then
			return false
		end
	end
	
	return true
end

function getColumnIndexMap()

	local items = getArrayOfItems()
	local columnIndexMap = {}

	local columnIndex = 1
	for i = 0, #items do

		local itemStartingPosition = reaper.GetMediaItemInfo_Value(items[i], "D_POSITION")

		if doesNotHaveKey(columnIndexMap, itemStartingPosition) then
			columnIndexMap[tostring(itemStartingPosition)] = columnIndex
			columnIndex = columnIndex + 1
		end
	end

	return columnIndexMap
end

function getItemColumns()

	local items = getArrayOfItems()
	local columnIndexMap = getColumnIndexMap()
	local columns = {}

	for i = 0, #items do

		local itemStartingPosition = reaper.GetMediaItemInfo_Value(items[i], "D_POSITION")
		local columnIndex = columnIndexMap[tostring(itemStartingPosition)]
		
		if columns[columnIndex] == nil then
			columns[columnIndex] = {}
		end

		table.insert(columns[columnIndex], items[i])
	end

	return columns
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

function getTargetFileName(columnIndex)


	-- string 1
	if columnIndex == 1 then
		return "string1_fret0_E2_40"
	elseif columnIndex == 2 then
		return "string1_fret1_F2_41"
	elseif columnIndex == 3 then
		return "string1_fret2_F#2_42"
	elseif columnIndex == 4 then
		return "string1_fret3_G2_43"
	elseif columnIndex == 5 then
		return "string1_fret4_G#2_44"
	elseif columnIndex == 6 then
		return "string1_fret5_A2_45"
	elseif columnIndex == 7 then
		return "string1_fret6_A#2_46"
	elseif columnIndex == 8 then
		return "string1_fret7_B2_47"
	elseif columnIndex == 9 then
		return "string1_fret8_C3_48"
	elseif columnIndex == 10 then
		return "string1_fret9_C#3_49"
	elseif columnIndex == 11 then
		return "string1_fret10_D3_50"
	elseif columnIndex == 12 then
		return "string1_fret11_D#3_51"
	elseif columnIndex == 13 then
		return "string1_fret12_E3_52"
	elseif columnIndex == 14 then
		return "string1_fret13_F3_53"
	elseif columnIndex == 15 then
		return "string1_fret14_F#3_54"
	elseif columnIndex == 16 then
		return "string1_fret15_G3_55"
	elseif columnIndex == 17 then
		return "string1_fret16_G#3_56"
	elseif columnIndex == 18 then
		return "string1_fret17_A3_57"
	elseif columnIndex == 19 then
		return "string1_fret18_A#3_58"
	elseif columnIndex == 20 then
		return "string1_fret19_B3_59"
	elseif columnIndex == 21 then
		return "string1_fret20_C4_60"
	elseif columnIndex == 22 then
		return "string1_fret21_C#4_61"
	elseif columnIndex == 23 then
		return "string1_fret22_D4_62"


	-- string 2
	elseif columnIndex == 24 then
		return "string2_fret0_A2_45"
	elseif columnIndex == 25 then
		return "string2_fret1_A#2_46"
	elseif columnIndex == 26 then
		return "string2_fret2_B2_47"
	elseif columnIndex == 27 then
		return "string2_fret3_C3_48"
	elseif columnIndex == 28 then
		return "string2_fret4_C#3_49"
	elseif columnIndex == 29 then
		return "string2_fret5_D3_50"
	elseif columnIndex == 30 then
		return "string2_fret6_D#3_51"
	elseif columnIndex == 31 then
		return "string2_fret7_E3_52"
	elseif columnIndex == 32 then
		return "string2_fret8_F3_53"
	elseif columnIndex == 33 then
		return "string2_fret9_F#3_54"
	elseif columnIndex == 34 then
		return "string2_fret10_G3_55"
	elseif columnIndex == 35 then
		return "string2_fret11_G#3_56"
	elseif columnIndex == 36 then
		return "string2_fret12_A3_57"
	elseif columnIndex == 37 then
		return "string2_fret13_A#3_58"
	elseif columnIndex == 38 then
		return "string2_fret14_B3_59"
	elseif columnIndex == 39 then
		return "string2_fret15_C4_60"
	elseif columnIndex == 40 then
		return "string2_fret16_C#4_61"
	elseif columnIndex == 41 then
		return "string2_fret17_D4_62"
	elseif columnIndex == 42 then
		return "string2_fret18_D#4_63"
	elseif columnIndex == 43 then
		return "string2_fret19_E4_64"
	elseif columnIndex == 44 then
		return "string2_fret20_F4_65"
	elseif columnIndex == 45 then
		return "string2_fret21_F#4_66"
	elseif columnIndex == 46 then
		return "string2_fret22_G4_67"


	-- string 3
	elseif columnIndex == 47 then
		return "string3_fret0_D3_50"
	elseif columnIndex == 48 then
		return "string3_fret1_D#3_51"
	elseif columnIndex == 49 then
		return "string3_fret2_E3_52"
	elseif columnIndex == 50 then
		return "string3_fret3_F3_53"
	elseif columnIndex == 51 then
		return "string3_fret4_F#3_54"
	elseif columnIndex == 52 then
		return "string3_fret5_G3_55"
	elseif columnIndex == 53 then
		return "string3_fret6_G#3_56"
	elseif columnIndex == 54 then
		return "string3_fret7_A3_57"
	elseif columnIndex == 55 then
		return "string3_fret8_A#3_58"
	elseif columnIndex == 56 then
		return "string3_fret9_B3_59"
	elseif columnIndex == 57 then
		return "string3_fret10_C4_60"
	elseif columnIndex == 58 then
		return "string3_fret11_C#4_61"
	elseif columnIndex == 59 then
		return "string3_fret12_D4_62"
	elseif columnIndex == 60 then
		return "string3_fret13_D#4_63"
	elseif columnIndex == 61 then
		return "string3_fret14_E4_64"
	elseif columnIndex == 62 then
		return "string3_fret15_F4_65"
	elseif columnIndex == 63 then
		return "string3_fret16_F#4_66"
	elseif columnIndex == 64 then
		return "string3_fret17_G4_67"
	elseif columnIndex == 65 then
		return "string3_fret18_G#4_68"
	elseif columnIndex == 66 then
		return "string3_fret19_A4_69"
	elseif columnIndex == 67 then
		return "string3_fret20_A#4_70"
	elseif columnIndex == 68 then
		return "string3_fret21_B4_71"
	elseif columnIndex == 69 then
		return "string3_fret22_C5_72"


	-- string 4
	elseif columnIndex == 70 then
		return "string4_fret0_G3_55"
	elseif columnIndex == 71 then
		return "string4_fret1_G#3_56"
	elseif columnIndex == 72 then
		return "string4_fret2_A3_57"
	elseif columnIndex == 73 then
		return "string4_fret3_A#3_58"
	elseif columnIndex == 74 then
		return "string4_fret4_B3_59"
	elseif columnIndex == 75 then
		return "string4_fret5_C4_60"
	elseif columnIndex == 76 then
		return "string4_fret6_C#4_61"
	elseif columnIndex == 77 then
		return "string4_fret7_D4_62"
	elseif columnIndex == 78 then
		return "string4_fret8_D#4_63"
	elseif columnIndex == 79 then
		return "string4_fret9_E4_64"
	elseif columnIndex == 80 then
		return "string4_fret10_F4_65"
	elseif columnIndex == 81 then
		return "string4_fret11_F#4_66"
	elseif columnIndex == 82 then
		return "string4_fret12_G4_67"
	elseif columnIndex == 83 then
		return "string4_fret13_G#4_68"
	elseif columnIndex == 84 then
		return "string4_fret14_A4_69"
	elseif columnIndex == 85 then
		return "string4_fret15_A#4_70"
	elseif columnIndex == 86 then
		return "string4_fret16_B4_71"
	elseif columnIndex == 87 then
		return "string4_fret17_C5_72"
	elseif columnIndex == 88 then
		return "string4_fret18_C#5_73"
	elseif columnIndex == 89 then
		return "string4_fret19_D5_74"
	elseif columnIndex == 90 then
		return "string4_fret20_D#5_75"
	elseif columnIndex == 91 then
		return "string4_fret21_E5_76"
	elseif columnIndex == 92 then
		return "string4_fret22_F5_77"


	-- string 5
	elseif columnIndex == 93 then
		return "string5_fret0_B3_59"
	elseif columnIndex == 94 then
		return "string5_fret1_C4_60"
	elseif columnIndex == 95 then
		return "string5_fret2_C#4_61"
	elseif columnIndex == 96 then
		return "string5_fret3_D4_62"
	elseif columnIndex == 97 then
		return "string5_fret4_D#4_63"
	elseif columnIndex == 98 then
		return "string5_fret5_E4_64"
	elseif columnIndex == 99 then
		return "string5_fret6_F4_65"
	elseif columnIndex == 100 then
		return "string5_fret7_F#4_66"
	elseif columnIndex == 101 then
		return "string5_fret8_G4_67"
	elseif columnIndex == 102 then
		return "string5_fret9_G#4_68"
	elseif columnIndex == 103 then
		return "string5_fret10_A4_69"
	elseif columnIndex == 104 then
		return "string5_fret11_A#4_70"
	elseif columnIndex == 105 then
		return "string5_fret12_B4_71"
	elseif columnIndex == 106 then
		return "string5_fret13_C5_72"
	elseif columnIndex == 107 then
		return "string5_fret14_C#5_73"
	elseif columnIndex == 108 then
		return "string5_fret15_D5_74"
	elseif columnIndex == 109 then
		return "string5_fret16_D#5_75"
	elseif columnIndex == 110 then
		return "string5_fret17_E5_76"
	elseif columnIndex == 111 then
		return "string5_fret18_F5_77"
	elseif columnIndex == 112 then
		return "string5_fret19_F#5_78"
	elseif columnIndex == 113 then
		return "string5_fret20_G5_79"
	elseif columnIndex == 114 then
		return "string5_fret21_G#5_80"
	elseif columnIndex == 115 then
		return "string5_fret22_A5_81"


	-- string 6
	elseif columnIndex == 116 then
		return "string6_fret0_E4_64"
	elseif columnIndex == 117 then
		return "string6_fret1_F4_65"
	elseif columnIndex == 118 then
		return "string6_fret2_F#4_66"
	elseif columnIndex == 119 then
		return "string6_fret3_G4_67"
	elseif columnIndex == 120 then
		return "string6_fret4_G#4_68"
	elseif columnIndex == 121 then
		return "string6_fret5_A4_69"
	elseif columnIndex == 122 then
		return "string6_fret6_A#4_70"
	elseif columnIndex == 123 then
		return "string6_fret7_B4_71"
	elseif columnIndex == 124 then
		return "string6_fret8_C5_72"
	elseif columnIndex == 125 then
		return "string6_fret9_C#5_73"
	elseif columnIndex == 126 then
		return "string6_fret10_D5_74"
	elseif columnIndex == 127 then
		return "string6_fret11_D#5_75"
	elseif columnIndex == 128 then
		return "string6_fret12_E5_76"
	elseif columnIndex == 129 then
		return "string6_fret13_F5_77"
	elseif columnIndex == 130 then
		return "string6_fret14_F#5_78"
	elseif columnIndex == 131 then
		return "string6_fret15_G5_79"
	elseif columnIndex == 132 then
		return "string6_fret16_G#5_80"
	elseif columnIndex == 133 then
		return "string6_fret17_A5_81"
	elseif columnIndex == 134 then
		return "string6_fret18_A#5_82"
	elseif columnIndex == 135 then
		return "string6_fret19_B5_83"
	elseif columnIndex == 136 then
		return "string6_fret20_C6_84"
	elseif columnIndex == 137 then
		return "string6_fret21_C#6_85"
	elseif columnIndex == 138 then
		return "string6_fret22_D6_86"
	else
		error("columnIndex " .. columnIndex .. " is invalid")
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
	elseif arg == 5 then
		return "E"
	elseif arg == 6 then
		return "F"
	elseif arg == 7 then
		return "G"
	elseif arg == 8 then
		return "H"	
	else
		error("don't recognize " .. arg .. " for getting a suffix")
	end
end

function guitarIsInOpenPosition(arg)

	-- apparently there are only 8 samples for the lowest note

	if arg == 1 then
		return true
	-- elseif arg == 24 then
	-- 	return true
	-- elseif arg == 47 then
	-- 	return true
	-- elseif arg == 70 then
	-- 	return true
	-- elseif arg == 93 then
	-- 	return true
	-- elseif arg == 116 then
	-- 	return true
	else
		return false
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

	local columns = getItemColumns()

	for j = 1, #columns do

		local uniqueItems = {}
		local itemTakeVolumes = {}

		for i = 1, #columns[j] do

			local item = columns[j][i]

			local takeIndex = 0
			local itemTake = reaper.GetTake(item, takeIndex)
			local itemTakeVolume = reaper.GetMediaItemTakeInfo_Value(itemTake, "D_VOL")

			if doesNotHaveValue(itemTakeVolumes, itemTakeVolume) then
				table.insert(itemTakeVolumes, itemTakeVolume)
				table.insert(uniqueItems, item)
			end
		end

		if guitarIsInOpenPosition(j) then



			if #uniqueItems ~= 8 then
				error("#uniqueItems is " .. #uniqueItems)
			end
		else
			if #uniqueItems ~= 4 then
				error("#uniqueItems is " .. #uniqueItems)
			end
		end

		unselectAllItems()

		for k = 1, #uniqueItems do
			reaper.SetMediaItemSelected(uniqueItems[k], true)
		end

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
   		local prefix = "rockStandard_"
   		local variationSuffix = getVariationSuffix(m)
   		-- local dynamicSuffix = "_soft"
   		-- local dynamicSuffix = "_medium"
   		local dynamicSuffix = "_hard"

   		local targetFileName = prefix .. getTargetFileName(j) .. dynamicSuffix .. variationSuffix .. ".wv"
   		os.rename(fileNameOfGluedItem, workingDirectory .. "/" .. targetFileName)
   	end

   	removeReapeaks()
	end

	--

endUndoBlock()