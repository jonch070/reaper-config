-- [[
--  Name: Generate Midi from ChordTrack
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



-- REAPER Script: Pro Chord Generator (Octave Persistent)
-- Author: Gemini AI + A-intheCode


local note_map = { ["C"]=0, ["C#"]=1, ["Db"]=1, ["D"]=2, ["D#"]=3, ["Eb"]=3, ["E"]=4, ["F"]=5, ["F#"]=6, ["Gb"]=6, ["G"]=7, ["G#"]=8, ["Ab"]=8, ["A"]=9, ["A#"]=10, ["Bb"]=10, ["B"]=11, ["H"]=11 }

local name_to_intervals = {
    [""] = {0, 4, 7}, ["m"] = {0, 3, 7}, ["7"] = {0, 4, 7, 10}, ["maj7"] = {0, 4, 7, 11},
    ["m7"] = {0, 3, 7, 10}, ["dim"] = {0, 3, 6}, ["sus4"] = {0, 5, 7}, ["sus2"] = {0, 2, 7},
    ["5"] = {0, 7}, ["add9"] = {0, 4, 7, 14}, ["m(add9)"] = {0, 3, 7, 14}
}

function main()
    local selTrack = reaper.GetSelectedTrack(0, 0)
    if not selTrack then return end
    
    reaper.Undo_BeginBlock()
    local trackIdx = reaper.GetMediaTrackInfo_Value(selTrack, "IP_TRACKNUMBER")
    reaper.InsertTrackAtIndex(trackIdx, true)
    local chordTrack = reaper.GetTrack(0, trackIdx)
    reaper.GetSetMediaTrackInfo_String(chordTrack, "P_NAME", "Midi", true)

    for i = 0, reaper.CountTrackMediaItems(selTrack) - 1 do
        local item = reaper.GetTrackMediaItem(selTrack, i)
        local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        
        -- Regex: Findet Grundton (z.B. C#), dann die Oktave (z.B. 4)
        local rootStr, octStr = notes:match("^([A-Ha-h][#b]?)(%-?%d+)")
        
        if rootStr and octStr then
            local rootBase = note_map[rootStr:upper()]
            local octave = tonumber(octStr)
            local rootMIDI = (octave + 1) * 12 + rootBase
            
            -- Extrahiere den Rest des Namens als Suffix (z.B. "m7")
            local fullRoot = rootStr .. octStr
            local suffix = notes:sub(#fullRoot + 1):gsub("%s+", "")
            
            local intervals = name_to_intervals[suffix] or {0, 4, 7}
            
            local iStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local iLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local midiItem = reaper.CreateNewMIDIItemInProj(chordTrack, iStart, iStart + iLen, false)
            local take = reaper.GetActiveTake(midiItem)
            
            for _, v in ipairs(intervals) do
                reaper.MIDI_InsertNote(take, false, false, 0, 1920*iLen, 0, rootMIDI + v, 90, false)
            end
        end
    end
    reaper.Undo_EndBlock("Generate Exact Pitch Chords", -1)
    reaper.UpdateArrange()
end
main()
