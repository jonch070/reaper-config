local Expression = {}

-- Helper: Linear Interpolation for CC
local function insertCCLinear(take, cc_num, start_ppq, end_ppq, start_val, end_val, interval_ppq)
    local steps = math.floor((end_ppq - start_ppq) / interval_ppq)
    if steps < 1 then 
        reaper.MIDI_InsertCC(take, false, false, start_ppq, 0xB0, cc_num, start_val)
        return 
    end
    
    for i = 0, steps do
        local pos = start_ppq + (i * interval_ppq)
        if pos > end_ppq then break end
        local t = i / steps
        local val = math.floor(start_val + (end_val - start_val) * t)
        val = math.max(0, math.min(127, val))
        reaper.MIDI_InsertCC(take, false, false, pos, 0xB0, cc_num, val)
    end
end

-- 1. Dynamic CC Generator (Follow Pitch + Breath)
function Expression.applyDynamicExpression(take, dynamics_strength, follow_pitch, breath_mode)
    if not take then return end
    
    -- Parse Notes
    local notes = {}
    local idx = 0
    local min_pitch, max_pitch = 127, 0
    
    while true do
        local ret, _, _, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
        if not ret then break end
        table.insert(notes, {s=startppq, e=endppq, p=pitch, v=vel, idx=idx})
        if pitch < min_pitch then min_pitch = pitch end
        if pitch > max_pitch then max_pitch = pitch end
        idx = idx + 1
    end
    
    if #notes == 0 then return end
    
    -- Sort by position
    table.sort(notes, function(a,b) return a.s < b.s end)
    
    -- Delete existing CC 1 and 11
    local cc_idx = 0
    while true do
        local ret, _, _, _, chan, msg2, msg3, num = reaper.MIDI_GetCC(take, cc_idx)
        if not ret then break end
        if num == 1 or num == 11 then
            reaper.MIDI_DeleteCC(take, cc_idx)
        else
            cc_idx = cc_idx + 1
        end
    end
    
    -- Parameters
    local base_cc = 64
    local pitch_range = max_pitch - min_pitch
    if pitch_range == 0 then pitch_range = 1 end
    
    local ppq_res = 240 -- CC Resolution (1/16th note approx)
    
    -- Generate Curves
    for i, n in ipairs(notes) do
        -- Calculate Target CC based on Pitch (if enabled)
        local target_cc = base_cc
        if follow_pitch then
            local normalized = (n.p - min_pitch) / pitch_range -- 0 to 1
            -- Map to 40 - 120 range scaled by strength
            local range = 80 * (dynamics_strength / 100)
            target_cc = 40 + (normalized * range)
        else
            -- Use Velocity as proxy if not strictly pitch
            target_cc = n.v 
        end
        target_cc = math.floor(math.max(10, math.min(127, target_cc)))
        
        -- Start CC (Previous note's target or Silence)
        local prev_cc = target_cc 
        if i > 1 then
             -- Simple connection
        end
        
        -- Draw Sustain Segment (Hold or slight swell)
        local swell_peak = target_cc + (math.random(-5, 5))
        
        -- Breath Logic: Check gap to next note
        local next_note = notes[i+1]
        local is_phrase_end = false
        if not next_note or (next_note.s - n.e) > 480 then -- Gap > 1/8 note
            is_phrase_end = true
        end
        
        local end_cc_val = swell_peak
        if breath_mode and is_phrase_end then
            end_cc_val = math.max(10, swell_peak - 40) -- Dip at end
        end
        
        -- Insert Points
        -- Attack (Start to Peak) - fast
        -- insertCCLinear(take, 1, n.s, n.s + math.min(n.e-n.s, 120), target_cc-10, swell_peak, 60)
        -- Sustain/Decay (Peak to End)
        -- insertCCLinear(take, 1, n.s, n.e, swell_peak, end_cc_val, 120)

        -- Simplified Single Curve per note for now
        insertCCLinear(take, 1, n.s, n.e, target_cc, end_cc_val, 60)   -- Modulation
        insertCCLinear(take, 11, n.s, n.e, target_cc, end_cc_val, 60)  -- Expression
        
    end
    
    reaper.MIDI_Sort(take)
end


-- 2. Smart Legato (Overlap)
function Expression.applySmartLegato(take, overlap_ms)
    if not take then return end
    
    local idx = 0
    local notes = {}
    while true do
        local ret, _, _, s, e, c, p, v = reaper.MIDI_GetNote(take, idx)
        if not ret then break end
        table.insert(notes, {index=idx, s=s, e=e})
        idx = idx + 1
    end
    
    -- Convert overlap_ms to PPQ
    local qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local tempo = reaper.Master_GetTempo()
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, qn + 1) - reaper.MIDI_GetPPQPosFromProjQN(take, qn)
    -- ms per beat = 60000 / tempo. 
    -- ppq per ms = ppq_per_beat / (60000/tempo)
    local ppq_overlap = math.floor(overlap_ms * (ppq_per_beat / (60000/tempo)))

    for i = 1, #notes - 1 do
        local n1 = notes[i]
        local n2 = notes[i+1]
        
        -- If notes are close enough (within reasonable legato range, e.g., < 1/4 note gap)
        if n2.s >= n1.e and (n2.s - n1.e) < ppq_per_beat then
            -- Extend n1 to overlap n2
            local new_end = n2.s + ppq_overlap
            reaper.MIDI_SetNote(take, n1.index, true, false, n1.s, new_end, -1, -1, -1, true)
            -- Update local struct for next iteration if needed (not strictly needed as we process fwd)
        end
    end
    reaper.MIDI_Sort(take)
end


-- 3. Smart Pedal (CC64)
function Expression.applySmartPedal(take)
    if not take then return end
    
    -- Remove existing Pedal
     local cc_idx = 0
    while true do
        local ret, _, _, _, _, _, _, num = reaper.MIDI_GetCC(take, cc_idx)
        if not ret then break end
        if num == 64 then
            reaper.MIDI_DeleteCC(take, cc_idx)
        else
            cc_idx = cc_idx + 1
        end
    end
    
    -- Analyze Chords roughly by grouping notes
    local notes = {}
    local idx = 0
    while true do
        local ret, _, _, s, e, _, p, _ = reaper.MIDI_GetNote(take, idx)
        if not ret then break end
        table.insert(notes, {s=s, e=e, p=p})
        idx = idx + 1
    end
    if #notes == 0 then return end
    table.sort(notes, function(a,b) return a.s < b.s end)
    
    -- Detect "clusters" (chords) or significant gaps
    local ppq_per_beat = 960 -- approx
    
    -- Simple Logic: Pedal DOWN at start of note cluster, Pedal UP/DOWN at widely spaced notes or harmonic shifts?
    -- Better: Pedal DOWN at first note. Pedal UP-DOWN (Retrigger) every Bar or every Chord Change?
    -- Since we don't have harmonic analysis here easily, let's trigger on specific gaps or simply "Auto-Legato Pedal"
    
    -- Logic: Pedal Down at Start of Note.
    -- If gap > X, Release Pedal.
    -- If Note overlaps significantly with previous but Pitch is distinct (Chord Change implied?), Retrigger.
    
    -- IMPLEMENTATION: Simple Legato Pedal (Connect everything, lift on big gaps)
    
    local chain_start = notes[1].s
    local chain_end = notes[1].e
    
    reaper.MIDI_InsertCC(take, false, false, chain_start, 0xB0, 64, 127) -- Down
    
    for i = 1, #notes - 1 do
        local n1 = notes[i]
        local n2 = notes[i+1]
        
        local gap = n2.s - n1.e
        
        if gap > 240 then -- 1/16th note gap -> Phrase break -> Reset Pedal
             reaper.MIDI_InsertCC(take, false, false, n1.e, 0xB0, 64, 0) -- Up
             reaper.MIDI_InsertCC(take, false, false, n2.s, 0xB0, 64, 127) -- Down
        else
             -- Overlap or small gap -> Hold Pedal (Do nothing)
             -- Ideally we retrigger if "Too many notes" to clear mud?
             -- Let's keep it simple: Release only on gaps.
        end
        chain_end = math.max(chain_end, n2.e)
    end
    
    reaper.MIDI_InsertCC(take, false, false, chain_end, 0xB0, 64, 0) -- Final Up
    reaper.MIDI_Sort(take)
end


return Expression
