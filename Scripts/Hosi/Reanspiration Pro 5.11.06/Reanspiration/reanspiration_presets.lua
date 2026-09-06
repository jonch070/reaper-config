-- @description Presets Module for Reanspiration Pro
-- @version 1.1 (Expanded Library)
-- @author Hosi

local Presets = {}

-----------------------------------------------------------
-- 1. FACTORY PRESETS
-----------------------------------------------------------
Presets.factory = {
    -- === POP & BALLAD ===
    {
        name = "Modern Pop Standard",
        genre = "Pop",
        description = "Radio-ready pop sound. Simple, effective.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0, -- Triads
            selected_rhythm_pattern = 1, -- Basic
            selected_drum_pattern = 1, -- Standard 4/4
            selected_bass_pattern = 1, -- Root
            arp_rate = 0.5,
            humanize_strength_timing = 10,
            humanize_strength_velocity = 10,
            selected_voicing = 1, 
        }
    },
    {
        name = "Pop Ballad Piano",
        genre = "Pop",
        description = "Emotional, slow, open voicings.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0,
            selected_rhythm_pattern = 0, -- Sustained
            selected_drum_pattern = 0, -- None
            arp_rate = 0.5,
            selected_voicing = 3, -- Open
            humanize_strength_velocity = 30,
            humanize_strength_timing = 20,
        }
    },
    {
        name = "80s Synth Pop",
        genre = "Pop",
        description = "Retro vibes, straight 8th bass, gated feel.",
        data = {
            selected_scale_type = 1, 
            complexity = 0, 
            selected_rhythm_pattern = 1,
            selected_drum_pattern = 1,
            selected_bass_pattern = 2, -- Driving 16th (or 8th if available)
            selected_arp_pattern = 1, -- Up
            arp_rate = 0.5, 
            humanize_strength_timing = 0, -- Tight
        }
    },
    {
        name = "Tropical Pluck",
        genre = "Pop",
        description = "Happy, bouncy, simple triads.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0, -- Triads
            selected_rhythm_pattern = 2, -- Offbeat/Reggae-ish
            selected_drum_pattern = 1, -- 4/4
            arp_rate = 0.5,
            humanize_strength_timing = 5, 
            humanize_strength_velocity = 5,
            selected_voicing = 1, -- Close position
        }
    },

    -- === EDM & ELECTRONIC ===
    {
        name = "Future Bass Supersaws",
        genre = "EDM",
        description = "Rich 7th chords, rhythmic gating.",
        data = {
            selected_scale_type = 1, 
            complexity = 1, -- 7ths
            selected_rhythm_pattern = 3, -- Syncopated
            selected_drum_pattern = 2, -- Half-time
            selected_voicing = 3, -- Open
            bass_pattern = 1, -- Root notes
        }
    },
    {
        name = "Cyberpunk Run",
        genre = "EDM",
        description = "Driving bass, fast arps, robotic feel.",
        data = {
            selected_scale_type = 6, -- Dorian
            complexity = 1, 
            selected_rhythm_pattern = 0, 
            selected_drum_pattern = 3, -- Techno
            selected_groove_template = 0, -- Straight
            arp_rate = 0.25, -- 1/16
            selected_perform_mode = 1, -- Arp
            selected_arp_pattern = 3, -- Up/Down
            humanize_strength_timing = 0, -- Robotic
            selected_bass_pattern = 2, -- Driving 16th
            mod_enabled = true, 
        }
    },
    {
        name = "Techno Rumble",
        genre = "EDM",
        description = "Dark, repetitive, mechanical.",
        data = {
            selected_scale_type = 2, -- Minor
            complexity = 0,
            selected_rhythm_pattern = 0,
            selected_drum_pattern = 3, -- Techno
            selected_bass_pattern = 2, -- Driving
            humanize_strength_timing = 0,
            melody_density = 2, -- Sparse
        }
    },
    {
        name = "Trance Uplifting",
        genre = "EDM",
        description = "Fast arps, euphoric chords.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0,
            selected_drum_pattern = 3, -- Techno/Trance beat
            selected_perform_mode = 1, -- Arp
            arp_rate = 0.25, -- 1/16
            selected_arp_pattern = 3, -- Up/Down
            selected_voicing = 3, -- Open
            spread = 1,
        }
    },
    {
        name = "House Piano",
        genre = "EDM",
        description = "Classic M1 style chords.",
        data = {
            selected_scale_type = 2, -- Minor
            complexity = 1, -- 7ths/9ths
            selected_rhythm_pattern = 3, -- Syncopated
            selected_drum_pattern = 1, -- 4/4 House
            humanize_strength_timing = 15, -- Little loose
            selected_voicing = 2, -- Drop 2
        }
    },

    -- === HIP-HOP & R&B ===
    {
        name = "Lofi Chill",
        genre = "Hip-Hop",
        description = "Relaxed beats, jazzy chords, swing feel.",
        data = {
            selected_scale_type = 2, -- Natural Minor
            complexity = 1, -- Simple/Jazzy 7ths
            selected_rhythm_pattern = 1, -- Basic
            selected_drum_pattern = 1, -- Hip Hop Basic
            selected_groove_template = 2, -- 16th Swing
            arp_rate = 0.5, -- 1/8
            humanize_strength_timing = 15,
            humanize_strength_velocity = 20,
            selected_voicing = 2, -- Drop 2
        }
    },
    {
        name = "Dark Trap Gloom",
        genre = "Hip-Hop",
        description = "Minor/Phrygian, haunting simple chords.",
        data = {
            selected_scale_type = 3, -- Phrygian usually (checking if supported, defaulting to 2/Minor if safe)
            complexity = 0, 
            selected_rhythm_pattern = 0, -- Long sustained pads
            selected_drum_pattern = 4, -- Trap
            arp_rate = 0.125, -- Fast hi-hats if applicable
            humanize_strength_timing = 0,
        }
    },
    {
        name = "Neo-Soul Keys",
        genre = "R&B",
        description = "Smooth 9th/11th chords, laid back swing.",
        data = {
            selected_scale_type = 1, -- Major (likely using relative minor)
            complexity = 2, -- Extended chords (7ths/9ths)
            selected_rhythm_pattern = 1, 
            selected_groove_template = 3, -- Heavy Swing
            humanize_strength_timing = 20,
            humanize_strength_velocity = 25,
            selected_voicing = 2, -- Drop 2 for lushness
            extra_tension = true, 
        }
    },
    {
        name = "Drill Dark",
        genre = "Hip-Hop",
        description = "Sliding 808s logic (if supported), dark minor.",
        data = {
            selected_scale_type = 2, -- Minor
            complexity = 0, 
            selected_drum_pattern = 4, -- Trap/Drill
            selected_rhythm_pattern = 0,
            melody_octave_min = 3, -- Low melody
        }
    },

    -- === JAZZ, BLUES & ROCK ===
    {
        name = "Jazz Walk",
        genre = "Jazz",
        description = "Walking bass lines and swing.",
        data = {
            selected_scale_type = 6, -- Dorian
            complexity = 2, -- 7ths+
            selected_rhythm_pattern = 4, -- Comping
            selected_drum_pattern = 6, -- Jazz (if 6 mapped) or 1
            selected_groove_template = 2, -- Swing
            selected_bass_pattern = 3, -- Walking
        }
    },
    {
        name = "Blues Shuffle",
        genre = "Blues",
        description = "12-bar feel, dominant 7ths.",
        data = {
            selected_scale_type = 5, -- Mixolydian (Dominant)
            complexity = 1, -- 7ths
            selected_groove_template = 3, -- Heavy Swing
            selected_drum_pattern = 1,
            selected_bass_pattern = 1,
        }
    },
    {
        name = "Rock Power",
        genre = "Rock",
        description = "Power chords, driving eighths.",
        data = {
            selected_scale_type = 2, -- Minor
            complexity = 0, -- Triads (Power chords logic internal?)
            selected_rhythm_pattern = 0, -- Sustained or driving
            selected_drum_pattern = 1, -- Rock Beat
            selected_bass_pattern = 1, -- Root
            selected_voicing = 0, -- Close
        }
    },

    -- === CINEMATIC ===
    {
        name = "Epic Cinematic",
        genre = "Cinematic",
        description = "Wide chords, slow movement, dramatic.",
        data = {
            selected_scale_type = 2, -- Natural Minor
            complexity = 0, -- Triads/Power chords
            selected_rhythm_pattern = 0, -- Sustained
            selected_drum_pattern = 5, -- Orchestral Perc
            arp_rate = 1, -- 1/4
            selected_voicing = 4, -- Drop 2+4 (Wide)
            spread = 2, -- Wide spread
            humanize_strength_timing = 5,
            humanize_strength_velocity = 40, -- Dynamic
        }
    },
    {
        name = "Horror Tension",
        genre = "Cinematic",
        description = "Dissonant clusters, random movement.",
        data = {
            selected_scale_type = 7, -- Locrian or Chromatic? (Using 7/Locrian or similar)
            complexity = 2,
            selected_rhythm_pattern = 0,
            arp_rate = 0.5,
            selected_melody_contour = 0, -- Random
            humanize_strength_timing = 30, -- Chaotic
        }
    },
    {
        name = "Hopeful Strings",
        genre = "Cinematic",
        description = "Major scale, swelling dynamics.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0,
            selected_voicing = 4, -- Wide
            selected_rhythm_pattern = 0, -- Sustained
            humanize_strength_velocity = 50, -- Very dynamic
        }
    },

    -- === FUNK & SOUL ===
    {
        name = "Funky Clav",
        genre = "Funk",
        description = "Syncopated 16th notes, sharp articulation.",
        data = {
            selected_scale_type = 6, -- Dorian
            complexity = 1, -- 7ths
            selected_rhythm_pattern = 3, -- Syncopated
            selected_drum_pattern = 1, -- Standard Funky
            selected_bass_pattern = 2, -- Driving 16th
            selected_groove_template = 2, -- 16th Swing
            arp_rate = 0.25, -- 1/16
        }
    },
    {
        name = "Disco Groove",
        genre = "Funk",
        description = "Four on the floor, octave bass.",
        data = {
            selected_scale_type = 6, -- Dorian
            complexity = 1, 
            selected_drum_pattern = 1, -- Disco beat
            selected_bass_pattern = 4, -- Octaves (if available, else 2)
            arp_rate = 0.5,
            spread = 1,
        }
    },

    -- === LATIN & WORLD ===
    {
        name = "Bossa Nova Vibes",
        genre = "Latin",
        description = "Relaxed syncopation, complex jazz chords.",
        data = {
            selected_scale_type = 1, -- Major (often Major 7)
            complexity = 2, -- 9ths
            selected_rhythm_pattern = 2, -- Clave-ish
            selected_drum_pattern = 6, -- Jazz/Latin
            selected_voicing = 2, -- Drop 2
            humanize_strength_timing = 15,
            selected_bass_pattern = 1, -- Root-5 movement simulation
        }
    },
    {
        name = "Reggaeton Beat",
        genre = "Latin",
        description = "Dembow rhythm, simple minor chords.",
        data = {
            selected_scale_type = 2, -- Minor
            complexity = 0, -- Triads
            selected_drum_pattern = 10, -- Reggaeton (if mapped, or specific pattern)
            selected_rhythm_pattern = 2, -- Offbeat
            humanize_strength_velocity = 0, -- Tight
        }
    },
    {
        name = "Oriental Pentatonic",
        genre = "World",
        description = "Open fifths, pentatonic melody.",
        data = {
            selected_scale_type = 4, -- Pentatonic Major/Minor
            complexity = 0,
            selected_voicing = 3, -- Open 5ths
            melody_density = 2, -- Sparse
            humanize_strength_timing = 25, -- Loose
        }
    },

    -- === AMBIENT & CHILL ===
    {
        name = "Deep Space Drone",
        genre = "Ambient",
        description = "Slow, massive chords, huge reverb.",
        data = {
            selected_scale_type = 7, -- Lydian (often floaty)
            complexity = 1, 
            selected_rhythm_pattern = 0, -- Sustained
            arp_rate = 1, -- Slow
            selected_voicing = 4, -- Wide
            humanize_strength_velocity = 10,
            spread = 2,
        }
    },
    {
        name = "Underwater Pad",
        genre = "Ambient",
        description = "Muffled, filtered feeling.",
        data = {
            selected_scale_type = 2, -- Minor
            complexity = 2, -- 9ths
            selected_rhythm_pattern = 0,
            melody_density = 1, -- Very sparse
            humanize_strength_timing = 50, -- Very loose
        }
    },

    -- === VIDEO GAME ===
    {
        name = "8-Bit Adventure",
        genre = "Game",
        description = "Fast arps, simple triads, heroic.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0, -- Triads
            selected_perform_mode = 1, -- Arp
            arp_rate = 0.25, -- 1/16
            selected_arp_pattern = 1, -- Up
            selected_drum_pattern = 1, -- Basic
            humanize_strength_timing = 0, -- Quantized
        }
    },
    {
        name = "RPG Village",
        genre = "Game",
        description = "Pastoral, woodwind style, pizzicato.",
        data = {
            selected_scale_type = 1, -- Major
            complexity = 0,
            selected_rhythm_pattern = 1, 
            selected_drum_pattern = 0, -- None
            arp_rate = 0.5,
            humanize_strength_timing = 10,
        }
    },
    {
        name = "Boss Battle",
        genre = "Game",
        description = "Fast, diminished, intense.",
        data = {
            selected_scale_type = 7, -- Diminished/Locrian
            complexity = 0,
            selected_drum_pattern = 3, -- Intense
            arp_rate = 0.125, -- 1/32 or fast 1/16
            selected_bass_pattern = 2, -- Driving
            mod_enabled = true, -- Key changes
        }
    },
    
    -- === EXPERIMENTAL ===
    {
        name = "Math Rock Intro",
        genre = "Experimental",
        description = "Odd time feel, clean taping.",
        data = {
            selected_scale_type = 6, -- Dorian/Lydian
            complexity = 2, -- Color tones
            selected_perform_mode = 1, -- Arp
            arp_rate = 0.33, -- Triplet feel maybe
            selected_voicing = 3,
        }
    },
    {
        name = "Random Chaos",
        genre = "Experimental",
        description = "High randomness, unpredictable.",
        data = {
            selected_scale_type = 0, -- Chromatic (if 0) or Random
            complexity = 5, -- Altered
            humanize_strength_timing = 100, -- Maximum slop
            humanize_strength_velocity = 100,
            melody_contour = 0, -- Random
        }
    }
}

-----------------------------------------------------------
-- 2. FILE I/O UTILITIES
-----------------------------------------------------------

function Presets.loadUserPresets(filepath)
    local file = io.open(filepath, "r")
    if not file then return {} end
    
    local content = file:read("*a")
    file:close()
    
    if not content or content == "" then return {} end
    
    local func, err = load("return " .. content)
    if not func then 
        reaper.ShowConsoleMsg("Error loading presets: " .. tostring(err) .. "\n")
        return {} 
    end
    
    local success, result = pcall(func)
    if success then return result else return {} end
end

function Presets.saveUserPresets(filepath, presets_table)
    local file = io.open(filepath, "w")
    if not file then return false, "Cannot open file for writing" end
    
    file:write("{\n")
    for _, preset in ipairs(presets_table) do
        file:write(string.format("  {\n    name = %q,\n    genre = %q,\n    description = %q,\n    data = {\n", 
            preset.name, preset.genre or "User", preset.description or ""))
        
        for k, v in pairs(preset.data) do
            local val_str = tostring(v)
            if type(v) == "string" then val_str = string.format("%q", v) end
            if type(v) == "boolean" then val_str = tostring(v) end
            file:write(string.format("      %s = %s,\n", k, val_str))
        end
        
        file:write("    }\n  },\n")
    end
    file:write("}\n")
    file:close()
    return true
end

-----------------------------------------------------------
-- 3. PACK SYSTEM (DLC / Factory Packs)
-----------------------------------------------------------

-- Save/overwrite a pack file to disk.
-- pack_data = { pack_name, pack_id, pack_version, pack_author, presets=[{name,genre,description,data}] }
function Presets.savePack(filepath, pack_data)
    local file = io.open(filepath, "w")
    if not file then return false, "Cannot open file: " .. filepath end

    file:write("return {\n")
    file:write(string.format("    pack_name    = %q,\n", pack_data.pack_name    or "My Pack"))
    file:write(string.format("    pack_id      = %q,\n", pack_data.pack_id      or "my_pack"))
    file:write(string.format("    pack_version = %q,\n", pack_data.pack_version or "1.0"))
    file:write(string.format("    pack_author  = %q,\n", pack_data.pack_author  or ""))
    file:write("    presets = {\n")

    local inst_keys = {"Kick","Snare","Stick","HatC","HatHO","HatO","HatP",
                       "TomH","TomM","TomL","Ride","Bell","Crash1","Crash2","Crash2C","China","Splash"}

    for _, preset in ipairs(pack_data.presets) do
        file:write(string.format("        {\n            name        = %q,\n            genre       = %q,\n            description = %q,\n",
            preset.name, preset.genre or "", preset.description or ""))
        file:write("            data = {\n")
        for _, k in ipairs(inst_keys) do
            if preset.data[k] then
                file:write(string.format("                %-8s = %q,\n", k, preset.data[k]))
            end
        end
        file:write("            }\n        },\n")
    end

    file:write("    }\n}\n")
    file:close()
    return true
end

-- Scan a directory and auto-load all files matching reanspiration_pack_*.lua
-- Each pack file must return a table with: pack_name, pack_id, pack_version, pack_author, presets
function Presets.scanAndLoadPacks(dir_path)
    local packs = {}
    if not reaper or not reaper.EnumerateFiles then return packs end

    local i = 0
    while true do
        local filename = reaper.EnumerateFiles(dir_path, i)
        if not filename then break end

        -- Only match reanspiration_pack_*.lua
        if filename:match("^reanspiration_pack_.*%.lua$") then
            local filepath = dir_path .. filename
            local ok, result = pcall(dofile, filepath)
            if ok and type(result) == "table" and type(result.presets) == "table" and #result.presets > 0 then
                -- Inject filename so we can display source info
                result._filename = filename
                table.insert(packs, result)
            elseif not ok then
                reaper.ShowConsoleMsg("[Reanspiration] Failed to load pack: " .. filename .. "\n  " .. tostring(result) .. "\n")
            end
        end
        i = i + 1
    end

    -- Sort packs alphabetically by name
    table.sort(packs, function(a, b)
        return (a.pack_name or "") < (b.pack_name or "")
    end)

    return packs
end

return Presets
