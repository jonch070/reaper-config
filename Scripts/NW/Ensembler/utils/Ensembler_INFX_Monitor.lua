-- Ensembler_INFX_Monitor.lua - Input FX Monitoring for Data Collection Only
-- Polls JSFX plugin parameters to get real-time MIDI state for keyboard visualization

Ensembler_INFX_Monitor = {}

local Ensembler_Chords = require('utils/Ensembler_Chords')

---Decode bitmask into array of MIDI note numbers
---@param low number Bitmask for MIDI notes 0-31
---@param high number Bitmask for MIDI notes 32-63
---@param high2 number Bitmask for MIDI notes 64-95
---@param high3 number Bitmask for MIDI notes 96-127
---@return number[] Array of MIDI note numbers
function Ensembler_INFX_Monitor.decode_unassigned_notes(low, high, high2, high3)
    local unassigned_notes = {}
    local bitmasks = {low, high, high2, high3}

    for mask_index = 1, 4 do
        local mask = bitmasks[mask_index]
        local base_note = (mask_index - 1) * 32

        for bit = 0, 31 do
            if (mask & (1 << bit)) ~= 0 then
                table.insert(unassigned_notes, base_note + bit)
            end
        end
    end

    return unassigned_notes
end

---@class InstrumentMidiData
---@field note number MIDI note number (0-127)
---@field lane_type "voice"|"chord_tone" Type of assignment
---@field transposition number Transposition in semitones

---@class MidiStateData
---@field instrument_notes table<string, InstrumentMidiData> Keyed by instrument GUID
---@field unassigned_notes number[] Array of MIDI notes held but not voiced
---@field chord_name string Human-readable chord name

---Poll MIDI state from Input FX instances
---@return MidiStateData
function Ensembler_INFX_Monitor.poll_midi_state()
    ---@type MidiStateData
    local midi_data = {
        instrument_notes = {},  -- [instrument_guid] = {note, lane_type, transposition}
        unassigned_notes = {},  -- array of midi notes held but not voiced
        chord_name = "No Chord"
    }

    local master_fx_info = nil

    -- Get all instruments from the current ensemble
    local instruments = State.ensemble.getAllInstruments()

    for _, instrument in ipairs(instruments) do
        local track = instrument.trackData.reaperTrack

        if track then
            local fx_index = INFX.find_ensembler_fx(track)

            if fx_index then
                -- Read the voiced note (includes transposition applied by JSFX)
                local note = reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.my_voiced_note)

                if note >= 0 then
                    -- Determine lane type and transposition from instrument position
                    local lane_type = "voice"
                    local transposition = 0

                    if instrument.position.chordTone then
                        lane_type = "chord_tone"
                        transposition = 0  -- Chord tones don't have octave transposition
                    elseif instrument.position.voice then
                        lane_type = "voice"
                        transposition = instrument.position.voice.octave * 12
                    end

                    midi_data.instrument_notes[instrument.trackData.guid] = {
                        note = math.floor(note + 0.5),  -- Round to integer
                        lane_type = lane_type,
                        transposition = transposition
                    }
                end

                -- Check if this is the master reporter
                local is_master = reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.is_master_reporter)
                if is_master > 0.5 then
                    master_fx_info = {track = track, fx_index = fx_index}
                end
            end
        end
    end

    -- Read global data from master reporter
    if master_fx_info then
        local track = master_fx_info.track
        local fx_index = master_fx_info.fx_index

        -- Read chord data
        local chord_root = reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.chord_root)
        local chord_quality = reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.chord_quality)

        if chord_root >= 0 and chord_quality > 0 then
            midi_data.chord_name = Ensembler_Chords.get_chord_name(
                math.floor(chord_root + 0.5),
                math.floor(chord_quality + 0.5)
            )
        end

        -- Read unassigned notes bitmasks
        local low = math.floor(reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.unassigned_notes_low) + 0.5)
        local high = math.floor(reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.unassigned_notes_high) + 0.5)
        local high2 = math.floor(reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.unassigned_notes_high2) + 0.5)
        local high3 = math.floor(reaper.TrackFX_GetParam(track, fx_index, State.config.JSFX_PARAM_MAP.unassigned_notes_high3) + 0.5)

        midi_data.unassigned_notes = Ensembler_INFX_Monitor.decode_unassigned_notes(low, high, high2, high3)
    end

    return midi_data
end

---Clear cache (kept for compatibility with existing callers)
function Ensembler_INFX_Monitor.clear_cache()
    -- No-op: caching removed in refactor
end

---Get current MIDI state
---@return MidiStateData
function Ensembler_INFX_Monitor.get_current_state()
    return Ensembler_INFX_Monitor.poll_midi_state()
end

return Ensembler_INFX_Monitor