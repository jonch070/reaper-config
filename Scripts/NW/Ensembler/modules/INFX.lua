-- INFX.lua - Management of INFX Plugins

require('types/types')
local GMEM = require('modules/GMEM')
local RetroactiveRecord = require('modules/RetroactiveRecord')

INFX = {}

local debug_log = State.debug_log

-- ========================================
-- Accessing Plugins
-- ========================================

-- Find EnsemblerFilter FX in a track's Input FX chain
-- TODO Rename all of these tracks/instruments/the naming data is kind of a mess
function INFX.find_ensembler_fx(track)
    local input_fx_count = reaper.TrackFX_GetRecCount(track)
    
    for i = 0, input_fx_count - 1 do
        local input_fx_index = i + 0x1000000 -- Offset for Input FX
        local retval, fx_name = reaper.TrackFX_GetFXName(track, input_fx_index, "")
        
        if fx_name:find(State.config.FX_NAME) then
        --    debug_log("Found Ensembler Filter at Input FX index " .. i)
            return input_fx_index, i  -- Return both offset index and raw index
        end
    end
    
    return nil, nil
end

-- ========================================
-- Updating Plugins
-- ========================================

---Set JSFX parameter with error checkingcomment
---@param track MediaTrack
---@param fx_index integer
---@param param_name string
---@param value any
---@return boolean
function INFX.set_fx_parameter(track, fx_index, param_name, value)
    local param_index = State.config.JSFX_PARAM_MAP[param_name]
    if not param_index then
        debug_log("ERROR: Unknown parameter: " .. param_name)
        return false
    end

    -- GMEM TEST: Write voice_number to gmem[0] for testing
    if param_name == "voice_number" then
        reaper.gmem_write(0, value)
        debug_log("GMEM TEST: Wrote voice_number = " .. value .. " to gmem[0]")
    end

    local success = reaper.TrackFX_SetParam(track, fx_index, param_index, value)
    if success then
        debug_log("Set " .. param_name .. " = " .. value .. " (param " .. param_index .. ")")
    else
        debug_log("FAILED to set " .. param_name .. " on FX " .. fx_index)
    end
    return success
end

---Configure transform data for an instrument via GMEM
---@param track MediaTrack
---@param fx_index integer
---@param instrumentId string
---@param instrumentMemorySlot integer
---@return boolean
function INFX.set_transform_data(track, fx_index, instrumentId, instrumentMemorySlot)
    -- Get computed transforms for this instrument (combines section + instrument)
    local computedTransforms = State.ensemble.getComputedTransformsForInstrument(instrumentId)

    debug_log("set_transform_data: "..instrumentId.." slot="..instrumentMemorySlot.." computedTransforms:")
    debug_log(computedTransforms)

    -- Convert to transform list
    local transformList = {}
    for parameter, transformer in pairs(computedTransforms) do
        table.insert(transformList, {
            parameter = parameter,
            transformer = transformer
        })
    end

    -- Write transform count
    GMEM.writeTransformCount(instrumentMemorySlot, #transformList)
    debug_log(string.format("GMEM slot %d: %d transforms", instrumentMemorySlot, #transformList))

    -- Write each transform
    for i, transform in ipairs(transformList) do
        local paramId = State.PARAMETER_TO_ID[transform.parameter] or 0
        local typeId = State.getTransformTypeId(transform.transformer.type)
        local value = transform.transformer.value

        GMEM.writeTransform(instrumentMemorySlot, i - 1, paramId, typeId, value)

        debug_log(string.format("  Transform %d: %s = %s(%.2f)",
            i, transform.parameter, transform.transformer.type, value))
    end

    -- Update the slot number slider to trigger JSFX @slider to read from GMEM
    -- This must happen AFTER writing to GMEM to avoid race conditions
    local success = INFX.set_fx_parameter(track, fx_index, "instrument_slot_number", instrumentMemorySlot)

    -- Increment transform_update_trigger to force @slider execution for CC preview resend
    -- This ensures detectChangedCCTransforms() runs even when slot number hasn't changed
    if success then
        local current_trigger = reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.transform_update_trigger)
        local new_trigger = (current_trigger + 1) % 1000  -- Wrap around to prevent overflow
        success = INFX.set_fx_parameter(track, fx_index, "transform_update_trigger", new_trigger)
    end

    if success then
        debug_log("Configured " .. #transformList .. " transforms for instrument " .. instrumentId .. " at GMEM slot " .. instrumentMemorySlot)
    else
        debug_log("ERROR: Failed to set transform parameters for " .. instrumentId)
    end

    return success
end

---Ensure track has EnsemblerFilter FX and configure it properly
---@param instrument Instrument
---@return boolean
function INFX.ensure_and_configure_fx(instrument)
    debug_log(instrument)
    local retval
    debug_log("Ensuring Ensembler Filter on track '" .. instrument.name .. "'")

    local track = instrument.trackData.reaperTrack
    
    -- Check if FX already exists
    local fx_index, raw_index = INFX.find_ensembler_fx(track)
    
    if not fx_index then
        -- FX doesn't exist, add it to Input FX chain
        local new_fx_index = reaper.TrackFX_AddByName(track, State.config.FX_NAME, true, -1)
        
        if new_fx_index >= 0 then
            -- Convert to Input FX offset for parameter access
            fx_index = new_fx_index + 0x1000000
            debug_log("Added EnsemblerFilter at Input FX position " .. new_fx_index)
        else
            debug_log("ERROR: Failed to add EnsemblerFilter FX (returned index: " .. new_fx_index .. ")")
            return false
        end
    else
        debug_log("EnsemblerFilter already exists, updating parameters")
    end
    
    local success = true
    
    -- Configure parameters based on lane type
    if instrument.position.chordTone and instrument.position.chordTone.targetNote then
        -- Chord tone configuration
        success = success and INFX.set_fx_parameter(track, fx_index, "voice_number", -1)  -- -1 for chord tone mode
        success = success and INFX.set_fx_parameter(track, fx_index, "chord_tone", instrument.position.chordTone.chordToneNum)
        success = success and INFX.set_fx_parameter(track, fx_index, "chord_tone_anchor_note", noteToMidi(instrument.position.chordTone.targetNote)) -- TODO - mismatched name between anchor_note and targetNote
        success = success and INFX.set_fx_parameter(track, fx_index, "transposition", 0)
        
        debug_log("Configured chord tone: " .. instrument.position.chordTone.chordToneNum .. " near MIDI note " .. instrument.position.chordTone.targetNote)
    else
        -- Voice configuration
        debug_log("Octave type: " .. type(instrument.position.voice.octave))
debug_log("Octave value: " .. tostring(instrument.position.voice.octave))
        local jsfx_voice_number = instrument.position.voice.voice - 1  -- Convert to 0-based for JSFX
        local transposition = instrument.position.voice.octave * 12
        success = success and INFX.set_fx_parameter(track, fx_index, "voice_number", jsfx_voice_number)
        success = success and INFX.set_fx_parameter(track, fx_index, "chord_tone", -1)  -- Disable chord tone mode
        success = success and INFX.set_fx_parameter(track, fx_index, "chord_tone_anchor_note", 0)  -- Clear anchor
        success = success and INFX.set_fx_parameter(track, fx_index, "transposition", transposition)
        
        debug_log("Configured voice " .. instrument.position.voice.voice .. " of " .. State.ensemble.getVoiceConfig() .. -- TODO total_voices
                 " (JSFX voice " .. jsfx_voice_number .. "), transpose " .. transposition)
    end
    
    -- Common parameters for both types
    success = success and INFX.set_fx_parameter(track, fx_index, "total_voices", State.ensemble.getVoiceConfig()) -- TODO total_voices
    success = success and INFX.set_fx_parameter(track, fx_index, "divisi_mode", State.ensemble.divisi_mode)
    success = success and INFX.set_fx_parameter(track, fx_index, "debug_mode", State.config.DEBUG and 1 or 0)
    
    -- Note: Transform data is configured in ensembleWasUpdated() with slot number
    -- This ensures all instruments get sequential slot assignments
    
    if success then
        return true
    else
        debug_log("ERROR: Failed to configure parameters")
        return false
    end
end

-- ========================================
-- Removing Plugins
-- ========================================

-- Remove EnsemblerFilter from a track's Input FX chain
function INFX.remove_ensembler_fx(track)
    local retval, track_name = reaper.GetTrackName(track, "")
    local fx_index, raw_index = INFX.find_ensembler_fx(track)
    
    if fx_index then
        debug_log("Removing EnsemblerFilter from track '" .. track_name .. "'")
        local success = reaper.TrackFX_Delete(track, fx_index)
        if success then
            debug_log("Successfully removed EnsemblerFilter")
            return true
        else
            debug_log("ERROR: Failed to remove EnsemblerFilter")
            return false
        end
    else
        -- Not an error if it's not there
        return true
    end
end

-- Remove all EnsemblerFilter FX from all tracks
function INFX.cleanup_all_tracks()
    local num_tracks = reaper.CountTracks(0)
    local cleaned_count = 0
    
    debug_log("Scanning " .. num_tracks .. " tracks for EnsemblerFilter FX")
    
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        if INFX.remove_ensembler_fx(track) then
            local fx_index = INFX.find_ensembler_fx(track)
            if not fx_index then  -- Confirm it was removed
                cleaned_count = cleaned_count + 1
            end
        end
    end
    
    debug_log("Cleaned " .. cleaned_count .. " tracks")
    return cleaned_count
end

-- ========================================
-- Responding to Events
-- ========================================

-- Update all ensemble instruments when ensemble configuration changes
function INFX.ensembleWasUpdated()
    local instruments = State.ensemble.getAllInstruments()
    debug_log(State.ensemble.instrumentsAssignedToVoices)
    debug_log(instruments)
    local master_set = false

    -- Assign memory slots to all instruments (shared between transform and retroactive systems)
    local slotNumbers = GMEM.assignInstrumentSlots(instruments)

    -- Initialize retroactive recording buffers
    RetroactiveRecord.initializeForEnsemble(instruments)

    for _, instrument in ipairs(instruments) do
        -- Make sure that all of the tracks in the ensemble have updated INFX plugins
        local configured = INFX.ensure_and_configure_fx(instrument)

        if configured then
            local fx_index = INFX.find_ensembler_fx(instrument.trackData.reaperTrack)
            if fx_index then
                -- Set first successfully configured track as master reporter for the INFX_MONITOR
                if not master_set then
                    INFX.set_fx_parameter(instrument.trackData.reaperTrack, fx_index, "is_master_reporter", 1)
                    master_set = true
                    debug_log("Set master reporter on track: " .. (instrument.trackData.guid or "Unknown"))
                end

                -- Get slot number for this instrument
                local slotNumber = slotNumbers[instrument.trackData.guid]
                if slotNumber then
                    -- Configure transform data via GMEM (writes to GMEM then sets instrument_slot_number)
                    INFX.set_transform_data(instrument.trackData.reaperTrack, fx_index, instrument.trackData.guid, slotNumber)

                    -- Set project time offset (slider25) for absolute timing in retroactive recording
                    local projectTimeOffset = reaper.GetProjectTimeOffset(0, false)
                    INFX.set_fx_parameter(instrument.trackData.reaperTrack, fx_index, "project_time_offset", projectTimeOffset)
                    Debug.log(string.format("Set slot %d, project time offset %.3f for track: %s",
                        slotNumber, projectTimeOffset, instrument.trackData.guid), Debug.FEATURE.JSFX)
                end
            end
        end
    end
end

-- ========================================
-- Helpers
-- ========================================

---comment
---@param noteName string
---@return integer
function noteToMidi(noteName)
    -- Note to semitone mapping (C = 0, C# = 1, D = 2, etc.)
    local noteValues = {
        ["C"] = 0,
        ["C#"] = 1,
        ["D"] = 2,
        ["D#"] = 3,
        ["E"] = 4,
        ["F"] = 5,
        ["F#"] = 6,
        ["G"] = 7,
        ["G#"] = 8,
        ["A"] = 9,
        ["A#"] = 10,
        ["B"] = 11
    }
    
    -- Parse the note name
    local note, octave = noteName:match("([A-G]#?)([0-9]+)")
    
    if not note or not octave then
        reaper.ShowConsoleMsg("Error: Invalid note name '" .. noteName .. "'\n")
        return 0
    end
    
    octave = tonumber(octave)
    if not octave then
        reaper.ShowConsoleMsg("Error: Invalid octave in note name '" .. noteName .. "'\n")
        return 0
    end
    
    local noteValue = noteValues[note]
    if not noteValue then
        reaper.ShowConsoleMsg("Error: Invalid note '" .. note .. "' in note name '" .. noteName .. "'\n")
        return 0
    end
    
    -- Calculate MIDI note number (C4 = 60, so octave 4 means (4+1)*12 = 60 for C)
    local midiNote = ((octave + 1) * 12) + noteValue
    
    -- Check if the result is within valid MIDI range (0-127)
    if midiNote < 0 or midiNote > 127 then
        reaper.ShowConsoleMsg("Error: Note '" .. noteName .. "' results in MIDI note " .. midiNote .. " which is out of range (0-127)\n")
        return 0
    end
    
    return midiNote
end

return INFX