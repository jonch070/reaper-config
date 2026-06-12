-- Ensembler_Chords.lua - Chord Name Lookup Database

Ensembler_Chords = {}

-- Chord quality names (matching JSFX database)
local CHORD_NAMES = {
    [1] = "maj",
    [2] = "min",
    [3] = "sus2",
    [4] = "sus4",
    [5] = "maj7",
    [6] = "min7",
    [7] = "7",
    [8] = "dim",
    [9] = "aug",
    [10] = "6",
    [11] = "m6",
    [12] = "maj9",
    [13] = "min9",
    [14] = "9",
    [15] = "add9",
    [16] = "m(add9)",
    [17] = "7sus4",
    [18] = "maj7sus4",
    [19] = "dim7",
    [20] = "m7b5",
    [21] = "m(maj7)",
    [22] = "aug7",
    [23] = "7b5",
    [24] = "7#5",
    [25] = "maj7#5",
    [26] = "6/9",
    [27] = "m6/9",
    [28] = "11",
    [29] = "m11",
    [30] = "maj11",
    [31] = "13",
    [32] = "m13",
    [33] = "maj13",
    [34] = "7#11",
    [35] = "maj7#11",
    [36] = "7b9",
    [37] = "7#9",
    [38] = "maj9#11",
    [39] = "m9b5",
    [40] = "5",
    [41] = "7sus2",
    
    -- Omitted note patterns
    [42] = "maj7(no3)",
    [43] = "7(no3)",
    [44] = "maj7(no5)",
    [45] = "min7(no5)",
    [46] = "9(no3)",
    [47] = "maj9(no3)",
    [48] = "maj(no5)",
    [49] = "min(no5)",
    
    -- Tension patterns
    [50] = "maj(#11)",
    [51] = "add9",
    [52] = "m(add9)",
    [53] = "7(#11)",
    [54] = "add#11",
    [55] = "m(add#11)",
    
    -- Fallback core triads (when complex lookup fails)
    [60] = "maj(+tensions)",
    [61] = "min(+tensions)",
    [62] = "dim(+tensions)",
    [63] = "aug(+tensions)"
}

-- Note names for root display
local NOTE_NAMES = State.config.NOTE_NAMES

-- Convert MIDI note number and chord quality to readable chord name
function Ensembler_Chords.get_chord_name(root_midi, quality)
    if root_midi < 0 or quality <= 0 then
        return "No Chord"
    end
    
    local root_name = NOTE_NAMES[(root_midi % 12) + 1]
    local quality_name = CHORD_NAMES[quality] or "unknown"
    
    return root_name .. quality_name
end

return Ensembler_Chords