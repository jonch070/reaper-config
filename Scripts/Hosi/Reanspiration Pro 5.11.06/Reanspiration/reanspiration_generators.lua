-- @description Generators Module for Reanspiration
-- @version 1.5 (Added Walking Bass Generator)
-- @author Hosi
-- @about
--   Chứa các hàm thực thi sinh MIDI (Generators) cho Melody, Drums, Bass, Arp/Strum.
--   Bao gồm logic Markov Chain thích ứng (Adaptive) và Euclidean Rhythms.

local Generators = {}
local reaper = reaper

-- Hàm load module phụ thuộc
local function loadModule(name)
    local script_path_info = debug.getinfo(1, "S")
    local script_path = script_path_info.source:match("@?(.*[/\\])")
    if not script_path then return nil end
    local success, lib = pcall(dofile, script_path .. name)
    if success then return lib else return nil end
end

local Utils = loadModule("reanspiration_utils.lua")
local Theory = loadModule("reanspiration_music_theory.lua")
local Library = loadModule("reanspiration_library_pro.lua")

if not Utils or not Theory or not Library then
    reaper.ShowConsoleMsg("Error: Could not load dependencies in Generators module.\n")
end

-----------------------------------------------------------
-- 0. MARKOV DATA (Dữ liệu xác suất chuyển bậc)
-----------------------------------------------------------
-- Dữ liệu gốc (Mặc định)
Generators.default_markov_matrix = {
    [1] = { [1]=10, [2]=25, [3]=20, [4]=15, [5]=15, [6]=10, [7]=5 },  -- I -> di chuyển tự do
    [2] = { [1]=15, [2]=10, [3]=25, [4]=15, [5]=20, [6]=10, [7]=5 },  -- II -> III hoặc V
    [3] = { [1]=10, [2]=20, [3]=10, [4]=25, [5]=15, [6]=15, [7]=5 },  -- III -> IV
    [4] = { [1]=10, [2]=10, [3]=20, [4]=10, [5]=30, [6]=15, [7]=5 },  -- IV -> V (mạnh)
    [5] = { [1]=35, [2]=5,  [3]=10, [4]=15, [5]=10, [6]=20, [7]=5 },  -- V -> I (Cadence)
    [6] = { [1]=10, [2]=15, [3]=10, [4]=15, [5]=20, [6]=10, [7]=20 }, -- VI -> V hoặc VII
    [7] = { [1]=50, [2]=5,  [3]=5,  [4]=5,  [5]=10, [6]=20, [7]=5 },  -- VII -> I (Dẫn cực mạnh)
}

-- Ma trận đang hoạt động (Active) - Khởi tạo bằng bản sao của Default
Generators.active_markov_matrix = {}
for k, v in pairs(Generators.default_markov_matrix) do
    Generators.active_markov_matrix[k] = {}
    for k2, v2 in pairs(v) do
        Generators.active_markov_matrix[k][k2] = v2
    end
end

-- Trạng thái học
Generators.is_markov_learned = false

-- Hàm Reset Markov về mặc định
function Generators.resetMarkovToDefault()
    Generators.active_markov_matrix = {}
    for k, v in pairs(Generators.default_markov_matrix) do
        Generators.active_markov_matrix[k] = {}
        for k2, v2 in pairs(v) do
            Generators.active_markov_matrix[k][k2] = v2
        end
    end
    Generators.is_markov_learned = false
    return "Markov Reset to Default."
end

-- Hàm Học Markov từ Take được chọn (Adaptive Logic)
function Generators.learnMarkovFromTake(take)
    if not take then return false, "No take selected." end
    
    -- 1. Phân tích Scale của Take để xác định ngữ cảnh
    local _, analyzed_scale_pcs = Theory.analyzeChordsAndScale(take)
    -- Nếu không tìm thấy scale rõ ràng, mặc định C Major (để tính toán tương đối)
    if #analyzed_scale_pcs == 0 then analyzed_scale_pcs = {0, 2, 4, 5, 7, 9, 11} end
    
    -- Tạo Map để tra cứu nhanh: PitchClass -> Degree (1-7)
    local pc_to_degree = {}
    -- Tìm root (giả sử phần tử đầu tiên của sorted scale là root của scale đó trong context đơn giản)
    -- Để chính xác hơn, ta dùng nốt bắt đầu của item làm root tạm thời hoặc root của scale
    local root_pc = analyzed_scale_pcs[1] 
    
    -- Xây dựng scale map (đơn giản hóa: map 12 nốt vào 7 bậc gần nhất)
    -- Ví dụ: C Major -> C=1, D=2, ...
    -- Nốt ngoài scale sẽ được map vào bậc gần nhất
    local scale_intervals = {}
    for _, pc in ipairs(analyzed_scale_pcs) do
        table.insert(scale_intervals, (pc - root_pc + 12) % 12)
    end
    table.sort(scale_intervals) -- {0, 2, 4, 5, 7, 9, 11}
    
    -- 2. Thu thập nốt nhạc
    local notes = {}
    local idx = 0
    while true do
        local ret, _, _, startppq, _, _, pitch, _ = reaper.MIDI_GetNote(take, idx)
        if not ret then break end
        table.insert(notes, {p = pitch, start = startppq})
        idx = idx + 1
    end
    table.sort(notes, function(a,b) return a.start < b.start end)
    
    if #notes < 2 then return false, "Not enough notes to learn (need 2+)." end
    
    -- 3. Xây dựng Ma trận đếm (Tally Matrix)
    local tally = {}
    for i=1,7 do tally[i] = {} end
    
    local prev_degree = nil
    
    for _, note in ipairs(notes) do
        local pc = note.p % 12
        local interval_from_root = (pc - root_pc + 12) % 12
        
        -- Tìm bậc gần nhất trong scale
        local best_degree = 1
        local min_dist = 12
        for i, scale_int in ipairs(scale_intervals) do
            local dist = math.abs(scale_int - interval_from_root)
            if dist > 6 then dist = 12 - dist end -- Wrap around distance
            if dist < min_dist then
                min_dist = dist
                best_degree = i
            end
        end
        
        if prev_degree then
            tally[prev_degree][best_degree] = (tally[prev_degree][best_degree] or 0) + 1
        end
        prev_degree = best_degree
    end
    
    -- 4. Chuẩn hóa và Cập nhật Active Matrix
    local learned_matrix = {}
    local has_learned_data = false
    
    for src=1, 7 do
        learned_matrix[src] = {}
        local total_count = 0
        for dest, count in pairs(tally[src]) do total_count = total_count + count end
        
        if total_count > 0 then
            -- Nếu có dữ liệu thực tế, tính trọng số
            has_learned_data = true
            for dest=1, 7 do
                local count = tally[src][dest] or 0
                -- Nhân lên để có số nguyên đẹp cho weightedRandom, thêm 1 chút bias nhỏ để không bị kẹt
                learned_matrix[src][dest] = (count / total_count) * 100 + 1 
            end
        else
            -- Nếu bậc này chưa từng xuất hiện trong bài mẫu (Gap), dùng dữ liệu mặc định
            -- để tránh việc melody bị kẹt hoặc crash
            for dest=1, 7 do
                learned_matrix[src][dest] = Generators.default_markov_matrix[src][dest]
            end
        end
    end
    
    if not has_learned_data then return false, "Could not detect meaningful melodic movement." end
    
    Generators.active_markov_matrix = learned_matrix
    Generators.is_markov_learned = true
    return true, "Successfully learned melody style!"
end


-----------------------------------------------------------
-- 1. HELPERS & DELETION FUNCTIONS
-----------------------------------------------------------

function Generators.simplifyToTriad(notes, chord_info)
    if not notes or #notes <= 3 then return notes end
    
    local target_pcs = {}
    local use_target = false
    
    -- Extract root, 3rd, 5th pitch classes from chord_info
    if chord_info and chord_info.root_note_pc then
        local root = chord_info.root_note_pc
        target_pcs[root] = true
        target_pcs[(root + 7) % 12] = true -- 5th
        
        if chord_info.is_major ~= nil then
             if chord_info.is_major then
                 target_pcs[(root + 4) % 12] = true -- Maj 3rd
             else
                 target_pcs[(root + 3) % 12] = true -- Min 3rd
             end
             use_target = true
        end
    end
    
    -- Reverse sort notes by pitch (highest first) to grab the upper voicing / closed triad
    local sorted_desc = {}
    for _, n in ipairs(notes) do table.insert(sorted_desc, n) end
    table.sort(sorted_desc, function(a, b) return a.pitch > b.pitch end)
    
    local unique_pcs_found = {}
    local selected_notes = {}
    
    -- Pass 1: Try to find Root, 3rd, 5th from the top notes
    if use_target then
        for _, n in ipairs(sorted_desc) do
            local pc = n.pitch % 12
            if target_pcs[pc] and not unique_pcs_found[pc] then
                unique_pcs_found[pc] = true
                table.insert(selected_notes, n)
            end
            if #selected_notes == 3 then break end
        end
    end
    
    -- Pass 2: If we don't have 3 notes, grab the highest unique pitch classes available
    if #selected_notes < 3 then
        for _, n in ipairs(sorted_desc) do
            local pc = n.pitch % 12
            if not unique_pcs_found[pc] then
                unique_pcs_found[pc] = true
                table.insert(selected_notes, n)
            end
            if #selected_notes == 3 then break end
        end
    end
    
    -- Pass 3: If STILL < 3 (e.g. chord only contains octaves of Root and 5th), pad with remaining highest notes
    if #selected_notes < 3 then
         local final_fallback = {}
         for i=1, math.min(3, #sorted_desc) do
             table.insert(final_fallback, sorted_desc[i])
         end
         selected_notes = final_fallback
    end
    
    -- Sort back to ascending pitch for Arp/Strum logic
    table.sort(selected_notes, function(a, b) return a.pitch < b.pitch end)
    return selected_notes
end

function Generators.deleteNotesByChannel(take, channel)
    if not take then return end
    local notes_to_delete = {}
    local note_idx = 0
    while true do
        local ret, _, _, _, _, chan, _, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        if chan == channel then
            table.insert(notes_to_delete, note_idx)
        end
        note_idx = note_idx + 1
    end
    if #notes_to_delete > 0 then
        table.sort(notes_to_delete, function(a, b) return a > b end)
        for _, index in ipairs(notes_to_delete) do
            reaper.MIDI_DeleteNote(take, index)
        end
    end
end

function Generators.insertChord(take, position, chord, length, channel)
    for _, note in ipairs(chord) do
        reaper.MIDI_InsertNote(take, false, false, position, position + length, channel, note, math.random(80, 110), false)
    end
end

function Generators.createMIDIChords(take, chords_event_list, item_start_ppq, item_length_ppq, channel, spread, voicing_type)
    if #chords_event_list == 0 then return end

    local total_duration = 0
    for _, chord_data in ipairs(chords_event_list) do
        total_duration = total_duration + (chord_data.duration_multiplier or 1.0)
    end
    if total_duration == 0 then return end

    local ppq_per_unit = item_length_ppq / total_duration
    local position = item_start_ppq
    
    -- Fallback initial chord
    local initial_chord_notes = {48, 52, 55} -- Start lower (C3 range) for better grounding
    if chords_event_list[1] and chords_event_list[1].chord then
        initial_chord_notes = {}
        for _, note_pc in ipairs(chords_event_list[1].chord) do
            table.insert(initial_chord_notes, note_pc + 48) -- Normalize to 3rd Octave (48-59)
        end
    end


    local prev_chord = initial_chord_notes

    for i, chord_data in ipairs(chords_event_list) do
        if chord_data and chord_data.chord then
            local current_chord = chord_data.chord
            
            -- Priority: Use Explicit Grid (startppq/endppq) from Architect
            local chord_start_pos = position
            local chord_len = 0
            
            if chord_data.startppq and chord_data.endppq then
                 -- Explicit Mode (from Architect)
                 chord_start_pos = chord_data.startppq
                 chord_len = chord_data.endppq - chord_data.startppq
            else
                 -- Relative/Legacy Mode
                 local mult = chord_data.duration_multiplier or 1.0
                 chord_len = ppq_per_unit * mult
            end
            
            -- Verify bounds relative to ITEM
            -- Note: item_start_ppq is the Item's Position in Project.
            -- MIDI InsertNote takes Project PPQ if valid? 
            -- Wait, insertChord takes 'position'. If 'position' is Project PPQ?
            -- Generators.insertChord logic:
            -- reaper.MIDI_InsertNote(take, ..., position, position + length, ...)
            -- REAPER API expects *PPQ relative to Take* usually, UNLESS we use project time function?
            -- No, MIDI_InsertNote uses PPQ.
            -- If Take is shifted (offset), we need to be careful.
            
            -- Architect passes PROJECT PPQ (start_ppq).
            -- MIDI_InsertNote expects PPQ.
            -- Ideally we should map relative to Take Start?
            -- But earlier checking existing code: it used 'position = item_start_ppq' (Project PPQ).
            -- So `insertChord` seems to expect Project PPQ.
            
            -- Let's stick to using the Project PPQ which seems to be the convention here.
            
            local bass_override_pc = chord_data.bass_override_pc

            -- Apply voicing using Theory module
            local voiced_chord = Theory.applyDropVoicing({table.unpack(current_chord)}, voicing_type)
            voiced_chord = Theory.applySpread(voiced_chord, spread)

            local best_voicing = Theory.getBestVoiceLeading(prev_chord, voiced_chord, bass_override_pc)
            best_voicing = Theory.adjustChord(best_voicing)

            Generators.insertChord(take, chord_start_pos, best_voicing, chord_len, channel)
            prev_chord = best_voicing
            
            -- update position for next iteration (Legacy mode)
            if not (chord_data.startppq and chord_data.endppq) then
                position = position + chord_len
            end
        end
    end
end

-----------------------------------------------------------
-- 2. DRUM GENERATORS
-----------------------------------------------------------

function Generators.generateAndInsertDrums(take, item_start_ppq, item_length_ppq, pattern_data, drum_channel)
    if not pattern_data then return end
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then return end
    local ppq_per_measure = ppq_per_beat * 4
    local note_len_16th = ppq_per_beat / 4

    local drum_name_from_pitch = {}
    for name, pitch in pairs(Library.drum_map) do
      drum_name_from_pitch[pitch] = name
    end

    for measure_start = item_start_ppq, item_start_ppq + item_length_ppq - 1, ppq_per_measure do
        for _, instrument_data in ipairs(pattern_data) do
            local pitch = instrument_data.pitch
            local base_vel = instrument_data.vel
            local drum_name = drum_name_from_pitch[pitch] or ""

            local randomized_vel = base_vel
            local variation = 0
            if string.find(drum_name, "HiHat") then variation = 10
            elseif string.find(drum_name, "BassDrum") or string.find(drum_name, "Snare") then variation = 5
            else variation = 8 end

            if variation > 0 then
                randomized_vel = base_vel + math.random(-variation, variation)
            end
            randomized_vel = math.max(1, math.min(127, randomized_vel))

            for _, pos_fraction in ipairs(instrument_data.positions) do
                local note_start_ppq = math.floor(measure_start + (pos_fraction * ppq_per_measure))
                local note_end_ppq = math.floor(note_start_ppq + note_len_16th)
                if note_start_ppq < item_start_ppq + item_length_ppq then
                    reaper.MIDI_InsertNote(take, false, false, note_start_ppq, note_end_ppq, drum_channel, pitch, math.floor(randomized_vel), true)
                end
            end
        end
    end
end

-- NEW: Euclidean Drum Generator Layer
function Generators.generateEuclideanLayer(take, item_start_ppq, item_length_ppq, midi_channel, note_pitch, steps, hits, rotation)
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_qn = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_qn <= 0 then ppq_per_qn = 960 end
    local step_len_ppq = ppq_per_qn / 4 

    local pattern = Utils.generateEuclideanPattern(steps, hits)
    pattern = Utils.rotateTable(pattern, rotation)

    local i = 0
    while true do
        local ret, sel, mut, start, endp, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if not ret then break end
        if chan == midi_channel and pitch == note_pitch then
            reaper.MIDI_DeleteNote(take, i)
        else
            i = i + 1
        end
    end

    local current_ppq = item_start_ppq
    local end_ppq = item_start_ppq + item_length_ppq
    local step_idx = 0

    while current_ppq < end_ppq do
        local pattern_idx = (step_idx % steps) + 1
        if pattern[pattern_idx] then
            local velocity = math.random(100, 115)
            if pattern_idx == 1 then velocity = 127 end
            local note_end = current_ppq + (step_len_ppq * 0.9) 
            if note_end > end_ppq then note_end = end_ppq end
            reaper.MIDI_InsertNote(take, false, false, current_ppq, note_end, midi_channel, note_pitch, velocity, true)
        end
        current_ppq = current_ppq + step_len_ppq
        step_idx = step_idx + 1
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end

function Generators.generateAndInsertDrumFill(take, item_start_ppq, item_length_ppq, drum_channel)
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then return end
    local ppq_per_measure = ppq_per_beat * 4
    local item_end_ppq = item_start_ppq + item_length_ppq
    local last_measure_start_ppq = item_end_ppq - ppq_per_measure

    if last_measure_start_ppq < item_start_ppq then
        last_measure_start_ppq = item_start_ppq
        ppq_per_measure = item_end_ppq - item_start_ppq
    end

    local notes_to_delete = {}
    local note_idx = 0
    while true do
        local ret, _, _, startppq, _, chan, _, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        if chan == drum_channel and startppq >= last_measure_start_ppq and startppq < item_end_ppq then
            table.insert(notes_to_delete, note_idx)
        end
        note_idx = note_idx + 1
    end
    if #notes_to_delete > 0 then
        table.sort(notes_to_delete, function(a, b) return a > b end)
        for _, index in ipairs(notes_to_delete) do reaper.MIDI_DeleteNote(take, index) end
    end

    local fill_instruments = {
        Library.drum_map["SnareHit"], Library.drum_map["Tom1"], Library.drum_map["Tom2"],
        Library.drum_map["Tom3"], Library.drum_map["MidTom"], Library.drum_map["HighTom"]
    }

    local step_size_16th = ppq_per_beat / 4
    local note_len = step_size_16th * 0.95
    local last_pitch = fill_instruments[1]

    for i = 0, 15 do
        local current_pos = last_measure_start_ppq + (i * step_size_16th)
        if current_pos >= item_end_ppq then break end

        if math.random() < 0.75 then
            local pitch_to_play
            if math.random() < 0.3 then pitch_to_play = last_pitch
            else pitch_to_play = Utils.selectRandom(fill_instruments) end
            
            local current_vel = math.min(127, 90 + (i * 2))
            reaper.MIDI_InsertNote(take, false, false, current_pos, current_pos + note_len, drum_channel, pitch_to_play, current_vel, true)
            last_pitch = pitch_to_play
        end
    end
end

function Generators.generateDrumVariation(take, item_start_ppq, item_length_ppq, drum_channel)
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then return end
    local ppq_per_16th = ppq_per_beat / 4
    local note_len = ppq_per_16th * 0.9
    local kick_pitch = Library.drum_map["BassDrum"]
    local hat_pitch = Library.drum_map["HiHatClosed"]

    local notes_to_delete = {}
    local existing_notes_at_pos = {}
    local note_idx = 0
    
    while true do
        local ret, _, _, startppq, _, chan, pitch, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        if chan == drum_channel and (pitch == kick_pitch or pitch == hat_pitch) then
            local rounded_startppq = math.floor((startppq - item_start_ppq) / ppq_per_16th + 0.5) * ppq_per_16th + item_start_ppq
            if math.random() < 0.15 then table.insert(notes_to_delete, note_idx) end
            if not existing_notes_at_pos[rounded_startppq] then existing_notes_at_pos[rounded_startppq] = {} end
            existing_notes_at_pos[rounded_startppq][pitch] = true
        end
        note_idx = note_idx + 1
    end

    if #notes_to_delete > 0 then
        table.sort(notes_to_delete, function(a, b) return a > b end)
        for _, index in ipairs(notes_to_delete) do reaper.MIDI_DeleteNote(take, index) end
    end

    reaper.MIDI_DisableSort(take)
    local num_16ths_in_item = math.floor(item_length_ppq / ppq_per_16th)
    for i = 0, num_16ths_in_item - 1 do
        local current_pos_abs = item_start_ppq + (i * ppq_per_16th)
        if current_pos_abs < item_start_ppq + item_length_ppq then
            local pos_has_notes = existing_notes_at_pos[current_pos_abs]
            if math.random() < 0.05 then
                local pitch_to_add, vel_to_add
                if math.random() < 0.4 then
                    pitch_to_add = kick_pitch; vel_to_add = math.random(90, 110)
                else
                    pitch_to_add = hat_pitch; vel_to_add = math.random(70, 90)
                end
                if not (pos_has_notes and pos_has_notes[pitch_to_add]) then
                     reaper.MIDI_InsertNote(take, false, false, current_pos_abs, current_pos_abs + note_len, drum_channel, pitch_to_add, vel_to_add, true)
                end
            end
        end
    end
    reaper.MIDI_Sort(take)
end

-----------------------------------------------------------
-- 3. MELODY GENERATORS
-----------------------------------------------------------

function Generators.generateMelody(take, analyzed_chords, scale, density, oct_min, oct_max, item_start_ppq, item_length_ppq, contour_name, library_pattern_index, active_motif)
    if #scale == 0 or #analyzed_chords == 0 then return {} end

    local melody = {}
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    local min_pitch_abs = oct_min * 12
    local max_pitch_abs = (oct_max + 1) * 12 - 1
    local scale_pcs = {}
    for _, pc in ipairs(scale) do scale_pcs[pc] = true end
    
    local current_pos = item_start_ppq
    local current_chord_index = 1

    local active_library_pattern = nil
    if library_pattern_index > 0 then
        active_library_pattern = Library.melody_patterns[library_pattern_index]
    end

    -- Initialize Markov State
    local markov_current_degree_idx = 1 
    local markov_last_pitch = nil

    -- PRIORITY 1: Library Pattern
    if active_library_pattern and active_library_pattern.notes and #active_library_pattern.notes > 0 then
        while current_pos < item_start_ppq + item_length_ppq do
            while current_chord_index < #analyzed_chords and current_pos >= analyzed_chords[current_chord_index + 1].startppq do
                current_chord_index = current_chord_index + 1
            end
            local active_chord = analyzed_chords[current_chord_index]
            local new_root_pc = active_chord.root_note_pc
            
            local current_segment_end_ppq
            if analyzed_chords[current_chord_index + 1] then
                current_segment_end_ppq = analyzed_chords[current_chord_index + 1].startppq
            else
                current_segment_end_ppq = item_start_ppq + item_length_ppq
            end
            local segment_duration_ppq = current_segment_end_ppq - current_pos
            if segment_duration_ppq <= 0 then break end

            local progress = (current_pos - item_start_ppq) / item_length_ppq
            local target_pitch = (min_pitch_abs + max_pitch_abs) / 2
            
            -- Contour Logic (Handle Markov as Random here)
            local c_name = contour_name
            if c_name == "Markov Chain" or c_name == "Random" then c_name = Utils.selectRandom({"Ascending", "Arch", "Descending", "Valley"}) end
            
            if c_name == "Ascending" then target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * progress
            elseif c_name == "Descending" then target_pitch = max_pitch_abs - (max_pitch_abs - min_pitch_abs) * progress
            elseif c_name == "Arch" then target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * math.sin(progress * math.pi)
            else target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * (math.cos(progress * math.pi * 2) * -0.5 + 0.5) end
            
            local avg_pattern_interval = 0
            for _, p_note in ipairs(active_library_pattern.notes) do avg_pattern_interval = avg_pattern_interval + p_note.interval end
            avg_pattern_interval = avg_pattern_interval / #active_library_pattern.notes
            local base_pattern_pitch = new_root_pc + (oct_min * 12) + avg_pattern_interval
            local octave_shift = math.floor((target_pitch - base_pattern_pitch) / 12 + 0.5) * 12

            for _, p_note in ipairs(active_library_pattern.notes) do
                local note_start_ppq_rel = segment_duration_ppq * p_note.start
                local note_duration_ppq = segment_duration_ppq * p_note.duration
                local note_pos_abs = current_pos + note_start_ppq_rel
                if note_pos_abs >= item_start_ppq + item_length_ppq then break end

                local base_pitch = new_root_pc + (oct_min * 12) + (p_note.octave_offset or 0)
                local interval_pitch = base_pitch + p_note.interval
                local final_pitch = interval_pitch + octave_shift
                
                local beat_index = math.floor(((note_pos_abs - item_start_ppq) / ppq_per_beat) % 4)
                local is_strong_beat = (beat_index == 0 or beat_index == 2)
                
                if is_strong_beat then
                    if p_note.interval % 12 == 4 or p_note.interval % 12 == 3 then
                        final_pitch = Theory.snapNoteToScale(final_pitch, {[active_chord.root_note_pc + 3] = true, [active_chord.root_note_pc + 4] = true})
                    elseif p_note.interval % 12 == 9 or p_note.interval % 12 == 8 then
                         final_pitch = Theory.snapNoteToScale(final_pitch, active_chord.chord_tones_pc)
                    else
                        final_pitch = Theory.snapNoteToScale(final_pitch, scale_pcs)
                    end
                else
                    final_pitch = Theory.snapNoteToScale(final_pitch, scale_pcs)
                end
                final_pitch = math.max(min_pitch_abs, math.min(max_pitch_abs, final_pitch))

                table.insert(melody, { pos = note_pos_abs, length = note_duration_ppq * 0.9, note = final_pitch })
            end
            current_pos = current_pos + segment_duration_ppq
        end

    -- PRIORITY 2: Active Generated Motif
    elseif active_motif and active_motif.notes and #active_motif.notes > 0 then
        local motif_length = active_motif.length_ppq
        if motif_length <= 0 then motif_length = ppq_per_beat * 4 end

        while current_pos < item_start_ppq + item_length_ppq do
            while current_chord_index < #analyzed_chords and current_pos >= analyzed_chords[current_chord_index + 1].startppq do
                current_chord_index = current_chord_index + 1
            end
            local active_chord = analyzed_chords[current_chord_index]
            local new_root_pc = active_chord.root_note_pc
            local transposition_interval = new_root_pc - active_motif.original_root_pc

            local progress = (current_pos - item_start_ppq) / item_length_ppq
            local target_pitch
            
            local c_name = contour_name
            if c_name == "Markov Chain" or c_name == "Random" then c_name = Utils.selectRandom({"Ascending", "Arch", "Descending", "Valley"}) end

            if c_name == "Ascending" then target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * progress
            elseif c_name == "Descending" then target_pitch = max_pitch_abs - (max_pitch_abs - min_pitch_abs) * progress
            elseif c_name == "Arch" then target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * math.sin(progress * math.pi)
            else target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * (math.cos(progress * math.pi * 2) * -0.5 + 0.5) end

            local avg_motif_interval = 0
            if #active_motif.notes > 0 then
                for _, motif_note in ipairs(active_motif.notes) do avg_motif_interval = avg_motif_interval + motif_note.interval end
                avg_motif_interval = avg_motif_interval / #active_motif.notes
            end
            local base_motif_pitch = active_motif.original_root_pc + (oct_min * 12) + avg_motif_interval
            local octave_shift = math.floor((target_pitch - (base_motif_pitch + transposition_interval)) / 12 + 0.5) * 12

            for _, motif_note in ipairs(active_motif.notes) do
                local note_pos_abs = current_pos + motif_note.start_ppq_rel
                if note_pos_abs >= item_start_ppq + item_length_ppq then break end

                local base_octave_root = active_motif.original_root_pc + (oct_min * 12)
                local original_pitch = base_octave_root + motif_note.interval
                local transposed_pitch = original_pitch + transposition_interval
                local final_pitch = transposed_pitch + octave_shift
                
                local beat_index = math.floor(((note_pos_abs - item_start_ppq) / ppq_per_beat) % 4)
                local is_strong_beat = (beat_index == 0 or beat_index == 2)
                
                if is_strong_beat then
                    final_pitch = Theory.snapNoteToScale(final_pitch, active_chord.chord_tones_pc)
                else
                    final_pitch = Theory.snapNoteToScale(final_pitch, scale_pcs)
                end
                final_pitch = math.max(min_pitch_abs, math.min(max_pitch_abs, final_pitch))

                table.insert(melody, { pos = note_pos_abs, length = motif_note.duration_ppq, note = final_pitch })
            end
            current_pos = current_pos + motif_length
        end

    -- PRIORITY 3: Algorithmic (Contour / Markov / Random)
    else
        local step_size = (ppq_per_beat * 4) / (density * 2)
        local note_length = step_size * 0.9

        while current_pos < item_start_ppq + item_length_ppq do
            while current_chord_index < #analyzed_chords and current_pos >= analyzed_chords[current_chord_index + 1].startppq do
                current_chord_index = current_chord_index + 1
            end
            local active_chord = analyzed_chords[current_chord_index]

            if math.random() < 0.9 then
                local best_note_pitch = -1
                
                -- === MARKOV CHAIN LOGIC (UPDATED) ===
                if contour_name == "Markov Chain" then
                    -- 1. Select next degree based on weights from ACTIVE Matrix
                    local weights = Generators.active_markov_matrix[markov_current_degree_idx] or Generators.active_markov_matrix[1]
                    local next_degree = Utils.weightedRandom(weights)
                    if not next_degree then next_degree = 1 end
                    markov_current_degree_idx = next_degree
                    
                    -- 2. Get Pitch Class from Scale
                    local scale_idx = ((markov_current_degree_idx - 1) % #scale) + 1
                    local target_pc = scale[scale_idx]
                    
                    -- 3. Determine Octave (Smooth movement)
                    if markov_last_pitch then
                        local min_dist = math.huge
                        for oct = oct_min, oct_max do
                            local p = target_pc + (oct * 12)
                            local dist = math.abs(p - markov_last_pitch)
                            if dist < min_dist then
                                min_dist = dist
                                best_note_pitch = p
                            end
                        end
                        -- Prevent large jumps (> 7 semitones) if possible
                        if math.abs(best_note_pitch - markov_last_pitch) > 7 and math.random() < 0.7 then
                             if best_note_pitch > markov_last_pitch then best_note_pitch = best_note_pitch - 12
                             else best_note_pitch = best_note_pitch + 12 end
                        end
                    else
                        -- First note: start in middle
                        best_note_pitch = target_pc + (math.floor((oct_min + oct_max)/2) * 12)
                    end
                    
                    best_note_pitch = math.max(min_pitch_abs, math.min(max_pitch_abs, best_note_pitch))
                    markov_last_pitch = best_note_pitch

                -- === STANDARD CONTOUR LOGIC ===
                else
                    local candidate_pool = {}
                    local beat_index = math.floor(((current_pos - item_start_ppq) / ppq_per_beat) % 4)
                    local is_strong_beat = (beat_index == 0 or beat_index == 2)

                    local is_leading_note_position = false
                    if current_chord_index < #analyzed_chords then
                        if (current_pos + step_size) >= analyzed_chords[current_chord_index + 1].startppq then
                            is_leading_note_position = true
                        end
                    end

                    if is_leading_note_position and math.random() < 0.75 then
                        local next_root_pc = analyzed_chords[current_chord_index + 1].root_note_pc
                        candidate_pool = { (next_root_pc - 1 + 12) % 12, (next_root_pc + 1) % 12 }
                    elseif is_strong_beat and math.random() < 0.9 then
                        for pc in pairs(active_chord.chord_tones_pc) do candidate_pool[pc] = true end
                    else
                        candidate_pool = scale_pcs
                    end
                    if next(candidate_pool) == nil then candidate_pool = scale_pcs end

                    local progress = (current_pos - item_start_ppq) / item_length_ppq
                    local target_pitch
                    local c_name = contour_name
                    if c_name == "Random" then c_name = Utils.selectRandom({"Ascending", "Arch", "Descending", "Valley"}) end
                    
                    if c_name == "Ascending" then target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * progress
                    elseif c_name == "Descending" then target_pitch = max_pitch_abs - (max_pitch_abs - min_pitch_abs) * progress
                    elseif c_name == "Arch" then target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * math.sin(progress * math.pi)
                    else target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * (math.cos(progress * math.pi * 2) * -0.5 + 0.5) end

                    local min_dist = math.huge
                    for oct = oct_min, oct_max do
                        for pc in pairs(candidate_pool) do
                            local current_pitch = pc + oct * 12
                            local snapped_pitch = Theory.snapNoteToScale(current_pitch, scale_pcs)
                            local dist = math.abs(snapped_pitch - target_pitch)
                            if dist < min_dist then
                                min_dist = dist
                                best_note_pitch = snapped_pitch
                            end
                        end
                    end
                end

                if best_note_pitch ~= -1 then
                    table.insert(melody, {pos = current_pos, length = note_length, note = best_note_pitch})
                end
            end
            current_pos = current_pos + step_size
        end
    end
    return melody
end

function Generators.generateNewMotif(take, analyzed_chords, scale, item_start_ppq, density, oct_min, oct_max)
    if not analyzed_chords or #analyzed_chords == 0 or not scale or #scale == 0 then
        return nil, "Error: No chords found."
    end
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    local motif_length_ppq = ppq_per_beat * 4
    local first_chord = analyzed_chords[1]
    local first_chord_root_pc = first_chord.root_note_pc

    local motif_notes_raw = Generators.generateMelody(take, analyzed_chords, scale, density, oct_min, oct_max, item_start_ppq, motif_length_ppq, "Arch", 0, nil)

    if #motif_notes_raw == 0 then return nil, "Error: No notes generated." end

    local motif = {
        notes = {},
        length_ppq = motif_length_ppq,
        original_root_pc = first_chord_root_pc,
        note_names_list = {}
    }

    for _, note_data in ipairs(motif_notes_raw) do
        local interval = note_data.note - (first_chord_root_pc + (oct_min * 12))
        table.insert(motif.notes, {
            start_ppq_rel = note_data.pos - item_start_ppq,
            duration_ppq = note_data.length,
            interval = interval
        })
        table.insert(motif.note_names_list, Theory.pitchToNoteName(note_data.note))
    end
    return motif, string.format("Motif generated (%d notes).", #motif.notes)
end

-- === THEMATIC DEVELOPMENT HELPERS ===

local function transformInvert(motif_notes, center_pitch)
    local new_notes = {}
    if #motif_notes == 0 then return new_notes end
    
    -- If no center pitch provided, use the first note's pitch as axis
    local axis = center_pitch or motif_notes[1].note
    
    for _, n in ipairs(motif_notes) do
        local dist = n.note - axis
        local new_pitch = axis - dist
        table.insert(new_notes, {
            pos = n.pos,
            length = n.length,
            note = new_pitch,
            original_pitch = n.note
        })
    end
    return new_notes
end

local function transformRetrograde(motif_notes, length_ppq)
    local new_notes = {}
    if #motif_notes == 0 then return new_notes end
    
    -- Sort by position just in case
    -- table.sort(motif_notes, function(a,b) return a.pos < b.pos end)
    
    local start_offset = motif_notes[1].pos
    local end_boundary = start_offset + length_ppq
    
    for i = #motif_notes, 1, -1 do
        local n = motif_notes[i]
        local dur = n.length
        local dist_from_end = end_boundary - (n.pos + dur)
        local new_pos = start_offset + dist_from_end
        
        table.insert(new_notes, {
            pos = new_pos,
            length = dur,
            note = n.note
        })
    end
    return new_notes
end

local function transformSequence(motif_notes, semitone_shift)
    local new_notes = {}
    for _, n in ipairs(motif_notes) do
        table.insert(new_notes, {
            pos = n.pos,
            length = n.length,
            note = n.note + semitone_shift
        })
    end
    return new_notes
end

function Generators.generateThematicMelody(take, analyzed_chords, scale, density, oct_min, oct_max, item_start_ppq, item_length_ppq, structure_type)
    local melody = {}
    
    -- 1. Generate Motif A (1 Bar typically, or 2 beats if item is short)
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    
    local bar_len = ppq_per_beat * 4
    local motif_len = bar_len 
    if item_length_ppq < bar_len * 2 then motif_len = ppq_per_beat * 2 end -- Short item -> Short motif
    
    -- Generate Motif A
    local motif_A_raw = Generators.generateMelody(take, analyzed_chords, scale, density, oct_min, oct_max, item_start_ppq, motif_len, "Arch", 0, nil)
    
    -- Normalize Motif A positions relative to 0
    local motif_A = {}
    for _, n in ipairs(motif_A_raw) do
        table.insert(motif_A, { pos = n.pos - item_start_ppq, length = n.length, note = n.note })
    end
    
    -- Generate Motif B (Contrast)
    local motif_B_raw = Generators.generateMelody(take, analyzed_chords, scale, density, oct_min, oct_max, item_start_ppq, motif_len, "Valley", nil, nil)
    local motif_B = {}
    for _, n in ipairs(motif_B_raw) do
        table.insert(motif_B, { pos = n.pos - item_start_ppq, length = n.length, note = n.note })
    end
    
    -- Determine Structure Map
    -- Segments calculate based on total item length divided by motif length
    local num_segments = math.floor(item_length_ppq / motif_len)
    if num_segments < 1 then num_segments = 1 end
    
    local scale_pcs = {}
    for _, pc in ipairs(scale) do scale_pcs[pc] = true end
    
    for seg = 1, num_segments do
        local seg_start_ppq = (seg - 1) * motif_len
        local current_motif_notes = {}
        local transform_type = "None"
        
        -- Default to A if structure unknown
        local section = "A" 
        
        if structure_type == "AABB" then
            if seg % 4 == 1 or seg % 4 == 2 then section = "A" else section = "B" end
        elseif structure_type == "ABAB" then
            if seg % 2 == 1 then section = "A" else section = "B" end
        elseif structure_type == "Call & Resp (A A' B B')" then
            local cycle = (seg - 1) % 4
            if cycle == 0 then section = "A"; transform_type = "None"
            elseif cycle == 1 then section = "A"; transform_type = "Invert" -- Answer A
            elseif cycle == 2 then section = "B"; transform_type = "None"
            elseif cycle == 3 then section = "B"; transform_type = "Variation" end -- Answer B
        elseif structure_type == "Rondo (ABACA)" then
            local cycle = (seg - 1) % 5
            if cycle == 0 then section = "A"
            elseif cycle == 1 then section = "B"
            elseif cycle == 2 then section = "A"
            elseif cycle == 3 then section = "C" -- C is effectively B inverted or retrograde
            elseif cycle == 4 then section = "A" end
            
            if section == "C" then 
               section = "B"; transform_type = "Retrograde"
            end
        else -- Random or Default
             if math.random() < 0.6 then section = "A" else section = "B" end
        end
        
        -- Select Base Motif
        local source_notes = (section == "A") and motif_A or motif_B
        
        -- Copy notes
        for _, n in ipairs(source_notes) do
            table.insert(current_motif_notes, {pos = n.pos, length = n.length, note = n.note})
        end
        
        -- Apply Transformations
        local center_pitch = current_motif_notes[1] and current_motif_notes[1].note or 60
        
        if transform_type == "Invert" then
            current_motif_notes = transformInvert(current_motif_notes, center_pitch)
        elseif transform_type == "Retrograde" then
            current_motif_notes = transformRetrograde(current_motif_notes, motif_len)
        elseif transform_type == "Variation" then
             -- Simple variation: change last few notes
             if #current_motif_notes > 2 then
                 local last_idx = #current_motif_notes
                 current_motif_notes[last_idx].note = current_motif_notes[last_idx].note + math.random(-2, 2)
                 current_motif_notes[last_idx-1].note = current_motif_notes[last_idx-1].note + math.random(-2, 2)
             end
        end
        
        -- Fit to Chords (Re-harmonize)
        -- For each note in the motif, we need to shift it to fit the chord at that position
        for _, n in ipairs(current_motif_notes) do
            local abs_pos = item_start_ppq + seg_start_ppq + n.pos
            
            -- Find chord at this position
            local current_chord = analyzed_chords[1]
            for _, c in ipairs(analyzed_chords) do
                if abs_pos >= c.startppq and abs_pos < c.endppq then
                    current_chord = c
                    break
                end
            end
            
            -- Snap to scale first
            local snapped_pitch = Theory.snapNoteToScale(n.note, scale_pcs)
            
            -- Snap to Chord tones heavily on strong beats? Or just Scale?
            -- Let's stick to Scale for melody flow, but maybe shift pitch to match Root movement if Sequence
            -- The simplest "Sequence" logic is to move the whole motif by the interval between the original chord root and current chord root.
            
            -- Calculate Motif Original Root (e.g., C) vs Current Chord Root (e.g., F) -> Shift +5
            local chord_root = current_chord.root_note_pc
            local original_root = analyzed_chords[1].root_note_pc
            local root_diff = chord_root - original_root
            if root_diff < -6 then root_diff = root_diff + 12 elseif root_diff > 6 then root_diff = root_diff - 12 end
            
            -- Apply Sequence Shift based on chord progression
            local harmonic_pitch = n.note + root_diff
            
            -- Snap final result to scale
            harmonic_pitch = Theory.snapNoteToScale(harmonic_pitch, scale_pcs)
            
            -- Insert note (Bound by item length)
            if (seg_start_ppq + n.pos + n.length) <= item_length_ppq then
                 table.insert(melody, { pos = abs_pos, length = n.length, note = harmonic_pitch })
            end
        end
    end
    
    return melody
end

-----------------------------------------------------------
-- 4. ARP / STRUM GENERATORS
-----------------------------------------------------------

local function performStrumHit(take, pos, direction, duration, notes_in_chord, velocity_curve_percent, base_vel_mult, strum_delay_ppq, use_palm_mute, up_stroke_latency_scale)
  local notes_to_strum = {}
  if direction == "D" then
    for j = 1, #notes_in_chord do table.insert(notes_to_strum, notes_in_chord[j]) end
  else
    for j = #notes_in_chord, 1, -1 do table.insert(notes_to_strum, notes_in_chord[j]) end
  end

  -- Palm Mute Adjustments
  local note_duration = duration
  local vel_scale = base_vel_mult or 1.0
  
  if use_palm_mute then
      note_duration = math.min(duration, 240) -- Max 1/4 note length roughly, but usually shorter for mute
      note_duration = note_duration * 0.5
      vel_scale = vel_scale * 0.7
  end

  local actual_strum_delay = strum_delay_ppq
  if direction == "U" and up_stroke_latency_scale then
      actual_strum_delay = actual_strum_delay * up_stroke_latency_scale
  end

  for j, note in ipairs(notes_to_strum) do
    local strum_offset = (j - 1) * actual_strum_delay
    local final_vel = math.max(1, math.floor(note.vel * vel_scale))
    
    if direction == "U" then
      final_vel = math.max(1, math.floor(final_vel * (velocity_curve_percent / 100)))
    end
    
    final_vel = math.max(1, math.min(127, final_vel))
    reaper.MIDI_InsertNote(take, false, false, pos + strum_offset, pos + strum_offset + note_duration, note.chan, note.pitch, final_vel, true)
  end
end

function Generators.applyArpeggioOrStrum(take, item, chords_to_process, mode, pattern_name, rate_value, strum_delay_ppq, velocity_curve, arp_rate_values, use_euclidean, euc_steps, euc_hits, use_palm_mute, use_guitar_voicing, up_latency_scale)
  reaper.MIDI_DisableSort(take)
  local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
  local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
  local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)

  -- Euclidean Pattern Gen
  local euc_pattern = nil
  if use_euclidean and euc_steps and euc_hits then
      euc_pattern = Utils.generateEuclideanPattern(euc_steps, euc_hits)
  end

  for i, chord_info in ipairs(chords_to_process) do
    local startppq_abs = chord_info.startppq
    local startppq_rel = startppq_abs - item_start_ppq
    local original_duration = chord_info.endppq - chord_info.startppq
    if original_duration <= 0 then goto continue end

    local notes_in_chord = {}
    for _, n in ipairs(chord_info.notes) do
      local note_channel = n.chan
      table.insert(notes_in_chord, {pitch = n.pitch, vel = n.vel, chan = note_channel})
    end
    table.sort(notes_in_chord, function(a, b) return a.pitch < b.pitch end)
    
    -- Simplify complex chords to triads for Arp and Strum to prevent pattern indexing/math errors
    -- We pass chord_info so the function can intelligently extract Root, 3rd, and 5th from the upper voicing.
    notes_in_chord = Generators.simplifyToTriad(notes_in_chord, chord_info)
    
    if #notes_in_chord == 0 then goto continue end

    -- Handle Random Pattern Selection Per Chord
    local current_pattern_name = pattern_name
    if pattern_name == "Random" then
        if mode == 1 then -- Arp
            current_pattern_name = Utils.selectRandom({"Arp Up", "Arp Down", "Arp Up/Down", "Arp Random"})
        elseif mode == 2 then -- Strum
             if Library.strum_patterns and #Library.strum_patterns > 0 then
                 current_pattern_name = Library.strum_patterns[math.random(#Library.strum_patterns)].name
             end
        end
    end

    if mode == 1 then -- ARPEGGIATOR
      if current_pattern_name == "None" then goto continue end
      local current_rate_value = rate_value
      if current_rate_value == -1 then -- Random
         current_rate_value = Utils.selectRandom(arp_rate_values)
      end
      local arp_note_len = ppq_per_beat * current_rate_value
      local arp_sequence = {}

      if current_pattern_name == "Arp Up" then arp_sequence = notes_in_chord
      elseif current_pattern_name == "Arp Down" then
        table.sort(notes_in_chord, function(a, b) return a.pitch > b.pitch end)
        arp_sequence = notes_in_chord
      elseif current_pattern_name == "Arp Up/Down" then
        arp_sequence = notes_in_chord
        for j = #notes_in_chord - 1, 2, -1 do table.insert(arp_sequence, notes_in_chord[j]) end
      elseif current_pattern_name == "Arp Random" then
        for j = #notes_in_chord, 1, -1 do
          local k = math.random(j)
          notes_in_chord[j], notes_in_chord[k] = notes_in_chord[k], notes_in_chord[j]
        end
        arp_sequence = notes_in_chord
      end

      local current_pos = startppq_rel
      local step = 0
      
      -- Calculate global step offset based on position
      local global_step_offset = math.floor(startppq_rel / arp_note_len)

      while current_pos < startppq_rel + original_duration do
        if #arp_sequence == 0 then break end
        
        -- Euclidean Check
        local should_play = true
        if use_euclidean and euc_pattern and #euc_pattern > 0 then
            local euc_idx = ((global_step_offset + step) % #euc_pattern) + 1
            should_play = euc_pattern[euc_idx]
        end

        if should_play then
            local note_to_play = arp_sequence[(step % #arp_sequence) + 1]
            if note_to_play then
              reaper.MIDI_InsertNote(take, false, false, current_pos, current_pos + arp_note_len, note_to_play.chan, note_to_play.pitch, note_to_play.vel, true)
            end
        end
        
        current_pos = current_pos + arp_note_len
        step = step + 1
      end

    elseif mode == 2 then -- STRUMMER
      if current_pattern_name == "None" then goto continue end
      local strum_data = nil
      if Library.strum_patterns then
        for _, p in ipairs(Library.strum_patterns) do
          if p.name == current_pattern_name then strum_data = p; break end
        end
      end

      if strum_data and strum_data.pattern then
        for _, hit in ipairs(strum_data.pattern) do
          local hit_start_pos_rel = startppq_rel + (original_duration * hit.start)
          local hit_duration_frac = hit.duration or (0.25 / 2)
          local hit_duration_ppq = (original_duration * hit_duration_frac) * 0.98
          local direction = hit.direction or "D"
          local vel_mult = hit.velocity_multiplier or 1.0

          
          -- Apply Guitar Voicing if requested (Mode 2 only usually, but lets support it generally)
          local effective_notes = notes_in_chord
          if use_guitar_voicing and mode == 2 then
               local chord_tones = chord_info.chord_tones_pc
               local root = chord_info.root_note_pc
               -- Generate new voicing notes
               local new_pitches = Theory.getGuitarVoicing(chord_tones, root, 2) -- Base Octave 2
               effective_notes = {}
               for _, p in ipairs(new_pitches) do
                   table.insert(effective_notes, {pitch=p, vel=90, chan=notes_in_chord[1].chan})
               end
          end

          local notes_to_strum_list = {}
          if direction == "D" then
            for j = 1, #effective_notes do table.insert(notes_to_strum_list, effective_notes[j]) end
          else
            for j = #effective_notes, 1, -1 do table.insert(notes_to_strum_list, effective_notes[j]) end
          end
          performStrumHit(take, hit_start_pos_rel, direction, hit_duration_ppq, notes_to_strum_list, velocity_curve, vel_mult, strum_delay_ppq, use_palm_mute, up_latency_scale)
        end
      else
        -- Fallback single strum
        local effective_notes = notes_in_chord
        if use_guitar_voicing and mode == 2 then
             local chord_tones = chord_info.chord_tones_pc
             local root = chord_info.root_note_pc
             local new_pitches = Theory.getGuitarVoicing(chord_tones, root, 2) 
             effective_notes = {}
             for _, p in ipairs(new_pitches) do
                 table.insert(effective_notes, {pitch=p, vel=90, chan=notes_in_chord[1].chan})
             end
        end
        local notes_to_strum_list = {}
        for j = 1, #effective_notes do table.insert(notes_to_strum_list, effective_notes[j]) end
        performStrumHit(take, startppq_rel, "D", original_duration, notes_to_strum_list, velocity_curve, 1.0, strum_delay_ppq, use_palm_mute, up_latency_scale)
      end
    end
    ::continue::
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

-----------------------------------------------------------
-- 5. UTILITY GENERATORS (Humanize, etc)
-----------------------------------------------------------

function Generators.humanizeNotes(take, timing_strength, velocity_strength, groove_name, swing_amount, accent_mode)
    reaper.MIDI_DisableSort(take)
    local item = reaper.GetMediaItemTake_Item(take)
    local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    local ppq_per_8th = ppq_per_beat / 2
    local ppq_per_16th = ppq_per_beat / 4
    
    local effective_swing = (swing_amount or 0) / 100.0 -- 0.0 to 1.0

    local note_count = reaper.MIDI_CountEvts(take)
    for i = 0, note_count - 1 do
        local ret, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if ret then
            local velocity_offset = math.random(-velocity_strength, velocity_strength)
            local new_vel = vel + velocity_offset
            
            -- === VELOCITY ACCENTS ===
            local note_pos_in_beat = (startppq - item_start_ppq) % ppq_per_beat
            local beat_pos_qn = reaper.MIDI_GetProjQNFromPPQPos(take, startppq)
            local beat_in_bar = (math.floor(beat_pos_qn) % 4) + 1 -- 1, 2, 3, 4
            
            local accent_boost = 15
            if accent_mode == "Strong (1 & 3)" then
                if beat_in_bar == 1 or beat_in_bar == 3 then new_vel = new_vel + accent_boost
                else new_vel = new_vel - (accent_boost * 0.5) end
            elseif accent_mode == "Weak (2 & 4)" then
                if beat_in_bar == 2 or beat_in_bar == 4 then new_vel = new_vel + accent_boost
                else new_vel = new_vel - (accent_boost * 0.5) end
            elseif accent_mode == "Syncopated (Off-beat)" then
                -- Check if off-beat (approx 8th note off-beat)
                local dist_from_beat = math.abs(note_pos_in_beat)
                if dist_from_beat > (ppq_per_beat * 0.4) and dist_from_beat < (ppq_per_beat * 0.6) then
                    new_vel = new_vel + accent_boost
                else
                     new_vel = new_vel - (accent_boost * 0.3)
                end
            end
            new_vel = math.max(1, math.min(127, new_vel))

            -- === TIMING & SWING ===
            local timing_offset = 0
            
            if groove_name == "8th Swing" then
                local note_pos_in_half_beat = (startppq - item_start_ppq) % ppq_per_beat -- Check within beat
                local on_off_beat_threshold = ppq_per_8th
                
                -- Check if it's the 2nd 8th note
                 if note_pos_in_half_beat >= (ppq_per_8th * 0.8) then
                     -- Apply Swing Delay
                     local max_swing_offset = ppq_per_8th * 0.33 -- Max triplet feel
                     timing_offset = timing_offset + (max_swing_offset * effective_swing)
                 end
            elseif groove_name == "16th Swing" then
                local note_pos_in_quarter = (startppq - item_start_ppq) % ppq_per_beat
                local sixteenth_idx = math.floor((note_pos_in_quarter / ppq_per_16th) + 0.5) % 4 -- 0,1,2,3
                
                -- Swing the even 16ths (1 and 3, i.e., 2nd and 4th)
                if sixteenth_idx == 1 or sixteenth_idx == 3 then
                    local max_swing_offset = ppq_per_16th * 0.33
                    timing_offset = timing_offset + (max_swing_offset * effective_swing)
                end
            end
            
            -- Add Standard Random Jitter
            timing_offset = timing_offset + math.random(-timing_strength, timing_strength)

            local new_startppq = startppq + timing_offset
            local new_endppq = endppq + timing_offset
            if new_startppq < 0 then new_startppq = 0 end
            if new_endppq < new_startppq then new_endppq = new_startppq + (endppq - startppq) end
            reaper.MIDI_SetNote(take, i, selected, muted, new_startppq, new_endppq, chan, pitch, new_vel, false)
        end
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end

-- 6. NEW: Walking Bass Generator
function Generators.generateWalkingBass(take, analyzed_chords, scale, item_start_ppq, item_length_ppq, channel)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    local quarter_note = ppq_per_beat
    local note_len = quarter_note * 0.95 -- Slightly shorter than full length for articulation
    
    local scale_pcs = {}
    for _, pc in ipairs(scale) do scale_pcs[pc] = true end



    local last_pitch = nil

    for i, chord in ipairs(analyzed_chords) do
        local next_chord = analyzed_chords[i+1]
        
        -- Target for the NEXT chord (for approach note calculation)
        -- If it's the last chord, wrap around to the first chord's root or stay on tonic
        local target_root_pc = next_chord and next_chord.root_note_pc or analyzed_chords[1].root_note_pc
        
        local duration_ppq = (next_chord and next_chord.startppq or (item_start_ppq + item_length_ppq)) - chord.startppq
        local beats_in_chord = math.floor(duration_ppq / quarter_note + 0.5)
        if beats_in_chord < 1 then beats_in_chord = 1 end

        local current_ppq = chord.startppq
        local chord_root_pitch = chord.root_note_pc + 36 -- Start at C2 (36) octave range
        
        -- Adjust octave to keep bass in reasonable range (E1 to E3 approx)
        if last_pitch then
            -- Find nearest octave of root to last pitch
            local p1 = chord.root_note_pc + 24 -- C1 range
            local p2 = chord.root_note_pc + 36 -- C2 range
            local p3 = chord.root_note_pc + 48 -- C3 range
            
            local d1 = math.abs(last_pitch - p1)
            local d2 = math.abs(last_pitch - p2)
            local d3 = math.abs(last_pitch - p3)
            
            if d1 <= d2 and d1 <= d3 then chord_root_pitch = p1
            elseif d2 <= d1 and d2 <= d3 then chord_root_pitch = p2
            else chord_root_pitch = p3 end
        end
        
        -- Ensure range limits (E1=28, G3=55)
        if chord_root_pitch < 28 then chord_root_pitch = chord_root_pitch + 12 end
        if chord_root_pitch > 55 then chord_root_pitch = chord_root_pitch - 12 end

        for beat = 1, beats_in_chord do
            if current_ppq >= item_start_ppq + item_length_ppq then break end
            
            local pitch_to_play = chord_root_pitch -- Default to root
            
            if beat == 1 then
                -- Beat 1: Always Root (mostly)
                pitch_to_play = chord_root_pitch
                
            elseif beat == 4 and next_chord then
                -- Beat 4: Approach Note to Next Root
                local target_pitch = target_root_pc + (math.floor(last_pitch/12))*12
                -- Adjust target octave to be close to last_pitch
                if math.abs(target_pitch - last_pitch) > 6 then
                    if target_pitch > last_pitch then target_pitch = target_pitch - 12 else target_pitch = target_pitch + 12 end
                end
                
                -- Logic: 
                -- 1. Chromatic approach from below/above
                -- 2. Diatonic step
                -- 3. Dominant (5th) approach
                
                local r = math.random()
                if r < 0.5 then 
                    -- Chromatic Approach (half step) from below or above
                    if math.random() < 0.5 then pitch_to_play = target_pitch - 1 
                    else pitch_to_play = target_pitch + 1 end
                elseif r < 0.8 then
                    -- Diatonic (Scale) Approach
                     -- (Simplified: just scale neighbor)
                     pitch_to_play = Theory.snapNoteToScale(target_pitch + (math.random()<0.5 and -1 or 1), scale_pcs)
                else
                    -- Fifth approach
                    pitch_to_play = target_pitch + 7
                    if pitch_to_play > 55 then pitch_to_play = pitch_to_play - 12 end
                end
                
            elseif beat == 3 then
                -- Beat 3: 5th or 3rd or Octave
                local chord_tones = {}
                for pc, _ in pairs(chord.chord_tones_pc) do
                    if pc ~= chord.root_note_pc then -- Exclude root if possible for variety
                        -- Find chord tone closest to current range
                        local p = pc + (math.floor(chord_root_pitch/12))*12
                        if math.abs(p - chord_root_pitch) > 6 then 
                             if p > chord_root_pitch then p = p - 12 else p = p + 12 end
                        end
                        table.insert(chord_tones, p)
                    end
                end
                if #chord_tones > 0 then
                    pitch_to_play = Utils.selectRandom(chord_tones)
                else 
                    pitch_to_play = chord_root_pitch + 12 -- Octave
                end
                
            else -- Beat 2 or others
                -- Passing note or Chord Tone
                if last_pitch then
                     -- Try to move stepwise if possible towards next target
                     local direction = 1
                     if math.random() < 0.5 then direction = -1 end
                     pitch_to_play = Theory.snapNoteToScale(last_pitch + direction, scale_pcs)
                else
                     pitch_to_play = chord_root_pitch + (math.random() < 0.5 and 4 or 7) -- 3rd or 5th approx
                     pitch_to_play = Theory.snapNoteToScale(pitch_to_play, chord.chord_tones_pc)
                end
            end
            
            -- Final Range Check
            if pitch_to_play < 28 then pitch_to_play = pitch_to_play + 12 end
            if pitch_to_play > 55 then pitch_to_play = pitch_to_play - 12 end
            
            local vel = (beat == 1) and 110 or 95 -- Accent beat 1
            vel = vel + math.random(-5, 5) -- Humanize velocity slightly
            
            reaper.MIDI_InsertNote(take, false, false, current_ppq, current_ppq + note_len, channel, pitch_to_play, vel, true)
            
            last_pitch = pitch_to_play
            current_ppq = current_ppq + quarter_note
        end
    end
end

-- 7. NEW: Melody Generator (RESTORED API CONTRACT)
-- NEW: Band Lock-in Bass Generator
function Generators.generateBassLockedToKick(take, chords, scale, kick_events, bass_min_oct, bass_max_oct)
    if not kick_events or #kick_events == 0 then return {} end
    
    local events = {}
    local scales = {} -- Cache scales per chord if needed, or simple scale
    local scale_pcs = {}
    if scale then for _, pc in ipairs(scale) do scale_pcs[pc] = true end end
    
    local min_pitch = (bass_min_oct or 2) * 12
    local max_pitch = (bass_max_oct or 3) * 12
    
    -- Iterate through detected Kick events
    for _, kick in ipairs(kick_events) do
        local pos = kick.pos
        local length = kick.len
        
        -- Clamp length if too short or finding mapping
        if length < 120 then length = 240 end -- Min 1/16th note approx
        
        -- Find chord at this position
        local current_chord = nil
        for _, chord in ipairs(chords) do
            if pos >= chord.startppq and pos < chord.endppq then
                current_chord = chord
                break
            end
        end
        
        if current_chord then
            -- Determine pitch: Root is priority
            local root = current_chord.root_note_pc
            local pitch = root + (bass_min_oct * 12)
            
            -- Simple logic: Octave switching if needed or random variety?
            -- For strict lock-in, let's stick to Root mostly, maybe 5th on weak beats
            -- But "Lock-in" usually implies Rhythmic Lock, Pitch is harmonic.
            
            -- Ensure range
            while pitch < min_pitch do pitch = pitch + 12 end
            while pitch > max_pitch do pitch = pitch - 12 end
            
            table.insert(events, {
                note = math.floor(pitch),
                pos = math.floor(pos),
                length = math.floor(length),
                velocity = math.floor(math.random(100, 115)) -- Tight velocity
            })
        end
    end
    
    return events
end

function Generators.generateMelody(take, chords, scale, density, min_oct, max_oct, start_ppq, length_ppq, contour_name, pattern_obj, active_motif)
    -- Sanitize Inputs
    if not chords or #chords == 0 then return {} end
    density = tonumber(density) or 4
    if density > 1 then density = density / 10 end -- Normalize 1-10 range to 0.1-1.0
    
    local root_pc = (scale and scale[1]) or 0
    local min_pitch = (min_oct or 4) * 12 + root_pc
    local max_pitch = (max_oct or 5) * 12 + root_pc -- Align max range to root as well for consistency

    local scale_pcs = {}
    for _, pc in ipairs(scale) do scale_pcs[pc] = true end

    -- === 1. PATTERN / MOTIF GENERATION ===
    if (type(pattern_obj)=="table" and pattern_obj) or active_motif then
        local p_notes = (type(pattern_obj)=="table" and pattern_obj and pattern_obj.notes) or (active_motif and active_motif.notes)
        if p_notes then
             local events = {}
             local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1) or 960
             
             for _, chord in ipairs(chords) do
                 local chord_len = chord.endppq - chord.startppq
                 local base_root = chord.root_note_pc + (min_oct * 12)
                 -- Adjust base root to be within range if possible
                 if base_root < min_pitch then base_root = base_root + 12 end
                 
                 for _, pn in ipairs(p_notes) do
                     -- Pattern logic: start/duration are fractions (0-1) of chord length OR beats?
                     -- Library comments say: "start: 0.0 to 1.0 (relative)"
                     local pos = chord.startppq + (pn.start * chord_len)
                     local len = pn.duration * chord_len
                     
                     -- Check range
                     if pos < (start_ppq + length_ppq) then
                         local pitch = base_root + pn.interval
                         if pn.octave_offset then pitch = pitch + pn.octave_offset end
                         
                         -- Apply Random Variation if Contour is "Random"
                         if contour_name == "Random" and math.random() < 0.25 then
                             local var_steps = math.random(-2, 2)
                             pitch = pitch + var_steps
                         end

                         -- Snap to scale
                         pitch = Theory.snapNoteToScale(pitch, scale_pcs)
                         
                         -- Octave adjustment
                         while pitch < min_pitch do pitch = pitch + 12 end
                         while pitch > max_pitch do pitch = pitch - 12 end
                         
                         table.insert(events, {
                             note = math.floor(pitch),
                             pos = math.floor(pos),
                             length = math.floor(len),
                             velocity = math.floor(math.random(90, 110))
                         })
                     end
                 end
             end
             return events
        end
    end

    -- === 2. CONTOUR / STOCHASTIC GENERATION (Fallback) ===
    local last_pitch = nil
    -- Ideally start near the first chord root in the middle of the range
    if chords and #chords > 0 then
        last_pitch = chords[1].root_note_pc + 60
    else
        last_pitch = 60
    end
    -- Adjust to range
    while last_pitch < min_pitch do last_pitch = last_pitch + 12 end
    while last_pitch > max_pitch do last_pitch = last_pitch - 12 end
    
    local melody_events = {}

    local current_ppq = start_ppq
    local end_ppq_limit = start_ppq + length_ppq

    local chord_idx = 1
    
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    
    while current_ppq < end_ppq_limit do
        -- Find current chord
        local current_chord = chords[1]
        for i, ch in ipairs(chords) do
            if current_ppq >= ch.startppq and current_ppq < ch.endppq then
                current_chord = ch
                chord_idx = i
                break
            end
        end
        if current_ppq >= chords[#chords].endppq then break end

        -- Next Note Determination
        local next_pitch = last_pitch
        local step_size = 0
        
        if contour_name == "Ascending" then
            step_size = math.random(1, 4)
        elseif contour_name == "Descending" then
            step_size = math.random(-4, -1)
        elseif contour_name == "Archive" then -- Arc
            local progress = (current_ppq - start_ppq) / length_ppq
            if progress < 0.5 then step_size = math.random(1, 3)
            else step_size = math.random(-3, -1) end
        elseif contour_name == "Counterpoint" then
             -- CONTRARY MOTION LOGIC
             local next_chord = chords[chord_idx + 1]
             local bass_direction = 1 -- Default Up
             
             if next_chord then
                 local r1 = current_chord.root_note_pc
                 local r2 = next_chord.root_note_pc
                 local diff = (r2 - r1 + 12) % 12
                 if diff > 6 then bass_direction = -1 else bass_direction = 1 end
                 if diff == 0 then bass_direction = (math.random() < 0.5 and 1 or -1) end
             end
             -- Move OPPOSITE to bass
             local melody_direction = -bass_direction
             step_size = melody_direction * math.random(1, 4)
             
        elseif contour_name == "Stationary" then
            step_size = math.random(-1, 1)
        elseif contour_name == "Markov Chain" then
             if Generators.markov_matrix then
                 local interval = Generators.getMarkovInterval(Generators.markov_matrix)
                 if interval then step_size = interval else step_size = math.random(-2, 2) end
             else
                 step_size = math.random(-2, 2)
             end
        else -- Random
             step_size = math.random(-3, 3)
        end
        
        next_pitch = last_pitch + step_size
        
        -- Constraint Check
        if next_pitch < min_pitch then next_pitch = next_pitch + 12 
        elseif next_pitch > max_pitch then next_pitch = next_pitch - 12 end
        
        -- Snap to Scale/Chord
        next_pitch = Theory.snapNoteToScale(next_pitch, scale_pcs)
        
        -- On strong beats, snap to chord tone
        local is_strong_beat = (current_ppq % ppq_per_beat) < (ppq_per_beat * 0.1)
        if is_strong_beat then
           local ct = Theory.getNearestChordTone(next_pitch, current_chord.chord_tones_pc)
           if ct then next_pitch = ct end
        end
        
        -- Duration
        local duration_opts = {0.25, 0.5, 1.0} -- beats
        local dur_beats = Utils.selectRandom(duration_opts)

        -- Density check
        if math.random() > density then
             -- Rest
             current_ppq = current_ppq + (dur_beats * ppq_per_beat)
        else
            -- Add Note to Table
            local vel = math.random(80, 110)
            local note_len = (dur_beats * ppq_per_beat) * 0.95
            
            table.insert(melody_events, {
                note = next_pitch,
                pos = current_ppq,
                length = note_len,
                velocity = vel
            })
            
            last_pitch = next_pitch
            current_ppq = current_ppq + (dur_beats * ppq_per_beat)
        end
    end
    
    return melody_events
end

-- 8. NEW: Cinematic Ostinato Generator
function Generators.generateOstinato(take, chords, scale, item_start_ppq, item_length, channel, pattern_len_fraction, buildup_percent)
    reaper.MIDI_DisableSort(take)
    
    buildup_percent = tonumber(buildup_percent) or 50
    pattern_len_fraction = tonumber(pattern_len_fraction) or 0.25
    
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    
    -- 1. Create Motif (1 bar max usually, based on fraction)
    -- pattern_len_fraction: 0.25 (1 beat), 0.5 (2 beats), 1.0 (1 bar)
    local motif_len_ppq = ppq_per_beat * 4 * pattern_len_fraction
    local motif_events = {}
    local num_notes = math.floor(4 * pattern_len_fraction * 4) -- approx 16th notes count
    if num_notes < 2 then num_notes = 2 end
    
    local scale_pcs = {} 
    for _,n in ipairs(scale) do scale_pcs[n] = true end
    
    -- Generate simple arpeggio-like motif
    for i = 1, num_notes do
        if math.random() > 0.3 then -- 70% chance of note
             local pos = (i-1) * (ppq_per_beat / 4) -- 16th grid
             if pos < motif_len_ppq then
                 local interval = Utils.selectRandom({0, 2, 4, 7, 12}) -- Scale degrees relative to root
                 table.insert(motif_events, {
                     rel_pos = pos,
                     interval = interval,
                     len = (ppq_per_beat/4) * 0.8
                 })
             end
        end
    end
    
    -- 2. Loop over chords
    for _, chord in ipairs(chords) do
        local chord_dur = (chord.endppq - chord.startppq)
        local num_loops = math.ceil(chord_dur / motif_len_ppq)
        
        for L = 0, num_loops - 1 do
            local loop_start_offset = L * motif_len_ppq
            
            for _, ev in ipairs(motif_events) do
                local note_pos = chord.startppq + loop_start_offset + ev.rel_pos
                if note_pos < chord.endppq and note_pos < (item_start_ppq + item_length) then
                    
                    -- Calculate Build-up Velocity
                    local progress = (note_pos - item_start_ppq) / item_length
                    local start_vel = 40
                    local end_vel = 110
                    local vel = start_vel + (end_vel - start_vel) * (progress * (buildup_percent / 100))
                    vel = math.floor(vel)
                    
                    -- Pitch Logic
                    local base_pitch = chord.root_note_pc + 60 -- C4 range
                    local pitch = Theory.snapNoteToScale(base_pitch + ev.interval, chord.chord_tones_pc) -- Snap to chord tones ideally
                    
                    -- Insert
                    reaper.MIDI_InsertNote(take, false, false, note_pos, note_pos + ev.len, channel, pitch, vel, true)
                end
            end
        end
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end

-----------------------------------------------------------
-- 5. COUNTERPOINT GENERATOR (Companions)
-----------------------------------------------------------

function Generators.generateCounterpoint(take, analyzed_chords, scale, item_start_ppq, item_length_ppq, target_channel)
    if not take or not scale or #scale == 0 then return end
    
    -- 1. Parse Main Melody (Channel 0 assumed or all except target)
    -- We assume the user wants to accompany the existing notes in the take.
    local melody_notes = {}
    local idx = 0
    -- Melody assumed to be on Channel 1 (index 0) if not specified, 
    -- but we will collect ALL notes that are NOT on the target channel (Counterpoint Channel)
    
    while true do
        local ret, _, _, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
        if not ret then break end
        if chan ~= target_channel then -- Don't read self if re-running
            table.insert(melody_notes, {pos=startppq, end_pos=endppq, pitch=pitch, vel=vel})
        end
        idx = idx + 1
    end
    
    if #melody_notes == 0 then return end
    table.sort(melody_notes, function(a,b) return a.pos < b.pos end)
    
    -- Time config
    local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn + 1)
    if ppq_per_beat <= 0 then ppq_per_beat = 960 end
    
    -- Delete existing notes on target channel to avoid overlap/duplication
    Generators.deleteNotesByChannel(take, target_channel)

    -- Scale Map
    local scale_pcs = {}
    for _, pc in ipairs(scale) do scale_pcs[pc] = true end
    
    -- State
    local cp_notes = {}
    local prev_cp_pitch = nil
    local prev_melody_pitch = nil
    
    -- Consonance Intervals (Semitones relative to 0)
    -- 3, 4 (3rds), 7 (5th), 8, 9 (6ths), 0 (8ve)
    local consonance_set = {[0]=true, [3]=true, [4]=true, [7]=true, [8]=true, [9]=true, [12]=true}
    
    -- Grid for processing (16th notes)
    local step_len = ppq_per_beat / 4
    local current_ppq = item_start_ppq
    local end_ppq = item_start_ppq + item_length_ppq
    
    -- Process by segments (Beats)
    while current_ppq < end_ppq do
        -- A. Analyze Melody Activity in this Beat
        local lookahead_end = math.min(end_ppq, current_ppq + ppq_per_beat)
        local notes_in_window = 0
        local window_melody_pitch_sum = 0
        local window_melody_count = 0
        local active_melody_pitch = nil -- Pitch at exact current_ppq
        
        for _, m_note in ipairs(melody_notes) do
            if m_note.pos >= current_ppq and m_note.pos < lookahead_end then
                notes_in_window = notes_in_window + 1
                window_melody_pitch_sum = window_melody_pitch_sum + m_note.pitch
                window_melody_count = window_melody_count + 1
            end
            if m_note.pos <= current_ppq and m_note.end_pos > current_ppq then
                active_melody_pitch = m_note.pitch
            end
        end
        
        if not active_melody_pitch and window_melody_count > 0 then
             active_melody_pitch = math.floor(window_melody_pitch_sum / window_melody_count + 0.5)
        end
        
        -- B. Rhythmic Decision (Complement)
        local cp_note_len = step_len -- Default
        local rhythm_type = "Active" 
        
        if notes_in_window >= 3 then -- Melody IS Active
             cp_note_len = ppq_per_beat -- CP Slow (Quarter)
             rhythm_type = "Static"
        elseif notes_in_window <= 1 then -- Melody Slow/Rest
             cp_note_len = ppq_per_beat / 2 -- CP Active (8th)
             rhythm_type = "Active"
        else
             cp_note_len = ppq_per_beat -- CP Slow default
             rhythm_type = "Medium"
        end

        
        -- C. Generation Loop for this segment
        -- We loop through the beat (current_ppq to lookahead_end) using cp_note_len
        local seg_ptr = current_ppq
        
        while seg_ptr < lookahead_end and seg_ptr < end_ppq do
            
            -- Find Melody Pitch at *this point*
            local curr_m_pitch = nil
            for _, m_note in ipairs(melody_notes) do
                if m_note.pos <= seg_ptr and m_note.end_pos > seg_ptr then
                    curr_m_pitch = m_note.pitch
                    break
                end
            end
            if not curr_m_pitch and rhythm_type == "Static" and active_melody_pitch then
                curr_m_pitch = active_melody_pitch -- Use average/representative if holding
            end

            -- Find Harmonic Context (Chord)
            local current_chord = nil
            if analyzed_chords then
                for _, chord in ipairs(analyzed_chords) do
                    if seg_ptr >= chord.startppq and seg_ptr < chord.endppq then
                        current_chord = chord
                        break
                    end
                end
            end
            local chord_tones = current_chord and current_chord.chord_tones_pc or {}
            
            -- D. Pitch Calculation
            local candidates = {}
            local root_pc = (scale and scale[1]) or 0
            local base_center = curr_m_pitch and (curr_m_pitch - 12) or (48 + root_pc) -- Default to Root in 3rd octave if no melody context
            if prev_cp_pitch then base_center = prev_cp_pitch end
            
            -- Generate Scale Candidates range +/- 12 from center
            for i = -12, 12 do
                 local p = base_center + i
                 if scale_pcs[p % 12] then -- Check Scale
                      table.insert(candidates, p)
                 end
            end
            
            -- Filter/Score Candidates
            local best_p = nil
            local best_score = -10000
            
            for _, cand in ipairs(candidates) do
                local score = 0
                -- Distance preference
                local dist = math.abs(cand - (prev_cp_pitch or base_center))
                score = score - (dist * 0.5) 
                
                -- 1. Vertical Harmony
                if curr_m_pitch then
                    local interval = math.abs(cand - curr_m_pitch) % 12
                    
                    if consonance_set[interval] then score = score + 20 end
                    if interval == 7 or interval == 0 then score = score + 10 end 
                    if interval == 1 or interval == 2 or interval == 11 then score = score - 30 end -- STRONG Dissonance check (m2, M2, M7)
                    
                    if cand > curr_m_pitch then score = score - 40 end -- Counterpoint usually lower
                    if cand == curr_m_pitch then score = score - 15 end -- Unison avoid if possible
                elseif current_chord then
                    -- If no melody note, match Chord Tone
                    if chord_tones[cand % 12] then score = score + 15 end
                end
                
                -- 2. Horizontal Motion & Parallel 5ths/8ves
                if prev_cp_pitch and prev_melody_pitch and curr_m_pitch then
                     local m_motion = curr_m_pitch - prev_melody_pitch
                     local c_motion = cand - prev_cp_pitch
                     
                     -- Contrary Motion Reward
                     if (m_motion > 0 and c_motion < 0) or (m_motion < 0 and c_motion > 0) then
                         score = score + 30
                     end
                     if (m_motion == 0) and (c_motion ~= 0) then score = score + 10 end -- Oblique
                     
                     -- Parallel 5th/8ve Penalty (Archenemy of Counterpoint)
                     local prev_interval = math.abs(prev_melody_pitch - prev_cp_pitch) % 12
                     local curr_interval = math.abs(curr_m_pitch - cand) % 12
                     
                     if (prev_interval == 7 and curr_interval == 7) or (prev_interval == 0 and curr_interval == 0) then
                         if m_motion ~= 0 and c_motion ~= 0 then -- Parallel motion
                              score = score - 500 -- FORBIDDEN
                         end
                     end
                else
                     -- No prev context, just prefer chord tones
                     if current_chord and chord_tones[cand%12] then score = score + 5 end
                end

                 -- Randomize slightly to break ties
                 score = score + math.random(-2, 2)
                
                if score > best_score then
                    best_score = score
                    best_p = cand
                end
            end
            
            if best_p then
                table.insert(cp_notes, {pos = seg_ptr, length = cp_note_len * 0.95, pitch = best_p, vel = math.random(70, 95)})
                prev_cp_pitch = best_p
            end
            
            if curr_m_pitch then prev_melody_pitch = curr_m_pitch end
            
            seg_ptr = seg_ptr + cp_note_len
        end
        
        current_ppq = lookahead_end
    end
    
    -- Insert Notes
    for _, n in ipairs(cp_notes) do
        reaper.MIDI_InsertNote(take, false, false, n.pos, n.pos + n.length, target_channel, n.pitch, n.vel, false)
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end


function Generators.generateBass(take, chords, scale, item_start_ppq, item_length_ppq, channel, energy)
    local energy = energy or 50
    local pattern_index = 1
    
    -- Select Pattern based on Energy
    -- Low Energy (0-40): Roots / Long notes (Indices 1-3 assumed)
    -- Mid Energy (40-70): Basic Rhythmic (Indices 4-8)
    -- High Energy (70-100): Octaves / Driving (Indices 9+)
    
    if Library and Library.bass_patterns and #Library.bass_patterns > 0 then
        local num_p = #Library.bass_patterns
        local min_idx = 1
        local max_idx = num_p
        
        if energy < 40 then
             max_idx = math.min(3, num_p)
        elseif energy < 70 then
             min_idx = math.min(4, num_p)
             max_idx = math.min(8, num_p)
        else
             min_idx = math.min(9, num_p)
        end
        
        -- Fallback if ranges invalid
        if min_idx > max_idx then min_idx = 1; max_idx = num_p end
        
        pattern_index = math.random(min_idx, max_idx)
        
        local p_func = Library.bass_patterns[pattern_index].func
        if p_func then
            for i, ch in ipairs(chords) do
                -- Calculate duration until next chord or end of item
                local next_start = (chords[i+1] and chords[i+1].startppq) or (item_start_ppq + item_length_ppq)
                local dur = next_start - ch.startppq
                
                -- Only process if within item bounds
                if ch.startppq >= item_start_ppq and ch.startppq < (item_start_ppq + item_length_ppq) then
                    -- Clamp duration if extending beyond item
                    if (ch.startppq + dur) > (item_start_ppq + item_length_ppq) then
                        dur = (item_start_ppq + item_length_ppq) - ch.startppq
                    end
                    
                    p_func(take, ch.startppq, dur, {is_major=ch.is_major}, ch.root_note_pc + 36, ch.root_note_pc, channel)
                end
            end
        end
    end
end

return Generators