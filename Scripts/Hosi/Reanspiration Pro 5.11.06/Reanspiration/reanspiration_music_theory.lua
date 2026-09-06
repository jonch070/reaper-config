-- @description Music Theory Module for Reanspiration
-- @version 1.1 (Added Pivot Chord Detection)
-- @author Hosi
-- @about
--   Chứa các định nghĩa về Âm giai, Hợp âm, và các thuật toán xử lý
--   Logic nhạc lý (Music Theory Logic) tách từ file chính.

local Theory = {}
local reaper = reaper

-- Tự động load Utils từ cùng thư mục nếu chưa có
local function loadUtils()
    local script_path_info = debug.getinfo(1, "S")
    local script_path = script_path_info.source:match("@?(.*[/\\])")
    if not script_path then return nil end
    local success, lib = pcall(dofile, script_path .. "reanspiration_utils.lua")
    if success then return lib else return nil end
end

local Utils = loadUtils()
if not Utils then 
    reaper.ShowConsoleMsg("Error: Could not load reanspiration_utils.lua inside Music Theory module.\n") 
end

-----------------------------------------------------------
-- 1. CONSTANTS & DEFINITIONS (Dữ liệu tĩnh)
-----------------------------------------------------------

Theory.note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

Theory.scales = {
  {name = "C", notes = {0, 2, 4, 5, 7, 9, 11}},
  {name = "C#/Db", notes = {1, 3, 5, 6, 8, 10, 0}},
  {name = "D", notes = {2, 4, 6, 7, 9, 11, 1}},
  {name = "D#/Eb", notes = {3, 5, 7, 8, 10, 0, 2}},
  {name = "E", notes = {4, 6, 8, 9, 11, 1, 3}},
  {name = "F", notes = {5, 7, 9, 10, 0, 2, 4}},
  {name = "F#/Gb", notes = {6, 8, 10, 11, 1, 3, 5}},
  {name = "G", notes = {7, 9, 11, 0, 2, 4, 6}},
  {name = "G#/Ab", notes = {8, 10, 0, 1, 3, 5, 7}},
  {name = "A", notes = {9, 11, 1, 2, 4, 6, 8}},
  {name = "A#/Bb", notes = {10, 0, 2, 3, 5, 7, 9}},
  {name = "B", notes = {11, 1, 3, 4, 6, 8, 10}},
}

Theory.scale_types = {
  ["Major"] = {0, 2, 4, 5, 7, 9, 11},
  ["Natural Minor"] = {0, 2, 3, 5, 7, 8, 10},
  ["Harmonic Minor"] = {0, 2, 3, 5, 7, 8, 11},
  ["Melodic Minor"] = {0, 2, 3, 5, 7, 9, 11},
  ["Pentatonic"] = {0, 2, 4, 7, 9, 0, 2},
  ["Dorian"] = {0, 2, 3, 5, 7, 9, 10},
  ["Mixolydian"] = {0, 2, 4, 5, 7, 9, 10},
  ["Phrygian"] = {0, 1, 3, 5, 7, 8, 10},
  ["Lydian"] = {0, 2, 4, 6, 7, 9, 11},
  ["Locrian"] = {0, 1, 3, 5, 6, 8, 10},
  ["Double Harmonic Major"] = {0, 1, 4, 5, 7, 8, 11},
  ["Neapolitan Major"] = {0, 1, 3, 5, 7, 9, 11},
  ["Neapolitan Minor"] = {0, 1, 3, 5, 7, 8, 11},
  ["Hungarian Minor"] = {0, 2, 3, 6, 7, 8, 11},
}

-----------------------------------------------------------
-- 2. BASIC PITCH UTILITIES
-----------------------------------------------------------

-- Chuyển đổi MIDI pitch sang tên nốt (ví dụ: 60 -> "C4")
function Theory.pitchToNoteName(pitch)
    local octave = math.floor(pitch / 12) - 1
    local note_name = Theory.note_names[(pitch % 12) + 1]
    return note_name .. octave
end

-- Nắn nốt vào scale gần nhất
function Theory.snapNoteToScale(pitch, scale_pcs)
    if not scale_pcs or next(scale_pcs) == nil then return pitch end

    local note_pc = pitch % 12
    if scale_pcs[note_pc] then return pitch end -- Already in scale

    local min_dist = 12
    for pc in pairs(scale_pcs) do
        local dist = pc - note_pc
        if math.abs(dist) < math.abs(min_dist) then
            min_dist = dist
        end
        -- Check wrapped distance
        dist = (pc - note_pc + 12) % 12
        if dist > 6 then dist = dist - 12 end
        if math.abs(dist) < math.abs(min_dist) then
            min_dist = dist
        end
    end

    return pitch + min_dist
end


function Theory.getNearestChordTone(current_pitch, chord_pcs)
    local candidates = {}
    for i = -12, 12 do
        if chord_pcs[(current_pitch + i) % 12] then
            table.insert(candidates, current_pitch + i)
        end
    end
    table.sort(candidates, function(a,b) return math.abs(a - current_pitch) < math.abs(b - current_pitch) end)
    return candidates[1] or current_pitch
end

-----------------------------------------------------------
-- 3. CHORD GENERATION & MANIPULATION
-----------------------------------------------------------

-- NEW: Tìm các bậc hợp âm chung giữa 2 scale (Pivot Chords)
function Theory.getPivotChords(scale_a_notes, scale_b_notes)
    local pivot_degrees = {}
    local scale_b_set = {}
    for _, pc in ipairs(scale_b_notes) do scale_b_set[pc] = true end

    -- Duyệt qua từng bậc của Scale A
    -- Kiểm tra xem hợp âm 3 nốt (Triad: 1-3-5) của bậc đó có nằm trọn trong Scale B không
    for i = 1, #scale_a_notes do
        local root = scale_a_notes[i]
        local third = scale_a_notes[((i + 2 - 1) % #scale_a_notes) + 1]
        local fifth = scale_a_notes[((i + 4 - 1) % #scale_a_notes) + 1]
        
        if scale_b_set[root] and scale_b_set[third] and scale_b_set[fifth] then
            table.insert(pivot_degrees, i)
        end
    end
    return pivot_degrees
end

function Theory.adjustChord(chord, scale_notes)
  local n = #chord
  table.sort(chord)

  for i = 2, n do
    while chord[i] - chord[i-1] > 12 do
      chord[i] = chord[i] - 12
    end
    if math.abs(chord[i] - chord[i-1]) <= 1 then
      if i < n then
        chord[i] = chord[i] + 12
      else
        chord[i-1] = chord[i-1] - 12
      end
    end
  end

  if scale_notes then
    local scale_set = {}
    for _, pc in ipairs(scale_notes) do scale_set[pc] = true end
    
    for i = 1, #chord do
      chord[i] = Theory.snapNoteToScale(chord[i], scale_set)
    end
  end

  return chord
end

function Theory.getChord(scale, degree, type, complexity)
    if not scale or not degree or degree > #scale then return nil end
    local root = scale[degree]
    local chord = {root}

    -- Step 1: Build basic triad
    if type == "major" or type == "dominant" then
        table.insert(chord, (root + 4) % 12)
        table.insert(chord, (root + 7) % 12)
    elseif type == "minor" then
        table.insert(chord, (root + 3) % 12)
        table.insert(chord, (root + 7) % 12)
    elseif type == "diminished" then
        table.insert(chord, (root + 3) % 12)
        table.insert(chord, (root + 6) % 12)
    elseif type == "sus2" then
        table.insert(chord, (root + 2) % 12)
        table.insert(chord, (root + 7) % 12)
    elseif type == "sus4" then
        table.insert(chord, (root + 5) % 12)
        table.insert(chord, (root + 7) % 12)
    end

    -- Step 2: Extensions
    if complexity >= 1 then -- 7ths
        if type == "dominant" then
            table.insert(chord, (root + 10) % 12)
        elseif type == "major" then
            table.insert(chord, (root + 11) % 12)
        elseif type == "minor" then
            table.insert(chord, (root + 10) % 12)
        elseif type == "diminished" then
             table.insert(chord, (root + 10) % 12) -- m7b5
        end
    end

    if complexity >= 2 then -- 9ths
        table.insert(chord, (root + 14) % 12)
    end

    if complexity >= 3 then -- 11ths
        if type == "major" or type == "dominant" then
            table.insert(chord, (root + 18) % 12) -- #11
        else
            table.insert(chord, (root + 17) % 12) -- 11
        end
    end

    if complexity >= 4 and type ~= "diminished" then -- 13ths
        table.insert(chord, (root + 21) % 12)
    end

    if complexity >= 5 then -- Alterations
        if type == "dominant" then
            local fifth_index = Utils.indexOf(chord, (root + 7) % 12)
            local ninth_index = Utils.indexOf(chord, (root + 2) % 12) -- 14 % 12 = 2

            local alteration_type = Utils.selectRandom({1, 2, 3})
            if alteration_type == 1 and fifth_index then
                chord[fifth_index] = (root + Utils.selectRandom({6, 8})) % 12 -- b5 or #5
            elseif alteration_type == 2 and ninth_index then
                chord[ninth_index] = (root + Utils.selectRandom({1, 3})) % 12 -- b9 or #9
            else
                table.insert(chord, (root + Utils.selectRandom({1, 3, 6, 8})) % 12)
            end
        else
             local dissonant_notes = {1, 6, 8}
             table.insert(chord, (root + Utils.selectRandom(dissonant_notes)) % 12)
        end
    end

    while #chord > 7 do
        table.remove(chord, math.random(2, #chord))
    end

    local snap_to_scale = complexity < 5
    local adjusted_chord = Theory.adjustChord(chord, snap_to_scale and scale or nil)

    return adjusted_chord
end

function Theory.invertChord(chord, inversion)
  for i = 1, inversion do
    local note = table.remove(chord, 1)
    table.insert(chord, note + 12)
  end
  return chord
end

function Theory.getChordInversion(chord, inversion)
  local new_chord = {table.unpack(chord)}
  return Theory.invertChord(new_chord, inversion)
end

function Theory.applySpread(chord, spread_amount)
  table.sort(chord)
  if #chord < 3 or spread_amount == 0 then return chord end

  if spread_amount >= 1 and #chord >= 3 then
    chord[#chord-1] = chord[#chord-1] + 12
  end
  if spread_amount >= 2 and #chord >= 4 then
    chord[#chord-2] = chord[#chord-2] + 12
  end

  table.sort(chord)
  return chord
end

function Theory.applyDropVoicing(chord, voicing_type)
  table.sort(chord)
  if #chord < 4 or voicing_type == "None" then return chord end

  if voicing_type == "Drop 2" then
    local note_to_move = table.remove(chord, #chord - 1)
    table.insert(chord, 1, note_to_move - 12)
  elseif voicing_type == "Drop 3" then
    local note_to_move = table.remove(chord, #chord - 2)
    table.insert(chord, 1, note_to_move - 12)
  elseif voicing_type == "Drop 4" then
    if #chord >= 4 then
      local note_to_move = table.remove(chord, #chord - 3)
      table.insert(chord, 1, note_to_move - 12)
    end
  elseif voicing_type == "Drop 2+4" then
    if #chord >= 4 then
      local note_2 = table.remove(chord, #chord - 1)
      local note_4 = table.remove(chord, #chord - 2)
      table.insert(chord, 1, note_2 - 12)
      table.insert(chord, 1, note_4 - 12)
    end
  end

  table.sort(chord)
  return chord
end

-- NEW: Guitar Open Voicing (String Separation)
function Theory.getGuitarVoicing(chord_tones_pc, root_pc, bass_octave)
    local voicing = {}
    local bass_pitch = root_pc + (bass_octave * 12) -- E.g. E2 range (approx 40-52)
    
    -- Ensure Bass is in reasonable Guitar Range (E2 - A2 approx)
    while bass_pitch < 40 do bass_pitch = bass_pitch + 12 end 
    while bass_pitch > 57 do bass_pitch = bass_pitch - 12 end
    
    table.insert(voicing, bass_pitch)
    
    -- Typical Guitar "Open" Spread: Root - 5th - Root - 3rd - 5th
    -- Or simply: Distribute chord tones upwards with gaps
    
    -- 1. Find 5th
    local fifth_pc = (root_pc + 7) % 12
    if chord_tones_pc[fifth_pc] then
        local p = fifth_pc + (math.floor(bass_pitch/12) * 12)
        if p <= bass_pitch then p = p + 12 end
        table.insert(voicing, p)
    end
    
    -- 2. Find Octave Root
    local p_root_oct = root_pc + (math.floor(bass_pitch/12) + 1) * 12
    if p_root_oct > voicing[#voicing] then
         table.insert(voicing, p_root_oct)
    else
         -- If 5th was higher, maybe skip or add next octave
         table.insert(voicing, p_root_oct + 12)
    end
    
    -- 3. Find 3rd (Major or Minor)
    local third_pc_maj = (root_pc + 4) % 12
    local third_pc_min = (root_pc + 3) % 12
    local used_3rd = nil
    if chord_tones_pc[third_pc_maj] then used_3rd = third_pc_maj
    elseif chord_tones_pc[third_pc_min] then used_3rd = third_pc_min end
    
    if used_3rd then
        local p = used_3rd + (math.floor(bass_pitch/12) + 1) * 12
        while p <= voicing[#voicing] do p = p + 12 end
         -- Guitar G string is often 3rd or 4th note
        table.insert(voicing, p)
    end
    
    -- 4. Extensions or High 5th
    -- Fill remaining "strings" (up to 6 notes total)
    local candidates = {}
    for pc in pairs(chord_tones_pc) do
        if pc ~= root_pc then -- We have ample roots
            table.insert(candidates, pc)
        end
    end
    
    while #voicing < 6 do
        local last = voicing[#voicing]
        if last > 88 then break end -- Too high
        
        -- Find nearest chord tone > last + 5 semitones (approx)
        local best_p = nil
        local min_d = 100
        for _, pc in ipairs(candidates) do
            local p = pc % 12
            -- Calc octave
            local target_oct = math.floor(last/12)
            local test1 = p + target_oct*12
            local test2 = p + (target_oct+1)*12
            
            if test1 > last and (test1 - last) > 4 then
                if (test1 - last) < min_d then min_d = test1 - last; best_p = test1 end
            end
            if test2 > last and (test2 - last) > 4 then
                if (test2 - last) < min_d then min_d = test2 - last; best_p = test2 end
            end
        end
        
        if best_p then 
            table.insert(voicing, best_p) 
        else
            break 
        end
    end
    
    table.sort(voicing)
    return voicing
end

function Theory.getBestVoiceLeading(prev_chord, chord, bass_override_pc)
    local min_score = math.huge
    local best_voicing = {}
    local initial_chord_pcs = {}
    for _, n in ipairs(chord) do initial_chord_pcs[n] = true end

    table.sort(prev_chord)
    local prev_top_note = prev_chord[#prev_chord]

    for i = 0, #chord - 1 do -- Inversions
        for oct_shift = -1, 1 do -- Octave shifts
            local base_inversion = Theory.getChordInversion(chord, i)
            local candidate_chord = {}
            for _, note_pc in ipairs(base_inversion) do
                table.insert(candidate_chord, note_pc + 60 + (oct_shift * 12))
            end
            table.sort(candidate_chord)

            local candidate_pcs = {}
            for _, n in ipairs(candidate_chord) do candidate_pcs[n % 12] = true end
            local pcs_match = true
            for pc in pairs(initial_chord_pcs) do
                if not candidate_pcs[pc] then
                    pcs_match = false
                    break
                end
            end
            if not pcs_match then goto next_candidate end

            local top_note = candidate_chord[#candidate_chord]
            local top_note_penalty = math.abs(top_note - prev_top_note)

            local total_movement_penalty = 0
            for j = 1, math.min(#prev_chord, #candidate_chord) do
                total_movement_penalty = total_movement_penalty + math.abs(candidate_chord[j] - prev_chord[j])
            end

            local score = (top_note_penalty * 4) + (total_movement_penalty * 1)

            if bass_override_pc ~= nil then
                if #candidate_chord > 0 then
                    local lowest_note_pc = candidate_chord[1] % 12
                    if lowest_note_pc ~= bass_override_pc then
                        score = score + 10000
                    end
                else
                    score = score + 10000
                end
            end

            if score < min_score then
                min_score = score
                best_voicing = candidate_chord
            end
            ::next_candidate::
        end
    end

    if #best_voicing == 0 then
        local adjusted_original = {}
        for _, n in ipairs(chord) do table.insert(adjusted_original, n + 60) end
        return Theory.adjustChord(adjusted_original)
    end

    return best_voicing
end

function Theory.createChordProgression(scale_notes, degrees_specs_list, is_major, complexity, root_note_pitch)
  local chords = {}
  local chord_types_major = {"major", "minor", "minor", "major", "major", "minor", "diminished"}
  local chord_types_minor = {"minor", "diminished", "major", "minor", "minor", "major", "major"}

  for _, spec in ipairs(degrees_specs_list) do
    local duration_multiplier = spec.duration or 1.0
    local bass_degree = spec.bass_degree
    local bass_override_pc = nil

    if bass_degree and type(bass_degree) == "number" and bass_degree >= 1 and bass_degree <= #scale_notes then
        bass_override_pc = scale_notes[bass_degree]
    end

    if spec.is_secondary_dominant then
        local target_degree = spec.target_degree
        local target_root_pc = scale_notes[target_degree]
        if target_root_pc then
            local sec_dom_root_pc = (target_root_pc + 7) % 12
            local temp_scale = {}
            local mixolydian_intervals = {0, 2, 4, 5, 7, 9, 10}
            for _, interval in ipairs(mixolydian_intervals) do
                table.insert(temp_scale, (sec_dom_root_pc + interval) % 12)
            end

            local chord = Theory.getChord(temp_scale, 1, "dominant", complexity)
            if chord then
              chord = Theory.adjustChord(chord, nil)
              table.insert(chords, {
                  degree = "V/" .. target_degree,
                  chord = chord,
                  is_major = true,
                  duration_multiplier = duration_multiplier,
                  bass_override_pc = bass_override_pc
              })
            end
        end
    else
        local degree = spec.degree
        local chord_type
        local use_borrowed = false

        if type(degree) ~= "number" or degree < 1 or degree > #scale_notes then
            goto continue
        end

        -- Modal Interchange Logic (Commented out to prevent out-of-key notes as per user request)
        if complexity >= 4 and degree ~= 1 and math.random() < 0.25 and false then 
            use_borrowed = true
        end

        local current_scale = scale_notes
        local current_chord_types = is_major and chord_types_major or chord_types_minor

        if use_borrowed then
            local parallel_scale_type = is_major and "Natural Minor" or "Major"
            local parallel_scale_intervals = Theory.scale_types[parallel_scale_type]
            current_scale = {}
            for _, interval in ipairs(parallel_scale_intervals) do
                table.insert(current_scale, (root_note_pitch + interval) % 12)
            end
            current_chord_types = is_major and chord_types_minor or chord_types_major
        end

        if not current_chord_types[degree] then
            chord_type = is_major and "major" or "minor"
        else
            chord_type = current_chord_types[degree]
        end

        if is_major and degree == 5 then
            chord_type = "dominant"
        end

        local chord = Theory.getChord(current_scale, degree, chord_type, complexity)
        if not chord or #chord < 3 then
            chord = Theory.getChord(scale_notes, degree, is_major and "major" or "minor", 0)
        end

        if chord then
            chord = Theory.adjustChord(chord, scale_notes)
            table.insert(chords, {
                degree = degree,
                chord = chord,
                is_major = (chord_type == "major" or chord_type == "dominant"),
                duration_multiplier = duration_multiplier,
                bass_override_pc = bass_override_pc
            })
        end
    end
    ::continue::
  end

  return chords
end

-----------------------------------------------------------
-- 4. ANALYSIS UTILITIES
-----------------------------------------------------------

function Theory.getScaleName(scale_pcs)
    if not scale_pcs or #scale_pcs == 0 then return "Unknown/Ambiguous" end

    local input_pcs_set = {}
    for _, pc in ipairs(scale_pcs) do
        input_pcs_set[pc] = true
    end

    local best_match = { score = 0, name = "Unknown/Ambiguous" }

    for root_pc = 0, 11 do
        local root_name = Theory.note_names[root_pc + 1]

        for scale_name, intervals in pairs(Theory.scale_types) do
            local current_score = 0
            local scale_pcs_set = {}
            for _, interval in ipairs(intervals) do
                scale_pcs_set[(root_pc + interval) % 12] = true
            end

            local match_count = 0
            local penalty = 0
            for pc in pairs(input_pcs_set) do
                if scale_pcs_set[pc] then
                    match_count = match_count + 1
                else
                    penalty = penalty + 1
                end
            end

            if penalty == 0 and match_count > best_match.score then
                 best_match.score = match_count
                 best_match.name = root_name .. " " .. scale_name
            elseif penalty > 0 and (match_count - penalty) > best_match.score then
                 best_match.score = match_count - penalty
                 best_match.name = root_name .. " " .. scale_name
            end
        end
    end

    if best_match.score < 3 then
        return "Unknown/Ambiguous"
    end

    return best_match.name
end

function Theory.getChordName(notes_in_chord)
    if not notes_in_chord or #notes_in_chord == 0 then return "?" end

    local pitches = {}
    for _, n in ipairs(notes_in_chord) do table.insert(pitches, n.pitch) end
    table.sort(pitches)

    local lowest_note = pitches[1]
    local lowest_note_pc = lowest_note % 12

    local note_pcs = {}
    for _, p in ipairs(pitches) do note_pcs[p % 12] = true end

    local root_note_pc = lowest_note_pc
    local best_root_score = -1

    for potential_root_pc in pairs(note_pcs) do
        local score = 0
        local intervals_from_this_root = {}
        for pc in pairs(note_pcs) do
            intervals_from_this_root[(pc - potential_root_pc + 12) % 12] = true
        end

        if intervals_from_this_root[7] then score = score + 5 end
        if intervals_from_this_root[4] or intervals_from_this_root[3] then score = score + 3 end
        if intervals_from_this_root[10] or intervals_from_this_root[11] then score = score + 2 end

        if score > best_root_score then
            best_root_score = score
            root_note_pc = potential_root_pc
        end
    end

    local root_name = Theory.note_names[root_note_pc + 1]

    local intervals_from_root = {}
    for pc in pairs(note_pcs) do
        intervals_from_root[(pc - root_note_pc + 12) % 12] = true
    end

    local quality = ""
    if intervals_from_root[4] then
        if intervals_from_root[11] then quality = "maj7"
        elseif intervals_from_root[10] then quality = "7"
        else quality = ""
        end
    elseif intervals_from_root[3] then
        if intervals_from_root[6] then
            if intervals_from_root[10] then quality = "m7b5"
            elseif intervals_from_root[9] then quality = "dim7"
            else quality = "dim"
            end
        elseif intervals_from_root[11] then quality = "m(maj7)"
        elseif intervals_from_root[10] then quality = "m7"
        else quality = "m"
        end
    elseif intervals_from_root[5] then quality = "sus4"
    elseif intervals_from_root[2] then quality = "sus2"
    else quality = "?"
    end

    local extensions = {}
    if intervals_from_root[2] and quality ~= "sus2" then table.insert(extensions, "9") end
    if intervals_from_root[6] and quality ~= "dim" and quality ~= "m7b5" and quality ~= "dim7" and (quality == "7" or quality == "maj7") then table.insert(extensions, "b13") end
    if intervals_from_root[8] and (quality == "7" or quality == "maj7") then table.insert(extensions, "#5") end
    if intervals_from_root[9] and (quality == "7" or quality == "maj7") then table.insert(extensions, "13") end
    if intervals_from_root[1] then table.insert(extensions, "b9") end

    local ext_str = ""
    if #extensions > 0 then
        ext_str = "(" .. table.concat(extensions, ",") .. ")"
    end

    local final_name = root_name .. quality .. ext_str

    if root_note_pc ~= lowest_note_pc then
        final_name = final_name .. "/" .. Theory.note_names[lowest_note_pc + 1]
    end

    return final_name
end

function Theory.analyzeChordsAndScale(take)
    local notes_by_start_time = {}
    local all_note_pcs = {}
    local note_idx = 0
    local DRUM_CHANNEL = 9

    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    local quantization_grid = ppq_per_beat / 8

    while true do
        local ret, _, _, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end

        if chan ~= DRUM_CHANNEL then
            local quantized_startppq = math.floor(startppq / quantization_grid + 0.5) * quantization_grid

            if not notes_by_start_time[quantized_startppq] then
                notes_by_start_time[quantized_startppq] = {}
            end
            table.insert(notes_by_start_time[quantized_startppq], {
                pitch = pitch,
                endppq = endppq,
                vel = vel,
                chan = chan
            })
            all_note_pcs[pitch % 12] = true
        end
        note_idx = note_idx + 1
    end

    local analyzed_chords = {}
    for startppq, notes in pairs(notes_by_start_time) do
        if #notes >= 2 then
            table.sort(notes, function(a, b) return a.pitch < b.pitch end)

            local root_note_pc = notes[1].pitch % 12
            local is_major = false
            if #notes >= 2 then
                for i = 2, #notes do
                    local interval = (notes[i].pitch - notes[1].pitch) % 12
                    if interval == 4 then
                        is_major = true
                        break
                    elseif interval == 3 then
                        is_major = false
                        break
                    end
                end
            end

            local chord_end_ppq = notes[1].endppq
            local chord_tones_pc = {}
            for _, note in ipairs(notes) do
                chord_tones_pc[note.pitch % 12] = true
                if note.endppq > chord_end_ppq then chord_end_ppq = note.endppq end
            end

            table.insert(analyzed_chords, {
                startppq = startppq,
                endppq = chord_end_ppq,
                notes = notes,
                chord_tones_pc = chord_tones_pc,
                root_note_pc = root_note_pc,
                is_major = is_major
            })
        end
    end

    table.sort(analyzed_chords, function(a, b) return a.startppq < b.startppq end)

    -- Merge consecutive identical chords
    local merged_chords = {}
    if #analyzed_chords > 0 then
        local current_merged = analyzed_chords[1]
        for i = 2, #analyzed_chords do
            local next_chord = analyzed_chords[i]
            
            -- Check if continuous (allowing for small gaps/overlaps)
            local is_continuous = (next_chord.startppq - current_merged.endppq) < (quantization_grid * 2.0)
            
            -- Check if identical (Root + Quality)
            local is_identical = (next_chord.root_note_pc == current_merged.root_note_pc) and (next_chord.is_major == current_merged.is_major)
            
            if is_continuous and is_identical then
                current_merged.endppq = math.max(current_merged.endppq, next_chord.endppq)
                -- Merge notes for completeness
                for _, n in ipairs(next_chord.notes) do table.insert(current_merged.notes, n) end
            else
                table.insert(merged_chords, current_merged)
                current_merged = next_chord
            end
        end
        table.insert(merged_chords, current_merged)
        analyzed_chords = merged_chords
    end

    local overall_scale = {}
    for note_pc in pairs(all_note_pcs) do
        table.insert(overall_scale, note_pc)
    end
    table.sort(overall_scale)

    return analyzed_chords, overall_scale
end

-- === SCALE DETECTOR ===
function Theory.detectScaleFromNotes(take)
    if not take then return nil, nil end
    local note_count = reaper.MIDI_CountEvts(take)
    if note_count == 0 then return nil, nil end
    
    -- 1. Build Histogram
    local histogram = {} -- 0-11
    for i = 0, 11 do histogram[i] = 0 end
    local total_notes = 0
    
    for i = 0, note_count - 1 do
        local _, _, _, _, _, _, pitch, val = reaper.MIDI_GetNote(take, i)
        local pc = pitch % 12
        -- Weight by velocity or duration could be added, here just count
        histogram[pc] = histogram[pc] + 1
        total_notes = total_notes + 1
    end
    
    if total_notes == 0 then return nil, nil end
    
    -- 2. Compare against all Scale Definitions
    local best_score = -1
    local best_root = 0
    local best_scale_name = "Major"
    
    -- Iterate 12 Roots
    for root = 0, 11 do
        -- Iterate all Scale Types
        for scale_name, intervals in pairs(Theory.scale_types) do
             -- Construct target Note Set for this Root + Scale
             local target_pcs = {}
             for _, interval in ipairs(intervals) do
                 target_pcs[(root + interval) % 12] = true
             end
             
             -- Score it
             local score = 0
             local notes_in_scale = 0
             
             for pc = 0, 11 do
                 if histogram[pc] > 0 then
                     if target_pcs[pc] then
                         score = score + histogram[pc]
                         notes_in_scale = notes_in_scale + histogram[pc]
                     else
                         -- Penalty for out-of-key notes?
                         -- score = score - (histogram[pc] * 0.5) 
                     end
                 end
             end
             
             -- Normalize score? Or just raw count?
             -- Let's prefer scales that cover MORE of the notes present
             -- And break ties with "simpler" scales if possible?
             
             if score > best_score then
                 best_score = score
                 best_root = root
                 best_scale_name = scale_name
             end
        end
    end
    
    -- Return result (root index 0-11, scale_name string)
    return best_root, best_scale_name
end

return Theory