-- [[
--  Name: Generate Chords from Midi
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





-- REAPER Script: Pro MIDI Chord Analyzer (Octave Persistent)
-- Author: Gemini AI + A-intheCode

local note_names = { [0]="C", [1]="C#", [2]="D", [3]="D#", [4]="E", [5]="F", [6]="F#", [7]="G", [8]="G#", [9]="A", [10]="A#", [11]="B" }
local min_segment_len = 0.15
local gap_threshold = 0.5

local chord_defs = {
    ["4,7"] = "", ["3,7"] = "m", ["4,7,10"] = "7", ["4,7,11"] = "maj7",
    ["3,7,10"] = "m7", ["3,6"] = "dim", ["5,7"] = "sus4", ["2,7"] = "sus2",
    ["7"] = "5", ["2,4,7"] = "add9", ["2,3,7"] = "m(add9)", ["4,7,9"] = "6"
}

function getChordName(notes)
    if #notes == 0 then return nil end
    table.sort(notes)
    
    local rootPitch = notes[1]
    local octave = math.floor(rootPitch / 12) - 1 -- Berechnet die Oktave (C4 = 60)
    local rootName = note_names[rootPitch % 12] .. octave
    
    local intervals = {}
    local seen = {}
    for i = 2, #notes do
        local diff = notes[i] - rootPitch
        if diff > 0 and not seen[diff] then
            table.insert(intervals, diff)
            seen[diff] = true
        end
    end
    
    -- Erst exakten Match suchen (für Add9 etc.)
    local interval_str = table.concat(intervals, ",")
    local suffix = chord_defs[interval_str]
    
    -- Fallback auf Oktav-Normalisierung
    if not suffix then
        local oct_intervals = {}
        local oct_seen = {}
        for _, v in ipairs(intervals) do
            local rel = v % 12
            if rel > 0 and not oct_seen[rel] then 
                table.insert(oct_intervals, rel)
                oct_seen[rel] = true
            end
        end
        table.sort(oct_intervals)
        suffix = chord_defs[table.concat(oct_intervals, ",")]
    end

    return rootName .. (suffix or "")
end

function main()
    local selItemCount = reaper.CountSelectedMediaItems(0)
    if selItemCount == 0 then return end
    reaper.Undo_BeginBlock()
    local firstTrack = reaper.GetMediaItem_Track(reaper.GetSelectedMediaItem(0,0))
    local trackPos = reaper.GetMediaTrackInfo_Value(firstTrack, "IP_TRACKNUMBER")
    reaper.InsertTrackAtIndex(trackPos, true)
    local emptyTrack = reaper.GetTrack(0, trackPos)
    reaper.GetSetMediaTrackInfo_String(emptyTrack, "P_NAME", "Chord Track", true)

    for i = 0, selItemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            local _, noteCount = reaper.MIDI_CountEvts(take)
            local timePoints = {}
            for n = 0, noteCount - 1 do
                local _, _, _, sPPQ, ePPQ, _, _, _ = reaper.MIDI_GetNote(take, n)
                table.insert(timePoints, reaper.MIDI_GetProjTimeFromPPQPos(take, sPPQ))
                table.insert(timePoints, reaper.MIDI_GetProjTimeFromPPQPos(take, ePPQ))
            end
            table.sort(timePoints)

            local raw = {}
            for e = 1, #timePoints - 1 do
                local tS, tE = timePoints[e], timePoints[e+1]
                if tE - tS > 0.001 then
                    local pMid = reaper.MIDI_GetPPQPosFromProjTime(take, tS + (tE-tS)/2)
                    local act = {}
                    for n = 0, noteCount - 1 do
                        local _, _, _, sP, eP, _, pit, _ = reaper.MIDI_GetNote(take, n)
                        if pMid >= sP and pMid < eP then table.insert(act, pit) end
                    end
                    local name = getChordName(act)
                    if name then table.insert(raw, {s=tS, e=tE, n=name}) end
                end
            end

            if #raw > 0 then
                local merged = {}
                local curr = raw[1]
                for s = 2, #raw do
                    if raw[s].n == curr.n and (raw[s].s - curr.e) <= gap_threshold then
                        curr.e = raw[s].e
                    else
                        if (curr.e - curr.s) >= min_segment_len then table.insert(merged, curr) end
                        curr = raw[s]
                    end
                end
                table.insert(merged, curr)
                for _, m in ipairs(merged) do
                    local eI = reaper.AddMediaItemToTrack(emptyTrack)
                    reaper.SetMediaItemInfo_Value(eI, "D_POSITION", m.s)
                    reaper.SetMediaItemInfo_Value(eI, "D_LENGTH", m.e - m.s)
                    reaper.GetSetMediaItemInfo_String(eI, "P_NOTES", m.n, true)
                end
            end
        end
    end
    reaper.Undo_EndBlock("Octave Analysis", -1)
    reaper.UpdateArrange()
end
main()
