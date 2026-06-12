-- components/Views/Grid/ChordToneLabel.lua - Interactive Chord Tone Label Component

require('types/types')
local ChordToneSelector = require('components/Selectors/ChordToneSelector')
local TargetNoteSelector = require('components/Selectors/TargetNoteSelector')

local ChordToneLabel = {}

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.UI)
end

-- Helper function to convert MIDI number to note name (matching INFX.noteToMidi convention)
local function midiToNoteName(midi_note)
    if midi_note < 0 or midi_note > 127 then
        debug_log("Error: MIDI note " .. midi_note .. " is out of range (0-127)")
        return nil
    end
    
    local note_class = midi_note % 12
    local octave = math.floor(midi_note / 12) - 1  -- C4 = MIDI 60, so octave = 60/12 - 1 = 4

    return State.config.NOTE_NAMES[note_class + 1] .. octave
end

---Render interactive chord tone label with selectors
---@param ctx ImGui_Context
---@param targetNote string
---@param chordToneNum integer
---@param rowId string Unique identifier for this row
---@param onChordToneChanged? function Optional callback when chord tone type changes
---@param onTargetNoteChanged? function Optional callback when target note changes
---@param onRemove? function Optional callback when remove is clicked
function ChordToneLabel.render(ctx, targetNote, chordToneNum, rowId, onChordToneChanged, onTargetNoteChanged, onRemove)
    -- Render chord tone selector
    ChordToneSelector.render(
        ctx,
        "chord_tone_" .. rowId,
        chordToneNum,
        function(newChordToneNum)
            if onChordToneChanged then
                onChordToneChanged(targetNote, chordToneNum, newChordToneNum)
            end
        end,
        onRemove and function()
            onRemove(targetNote, chordToneNum)
        end or nil
    )
    
    -- Add "near" text
    reaper.ImGui_SameLine(ctx, 0, 4)
    reaper.ImGui_Text(ctx, "near")
    
    -- Render target note selector  
    reaper.ImGui_SameLine(ctx, 0, 4)
    local targetNoteMidi = noteToMidi(targetNote)  -- Use INFX.noteToMidi function
    TargetNoteSelector.render(
        ctx,
        "target_note_" .. rowId,
        targetNoteMidi,
        function(newMidiNote)
            local newTargetNote = midiToNoteName(newMidiNote)
            if newTargetNote and onTargetNoteChanged then
                onTargetNoteChanged(targetNote, chordToneNum, newTargetNote)
            end
        end
    )
end

return ChordToneLabel