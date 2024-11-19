-- Select a MIDI item, run

local cc_01_id = 40239
local cc_02_id = 40240
local cc_07_id = 40245
local cc_11_id = 40249
local velocity_id = 40237

-- insert command ID, look it up in the MIDI Editor section of the Action list, it's between 40237 
-- and 40840 named "CC: Set CC lane to ..."
-- local cc_action = "" 

-- Item: Open in built-in MIDI editor (set default behavior in preferences)
-- reaper.Main_OnCommand(40153, 0) 

-- reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), tonumber(cc_action))
reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), cc_11_id)
