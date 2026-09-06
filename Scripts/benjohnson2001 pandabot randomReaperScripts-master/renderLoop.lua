-- @noindex

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end


function thirtyTwoBitsFloatingPoint()
	return 3
end

function largeFilesAreAutoWavSlashWave64()
	return 0
end

function writeBwfIsCheckedAndIncludeProjectFilenameIsUnchecked()
	return 1
end

function doNotIncludeMarkersOrRegions()
	return 0
end

function doNotEmbedTempo()
	-- returning false means tempo will not be embedded
	return false
end

function currentProjectPath()
	return nil
end

function startOfTimeSelection()
	return -2
end

function endOfTimeSelection()
	return -2
end

function doNotOverwriteWithoutAsking()
	-- returning false means it will not overwrite without asking
	return false
end

function closeTheRenderWindowWhenDone()
	return true
end

function silentlyIncreaseTheFilenameIfItAlreadyExists()
	return true
end

local renderConfigurationString = ultraschall.CreateRenderCFG_WAV(thirtyTwoBitsFloatingPoint(),
																																	largeFilesAreAutoWavSlashWave64(),
																																	writeBwfIsCheckedAndIncludeProjectFilenameIsUnchecked(),
																																	doNotIncludeMarkersOrRegions(),
																																	doNotEmbedTempo())

local secondaryRenderConfigurationString = nil

local outputPath = "/Users/panda/Desktop/wurlieRhythmHigherOctaveVerticalChord4.wav"

local numberOfTimesToRender = 17

for i = 0, numberOfTimesToRender - 1 do

	ultraschall.RenderProject(currentProjectPath(),
														outputPath,
														startOfTimeSelection(),
														endOfTimeSelection(),
														doNotOverwriteWithoutAsking(),
														closeTheRenderWindowWhenDone(),
														silentlyIncreaseTheFilenameIfItAlreadyExists(),
														renderConfigurationString,
														secondaryRenderConfigurationString)
end




