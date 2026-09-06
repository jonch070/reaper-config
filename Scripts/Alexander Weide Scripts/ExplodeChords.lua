-- [[
--  Name: Explode Chords
--  Description: Seperates multi voice Midi items and distributes them to multiple new tracks.
--  Author: A-intheCode

--  License: GNU General Public License v3.0
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program. If not, see <https://www.gnu.org/licenses/>.
-- ]]



-- Explode MIDI Chords with Gap-Filling (Full Timeline & Sync Fix)
-- Autor: Gemini AI + A-intheCode


function ExplodeMidiChordsRobust()
    -- 1. Benutzereingabe
    local retval, user_input = reaper.GetUserInputs("Explode & Fill (Long Item Fix)", 2, "Toleranz (ms):,Ziel-Stimmenanzahl:", "25,4")
    if not retval then return end
    
    local TOLERANCE_MS, TARGET_VOICES = user_input:match("([^,]+),([^,]+)")
    TOLERANCE_MS = tonumber(TOLERANCE_MS) or 25
    TARGET_VOICES = tonumber(TARGET_VOICES) or 4

    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount == 0 then return end

    reaper.Undo_BeginBlock()

    -- Ersten Track für die Platzierung bestimmen
    local firstItem = reaper.GetSelectedMediaItem(0, 0)
    local parentTrack = reaper.GetMediaItem_Track(firstItem)
    local parentIdx = reaper.GetMediaTrackInfo_Value(parentTrack, "IP_TRACKNUMBER")

    -- Ziel-Tracks (Voices) erstellen
    local voiceTracks = {}
    reaper.InsertTrackAtIndex(parentIdx, true)
    local folder = reaper.GetTrack(0, parentIdx)
    reaper.GetSetMediaTrackInfo_String(folder, "P_NAME", "Exploded Folder", true)
    reaper.SetMediaTrackInfo_Value(folder, "I_FOLDERDEPTH", 1)

    for v = 1, TARGET_VOICES do
        reaper.InsertTrackAtIndex(parentIdx + v, true)
        local tr = reaper.GetTrack(0, parentIdx + v)
        reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "Voice " .. v, true)
        voiceTracks[v] = tr
        if v == TARGET_VOICES then reaper.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", -1) end
    end

    -- 2. Über selektierte Items loopen
    for m = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, m)
        local take = reaper.GetActiveTake(item)
        
        if take and reaper.TakeIsMIDI(take) then
            local _, noteCount = reaper.MIDI_CountEvts(take)
            local notes = {}

            -- Noten mit ABSOLUTER Projektzeit sammeln
            for i = 0, noteCount - 1 do
                local _, sel, mut, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
                local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)
                local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, endppq)
                table.insert(notes, {sel=sel, muted=mut, start_time=start_time, end_time=end_time, chan=chan, pitch=pitch, vel=vel})
            end

            -- Nach Zeit sortieren
            table.sort(notes, function(a, b) return a.start_time < b.start_time end)

            -- Akkorde gruppieren
            local chordGroups = {}
            local i = 1
            while i <= #notes do
                local group = {notes[i]}
                local j = i + 1
                while j <= #notes and (notes[j].start_time - notes[i].start_time) < (TOLERANCE_MS / 1000) do
                    table.insert(group, notes[j])
                    j = j + 1
                end
                table.sort(group, function(a, b) return a.pitch > b.pitch end)
                table.insert(chordGroups, group)
                i = j
            end

            -- 3. Noten in neue Items schreiben
            local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            for v = 1, TARGET_VOICES do
                local targetTr = voiceTracks[v]
                local newItem = reaper.CreateNewMIDIItemInProj(targetTr, itemPos, itemPos + itemLen)
                local newTake = reaper.GetActiveTake(newItem)

                -- Alle Noten für diese Stimme einfügen
                for _, group in ipairs(chordGroups) do
                    local n = group[v] or group[#group] -- Gap-Fill Logik
                    if n then
                        -- Projektzeit wieder in PPQ des NEUEN Takes umrechnen
                        local newStartPPQ = reaper.MIDI_GetPPQPosFromProjTime(newTake, n.start_time)
                        local newEndPPQ = reaper.MIDI_GetPPQPosFromProjTime(newTake, n.end_time)
                        reaper.MIDI_InsertNote(newTake, n.sel, n.muted, newStartPPQ, newEndPPQ, n.chan, n.pitch, n.vel, false)
                    end
                end
                reaper.MIDI_Sort(newTake) -- Erst am Ende sortieren für bessere Performance
            end
            
            -- Original stummschalten
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
        end
    end

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Explode Chords Full Fix", -1)
end

ExplodeMidiChordsRobust()
