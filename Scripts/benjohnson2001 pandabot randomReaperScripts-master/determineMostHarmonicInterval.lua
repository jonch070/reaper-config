-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function getNoteNumber(arg)

	if arg == "C6" then
		return 84
	elseif arg == "B5" then
		return 83
	elseif arg == "A#5" then
		return 82
	elseif arg == "A5" then
		return 81
	elseif arg == "G#5" then
		return 80
	elseif arg == "G5" then
		return 79
	elseif arg == "F#5" then
		return 78
	elseif arg == "F5" then
		return 77
	elseif arg == "E5" then
		return 76
	elseif arg == "D#5" then
		return 75
	elseif arg == "D5" then
		return 74
	elseif arg == "C#5" then
		return 73
	elseif arg == "C5" then
		return 72
	elseif arg == "B4" then
		return 71
	elseif arg == "A#4" then
		return 70
	elseif arg == "A4" then
		return 69
	elseif arg == "G#4" then
		return 68
	elseif arg == "G4" then
		return 67
	elseif arg == "F#4" then
		return 66
	elseif arg == "F4" then
		return 65
	elseif arg == "E4" then
		return 64
	elseif arg == "D#4" then
		return 63
	elseif arg == "D4" then
		return 62
	elseif arg == "C#4" then
		return 61
	elseif arg == "C4" then
		return 60
	elseif arg == "B3" then
		return 59
	elseif arg == "A#3" then
		return 58
	elseif arg == "A3" then
		return 57
	elseif arg == "G#3" then
		return 56
	elseif arg == "G3" then
		return 55
	elseif arg == "F#3" then
		return 54
	elseif arg == "F3" then
		return 53
	elseif arg == "E3" then
		return 52
	elseif arg == "D#3" then
		return 51
	elseif arg == "D3" then
		return 50
	elseif arg == "C#3" then
		return 49
	elseif arg == "C3" then
		return 48
	elseif arg == "B2" then
		return 47
	elseif arg == "A#2" then
		return 46
	elseif arg == "A2" then
		return 45
	elseif arg == "G#2" then
		return 44
	elseif arg == "G2" then
		return 43
	elseif arg == "F#2" then
		return 42
	elseif arg == "F2" then
		return 41
	elseif arg == "E2" then
		return 40
	elseif arg == "D#2" then
		return 39
	elseif arg == "D2" then
		return 38
	elseif arg == "C#2" then
		return 37
	elseif arg == "C2" then
		return 36
	else
		print("couldn't find the note " .. arg)
	end
end

function getIntervalName(arg)

	if arg == 1 then
		return "minor second (dissonant)"
	elseif arg == 2 then
		return "major second (dissonant)"
	elseif arg == 3 then
		return "minor third"
	elseif arg == 4 then
		return "major third"
	elseif arg == 5 then
		return "perfect fourth"
	elseif arg == 6 then
		return "augmented fourth (dissonant)"
	elseif arg == 7 then
		return "perfect fifth"
	elseif arg == 8 then
		return "minor sixth"
	elseif arg == 9 then
		return "major sixth"
	elseif arg == 10 then
		return "minor seventh (dissonant)"
	elseif arg == 11 then
		return "major seventh (dissonant)"
	elseif arg == 12 then
		return "octave"
	end
end

function getMostHarmonicInterval(arg12, arg13, arg23)

	if arg12 == 12 then
		return "12"
	end

	if arg13 == 12 then
		return "13"
	end

	if arg23 == 12 then
		return "23"
	end

	if arg12 == 7 then
		return "12"
	end

	if arg13 == 7 then
		return "13"
	end

	if arg23 == 7 then
		return "23"
	end

	if arg12 == 5 then
		return "12"
	end

	if arg13 == 5 then
		return "13"
	end

	if arg23 == 5 then
		return "23"
	end

	if arg12 == 4 then
		return "12"
	end

	if arg13 == 4 then
		return "13"
	end

	if arg23 == 4 then
		return "23"
	end

	if arg12 == 3 then
		return "12"
	end

	if arg13 == 3 then
		return "13"
	end

	if arg23 == 3 then
		return "23"
	end
end

local numberOfInputs = 1
local defaultInputs = ""
local userComplied, userInputs =  reaper.GetUserInputs("enter 3 notes", numberOfInputs, "notes:,extrawidth=100", defaultInputs)

if not userComplied then
	return
end

local characterOffset = 0

local firstNote = nil
local secondNote = nil
local thirdNote = nil

if string.sub(userInputs, 2, 2) == "#" then
	firstNote = string.sub(userInputs, 1, 3)
	characterOffset = characterOffset + 1
else
	firstNote = string.sub(userInputs, 1, 2)
end

if string.sub(userInputs, 4 + characterOffset, 4 + characterOffset) == "#" then
	secondNote = string.sub(userInputs, 3 + characterOffset, 5 + characterOffset)
	characterOffset = characterOffset + 1
else
	secondNote = string.sub(userInputs, 3 + characterOffset, 4 + characterOffset)
end

if string.sub(userInputs, 6 + characterOffset, 6 + characterOffset) == "#" then
	thirdNote = string.sub(userInputs, 5 + characterOffset, 7 + characterOffset)
	characterOffset = characterOffset + 1
else
	thirdNote = string.sub(userInputs, 5 + characterOffset, 6 + characterOffset)
end


local firstNoteNumber = getNoteNumber(firstNote)
local secondNoteNumber = getNoteNumber(secondNote)
local thirdNoteNumber = getNoteNumber(thirdNote)

print(firstNote .. ": " .. firstNoteNumber)
print(secondNote .. ": " .. secondNoteNumber)
print(thirdNote .. ": " .. thirdNoteNumber)

local numberOfSemitonesBetweenFirstAndSecondNotes = math.abs(firstNoteNumber-secondNoteNumber)
local numberOfSemitonesBetweenFirstAndThirdNotes = math.abs(firstNoteNumber-thirdNoteNumber)
local numberOfSemitonesBetweenSecondAndThirdNotes = math.abs(secondNoteNumber-thirdNoteNumber)

print(firstNote .. "-" .. secondNote .. ": " .. numberOfSemitonesBetweenFirstAndSecondNotes .. "  " .. getIntervalName(numberOfSemitonesBetweenFirstAndSecondNotes))
print(firstNote .. "-" .. thirdNote .. ": " .. numberOfSemitonesBetweenFirstAndThirdNotes.. "  " .. getIntervalName(numberOfSemitonesBetweenFirstAndThirdNotes))
print(secondNote .. "-" .. thirdNote .. ": " .. numberOfSemitonesBetweenSecondAndThirdNotes.. "  " .. getIntervalName(numberOfSemitonesBetweenSecondAndThirdNotes))
print("\n")
local mostHarmonicInterval = getMostHarmonicInterval(numberOfSemitonesBetweenFirstAndSecondNotes, numberOfSemitonesBetweenFirstAndThirdNotes, numberOfSemitonesBetweenSecondAndThirdNotes)

if mostHarmonicInterval == "12" then
	print("---->   " .. firstNote .. "-" .. secondNote .. ": " .. getIntervalName(numberOfSemitonesBetweenFirstAndSecondNotes) .. "   <----")
elseif mostHarmonicInterval == "13" then
	print("---->   " .. firstNote .. "-" .. thirdNote .. ": " .. getIntervalName(numberOfSemitonesBetweenFirstAndThirdNotes) .. "   <----")
elseif mostHarmonicInterval == "23" then
	print("---->   " .. secondNote .. "-" .. thirdNote .. ": " .. getIntervalName(numberOfSemitonesBetweenSecondAndThirdNotes) .. "   <----")
end



