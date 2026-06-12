-- Ensemble.lua - State and Management of Ensembles
-- TODO - This file is pretty big, probably needs to be broken apart a bit

require('types/types')

-- ========================================
-- Class
-- ========================================

Ensemble = {
    -- TODO this should load the default preset instead of hardcoding
    name = "New Ensemble", -- Default Name
    divisi_mode = 0, -- 0=bottom-up, 1=top-down, 2=fill
    is_active = false,
    is_modified = false,
    selected_preset = 0, -- TODO does this make sense to live here?
    preset_list = {} -- TODO does this make sense to live here?
}

-- ========================================
-- GUID Generation
-- ========================================

-- Generate unique GUID-style identifier
local function generateGuid()
    local chars = "0123456789abcdef"
    local guid = ""
    for i = 1, 32 do
        local idx = math.random(1, #chars)
        guid = guid .. chars:sub(idx, idx)
        if i == 8 or i == 12 or i == 16 or i == 20 then
            guid = guid .. "-"
        end
    end
    return guid
end


-- ========================================
-- Data Structures
-- ========================================

-- Voice Grid Data: instrumentsAssignedToVoices[voice][octave] = slotData
---@type table<number, table<integer, Instrument[]>>
local instrumentsAssignedToVoices = {}

-- Chord Tone Grid Data: instrumentsAssignedToChordTones[targetNote][chordTone] = slotData  
---@type table<string, table<integer, Instrument[]>>
local instrumentsAssignedToChordTones = {}

-- Sections define the columns in the UI
---@type table<Section[]>
local sections = {}

-- Transform Data for CC/Velocity transformations
---@type TransformData
local transforms = {
    activeColumns = {}, -- Will be initialized properly when State is available
    bySection = {},
    byInstrument = {}
}

-- Voice configuration
local voiceCount = 3
local numVisibleOctavesPositive = 2  -- How many octaves above "as played" to show
local numVisibleOctavesNegative = 2  -- How many octaves below "as played" to show

-- ========================================
-- Voice Position System
-- ========================================

-- SEQUENCE CONCEPT:
-- Voices are arranged in a linear sequence starting from "as played voice 1" (v1o0 = position 0)
-- For 3 voices: ..., v1o-1, v2o-1, v3o-1, v1o0, v2o0, v3o0, v1o1, v2o1, v3o1, ...
--               ..., -6,    -5,    -4,    -3,   -2,   -1,    0,    1,    2,    ...
-- Position 0 = v1o0 (reference point: "as played, voice 1")
-- Each instrument maintains its relative position in this sequence when voice count changes

---Convert voice/octave coordinates to linear position relative to v1o0
---@param voice number
---@param octave number
---@param currentVoiceCount number
---@return number
local function voiceOctaveToPosition(voice, octave, currentVoiceCount)
    return (octave * currentVoiceCount) + (voice - 1)
end

---Convert linear position back to voice/octave coordinates
---@param position number
---@param newVoiceCount number
---@return number
---@return number
local function positionToVoiceOctave(position, newVoiceCount)
    local octave = math.floor(position / newVoiceCount)
    local voice = (position % newVoiceCount) + 1
    return voice, octave
end

---Find the octave bounds of all instruments after redistribution
---@param newVoiceCount number
---@return integer
---@return integer
local function findInstrumentOctaveBoundsAfterRedistribution(newVoiceCount)
    local minOctave = math.huge
    local maxOctave = -math.huge
    local foundAnyInstruments = false
    
    -- Check all voice assignments
    for voice, octaves in pairs(instrumentsAssignedToVoices) do
        for octave, instruments in pairs(octaves) do
            if instruments and #instruments > 0 then
                -- Convert current position to linear sequence position
                local currentPosition = voiceOctaveToPosition(voice, octave, voiceCount)
                -- Convert to new position with new voice count
                local newVoice, newOctave = positionToVoiceOctave(currentPosition, newVoiceCount)
                
                minOctave = math.min(minOctave, newOctave)
                maxOctave = math.max(maxOctave, newOctave)
                foundAnyInstruments = true
            end
        end
    end
    
    -- If no instruments found, return sensible defaults
    if not foundAnyInstruments then
        return 0, 0  -- Just the "as played" octave
    end
    
    return minOctave, maxOctave
end

-- ========================================
-- Accessing Ensemble Data
-- ========================================

---Get empty chord tone positions for saving
---@return table[] Array of {targetNote: string, chordToneNum: integer}
local function getEmptyChordTonePositions()
    local emptyPositions = {}
    for targetNote, chordToneTable in pairs(instrumentsAssignedToChordTones) do
        for chordToneNum, instruments in pairs(chordToneTable) do
            if #instruments == 0 then
                table.insert(emptyPositions, {
                    targetNote = targetNote,
                    chordToneNum = chordToneNum
                })
            end
        end
    end
    return emptyPositions
end

-- Get data for saving this ensemble
---@return EnsembleSaveState
function Ensemble.getStateForSaving()
    return {
        name = Ensemble.name,
        divisi_mode = Ensemble.divisi_mode,
        is_modified = Ensemble.is_modified,
        voiceCount = voiceCount,
        numVisibleOctavesPositive = numVisibleOctavesPositive,
        numVisibleOctavesNegative = numVisibleOctavesNegative,
        instruments = Ensemble.getAllInstrumentsFlat(),
        sections = sections,
        transforms = transforms,
        emptyChordTonePositions = getEmptyChordTonePositions()
    }
end

---Replace the Ensemble state with the given state
---@param loadState EnsembleSaveState
function Ensemble.loadEnsemble(loadState) 
    Ensemble.clear()

    debug_log("loadEnsemble:")
    debug_log(loadState)
    
    Ensemble.name = loadState.name
    Ensemble.divisi_mode = loadState.divisi_mode
    -- For presets, is_modified will be nil, so default to false
    -- For temp state, it will be the saved value
    Ensemble.is_modified = loadState.is_modified or false
    voiceCount = loadState.voiceCount
    numVisibleOctavesPositive = loadState.numVisibleOctavesPositive
    numVisibleOctavesNegative = loadState.numVisibleOctavesNegative
    sections = loadState.sections
    
    -- Load transforms (with defaults for older saved states)
    if loadState.transforms then
        transforms = loadState.transforms
    else
        -- Reset to defaults if no transform data in saved state
        transforms = {
            activeColumns = {}, -- Will be set by proper initialization
            bySection = {},
            byInstrument = {}
        }
    end

    -- Reset chord tone assignments (will be rebuilt from loaded instruments)
    instrumentsAssignedToChordTones = {}
    
    -- Restore empty chord tone positions first
    if loadState.emptyChordTonePositions then
        for _, position in ipairs(loadState.emptyChordTonePositions) do
            local targetNote = position.targetNote
            local chordToneNum = position.chordToneNum
            
            if not instrumentsAssignedToChordTones[targetNote] then
                instrumentsAssignedToChordTones[targetNote] = {}
            end
            instrumentsAssignedToChordTones[targetNote][chordToneNum] = {}
        end
    end

    -- TODO - Is it a problem that this will call wasUpdated a lot?
    for _, instrumentData in pairs(loadState.instruments) do 
        local newInstrument = Ensemble.createInstrumentFromLoadData(instrumentData)
        debug_log("newInsturment:")
        debug_log(newInstrument)
        if instrumentData.position.voice then 
            Ensemble.addInstrumentToSectionAtVoiceAndOctave(newInstrument, instrumentData.position.sectionId, instrumentData.position.voice.voice, instrumentData.position.voice.octave)
        else 
            Ensemble.addInstrumentToSectionAtChordTone(newInstrument, instrumentData.position.sectionId, instrumentData.position.chordTone.targetNote, instrumentData.position.chordTone.chordToneNum)
        end
    end
    
    -- Apply configuration and trigger updates
    Ensemble.wasUpdated()
    
    debug_log("loadEnsemble complete")
end

---Get current octave range settings
---@return integer
---@return integer
function Ensemble.getOctaveRanges()
    return numVisibleOctavesPositive, numVisibleOctavesNegative
end

-- Set octave range settings (for external updates if needed)
function Ensemble.setOctaveRanges(positive, negative)
    numVisibleOctavesPositive = positive
    numVisibleOctavesNegative = negative
end

---Get all active sections sorted by display order
---@return Section[]
function Ensemble.getActiveSectionsSorted()
    local activeSections = {}
    for _, section in ipairs(sections) do
        if section.active then
            table.insert(activeSections, section)
        end
    end
    table.sort(activeSections, function(a, b) return a.displayOrder < b.displayOrder end)
    return activeSections
end

---Return an array of instruments
---@return Instrument[]
function Ensemble.getAllInstruments() 
    
    ---@type Instrument[]
    local allInstruments = {}

    -- Get tracks from voice assignments
    for voice, octaves in pairs(instrumentsAssignedToVoices) do
        for octave, voiceInstruments in pairs(octaves) do
            if voiceInstruments then
                for i = #voiceInstruments, 1, -1 do 
                    allInstruments[#allInstruments+1] = voiceInstruments[i]
                end
            end
        end
    end

    -- Get tracks from chord tone assignments
    for targetNote, chordTones in pairs(instrumentsAssignedToChordTones) do
        for chordToneNum, chordInstruments in pairs(chordTones) do
            if chordInstruments then
                for i = #chordInstruments, 1, -1 do 
                    allInstruments[#allInstruments+1] = chordInstruments[i]
                end
            end
        end
    end

    return allInstruments
end 

---Get all instruments as flat data structures (for serialization)
---@return InstrumentFlat[]
function Ensemble.getAllInstrumentsFlat()
    ---@type InstrumentFlat[]
    local flatInstruments = {}
    local instruments = Ensemble.getAllInstruments()
    
    for _, instrument in pairs(instruments) do
        ---@type InstrumentFlat
        local flatInstrument = {
            name = instrument.name,
            position = instrument.position,
            trackGuid = instrument.trackData.guid
        }
        flatInstruments[#flatInstruments + 1] = flatInstrument
    end
    
    return flatInstruments
end

---Get all instruments for a specific section, sorted by voice/octave, then chord tones
---@param sectionId string Section identifier
---@return Instrument[]
function Ensemble.getInstrumentsForSection(sectionId)
    local sectionInstruments = {}
    local allInstruments = Ensemble.getAllInstruments()
    
    -- Filter instruments for this section
    for _, instrument in ipairs(allInstruments) do
        if instrument.position.sectionId == sectionId then
            table.insert(sectionInstruments, instrument)
        end
    end
    
    -- Sort instruments: voice instruments first (by octave desc, voice desc), then chord tones
    table.sort(sectionInstruments, function(a, b)
        local aPos = a.position
        local bPos = b.position
        
        -- Voice instruments vs chord tone instruments
        if aPos.voice and not bPos.voice then
            return true  -- Voice instruments come first
        elseif not aPos.voice and bPos.voice then
            return false -- Chord tone instruments come second
        elseif aPos.voice and bPos.voice then
            -- Both are voice instruments: sort by octave desc, then voice desc
            if aPos.voice.octave ~= bPos.voice.octave then
                return aPos.voice.octave > bPos.voice.octave
            else
                return aPos.voice.voice > bPos.voice.voice
            end
        else
            -- Both are chord tone instruments: sort by target note desc, then chord tone desc
            if aPos.chordTone.targetNote ~= bPos.chordTone.targetNote then
                return aPos.chordTone.targetNote > bPos.chordTone.targetNote
            else
                return aPos.chordTone.chordToneNum > bPos.chordTone.chordToneNum
            end
        end
    end)
    
    return sectionInstruments
end

---Get flat instruments for a specific section (for template saving)
---@param sectionId string Section identifier
---@return InstrumentFlat[]
function Ensemble.getFlatInstrumentsForSection(sectionId)
    ---@type InstrumentFlat[]
    local flatInstruments = {}
    local instruments = Ensemble.getInstrumentsForSection(sectionId)
    
    -- Convert to flat format
    for _, instrument in ipairs(instruments) do
        ---@type InstrumentFlat
        local flatInstrument = {
            name = instrument.name,
            position = instrument.position,
            trackGuid = instrument.trackData.guid
        }
        table.insert(flatInstruments, flatInstrument)
    end
    
    return flatInstruments
end

---Get tracks for a specific voice/octave cell filtered by section
---@param voice integer
---@param octave integer
---@param sectionId string
---@return Instrument[]
function Ensemble.getInstrumentsForVoiceOctaveSection(voice, octave, sectionId)
    local instruments = instrumentsAssignedToVoices[voice] and instrumentsAssignedToVoices[voice][octave]
    if instruments then
        local sectionTracks = {}
        for _, track in ipairs(instruments) do
            if track.position.sectionId == sectionId then
                table.insert(sectionTracks, track)
            end
        end
        return sectionTracks
    end
    return {}
end

-- Get instruments for a chord tone cell filtered by section
---@param chordToneNum integer
---@param targetNote string
---@param sectionId string
---@return Instrument[]
function Ensemble.getInstrumentsForChordToneTargetAndSection(targetNote, chordToneNum, sectionId)
    local instruments = instrumentsAssignedToChordTones[targetNote] and 
                     instrumentsAssignedToChordTones[targetNote][chordToneNum]
    if instruments then
        local sectionTracks = {}
        for _, track in ipairs(instruments) do
            if track.position.sectionId == sectionId then
                table.insert(sectionTracks, track)
            end
        end
        return sectionTracks
    end
    return {}
end

---Get sorted chord tone rows for UI rendering
---@return ChordTonePosition[]
function Ensemble.getSortedChordTones()
    ---@type ChordTonePosition[]
    local chordTones = {}
    
    for targetNote, chordToneData in pairs(instrumentsAssignedToChordTones) do
        for chordToneNum, instruments in pairs(chordToneData) do 
            chordTones[#chordTones+1] = {
                targetNote = targetNote,
                chordToneNum = chordToneNum
            }
        end
    end
    
    -- Sort: target note high to low, then chord tone high to low within each target note
    table.sort(chordTones, function(a, b)
        if a.targetNote ~= b.targetNote then
            return a.targetNote > b.targetNote
        end
        return a.chordToneNum > b.chordToneNum
    end)
    
    return chordTones
end

---Check if a track GUID is already assigned anywhere in the ensemble
---@param trackGuid string
---@return boolean
function Ensemble.isTrackGuidInEnsemble(trackGuid)
    local instruments = Ensemble.getAllInstruments()
    for _, instrument in ipairs(instruments) do
        if instrument.trackData.guid == trackGuid then
            return true
        end
    end
    return false
end

-- ========================================
-- Modifying the Ensemble
-- ========================================

---Create an Instrument object from a MediaTrack
---@param instrumentData InstrumentFlat
---@return Instrument
function Ensemble.createInstrumentFromLoadData(instrumentData) 

    -- Try to find the track
    local trackName = instrumentData.name
    local track = ReaperTracks.get_by_guid(instrumentData.trackGuid)
    local found = track ~= nil
    if track then 
        local retval, latestTrackName = reaper.GetTrackName(track)
        trackName = latestTrackName
    end

    ---@type Instrument
    return {
        name = trackName,
        position = {}, -- TODO - clean up this handling
        trackData = {
            guid = instrumentData.trackGuid,
            reaperTrack = track,
            isMissing = not found -- TODO Need a way to clear this if the track is restored in the cache
        }
    }
end

---Create an Instrument object from a MediaTrack
---@param track MediaTrack
---@return Instrument
function Ensemble.createInstrumentFromTrack(track) 

    local trackGuid = reaper.GetTrackGUID(track)
    local retval, trackName = reaper.GetTrackName(track)

    ---@type Instrument
    return {
        name = trackName,
        position = {}, -- TODO - clean up this handling
        trackData = {
            guid = trackGuid,
            reaperTrack = track
        }
    }
end

---Check if adding another instrument would exceed GMEM limits
---@return boolean canAdd True if instrument can be added
local function checkInstrumentLimit()
    local currentCount = #Ensemble.getAllInstruments()
    local MAX_INSTRUMENTS_GMEM = 200

    if currentCount >= MAX_INSTRUMENTS_GMEM then
        Debug.log(string.format("ERROR: Cannot add more than %d instruments (GMEM transform limit)", MAX_INSTRUMENTS_GMEM), Debug.FEATURE.ENSEMBLE)
        return false
    end

    return true
end

-- Add Instrument to a voice/octave cell
---@param instrument Instrument
---@param sectionId string
---@param voice number
---@param octave number
function Ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, sectionId, voice, octave)
    debug_log(instrument)

    -- TODO Do we want to add a removal here in case we're adding an instrument that is already assigned elsewhere?

    -- Check GMEM instrument limit
    if not checkInstrumentLimit() then
        return
    end

    -- Re-assign the section and position
    instrument.position.sectionId = sectionId
    instrument.position.voice = {voice = voice, octave = octave}
    instrument.position.chordTone = nil

    -- create nested arrays as needed
    if not instrumentsAssignedToVoices[voice] then
        instrumentsAssignedToVoices[voice] = {}
    end
    if not instrumentsAssignedToVoices[voice][octave] then
        instrumentsAssignedToVoices[voice][octave] = {}
    end

    -- Add the instrument in position
    table.insert(instrumentsAssignedToVoices[voice][octave], instrument)
    Ensemble.wasUpdated()
end

-- Add Instrument to a chord tone cell
---@param instrument Instrument
---@param sectionId string
---@param targetNote string
---@param chordToneNum integer
function Ensemble.addInstrumentToSectionAtChordTone(instrument, sectionId, targetNote, chordToneNum)
    -- TODO Do we want to add a removal here in case we're adding an instrument that is already assigned elsewhere?

    -- Check GMEM instrument limit
    if not checkInstrumentLimit() then
        return
    end

    -- Re-assign the section and position
    instrument.position.sectionId = sectionId
    instrument.position.voice = nil
    instrument.position.chordTone = {chordToneNum = chordToneNum, targetNote = targetNote}

    -- create nested arrays as needed
    if not instrumentsAssignedToChordTones[targetNote] then
        instrumentsAssignedToChordTones[targetNote] = {}
    end
    if not instrumentsAssignedToChordTones[targetNote][chordToneNum] then
        instrumentsAssignedToChordTones[targetNote][chordToneNum] = {}
    end

    -- Add the instrument in position
    table.insert(instrumentsAssignedToChordTones[targetNote][chordToneNum], instrument)
    Ensemble.wasUpdated()
end

--- Remove Instrument from Position
--- @param instrument Instrument
function Ensemble.removeInstrumentFromCurrentPosition(instrument)
    debug_log(instrument)

    local function remove_by_value(array, value)
        for i, v in ipairs(array) do
            if v == value then
                table.remove(array, i)
                return true 
            end
        end
    end

    -- Clean up it's fx
    INFX.remove_ensembler_fx(instrument.trackData.reaperTrack)

    -- Remove it from array
    if instrument.position.voice then
        remove_by_value(instrumentsAssignedToVoices[instrument.position.voice.voice][instrument.position.voice.octave], instrument)
    else
        remove_by_value(instrumentsAssignedToChordTones[instrument.position.chordTone.targetNote][instrument.position.chordTone.chordToneNum], instrument)
    end

    -- Zero out all position data
    instrument.position.sectionId = nil
    instrument.position.voice = nil
    instrument.position.chordTone = nil

    Ensemble.wasUpdated()
end

---Move a specific track from one voice/octave to another
---@param instrument Instrument
---@param toVoice integer
---@param toOctave integer
---@param toSectionId string
function Ensemble.moveInstrumentToVoiceOctaveSection(instrument, toVoice, toOctave, toSectionId)
    debug_log(instrument)
    -- First, find and remove the track from its current location
    Ensemble.removeInstrumentFromCurrentPosition(instrument)
    
    -- Add it to the new location 
    Ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, toSectionId, toVoice, toOctave)
end

---Move a specific track to a chord tone
---@param instrument Instrument
---@param targetNote string
---@param chordToneNum integer
---@param sectionId string
function Ensemble.moveInstrumentToChordToneSection(instrument, targetNote, chordToneNum, sectionId)
    
    -- First, find and remove the track from its current location
    Ensemble.removeInstrumentFromCurrentPosition(instrument)
    
    -- Then add it to the new position
    Ensemble.addInstrumentToSectionAtChordTone(instrument, sectionId, targetNote, chordToneNum)
end


--- Find next available chord tone position
---@return string|nil, integer|nil
local function findNextChordTonePosition()
    -- Logic: Root C1→C8, then 5ths C1→C8, then 3rds C1→C8
    local chordToneOrder = {0, 7, 4}  -- Root, 5th, 3rd (semitones from root)
    
    for _, chordToneNum in ipairs(chordToneOrder) do
        for octave = 1, 8 do
            local targetNote = "C" .. octave
            
            -- Check if this position is available
            local exists = instrumentsAssignedToChordTones[targetNote] ~= nil and instrumentsAssignedToChordTones[targetNote][chordToneNum] ~= nil
            
            if not exists then
                return targetNote, chordToneNum
            end
        end
    end
    
    -- All positions taken - return nil to fail silently
    return nil, nil
end

--- Add a new chord tone row (finds next available position)
---@return string|nil, integer|nil
function Ensemble.addNewChordTone()
    local targetNote, chordToneNum = findNextChordTonePosition()
    
    if not targetNote or not chordToneNum then
        -- All positions taken, fail silently
        return nil, nil
    end

    -- Add the chord tone position
    if not instrumentsAssignedToChordTones[targetNote] then
        instrumentsAssignedToChordTones[targetNote] = {}
    end 
    instrumentsAssignedToChordTones[targetNote][chordToneNum] = {}

    Ensemble.wasUpdated()

    return targetNote, chordToneNum
end

---Modify chord tone number for all instruments in a chord tone position
---@param oldTargetNote string
---@param oldChordToneNum integer
---@param newChordToneNum integer
function Ensemble.modifyChordToneNumber(oldTargetNote, oldChordToneNum, newChordToneNum)
    local instruments = instrumentsAssignedToChordTones[oldTargetNote] and 
                       instrumentsAssignedToChordTones[oldTargetNote][oldChordToneNum]
    
    if not instruments then
        return -- No chord tone row exists
    end
    
    -- Handle empty chord tone row (show row exists but no instruments)
    if #instruments == 0 then
        -- Create new empty position and remove old one
        if not instrumentsAssignedToChordTones[oldTargetNote] then
            instrumentsAssignedToChordTones[oldTargetNote] = {}
        end
        if not instrumentsAssignedToChordTones[oldTargetNote][newChordToneNum] then
            instrumentsAssignedToChordTones[oldTargetNote][newChordToneNum] = {}
        end
        -- Remove old empty position
        instrumentsAssignedToChordTones[oldTargetNote][oldChordToneNum] = nil
    else
        -- Create a safe copy for iteration during modification
        local instrumentsCopy = Utils.shallowCopy(instruments)
        
        -- Move each instrument to the new chord tone number using existing methods
        for _, instrument in ipairs(instrumentsCopy) do
            local sectionId = instrument.position.sectionId
            Ensemble.removeInstrumentFromCurrentPosition(instrument)
            Ensemble.addInstrumentToSectionAtChordTone(instrument, sectionId, oldTargetNote, newChordToneNum)
        end
    end
    
    Ensemble.wasUpdated()
end

---Modify target note for all instruments in a chord tone position
---@param oldTargetNote string
---@param oldChordToneNum integer
---@param newTargetNote string
function Ensemble.modifyChordToneTargetNote(oldTargetNote, oldChordToneNum, newTargetNote)
    local instruments = instrumentsAssignedToChordTones[oldTargetNote] and 
                       instrumentsAssignedToChordTones[oldTargetNote][oldChordToneNum]
    
    if not instruments then
        return -- No chord tone row exists
    end
    
    -- Handle empty chord tone row (row exists but no instruments)
    if #instruments == 0 then
        -- Create new empty position
        if not instrumentsAssignedToChordTones[newTargetNote] then
            instrumentsAssignedToChordTones[newTargetNote] = {}
        end
        if not instrumentsAssignedToChordTones[newTargetNote][oldChordToneNum] then
            instrumentsAssignedToChordTones[newTargetNote][oldChordToneNum] = {}
        end
    else
        -- Create a safe copy for iteration during modification
        local instrumentsCopy = Utils.shallowCopy(instruments)

        -- Move each instrument to the new target note using existing methods
        for _, instrument in ipairs(instrumentsCopy) do
            local sectionId = instrument.position.sectionId
            Ensemble.removeInstrumentFromCurrentPosition(instrument)
            Ensemble.addInstrumentToSectionAtChordTone(instrument, sectionId, newTargetNote, oldChordToneNum)
        end
    end

    -- Remove old position (applies to both empty and non-empty cases)
    instrumentsAssignedToChordTones[oldTargetNote][oldChordToneNum] = nil

    Ensemble.wasUpdated()
end

---Remove a chord tone position and all instruments in it
---@param targetNote string
---@param chordToneNum integer
function Ensemble.removeChordTonePosition(targetNote, chordToneNum)
    local instruments = instrumentsAssignedToChordTones[targetNote] and
                       instrumentsAssignedToChordTones[targetNote][chordToneNum]

    if not instruments then
        return -- No chord tone position exists
    end

    -- Remove all instruments from this position (iterate backwards to safely remove)
    for i = #instruments, 1, -1 do
        Ensemble.removeInstrumentFromCurrentPosition(instruments[i])
    end

    -- Remove the position itself
    instrumentsAssignedToChordTones[targetNote][chordToneNum] = nil

    Ensemble.wasUpdated()
end

---Create a new section
---@param name string
---@return Section
function Ensemble.createSection(name)
    ---@type Section
    local newSection = {
        sectionId = generateGuid(),
        name = name,
        displayOrder = #sections + 1,
        active = true
    }
    sections[#sections+1] = newSection
    Ensemble.wasUpdated()
    return newSection
end

---Delete section and all its instruments
---@param sectionId string
---@return boolean success
function Ensemble.deleteSection(sectionId)
    -- Remove all instruments from this section first
    local allInstruments = Ensemble.getAllInstruments()
    for i = #allInstruments, 1, -1 do
        local instrument = allInstruments[i]
        if instrument.position.sectionId == sectionId then
            Ensemble.removeInstrumentFromCurrentPosition(instrument)
        end
    end
    
    -- Remove section from sections array
    for i = #sections, 1, -1 do
        if sections[i].sectionId == sectionId then
            table.remove(sections, i)
            Ensemble.wasUpdated()
            return true
        end
    end
    
    return false
end

-- Remove all instruments
function Ensemble.clear() 
    instrumentsAssignedToVoices = {}
    instrumentsAssignedToChordTones = {}
    -- Reset transforms to defaults  
    transforms.activeColumns = {}
    transforms.bySection = {}
    transforms.byInstrument = {}
    Ensemble.wasUpdated()
end

-- Reset the Ensemble to the default
function Ensemble.reset() 
    -- This really should just load whatever the default Preset is instead
    -- TODO
end

-- ========================================
-- Voice Count Management
-- ========================================

---Get current voice configuration
---@return integer
function Ensemble.getVoiceConfig()
    return voiceCount
end

---Pure function to translate a voice position from one voice count to another
---@param position Position Position object with voice data
---@param oldVoiceCount integer Original voice count
---@param newVoiceCount integer New voice count
---@return Position newPosition New position with updated voice data
function Ensemble.translateVoicePositionToNewNumVoices(position, oldVoiceCount, newVoiceCount)
    if oldVoiceCount == newVoiceCount or not position.voice then
        return position -- No change needed for same voice count or chord tones
    end
    
    -- Convert current position to linear sequence position relative to v1o0
    local currentPosition = voiceOctaveToPosition(
        position.voice.voice,
        position.voice.octave,
        oldVoiceCount
    )
    
    -- Convert position back to new voice/octave system
    local newVoice, newOctave = positionToVoiceOctave(currentPosition, newVoiceCount)
    
    -- Create new position object
    local newPosition = {
        sectionId = position.sectionId,
        voice = {
            voice = newVoice,
            octave = newOctave
        },
        chordTone = position.chordTone -- Preserve chord tone data (should be nil for voice positions)
    }
    
    return newPosition
end

---Adjust octave bounds to fit a collection of instruments
---@param instruments Instrument[]|InstrumentFlat[] Collection of instruments to check
function Ensemble.adjustOctaveBoundsToFitInstrumentCollection(instruments)
    local minOctave = math.huge
    local maxOctave = -math.huge
    local foundAnyVoiceInstruments = false
    
    -- Find min/max octaves from all voice instruments
    for _, instrument in ipairs(instruments) do
        local position = instrument.position
        if position and position.voice then
            minOctave = math.min(minOctave, position.voice.octave)
            maxOctave = math.max(maxOctave, position.voice.octave)
            foundAnyVoiceInstruments = true
        end
    end
    
    -- Only adjust if we found voice instruments
    if foundAnyVoiceInstruments then
        -- Auto-expand positive range if needed
        if maxOctave > numVisibleOctavesPositive then
            debug_log("AUTO-EXPANDED positive octave range from " .. numVisibleOctavesPositive .. " to " .. maxOctave)
            numVisibleOctavesPositive = maxOctave
        end
        
        -- Auto-expand negative range if needed  
        if minOctave < -numVisibleOctavesNegative then
            debug_log("AUTO-EXPANDED negative octave range from " .. numVisibleOctavesNegative .. " to " .. (-minOctave))
            numVisibleOctavesNegative = -minOctave
        end
    end
end

---Redistribute instruments when voice count changes
---@param newVoiceCount any
function Ensemble.redistributeVoices(newVoiceCount)
    if newVoiceCount == voiceCount then
        return -- No change needed
    end
    
    debug_log("=== REDISTRIBUTION DEBUG ===")
    debug_log("Changing from " .. voiceCount .. " to " .. newVoiceCount .. " voices")
    
    local oldVoiceCount = voiceCount
    local newAssignments = {}
    
    -- Redistribute voice assignments using the new clean approach
    for voice, octaves in pairs(instrumentsAssignedToVoices) do
        for octave, slotData in pairs(octaves) do
            -- Update each instrument's position object using the pure function
            for _, instrument in ipairs(slotData) do
                instrument.position = Ensemble.translateVoicePositionToNewNumVoices(
                    instrument.position,
                    oldVoiceCount,
                    newVoiceCount
                )
                
                local newVoice = instrument.position.voice.voice
                local newOctave = instrument.position.voice.octave
                
                debug_log("Position calculation: v" .. voice .. "o" .. octave .. " → v" .. newVoice .. "o" .. newOctave)
                
                -- Create new assignment structure
                if not newAssignments[newVoice] then
                    newAssignments[newVoice] = {}
                end
                if not newAssignments[newVoice][newOctave] then
                    newAssignments[newVoice][newOctave] = {}
                end
                
                -- Add instrument to new assignment
                table.insert(newAssignments[newVoice][newOctave], instrument)
            end
        end
    end
    
    -- Replace assignments and update voice count
    instrumentsAssignedToVoices = newAssignments
    voiceCount = newVoiceCount
    
    -- Adjust octave bounds to fit redistributed instruments
    Ensemble.adjustOctaveBoundsToFitInstrumentCollection(Ensemble.getAllInstruments())
    
    debug_log("=== END REDISTRIBUTION DEBUG ===")
    Ensemble.wasUpdated()
end

-- ========================================
-- Managing Updates
-- ========================================

-- Main ensemble update function - call whenever ensemble configuration changes
function Ensemble.wasUpdated()
    
    -- Notify the INFX manager to ensure plugins are up-to-date
    INFX.ensembleWasUpdated()
    
    -- Make sure the Ensemble is active -- TODO is this still a thing?
    State.ensemble.is_active = true
    State.ensemble.is_modified = true  -- Mark as modified
    
    -- Make sure all of the instruments in the Ensembler are selected in Reaper
    ReaperTracks.sync_track_selection()

    -- Save state of Ensembler to project
    EnsemblePersistence.saveTempState()

    Ensembler_INFX_Monitor.clear_cache()
end

-- ========================================
-- Transform System Functions
-- ========================================

---Get the transform data
---@return TransformData
function Ensemble.getTransforms()
    return transforms
end

---Get active columns for the transform view
---@return TransformParameter[]
function Ensemble.getActiveTransformColumns()
    return transforms.activeColumns
end

---Sort parameters in display order (velocity first, then CC1-CC127)
---@param parameters TransformParameter[]
---@return TransformParameter[]
local function sortParameters(parameters)
    local sorted = {}
    for _, param in ipairs(parameters) do
        table.insert(sorted, param)
    end
    
    table.sort(sorted, function(a, b)
        -- Velocity always comes first
        if a == "velocity" then return true end
        if b == "velocity" then return false end
        
        -- Both are CC parameters, sort numerically
        local numA = tonumber(a:match("cc(%d+)"))
        local numB = tonumber(b:match("cc(%d+)"))
        return numA < numB
    end)
    
    return sorted
end

---Set active columns for the transform view
---@param columns TransformParameter[]
function Ensemble.setActiveTransformColumns(columns)
    transforms.activeColumns = sortParameters(columns)
    Ensemble.wasUpdated()
end

---Add a transform parameter to the active columns
---@param parameter TransformParameter
function Ensemble.addTransformParameter(parameter)
    local currentColumns = Ensemble.getActiveTransformColumns()
    
    -- Check if parameter is already active
    for _, existingParam in ipairs(currentColumns) do
        if existingParam == parameter then
            debug_log("Parameter " .. parameter .. " is already active")
            return
        end
    end
    
    -- Add the parameter
    table.insert(currentColumns, parameter)
    Ensemble.setActiveTransformColumns(currentColumns)
    debug_log("Added transform parameter: " .. parameter)
end

---Remove a transform parameter from the active columns
---@param parameter TransformParameter
function Ensemble.removeTransformParameter(parameter)
    local currentColumns = Ensemble.getActiveTransformColumns()
    local newColumns = {}
    
    -- Copy all columns except the one to remove
    for _, col in ipairs(currentColumns) do
        if col ~= parameter then
            table.insert(newColumns, col)
        end
    end
    
    Ensemble.setActiveTransformColumns(newColumns)
    debug_log("Removed transform parameter: " .. parameter)
end

---Replace a transform parameter at a specific position
---@param oldParameter TransformParameter
---@param newParameter TransformParameter
function Ensemble.replaceTransformParameter(oldParameter, newParameter)
    local currentColumns = Ensemble.getActiveTransformColumns()
    local newColumns = {}
    
    -- Replace the old parameter with the new one
    for _, col in ipairs(currentColumns) do
        if col == oldParameter then
            table.insert(newColumns, newParameter)
        else
            table.insert(newColumns, col)
        end
    end
    
    Ensemble.setActiveTransformColumns(newColumns)
    debug_log("Replaced transform parameter: " .. oldParameter .. " -> " .. newParameter)
end

---Get transformer for a section and parameter
---@param sectionId string
---@param parameter TransformParameter
---@return Transformer|nil
function Ensemble.getSectionTransformer(sectionId, parameter)
    if transforms.bySection[sectionId] then
        return transforms.bySection[sectionId][parameter]
    end
    return nil
end

---Get transformer for an instrument and parameter
---@param instrumentId string
---@param parameter TransformParameter
---@return Transformer|nil
function Ensemble.getInstrumentTransformer(instrumentId, parameter)
    if transforms.byInstrument[instrumentId] then
        return transforms.byInstrument[instrumentId][parameter]
    end
    return nil
end

---Set transformer for a section and parameter (without triggering update)
---@param sectionId string
---@param parameter TransformParameter
---@param transformer Transformer|nil
local function setSectionTransformerInternal(sectionId, parameter, transformer)
    if not transforms.bySection[sectionId] then
        transforms.bySection[sectionId] = {}
    end
    transforms.bySection[sectionId][parameter] = transformer
end

---Set transformer for an instrument and parameter (without triggering update)
---@param instrumentId string
---@param parameter TransformParameter
---@param transformer Transformer|nil
local function setInstrumentTransformerInternal(instrumentId, parameter, transformer)
    if not transforms.byInstrument[instrumentId] then
        transforms.byInstrument[instrumentId] = {}
    end
    transforms.byInstrument[instrumentId][parameter] = transformer
end

---Set transformer for a section and parameter
---@param sectionId string
---@param parameter TransformParameter
---@param transformer Transformer|nil
function Ensemble.setSectionTransformer(sectionId, parameter, transformer)
    setSectionTransformerInternal(sectionId, parameter, transformer)
    Ensemble.wasUpdated()
end

---Set transformer for an instrument and parameter
---@param instrumentId string
---@param parameter TransformParameter
---@param transformer Transformer|nil
function Ensemble.setInstrumentTransformer(instrumentId, parameter, transformer)
    setInstrumentTransformerInternal(instrumentId, parameter, transformer)
    Ensemble.wasUpdated()
end

---Set transformer for a section and parameter (without triggering update - for UI use)
---@param sectionId string
---@param parameter TransformParameter
---@param transformer Transformer|nil
function Ensemble.setSectionTransformerNoUpdate(sectionId, parameter, transformer)
    setSectionTransformerInternal(sectionId, parameter, transformer)
end

---Set transformer for an instrument and parameter (without triggering update - for UI use)
---@param instrumentId string
---@param parameter TransformParameter
---@param transformer Transformer|nil
function Ensemble.setInstrumentTransformerNoUpdate(instrumentId, parameter, transformer)
    setInstrumentTransformerInternal(instrumentId, parameter, transformer)
end

---Clear all transformers for a specific parameter
---@param parameter TransformParameter
function Ensemble.clearAllTransformersForParameter(parameter)
    -- Clear from all sections
    for sectionId, sectionTransforms in pairs(transforms.bySection) do
        sectionTransforms[parameter] = nil
    end
    
    -- Clear from all instruments
    for instrumentId, instrumentTransforms in pairs(transforms.byInstrument) do
        instrumentTransforms[parameter] = nil
    end
    
    Ensemble.wasUpdated()
end

---Clear transformers of a specific type for a specific parameter
---@param parameter TransformParameter
---@param transformerType TransformerType
function Ensemble.clearTransformerTypeForParameter(parameter, transformerType)
    local clearedAny = false
    
    -- Clear transforms of specified type from sections
    for sectionId, sectionTransforms in pairs(transforms.bySection) do
        if sectionTransforms[parameter] and sectionTransforms[parameter].type == transformerType then
            sectionTransforms[parameter] = nil
            clearedAny = true
        end
    end
    
    -- Clear transforms of specified type from instruments
    for instrumentId, instrumentTransforms in pairs(transforms.byInstrument) do
        if instrumentTransforms[parameter] and instrumentTransforms[parameter].type == transformerType then
            instrumentTransforms[parameter] = nil
            clearedAny = true
        end
    end
    
    if clearedAny then
        Ensemble.wasUpdated()
    end
end

---Check if a parameter has any transformers (for confirmation dialogs)
---@param parameter TransformParameter
---@return boolean
function Ensemble.parameterHasTransformers(parameter)
    -- Check sections
    for sectionId, sectionTransforms in pairs(transforms.bySection) do
        if sectionTransforms[parameter] then
            return true
        end
    end
    
    -- Check instruments
    for instrumentId, instrumentTransforms in pairs(transforms.byInstrument) do
        if instrumentTransforms[parameter] then
            return true
        end
    end
    
    return false
end

---Get computed transforms for an instrument (combines section + instrument transforms)
---@param instrumentId string The instrument ID
---@return table<TransformParameter, Transformer> computedTransforms Map of parameter to final computed transformer
function Ensemble.getComputedTransformsForInstrument(instrumentId)
    local computedTransforms = {}
    
    -- Get instrument's section ID (need to find which section this instrument belongs to)
    local instrumentSectionId = nil
    for voice, octaveTable in pairs(instrumentsAssignedToVoices) do
        for octave, instruments in pairs(octaveTable) do
            for _, instrument in ipairs(instruments) do
                if instrument.trackData.guid == instrumentId then
                    instrumentSectionId = instrument.position.sectionId
                    break
                end
            end
            if instrumentSectionId then break end
        end
        if instrumentSectionId then break end
    end
    
    -- Also check chord tone assignments
    if not instrumentSectionId then
        for targetNote, chordToneTable in pairs(instrumentsAssignedToChordTones) do
            for chordTone, instruments in pairs(chordToneTable) do
                for _, instrument in ipairs(instruments) do
                    if instrument.trackData.guid == instrumentId then
                        instrumentSectionId = instrument.position.sectionId
                        break
                    end
                end
                if instrumentSectionId then break end
            end
            if instrumentSectionId then break end
        end
    end
    
    -- Get section and instrument transforms
    local sectionTransforms = instrumentSectionId and transforms.bySection[instrumentSectionId] or {}
    local instrumentTransforms = transforms.byInstrument[instrumentId] or {}
    debug_log("sectionTransforms:")
    debug_log(sectionTransforms)
    debug_log("instrumentTransforms:")
    debug_log(instrumentTransforms)
    
    -- Get all parameters that have transforms in either section or instrument
    local allParameters = {}
    for parameter in pairs(sectionTransforms) do
        allParameters[parameter] = true
    end
    for parameter in pairs(instrumentTransforms) do
        allParameters[parameter] = true
    end
    
    -- Compute final transform for each parameter
    for parameter in pairs(allParameters) do
        local sectionTransform = sectionTransforms[parameter]
        local instrumentTransform = instrumentTransforms[parameter]
        
        if instrumentTransform and not sectionTransform then
            -- Instrument only: use instrument transform (including ignore)
            computedTransforms[parameter] = instrumentTransform
            
        elseif sectionTransform and not instrumentTransform then
            -- Section only: use section transform (including ignore)
            computedTransforms[parameter] = sectionTransform
            
        elseif sectionTransform and instrumentTransform then
            -- Both exist: apply combination rules
            
            -- 1. Instrument ignore always wins
            if instrumentTransform.type == "ignore" then
                computedTransforms[parameter] = instrumentTransform
                
            -- 2. Section ignore always loses to instrument  
            elseif sectionTransform.type == "ignore" then
                computedTransforms[parameter] = instrumentTransform
                
            -- 3. Instrument fixed always wins (absolute value, can't be modified)
            elseif instrumentTransform.type == "fixed" then
                computedTransforms[parameter] = instrumentTransform
                
            -- 4. Instrument is scale - multiply with section value (keeps section's type)
            else -- instrumentTransform.type == "scale"
                local combinedValue = sectionTransform.value * instrumentTransform.value
                
                -- Round to integer if section type is fixed (MIDI values must be integers)
                if sectionTransform.type == "fixed" then
                    combinedValue = Utils.round(combinedValue)
                end
                
                computedTransforms[parameter] = {
                    type = sectionTransform.type,  -- scale or fixed 
                    value = combinedValue
                }
            end
        end
    end
    
    return computedTransforms
end

---Migrate all transformers from one parameter to another
---@param fromParameter TransformParameter
---@param toParameter TransformParameter
function Ensemble.migrateTransformersToNewParameter(fromParameter, toParameter)
    -- Helper function to migrate transformers within a transform table
    local function migrateInTransformTable(transformTable)
        if transformTable[fromParameter] then
            -- Copy transformer to new parameter
            transformTable[toParameter] = transformTable[fromParameter]
            -- Remove from old parameter
            transformTable[fromParameter] = nil
        end
    end
    
    -- Migrate from all sections
    for sectionId in pairs(transforms.bySection) do
        migrateInTransformTable(transforms.bySection[sectionId])
    end
    
    -- Migrate from all instruments
    for instrumentId in pairs(transforms.byInstrument) do
        migrateInTransformTable(transforms.byInstrument[instrumentId])
    end
    
    Ensemble.wasUpdated()
end

--- Initialize a default ensemble when no saved state exists
--- Creates a default section and sets up basic transform columns
function Ensemble.initializeDefaultEnsemble()
    debug_log("Initializing default ensemble")

    -- Clear retroactive recording buffers when initializing new ensemble
    RetroactiveRecord.clearAllBuffers()

    -- Set default ensemble properties
    name = State.config.DEFAULT_ENSEMBLE_NAME
    divisi_mode = 1
    is_modified = false
    voiceCount = 3
    numVisibleOctavesPositive = 2
    numVisibleOctavesNegative = 2
    
    -- Create default section
    sections = {}
    Ensemble.createSection(State.config.DEFAULT_SECTION_NAME)
    
    -- Initialize empty instrument assignments
    instrumentsAssignedToVoices = {}
    instrumentsAssignedToChordTones = {}
    emptyChordTonePositions = {}
    
    -- Initialize transforms structure
    transforms = {
        activeColumns = {},
        bySection = {},
        byInstrument = {}
    }
    
    -- Set up default transform columns using proper methods
    Ensemble.addTransformParameter("velocity")
    Ensemble.addTransformParameter("cc1")
    Ensemble.addTransformParameter("cc11")
    
    debug_log("Default ensemble initialized with Section A and transform columns: velocity, cc1, cc11")
end

return Ensemble