-- @description Library file for Reanspiration script. Contains chord progressions, bass patterns, rhythm, and drum patterns.
-- @version 3.0 (Major Library Expansion)
-- @author Hosi
-- @about
--   This is a library file required by the main 'Hosi_Reanspiration_Pro.lua' script.
--   It must be placed in the same directory as the main script.
--   You can safely edit this file to add your own custom chord progressions, bass, rhythm, and drum patterns.
--   NEW in v3.0: Added dozens of new patterns across all modules (Chord, Bass, Drums, Melody).

local M = {}

-------------------------------------------
-- 1. DRUM MAP (NEW in v2.4)
-------------------------------------------
-- This table maps drum names used in the patterns below to specific MIDI note numbers.
-- You can change the note numbers here to match your custom drum sampler.
-- Based on GM Standard and user-provided map.
M.drum_map = {
  ["BassDrum"]    = 36, -- C1
  ["SnareStick"]  = 37, -- C#1
  ["SnareHit"]    = 38, -- D1
  ["Snare/Clap"]  = 39, -- D#1
  ["SnareEdge"]   = 40, -- E1 (Rimshot)
  ["Tom1"]        = 41, -- F1 (Low Floor Tom)
  ["HiHatClosed"] = 42, -- F#1
  ["Tom2"]        = 43, -- G1 (High Floor Tom)
  ["HiHatPedal"]  = 44, -- G#1
  ["Tom3"]        = 45, -- A1 (Low Tom)
  ["HiHatOpen"]   = 46, -- A#1
  ["MidTom"]      = 47, -- B1 (Low-Mid Tom)
  ["Crash"]       = 49, -- C#2 (Crash Cymbal 1)
  ["HighTom"]     = 50, -- D2 (High Tom)
  ["RideCrash"]   = 51, -- D#2 (Ride Cymbal 1)
  ["RideBell"]    = 53, -- F2
  ["Tambourine"]  = 54, -- F#2
  ["Crash2"]      = 57, -- A2 (Crash Cymbal 2)
  ["OpenHiConga"] = 63, -- D#3
  ["LowConga"]    = 64, -- E3
  ["Claves"]      = 75, -- D#4
}


-------------------------------------------
-- 2. CHORD PROGRESSION LIBRARY (UPDATED v3.0)
-------------------------------------------
-- To add a progression, add a new entry to the 'major' or 'minor' tables.
-- Each progression is a table of "chord events".
-- Each "chord event" is a table with:
--   - degree: (Required) The scale degree (e.g., 1, 5, 6).
--   - duration: (Optional) The duration as a fraction of a measure (default: 1.0).
--   - bass_degree: (Optional) The required bass note degree (for slash chords).

M.chord_progressions = {
  major = {
    -- Original Progressions (Converted to new format)
    ["Pop 1 (I-V-vi-IV)"] = {
      { degree = 1 },
      { degree = 5 },
      { degree = 6 },
      { degree = 4 }
    },
    ["Pop 2 (I-vi-IV-V)"] = {
      { degree = 1 },
      { degree = 6 },
      { degree = 4 },
      { degree = 5 }
    },
    ["50s (I-vi-ii-V)"] = {
      { degree = 1 },
      { degree = 6 },
      { degree = 2 },
      { degree = 5 }
    },
    ["Canon (I-V-vi-iii-IV-I-IV-V)"] = {
      { degree = 1 },
      { degree = 5 },
      { degree = 6 },
      { degree = 3 },
      { degree = 4 },
      { degree = 1 },
      { degree = 4 },
      { degree = 5 }
    },
    ["Rock Anthem (I-IV-V)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 5 },
      { degree = 5 }
    },
    ["Sensitive Pop (vi-IV-I-V)"] = {
      { degree = 6 },
      { degree = 4 },
      { degree = 1 },
      { degree = 5 }
    },
    ["Modern Pop (I-V-vi-iii)"] = {
      { degree = 1 },
      { degree = 5 },
      { degree = 6 },
      { degree = 3 }
    },
    ["Ascending (IV-V-vi)"] = {
      { degree = 4 },
      { degree = 5 },
      { degree = 6 },
      { degree = 6 }
    },

    -- Added Progressions (Converted)
    ["Royal Road (IV-V-iii-vi)"] = {
      { degree = 4 },
      { degree = 5 },
      { degree = 3 },
      { degree = 6 }
    },
    ["Folk (I-IV-I-V)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 1 },
      { degree = 5 }
    },
    ["Ascending Bass (I-ii-iii-IV)"] = {
      { degree = 1 },
      { degree = 2 },
      { degree = 3 },
      { degree = 4 }
    },
    ["Gospel (I-iii-IV-V)"] = {
      { degree = 1 },
      { degree = 3 },
      { degree = 4 },
      { degree = 5 }
    },
    ["Classic Rock (I-bVII-IV-I)"] = {
      { degree = 1 },
      { degree = 7 },
      { degree = 4 },
      { degree = 1 }
    },
    ["Lydian Dream (I-II-V-I)"] = {
      { degree = 1 },
      { degree = 2 },
      { degree = 5 },
      { degree = 1 }
    },
    ["Doo-Wop (I-IV-V-IV)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 5 },
      { degree = 4 }
    },
    ["EDM Pop (vi-IV-I-V)"] = {
      { degree = 6 },
      { degree = 4 },
      { degree = 1 },
      { degree = 5 }
    },
    ["Simple Pop (I-IV-V-IV)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 5 },
      { degree = 4 }
    },
    ["Uplifting Pop (IV-I-V-vi)"] = {
      { degree = 4 },
      { degree = 1 },
      { degree = 5 },
      { degree = 6 }
    },

    -- NEW: Examples of advanced features
    ["Jazz (ii-V-I)"] = {
      { degree = 2, duration = 0.5 }, -- Bậc II, chiếm 50% ô nhịp
      { degree = 5, duration = 0.5 }, -- Bậc V, chiếm 50% ô nhịp
      { degree = 1, duration = 1.0 }  -- Bậc I, chiếm 100% ô nhịp
    },
    ["Pop Bassline (I-V/VII-vi-IV)"] = {
      { degree = 1 }, -- I
      { degree = 5, bass_degree = 7 }, -- V/VII (Hợp âm bậc V, bass bậc VII)
      { degree = 6 }, -- vi
      { degree = 4 }  -- IV
    },
    
    --- NEW (v3.0) ---
    ["12-Bar Blues (I-IV-V)"] = {
      { degree = 1 }, { degree = 4 }, { degree = 1 }, { degree = 1 },
      { degree = 4 }, { degree = 4 }, { degree = 1 }, { degree = 1 },
      { degree = 5 }, { degree = 4 }, { degree = 1 }, { degree = 5 }
    },
    ["Jazz (ii-V-I-VI)"] = {
      { degree = 2 },
      { degree = 5 },
      { degree = 1 },
      { degree = 6 }
    },
    ["Rhythmic Pop (I - - - IV - V -)"] = {
      { degree = 1, duration = 1.5 }, -- Dài 1.5 ô nhịp
      { degree = 4, duration = 0.5 }, -- Dài 0.5 ô nhịp
      { degree = 5, duration = 1.0 }  -- Dài 1.0 ô nhịp
    },
    ["Modal (I-bVII-I-V)"] = {
      { degree = 1 },
      { degree = 7 },
      { degree = 1 },
      { degree = 5 }
    },
    ["Descending Bass (I-V/7-vi-iii/5)"] = {
      { degree = 1 }, 
      { degree = 5, bass_degree = 7 }, 
      { degree = 6 }, 
      { degree = 3, bass_degree = 5 }
    },
    --- END NEW (v3.0) ---

  },
  minor = {
    -- Original Progressions (Converted)
    ["Standard (i-VI-III-VII)"] = {
      { degree = 1 },
      { degree = 6 },
      { degree = 3 },
      { degree = 7 }
    },
    ["Pop (i-iv-v-i)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 5 },
      { degree = 1 }
    },
    ["Jazz (ii°-v-i)"] = {
      { degree = 2, duration = 0.5 },
      { degree = 5, duration = 0.5 },
      { degree = 1 }
    },
    ["Andalusian Cadence (i-VII-VI-V)"] = {
      { degree = 1 },
      { degree = 7 },
      { degree = 6 },
      { degree = 5 }
    },
    ["Rock Ballad (i-VI-iv-v)"] = {
      { degree = 1 },
      { degree = 6 },
      { degree = 4 },
      { degree = 5 }
    },
    ["Cinematic (i-iv-VII-III)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 7 },
      { degree = 3 }
    },
    ["Dark Pop (i-VII-VI-iv)"] = {
      { degree = 1 },
      { degree = 7 },
      { degree = 6 },
      { degree = 4 }
    },
    ["Classic Minor (i-iv-v-VI)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 5 },
      { degree = 6 }
    },

    -- Added Progressions (Converted)
    ["Dorian Groove (i-IV-i-IV)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 1 },
      { degree = 4 }
    },
    ["Sad Descending (i-v-iv-III)"] = {
      { degree = 1 },
      { degree = 5 },
      { degree = 4 },
      { degree = 3 }
    },
    ["Phrygian Metal (i-II-i-v)"] = {
      { degree = 1 },
      { degree = 2 },
      { degree = 1 },
      { degree = 5 }
    },
    ["Sentimental (i-v-VI-V)"] = {
      { degree = 1 },
      { degree = 5 },
      { degree = 6 },
      { degree = 5 }
    },
    ["James Bond (i-bVI-V)"] = {
      { degree = 1 },
      { degree = 6 },
      { degree = 5 },
      { degree = 5 }
    },
    ["Pop/R&B (i-VII-v-VI)"] = {
      { degree = 1 },
      { degree = 7 },
      { degree = 5 },
      { degree = 6 }
    },
    ["Trap/HipHop (i-VI-VII-i)"] = {
      { degree = 1 },
      { degree = 6 },
      { degree = 7 },
      { degree = 1 }
    },
    ["Emotional Pop (VI-VII-i-v)"] = {
      { degree = 6 },
      { degree = 7 },
      { degree = 1 },
      { degree = 5 }
    },
    
    --- NEW (v3.0) ---
    ["Minor Blues (i-iv-i-i)"] = {
      { degree = 1 }, { degree = 4 }, { degree = 1 }, { degree = 1 },
      { degree = 4 }, { degree = 4 }, { degree = 1 }, { degree = 1 },
      { degree = 5 }, { degree = 4 }, { degree = 1 }, { degree = 5 }
    },
    ["Emotional (i-VII-III-VI)"] = {
      { degree = 1 },
      { degree = 7 },
      { degree = 3 },
      { degree = 6 }
    },
    ["Latin (i-v-iv-v)"] = {
      { degree = 1 },
      { degree = 5 },
      { degree = 4 },
      { degree = 5 }
    },
    ["Dorian (i-IV-VII-i)"] = {
      { degree = 1 },
      { degree = 4 },
      { degree = 7 },
      { degree = 1 }
    },
    ["Minor Descending Bass (i - VII/7 - VI - V)"] = {
      { degree = 1 }, 
      { degree = 7, bass_degree = 7 }, 
      { degree = 6 }, 
      { degree = 5 }
    },
    --- END NEW (v3.0) ---
  }
}

-------------------------------------------
-- 3. BASS PATTERN LIBRARY (UPDATED v3.0)
-------------------------------------------
-- To add a new bass pattern:
--   a) Copy and paste an existing pattern block.
--   b) Change the 'name' to what you want to see in the GUI.
--   c) Edit the 'func' (function) to create the MIDI notes for your pattern.
-- The list below is ordered. The order you define them in here is the order they will appear in the GUI.

M.bass_patterns = {
    -- Original Patterns
    {
        name = "Root Notes",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            reaper.MIDI_InsertNote(take, false, false, position, position + chord_length, channel, root_note, 100, true)
        end
    },
    {
        name = "Root + Fifth",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half_length = chord_length / 2
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, channel, fifth_note, 100, true)
        end
    },
    -- Added Patterns --
    {
        name = "Quarter Notes",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, root_note, 95, true)
        end
    },
    -- NEW POP PATTERNS --
    {
        name = "Pop - Pushing 8ths",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local eighth_length = chord_length / 8
            for i = 0, 7 do
                reaper.MIDI_InsertNote(take, false, false, position + i*eighth_length, position + (i+1)*eighth_length, channel, root_note, 100 - i*2, true)
            end
        end
    },
    {
        name = "Pop - Synth Octaves",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local eighth = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + eighth, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*eighth, position + 3*eighth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 4*eighth, position + 5*eighth, channel, root_note+12, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 6*eighth, position + 7*eighth, channel, root_note, 95, true)
        end
    },
    {
        name = "Pop - Ballad",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half = chord_length / 2
            reaper.MIDI_InsertNote(take, false, false, position, position + half, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half, position + half + chord_length / 4, channel, root_note+7, 90, true)
        end
    },
    -- Added Patterns Continued --
    {
        name = "Alberti Bass",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, fifth_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, fifth_note, 95, true)
        end
    },
    {
        name = "Funk Groove",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local sixteenth = chord_length / 16
            reaper.MIDI_InsertNote(take, false, false, position, position + sixteenth, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*sixteenth, position + 3*sixteenth, channel, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 5*sixteenth, position + 6*sixteenth, channel, root_note + 12, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 6*sixteenth, position + 7*sixteenth, channel, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 10*sixteenth, position + 11*sixteenth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 14*sixteenth, position + 15*sixteenth, channel, root_note, 95, true)
        end
    },
    {
        name = "Reggae 'One Drop'",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half_length = chord_length / 2
            -- Note on beat 3
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, channel, root_note, 100, true)
        end
    },
    -- Original Patterns Continued
    {
        name = "Simple Walk",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local root_note_pc = root_note % 12
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, fifth_note, 95, true)
            
            local passing_note
            if (next_root_pc - root_note_pc) % 12 > 6 then -- Descending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) - 12 + 1
            else -- Ascending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) -1
            end
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, passing_note, 90, true)
        end
    },
    {
        name = "Arpeggio Up",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local third_length = chord_length / 3
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + third_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + third_length, position + 2 * third_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * third_length, position + chord_length, channel, fifth_note, 95, true)
        end
    },
    {
        name = "Pop Rhythm",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local eighth_length = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length, position + 2 * quarter_length + eighth_length, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length + eighth_length, position + 3 * quarter_length, channel, root_note, 95, true)
        end
    },
    {
        name = "Octaves",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half_length = chord_length / 2
            local octave_note = root_note + 12
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, channel, octave_note, 95, true)
        end
    },
    {
        name = "Classic Rock",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_len = chord_length / 4
            local eighth_len = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_len, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_len + eighth_len, position + 2*quarter_len, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_len, position + 3*quarter_len, channel, root_note, 95, true)
        end
    },
    
    --- NEW (v3.0) ---
    {
        name = "Walking (Root-3-5-3)",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, fifth_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, third_note, 95, true)
        end
    },
    {
        name = "Synth Pulse (16ths)",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local sixteenth = chord_length / 16
            for i = 0, 15 do
                local vel = (i % 2 == 0) and 100 or 85
                reaper.MIDI_InsertNote(take, false, false, position + i*sixteenth, position + (i+1)*sixteenth, channel, root_note, vel, true)
            end
        end
    },
    {
        name = "Off-beat 8ths",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local eighth = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position + eighth, position + 2*eighth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*eighth, position + 4*eighth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 5*eighth, position + 6*eighth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 7*eighth, position + 8*eighth, channel, root_note, 95, true)
        end
    },
    {
        name = "Pushing (Anticipated)",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local sixteenth = chord_length / 16
            -- Play on the 'e' of 4 (of previous measure, simulated by playing at 15*sixteenth)
            reaper.MIDI_InsertNote(take, false, false, position - sixteenth, position, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*sixteenth, position + 4*sixteenth, channel, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 8*sixteenth, position + 10*sixteenth, channel, root_note, 95, true)
        end
    },
    --- END NEW (v3.0) ---
}

-------------------------------------------
-- 4. RHYTHM PATTERN LIBRARY
-------------------------------------------
-- To add a new rhythm pattern:
--   a) Copy and paste an existing pattern block.
--   b) Change the 'name' to what you want to see in the GUI.
--   c) Edit the 'pattern' table. Each entry is a note with:
--      - 'start': The start position as a fraction of the total chord duration (0.0 to 1.0).
--      - 'duration': The note's duration as a fraction of the total chord duration.
M.rhythm_patterns = {
    {
        name = "Sustained", -- Default long chord
        pattern = {
            { start = 0, duration = 1 }
        }
    },
    {
        name = "Ballad",
        pattern = {
            { start = 0, duration = 0.5 },
            { start = 0.5, duration = 0.5 }
        }
    },
    -- Added Patterns --
    {
        name = "March",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.5, duration = 0.25 }
        }
    },
    -- NEW POP PATTERNS --
    {
        name = "Pop - Four on the Floor",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.25, duration = 0.25 },
            { start = 0.5, duration = 0.25 },
            { start = 0.75, duration = 0.25 }
        }
    },
    {
        name = "Pop - Modern Syncopation",
        pattern = {
            { start = 0, duration = 0.125 },
            { start = 0.375, duration = 0.125 },
            { start = 0.625, duration = 0.25 }
        }
    },
    {
        name = "Pop - Piano Ballad",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.375, duration = 0.125 },
            { start = 0.5, duration = 0.25 },
            { start = 0.875, duration = 0.125 }
        }
    },
    -- Added Patterns Continued
    {
        name = "Reggae Skank",
        pattern = {
            { start = 0.25, duration = 0.25 },
            { start = 0.75, duration = 0.25 }
        }
    },
    {
        name = "Waltz",
        pattern = {
            { start = 0, duration = 0.333 },
            { start = 0.333, duration = 0.333 },
            { start = 0.666, duration = 0.333 }
        }
    },
    {
        name = "Dotted 8th",
        pattern = {
            { start = 0, duration = 0.375 },
            { start = 0.375, duration = 0.125 },
            { start = 0.5, duration = 0.375 },
            { start = 0.875, duration = 0.125 }
        }
    },
    {
        name = "Power Ballad",
        pattern = {
            { start = 0, duration = 0.125 },
            { start = 0.125, duration = 0.125 },
            { start = 0.25, duration = 0.125 },
            { start = 0.375, duration = 0.625 }
        }
    },
    {
        name = "Funk Stabs",
        pattern = {
            { start = 0.125, duration = 0.125 },
            { start = 0.625, duration = 0.125 }
        }
    },
    -- Original Patterns Continued
    {
        name = "Syncopated Pop",
        pattern = {
            { start = 0.375, duration = 0.375 },
            { start = 0.75, duration = 0.25 }
        }
    },
    {
        name = "Bossa Nova",
        pattern = {
            { start = 0, duration = 0.375 },
            { start = 0.5, duration = 0.375 }
        }
    },
    {
        name = "Swing Quarters",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.333, duration = 0.25 },
            { start = 0.666, duration = 0.25 }
        }
    },
    
    --- NEW (v3.0) ---
    {
        name = "EDM Sidechain",
        pattern = {
            { start = 0, duration = 0.2 },
            { start = 0.25, duration = 0.2 },
            { start = 0.5, duration = 0.2 },
            { start = 0.75, duration = 0.2 }
        }
    },
    {
        name = "Anticipated Stab",
        pattern = {
            { start = 0.875, duration = 0.125 } -- "and" of 4
        }
    },
    {
        name = "The 'And's",
        pattern = {
            { start = 0.125, duration = 0.125 },
            { start = 0.375, duration = 0.125 },
            { start = 0.625, duration = 0.125 },
            { start = 0.875, duration = 0.125 }
        }
    },
    --- END NEW (v3.0) ---

    {
        name = "Random",
        -- This is a special case handled by the main script to generate a random rhythm.
        pattern = {}
    }
}

-------------------------------------------
-- 5. STRUM PATTERN LIBRARY (NEW)
-------------------------------------------
-- To add a new strum pattern:
--   a) Add a new entry to this table.
--   b) 'name': The name to show in the GUI.
--   c) 'pattern': A table of hits. Each hit has:
--      - 'start': Start position (0.0 to 1.0)
--      - 'direction': "D" (Down) or "U" (Up)
--      - 'duration': (Optional) Hit duration as a fraction of chord length (default: 0.125)
--      - 'velocity_multiplier': (Optional) Velocity scale (0.0 to 1.0, default: 1.0)
M.strum_patterns = {
    {
        name = "Simple Down (Quarter)",
        pattern = {
            { start = 0, direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.25, direction = "D", duration = 0.25, velocity_multiplier = 0.85 },
            { start = 0.5, direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.75, direction = "D", duration = 0.25, velocity_multiplier = 0.85 }
        }
    },
    {
        name = "Simple Down (8ths)",
        pattern = {
            { start = 0, direction = "D", duration = 0.125, velocity_multiplier = 1.0 },
            { start = 0.125, direction = "D", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.25, direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.375, direction = "D", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.5, direction = "D", duration = 0.125, velocity_multiplier = 1.0 },
            { start = 0.625, direction = "D", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.75, direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.875, direction = "D", duration = 0.125, velocity_multiplier = 0.8 }
        }
    },
    {
        name = "Folk (D-DU-DU)",
        pattern = {
            { start = 0, direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.25, direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.375, direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.5, direction = "D", duration = 0.125, velocity_multiplier = 1.0 },
            { start = 0.625, direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.75, direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.875, direction = "U", duration = 0.125, velocity_multiplier = 0.8 }
        }
    },
    {
        name = "Waltz (D-du-du)",
        pattern = {
            { start = 0, direction = "D", duration = 0.33, velocity_multiplier = 1.0 },
            { start = 0.33, direction = "D", duration = 0.165, velocity_multiplier = 0.8 },
            { start = 0.495, direction = "U", duration = 0.165, velocity_multiplier = 0.7 },
            { start = 0.66, direction = "D", duration = 0.165, velocity_multiplier = 0.8 },
            { start = 0.825, direction = "U", duration = 0.165, velocity_multiplier = 0.7 }
        }
    },
    {
        name = "Single Strum (Down)",
        pattern = {
            { start = 0, direction = "D", duration = 1.0, velocity_multiplier = 1.0 }
        }
    },
    {
        name = "Single Strum (Up)",
        pattern = {
            { start = 0, direction = "U", duration = 1.0, velocity_multiplier = 1.0 }
        }
    },
    
    --- NEW (v3.0) ---
    {
        name = "Syncopated (D - dU - U -)",
        pattern = {
            { start = 0,     direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.375, direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.5,   direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.75,  direction = "U", duration = 0.125, velocity_multiplier = 0.8 }
        }
    },
    {
        name = "Pop Syncopation (D- -U- -D-)",
        pattern = {
            { start = 0,     direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.375, direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.625, direction = "D", duration = 0.125, velocity_multiplier = 0.9 }
        }
    },
    
    --- NEW (User Request) ---
    {
        name = "Island Strum (D- -u -u d u)",
        pattern = {
            { start = 0,     direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.375, direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.625, direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.75,  direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.875, direction = "U", duration = 0.125, velocity_multiplier = 0.8 }
        }
    },
    {
        name = "Pop Rock (D- D- D-du)",
        pattern = {
            { start = 0,     direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.25,  direction = "D", duration = 0.25, velocity_multiplier = 0.95 },
            { start = 0.5,   direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.75,  direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.875, direction = "U", duration = 0.125, velocity_multiplier = 0.8 }
        }
    },
    {
        name = "Acoustic 16ths (D-du -udu)",
        pattern = {
            { start = 0,     direction = "D", duration = 0.25, velocity_multiplier = 1.0 },
            { start = 0.25,  direction = "D", duration = 0.125, velocity_multiplier = 0.85 },
            { start = 0.375, direction = "U", duration = 0.125, velocity_multiplier = 0.75 },
            -- skip 0.5 (rest)
            { start = 0.625, direction = "U", duration = 0.125, velocity_multiplier = 0.8 },
            { start = 0.75,  direction = "D", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.875, direction = "U", duration = 0.125, velocity_multiplier = 0.8 }
        }
    },
    {
        name = "Ska / Upbeats",
        pattern = {
            { start = 0.125, direction = "U", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.375, direction = "U", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.625, direction = "U", duration = 0.125, velocity_multiplier = 0.9 },
            { start = 0.875, direction = "U", duration = 0.125, velocity_multiplier = 0.9 }
        }
    },
    {
        name = "Fast Triplets (Gallop)",
        pattern = {
            { start = 0,     direction = "D", duration = 0.083, velocity_multiplier = 1.0 },
            { start = 0.083, direction = "D", duration = 0.083, velocity_multiplier = 0.8 },
            { start = 0.166, direction = "U", duration = 0.083, velocity_multiplier = 0.7 },
            
            { start = 0.25,  direction = "D", duration = 0.083, velocity_multiplier = 1.0 },
            { start = 0.333, direction = "D", duration = 0.083, velocity_multiplier = 0.8 },
            { start = 0.416, direction = "U", duration = 0.083, velocity_multiplier = 0.7 },
            
            { start = 0.5,   direction = "D", duration = 0.083, velocity_multiplier = 1.0 },
            { start = 0.583, direction = "D", duration = 0.083, velocity_multiplier = 0.8 },
            { start = 0.666, direction = "U", duration = 0.083, velocity_multiplier = 0.7 },
            
            { start = 0.75,  direction = "D", duration = 0.083, velocity_multiplier = 1.0 },
            { start = 0.833, direction = "D", duration = 0.083, velocity_multiplier = 0.8 },
            { start = 0.916, direction = "U", duration = 0.083, velocity_multiplier = 0.7 }
        }
    },
    --- END NEW (v3.0) ---
}

-------------------------------------------
-- 6. DRUM PATTERN LIBRARY (UPDATED v3.0)
-------------------------------------------
-- Patterns now use 'pitch = M.drum_map["DrumName"]' instead of hard-coded numbers.
M.drum_patterns = {
    {
        name = "Pop/Rock - Four on the Floor",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Basic Rock",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.5} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Hip-Hop - Classic",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.0625, 0.5, 0.5625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Hip-Hop - Modern",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.375, 0.5} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 80,  positions = {0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.8125, 0.875, 0.9375} } -- Hi-hat 16ths
        }
    },
    {
        name = "Trap",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.3125, 0.6875} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 120, positions = {0.5} }, -- Snare on 3
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.875} }, -- Hi-hat with rolls
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.9375} } -- Open Hat
        }
    },
    {
        name = "Dubstep",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 125, positions = {0.5} }, -- Snare on 3
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0.1875, 0.4375, 0.6875, 0.9375} }, -- Closed Hat
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.3125} } -- Open Hat
        }
    },
    {
        name = "UK Garage",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.375, 0.625} }, -- Kick
            { pitch = M.drum_map["Snare/Clap"], vel = 110, positions = {0.25, 0.75} }, -- Clap
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0.125, 0.625} }, -- Closed Hat
            { pitch = M.drum_map["HiHatOpen"], vel = 105, positions = {0.875} }, -- Open Hat
            { pitch = M.drum_map["MidTom"], vel = 95,  positions = {0.1875} } -- Mid Tom
        }
    },
    {
        name = "Drum 'N' Bass",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 120, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat 8ths
            { pitch = M.drum_map["HiHatOpen"], vel = 110, positions = {0.4375, 0.9375} } -- Open Hat
        }
    },
    {
        name = "Deep House",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 115, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["Snare/Clap"], vel = 105, positions = {0.25, 0.75} }, -- Clap
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hat on beat
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Disco",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hi-hat on the off-beats
        }
    },
    {
        name = "Reggae 'One Drop' Beat",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 110, positions = {0.5} }, -- Kick on beat 3
            { pitch = M.drum_map["SnareEdge"], vel = 120, positions = {0.5} }, -- Rimshot/Snare on beat 3
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0.125, 0.375, 0.625, 0.875} } -- Hi-hat on off-beats
        }
    },
    -- NEW PATTERNS FROM REFERENCE
    {
        name = "Rock - 80s Beat",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.375, 0.5} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 95,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat
        }
    },
    {
        name = "Pop - Syncopated Kick",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.1875, 0.375, 0.625, 0.8125} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat
        }
    },
    {
        name = "Motown Beat",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 115, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 120, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["Tambourine"], vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Tambourine
        }
    },
    {
        name = "Slow Blues Shuffle",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 110, positions = {0, 0.375} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 100, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["RideCrash"], vel = 90,  positions = {0, 0.1875, 0.25, 0.375, 0.5625, 0.625, 0.75} } -- Ride Cymbal with swing feel
        }
    },
    {
        name = "Shuffle Feel",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 115, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.1875, 0.375, 0.5625, 0.75} } -- Hi-hat with shuffle feel
        }
    },
    {
        name = "Funk - Syncopated Snare",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.4375, 0.625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 120, positions = {0.1875, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 95,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat
            { pitch = M.drum_map["HiHatOpen"], vel = 105, positions = {0.9375} } -- Open Hat
        }
    },
    {
        name = "Funk - Tom Groove",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.1875, 0.4375, 0.8125} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.3125, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat
            { pitch = M.drum_map["HighTom"], vel = 110, positions = {0.625} }, -- High Tom
            { pitch = M.drum_map["Tom3"], vel = 110, positions = {0.875} }  -- Low Tom (using Tom3)
        }
    },
    -- NEW PATTERNS FROM CHEAT SHEET PDF
    {
        name = "Riddim",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.5} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["Snare/Clap"], vel = 105, positions = {0.25, 0.75} }, -- Clap
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Closed Hat 8ths
        }
    },
    {
        name = "Hip-Hop - Dirty South",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.25, 0.875} }, -- Kick & Sub Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["SnareEdge"], vel = 100, positions = {0.75, 0.9375} }, -- Clave (using Rimshot)
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hat 4ths
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.375} } -- Open Hat
        }
    },
    {
        name = "Moombahton",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.375, 0.75, 0.875} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.625} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 95,  positions = {0.1875, 0.6875} } -- Closed Hat
        }
    },
    {
        name = "Classic House",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat 8ths
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Trance",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["Snare/Clap"], vel = 110, positions = {0.25, 0.75} }, -- Clap
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.8125, 0.875, 0.9375} }, -- Closed Hat 16ths
            { pitch = M.drum_map["HiHatOpen"], vel = 105, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Trap - Variant",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.5625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.125} } -- Open Hat
        }
    },
    {
        name = "Boom Bap (90s)",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.5, 0.6875} }, -- Main Kicks (Strong)
            { pitch = M.drum_map["BassDrum"], vel = 85,  positions = {0.125} }, -- Ghost Kick (User req: 85 velocity)
            { pitch = M.drum_map["SnareHit"], vel = 125, positions = {0.25, 0.75} }, -- Snare (2, 4) strong
            { pitch = M.drum_map["HiHatClosed"], vel = 110, positions = {0, 0.25, 0.5, 0.75} }, -- Hat Downbeats
            { pitch = M.drum_map["HiHatClosed"], vel = 85,  positions = {0.125, 0.375, 0.625, 0.875} }, -- Hat Upbeats
            { pitch = M.drum_map["HiHatClosed"], vel = 50,  positions = {0.46875} } -- Ghost 32nd (0.46875) only
        }
    },
    {
        name = "Hip-Hop - 16th Hats",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.1875, 0.375, 0.625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 85,  positions = {0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.8125, 0.875, 0.9375} } -- Hi-hat 16ths
        }
    },
    {
        name = "Dubstep - Half-Time Variant",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 125, positions = {0.5} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0.375, 0.875} }, -- Closed Hat
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.125, 0.625} } -- Open Hat
        }
    },
    {
        name = "Deep House - Variant",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = M.drum_map["Snare/Clap"], vel = 110, positions = {0.25, 0.75} }, -- Clap
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.5} }, -- Closed Hat (simplified from image)
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Jungle Breakbeat",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.5625} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 120, positions = {0.25, 0.6875, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.875} }, -- Closed Hat
        
            { pitch = M.drum_map["HiHatOpen"], vel = 110, positions = {0.75} } -- Open Hat (with snare)
        }
    },
    {
        name = "Salsa Tumbao",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 90, positions = {0, 0.5} }, -- Kick (Tumbadora bass)
            { pitch = M.drum_map["Claves"], vel = 110, positions = {0, 0.1875, 0.375, 0.625, 0.75} }, -- Clave
            { pitch = M.drum_map["OpenHiConga"], vel = 100, positions = {0.25, 0.75} }, -- High Conga (Slap)
            { pitch = M.drum_map["LowConga"], vel = 105, positions = {0.375, 0.875} }, -- Low Conga (Open)
            { pitch = M.drum_map["SnareEdge"], vel = 80, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Rimshot (Cascara simulation)
        }
    },
    {
        name = "R&B - Beat Starter",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 100, positions = {0.375, 0.875} }, -- Snare (Less Velocity)
            { pitch = M.drum_map["HiHatClosed"], vel = 127, positions = {0, 0.125, 0.25, 0.4375, 0.5, 0.625, 0.75, 0.9375} }, -- Closed Hats (Full Velocity)
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0.0625, 0.5625} }, -- Closed Hats (Less Velocity)
            { pitch = M.drum_map["HiHatOpen"], vel = 100, positions = {0.3125, 0.8125} }  -- Open Hats (Less Velocity)
        }
    },
    {
        name = "Trap - Beat Starter",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.0625, 0.5, 0.8125, 0.875} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 100, positions = {0.375, 0.875} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 127, positions = {0, 0.25, 0.5, 0.6875, 0.75} }, -- Closed Hats (Full Velocity)
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0.125, 0.375, 0.5625, 0.625, 0.8125, 0.875, 0.9375} }  -- Closed Hats (Less Velocity)
        }
    },
	{
        name = "Trap - Beat Starter 8",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.125, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 100, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 127, positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hats (Full Velocity)
            { pitch = M.drum_map["HiHatClosed"], vel = 100, positions = {0.125, 0.375, 0.625, 0.875} }  -- Closed Hats (Less Velocity)
        }
    },
    
    --- NEW (v3.0) ---
    {
        name = "Reggaeton (Dem Bow)",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 125, positions = {0, 0.375, 0.75} }, -- Kick
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.625} }, -- Snare
            { pitch = M.drum_map["HiHatClosed"], vel = 90, positions = {0.125, 0.875} } -- Hi-hat
        }
    },
    {
        name = "Metal (Double Kick)",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Kick 8ths
            { pitch = M.drum_map["SnareHit"], vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = M.drum_map["Crash"], vel = 110, positions = {0} } -- Crash on 1
        }
    },
    {
        name = "Half-Time Rock",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 120, positions = {0} }, -- Kick on 1
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.5} }, -- Snare on 3
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Bossa Nova (Basic)",
        pattern = {
            { pitch = M.drum_map["SnareEdge"], vel = 100, positions = {0, 0.1875, 0.375, 0.5625, 0.75, 0.9375} }, -- Rimshot (Clave)
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Hi-hat 8ths
            { pitch = M.drum_map["BassDrum"], vel = 115, positions = {0, 0.375, 0.5, 0.875} } -- Kick
        }
    },
    {
        name = "Vinahouse (VN Dance)",
        pattern = {
            { pitch = M.drum_map["BassDrum"], vel = 127, positions = {0, 0.25, 0.5, 0.75} }, -- Strong Kick 4/4 ("Four-on-the-floor")
            { pitch = M.drum_map["SnareHit"], vel = 110, positions = {0.25, 0.75} }, -- Snare on 2 & 4
            { pitch = M.drum_map["Snare/Clap"], vel = 120, positions = {0.25, 0.75} }, -- Layered Clap on 2 & 4 (Punchy)
            { pitch = M.drum_map["HiHatOpen"], vel = 115, positions = {0.125, 0.375, 0.625, 0.875} }, -- Off-beat Open Hat ("Thúc giục")
            { pitch = M.drum_map["HiHatClosed"], vel = 90,  positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hat filler (16ths, avoiding open hat)
            { pitch = M.drum_map["Tom1"], vel = 100, positions = {0.4375, 0.9375} } -- Scatter Percussion (Tom fills)
        }
    },
    --- END NEW (v3.0) ---
}

-------------------------------------------
-- 7. MELODY PATTERN LIBRARY (UPDATED v3.0)
-------------------------------------------
-- Định nghĩa các mẫu giai điệu (motif) có thể tái sử dụng.
-- Mỗi nốt được định nghĩa bằng:
--   - start: Vị trí bắt đầu (0.0 đến 1.0) trong phạm vi hợp âm/ô nhịp.
--   - duration: Trường độ (0.0 đến 1.0) của nốt.
--   - interval: Quãng (tính bằng bán cung) so với NỐT GỐC của hợp âm.
--   - (Tùy chọn) octave_offset: Dịch chuyển quãng tám (ví dụ: 12).
M.melody_patterns = {
    {
        name = "Arp Up (8th Notes)",
        notes = {
            { start = 0,    duration = 0.125, interval = 0 },  -- Nốt gốc
            { start = 0.125, duration = 0.125, interval = 4 },  -- Nốt bậc 3 (sẽ tự động thành 3 nếu hợp âm là thứ)
            { start = 0.25,  duration = 0.125, interval = 7 },  -- Nốt bậc 5
            { start = 0.375, duration = 0.125, interval = 12 }, -- Nốt gốc (quãng 8)
            { start = 0.5,   duration = 0.125, interval = 0 },  
            { start = 0.625, duration = 0.125, interval = 4 }, 
            { start = 0.75,  duration = 0.125, interval = 7 },  
            { start = 0.875, duration = 0.125, interval = 12 }
        }
    },
    {
        name = "Rhythmic Motif 1",
        notes = {
            { start = 0.375, duration = 0.125, interval = 7 }, -- Nốt bậc 5 ở cuối phách 2
            { start = 0.5,   duration = 0.25,  interval = 12 }, -- Nốt gốc (q8) ở phách 3
            { start = 0.75,  duration = 0.125, interval = 9 }  -- Nốt bậc 6 (sẽ tự nắn vào âm giai)
        }
    },
    {
        name = "Scale Run Up (16ths)",
        notes = {
            { start = 0,    duration = 0.0625, interval = 0 }, -- Bậc 1
            { start = 0.0625, duration = 0.0625, interval = 2 }, -- Bậc 2
            { start = 0.125,  duration = 0.0625, interval = 4 }, -- Bậc 3 (sẽ nắn)
            { start = 0.1875, duration = 0.0625, interval = 5 }, -- Bậc 4
            { start = 0.25,   duration = 0.0625, interval = 7 }, -- Bậc 5
            { start = 0.3125, duration = 0.0625, interval = 9 }, -- Bậc 6 (sẽ nắn)
            { start = 0.375,  duration = 0.0625, interval = 11 }, -- Bậc 7 (sẽ nắn)
            { start = 0.4375, duration = 0.0625, interval = 12 }  -- Bậc 8
        }
    },
    
    -- CÁC MẪU MỚI (v2.7)
    {
        name = "Arp Down (8th Notes)",
        notes = {
            { start = 0,    duration = 0.125, interval = 12 }, -- Nốt gốc (quãng 8)
            { start = 0.125, duration = 0.125, interval = 7 },  -- Nốt bậc 5
            { start = 0.25,  duration = 0.125, interval = 4 },  -- Nốt bậc 3 (sẽ nắn)
            { start = 0.375, duration = 0.125, interval = 0 },  -- Nốt gốc
            { start = 0.5,   duration = 0.125, interval = 12 }, 
            { start = 0.625, duration = 0.125, interval = 7 }, 
            { start = 0.75,  duration = 0.125, interval = 4 }, 
            { start = 0.875, duration = 0.125, interval = 0 }
        }
    },
    {
        name = "Arp Up/Down (16ths)",
        notes = {
            { start = 0,      duration = 0.0625, interval = 0 }, 
            { start = 0.0625, duration = 0.0625, interval = 4 }, 
            { start = 0.125,  duration = 0.0625, interval = 7 }, 
            { start = 0.1875, duration = 0.0625, interval = 12 },
            { start = 0.25,   duration = 0.0625, interval = 7 }, 
            { start = 0.3125, duration = 0.0625, interval = 4 },
            { start = 0.375,  duration = 0.0625, interval = 0 },
            { start = 0.4375, duration = 0.0625, interval = -5 } -- Nốt bậc 5 (thấp)
        }
    },
    {
        name = "Syncopated Root+5th",
        notes = {
            { start = 0,     duration = 0.25,  interval = 0 }, -- Nốt gốc ở phách 1
            { start = 0.375, duration = 0.125, interval = 7 }, -- Nốt 5 ở cuối phách 2
            { start = 0.625, duration = 0.25,  interval = 7 }  -- Nốt 5 ở giữa phách 3
        }
    },
    {
        name = "Pop Root Rhythm",
        notes = {
            { start = 0,     duration = 0.25,  interval = 0 },
            { start = 0.375, duration = 0.125, interval = 0 },
            { start = 0.625, duration = 0.125, interval = 0, octave_offset = 12 }
        }
    },
    {
        name = "Guide Tones (3rd/7th)",
        notes = {
            -- (Sẽ tự động nắn 4->3 (thứ) và 10->11 (maj7) bởi logic)
            { start = 0,   duration = 0.5, interval = 4 }, -- Bậc 3
            { start = 0.5, duration = 0.5, interval = 10 } -- Bậc 7
        }
    },
    {
        name = "Scale Run Down (16ths)",
        notes = {
            { start = 0,    duration = 0.0625, interval = 12 }, -- Bậc 8
            { start = 0.0625, duration = 0.0625, interval = 11 }, -- Bậc 7
            { start = 0.125,  duration = 0.0625, interval = 9 }, -- Bậc 6
            { start = 0.1875, duration = 0.0625, interval = 7 }, -- Bậc 5
            { start = 0.25,   duration = 0.0625, interval = 5 }, -- Bậc 4
            { start = 0.3125, duration = 0.0625, interval = 4 }, -- Bậc 3
            { start = 0.375,  duration = 0.0625, interval = 2 }, -- Bậc 2
            { start = 0.4375, duration = 0.0625, interval = 0 }  -- Bậc 1
        }
    },
    
    --- NEW (v3.0) ---
    {
        name = "Rhythmic Motif 2 (Syncopated)",
        notes = {
            { start = 0.125, duration = 0.125, interval = 0 }, -- & of 1
            { start = 0.375, duration = 0.25,  interval = 4 }, -- & of 2
            { start = 0.875, duration = 0.125, interval = 7 }  -- & of 4
        }
    },
    {
        name = "Scale Run (3rds Up)",
        notes = {
            { start = 0,      duration = 0.125, interval = 0 }, -- 1
            { start = 0.125,  duration = 0.125, interval = 4 }, -- 3
            { start = 0.25,   duration = 0.125, interval = 2 }, -- 2
            { start = 0.375,  duration = 0.125, interval = 7 }, -- 5
            { start = 0.5,    duration = 0.125, interval = 5 }, -- 4
            { start = 0.625,  duration = 0.125, interval = 9 }, -- 6
            { start = 0.75,   duration = 0.125, interval = 7 }, -- 5
            { start = 0.875,  duration = 0.125, interval = 12 } -- 8
        }
    },
    {
        name = "Lower Neighbor (8ths)",
        notes = {
            { start = 0,      duration = 0.125, interval = 0 },  -- 1
            { start = 0.125,  duration = 0.125, interval = -1 }, -- 7 (sẽ nắn)
            { start = 0.25,   duration = 0.125, interval = 0 },  -- 1
            { start = 0.375,  duration = 0.125, interval = 4 },  -- 3
            { start = 0.5,    duration = 0.125, interval = 2 },  -- 2
            { start = 0.625,  duration = 0.125, interval = 4 },  -- 3
            { start = 0.75,   duration = 0.125, interval = 0 },  -- 1
            { start = 0.875,  duration = 0.125, interval = 7 }   -- 5
        }
    },
    {
        name = "Pulsing 8ths (Root)",
        notes = {
            { start = 0,      duration = 0.125, interval = 0 },
            { start = 0.125,  duration = 0.125, interval = 0 },
            { start = 0.25,   duration = 0.125, interval = 0 },
            { start = 0.375,  duration = 0.125, interval = 0 },
            { start = 0.5,    duration = 0.125, interval = 0 },
            { start = 0.625,  duration = 0.125, interval = 0 },
            { start = 0.75,   duration = 0.125, interval = 0 },
            { start = 0.875,  duration = 0.125, interval = 0 }
        }
    },
    --- END NEW (v3.0) ---
}


-- This is essential for the main script to be able to load the library.
return M
