-- NoIndex: true

--[[
    Lokasenna_GUI example

    - General demonstration
  - Tabs and layer sets
    - SubwindowsSet_note
  - Accessing elements' parameters

]]--
function Msg(value)
  --returns nothing

  if debug_output then --check if flag is set true (at the start of this script)
    reaper.ShowConsoleMsg(tostring(value) )
  end
end


local dm, _ = debug_mode
local function Msg(str)
  reaper.ShowConsoleMsg(tostring(str).."\n")
end

local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
inipath = reaper.get_ini_file()

--local info = debug.getinfo(1,'S');
--script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]

-- The Core library must be loaded prior to anything else
--------------------------------
 --REATRAK LOCAL GUI LIBRARY start
--------------------------------
--local lib_path = script_path --reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
--if not lib_path or lib_path == "" then
    --reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Script: Set Lokasenna_GUI v2 library path.lua' in your Action List.", "Whoops!", 0)
    --return
--end
--[[
loadfile(script_path .. "ReaTrak_Core.lua")()

GUI.req(script_path .. "ReaTrak_Classes/Class - Label.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Knob.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Tabs.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Slider.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Button.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Menubox.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Textbox.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Listbox.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Frame.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Options.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Window.lua")()

--------------------------------
 --REATRAK LOCAL GUI LIBRARY end
--------------------------------
--]]
--------------------------------
 --LOKASENNA GUI LIBRARY start
--------------------------------

local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Script: Set Lokasenna_GUI v2 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Label.lua")()
GUI.req("Classes/Class - Knob.lua")()
GUI.req("Classes/Class - Tabs.lua")()
GUI.req("Classes/Class - Slider.lua")()
GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Listbox.lua")()
GUI.req("Classes/Class - Frame.lua")()
GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Window.lua")()

--------------------------------
 --LOKASENNA GUI LIBRARY end
--------------------------------


-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end




------------------------------------
-------- Functions -----------------
------------------------------------

 marker_state = reaper.GetToggleCommandState( 40691 )
 
 if marker_state == 0 then
   reaper.Main_OnCommand(40691, 0) --View: Toggle show media cues in items
 end
 

bass_root_table = {"C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"}

osversion = reaper.GetOS()

ks_start = -1
ks_end = -1

function time_sel_item()

  sel_item = reaper.GetSelectedMediaItem( 0, 0 )
  item_pos = reaper.GetMediaItemInfo_Value( sel_item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( sel_item, "D_LENGTH" )
  item_end = item_pos + item_length
  start_pos, end_pos = reaper.GetSet_LoopTimeRange2( 0, true, false, item_pos, item_end, 0 )
  sel_track = reaper.GetMediaItemInfo_Value( sel_item, "P_TRACK" )
  reaper.Main_OnCommand(40297,0) -- Track: Unselect all tracks
  reaper.SetTrackSelected( sel_track, true )
  

end


local function GetPathSeparator()
  if osversion:find("Win") then return "\\"
  else return "/" end
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function NearestValue(table, number)
    local smallestSoFar, smallestIndex
    for i, y in ipairs(table) do
        if not smallestSoFar or (math.abs(number-y) < smallestSoFar) then
            smallestSoFar = math.abs(number-y)
            smallestIndex = i
        end
    end
    return smallestIndex, table[smallestIndex]
end

function position_in_table(table,key_name)

 local index={}
 for k,v in pairs(table) do
    index[v]=k
 end
 return index[key_name]
end

function keyswitch_notes()

    start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time1 == end_time1 then
      reaper.MB( "Select Regions & Track", "No Time Selection", 0 )
      reaper.defer(function () end)
      return
    end
    retval, num_markersOut, num_regionsOut = reaper.CountProjectMarkers( 0 )
    _, first_region = reaper.GetLastMarkerAndCurRegion( 0, start_time1 )
    _, last_region = reaper.GetLastMarkerAndCurRegion(0, end_time1)
    if last_region == -1 then last_region = num_regionsOut end
  
  retval_inputs, retvals_csv = reaper.GetUserInputs( "Ignore Keyswitch Note Number Range", 2, "end note 0-127 (-1 none),start note 0-127 (-1 none)", "-1,-1" )
      if retval_inputs then
         ks_end, ks_start = retvals_csv:match("([^,]+),([^,]+)")
         ks = 1
         
      else
         ks_end = -1 
         ks_start = -1
         reaper.MB( "Cancelled", "No Selection", 0 
         )
         reaper.defer(function () end)
         return
         
         --ks = 0
      end 
      
      

end


function chord_name_notes(nameOut)
    --[[
    --Msg("snap_midi_chords")
    --commandID1 = reaper.NamedCommandLookup("_RS36f146bbf2f5b41d41315020d307f6b50c4ccbac")
    --reaper.Main_OnCommand(commandID1, 0) --Script: ReaTrak move cursor to time selection.lua   
    start_loop, end_loop = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    --reaper.SetEditCurPos( start_loop, 0, 0 )

    time = start_loop --reaper.GetCursorPosition()
    
    region_count , num_markersOut , num_regionsOut = reaper.CountProjectMarkers(0)
    markrgnindexnumber, rgnendOut = reaper.GetLastMarkerAndCurRegion(0, time)
    if rgnendOut == -1 then rgnendOut = num_regionsOut end
    retval, isrgnOut, posOut, rgnendOut, nameOut, markrgnindexnumberOut = reaper.EnumProjectMarkers(rgnendOut)
    
    start_time, end_time = reaper.GetSet_LoopTimeRange(true, true, posOut, rgnendOut, 0)
    --clear_name_flag = 0 --this flag is needed in the SetProjectMarker4 function to enable the region name to be cleared
    --reaper.SetProjectMarker4(0, markrgnindexnumberOut, true, posOut, rgnendOut, chord, 0, clear_name_flag)
    --]]
    
    --if string.match( nameOut, "@.*") then next_region() end -- skip region marked @ ignore
    
    
    chordroot, chordtype = string.match(nameOut, "(%w[#b]?)(.*)$")
    
    if string.match(nameOut, "/C") then slash_note = "C" slash_num = 0 end
    if string.match(nameOut, "/C#") then slash_note = "C#" slash_num = -1 end 
    if string.match(nameOut, "/Db") then slash_note = "Db" slash_num = -1 end 
    if string.match(nameOut, "/D") then slash_note = "D" slash_num = -2 end 
    if string.match(nameOut, "/D#") then slash_note = "D#" slash_num = -3 end 
    if string.match(nameOut, "/Eb") then slash_note = "Eb" slash_num = -3 end 
    if string.match(nameOut, "/E") then slash_note = "E" slash_num = -4 end 
    if string.match(nameOut, "/F") then slash_note = "F" slash_num = -5 end 
    if string.match(nameOut, "/F#") then slash_note = "F#" slash_num = -6 end 
    if string.match(nameOut, "/Gb") then slash_note = "Gb" slash_num = -6 end
    if string.match(nameOut, "/G") then slash_note = "G" slash_num = -7 end 
    if string.match(nameOut, "/G#") then slash_note = "G#" slash_num = -8 end 
    if string.match(nameOut, "/Ab") then slash_note = "Ab" slash_num = -8 end 
    if string.match(nameOut, "/A") then slash_note = "A" slash_num = -8 end 
    if string.match(nameOut, "/A#") then slash_note = "A#" slash_num = -9 end 
    if string.match(nameOut, "/Bb") then slash_note = "Bb" slash_num = -9 end 
    if string.match(nameOut, "/B") then slash_note = "B" slash_num = -10 end 
     
        
    if not chordtype or #chordtype == 0 then chordtype = "Maj" end

    if chordroot == "C" then rootkey = 0 end
    if chordroot == "C#" then rootkey = 1 end
    if chordroot == "Db" then rootkey = 1 end
    if chordroot == "D" then rootkey = 2 end
    if chordroot == "D#" then rootkey = 3 end
    if chordroot == "Eb" then rootkey = 3 end
    if chordroot == "E" then rootkey = 4 end
    if chordroot == "F" then rootkey = 5 end
    if chordroot == "F#" then rootkey = 6 end
    if chordroot == "Gb" then rootkey = 6 end
    if chordroot == "G" then rootkey = 7 end
    if chordroot == "G#" then rootkey = 8 end
    if chordroot == "Ab" then rootkey = 8 end
    if chordroot == "A" then rootkey = 9 end
    if chordroot == "A#" then rootkey = 10 end
    if chordroot == "Bb" then rootkey = 10 end
    if chordroot == "B" then rootkey = 11 end



    if string.find(",Maj,M,", ","..chordtype..",", 1, true) then notenums = "0,4,7" end              
    if string.find(",m,min,", ","..chordtype..",", 1, true) then notenums = "0,3,7" end            
    if string.find(",dim,m-5,mb5,m(b5),0,", ","..chordtype..",", 1, true) then notenums = "0,3,6" end                
    if string.find(",aug,+,+5,(#5),", ","..chordtype..",", 1, true) then notenums = "0,4,8" end                
    if string.find(",-5,(b5),", ","..chordtype..",", 1, true) then notenums = "0,4,6" end                
    if string.find(",sus2,", ","..chordtype..",", 1, true) then notenums = "0,2,7" end                
    if string.find(",sus4,sus,(sus4),", ","..chordtype..",", 1, true) then notenums = "0,5,7" end                
    if string.find(",5,", ","..chordtype..",", 1, true) then notenums = "0,7,12" end                  
    if string.find(",5add7,5/7,", ","..chordtype..",", 1, true) then notenums = "0,7,10,12" end               
    if string.find(",add2,(add2),", ","..chordtype..",", 1, true) then notenums = "0,2,4,7" end              
    if string.find(",add4,(add4),", ","..chordtype..",", 1, true) then notenums = "0,4,5,7" end              
    if string.find(",madd4,m(add4),", ","..chordtype..",", 1, true) then notenums = "0,3,5,7" end              
    if string.find(",11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,17" end       
    if string.find(",11sus4,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,14,17" end       
    if string.find(",m11,min11,-11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,14,17" end       
    if string.find(",Maj11,maj11,M11,Maj7(add11),M7(add11),", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,14,17" end       
    if string.find(",mMaj11,minmaj11,mM11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,11,14,17" end       
    if string.find(",aug11,9+11,9aug11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,18" end       
    if string.find(",augm11, m9#11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,14,18" end       
    if string.find(",11b5,11-5,11(b5),", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,14,17" end       
    if string.find(",11#5,11+5,11(#5),", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,14,17" end       
    if string.find(",11b9,11-9,11(b9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,13,17" end       
    if string.find(",11#9,11+9,11(#9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15,17" end       
    if string.find(",11b5b9,11-5-9,11(b5b9),", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,13,17" end       
    if string.find(",11#5b9,11+5-9,11(#5b9),", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,13,17" end       
    if string.find(",11b5#9,11-5+9,11(b5#9),", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,15,17" end       
    if string.find(",11#5#9,11+5+9,11(#5#9),", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,15,17" end       
    if string.find(",m11b5,m11-5,m11(b5),", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,14,17" end       
    if string.find(",m11#5,m11+5,m11(#5),", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,14,17" end       
    if string.find(",m11b9,m11-9,m11(b9),", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,13,17" end       
    if string.find(",m11#9,m11+9,m11(#9),", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,15,17" end       
    if string.find(",m11b5b9,m11-5-9,m11(b5b9),", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,13,17" end       
    if string.find(",m11#5b9,m11+5-9,m11(#5b9),", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,13,17" end       
    if string.find(",m11b5#9,m11-5+9,m11(b5#9),", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,15,17" end       
    if string.find(",m11#5#9,m11+5+9,m11(#5#9),", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,15,17" end       
    if string.find(",Maj11b5,maj11b5,maj11-5,maj11(b5),", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,14,17" end       
    if string.find(",Maj11#5,maj11#5,maj11+5,maj11(#5),", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,14,17" end       
    if string.find(",Maj11b9,maj11b9,maj11-9,maj11(b9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,13,17" end       
    if string.find(",Maj11#9,maj11#9,maj11+9,maj11(#9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,15,17" end       
    if string.find(",Maj11b5b9,maj11b5b9,maj11-5-9,maj11(b5b9),", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,13,17" end       
    if string.find(",Maj11#5b9,maj11#5b9,maj11+5-9,maj11(#5b9),", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,13,17" end       
    if string.find(",Maj11b5#9,maj11b5#9,maj11-5+9,maj11(b5#9),", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,15,17" end       
    if string.find(",Maj11#5#9,maj11#5#9,maj11+5+9,maj11(#5#9),", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,15,17" end       
    if string.find(",13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,17,21" end    
    if string.find(",m13,min13,-13,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,14,17,21" end    
    if string.find(",Maj13,maj13,M13,Maj7(add13),M7(add13),min,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,14,17,21" end    
    if string.find(",mMaj13,minmaj13,mM13,", ","..chordtype..",", 1, true) then notenums = "0,3,7,11,14,17,21" end    
    if string.find(",13b5,13-5,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,14,17,21" end    
    if string.find(",13#5,13+5,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,14,17,21" end    
    if string.find(",13b9,13-9,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,13,17,21" end    
    if string.find(",13#9,13+9,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15,17,21" end    
    if string.find(",13b5b9,13-5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,13,17,21" end    
    if string.find(",13#5b9,13+5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,13,17,21" end    
    if string.find(",13b5#9,13-5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,15,17,21" end    
    if string.find(",13#5#9,13+5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,15,17,21" end    
    if string.find(",13b9#11,13-9+11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,13,18,21" end    
    if string.find(",m13b5,m13-5,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,14,17,21" end    
    if string.find(",m13#5,m13+5,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,14,17,21" end    
    if string.find(",m13b9,m13-9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,13,17,21" end    
    if string.find(",m13#9,m13+9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,15,17,21" end    
    if string.find(",m13b5b9,m13-5-9,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,13,17,21" end    
    if string.find(",m13#5b9,m13+5-9,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,13,17,21" end    
    if string.find(",m13b5#9,m13-5+9,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,15,17,21" end    
    if string.find(",m13#5#9,m13+5+9,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,15,17,21" end    
    if string.find(",Maj13b5,maj13b5,maj13-5,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,14,17,21" end    
    if string.find(",Maj13#5,maj13#5,maj13+5,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,14,17,21" end    
    if string.find(",Maj13b9,maj13b9,maj13-9,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,13,17,21" end    
    if string.find(",Maj13#9,maj13#9,maj13+9,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,15,17,21" end    
    if string.find(",Maj13b5b9,maj13b5b9,maj13-5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,13,17,21" end    
    if string.find(",Maj13#5b9,maj13#5b9,maj13+5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,13,17,21" end    
    if string.find(",Maj13b5#9,maj13b5#9,maj13-5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,15,17,21" end    
    if string.find(",Maj13#5#9,maj13#5#9,maj13+5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,15,17,21" end    
    if string.find(",Maj13#11,maj13#11,maj13+11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,14,18,21" end    
    if string.find(",13#11,13+11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,18,21" end    
    if string.find(",m13#11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,14,18,21" end    
    if string.find(",13sus4,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,14,17,21" end    
    if string.find(",6,M6,Maj6,maj6,", ","..chordtype..",", 1, true) then notenums = "0,4,7,9" end              
    if string.find(",m6,min6,", ","..chordtype..",", 1, true) then notenums = "0,3,7,9" end              
    if string.find(",6add4,6/4,6(add4),Maj6(add4),M6(add4),", ","..chordtype..",", 1, true) then notenums = "0,4,5,7,9" end            
    if string.find(",m6add4,m6/4,m6(add4),", ","..chordtype..",", 1, true) then notenums = "0,3,5,7,9" end            
    if string.find(",69,6add9,6/9,6(add9),Maj6(add9),M6(add9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,9,14" end           
    if string.find(",m6add9,m6/9,m6(add9),", ","..chordtype..",", 1, true) then notenums = "0,3,7,9,14" end           
    if string.find(",6sus2,", ","..chordtype..",", 1, true) then notenums = "0,2,7,9" end              
    if string.find(",6sus4,", ","..chordtype..",", 1, true) then notenums = "0,5,7,9" end              
    if string.find(",6add11,6/11,6(add11),Maj6(add11),M6(add11),", ","..chordtype..",", 1, true) then notenums = "0,4,7,9,17" end           
    if string.find(",m6add11,m6/11,m6(add11),m6(add11),", ","..chordtype..",", 1, true) then notenums = "0,3,7,9,17" end           
    if string.find(",7,dom,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10" end             
    if string.find(",7add2,", ","..chordtype..",", 1, true) then notenums = "0,2,4,7,10" end           
    if string.find(",7add4,", ","..chordtype..",", 1, true) then notenums = "0,4,5,7,10" end           
    if string.find(",m7,min7,-7,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10" end             
    if string.find(",m7add4,", ","..chordtype..",", 1, true) then notenums = "0,3,5,7,10" end           
    if string.find(",Maj7,maj7,Maj7,M7,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11" end             
    if string.find(",dim7,07,", ","..chordtype..",", 1, true) then notenums = "0,3,6,9" end              
    if string.find(",mMaj7,minmaj7,mmaj7,min/maj7,mM7,m(addM7),m(+7),-(M7),", ","..chordtype..",", 1, true) then notenums = "0,3,7,11" end             
    if string.find(",7sus2,", ","..chordtype..",", 1, true) then notenums = "0,2,7,10" end             
    if string.find(",7sus4,7sus,7sus11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10" end             
    if string.find(",Maj7sus2,maj7sus2,M7sus2,", ","..chordtype..",", 1, true) then notenums = "0,2,7,11" end             
    if string.find(",Maj7sus4,maj7sus4,M7sus4,", ","..chordtype..",", 1, true) then notenums = "0,5,7,11" end             
    if string.find(",aug7,+7,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10" end             
    if string.find(",7b5,7-5,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10" end             
    if string.find(",7#5,7+5,7+,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10" end             
    if string.find(",m7b5,m7-5,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10" end             
    if string.find(",m7#5,m7+5,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10" end             
    if string.find(",Maj7b5,maj7b5,maj7-5,M7b5,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11" end             
    if string.find(",Maj7#5,maj7#5,maj7+5,M7+5,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11" end             
    if string.find(",7b9,7-9,7(addb9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,13" end          
    if string.find(",7#9,7+9,7(add#9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15" end          
    if string.find(",m7b9, m7-9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,13" end          
    if string.find(",m7#9, m7+9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,15" end          
    if string.find(",Maj7b9,maj7b9,maj7-9,maj7(addb9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,13" end          
    if string.find(",Maj7#9,maj7#9,maj7+9,maj7(add#9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,15" end          
    if string.find(",7b9b13,7-9-13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,13,20" end       
    if string.find(",m7b9b13, m7-9-13,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,13,20" end       
    if string.find(",7b13,7-13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,20" end       
    if string.find(",m7b13,m7-13,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,14,20" end       
    if string.find(",7#9b13,7+9-13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15,20" end       
    if string.find(",m7#9b13,m7+9-13,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,15,20" end       
    if string.find(",7b5b9,7-5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,13" end          
    if string.find(",7b5#9,7-5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,15" end          
    if string.find(",7#5b9,7+5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,13" end          
    if string.find(",7#5#9,7+5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,15" end          
    if string.find(",7#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,18" end          
    if string.find(",7add6,7/6,", ","..chordtype..",", 1, true) then notenums = "0,4,7,9,10" end           
    if string.find(",7add11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,17" end          
    if string.find(",7add13,7/13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,21" end          
    if string.find(",m7add11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,17" end          
    if string.find(",m7b5b9,m7-5-9,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,13" end          
    if string.find(",m7b5#9,m7-5+9,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,15" end          
    if string.find(",m7#5b9,m7+5-9,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,13" end          
    if string.find(",m7#5#9,m7+5+9,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,15" end          
    if string.find(",m7#11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,18" end          
    if string.find(",Maj7b5b9,maj7b5b9,maj7-5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,13" end          
    if string.find(",Maj7b5#9,maj7b5#9,maj7-5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,15" end          
    if string.find(",Maj7#5b9,maj7#5b9,maj7+5-9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,13" end          
    if string.find(",Maj7#5#9,maj7#5#9,maj7+5+9,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,15" end          
    if string.find(",Maj7add11,maj7add11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,17" end          
    if string.find(",Maj7#11,maj7#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,18" end          
    if string.find(",9,7(add9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14" end          
    if string.find(",m9,min9,-9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,10,14" end          
    if string.find(",Maj9,maj9,M9,Maj7(add9),M7(add9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,14" end          
    if string.find(",Maj9sus4,maj9sus4,", ","..chordtype..",", 1, true) then notenums = "0,5,7,11,14" end          
    if string.find(",mMaj9,minmaj9,mmaj9,min/maj9,mM9,m(addM9),m(+9),-(M9),", ","..chordtype..",", 1, true) then notenums = "0,3,7,11,14" end          
    if string.find(",9sus4,9sus,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,14" end          
    if string.find(",aug9,+9,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15" end          
    if string.find(",9add6,9/6,", ","..chordtype..",", 1, true) then notenums = "0,4,7,9,10,14" end        
    if string.find(",m9add6,m9/6,", ","..chordtype..",", 1, true) then notenums = "0,3,7,9,14" end           
    if string.find(",9b5,9-5,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,14" end          
    if string.find(",9#5,9+5,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,14" end          
    if string.find(",m9b5,m9-5,", ","..chordtype..",", 1, true) then notenums = "0,3,6,10,14" end          
    if string.find(",m9#5,m9+5,", ","..chordtype..",", 1, true) then notenums = "0,3,8,10,14" end          
    if string.find(",Maj9b5,maj9b5,", ","..chordtype..",", 1, true) then notenums = "0,4,6,11,14" end          
    if string.find(",Maj9#5,maj9#5,", ","..chordtype..",", 1, true) then notenums = "0,4,8,11,14" end          
    if string.find(",Maj9#11,maj9#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,11,14,18" end       
    if string.find(",b9#11,-9+11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,13,18" end       
    if string.find(",add9,2,", ","..chordtype..",", 1, true) then notenums = "0,4,7,14" end             
    if string.find(",madd9,m(add9),-(add9),", ","..chordtype..",", 1, true) then notenums = "0,3,7,14" end             
    if string.find(",add11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,17" end             
    if string.find(",madd11,m(add11),-(add11),", ","..chordtype..",", 1, true) then notenums = "0,3,7,17" end             
    if string.find(",(b9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,13" end             
    if string.find(",(#9),", ","..chordtype..",", 1, true) then notenums = "0,4,7,15" end             
    if string.find(",(b5b9),", ","..chordtype..",", 1, true) then notenums = "0,4,6,13" end             
    if string.find(",(#5b9),", ","..chordtype..",", 1, true) then notenums = "0,4,8,13" end             
    if string.find(",(b5#9),", ","..chordtype..",", 1, true) then notenums = "0,4,6,15" end             
    if string.find(",(#5#9),", ","..chordtype..",", 1, true) then notenums = "0,4,8,15" end             
    if string.find(",m(b9), mb9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,13" end             
    if string.find(",m(#9), m#9,", ","..chordtype..",", 1, true) then notenums = "0,3,7,15" end             
    if string.find(",m(b5b9), mb5b9,", ","..chordtype..",", 1, true) then notenums = "0,3,6,13" end             
    if string.find(",m(#5b9), m#5b9,", ","..chordtype..",", 1, true) then notenums = "0,3,8,13" end             
    if string.find(",m(b5#9), mb5#9,", ","..chordtype..",", 1, true) then notenums = "0,3,6,15" end             
    if string.find(",m(#5#9), m#5#9,", ","..chordtype..",", 1, true) then notenums = "0,3,8,15" end             
    if string.find(",m(#11), m#11,", ","..chordtype..",", 1, true) then notenums = "0,3,7,18" end             
    if string.find(",(#11),", ","..chordtype..",", 1, true) then notenums = "0,4,7,18" end             
    if string.find(",m#5,", ","..chordtype..",", 1, true) then notenums = "0,3,8" end                
    if string.find(",maug,augaddm3,augadd(m3),", ","..chordtype..",", 1, true) then notenums = "0,3,8,10" end                  
    if string.find(",13#9#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15,18,21" end    
    if string.find(",13#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,18,21" end    
    if string.find(",13susb5,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,14,17,21" end    
    if string.find(",13susb5#9,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,15,21" end       
    if string.find(",13susb5b9,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,13,17,21" end    
    if string.find(",13susb9,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,13,17,21" end    
    if string.find(",13susb9#11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,13,18,21" end    
    if string.find(",13sus#5,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,17,21" end       
    if string.find(",13sus#5b9,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,13,17,21" end    
    if string.find(",13sus#5b9#11,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,13,18,21" end    
    if string.find(",13sus#5#11,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,18" end          
    if string.find(",13sus#5#9#11,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,15,18" end       
    if string.find(",13sus#9,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,15,17,21" end    
    if string.find(",13sus#9#11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,15,18,21" end    
    if string.find(",13sus#11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,14,18,21" end    
    if string.find(",7b5b13,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,20" end              
    if string.find(",7b5#9b13,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,15,20" end       
    if string.find(",7#5#11,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,18" end          
    if string.find(",7#5#9#11,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,15,18" end       
    if string.find(",7#5b9#11,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,13,18" end       
    if string.find(",7#9#11b13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,15,18,20" end       
    if string.find(",7#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10, 18" end             
    if string.find(",7#11b13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,18,20" end       
    if string.find(",7susb5,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10" end             
    if string.find(",7susb5b9,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,13" end          
    if string.find(",7b5b9b13,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,13,20" end       
    if string.find(",7susb5b13,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,14,20" end       
    if string.find(",7susb5#9,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,15" end          
    if string.find(",7susb5#9b13,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,15,20" end       
    if string.find(",7susb9,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,13" end          
    if string.find(",7susb9b13,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,13,20" end       
    if string.find(",7susb9#11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,13,18" end       
    if string.find(",7susb9#11b13,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,13,18,20" end    
    if string.find(",7susb13,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,20" end          
    if string.find(",7sus#5,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10" end             
    if string.find(",7sus#5#9#11,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,15,18" end       
    if string.find(",7sus#5#11,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,18" end          
    if string.find(",7sus#9,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,15" end          
    if string.find(",7sus#9b13,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,15,20" end       
    if string.find(",7sus#9#11b13,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,15,18,20" end    
    if string.find(",7sus#11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,18" end          
    if string.find(",7sus#11b13,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,18,20" end       
    if string.find(",9b5b13,", ","..chordtype..",", 1, true) then notenums = "0,4,6,10,14,20" end       
    if string.find(",9b13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,20" end       
    if string.find(",9#5#11,", ","..chordtype..",", 1, true) then notenums = "0,4,8,10,14,18" end       
    if string.find(",9#11,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,18" end       
    if string.find(",9#11b13,", ","..chordtype..",", 1, true) then notenums = "0,4,7,10,14,18,20" end    
    if string.find(",9susb5,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,14" end    
    if string.find(",9susb5b13,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,14,20" end    
    if string.find(",9sus#11,", ","..chordtype..",", 1, true) then notenums = "0,5,7,10,18" end          
    if string.find(",9susb5#9,", ","..chordtype..",", 1, true) then notenums = "0,5,6,10,14,15" end       
    if string.find(",9sus#5#11,", ","..chordtype..",", 1, true) then notenums = "0,5,8,10,14,18" end
    if string.find(",quartal,", ","..chordtype..",", 1, true) then notenums = "0,5,10,15" end
    if string.find(",sowhat,", ","..chordtype..",", 1, true) then notenums = "0,5,10,16" end
                 
                     
    --Msg("Chord Type: "..chordtype)
    --Msg("Note Numbers: "..notenums)
    
    
    
    --Convert Chord to Reascale
    
    x1=1
    x2=0
    x3=0
    x4=0
    x5=0
    x6=0
    x7=0
    x8=0
    x9=0
    x10=0
    x11=0
    x12=0
    
    
    
    
    --Cnotes = {0, 4, 7, 10}
    local str = (notenums)
    local t = {}
    for num in string.gmatch(str, "%d+") do
        t[#t+1] = tonumber(num)
    end
    
    
    Cnotes = t
    
      if Cnotes[2] == 1 then x2=2
      elseif Cnotes[2] == 2 then x3=2
      elseif Cnotes[2] == 3 then x4=3
      elseif Cnotes[2] == 4 then x5=3
      elseif Cnotes[2] == 5 then x6=4
      elseif Cnotes[2] == 6 then x7=5
      elseif Cnotes[2] == 7 then x8=5
      elseif Cnotes[2] == 8 then x9=5
      elseif Cnotes[2] == 9 then x10=6
      elseif Cnotes[2] == 10 then x11=7
      elseif Cnotes[2] == 11 then x12=7
      elseif Cnotes[2] == 13 then x2=9
      elseif Cnotes[2] == 14 then x3=9
      elseif Cnotes[2] == 15 then x4=9
      elseif Cnotes[2] == 16 then x5=9
      elseif Cnotes[2] == 17 then x6="B"
      elseif Cnotes[2] == 18 then x7="B"
    
      end
      
      if Cnotes[3] == 3 then x4=3 
      elseif Cnotes[3] == 4 then x5=3
      elseif Cnotes[3] == 5 then x6=4
      elseif Cnotes[3] == 6 then x7=5
      elseif Cnotes[3] == 7 then x8=5
      elseif Cnotes[3] == 8 then x9=5  
      elseif Cnotes[3] == 9 then x10=6
      elseif Cnotes[3] == 10 then x11=7
      elseif Cnotes[3] == 11 then x12=7
      elseif Cnotes[3] == 13 then x2=9
      elseif Cnotes[3] == 14 then x3=9
      elseif Cnotes[3] == 15 then x4=9
      elseif Cnotes[3] == 16 then x5=9
      elseif Cnotes[3] == 17 then x6="B"
      elseif Cnotes[3] == 18 then x7="B"
    
      end
      
      if Cnotes[4] == 5 then x6=4
      elseif Cnotes[4] == 6 then x7=5
      elseif Cnotes[4] == 7 then x8=5
      elseif Cnotes[4] == 8 then x9=5
      elseif Cnotes[4] == 9 then x10=6
      elseif Cnotes[4] == 10 then x11=7
      elseif Cnotes[4] == 11 then x12=7
      elseif Cnotes[4] == 13 then x2=9
      elseif Cnotes[4] == 14 then x3=9
      elseif Cnotes[4] == 15 then x4=9
      elseif Cnotes[4] == 16 then x5=9
      elseif Cnotes[4] == 17 then x6="B"
      elseif Cnotes[4] == 18 then x7="B"  
      elseif Cnotes[4] == 19 then x8="B"
      elseif Cnotes[4] == 20 then x9="B"
      elseif Cnotes[4] == 21 then x10="D"
      elseif Cnotes[4] == 22 then x11="D"
      elseif Cnotes[4] == 23 then x12="D"
       
      end  
    
    
      if Cnotes[5] == 6 then x7=5 
      elseif Cnotes[5] == 7 then x8=5
      elseif Cnotes[5] == 8 then x9=5
      elseif Cnotes[5] == 9 then x10=6
      elseif Cnotes[5] == 10 then x11=7
      elseif Cnotes[5] == 11 then x12=7
      elseif Cnotes[5] == 13 then x2=9
      elseif Cnotes[5] == 14 then x3=9
      elseif Cnotes[5] == 15 then x4=9
      elseif Cnotes[5] == 16 then x5=9
      elseif Cnotes[5] == 17 then x6="B"
      elseif Cnotes[5] == 18 then x7="B"
      elseif Cnotes[5] == 19 then x8="B"
      elseif Cnotes[5] == 20 then x9="B"
      elseif Cnotes[5] == 21 then x10="D"
      elseif Cnotes[5] == 22 then x11="D"
      elseif Cnotes[5] == 23 then x12="D"
      
      end  
    
    
      
      if Cnotes[6] == 7 then x8=6
      elseif Cnotes[6] == 8 then x9=6
      elseif Cnotes[6] == 9 then x10=6
      elseif Cnotes[6] == 10 then x11=7
      elseif Cnotes[6] == 11 then x12=7
      elseif Cnotes[6] == 13 then x2=9
      elseif Cnotes[6] == 14 then x3=9
      elseif Cnotes[6] == 15 then x4=9
      elseif Cnotes[6] == 16 then x5=9
      elseif Cnotes[6] == 17 then x6="B"
      elseif Cnotes[6] == 18 then x7="B"
      elseif Cnotes[6] == 19 then x8="B"
      elseif Cnotes[6] == 20 then x9="B"
      elseif Cnotes[6] == 21 then x10="D"
      elseif Cnotes[6] == 22 then x11="D"
      elseif Cnotes[6] == 23 then x12="D"
      
      end   
    
    
      if Cnotes[7] == 7 then x8=7
      elseif Cnotes[7] == 8 then x9=7
      elseif Cnotes[7] == 9 then x10=7
      elseif Cnotes[7] == 10 then x11=7
      elseif Cnotes[7] == 11 then x12=7
      elseif Cnotes[7] == 13 then x2=9
      elseif Cnotes[7] == 14 then x3=9
      elseif Cnotes[7] == 15 then x4=9
      elseif Cnotes[7] == 16 then x5=9
      elseif Cnotes[7] == 17 then x6="B"
      elseif Cnotes[7] == 18 then x7="B"
      elseif Cnotes[7] == 19 then x8="B"
      elseif Cnotes[7] == 20 then x9="B"
      elseif Cnotes[7] == 21 then x10="D"
      elseif Cnotes[7] == 22 then x11="D"
      elseif Cnotes[7] == 23 then x12="D"
      
      end   
    
    
    reascale = (x1 .. x2 .. x3 .. x4 .. x5 .. x6 .. x7 .. x8 .. x9 .. x10 .. x11 .. x12)
    
    
    
    
                  
    
    if Cnotes[3] == nil then Cnotes[3] = 0 end
    if Cnotes[4] == nil then Cnotes[4] = 0 end
    if Cnotes[5] == nil then Cnotes[5] = 0 end
    if Cnotes[6] == nil then Cnotes[6] = 0 end
    if Cnotes[7] == nil then Cnotes[7] = 0 end
    

    -- @website http://forum.cockos.com/member.php?u=70694
    
      for key in pairs(reaper) do _G[key]=reaper[key]  end
      
end -- end of funtion chord_name_notes()


function chords_table()

  --Msg("rootkey "..rootkey)

  --Msg("notenums ".. notenums)
  
  
  
  -- Convert string to table using function string:split(sep)
  notenums_table = notenums.split(notenums, ',')
  --------------------------
  --Msg("notenums_table 6 "..notenums_table[6])
  
  
  num_chord_notes = tablelength(notenums_table)

  
  -- Convert string to table
  chord_notes = {}
  for note in notenums:gmatch("%d*") do
     table.insert(chord_notes, tonumber(note))
  end
  
  
  ----------------------------------------- 
  --- Create chord notes table
  
  

  
  chord_notes_table = {}
  -- Insert slash notes into table
  octave = 0
  if slash_num then
    for i = 0, 10 do
      insert_note = ((rootkey+octave) + (slash_num+octave))
     
      if insert_note > -1 and insert_note < 128 then
        table.insert(chord_notes_table, tonumber(insert_note))
      end
      octave = octave +12
    end  
  end
  -- Insert all chord notes over all octaves into table
  for i = 1, num_chord_notes do
    
    insert_note = (chord_notes[i] + rootkey -12)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end 
    insert_note = (chord_notes[i] + rootkey)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +12)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +24)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end          
    insert_note = (chord_notes[i] + rootkey +36)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +48)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +60)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +72)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +84)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +96)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +108)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end
    insert_note = (chord_notes[i] + rootkey +120)
   
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_notes_table, tonumber(insert_note))
    end 

  end 
  
  
  chord_root_table = {}
  -- Insert slash notes into table
  octave = 0
  if slash_num then
    for i = 0, 10 do
      insert_note = ((rootkey+octave) + (slash_num+octave))
     
      if insert_note > -1 and insert_note < 128 then
        table.insert(chord_notes_table, tonumber(insert_note))
      end
      octave = octave +12
    end  
  end
  -- Insert all chord notes over all octaves into table
  --for i = 1, num_chord_notes do
    
    insert_note = (rootkey -12)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end 
    insert_note = (rootkey)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +12)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +24)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end          
    insert_note = (rootkey +36)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +48)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +60)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +72)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +84)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +96)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +108)
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end
    insert_note = (rootkey +120)
   
    if insert_note > -1 and insert_note < 128 then
      table.insert(chord_root_table, tonumber(insert_note))
    end 

   
    table.sort(chord_root_table)
    
    table.sort(chord_notes_table)
    
    chord_notes_table_count = tablelength(chord_notes_table)
    
  
  reg_cnt = reaper.CountProjectMarkers(0)
  chords = {}
  for i=0, reg_cnt-1 do
    _, isrgn, pos, rgnend, name, index = reaper.EnumProjectMarkers( i )
    if isrgn then
    --Msg("name ".. name .." pos ".. pos)
      chords[name] = {Start = pos, End = rgnend, Name = name,Index = index}
      chords[pos] = {Start = pos, End = rgnend, Name = name,Index = index}
      chords[rgnend] = {Start = pos, End = rgnend, Name = name,Index = index}
      chords[index] = {Start = pos, End = rgnend, Name = name,Index = index}
    
    end
  end
  
end  -- end function chords_table()


function sel_note_table()

  item = reaper.GetSelectedMediaItem(0, 0)
  -- Get the active take
  take = reaper.GetActiveTake(item)
  
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
  _, notecnt = reaper.MIDI_CountEvts( take )
  
  for i = 0, notecnt do -- deselect all notes first
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
  end  
  --if reaper.TakeIsMIDI(take) then
  
  ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
  ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
  
  for i = 0, notecnt do -- set notes selected starting in time selection
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
      reaper.MIDI_SetNote( take, i, true, false, startppqpos, endppqpos, chan, pitch, vel, true )
      
    end
    
  end
  --reaper.MB( "Continue", "Continue", 1 )
  --reaper.Main_OnCommand(40153, 0) --Item: Open in built-in MIDI editor (set default behavior in preferences)
  
  --ME = reaper.MIDIEditor_GetActive()
  --if not ME then return end
  --take = reaper.MIDIEditor_GetTake(ME)
  --if not take or not reaper.TakeIsMIDI(take) then return end
  --Msg("Select All Midi Notes")
  --reaper.MIDIEditor_OnCommand( ME, 40877 ) --Edit: Select all notes starting in time selection
  
  --reaper.MB( "Continue", "Continue", 1 )
  _, notecnt = reaper.MIDI_CountEvts( take )
  --Msg("notecnt "..notecnt)
  --if not notecnt then
  --  next_region()
  --    end  
    count = 0
    sel_count = 0
    low_pitch = 0
    hi_pitch =127
    last_pitch = 0
    first_note_index = 0
    
    sel_notes = {}
    for i = 0, notecnt -1 do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
      if selected then
        
        
        --Msg("Found Selected note ".. pitch .." @ ".. i)
        
        
        table.insert(sel_notes, "Pitch="..pitch .. " Idx="..i)
        
        if count == 0 then
          first_note_index = i  -- first selected note idx
          
          --Msg("count "..count)
          --Msg("first note ".. pitch .." @ ".. i)
          last_pitch = pitch
          hi_pitch = pitch
          
        end
        
        if pitch <= last_pitch then
          --low_pitch = pitch
          last_pitch = pitch
        end
        
        if pitch >= hi_pitch then
          hi_pitch = pitch
          last_pitch = pitch
        end
        
        last_count = count
        count = count +1
        last_note = i 
        
         
      end
    --Msg("sel_notes[sel_note_index] "..sel_notes[1].Idx)  
    end
    table.sort(sel_notes, function(a,b) return a < b end)
    --Msg("SAVE TABLE ON")
    --table.save( sel_notes , "C:\\temp\\table-sel_notes.txt" )
    
    
    pattern = "Pitch=(%d+) Idx=(%d+)" -- "(%d+),(%d+)" 
    --local pitch_i, i_pitch = sel_notes[i]:match(pattern)
    --Pitch=52 Idx=55
    --pitch_i = tonumber(pitch_i)
    --i_pitch = tonumber(i_pitch)
    --Msg("pitch_i "..pitch_i)
    --Msg("i_pitch "..i_pitch)
    --Msg("first_note_index "..first_note_index)
    --Msg("sel_notes[1] "..sel_notes[1])
    note_str = tostring(sel_notes[1])
    --Msg("note_str "..note_str)       
    low_pitch, low_idx = note_str:match(pattern)
    --Msg("low_pitch "..low_pitch)
    
    

    selected_pitch_order = {}

    order = 0
    --for i = first_note_index , (first_note_index + count) do
    --for i = first_note_index, first_note_index + count do -- -1 do 
    for i = 0, notecnt  do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
      if selected then 
        order = order +1
        --Msg("Found Selected note 2 ".. pitch .." @ ".. i)
       
         
        selected_pitch_order[order] = { sort_pitch = pitch, sort_idx = i}
        --table.insert(sel_notes, "Pitch="..pitch .. " Idx="..i)
      end
    end
    
    
    table.sort(selected_pitch_order, function(a,b) return a.sort_pitch < b.sort_pitch end) 
    
    --Msg("SAVE TABLE ON")
    --table.save( sel_notes , "C:\\temp\\table-sel_pitch_order.txt" )
    
    
    
    for i = 1, count do
    
      --Msg("note ".. selected_pitch_order[i].sort_pitch .. " idx " ..selected_pitch_order[i].sort_idx)
    end   
   
     
    function nt2_write(path, data, sep)
        sep = sep or ','
        local file = assert(io.open(path, "w"))
        file:write('Image ID' .. "," .. 'Caption')
        file:write('\n')
        for k, v in pairs(data) do
          file:write(v["image_id"] .. "," .. v["caption"])
          file:write('\n')
        end
        file:close()
    end
    
    function print_r (t, fd)
        fd = fd or io.stdout
        local function print(str)
           str = str or ""
           fd:write(str.."\n")
        end
        
    end



    --Msg("count "..count)
    --Msg("low_pitch "..low_pitch) 
    --Msg("hi_pitch "..hi_pitch)
    --Msg("first_note_index "..first_note_index) 
    --Msg("last_pitch "..last_pitch)
    --Msg("sel_notes[1].Pitch "..sel_notes[1].Idx)
    previous_note = -1
    previous_chord_notes_table_index = 0
    root_note_number = 0
    root_table_index = 0
    chord_notes_table_index = 0
    current_chord_notes_table_index = 0
    
    --for i = first_note_index, (first_note_index + count)-1 do
    --Msg("count through notes and set new pich")
    --for i = first_note_index, (first_note_index + count)-1 do
    for i = 1, count do --  -1 do
      
      --Msg("#note ".. selected_pitch_order[i].sort_pitch .. " #idx " ..selected_pitch_order[i].sort_idx)
      pitch_i =  selected_pitch_order[i].sort_pitch
      i_pitch = selected_pitch_order[i].sort_idx
      
      
      
      low_pitch = selected_pitch_order[1].sort_pitch
      
 
      if pitch_i == low_pitch then
        root_table_index, new_pitch = NearestValue(chord_root_table, pitch_i)
        --Msg("chord root number = "..root_table_index)
        --Msg("root number new pitch "..new_pitch)
        --Msg("note idx ".. i_pitch)
        new_pitch = chord_root_table[root_table_index]
        if not new_pitch then break end
        --Msg("new_pitch "..new_pitch)
        root_note_number = new_pitch
        chord_notes_table_index = position_in_table(chord_notes_table,root_note_number)
        current_chord_notes_table_index = chord_notes_table_index
        --root_note_number_index = chord_notes_table[root_note_number]
        --Msg("root_note_number_index "..root_note_number_index)
        --root_pitch_index = table_index
      end
      
      if pitch_i == previous_note then
        --Msg("previous_note "..previous_note)
        --Msg("pitch_i "..pitch_i)
        --Msg("previous_note "..previous_note .." pitch_i ".. pitch_i)
        new_pitch = chord_notes_table[previous_chord_notes_table_index]
        --if not new_pitch then break end
        current_chord_notes_table_index = position_in_table(chord_notes_table, new_pitch)
        --Msg("previous_note "..previous_note)
        --Msg("= previous new_pitch "..new_pitch)
        
      end  
    
      
      
      if pitch_i > low_pitch and pitch_i > previous_note then
        --Msg("pitch > low_pitch "..pitch_i)
        octave_notes_opt = GUI.Val("octave_notes_opt")
        if octave_notes_opt == 1 then note_limit = 125 end
        if octave_notes_opt == 2 then note_limit = 23 end
        
        if pitch_i > previous_note and pitch_i > root_note_number +note_limit then
        
          new_pitch = position_in_table(chord_notes_table, current_chord_notes_table_index +1)
          --if not new_pitch then break end
          current_chord_notes_table_index = position_in_table(chord_notes_table, new_pitch)
        end
        
        if pitch_i > root_note_number +note_limit and previous_note < root_note_number +note_limit then
          --Msg("Next Octave Pitch "..pitch_i)
          root_table_index, new_pitch = NearestValue(chord_root_table, pitch_i)
          new_pitch = chord_root_table[root_table_index]
          --if not new_pitch then break end
          root_note_number = new_pitch
          --new_pitch = chord_notes_table[chord_notes_table_index]
          current_chord_notes_table_index = position_in_table(chord_notes_table, new_pitch)
          --Msg("previous_note "..previous_note)
          --Msg("new_pitch "..new_pitch)
        
        else
        
          if pitch_i > previous_note and pitch_i < root_note_number +note_limit then 
            chord_notes_table_index = position_in_table(chord_notes_table, current_chord_notes_table_index +1)
            --Msg("root_note_number "..root_note_number)
            --Msg("chord_notes_table_index "..chord_notes_table_index)
            --new_pitch = chord_notes_table_index
            new_pitch = chord_notes_table[previous_chord_notes_table_index +1]
            if not new_pitch then break end
            current_chord_notes_table_index = position_in_table(chord_notes_table, new_pitch)
            --Msg("previous_note "..previous_note)
            --Msg("else new_pitch < root_note_number +23 "..new_pitch)
            --chords_table()
          end
          
          if pitch_i > previous_note and pitch_i > root_note_number +note_limit then 
            new_pitch = chord_notes_table[previous_chord_notes_table_index +1]
            if not new_pitch then break end
            current_chord_notes_table_index = position_in_table(chord_notes_table, new_pitch)
            --current_chord_notes_table_index = previous_chord_notes_table_index
            --Msg("previous_note "..previous_note)
            --Msg("else new_pitch > root_note_number +23 "..new_pitch)
            --chords_table()
          end          
            
        end
        
       
      end
      
      previous_note = pitch_i --new_pitch
      
      previous_chord_notes_table_index = current_chord_notes_table_index
      
      current_pitch = new_pitch
      
      --Msg("current_chord_notes_table_index "..tostring(current_chord_notes_table_index))
      
      --sel_note_idx = sel_notes[i].Idx
      _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i_pitch )
      --Msg("Current Note Position "..current_pitch)
      --Msg("NOTE SHIFT ON")
      --note_mute = false
      if new_pitch < ks_start or new_pitch > ks_end then
        octave_notes_opt = GUI.Val("octave_notes_opt")
        --Msg("octave_notes_opt "..octave_notes_opt)
        if new_pitch < root_note_number +11 and octave_notes_opt == 1 then note_mute = false end
        if new_pitch > root_note_number +11 and octave_notes_opt == 1 then note_mute = true end
        if new_pitch < root_note_number +11 and octave_notes_opt == 2 then note_mute = false end
        if new_pitch > root_note_number +11 and octave_notes_opt == 2 then note_mute = false end
          reaper.MIDI_SetNote( take, i_pitch  , true, note_mute, startppqpos, endppqpos, chan, new_pitch, vel, true ) 
          --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
          _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i_pitch )
          --Msg("Changed Note Position "..current_pitch) 
      end
    end   
    
    

    
    reaper.MIDI_Sort( take )
    --reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
end      -- end function sel_note_table()


function btn_click_octave_up()  

  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto octave_up_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto octave_up_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto octave_up_end
  end
  
  item = reaper.GetSelectedMediaItem(0, 0)
  -- Get the active take
  take = reaper.GetActiveTake(item)
  
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
  _, notecnt = reaper.MIDI_CountEvts( take )
  
  for i = 0, notecnt do -- deselect all notes first
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
  end  
  --if reaper.TakeIsMIDI(take) then
  
  ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
  ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
  
  for i = 0, notecnt do -- set notes selected starting in time selection
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
      reaper.MIDI_SetNote( take, i, true, muted, startppqpos, endppqpos, chan, pitch, vel, true )
      
    end
    
  end

   reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40179 ) --Edit: Move notes up one octave  
  
--[[  
  --reaper.MB( "Continue", "Continue", 1 )
  _, notecnt = reaper.MIDI_CountEvts( take )
  --Msg("notecnt "..notecnt)
  --if not notecnt then
  --  next_region()
  --    end  
    count = 0
    sel_count = 0
    low_pitch = 0
    hi_pitch =127
    last_pitch = 0
    first_note_index = 0
    
    sel_notes = {}
    for i = 0, notecnt -1 do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
      if selected then
        if pitch < ks_start or pitch > ks_end then
          --Msg("Note "..i .." "..pitch)
          reaper.MIDI_SetNote( take, i  , true, muted, startppqpos, endppqpos, chan, pitch+12, vel, true )
          
          --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
          _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i )
          --Msg("Changed Note "..i .. " "..current_pitch) 
        end
      end
    end
--]]    
    reaper.MIDI_Sort(take)
    reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
    ::octave_up_end::
end

function btn_click_octave_down() 

  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto octave_down_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto octave_down_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto octave_down_end
  end
  
  item = reaper.GetSelectedMediaItem(0, 0)
  -- Get the active take
  take = reaper.GetActiveTake(item)
  
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
  _, notecnt = reaper.MIDI_CountEvts( take )
  
  for i = 0, notecnt do -- deselect all notes first
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
  end  
  --if reaper.TakeIsMIDI(take) then
  
  ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
  ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
  
  for i = 0, notecnt do -- set notes selected starting in time selection
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
      reaper.MIDI_SetNote( take, i, true, muted, startppqpos, endppqpos, chan, pitch, vel, true )
      
    end
    
  end
  
   reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40180 ) --Edit: Move notes down one octave    
--[[  
  --reaper.MB( "Continue", "Continue", 1 )
  _, notecnt = reaper.MIDI_CountEvts( take )
  --Msg("notecnt "..notecnt)
  --if not notecnt then
  --  next_region()
  --    end  
    count = 0
    sel_count = 0
    low_pitch = 0
    hi_pitch =127
    last_pitch = 0
    first_note_index = 0
    
    sel_notes = {}
    for i = 0, notecnt -1 do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
      if selected then
        --Msg("Note "..i .." "..pitch)
        if pitch < ks_start or pitch > ks_end then
          reaper.MIDI_SetNote( take, i  , true, muted, startppqpos, endppqpos, chan, pitch-12, vel, true ) 
          --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
          _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i )
          --Msg("Changed Note "..i .. " "..current_pitch)
        end
      end
    end
--]]    
    
    reaper.MIDI_Sort(take)
    reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
    ::octave_down_end::
end

function btn_click_snap_scale()
  commandID1 = reaper.NamedCommandLookup("_RSd79947ade28b889b51fcdaa202bb2bd1ebb36052")
  reaper.Main_OnCommand(commandID1, 0) -- Script: mpl_Snap takes to scale.lua
end

function btn_click_set_bass_root()

  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto set_bass_root_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto set_bass_root_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto set_bass_root_end
  end
  
  remove_current_marker()
  bass_root_marker = GUI.Val("bass_marker_choice")
  --Msg("bass_root_marker "..bass_root_marker)
  item = reaper.GetSelectedMediaItem(0, 0)
  -- Get the active take
  take = reaper.GetActiveTake(item)
  reaper.MIDI_Sort(take)
  MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
  start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
  ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
  reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, bass_root_table[bass_root_marker] ) -- Text Event Type 6 Insert Midi Marker    
  
  reaper.MIDI_Sort(take)
  
  ::set_bass_root_end::

end

function btn_click_chord_semi_up()

  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto chord_semi_up_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto chord_semi_up_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto chord_semi_up_end
  end
  
  get_marker()
  
  if not found_marker then
  
    goto chord_semi_up_end
  end
  
  remove_current_marker()
  

  --chord, p = nil, 0
  root, chord_type = string.match(found_marker, "(%w[#b]?)(.*)$")
  switches = string.match( found_marker, "-%a.*")
  --if not chord or #chord == 0 then chord = "" end
  if found_marker == "" then root = "" chord = "" i=i +1 end
  
  if string.find(found_marker, "-%a.*")  == 1 then root = "" chord = "" end  
  
  var = chord_type
    
  transpose = "+1" -- set to transpose 1 semitone
  
   
  
   if ("" == root and (transpose == "+1" or transpose == "-11")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "C#"..var 
   elseif ("C#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "D"..var
   elseif ("Db" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "D"..var
   elseif ("D" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "D#"..var
   elseif ("D#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "E"..var
   elseif ("Eb" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "E"..var
   elseif ("E" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "F"..var
   elseif ("F" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "F#"..var
   elseif ("F#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "G"..var
   elseif ("Gb" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "G"..var
   elseif ("G" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "G#"..var
   elseif ("G#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "A"..var
   elseif ("Ab" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "A"..var
   elseif ("A" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "A#"..var
   elseif ("A#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "B"..var
   elseif ("Bb" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "B"..var
   elseif ("B" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "C"..var
   
   elseif ("" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "D"..var
   elseif ("C#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "D#"..var
   elseif ("Db" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Eb"..var
   elseif ("D" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "E"..var
   elseif ("D#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "F"..var
   elseif ("Eb" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "F"..var
   elseif ("E" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "F#"..var
   elseif ("F" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "G"..var
   elseif ("F#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "G#"..var
   elseif ("Gb" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Ab"..var
   elseif ("G" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "A"..var
   elseif ("G#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "A#"..var
   elseif ("Ab" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Bb"..var
   elseif ("A" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "B"..var
   elseif ("A#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "C"..var
   elseif ("Bb" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Db"..var
   elseif ("B" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "C#"..var
   
   elseif ("" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "D#"..var
   elseif ("C#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "E"..var
   elseif ("Db" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "E"..var
   elseif ("D" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "F"..var
   elseif ("D#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "F#"..var
   elseif ("Eb" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "Gb"..var
   elseif ("E" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "G"..var
   elseif ("F" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "G#"..var
   elseif ("F#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "A"..var
   elseif ("Gb" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "A"..var
   elseif ("G" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "A#"..var
   elseif ("G#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "B"..var
   elseif ("Ab" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "B"..var
   elseif ("A" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "C"..var
   elseif ("A#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "C#"..var
   elseif ("Bb" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "Db"..var
   elseif ("B" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "D"..var
   
   elseif ("" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "E"..var
   elseif ("C#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "F"..var
   elseif ("Db" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "F"..var
   elseif ("D" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "F#"..var
   elseif ("D#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "G"..var
   elseif ("Eb" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "G"..var
   elseif ("E" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "G#"..var
   elseif ("F" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "A"..var
   elseif ("F#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "A#"..var
   elseif ("Gb" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "Bb"..var
   elseif ("G" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "B"..var
   elseif ("G#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "C"..var
   elseif ("Ab" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "C"..var
   elseif ("A" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "C#"..var
   elseif ("A#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "D"..var
   elseif ("Bb" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "D"..var
   elseif ("B" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "D#"..var
   
   elseif ("" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "F"..var
   elseif ("C#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "F#"..var
   elseif ("Db" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "Gb"..var
   elseif ("D" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "G"..var
   elseif ("D#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "G#"..var
   elseif ("Eb" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "Ab"..var
   elseif ("E" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "A"..var
   elseif ("F" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "A#"..var
   elseif ("F#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "B"..var
   elseif ("Gb" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "B"..var
   elseif ("G" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "C"..var
   elseif ("G#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "C#"..var
   elseif ("Ab" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "C#"..var
   elseif ("A" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "D"..var
   elseif ("A#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "D#"..var
   elseif ("Bb" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "Eb"..var
   elseif ("B" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "E"..var
   
   elseif ("" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "F#"..var
   elseif ("C#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "G"..var
   elseif ("Db" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "G"..var
   elseif ("D" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "G#"..var
   elseif ("D#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "A"..var
   elseif ("Eb" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "A"..var
   elseif ("E" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "A#"..var
   elseif ("F" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "B"..var
   elseif ("F#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "C"..var
   elseif ("Gb" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "C"..var
   elseif ("G" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "C#"..var
   elseif ("G#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "D"..var
   elseif ("Ab" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "D"..var
   elseif ("A" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "D#"..var
   elseif ("A#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "E"..var
   elseif ("Bb" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "E"..var
   elseif ("B" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "F"..var
   
   elseif ("" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "G"..var
   elseif ("C#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "G#"..var
   elseif ("Db" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "Ab"..var
   elseif ("D" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "A"..var
   elseif ("D#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "A#"..var
   elseif ("Eb" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "Bb"..var
   elseif ("E" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "B"..var
   elseif ("F" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "C"..var
   elseif ("F#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "C#"..var
   elseif ("Gb" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "Db"..var
   elseif ("G" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "D"..var
   elseif ("G#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "D#"..var
   elseif ("Ab" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "D#"..var
   elseif ("A" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "E"..var
   elseif ("A#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "F"..var
   elseif ("Bb" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "F"..var
   elseif ("B" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "F#"..var
   
   elseif ("" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "G#"..var
   elseif ("C#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "A"..var
   elseif ("Db" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "A"..var
   elseif ("D" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "A#"..var
   elseif ("D#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "B"..var
   elseif ("Eb" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "B"..var
   elseif ("E" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "C"..var
   elseif ("F" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "C#"..var
   elseif ("F#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "D"..var
   elseif ("Gb" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "D"..var
   elseif ("G" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "D#"..var
   elseif ("G#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "E"..var
   elseif ("Ab" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "E"..var
   elseif ("A" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "F"..var
   elseif ("A#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "F#"..var
   elseif ("Bb" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "Gb"..var
   elseif ("B" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "G"..var
   
   elseif ("" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "A"..var
   elseif ("C#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "A#"..var
   elseif ("Db" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "Bb"..var
   elseif ("D" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "B"..var
   elseif ("D#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "C"..var
   elseif ("Eb" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "C"..var
   elseif ("E" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "C#"..var
   elseif ("F" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "D"..var
   elseif ("F#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "D#"..var
   elseif ("Gb" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "Eb"..var
   elseif ("G" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "E"..var
   elseif ("G#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "F"..var
   elseif ("Ab" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "F"..var
   elseif ("A" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "F#"..var
   elseif ("A#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "G"..var
   elseif ("Bb" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "G"..var
   elseif ("B" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "G#"..var
   
   elseif ("" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "A#"..var
   elseif ("C#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "B"..var
   elseif ("Db" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "B"..var
   elseif ("D" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "C"..var
   elseif ("D#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "C#"..var
   elseif ("Eb" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "Db"..var
   elseif ("E" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "D"..var
   elseif ("F" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "D#"..var
   elseif ("F#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "E"..var
   elseif ("Gb" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "E"..var
   elseif ("G" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "F"..var
   elseif ("G#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "F#"..var
   elseif ("Ab" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "Gb"..var
   elseif ("A" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "G"..var
   elseif ("A#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "G#"..var
   elseif ("Bb" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "Ab"..var
   elseif ("B" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "A"..var
   
   elseif ("" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "B"..var
   elseif ("C#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "C"..var
   elseif ("Db" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "C"..var
   elseif ("D" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "C#"..var
   elseif ("D#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "D"..var
   elseif ("Eb" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "D"..var
   elseif ("E" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "D#"..var
   elseif ("F" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "E"..var
   elseif ("F#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "F"..var
   elseif ("Gb" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "F"..var
   elseif ("G" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "F#"..var
   elseif ("G#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "G"..var
   elseif ("Ab" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "G"..var
   elseif ("A" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "G#"..var
   elseif ("A#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "A"..var
   elseif ("Bb" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "A"..var
   elseif ("B" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "A#"..var
    
   
   end
   
   if keyswitch_opt == "Yes" then
     keyswitch_notes()
   else   
     ks_start = -1
     ks_end = -1
   end
    
   --reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   item = reaper.GetSelectedMediaItem(0, 0)
   -- Get the active take
   take = reaper.GetActiveTake(item)
   reaper.MIDI_Sort(take)
   MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
   start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
   ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
   reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, new_region_name ) -- Text Event Type 6 Insert Midi Marker    
    
   _, notecnt = reaper.MIDI_CountEvts( take )
   
   for i = 0, notecnt do -- deselect all notes first
   
     retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
     
     reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
   end  
   --if reaper.TakeIsMIDI(take) then
   
   ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
   ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
   
   for i = 0, notecnt do -- set notes selected starting in time selection
   
     retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
     
     if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
       reaper.MIDI_SetNote( take, i, true, muted, startppqpos, endppqpos, chan, pitch, vel, true )
       
     end
     
   end
   
   
   reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40177 ) --Edit: Move notes up one semitone   
   --[[
   _, notecnt = reaper.MIDI_CountEvts( take )
   --Msg("notecnt "..notecnt)
   --if not notecnt then
   --  next_region()
   --    end  
     count = 0
     sel_count = 0
     low_pitch = 0
     hi_pitch =127
     last_pitch = 0
     first_note_index = 0
     
     sel_notes = {}
     for i = 0, notecnt -1 do
       _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
       if selected then
         if pitch < ks_start or pitch > ks_end then
           --Msg("Note "..i .." "..pitch)
           reaper.MIDI_SetNote( take, i  , true, muted, startppqpos, endppqpos, chan, pitch+1, vel, true )
           
           --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
           _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i )
           --Msg("Changed Note "..i .. " "..current_pitch) 
         end
       end
     end
--]]     
     reaper.MIDI_Sort(take)   
     reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
   
   ::chord_semi_up_end::
end

function btn_click_chord_semi_down()

  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto chord_semi_down_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto chord_semi_down_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto chord_semi_down_end
  end
  
  get_marker()
  
  --Msg("found_marker "..found_marker)
  
  if not found_marker then
  
    goto chord_semi_down_end
  end
  
  

  --chord, p = nil, 0
  root, chord_type = string.match(found_marker, "(%w[#b]?)(.*)$")
  switches = string.match( found_marker, "-%a.*")
  --if not chord or #chord == 0 then chord = "" end
  if found_marker == "" then root = "" chord = "" i=i -1 end
  
  if string.find(found_marker, "-%a.*")  == 1 then root = "" chord = "" end  
  
  --Msg("Root "..root)
  --Msg("chord "..chord)
  
  var = chord_type
  transpose = "-1" -- set to transpose 1 semitone
  
   if ("" == root and (transpose == "+1" or transpose == "-11")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "C#"..var 
   elseif ("C#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "D"..var
   elseif ("Db" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "D"..var
   elseif ("D" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "D#"..var
   elseif ("D#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "E"..var
   elseif ("Eb" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "E"..var
   elseif ("E" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "F"..var
   elseif ("F" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "F#"..var
   elseif ("F#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "G"..var
   elseif ("Gb" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "G"..var
   elseif ("G" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "G#"..var
   elseif ("G#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "A"..var
   elseif ("Ab" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "A"..var
   elseif ("A" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "A#"..var
   elseif ("A#" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "B"..var
   elseif ("Bb" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "B"..var
   elseif ("B" == root and (transpose == "+1"  or transpose == "-11")) then new_region_name = "C"..var
   
   elseif ("" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "D"..var
   elseif ("C#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "D#"..var
   elseif ("Db" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Eb"..var
   elseif ("D" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "E"..var
   elseif ("D#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "F"..var
   elseif ("Eb" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "F"..var
   elseif ("E" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "F#"..var
   elseif ("F" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "G"..var
   elseif ("F#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "G#"..var
   elseif ("Gb" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Ab"..var
   elseif ("G" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "A"..var
   elseif ("G#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "A#"..var
   elseif ("Ab" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Bb"..var
   elseif ("A" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "B"..var
   elseif ("A#" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "C"..var
   elseif ("Bb" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "Db"..var
   elseif ("B" == root and (transpose == "+2"  or transpose == "-10")) then new_region_name = "C#"..var
   
   elseif ("" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "D#"..var
   elseif ("C#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "E"..var
   elseif ("Db" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "E"..var
   elseif ("D" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "F"..var
   elseif ("D#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "F#"..var
   elseif ("Eb" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "Gb"..var
   elseif ("E" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "G"..var
   elseif ("F" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "G#"..var
   elseif ("F#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "A"..var
   elseif ("Gb" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "A"..var
   elseif ("G" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "A#"..var
   elseif ("G#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "B"..var
   elseif ("Ab" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "B"..var
   elseif ("A" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "C"..var
   elseif ("A#" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "C#"..var
   elseif ("Bb" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "Db"..var
   elseif ("B" == root and (transpose == "+3"  or transpose == "-9")) then new_region_name = "D"..var
   
   elseif ("" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "E"..var
   elseif ("C#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "F"..var
   elseif ("Db" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "F"..var
   elseif ("D" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "F#"..var
   elseif ("D#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "G"..var
   elseif ("Eb" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "G"..var
   elseif ("E" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "G#"..var
   elseif ("F" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "A"..var
   elseif ("F#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "A#"..var
   elseif ("Gb" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "Bb"..var
   elseif ("G" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "B"..var
   elseif ("G#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "C"..var
   elseif ("Ab" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "C"..var
   elseif ("A" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "C#"..var
   elseif ("A#" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "D"..var
   elseif ("Bb" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "D"..var
   elseif ("B" == root and (transpose == "+4"  or transpose == "-8")) then new_region_name = "D#"..var
   
   elseif ("" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "F"..var
   elseif ("C#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "F#"..var
   elseif ("Db" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "Gb"..var
   elseif ("D" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "G"..var
   elseif ("D#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "G#"..var
   elseif ("Eb" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "Ab"..var
   elseif ("E" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "A"..var
   elseif ("F" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "A#"..var
   elseif ("F#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "B"..var
   elseif ("Gb" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "B"..var
   elseif ("G" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "C"..var
   elseif ("G#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "C#"..var
   elseif ("Ab" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "C#"..var
   elseif ("A" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "D"..var
   elseif ("A#" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "D#"..var
   elseif ("Bb" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "Eb"..var
   elseif ("B" == root and (transpose == "+5"  or transpose == "-7")) then new_region_name = "E"..var
   
   elseif ("" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "F#"..var
   elseif ("C#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "G"..var
   elseif ("Db" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "G"..var
   elseif ("D" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "G#"..var
   elseif ("D#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "A"..var
   elseif ("Eb" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "A"..var
   elseif ("E" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "A#"..var
   elseif ("F" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "B"..var
   elseif ("F#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "C"..var
   elseif ("Gb" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "C"..var
   elseif ("G" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "C#"..var
   elseif ("G#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "D"..var
   elseif ("Ab" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "D"..var
   elseif ("A" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "D#"..var
   elseif ("A#" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "E"..var
   elseif ("Bb" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "E"..var
   elseif ("B" == root and (transpose == "+6"  or transpose == "-6")) then new_region_name = "F"..var
   
   elseif ("" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "G"..var
   elseif ("C#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "G#"..var
   elseif ("Db" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "Ab"..var
   elseif ("D" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "A"..var
   elseif ("D#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "A#"..var
   elseif ("Eb" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "Bb"..var
   elseif ("E" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "B"..var
   elseif ("F" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "C"..var
   elseif ("F#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "C#"..var
   elseif ("Gb" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "Db"..var
   elseif ("G" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "D"..var
   elseif ("G#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "D#"..var
   elseif ("Ab" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "D#"..var
   elseif ("A" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "E"..var
   elseif ("A#" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "F"..var
   elseif ("Bb" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "F"..var
   elseif ("B" == root and (transpose == "+7"  or transpose == "-5")) then new_region_name = "F#"..var
   
   elseif ("" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "G#"..var
   elseif ("C#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "A"..var
   elseif ("Db" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "A"..var
   elseif ("D" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "A#"..var
   elseif ("D#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "B"..var
   elseif ("Eb" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "B"..var
   elseif ("E" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "C"..var
   elseif ("F" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "C#"..var
   elseif ("F#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "D"..var
   elseif ("Gb" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "D"..var
   elseif ("G" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "D#"..var
   elseif ("G#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "E"..var
   elseif ("Ab" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "E"..var
   elseif ("A" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "F"..var
   elseif ("A#" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "F#"..var
   elseif ("Bb" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "Gb"..var
   elseif ("B" == root and (transpose == "+8"  or transpose == "-4")) then new_region_name = "G"..var
   
   elseif ("" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "A"..var
   elseif ("C#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "A#"..var
   elseif ("Db" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "Bb"..var
   elseif ("D" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "B"..var
   elseif ("D#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "C"..var
   elseif ("Eb" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "C"..var
   elseif ("E" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "C#"..var
   elseif ("F" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "D"..var
   elseif ("F#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "D#"..var
   elseif ("Gb" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "Eb"..var
   elseif ("G" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "E"..var
   elseif ("G#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "F"..var
   elseif ("Ab" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "F"..var
   elseif ("A" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "F#"..var
   elseif ("A#" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "G"..var
   elseif ("Bb" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "G"..var
   elseif ("B" == root and (transpose == "+9"  or transpose == "-3")) then new_region_name = "G#"..var
   
   elseif ("" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "A#"..var
   elseif ("C#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "B"..var
   elseif ("Db" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "B"..var
   elseif ("D" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "C"..var
   elseif ("D#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "C#"..var
   elseif ("Eb" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "Db"..var
   elseif ("E" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "D"..var
   elseif ("F" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "D#"..var
   elseif ("F#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "E"..var
   elseif ("Gb" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "E"..var
   elseif ("G" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "F"..var
   elseif ("G#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "F#"..var
   elseif ("Ab" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "Gb"..var
   elseif ("A" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "G"..var
   elseif ("A#" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "G#"..var
   elseif ("Bb" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "Ab"..var
   elseif ("B" == root and (transpose == "+10"  or transpose == "-2")) then new_region_name = "A"..var
   
   elseif ("" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = region_name
   elseif ("C" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "B"..var
   elseif ("C#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "C"..var
   elseif ("Db" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "C"..var
   elseif ("D" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "C#"..var
   elseif ("D#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "D"..var
   elseif ("Eb" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "D"..var
   elseif ("E" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "D#"..var
   elseif ("F" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "E"..var
   elseif ("F#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "F"..var
   elseif ("Gb" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "F"..var
   elseif ("G" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "F#"..var
   elseif ("G#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "G"..var
   elseif ("Ab" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "G"..var
   elseif ("A" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "G#"..var
   elseif ("A#" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "A"..var
   elseif ("Bb" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "A"..var
   elseif ("B" == root and (transpose == "+11"  or transpose == "-1")) then new_region_name = "A#"..var
    
   
   end
   
   --Msg("new_region_name "..new_region_name)
   --Msg("var "..var)
   
   if keyswitch_opt == "Yes" then
     keyswitch_notes()
   else   
     ks_start = -1
     ks_end = -1
   end
   
   remove_current_marker()
   
    
   --reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   item = reaper.GetSelectedMediaItem(0, 0)
   -- Get the active take
   take = reaper.GetActiveTake(item)
   reaper.MIDI_Sort(take)
   MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
   start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
   ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
   reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, new_region_name ) -- Text Event Type 6 Insert Midi Marker    
    
   _, notecnt = reaper.MIDI_CountEvts( take )
   
   for i = 0, notecnt do -- deselect all notes first
   
     retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
     
     reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
   end  
   --if reaper.TakeIsMIDI(take) then
   
   ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
   ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
   
   for i = 0, notecnt do -- set notes selected starting in time selection
   
     retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
     
     if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
       reaper.MIDI_SetNote( take, i, true, muted, startppqpos, endppqpos, chan, pitch, vel, true )
       
     end
     
   end

   reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40178 ) --Edit: Move notes down one semitone  
   
   --[[
   _, notecnt = reaper.MIDI_CountEvts( take )
   --Msg("notecnt "..notecnt)
   --if not notecnt then
   --  next_region()
   --    end  
     count = 0
     sel_count = 0
     low_pitch = 0
     hi_pitch =127
     last_pitch = 0
     first_note_index = 0
     
     sel_notes = {}
     for i = 0, notecnt -1 do
       _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
       if selected then
         if pitch < ks_start or pitch > ks_end then
           --Msg("Note "..i .." "..pitch)
           reaper.MIDI_SetNote( take, i  , true, muted, startppqpos, endppqpos, chan, pitch-1, vel, true )
           
           --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
           _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i )
           --Msg("Changed Note "..i .. " "..current_pitch) 
         end
       end
     end
--]]     
     reaper.MIDI_Sort(take)   
     reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
   
   ::chord_semi_down_end::
end

function btn_click_bass_semi_up()
  --get curent marker
  --write new marker
  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto bass_semi_up_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto bass_semi_up_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto bass_semi_up_end
  end
  
  if keyswitch_opt == "Yes" then
    keyswitch_notes()
  else   
    ks_start = -1
    ks_end = -1
  end  
  
  -- Get the active take
  take = reaper.GetActiveTake(item) 
  
  _, notecnt = reaper.MIDI_CountEvts( take )
  
  get_marker()
  
  current_bass_root = position_in_table(bass_root_table,found_marker)

  if current_bass_root == 12 then current_bass_root = 0 end
  target_bass_root = bass_root_table[current_bass_root+1]  
  
  remove_current_marker() 
   
  for i = 0, notecnt do -- deselect all notes first
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
  end  
  --if reaper.TakeIsMIDI(take) then
  
  sel_midi_notes = {}
  
  ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
  ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
  
  for i = 0, notecnt do -- set notes selected starting in time selection
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
      reaper.MIDI_SetNote( take, i, true, muted, startppqpos, endppqpos, chan, pitch, vel, true )
      
    end
    
  end
  
  for i = 1, tablelength(sel_midi_notes) do
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, sel_midi_notes[i] )
    reaper.MIDI_SetNote( take, sel_midi_notes[i], true, muted, startppqpos, endppqpos, chan, pitch, vel, true )  
  
  end
  
   reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40177 ) --Edit: Move notes up one semitone 
   
--[[  
  --reaper.MB( "Continue", "Continue", 1 )
  _, notecnt = reaper.MIDI_CountEvts( take )
  --Msg("notecnt "..notecnt)
  --if not notecnt then
  --  next_region()
  --    end  
    count = 0
    sel_count = 0
    low_pitch = 0
    hi_pitch =127
    last_pitch = 0
    first_note_index = 0
    
    sel_notes = {}
    for i = 0, notecnt -1 do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
      if selected then
        if pitch < ks_start or pitch > ks_end then
          --Msg("Note "..i .." "..pitch)
          reaper.MIDI_SetNote( take, i  , true, muted, startppqpos, endppqpos, chan, pitch+1, vel, true )
          
          --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
          _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i )
          --Msg("Changed Note "..i .. " "..current_pitch) 
        end
      end
    end 
    
    item = reaper.GetSelectedMediaItem(0, 0)
    -- Get the active take
    take = reaper.GetActiveTake(item)
    reaper.MIDI_Sort(take)
    MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
    start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
    ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
    reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, target_bass_root ) -- Text Event Type 6 Insert Midi Marker    
--]]    
    reaper.MIDI_Sort(take)
    reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
    ::bass_semi_up_end::
   
end

function btn_click_bass_semi_down()

  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto bass_semi_down_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto bass_semi_down_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto bass_semi_down_end
  end
  
  if keyswitch_opt == "Yes" then
    keyswitch_notes()
  else   
    ks_start = -1
    ks_end = -1
  end  
  
  -- Get the active take
  take = reaper.GetActiveTake(item) 
  
  _, notecnt = reaper.MIDI_CountEvts( take )
  
  get_marker()
  
  current_bass_root = position_in_table(bass_root_table,found_marker)

  if current_bass_root == 12 then current_bass_root = 0 end
  target_bass_root = bass_root_table[current_bass_root-1]  
  
  remove_current_marker() 
  
   
  for i = 0, notecnt do -- deselect all notes first
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    reaper.MIDI_SetNote( take, i, false, muted, startppqposIn, endppqpos, chan, pitch, vel, true )
  end  
  --if reaper.TakeIsMIDI(take) then
  
  sel_midi_notes = {}
  
  ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
  ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_time1 )  
  
  for i = 0, notecnt do -- set notes selected starting in time selection
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
    
    if startppqpos > ppq_start -5 and startppqpos < ppq_end -5 then
      reaper.MIDI_SetNote( take, i, true, muted, startppqpos, endppqpos, chan, pitch, vel, true )
      
    end
    
  end
  
  for i = 1, tablelength(sel_midi_notes) do
  
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, sel_midi_notes[i] )
    reaper.MIDI_SetNote( take, sel_midi_notes[i], true, muted, startppqpos, endppqpos, chan, pitch, vel, true )  
  
  end
  
   reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
   --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
   reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40178 ) --Edit: Move notes down one semitone  
--[[  
  --reaper.MB( "Continue", "Continue", 1 )
  _, notecnt = reaper.MIDI_CountEvts( take )
  --Msg("notecnt "..notecnt)
  --if not notecnt then
  --  next_region()
  --    end  
    count = 0
    sel_count = 0
    low_pitch = 0
    hi_pitch =127
    last_pitch = 0
    first_note_index = 0
    
    sel_notes = {}
    for i = 0, notecnt -1 do
      _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
      if selected then
        if pitch < ks_start or pitch > ks_end then
          --Msg("Note "..i .." "..pitch)
          reaper.MIDI_SetNote( take, i  , true, muted, startppqpos, endppqpos, chan, pitch-1, vel, true )
          
          --reaper.MIDI_SetNote( take, i-1, true, muted, startppqpos, endppqpos, chan, new_pitch, vel, true )
          _, selected, muted, startppqpos, endppqpos, chan, current_pitch, vel = reaper.MIDI_GetNote( take, i )
          --Msg("Changed Note "..i .. " "..current_pitch) 
        end
      end
    end 
    
    item = reaper.GetSelectedMediaItem(0, 0)
    -- Get the active take
    take = reaper.GetActiveTake(item)
    reaper.MIDI_Sort(take)
    MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
    start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
    ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
    reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, target_bass_root ) -- Text Event Type 6 Insert Midi Marker    
--]]    
    reaper.MIDI_Sort(take)
    reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) --File: Close window
    ::bass_semi_down_end::
end

function btn_click_set_chord_name()

   item = reaper.GetSelectedMediaItem(0, 0)
   
   if not item then
     reaper.MB( "Select an item", "Notice", 0 )
     goto set_chord_name_end
   end   
   
   start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
   
    
   item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
   item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
   item_end = item_pos + item_length
   
   
   
   if start_time1 == end_time1 then
     reaper.MB( "Set Time Select within item", "Notice", 0 )
     goto set_chord_name_end
   end
   
   if start_time1 < item_pos or start_time1 > item_end then
     reaper.MB( "Set Time Select within item", "Notice", 0 )
     goto set_chord_name_end
   end
   
   retval, new_chord_name = reaper.GetUserInputs( "Chord Name Marker", 1, "Enter Chord Name", "" )
   
   if not retval then
     goto set_chord_name_end
   end
   
   item = reaper.GetSelectedMediaItem(0, 0)
   -- Get the active take
   take = reaper.GetActiveTake(item)
   reaper.MIDI_Sort(take)
   MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
   start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
   ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
   reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, new_chord_name ) -- Text Event Type 6 Insert Midi Marker    
   
   reaper.MIDI_Sort(take)
   
   ::set_chord_name_end::

end

function browse_folder()

  retval, folder = reaper.JS_Dialog_BrowseForFolder( "Browse for folder", path  )
  path = folder
  reaper.BR_Win32_WritePrivateProfileString( "reaper", "reatrak_midi_folder", path, inipath )
  btn_click_refresh()
  
end

retval_folder, path = reaper.BR_Win32_GetPrivateProfileString("reaper", "reatrak_midi_folder", "", inipath)

if retval_folder == 0 then
  path = script_path .. "wv_player\\midi"
end

local function GetFiles(path)
  local tree = {}
  local subDirIndex, fileIndex = 0, 0
  local pathChild

  if path ~= nil then 
    repeat
      pathChild = reaper.EnumerateSubdirectories(path, subDirIndex)
        if pathChild then
          local tmpPath = GetFiles(path .. GetPathSeparator() .. pathChild)
            for i = 1, #tmpPath do
              tree[#tree + 1] = tmpPath[i]
            end
        end
        subDirIndex = subDirIndex + 1
    until not pathChild

    repeat
      local fileFound = reaper.EnumerateFiles(path, fileIndex)
        if fileFound then
          tree[#tree + 1] = path .. GetPathSeparator() .. fileFound
        end
        fileIndex = fileIndex + 1
    until not fileFound
  end
  return tree
end


function filename_table()
  
  --Msg("Table Length "..tablelength(midi_path_files))
  midi_path_files = GetFiles(path)
  midi_path_files2 = {}
  for i = 1, tablelength(midi_path_files) do
    filetxt = ([["]]..midi_path_files[i]..[["]])
    --Msg(filetxt)
    --dir1 = string.gsub(filetxt, "\\[^\\]*$", "")
    --dir = dir1 .. GetPathSeparator()
    txt_filename1 = string.match(filetxt, "\\[^\\]*$")
    txt_filename = string.gsub(txt_filename1, "\\", "")
    txt_filename = string.gsub(txt_filename, "\\", "")
    txt_filename = string.gsub(txt_filename, "\"", "")
    table.insert(midi_path_files2,txt_filename)
    
  end  
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      Msg(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      Msg(formatting .. tostring(v))      
    else
      Msg(formatting .. v)
    end
  end
end

function btn_click_refresh()
  
  GetFiles(path)
  GetPathSeparator()
  filename_table()
  --GUI.elms.file_list:init()
  --GUI.elms.file_list2:init()
  
  GUI.elms.file_list.list = midi_path_files
  GUI.elms.file_list:redraw()
  
  GUI.elms.file_list2.list = midi_path_files2
  GUI.elms.file_list2:redraw()
  
  --[[
  GUI.elms.file_list:ondelete()
  GUI.New("file_list", "Listbox",  5,  150,  40,  600, 608, midi_path_files2, false, "Files")
  GUI.elms.file_list:init()
  
  GUI.elms.file_list2:ondelete()
  GUI.New("file_list2", "Listbox",  3,  150,  300,  600, 408, midi_path_files2, false, "Files")
  GUI.elms.file_list2:init()
  --]]

--[[ 
  GUI.elms.my_frm6:ondelete()
  GUI.New("my_frm6",      "Frame",           3, 190+x6, 960+y6, 590, 35, true, true, "elm_bg", 4)
  GUI.elms.my_frm6.text = "midifile_path2"
  GUI.elms.my_frm6.col_txt = "white"
  GUI.elms.my_frm6:init()
  
  GUI.elms.my_frm4:ondelete()
  GUI.New("my_frm4",      "Frame",           5, 190+x6, 900+y6, 590, 35, true, true, "elm_bg", 4)
  GUI.elms.my_frm4.text = "midifile_path"
  GUI.elms.my_frm4.col_txt = "white"
  GUI.elms.my_frm4:init()
--]]  
  
  
  function GUI.elms.file_list:onmouseup()
      GUI.Listbox.onmouseup(self)
      listbox_val = GUI.Val("file_list")
      midifile_path = midi_path_files[listbox_val]
  
      --reaper.ShowConsoleMsg("Current index: " .. midi_path_files[listbox_val] .."\n")
      GUI.elms.my_frm4:ondelete()
      GUI.New("my_frm4",      "Frame",           5, 190+x6, 900+y6, 590, 35, true, true, "elm_bg", 4)
      GUI.elms.my_frm4.text = midi_path_files[listbox_val] 
      GUI.elms.my_frm4.col_txt = "white"
      GUI.elms.my_frm4:init()
      
  end
  
  function GUI.elms.file_list2:onmouseup()
      GUI.Listbox.onmouseup(self)
      listbox_val2 = GUI.Val("file_list2")
      midifile_path2 = midi_path_files[listbox_val2]
  
      --reaper.ShowConsoleMsg("Current index: " .. midifile_path2 .."\n")
      GUI.elms.my_frm6:ondelete()
      GUI.New("my_frm6",      "Frame",           3, 190+x6, 960+y6, 590, 35, true, true, "elm_bg", 4)
      GUI.elms.my_frm6.text = midi_path_files[listbox_val2] --" Choose the Root of the Chord then the Chord type or add the Root Note for / Slash Chords"
      GUI.elms.my_frm6.col_txt = "white"
      GUI.elms.my_frm6:init()    
  end 
 
  --view_opt = GUI.elms.view_opt.optarray[ GUI.Val("view_opt") ]
  --if view_opt == "Filename" then btn_click_file() end
  --if view_opt == "Pathname" then btn_click_path() end
end

function show_midi_markers()

  reaper.Main_OnCommand(40691, 0) --View: Toggle show media cues in items

end

GetFiles(path)
GetPathSeparator()
filename_table()





local function fade_lbl()
   
   -- Fade out the label
    if GUI.elms.my_lbl.z == 3 then
        GUI.elms.my_lbl:fade(1, 3, 6)
        
    -- Bring it back
    else
        GUI.elms.my_lbl:fade(1, 3, 6, -3)
    end
    
end

--[[
local function btn_click()
  
    -- Open the Window element
  GUI.elms.wnd_test:open()
  
end
--]]

local function wnd_OK()

    -- Close the Window element
    GUI.elms.wnd_test:close()
    
end

function btn_click_show_path()

  Msg("Midi Path= ".. midifile_path)

end




function btn_click_insert_file()
  --midifile_path2 = midi_path_files[listbox_val2]
  media_pos_start =  reaper.GetCursorPosition()
  reaper.InsertMedia( midifile_path2, 0 )
  media_pos_end =  reaper.GetCursorPosition()
  pos_start, pos_end = reaper.GetSet_LoopTimeRange2( 0, true, false, media_pos_start, media_pos_end, 0 )
end

function btn_click_play_file()

  --GUI.file_list.onmouseup(self)
      --listbox_val = GUI.Val("file_list")
  --listbox_val = GUI.Val("file_list")
  --Msg("Source "..midi_path_files[listbox_val])
  --file_source = midi_path_files[listbox_val]
  if reaper.file_exists( "C:\\Program Files\\MPC-HC\\mpc-hc64.exe" ) then
    
    if midifile_path then
      reaper.ExecProcess([[cmd.exe /C " cd "C:\\Program Files\\MPC-HC\\" & "mpc-hc64.exe" "]].. midifile_path ..[[" /minimized"]],-2)
    end  
  else
    if midifile_path then 
      reaper.ExecProcess([[cmd.exe /C " cd ]] .. script_path .. [[wv_player/ & "wv_player.exe" /n:1 "]].. midifile_path ..[["]],-2)
    end
  end  
end

function btn_click_play_file2()

  --GUI.file_list.onmouseup(self)
      --listbox_val = GUI.Val("file_list")
  --listbox_val = GUI.Val("file_list")
  --Msg("Source "..midi_path_files[listbox_val])
  --file_source = midi_path_files[listbox_val]
  if reaper.file_exists( "C:\\Program Files\\MPC-HC\\mpc-hc64.exe" ) then
    
    if midifile_path2 then
      reaper.ExecProcess([[cmd.exe /C " cd "C:\\Program Files\\MPC-HC\\" & "mpc-hc64.exe" "]].. midifile_path2 ..[[" /minimized"]],-2)
    end  
  else
    if midifile_path2 then 
      reaper.ExecProcess([[cmd.exe /C " cd ]] .. script_path .. [[wv_player/ & "wv_player.exe" /n:1 "]].. midifile_path2 ..[["]],-2)
    end
  end  
  
  --if midifile_path2 then 
    --reaper.ExecProcess([[cmd.exe /C " cd ]] .. script_path .. [[wv_player/ & "wv_player.exe" /n:1 "]].. midifile_path2 ..[["]],-2)
  --end
  
end

function btn_click_stop()
  --app_path = script_path .. "/wv_player//stop.mid"
  --Msg("app_path "..app_path)
  if reaper.file_exists("C:\\Program Files\\MPC-HC\\mpc-hc64.exe" ) then
    reaper.ExecProcess([[taskkill /f /im mpc-hc64.exe]],-2)
  else
    reaper.ExecProcess([[taskkill /f /im wv_player.exe]],-2)
  end
  --reaper.ExecProcess([[cmd.exe /C " cd ]] .. script_path .. [[C:\> "runas /user:<localmachinename>\administrator cmd & wv_player/ & stop_wv_player_shortcut.bat"]],-2)
  --Msg("STOP")
  --reaper.ExecProcess([[cmd.exe /C " cd ]] .. script_path .. [[wv_player/ & "wv_player.exe" /n:1 "]] .. app_path ..[["]],-2)
  --reaper.ExecProcess([[cmd.exe /C " cd ]] .. script_path .. [[wv_player/ & "wv_player.exe" /n:1 "]].. midifile_path ..[["]],-2)
      
end

function get_marker()

  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
  item = reaper.GetSelectedMediaItem(0, 0)
  -- Get the active take
  take = reaper.GetActiveTake(item)
  -- Process the take IFF the take contains MIDI
  if reaper.TakeIsMIDI(take) then
    ppq_pos = reaper.MIDI_GetPPQPosFromProjTime( take, start_time1 )
    
    -- Get all the MIDI events for this take
    ok, buf = reaper.MIDI_GetAllEvts(take, "")
    -- Proceed only if there are MIDI events to pr+ocess
    if ok and buf:len() > 0 then
      --[[
      Since messages offsets are relative to the previous message,
      track the total offset, in order to know the position of the MIDI events
      --]]
      total_offset = 0
      pos = 1
      while pos <= buf:len() do
        offs, flag, msg = string.unpack("IBs4", buf, pos)
        total_offset = total_offset + offs  
        adv = 4 + 1 + 4 + msg:len()
        -- Determine if this event is a lyric message 5 or text 1
        --0x01 = Text
        --0x02 = Copyright
        --0x03 = Sequence/Track Name
        --0x04 = Instrument
        --0x05 = Lyric
        --0x06 = Marker
        --0x07 = Cue
        --0x08 = Program
        --0x09 = Device
        if msg:byte(1) == 255 and msg:byte(2) == 6 and ppq_pos == total_offset then --5 then --for lyrics -- 6 markers
          found_marker = msg:sub(3)
          --position = reaper.MIDI_GetProjTimeFromPPQPos(take, total_offset)
          -- Create the marker
          --reaper.AddProjectMarker(0, false, position, 0, lyric, -1)
          --Msg("Found Marker "..found_marker) 
        end
        pos = pos+adv
      end
    end
  end

end

function remove_markers()

  choice = reaper.MB( "Are You Sure ?", "Del Item Markers", 1 )
  if choice == 1 then  
--[[
Text Event Type:
1 = Text
2 = Copyright
3 = Sequence/Track Name
4 = Instrument
5 = Lyric
6 = Marker
7 = Cue
8 = Program
9 = Device 
--]]

     start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
     selitem = reaper.GetSelectedMediaItem( 0, 0 )
     take = reaper.GetActiveTake( selitem )
     ppq_pos = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
     retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
     
     for i = 0, textsyxevtcnt do
          
       retval, notecnt, ccevtcnt, textsyxevtcnt2 = reaper.MIDI_CountEvts( take )
       for t = 0,textsyxevtcnt2 do   
         retval, selected, muted, ppqpos, text_type, msg = reaper.MIDI_GetTextSysexEvt( take, i, false, false, 0, 0, "" )
         if text_type == 6 then --and ppq_pos == ppqpos then -- Text Event Type
           reaper.MIDI_DeleteTextSysexEvt( take, i )
         end
       end  
         
     end
     reaper.MIDI_Sort(take)   



   
  end     
     
end 

function remove_markers_selection()

  choice = reaper.MB( "Are You Sure ?", "Del Item Markers", 1 )
  if choice == 1 then  
--[[
Text Event Type:
1 = Text
2 = Copyright
3 = Sequence/Track Name
4 = Instrument
5 = Lyric
6 = Marker
7 = Cue
8 = Program
9 = Device 
--]]

     start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
     selitem = reaper.GetSelectedMediaItem( 0, 0 )
     take = reaper.GetActiveTake( selitem )
     ppq_pos = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
     retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
     
     ppq_start = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
     ppq_end = reaper.MIDI_GetPPQPosFromProjTime( take, end_sel )
     
     for i = 0, textsyxevtcnt do
          
       retval, notecnt, ccevtcnt, textsyxevtcnt2 = reaper.MIDI_CountEvts( take )
       for t = 0,textsyxevtcnt2 do   
         retval, selected, muted, ppqpos, text_type, msg = reaper.MIDI_GetTextSysexEvt( take, i, false, false, 0, 0, "" )
         if text_type == 6 and ppqpos > ppq_start-5 and ppqpos < ppq_end then --and ppq_pos == ppqpos then -- Text Event Type
           reaper.MIDI_DeleteTextSysexEvt( take, i )
         end
       end  
         
     end
     reaper.MIDI_Sort(take)   



   
  end     
     
end 

function remove_current_marker()

  start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
  selitem = reaper.GetSelectedMediaItem( 0, 0 )
  take = reaper.GetActiveTake( selitem )
  ppq_pos = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
  retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
  
  for i = 0, textsyxevtcnt do
       
    retval, notecnt, ccevtcnt, textsyxevtcnt2 = reaper.MIDI_CountEvts( take )
    for t = 0,textsyxevtcnt2 do   
      retval, selected, muted, ppqpos, text_type, msg = reaper.MIDI_GetTextSysexEvt( take, i, false, false, 0, 0, "" )
      if text_type == 6 and ppq_pos == ppqpos then -- Text Event Type
        reaper.MIDI_DeleteTextSysexEvt( take, i )
      end
    end  
      
  end
  reaper.MIDI_Sort(take)     

end

function write_markers(mark_name)
  --Msg("New Chord Name "..mark_name)
  item = reaper.GetSelectedMediaItem(0, 0)

  if not item then
    reaper.MB( "Select an item", "Notice", 0 )
    goto write_markers_end
  end   
  
  start_time1, end_time1 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
   
  item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
  item_length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
  item_end = item_pos + item_length
  
 
  
  if start_time1 == end_time1 then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto write_markers_end
  end
  
  if start_time1 < item_pos or start_time1 > item_end then
    reaper.MB( "Set Time Select within item", "Notice", 0 )
    goto write_markers_end
  end
  
  remove_current_marker()
  if keyswitch_opt == "Yes" then
    keyswitch_notes()
  else   
    ks_start = -1
    ks_end = -1
  end
   
  --reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
  --take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  item = reaper.GetSelectedMediaItem(0, 0)
  -- Get the active take
  take = reaper.GetActiveTake(item)
  reaper.MIDI_Sort(take)
  MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
  start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0 )
  ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
  reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, mark_name ) -- Text Event Type 6 Insert Midi Marker 
          
  --reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) -- File Close wimdow
  chord_name_notes(mark_name)
  chords_table()
  sel_note_table()
  
  ::write_markers_end::
  
end

function write_markers2()
  reaper.Main_OnCommand(40153,0) --Item: Open in built-in MIDI editor (set default behavior in preferences) 40153
  take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  reaper.MIDI_Sort(take)
  MIDIOK, MIDI = reaper.MIDI_GetAllEvts(take, "")
  start_sel, end_sel = reaper.GetSet_LoopTimeRange2( 0, false, false, start_sel, end_sel, 0 )
  ticks = reaper.MIDI_GetPPQPosFromProjTime( take, start_sel )
  reaper.MIDI_InsertTextSysexEvt( take, true, false, ticks, 6, chord ) -- Text Event Type 6 Insert Midi Marker 
          
  reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 2 ) -- File Close wimdow
end

-- Returns a list of every element on the specified z-layer and
-- a second list of each element's values
local function get_values_for_tab(tab_num)
    
  -- The '+ 2' here is just to translate from a tab number to its' 
  -- associated z layer. More complicated scripts would have to 
  -- actually access GUI.elms.tabs.z_sets[tab_num] and iterate over
  -- the table's contents (see the call to GUI.elms.tabs:update_sets
  -- below)
    local strs_v, strs_val = {}, {}
  for k, v in pairs(GUI.elms_list[tab_num + 2]) do
    
        strs_v[#strs_v + 1] = v
    local val = GUI.Val(v)
    if type(val) == "table" then
      local strs = {}
      for k, v in pairs(val) do
                local str = tostring(v) 
                
                -- For conciseness, reduce boolean values to T/F
        if str == "true" then
                    str = "T"
                elseif str == "false" then
                    str = "F"
                end
                strs[#strs + 1] = str
      end
      val = table.concat(strs, ", ")
    end
        
        -- Limit the length of the returned string so it doesn't
        -- spill out past the edge of the window
    strs_val[#strs_val + 1] = string.len(tostring(val)) <= 35
                                and tostring(val)
                                or  string.sub(val, 1, 32) .. "..."
    
  end
    
    return strs_v, strs_val
    
end




------------------------------------
-------- Window settings -----------
------------------------------------


GUI.name = "ReaTrak Snap Midi to Chords"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 915, 770 --915, 770
GUI.anchor, GUI.corner = "mouse", "C"



--[[  

  Button    z,   x,   y,   w,   h, caption, func[, ...]
  Checklist  z,   x,   y,   w,   h, caption, opts[, dir, pad]
  Frame    z,   x,   y,   w,   h[, shadow, fill, color, round]
  Knob    z,   x,   y,   w,   caption, min, max, default[, inc, vals]  
  Label    z,   x,   y,    caption[, shadow, font, color, bg]
  Menubox    z,   x,   y,   w,   h, caption, opts
  Radio    z,   x,   y,   w,   h, caption, opts[, dir, pad]
  Slider    z,   x,   y,   w,   caption, min, max, defaults[, inc, dir]
  Tabs    z,   x,   y,     tab_w, tab_h, opts[, pad]
  Textbox    z,   x,   y,   w,   h[, caption, pad]
    Window      z,  x,  y,  w,  h,  caption, z_set[, center]
  
]]--


-- Elements can be created in any order you want. I find it easiest to organize them
-- by tab, or by what part of the script they're involved in.




------------------------------------
-------- General elements ----------
------------------------------------

--Tabs

GUI.New("tabs",      "Tabs",           1, 0, 0, 25, 20, "Key Chords,All Chords", 60)
--GUI.New("tab_bg",     "Frame",          2, 0, 0, 600, 20, true, true, "elm_bg", 1)
GUI.elms.tabs.col_txt = "chorus_fill"

-- Telling the tabs which z layers to display
-- See Classes/Tabs.lua for more detail
GUI.elms.tabs:update_sets(
  --  Tab
  --               Layers
  {     [1] =     {3,6},
    [2] =     {2,4,7}, --Include layer 2,6 on Tab 2 Chord Root Radio and Insert Root Note Button
    [3] =     {2,5,6}, --Include layer 2 on Tab 3 Chord Root Radio and Insert Root Note Button
    [4] =     {6},
    [5] =     {7},
    [6] =     {8},
    [7] =     {9},
    [8] =     {10},
    [9] =     {11},
    [10] =     {12},
    [11] =     {13},
    [12] =     {14},
    [13] =     {15},
    [14] =     {16},
    [15] =     {17},
    [16] =     {18},
    [17] =     {19},
    [18] =     {20},
    [19] =     {21},
    [20] =     {22},
    
  }
)


--GUI.New("tabs",   "Tabs",     1, 0, 0, 64, 20, "Stuff", 16)
GUI.New("tab_bg",  "Frame",    2, 0, 0, 448, 20, false, true, "elm_bg", 0)
--GUI.New("my_btn",   "Button",     1, 168, 28, 96, 20, "Go!", btn_click)
--GUI.New("btn_frm",  "Frame",    1, 0, 56, GUI.w, 4, true, true)

-- Telling the tabs which z layers to display
-- See Classes/Tabs.lua for more detail
--[[
GUI.elms.tabs:update_sets(
  --  Tab
  --      Layers
  {  [1] =  {3},
    [2] =  {4},
    [3] =  {5},
  }
)
--]]
-- Notice that layers 1 and 2 aren't assigned to a tab; this leaves them visible
-- all the time.


--[[

------------------------------------
-------- Tab 1 Elements ------------
------------------------------------


GUI.New("my_lbl",   "Label",     3, 256, 96, "Label!", true, 1)
GUI.New("my_knob",   "Knob",     3, 64, 112, 48, "Volume", 0, 11, 44, 0.25)
GUI.New("my_mnu",   "Menubox",     3, 256, 176, 64, 20, "Options:", "1,2,3,4,5,6.12435213613")
GUI.New("my_btn2",  "Button",       3, 256, 256, 64, 20, "Click me!", fade_lbl)
GUI.New("my_txt",   "Textbox",     3, 96, 224, 96, 20, "Text:", 4)
GUI.New("my_frm",   "Frame",     3, 16, 288, 192, 128, true, false, "elm_frame", 4)


-- We have too many values to be legible if we draw them all; we'll disable them, and
-- have the knob's caption update itself to show the value instead.
GUI.elms.my_knob.vals = false
function GUI.elms.my_knob:redraw()
  
    GUI.Knob.redraw(self)

    self.caption = self.retval .. "dB"
  
end

-- Make sure it shows the value right away
GUI.elms.my_knob:redraw()


GUI.Val("my_frm",   "this is a really long string of text with no carriage returns so hopefully "..
                    "it will be wrapped correctly to fit inside this frame")
GUI.elms.my_frm.bg = "elm_bg"

--]]


------------------------------------
-------- Tab 2 Elements ------------
------------------------------------

-- Button Colors  = {r, g, b, transparency}

GUI.colors["count_in"] = {255, 124, 192, 255}
GUI.colors["intro_post_fill"] = {119, 17, 174, 255}
GUI.colors["intro"] = {159, 22, 232, 255}
GUI.colors["intro_fill"] = {183, 128, 237, 255}
GUI.colors["verse_post_fill"] = {17, 39, 174, 255}
GUI.colors["verse"] = {55, 118, 235, 255}
GUI.colors["verse_fill"] = {113, 190, 241, 255}
GUI.colors["verse_ending"] = {151, 208, 245, 255}
GUI.colors["bridge_post_fill"] = {206, 105, 20, 255}
GUI.colors["bridge"] = {234, 133, 48, 255}
GUI.colors["bridge_fill"] = {239, 164, 100, 255}
GUI.colors["pre_chorus_post_fill"] = {206, 179, 20, 255}
GUI.colors["pre_chorus"] = {234, 208, 48, 255}
GUI.colors["pre_chorus_fill"] = {244, 231, 151, 255}
GUI.colors["chorus_post_fill"] = {11, 116, 39, 255}
GUI.colors["chorus"] = {17, 174, 59, 255}
GUI.colors["chorus_fill"] = {80, 237, 123, 255}
GUI.colors["chorus_ending"] = {158, 254, 182, 255}
GUI.colors["play_anywhere"] = {228, 26, 39, 250}
GUI.colors["drum_riff"] = {115, 23, 17, 255}
GUI.colors["hold"] = {191, 191, 191, 255}
GUI.colors["shot"] = {127, 127, 127, 255}
GUI.colors["rest"] = {0, 0, 0, 255}

--Text Colors

GUI.colors["btn_txt1"] = {255, 255, 255, 255} --white
GUI.colors["btn_txt2"] = {155, 155, 155, 255} --gray
GUI.colors["btn_txt3"] = {0, 0, 0, 255} --black
---------------------------------------------------------------------
--Chord Scales Tab 2 (2,4)
---------------------------------------------------------------------

--Chord Input
--local number = GUI.Val("key_choice")

CMajor = {"C", "Dm", "Em", "F", "G", "Am", "Bdim", "CMaj7", "Dm7", "Em7", "FMaj7", "G7", "Am7", "Bm7b5"}
CsMajor = {"C#", "D#m", "Fm", "F#", "G#", "A#m", "Cdim", "C#Maj7", "D#m7", "Fm7", "F#Maj7", "G#7", "A#m7", "Cm7b5"}
DbMajor = {"Db", " Ebm", " Fm", " Gb", "Ab", "Bbm", "Cdim", "DbMaj7", "Ebm7", "Fm7", "GbMaj7", "Ab7", " Bbm7", "Cm7b5"}
DMajor = {"D", "Em", "F#m", "G", "A", "Bm", "C#dim", "DMaj7", "Em7", "F#m7", "GMaj7", "A7", "Bm7", "C#m7b5"}
DsMajor = {"D#", "Fm", "Gm", "G#", "A#", "Cm", "Ddim", "D#Maj", "Fm7", "Gm7", "G#Maj7", "A7", "Cm7", "Dm7b5"}
EbMajor = {"Eb", "Fm", "Gm", "Ab", "Bb", "Cm", "Ddim", "EbMaj7", "Fm7", "Gm7", "AbMaj7", "Bb7", "Cm7", "Dm7b5"}
EMajor = {"E", "F#m", "G#m", "A", "B", "C#m", "D#dim", "EMaj7", "F#m7", "G#m7", "AMaj7", "B7", "C#m7", "D#m7b5"}
FMajor = {"F", "Gm", "Am", "Bb", "C", "Dm", "Edim", "FMaj7", "Gm7", "Am7", "BbMaj7", "C7", "Dm7", "Em7b5"}
FsMajor = {"F#", "G#m", "A#m", "B", "C#", "D#m", "Fdim", "F#Maj7", "G#m7", "A#m7", "BMaj7", "C#7", "D#m7", "Fm7b5"}
GbMajor = {"Gb", "Abm", "Bbm", "B", "Db", "Ebm", "Fdim", "GbMaj7", "Abm7", "Bbm7", "BMaj7", "Db7", "Ebm7", "Fm7b5"}
GMajor = {"G", "Am", "Bm", "C", "D", "Em", "F#dim", "GMaj7", "Am7", "Bm7", "CMaj7", "D7", "Em7", "F#m7b5"}
GsMajor = {"G#", "A#m", "Cm", "C#", "D#", "Fm", "Gdim", "G#Maj7", "A#m7", "Cm7", "C#Maj7", "D#7", "Fm7", "Gm7b5"}
AbMajor = {"Ab", "Bbm", "Cm", "Db", "Eb", "Fm", "Gdim", "bMaj7", "Bbm7", "Cm7", "DbMaj7", "Eb7", "Fm7", "Gm7b5"}
AMajor = {"A", "Bm", "C#m", "D", "E", "F#m", "G#dim", "AMaj7", "Bm7", "C#m7", "DMaj7", "E7", "F#m7", "G#m7b5"}
AsMajor = {"A#", "Cm", "Dm", "D#", "F", "Gm", "Adim", "A#Maj7", "Cm7", "Dm7", "D#Maj7", "F7", "Gm7", "Am7b5"}
BbMajor = {"Bb", "Cm", "Dm", "Eb", "F", "Gm", "Adim", "BbMaj7", "Cm7", "Dm7", "EbMaj7", "F7", "Gm7", "Am7b5"}
BMajor = {"B", "C#m", "D#m", "E", "F#", "G#m", "A#dim", "BMaj7", "C#m7", "D#m7", "EMaj7", "F#7", "G#m7", "A#m7b5"}


CMinor = {"Cm", "Ddim", "Eb", "Fm", "Gm", "Ab", "Bb", "Cm7", "Dm7b5", "EbMa7", "Fm7", "Gm7", "AbMaj7", "Bm7"}
CsMinor = {"C#m", "D#m", "E", "F#m", "G#m", "A", "B", "C#m7", "D#m7b5", "EMaj7", "F#m7", "G#m7", "AMaj7", "B7"}
DbMinor = {"Dbm", "Ebdim", "E", "Gbm", "Abm", "A", "B", "Dbm7", "Ebm7b5", "EMaj7", "Gbm7", "Abm7", "AMaj7", "B7"}
DMinor = {"Dm", "Edim", "F", "Gm", "Am", "Bb", "C", "Dm7", "Em7b5", "FMaj7", "Gm7", "A7", "BbMaj7", "C7"}
DsMinor = {"D#m", "Fdim", "F#", "G#m", "A#m", "B", "C#", "D#m7", "Fm7b5", "F#Maj7", "G#m7", "A#m7", "BMaj7", "C#7"}
EbMinor = {"Ebm", "Fdim", "Gb", "Abm", "Bbm", "B", "Db", "Ebm7", "Fm7b5", "GbMaj7", "Abm7", "Bb7", "BMaj7", "Db7"}
EMinor = {"Em", "F#dim", "G", "Am", "Bm", "C", "D", "Em7", "F#m7b5", "GMaj7", "Am7", "B7", "CMaj7", "D7"}
FMinor = {"Fm", "F#dim", "Ab", "Bbm", "Cm", "Db", "Eb", "Fm7", "F#m7b5", "AbMaj7", "Bbm7", "C7", "DbMaj7", "Eb7"}
FsMinor = {"F#m", "G#dim", "A", "Bm", "C#m", "D", "E", "F#m7", "G#m7b5", "AMaj7", "Bm7", "C#m7", "DMaj7", "E7"}
GbMinor = {"Gbm", "Abdim", "A", "Bm", "Dbm", "D", "E", "Gbm7", "Abm7b5", "AMaj7", "Bm7", "Dbm7", "DMaj7", "E7"}
GMinor = {"Gm", "Adim", "Bb", "Cm", "Dm", "Eb", "F", "Gm7", "Am7b5", "BbMaj7", "Cm7", "Dm7", "EbMaj7", "F7"}
GsMinor = {"G#m", "A#dim", "B", "C#m", "D#m", "E", "F#", "G#m7", "A#m7b5", "BMaj7", "C#m7", "D#m7", "EMaj7", "F#7"}
AbMinor = {"Abm", "Bbdim", "B", "Dbm", "Ebm", "E", "Gb", "Abm7", "Bbm7b5", "BMaj7", "Dbm7", "Ebm7", "EMaj7", "Gb7"}
AMinor = {"Am", "Bdim", "C", "Dm", "Em", "F", "G", "Am7", "Bm7b5", "CMaj7", "Dm7", "E7", "FMaj7", "G7"}
AsMinor = {"A#m", "Cdim", "C#", "D#m", "Fm", "F#", "G#", "A#m7", "Cm7b5", "C#Maj7", "D#m7", "Fm7", "F#Maj7", "G#7"}
BbMinor = {"Bbm", "Cdim", "Db", "Ebm", "Fm", "Gb", "Ab", "Bbm7", "Cm7b5", "DbMaj7", "Ebm7", "Fm7", "GbMaj7", "Ab7"}
BMinor = {"Bm", "C#dim", "D", "Em", "F#m", "G", "A", "Bm7", "C#m7b5", "DMaj7", "Em7", "F#7", "GMaj7", "A7"}


CHarmonic_Major = {"C", "Ddim", "E", "Fm", "G", "Abdim", "Bdim", "CMaj7", "Dm7b5", "Em", "FmMaj7", "G7", "Abaug", "Bdim7"}
CsHarmonic_Major = {"C#", "D#dim", "F", "F#m", "  G#", "Adim", "Cdim", "C#Maj7", "D#m7b5", "Fm", "F#mMaj7", "G#7", "Aaug", "Cdim7"}
DbHarmonic_Major = {"Db", "Ebdim", "F", "Gbm", "Ab", "Adim", "Cdim", "DbMaj7", "Ebm7b5", "Fm", "GbmMaj7", "Ab7", "Aaug", "Cdim7"}
DHarmonic_Major = {"D", "Edim", "F#", "Gm", "A", "Bbdim", "Dbdim", "DMaj7", "Em7b5", "F#m", "GmMaj7", "A7", "Bbdim", "Dbdim7"}
DsHarmonic_Major = {"D#", "Fdim", "G", "G#m", "A#", "Bdim", "Ddim", "D#Maj7", "Fm7b5", "Gm", "G#mMaj7", "A#7", "Baug", "Ddim7"}
EbHarmonic_Major = {"Eb", "Fdim", "G", "Abm", "Bb", "Bdim", "Ddim", "EbMaj7", "Fm7b5", "Gm", "AbmMaj7", "Bb7", "Baug", "Ddim7"}
EHarmonic_Major = {"E", "F#dim", "Ab", "Am", "B", "Cdim", "Ebdim", "EMaj7", "F#m7b5", "Abm", "AmMaj7", "B7", "Caug", "Ebdim7"}
FHarmonic_Major = {"F", "Gdim", "A", " Bbm", "  C", " Dbdim", "Edim", " FMaj7", "Gm7b5", "Am", "BbmMaj7", "C7", "Dbaug", "Edim7"}
FsHarmonic_Major = {"F#", "G#dim", "A#", "Bm", "C#", "Ddim", "Fdim", "F#Maj7", "G#m7b5", "A#m", "BmMaj7", "C#7", "Daug", "Fdim7"}
GbHarmonic_Major = {"Gb", "Abdim", "Bb", "Bm", "Db", "Ddim", "Fdim", "GbMaj7", "Abm7b5", "Bbm", "BmMaj7", "Db7", "Daug", "Fdim7"}
GHarmonic_Major = {"G", "Adim", "B", "Cm", "D", "Ebdim", "F#dim", "GMaj7", "Am7b5", "Bm", "CmMaj7", "D7", "Ebaug", "F#dim7"}
GsHarmonic_Major = {"G#", "A#dim", "C", "C#m", "D#", "Edim", "Gdim", "G#Maj7", "A#m7b5", "Cm", "C#mMaj7", "D#7", "Eaug", "Gdim7"}
AbHarmonic_Major = {"Ab", "Bbdim", "C", "Dbm", "Eb", "Edim", "Gdim", "AbMaj7", "Bbm7b5", "Cm", "DbmMaj7", "Eb7", "Eaug", "Gdim7"}
AHarmonic_Major = {"A", "Bdim", "C#", "Dm", "E", "Fdim", "Abdim", "AMaj7", "Bm7b5", "Dbm", "DmMaj7", "E7", "Faug", "Abdim7"}
AsHarmonic_Major = {"A#", "Cdim", "D", "D#m", "F", "F#dim", "Adim", "A#Maj7", "Cm7b5", "Dm", "D#mMaj7", "F7", "F#aug", "Adim7"}
BbHarmonic_Major = {"Bb", "Cdim", "D", "Ebm", "F", "Gbdim", "Adim", " BbMaj7", "Cm7b5", "Dm", "EbmMaj7", "F7", "Gbaug", "Adim7"}
BHarmonic_Major = {"B", "C#dim", "Eb", "Em", "F#", "Gdim", "Bbdim", "BMaj7", "C#m7b5", "Ebm", "EmMaj7", "F#7", "Gaug", "Bbdim7"}

CMelodic_Major = {"C", "Ddim", "Edim", "Fm", "Gm", "Abaug", "Bb", "C7", "Dm7b5", "Eaug", "FmMaj7", "Gm7", "AbMaj7#5", "Bb7"}
CsMelodic_Major = { "C#", "D#dim", "Fdim", "F#m", "G#m", "Aaug", "B", "C#7", "D#m7b5", "Faug", "F#mMaj7", "G#m7", "AMaj7#5", "B7"}
DbMelodic_Major = { "Db", "Ebdim", "Fdim", "Gbm", "Abm", "Aaug", "B", "Db7", "Ebm7b5", "Faug", "GbmMaj7", "Abm7", "AMaj7#5", "B7"}
DMelodic_Major = { "D", "Edim", "Cbdim", "Gm", "Am", "Bbaug", "C", "D7", "Em7b5", "Gbaug", "GmMaj7", "Am7", "BbMaj7#5", "C7"}
DsMelodic_Major = { "D#", "Fdim", "Gdim", "G#m", "A#m", "Baug", "C#", "D#7", "Fm7b5", "Gaug", "G#mMaj7", "A#m7", "BMaj7#5", "C#7"}
EbMelodic_Major = { "Eb", "Fdim", "Gdim", "Abm", "Bbm", "Baug", "Db", "Eb7", "Fm7b5", "Gaug", "AbmMaj7", "Bbm7", "BMaj7#5", "Db7"}
EMelodic_Major = { "E", "Gbdim", "Abdim", "Am", "Bm", "Caug", "D", "E7", "Gb,7b5", "Abaug", "AnMaj7", "Bm7", "CMaj7#5", "D7"}
FMelodic_Major = { "F", "Gdim", "Adim", "Bbm", "Cm", "Dbaug", "Eb", "F7", "Gm7b5", "Aaug", "BbmMaj7", "Cm7", "DbMaj7#5", "Eb7"}
FsMelodic_Major = { "F#", "G#dim", "A#dim", "Bm", "C#m", "Daug", "E", "F#7", "G#m7b5", "A#aug", "BmMaj7", "C#m7", "DMaj7#5", "E7"}
GbMelodic_Major = { "Gb", "Abdim", "Bbdim", "Bm", "Dbm", "Daug", "E", "Gb7", "Abm7b5", "Bbaug", "BmMaj7", "Dbm7", "DMaj7#5", "E7"}
GMelodic_Major = { "G", "Adim", "Bdim", "Cm", "Dm", "Eaug", "F", "G7", "Am7b5", "Baug", "Cmmaj7", "Dm7", "EbMaj7#5", "F7"}
GsMelodic_Major = { "G#", "A#dim", "Cdim", "C#m", "D#m", "Eaug", "F#", "G#7", "A#m7b5", "Caug", "C#mMaj7", "D#m7", "EMaj7#5", "F#7"}
AbMelodic_Major = { "Ab", "Bbdim", "Cdim", "Dbm", "Ebm", "Eaug", "Gb", "Ab7", "Bbm7b5", "Caug", "DbmMaj7", "Ebm7", "EMaj7#5", "Gb7"}
AMelodic_Major = { "A", "Bdim", "Dbdim", "Dm", "Em", "Faug", "G", "A7", "Bm7b5", "Dbaug", "Dmmaj7", "Em7", "FMaj7#5", "G7"}
AsMelodic_Major = { "A#", "Cdim", "D#min", "D#m", "Fm", "F#aug", "G#", "A#7", "Cm7b5", "Daug", "D#mMaj7", "Fm7", "F#Maj7#5", "G#7"}
BbMelodic_Major = { "Bb", "Cdim", "Ddim", "Ebm", "Fm", "Gbaug", "Ab", "Bb7", "Cm7b5", "Daug", "EbmMaj7", "Fm7", "GbMaj7#5", "Ab7"}
BMelodic_Major = { "B", "Dbdim", "Ebdim", "Em", "Gbm", "Gaug", "A", "B7", "Dbm7b5", "Ebaug", "EmMaj7", "Gbm7", "GMaj7#5", "A7"}

CHarmonic_Minor = {"Cm", "Ddim", "Ebaug", "Fm", "G", "Ab", "Bdim", "CmMaj7", "Dm7b5", "EbMa7#5", "Fm7", "G7", "Abm", "Baug"}
CsHarmonic_Minor = {"C#m", "D#dim", "Eaug", "F#m", "G#", "A", "Cdim", "C#mMaj7", "D#m7b5", "EMaj7#5", "F#m7", "G#7", "Am", "Caug"}
DbHarmonic_Minor = {"Dbm", "Ebdim", "Eaug", "Gbm", "Ab", "A", "Cdim", "DbmMaj7", "Ebm7b5", "EMaj7#5", "Gbm7", "Ab7", "Am", "Caug"}
DHarmonic_Minor = {"Dm", "Edim", "Faug", "Gm", "A", "Bb", "Dbdim", "DmMaj7", "Em7b5", "FMaj7#", "Gm7", "A7", "Bbm", "Dbaug"}
DsHarmonic_Minor = {"D#m", "Fdim", "F#aug", "G#m", "A#", "B", "Ddim", "D#mMaj7", "Fm7b5", "F#Maj7#5", "G#m7", "A#7", "Bm", "Daug"}
EbHarmonic_Minor = {"Ebm", "Fdim", "Gbaug", "Abm", "Bb", "B", "Ddim", "EbmMaj7", "Fm7b5", "GbMaj7#5", "Abm7", "Bb7", "Bm", "Daug"}
EHarmonic_Minor = {"Em", "F#dim", "Gaug", "Am", "B", "C", "Ebdim", "EmMaj7", "F#m7b5", "GMaj7#5", "Am7", "B7", "Cm", "Ebdim7"}
FHarmonic_Minor = {"Fm", "Gdim", "Abaug", "Bbm", "C", "C#", "Edim", "FmMaj7", "Gm7b5", "AbMaj7#5", "Bbm7", "C7", "C#m", "Eaug"}
FsHarmonic_Minor = {"F#m", "G#dim", "Aaug", "Bm", "C#", "D", "Fdim", "F#mMaj7", "G#m7b5", "AMaj7#5", "Bm7", "C#7", "Dm", "Faug"}
GbHarmonic_Minor = {"Gbm", "Abdim", "Aaug", "Bm", "Db", "D", "Fdim", "GbmMaj7", "Abm7b5", "AMaj7#5", "Bm7", "Db7", "Dm", "Faug"}
GHarmonic_Minor = {"Gm", "Adim", "Bbaug", "Cm", "D", "Eb", "F#dim", "GmMaj7", "Am7b5", "BbMaj7#5", "Cm7", "D7", "Ebm", "F#aug"}
GsHarmonic_Minor = {"G#m", "A#dim", "Baug", "C#m", "D#", "E", "Gdim", "G#mMaj7", "A#m7b5", "BMaj7#5", "C#m7", "D#7", "Em", "Gaug"}
AbHarmonic_Minor = {"Abm", "Bbdim", "Baug", "Dbm", "Eb", "E", "Gdim", "AbmMaj7", "Bbm7b5", "BMaj7#5", "Dbm7", "Eb7", "Em", "Gaug"}
AHarmonic_Minor = {"Am", "Bdim", "Caug", "Dm", "E", "F", "G#dim", "AmMaj7", "Bm7b5", "CMaj7#5", "Dm7", "E7", "Fm", "G#aug"}
AsHarmonic_Minor = {"A#m", "Cdim", "C#aug", "D#m", "F", "F#", "Adim", "A#mMaj7", "Cm7b5", "C#Maj7#5", "D#m7", "F7", "F#m", "Aaug"}
BbHarmonic_Minor = {"Bbm", "Cdim", "Dbaug", "Ebm", "F", "Gb", "Adim", "BbmMaj7", "Cm7b5", "DbMaj7#5", "Ebm7", "F7", "Gbm", "Aaug"}
BHarmonic_Minor = {"Bm", "C#dim", "Daug", "Em", "F#", "G", "Bbdim", "BmMaj7", "C#m7b5", "DMaj7#5", "Em7", "F#7", "Gm", "Bbaug"}


CMelodic_Minor = {"Cm", "Dm", "Ebaug", "F", "G", "Adim", "Bdim", "CmMaj7", "Dm7", "EbMaj7#5", "F7", "G7", "Am7b5", "Baug"}
CsMelodic_Minor = { "C#m", "D#m", "Eaug", "F#", "G#", "A#dim", "Cdim", "C#nMaj7", "D#m7", "EMaj7#5", "F#7", "G#7", "A#mb5", "Caug"}
DbMelodic_Minor = { "Dbm", "Em", "Eaug", "Gb", "Ab", "Bbdim", "Cdim", "DbmMaj7", "Ebm7", "EMaj7#5", "Gb7", "Ab7", "Bbm7b5", "Caug"}
DMelodic_Minor = { "Dm", "Em", "Faug", "G", "A", "Bdim", "Dbdim", "DmMaj7", "Em7", "FMa7#5", "G7", "A7", "Bm7b5", "Daug"}
DsMelodic_Minor = { "D#m", "Fm", "F#aug", "G#", "A#", "Cdim", "Ddim", "D#mMaj7", "Fm7", "F#Maj7#5", "G#7", "A#7", "Cm7b5", "Daug"}
EbMelodic_Minor = { "Ebm", "Fm", "Gbaug", "Ab", "Bb", "Cdim", "Ddim", "EbmMaj7", "Fm7", "GbMaj7#5", "Ab7", "Bb7", "Cm7b5", "Daug"}
EMelodic_Minor = { "Em", "Gbm", "Gaug", "A", "B", "Dbdim", "Ebdim", "EmMaj7", "Gbm7", "GMaj7#5", "A7", "B7", "Dbm7b5", "Ebaug"}
FMelodic_Minor = { "Fm", "Gm", "Abaug", "Bb", "C", "Ddim", "Edim", "FmMaj7", "Gm7", "AbMaj7#5", "Bb7", "C7", "Dm7b5", "Eaug"}
FsMelodic_Minor = { "F#m", "G#m", "Aaug", "B", "C#", "D#dim", "Fdim", "F#mMaj", "G#m7", "AMaj7#5", "B7", "C#7", "D#m7b5", "Faug"}
GbMelodic_Minor = { "Gbm", "Abm", "Aaug", "B", "Db", "Ebdim", "Fdim", "GbmMaj7", "Abm7", "AMaj7#5", "B7", "Db7", "Ebm7b5", "Faug"}
GMelodic_Minor = { "Gm", "Am", "Bbaug", "C", "D", "Edim", "Gbdim", "GmMaj7", "Am7", "BbMaj7#5", "C7", "D7", "Em7b5", "Gbaug"}
GsMelodic_Minor = { "G#m", "A#m", "Baug", "C#", "D#", "Fdim", "Gdim", "G#mMaj7", "A#m7", "BMaj7#5", "C#7", "D#7", "Fm7b5", "Gaug"}
AbMelodic_Minor = { "Abm", "Bbm", "Baug", "Db", "Eb", "Fdim", "Gdim", "AbmMaj7", "Bbm7", "BMaj7#5", "Db7", "Eb7", "Fm7b5", "Daug"}
AMelodic_Minor = { "Am", "Bm", "Caug", "D", "R", "Gbdim", "Abdim", "AmMaj7", "Bm7", "CMaj7#5", "D7", "E7", "Gbm7b5", "Abaug"}
AsMelodic_Minor = { "A#m", "Cm", "C#aug", "D#", "F", "Gdim", "Adim", "A#mMaj7", "Cm7", "C#Maj7#5", "D#7", "F7", "Gm7b5", "Aaug"}
BbMelodic_Minor = { "Bbm", "Cm", "Dbaug", "Eb", "F", "Gdim", "Adim", "BbmMaj7", "Cm7", "DbMaj7#5", "Eb7", "F7", "Gm7b5", "Aaug"}
BMelodic_Minor = { "Bm", "Dbm", "Daug", "E", "Gb", "Abdim", "Bbdim", "BmMaj7", "Dbm7", "DMaj7#5", "E7", "Gb7", "Abm7b5", "Bbaug"}

CIonian = {"C", "Dm", "Em", "F", "G", "Am", "Bdim", "CMaj7", "Dm7", "Em7", "FMaj7", "G7", "Am7", "Bm7b5"}
CsIonian = {"C#", "D#m", "Fm", "F#", "G#", "A#m", "Cdim", "C#Maj7", "D#7", "Fm7", "F#Maj7", "G#7", "A#m7", "Cm7b5"}
DbIonian = {"Db", "Ebm", "Fm", "F#", "Ab", "Bbm", "Cdim", "DbMaj7", "Eb7", "Fm7", "F#Maj7", "Ab7", "Bbm7", "Cm7b5"}
DIonian = {"D", "Em", "F#m", "G", "A", "Bm", "C#dim", "DMaj7", "Em7", "F#m7", "GMaj7", "A7", "Bm7", "C#m75m"}
DsIonian = {"D#", "Fm", "Gm", "G#", "Bb", "Cm", "Ddim", "D#Maj7", "Fm7", "Gm7", "G#Maj7", "Bb7", "Cm7", "Dm7b5"}
EbIonian = {"Eb", "Fm", "Gm", "G#", "Bb", "Cm", "Ddim", "EbMaj7", "Fm7", "Gm7", "AbMaj7", "Bb7", "Cm7", "Dm7b5"}
EIonian = {"E", "F#m", "G#m", "A", "B", "C#m", "Ebdim", "EMaj7", "F#m7", "G#m7", "AMaj7", "B7", "C#7", "D#m7b5"}
FIonian = {"F", "Gm", "Am", "Bb", "C", "Dm", "Edim", "FMaj7", "Gm7", "Am7", "BbMaj7", "C7", "Dm7", "Em7b5"}
FsIonian = {"F#", "G#m", "A#m", "B", "C#", "D#m", "Fdim", "F#Maj7", "G#m7", "A#m7", "BMaj7", "C#7", "D#m7", "Fm7b5"}
GbIonian = {"Gb", "Abm", "Bbm", "B", "Db", "Ebm", "Fdim", "GbMaj7", "Abm7", "Bbm7", "BMaj7", "Db7", "Ebm7", "Fm7b5"}
GIonian = {"G", "A", "Bm", "C", "D", "Em", "F#dim", "GMaj7", "Am7", "Bm7", "CMaj7", "D7", "Em7", "F#m7b5"}
GsIonian = {"G#", "A#m", "Cm", "C#", "Eb", "Fm", "Gdim", "G#Maj7", "Bbm7", "Cm7", "C#Maj7", "D#7", "Fm7", "Gm7b5"}
AbIonian = {"Ab", "A#m", "Cm", "C#", "Eb", "Fm", "Gdim", "AbMaj7", "Bbm7", "Cm7", "C#Maj7", "D#7", "Fm7", "Gm7b5"}
AIonian = {"A", "Bm", "C#m", "D", "E", "F#m", "G#dim", "AMaj7", "Bm7", "C#m7", "DMaj7", "E7", "F#m7", "G#m7b5"}
AsIonian = {"A#", "Cm", "Dm", "D#", "F", "Gm", "Adim", "A#Maj7", "Cm7", "Dm7", "D#Maj7", "F7", "Gm7", "Am7b5"}
BbIonian = {"Bb", "Cm", "Dm", "Eb", "F", "Gm", "Adim", "BbMaj7", "Cm7", "Dm7", "EbMaj7", "F7", "Gm7", "Am7b5"}
BIonian = {"B", "C#m", "Ebm", "E", "F#", "G#m", "Bbdim", "BMaj7", "C#m7", "Ebm7", "EMaj7", "F#7", "G#m7", "Bbm7b5"}


CDorian = {"Cm", "Dm", "Eb", "F", "Gm", "Adim", "Bb", "Cm7", "Dm7", "EbMaj7", "F7", "Gm7", "Am7b5", "BbMaj7"}
CsDorian = {"C#m", "D#m", "E", "F#", "G#", "A#dim", "B", "C#m7", "D#m7", "EMaj7", "F#7", "G#m7", "A#m7b5", "BMaj7"}
DbDorian = {"Dbm", "Ebm", "E", "Gb", "Abm", "Bbdim", "B", "Dbm7", "Ebm7", "EMaj7", "Gb7", "Abm7", "Bbm7b5", "BMaj7"}
DDorian = {"Dm", "Em", "F", "G", "Am", "Bdim", "C", "Dm7", "Em7", "FMaj7", "G7", "Am7", "Bm7b5", "CMaj7"}
DsDorian = {"D#m", "Fm", "F#", "G#", "Bbm", "Cdim", "C#", "D#m7", "Fm7", "F#Maj7", "G#7", "A#m7", "Cm7b5", "C#Maj7"}
EbDorian = {"Ebm", "Fm", "Gb", "Ab", "Bbm", "Cdim", "Db", "Ebm7", "Fm7", "GbMaj7", "Ab7", "Bbm7", "Cm7b5", "DbMaj7"}
EDorian = {"Em", "F#m", "G", "A", "Bm", "C#m", "D", "Em7", "F#m7", "GMaj7", "A7", "Bm7", "C#m7b5", "DMaj7"}
FDorian = {"Fm", "Gm", "G#", "Bb", "Cm", "Ddim", "Eb", "Fm7", "Gm7", "G#Maj7", "Bb7", "Cm7", "Dm7b5", "EbMaj7"}
FsDorian = {"F#m", "G#m", "A", "B", "C#m", "D#dim", "E", "F#m7", "G#m7", "AMaj7", "B7", "C#m7", "D#m7b5", "EMaj7"}
GbDorian = {"Gbm", "Abm", "A", "B", "Dbm", "Ebdim", "E", "Gbm7", "Abm7", "AMaj7", "B7", "Dbm7", "Ebm7b5", "EMaj7"}
GDorian = {"Gm", "Am", "Bb", "C", "Dm", "Edim", "F", "Gm7", "Am7", "BbMaj7", "C7", "Dm7", "Em7b5", "FMaj7"}
GsDorian = {"G#m", "Bbm", "B", "C#", "Ebm", "Fdim", "F#", "G#m7", "Bbm7", "BMaj7", "C#7", "Ebm7", "Fm7b5", "F#Maj7"}
AbDorian = {"Abm", "Bbm", "B", "C#", "Ebm", "Fdim", "F#", "Abm7", "Bbm7", "BMaj7", "C#7", "Ebm7", "Fm7b5", "F#Maj7"}
ADorian = {"Am", "Bm", "C", "D", "Em", "F#dim", "G", "Am7", "Bm7", "CMaj7", "D7", "Em7", "F#m7b5", "Gmaj7"}
AsDorian = {"A#m", "Cm", "C#", "Eb", "Fm", "Gdim", "G#", "Bbm7", "Cm7", "C#Maj7", "Eb7", "Fm7", "Gm7b5", "G#maj7"}
BbDorian = {"Bbm", "Cm", "Db", "Eb", "Fm", "Gdim", "Ab", "Bbm7", "Cm7", "DbMaj7", "Eb7", "Fm7", "Gm7b5", "Abmaj7"}
BDorian = {"Bm", "Dbm", "D", "E", "Gbm", "Abdim", "A", "Bm7", "Dbm7", "DMaj7", "E7", "Gbm7", "Abm7b5", "AMaj7"}


CPhrygian = {"Cm", "Db", "Eb", "Fm", "Gdim", "Ab", "Bbm", "Cm7", "DbMaj7", "Eb7", "Fm7", "Gm7b5", "AbMaj7", "Bbm"}
CsPhrygian = { "C#m", "D", "E", "F#m", "G#dim", "A", "Bm", "C#m7", "DMaj7", "E7", "F#m7", "G#m7b5", "AMaj7", "Bm7"}
DbPhrygian = { "Dbm", "D", "E", "Gbm", "Abdim", "A", "Bm", "Dbm7", "DMaj7", "E7", "Gbm7", "Abm7b5", "AMaj7", "Bm7"}
DPhrygian = { "Dm", "Eb", "F", "Gm", "Adim", "Bb", "Cm", "Dm7", "EbMaj7", "F7", "Gm7", "Am7b5", "BbMaj7", "Cm7"}
DsPhrygian = { "D#m", "E", "F#", "G#m", "A#dim", "B", "C#m", "D#m7", "EMaj7", "F#7", "G#m7", "A#m7b5", "BMaj7", "C#m7"}
EbPhrygian = { "Ebm", "E", "Gb", "Abm", "Bbdim", "B", "Dbm", "Ebm7", "EMaj7", "Gb7", "Abm7", "Bbm7b5", "BMaj7", "Dbm7"}
EPhrygian = { "Em", "F", "G", "Am", "Bdim", "C", "Dm", "Em7", "FMaj7", "G7", "Am7", "Bm7b5", "CMaj7", "Dm7"}
FPhrygian = { "Fm", "Gb", "Ab", "Bbm", "Cdim", "Db", "Ebm", "Fm7", "GbMaj7", "Ab7", "Bbm7", "Cm7b5", "DbMaj7", "Ebm7"}
FsPhrygian = { "F#m", "G", "A", "Bm", "C#dim", "D", "Em", "F#m7", "GMaj7", "A7", "Bm7", "C#m7b5", "DMaj7", "Em7"}
GbPhrygian = { "Gbm", "G", "A", "Bm", "Dbdim", "D", "Em", "Gbm7", "GMaj7", "A7", "Bm7", "Dbm7b5", "DMaj7", "Em7"}
GPhrygian = { "Gm", "Ab", "Bb", "Cm", "Ddim", "Eb", "Fm", "Gm7", "AbMaj7", "Bb7", "Cm7", "Dm7b5", "EbMaj7", "Fm7"}
GsPhrygian = { "G#m", "A", "B", "C#m", "D#dim", "E", "F#m", "G#m7", "AMaj7", "B7", "C#m7", "D#m7b5", "EMaj7", "F#m7"}
AbPhrygian = { "Abm", "A", "B", "Dbm", "Ebdim", "E", "Gbm", "Abm7", "AMaj", "B7", "Dbm7", "Ebm7b5", "EMaj7", "Gbm7"}
APhrygian = { "Am", "Bb", "C", "Dm", "Edim", "F", "Gm", "Am7", "BbMaj7", "C7", "Dm7", "Em7b5", "FMaj7", "Gm7"}
AsPhrygian = { "A#m", "B", "C#", "D#m", "Fdim", "F#", "G#m", "A#m7", "BMaj7", "C#7", "D#m7", "Fm7b5", "F#Maj7", "G#m7"}
BbPhrygian = { "Bbm", "B", "Db", "Ebm", "Fdim", "Gb", "Abm", "Bbm7", "BMaj7", "Db7", "Ebm7", "Fm7b5", "GbMaj7", "Abm7"}
BPhrygian = { "Bm", "C", "D", "Em", "Gbdim", "G", "Am", "Bm7", "CMaj7", "D7", "Em7", "Gbm7b5", "GMaj7", "Am7"}

CLydian = {"C", "D", "Em", "Gbdim", "G", "Am", "Bm", "CMaj7", "D7", "Em7", "Gbm7b5", "GMaj", "7Am7", "Bm7"}
CsLydian = { "C#", "D#", "Fm", "Gdim", "G#", "A#m", "Cm", "C#Maj7", "D#7", "Fm7", "Gm7b5", "G#Maj7", "A#m7", "Cm7"}
DbLydian = { "Db", "Eb", "Fm", "Gdim", "Ab", "Bbm", "Cm", "DbMaj7", "Eb7", "Fm7", "Gm7b5", "AbMaj7", "Bbm7", "Cm7"}
DLydian = { "D", "E", "Gbm", "Abdim", "A", "Bm", "Dbm", "DMaj7", "E7", "Gbm7", "Abm7b5", "AMaj7", "Bm7", "Dbm7"}
DsLydian = { "D#", "F", "Gm", "Adim", "A#", "Cm", "Dm", "D#Maj7", "F7", "Gm7", "Am7b5", "A#Maj7", "Cm7", "Dm7"}
EbLydian = { "Eb", "F", "Gm", "Adim", "Bb", "Cm", "Dm", "EbMaj7", "F7", "Gm7", "Am7b5", "BbMaj7", "Cm7", "Dm7"}
ELydian = { "E", "Gb", "Abm", "Bbdim", "B", "Dbm", "Ebm", "EMaj7", "Gb7", "Abm7", "Bbm7b5", "BMaj7", "Dbm7", "Ebm7"}
FLydian = { "F", "G", "Am", "Bdim", "C", "Dm", "Em", "FMaj7", "G7", "Am7", "Bm7b5", "CMaj7", "Dm7", "Em7"}
FsLydian = { "F#", "G#", "A#m", "Cdim", "C#", "D#m", "Fm", "F#Maj7", "G#7", "A#m7", "Cm7b5", "C#Maj7", "D#m7", "Fm7"}
GbLydian = { "Gb", "Ab", "Bbm", "Cdim", "Db", "Ebm", "Fm", "GbMaj7", "Ab7", "Bbm7", "Cm7b5", "DbMaj7", "Ebm7", "Fm7"}
GLydian = { "G", "A", "Bm", "Dbdim", "D", "Em", "Gbm", "GMaj7", "A7", "Bm7", "Dbm7b5", "DMaj7", "Em7", "Gbm7"}
GsLydian = { "G#", "A#", "Cm", "Ddim", "D#", "Fm", "Gm", "G#Maj7", "A#7", "Cm7", "Dm7b5", "D#Maj7", "Fm7", "Gm7"}
AbLydian = { "Ab", "Bb", "Cm", "Ddim", "Eb", "Fm", "Gm", "AbMaj7", "Bb7", "Cm7", "Dm7b5", "EbMaj7", "Fm7", "Gm7"}
ALydian = { "A", "B", "Dbm", "Ebdim", "E", "Gbm", "Abm", "AMaj7", "B7", "Dbm7", "Ebm7b5", "EMaj7", "Gbm7", "Abm7"}
AsLydian = { "A#", "C", "Dm", "Edim", "F", "Gm", "Am", "A#Maj7", "C7", "Dm7", "Em7b5", "FMaj7", "Gm7", "Am7"}
BbLydian = { "Bb", "C", "Dm", "Edim", "F", "Gm", "Am", "Bbmaj7", "C7", "Dm7", "Em7b5", "FMaj7", "Gm7", "Am7"}
BLydian = { "B", "Db", "Ebm", "Fdim", "Gb", "Abm", "Bbm", "BMaj7", "Db7", "Ebm7", "Fm7b5", "GbMaj7", "Abm7", "Bbm7"}


CMixolydian = {"C", "Dm", "Edim", "F", "Gm", "Am", "Bb", "C7", "Dm7", "Em7b5", "FMaj7", "Gm7", "Am7", "BbMaj7"}
CsMixolydian = { "C#", "D#m", "Fdim", "F#", "G#m", "A#m", "B", "C#7", "D#m7", "Fm7b5", "F#Maj7", "G#m7", "A#m7", "BMaj7"}
DbMixolydian = { "Db", "Ebm", "Fdim", "Gb", "Abm", "Bbm", "B", "Db7", "Ebm7", "Fm7b5", "GbMaj7", "Abm7", "Bbm7", "BMaj7"}
DMixolydian = { "D", "Em", "Gbdim", "G", "Am", "Bm", "C", "D7", "Em7", "Gbm7b5", "GMaj7", "Am7", "Bm7", "CMaj7"}
DsMixolydian = { "D#", "Fm", "Gdim", "G#", "A#m", "Cm", "C#", "D#7", "Fm7", "Gm7b5", "G#Maj7", "A#m7", "Cm7", "C#Maj7"}
EbMixolydian = { "Eb", "Fm", "Gdim", "Ab", "Bbm", "Cm", "Db", "Eb7", "Fm7", "Gm7b5", "AbMaj7", "Bbm7", "Cm7", "DbMaj7"}
EMixolydian = { "E", "Gbm", "Abdim", "A", "Bm", "Dbm", "D", "E7", "Gbm7", "Abm7b5", "AMaj7", "Bm7", "Dbm7", "DMaj7"}
FMixolydian = { "F", "Gm", "Adim", "Bb", "Cm", "Dm", "Eb", "F7", "Gm7", "Am7b5", "BbMaj7", "Cm7", "Dm7", "EbMaj7"}
FsMixolydian = { "F#", "G#m", "A#dim", "B", "C#m", "D#m", "E", "F#7", "G#m7", "A#m7b5", "BMaj7", "C#m7", "D#m7", "EMaj7"}
GbMixolydian = { "Gb", "Abm", "Bbdim", "B", "Dbm", "Ebm", "E", "Gb7", "Abm7", "Bbm7b5", "BMaj7", "Dbm7", "Ebm7", "EMaj7"}
GMixolydian = { "G", "Am", "Bdim", "C", "Dm", "Em", "F", "G7", "Am7", "Bm7b5", "CMaj7", "Dm7", "Em7", "FMaj7"}
GsMixolydian = { "G#", "A#m", "Cdim", "C#", "D#m", "Fm", "F#", "G#7", "A#m7", "Cm7b5", "C#Maj7", "D#m7", "F#m", "F#Maj7"}
AbMixolydian = { "Ab", "Bbm", "Cdim", "Db", "Ebm", "Fm", "Gb", "Ab7", "Bbm7", "Cm7b5", "DbMaj7", "Ebm7", "Fm7", "GbMaj7"}
AMixolydian = { "A", "Bm", "Dbdim", "D", "Em", "Gbm", "G", "A7", "Bm7", "Dbm7b5", "DMaj7", "Em7", "Gbm7", "GMaj7"}
AsMixolydian = { "A#", "Cm", "Ddim", "D#", "Fm", "Gm", "G#", "A#7", "Cm7", "Dm7b5", "D#maj7", "Fm7", "Gm7", "G#Maj7"}
BbMixolydian = { "Bb", "Cm", "Ddim", "Eb", "Fm", "Gm", "Ab", "Bb7", "Cm7", "Dm7b5", "EbMaj7", "Fm7", "Gm7", "Abmaj7"}
BMixolydian = { "B", "Dbm", "Ebdim", "E", "Gbm", "Abm", "A", "B7", "Dbm7", "Ebm7b5", "EMaj7", "Gbm7", "Abm7", "AMaj7"}


CAeolian = {"Cm", "Ddim", "Eb", "Fm", "Gm", "Ab", "Bb", "Cm7", "Dm7b5", "EbMaj7", "Fm7", "Gm7", "AbMaj7", "Bb7"}
CsAeolian = { "C#m", "D#dim", "E", "F#m", "G#m", "A", "B", "C#m7", "D#m7b5", "EMaj7", "F#m7", "G#m7", "AMaj7", "B7"}
DbAeolian = { "Dbm", "Ebdim", "E", "Gbm", "Abm", "A", "B", "Dbm7", "Ebm7b5", "EMaj7", "Gbm7", "Abm7", "AMaj7", "B7"}
DAeolian = { "Dm", "Edim", "F", "Gm", "Am", "Bb", "C", "Dm7", "Em7b5", "FMaj7", "Gm7", "Am7", "BbMaj7", "C7"}
DsAeolian = { "D#m", "Fdim", "F#", "G#m", "A#M", "B", "C#", "D#m7", "Fm7b5", "F#Maj7", "G#m7", "A#m7", "BMaj7", "C#7"}
EbAeolian = { "Ebm", "Fdim", "Gb", "Abm", "Bbm", "B", "Db", "Ebm7", "Fm7b5", "GbMaj7", "Abm7", "Bbm7", "BMaj7", "Db7"}
EAeolian = { "Em", "Gbdim", "G", "Am", "Bm", "C", "D", "Em7", "Gbm7b5", "GMaj7", "Am7", "Bm7", "CMaj7", "D7"}
FAeolian = { "Fm", "Gdim", "Ab", "Bbm", "Cm", "Db", "Eb", "Fm7", "Gm7b5", "AbMaj7", "Bbm7", "Cm7", "Dbmaj7", "Eb7"}
FsAeolian = { "F#m", "G#dim", "A", "Bm", "C#m", "D", "E", "F#m7", "G#m7b5", "AMaj7", "Bm7", "C#m7", "DMaj7", "E7"}
GbAeolian = { "Gbm", "Abdim", "A", "Bm", "Dbm", "D", "E", "Gbm7", "Abm7b5", "Amaj7", "Bm7", "Dbm7", "DMaj7", "E7"}
GAeolian = { "Gm", "Adim", "Bb", "Cm", "Dm", "Eb", "F", "Gm7", "Am7b5", "BbMaj7", "Cm7", "Dm7", "EbMaj7", "F7"}
GsAeolian = { "G#m", "A#dim", "B", "C#m", "D#m", "E", "F#", "G#m7", "A#m7b5", "BMaj7", "C#m7", "D#m7", "EMaj7", "F#7"}
AbAeolian = { "Abm", "Bbdim", "B", "Dbm", "Ebm", "E", "Gb", "Abm7", "Bbm7b5", "BMaj7", "Dbm7", "Ebm7", "EMaj7", "Gb7"}
AAeolian = { "Am", "Bdim", "C", "Dm", "Em", "F", "G", "Am7", "Bm7b5", "CMaj7", "Dm7", "Em8", "FMaj7", "G7"}
AsAeolian = { "A#m", "Cdim", "C#", "D#m", "Fm", "F#", "G#", "A#m7", "Cm7b5", "C#Maj7", "D#m7", "Fm7", "F#maj7", "G#7"}
BbAeolian = { "Bbm", "Cdim", "Db", "Ebm", "Fm", "Gb", "Ab", "Bbm7", "Cm7b5", "Dbmaj7", "Ebm7", "Fm7", "Gbmaj7", "Ab7"}
BAeolian = { "Bm", "Dbdim", "D", "Em", "Gbm", "G", "A", "Bm7", "Dbm7b5", "DMaj7", "Em7", "Gbm7", "GMaj7", "A7"}


CLocrian = {"Cdim", "C#", "Ebm", "Fm", "F#", "Ab", "Bdim", "Cm7b5", "DbMaj7", "Ebm7", "Fm7", "F#Maj7", "Ab7", "Bbm7"}
CsLocrian = { "C#dim", "D", "Em", "F#m", "G", "A", "Bm", "C#m7b5", "DMaj7", "Em7", "F#m7", "GMaj7", "A7", "Bm7"}
DbLocrian = { "Dbdim", "D", "Em", "Gbm", "G", "A", "Bm", "Dbm7b5", "DMaj7", "Em7", "Gbm7", "GMaj7", "A7", "Bm7"}
DLocrian = { "Ddim", "Eb", "Fm", "Gm", "Ab", "Bb", "Cm", "Dm7b5", "EbMaj7", "Fm7", "Gm7", "AbMaj7", "Bb7", "Cm7"}
DsLocrian = { "D#dim", "E", "F#m", "G#m", "A", "B", "C#m", "D#m7b5", "EMaj", "F#m7", "G#m7", "AMaj7", "B7", "C#m7"}
EbLocrian = { "Ebdim", "E", "Gbm", "Abm", "A", "B", "Dbm", "Ebm7b5", "EMaj7", "Gbm7", "Abm7", "AMaj7", "B7", "Dbm7"}
ELocrian = { "Edim", "F", "Gm", "Am", "bb", "C", "Dm", "Em7b5", "FMaj7", "Gm7", "Am7", "Bbmaj7", "C7", "Dm7"}
FLocrian = { "Fdim", "Gb", "Abm", "Bbm", "B", "Db", "Ebm", "Fm7b5", "GbMaj7", "Abm7", "Bbm7", "BMaj7", "Db7", "Ebm7"}
FsLocrian = { "F#dim", "G", "Am", "Bm", "C", "D", "Em", "F#m7b5", "GMaj7", "Am7", "Bm7", "CMaj7", "D7", "Em7"}
GbLocrian = { "Gbdim", "G", "Am", "Bm", "C", "D", "Em", "Gbm7b5", "GMaj7", "Am7", "Bm7", "CMaj7", "D7", "Em7"}
GLocrian = { "Gdim", "Ab", "Bbm", "Cm", "Db", "Eb", "Fm", "Gm7b5", "Abmaj7", "Bbm7", "Cm7", "Dbmaj7", "Eb7", "Fm7"}
GsLocrian = { "G#dim", "A", "Bm", "C#m", "D", "E", "F#m", "G#m7b5", "AMaj7", "Bm7", "C#m7", "DMaj7", "E7", "F#m7"}
AbLocrian = { "Abdim", "A", "Bm", "Dbm", "D", "E", "Gbm", "Abm7b5", "AMaj7", "Bm7", "Dbm7", "DMaj7", "E7", "Gbm7"}
ALocrian = { "Adim", "Bb", "Cm", "Dm", "Eb", "F", "Gm", "Am7b5", "BbMaj7", "Cm7", "Dm7", "Ebmaj7", "F7", "Gm7"}
AsLocrian = { "A#dim", "B", "C#m", "D#m", "E", "F#", "G#m", "A#m7b5", "BMaj7", "C#m7", "D#m7", "EMaj7", "F#7", "G#m7"}
BbLocrian = { "Bbdim", "B", "Dbm", "Ebm", "E", "Gb", "Abm", "Bbm7b5", "BMaj7", "Dbm7", "Ebm7", "EMaj7", "Gb7", "Abm7"}
BLocrian = { "Bdim", "C", "Dm", "Em", "F", "G", "Am", "Bm7b5", "CMaj7", "Dm7", "Em7", "FMaj7", "G7", "Am7"}






--chord = minor_c
--chord4 = major_chords_c[6] 
--Msg("Major Chord C =")
--Msg(major_chords_c[6])
--local note_names = { [1] = "C", [2] = "Dm", [3] = "Em", [4] = "F", [5] = "G", [6] = "Am", [7] = "Bdim", [8] = "CMaj7", [9] = "Dm7", [10] = "Em7", [11] = "FMaj7", [12] = "G7", [13] = "Am7", [14] = "Bm7b5"}
--local note_names = { [1] = "C", [2] = "Dm", [3] = "Em", [4] = "F", [5] = "G", [6] = "Am", [7] = "Bdim", [8] = "CMaj7", [9] = "Dm7", [10] = "Em7", [11] = "FMaj7", [12] = "G7", [13] = "Am7", [14] = "Bm7b5"}

--local selected_note = note_names[number]

--local selected_note = major_chords[inkey]
--Msg(selected_note)



function key_chord_input()

  newName = keychordName    
  write_markers(newName)
  
end


function btn_click_chord1()
    keychordName = chord[1]
    key_chord_input ()
    
    end    
function btn_click_chord2()
    keychordName = chord[2]
    key_chord_input ()
    end
    
function btn_click_chord3()
    keychordName = chord[3]
    key_chord_input ()
    end

function btn_click_chord4()
    keychordName = chord[4]
    key_chord_input ()
    end
function btn_click_chord5()
    keychordName = chord[5]
    key_chord_input ()
    end
function btn_click_chord6()
    keychordName = chord[6]
    key_chord_input ()
    end
function btn_click_chord7()
    keychordName = chord[7]
    key_chord_input ()
    end
function btn_click_chord8()
    keychordName = chord[8]
    key_chord_input ()
    end
function btn_click_chord9()
    keychordName = chord[9]
    key_chord_input ()
    end
function btn_click_chord10()
    keychordName = chord[10]
    key_chord_input ()
    end
function btn_click_chord11()
    keychordName = chord[11]
    key_chord_input ()
    end
function btn_click_chord12()
    keychordName = chord[12]
    key_chord_input ()
    end
function btn_click_chord13()
    keychordName = chord[13]
    key_chord_input ()
    end
function btn_click_chord14()
    keychordName = chord[14]
    key_chord_input ()
    end







--GUI.New("my_frm9",      "Frame",           4, 32, 255, 340, 20, true, true, "elm_bg", 4)
--function update_buttons()
--end


    GUI.New("key_choice",     "Radio",          3, 210, 30, 610, 110, "Select Key", "C,C♯,Db,D,D♯,Eb,E,F,F♯,Gb,G,G♯,Ab,A,A♯,Bb,B", "h", 15)
    
    --GUI.New("marker_choice",     "Radio",          3, 820, 30, 80, 620, "Bass Root", "C,C♯,Db,D,D♯,Eb,E,F,F♯,Gb,G,G♯,Ab,A,A♯,Bb,B", "v", 15)
    GUI.New("bass_marker_choice",     "Radio",          3, 830, 30, 80, 450, "Bass Root", "C,C♯,D,D♯,E,F,F♯,G,G♯,A,A♯,B", "v", 15)
  --GUI.elms.my_frm9.text = " Choose Your Key"
  --GUI.elms.my_frm9.col_txt = "white"
  
    --GUI.New("scale_choice",     "Radio",          4, 20, 100, 140, 330, "Select Scale", "Major,Minor,Harmonic Major,Harmonic Minor,Melodic Major,Melodic Minor,Ionian,Dorian,Phrygian,Lydian,Mixolydian,Aeolian,Locrian", "v", 4)
    
    GUI.New("scale_choice",   "Menubox",     3, 75, 40, 130, 20, "Chord Scale", "Major,Minor,Harmonic Major,Harmonic Minor,Melodic Major,Melodic Minor,Ionian,Dorian,Phrygian,Lydian,Mixolydian,Aeolian,Locrian")
    
    --GUI.New("scale_choice2",   "Menubox",     4, 120, 200, 64, 20, "Select Scale", "Major,Minor,Harmonic Major,Harmonic Minor,Melodic Major,Melodic Minor,Ionian,Dorian,Phrygian,Lydian,Mixolydian,Aeolian,Locrian")
        

      --if GUI.elms.key_choice.optarray then GUI.elms.lb_key_chord = nil end
      scale = GUI.elms.scale_choice.optarray[ GUI.Val("scale_choice") ]
      
            
      --inkey = GUI.elms.key_choice.optarray[ GUI.Val("key_choice") ]
  --if scale == nil then scale = "Major" end
  --if inkey == nil then inkey = "C" end
 
  
  --chord1 = "C"  
  --GUI.elm_updated = false 
      --Msg("Scale")
     -- Msg(scale)
  --if scale  == "Minor" then scale_minor() end
--scale = GUI.elms.scale_choice.optarray[ GUI.Val("scale_choice") ]
--inkey = GUI.elms.key_choice.optarray[ GUI.Val("key_choice") ]    
--local tblAlphabet = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"};
--Msg(tblAlphabet[4])

-- Radio call funtion on click

function GUI.elms.key_choice:onmouseup()
    -- Run the original method
    GUI.Radio.onmouseup(self)

    -- And then your function
    update_chord_buttons()
end

function GUI.elms.bass_marker_choice:onmouseup()
    -- Run the original method
    GUI.Radio.onmouseup(self)

   
    
end

function GUI.elms.scale_choice:onmouseup()
    -- Run the original method
    GUI.Menubox.onmouseup(self)

    -- And then your function
    update_chord_buttons() 
end

--Update Chord Buttons to new Key/Scale      

function update_chord_buttons() 
    
--Delete old buttons before updating  

    GUI.elms.lb_chords_on:ondelete() 
    GUI.elms.lb_key_chord:ondelete()     
    GUI.elms.key_chord1:ondelete() 
    GUI.elms.key_chord2:ondelete()    
    GUI.elms.key_chord3:ondelete()     
    GUI.elms.key_chord4:ondelete()     
    GUI.elms.key_chord5:ondelete()     
    GUI.elms.key_chord6:ondelete()     
    GUI.elms.key_chord7:ondelete()    
    GUI.elms.key_chord8:ondelete()     
    GUI.elms.key_chord9:ondelete()     
    GUI.elms.key_chord10:ondelete()     
    GUI.elms.key_chord11:ondelete()     
    GUI.elms.key_chord12:ondelete()     
    GUI.elms.key_chord13:ondelete()     
    GUI.elms.key_chord14:ondelete()     
  
    
--Use Legal characters from Radio s=# and remove underscore    
          
    key_numbers = GUI.Val("key_choice")
    key_names = { [1] = "C", [2] = "Cs", [3] = "Db", [4] = "D", [5] = "Ds", [6] = "Eb", [7] = "E", [8] = "F", [9] = "Fs", [10] = "Gb", [11] = "G", [12] = "Gs", [13] = "Ab", [14] = "A", [15] = "As", [16] = "Bb", [17] = "B"}
    selected_key = key_names[key_numbers]
    
    scale_numbers = GUI.Val("scale_choice")
    scale_names = { [1] = "Major", [2] = "Minor", [3] = "Harmonic_Major", [4] = "Harmonic_Minor", [5] = "Melodic_Major", [6] = "Melodic_Minor", [7] = "Ionian", [8] = "Dorian", [9] = "Phrygian", [10] = "Lydian", [11] = "Mixolydian", [12] = "Aeolian", [13] = "Locrian"}
    selected_scale = scale_names[scale_numbers] 

     
     
    scale = GUI.elms.scale_choice.optarray[ GUI.Val("scale_choice") ]
    inkey = GUI.elms.key_choice.optarray[ GUI.Val("key_choice") ]    
 
    
    chord_val = tostring(selected_key..selected_scale)
    

    chord = _G[chord_val]
    --newname = chord_val
    newname = selected_key:gsub("s", "♯")
    newname2 = selected_scale:gsub("_", " ")

-- Button Position Adjustment add e.g x = -10 or x = 0 or x = 10    
    x9 = 200
    y9 = 160
    
    

    GUI.New("lb_chords_on",      "Label",           3, 20+x9, 20+y9, "Chords on", true, 1)
    GUI.New("lb_key_chord",      "Label",           3, 155+x9, 20+y9, newname, true, 1)
    GUI.New("lb_key_scale",      "Label",           3, 195+x9, 20+y9, newname2, true, 1)
    
    GUI.New("key_chord1",      "Button",           3, 16+x9, 55+y9, 70, 20, chord[1], btn_click_chord1)
    GUI.New("key_chord2",      "Button",           3, 96+x9, 55+y9, 70, 20, chord[2], btn_click_chord2)
    GUI.New("key_chord3",      "Button",           3, 176+x9, 55+y9, 70, 20, chord[3], btn_click_chord3)
    GUI.New("key_chord4",      "Button",           3, 256+x9, 55+y9, 70, 20, chord[4], btn_click_chord4)
    GUI.New("key_chord5",      "Button",           3, 336+x9, 55+y9, 70, 20, chord[5], btn_click_chord5)
    GUI.New("key_chord6",      "Button",           3, 416+x9, 55+y9, 70, 20, chord[6], btn_click_chord6)
    GUI.New("key_chord7",      "Button",           3, 496+x9, 55+y9, 70, 20, chord[7], btn_click_chord7)
  
    GUI.New("key_chord8",      "Button",           3, 16+x9, 80+y9, 70, 20, chord[8], btn_click_chord8)
    GUI.New("key_chord9",      "Button",           3, 96+x9, 80+y9, 70, 20, chord[9], btn_click_chord9)
    GUI.New("key_chord10",      "Button",           3, 176+x9, 80+y9, 70, 20, chord[10], btn_click_chord10)
    GUI.New("key_chord11",      "Button",           3, 256+x9, 80+y9, 70, 20, chord[11], btn_click_chord11)
    GUI.New("key_chord12",      "Button",           3, 336+x9, 80+y9, 70, 20, chord[12], btn_click_chord12)
    GUI.New("key_chord13",      "Button",           3, 416+x9, 80+y9, 70, 20, chord[13], btn_click_chord13)
    GUI.New("key_chord14",      "Button",           3, 496+x9, 80+y9, 70, 20, chord[14], btn_click_chord14)
   

    
end

--chordname1 = GUI.Val("key_choice")
--button_1.func = new_chord_function

    key_numbers = GUI.Val("key_choice")
    key_names = { [1] = "C", [2] = "Cs", [3] = "Db", [4] = "D", [5] = "Ds", [6] = "Eb", [7] = "E", [8] = "F", [9] = "Fs", [10] = "Gb", [11] = "G", [12] = "Gs", [13] = "Ab", [14] = "A", [15] = "As", [16] = "Bb", [17] = "B"}
    selected_key = key_names[key_numbers]
    
    scale_numbers = GUI.Val("scale_choice")
    scale_names = { [1] = "Major", [2] = "Minor", [3] = "Harmonic_Major", [4] = "Harmonic_Minor", [5] = "Melodic_Major", [6] = "Melodic_Minor", [7] = "Ionian", [8] = "Dorian", [9] = "Phrygian", [10] = "Lydian", [11] = "Mixolydian", [12] = "Aeolian", [13] = "Locrian"}
    selected_scale = scale_names[scale_numbers] 
     
     
    scale = GUI.elms.scale_choice.optarray[ GUI.Val("scale_choice") ]
    inkey = GUI.elms.key_choice.optarray[ GUI.Val("key_choice") ]    
    
    chord_val = tostring(selected_key..selected_scale)
    chord = _G[chord_val]
    
    --newname = chord_val
    newname = selected_key:gsub("s", "♯")
    newname2 = selected_scale:gsub("_", " ") 

-- Button Position Adjustment add e.g x = -10 or x = 0 or x = 10    
    x9 = 200
    y9 = 160
    
    GUI.New("lb_info",      "Label",           3, 220, 270, "Select Midi Item & Time Selection in Reaper then Select Chord", true, 2)
    
    GUI.New("lb_chords_on",      "Label",           3, 20+x9, 20+y9, "Chord on", true, 1)
    GUI.New("lb_key_chord",      "Label",           3, 155+x9, 20+y9, newname, true, 1)
    --GUI.elms.lb_key_chord.col_txt = "verse_fill"
    --GUI.elms.lb_key_chord.font = {"chords", 40, "bi"}
    
    GUI.New("lb_key_scale",      "Label",           3, 195+x9, 20+y9, newname2, true, 1)
    
    GUI.New("key_chord1",      "Button",           3, 16+x9, 55+y9, 70, 20, chord[1], btn_click_chord1)
    GUI.New("key_chord2",      "Button",           3, 96+x9, 55+y9, 70, 20, chord[2], btn_click_chord2)
    GUI.New("key_chord3",      "Button",           3, 176+x9, 55+y9, 70, 20, chord[3], btn_click_chord3)
    GUI.New("key_chord4",      "Button",           3, 256+x9, 55+y9, 70, 20, chord[4], btn_click_chord4)
    GUI.New("key_chord5",      "Button",           3, 336+x9, 55+y9, 70, 20, chord[5], btn_click_chord5)
    GUI.New("key_chord6",      "Button",           3, 416+x9, 55+y9, 70, 20, chord[6], btn_click_chord6)
    GUI.New("key_chord7",      "Button",           3, 496+x9, 55+y9, 70, 20, chord[7], btn_click_chord7)
  
    GUI.New("key_chord8",      "Button",           3, 16+x9, 80+y9, 70, 20, chord[8], btn_click_chord8)
    GUI.New("key_chord9",      "Button",           3, 96+x9, 80+y9, 70, 20, chord[9], btn_click_chord9)
    GUI.New("key_chord10",      "Button",           3, 176+x9, 80+y9, 70, 20, chord[10], btn_click_chord10)
    GUI.New("key_chord11",      "Button",           3, 256+x9, 80+y9, 70, 20, chord[11], btn_click_chord11)
    GUI.New("key_chord12",      "Button",           3, 336+x9, 80+y9, 70, 20, chord[12], btn_click_chord12)
    GUI.New("key_chord13",      "Button",           3, 416+x9, 80+y9, 70, 20, chord[13], btn_click_chord13)
    GUI.New("key_chord14",      "Button",           3, 496+x9, 80+y9, 70, 20, chord[14], btn_click_chord14)









------------------------------------
-------- Tab 3 Elements ------------
------------------------------------

---Sections

function btn_click_sect_help()
    commandID1 = reaper.NamedCommandLookup("_RSbe31a3de2526d47fa8357af06379275cceb291c2")
    reaper.Main_OnCommand(commandID1, 0) -- Script: ReaTrak sections help.lua
    end


function btn_click_count_in()
    commandID1 = reaper.NamedCommandLookup("_b2ce30f0f372ec4995a64701ccb9169a")
    reaper.Main_OnCommand(commandID1, 0) -- Custom: ReaTrak Set to Count-In
    end

function btn_click_intro_post_fill()
    commandID2 = reaper.NamedCommandLookup("_f7c5b3a543e08d43804cf4dbf3c1cef0")
    reaper.Main_OnCommand(commandID2, 0) -- Custom: ReaTrak Set to Intro Post Fill
    end
    
function btn_click_intro()
    commandID3 = reaper.NamedCommandLookup("_b6b4a8efc7c17e4293bd5b72e6617705")
    reaper.Main_OnCommand(commandID3, 0) -- Custom: ReaTrak Set to Intro
    end   
      
function btn_click_intro_fill()
    commandID4 = reaper.NamedCommandLookup("_90d9c3359514c547af6790ca8994a692")
    reaper.Main_OnCommand(commandID4, 0) -- Custom: ReaTrak Set to Intro Fill
    end    

function btn_click_verse_post_fill()
    commandID5 = reaper.NamedCommandLookup("_9a584ba9b330d343a95c2aa93fa6117b")
    reaper.Main_OnCommand(commandID5, 0) -- Custom: ReaTrak Set to Verse Post Fill
    end

function btn_click_verse()
    commandID6 = reaper.NamedCommandLookup("_ee462747fde1024f9cbab032dc78f12a")
    reaper.Main_OnCommand(commandID6, 0) -- Custom: ReaTrak Set to Verse
    end

function btn_click_verse_fill()
    commandID7 = reaper.NamedCommandLookup("_705d2ad890997c47910db95a51711f24")
    reaper.Main_OnCommand(commandID7, 0) -- Custom: ReaTrak Set to Verse Fill
    end
    
function btn_click_verse_ending()
    commandID8 = reaper.NamedCommandLookup("_a8a68b8ec61b344493682802d9ac44a4")
    reaper.Main_OnCommand(commandID8, 0) -- Custom: ReaTrak Set to Ending Verse
    end 
    
function btn_click_set_drum_riff_btn1()
    commandID171 = reaper.NamedCommandLookup("_5e1fe04adc6fe64d92f8e19d2fb2f59f")
    reaper.Main_OnCommand(commandID171, 0) -- Custom: ReaTrak Set to Drum Riff
    end    
    
---Sections Row 2

function btn_click_bridge_post_fill()
    commandID9 = reaper.NamedCommandLookup("_34073107cc237b4f98d4c3dffd500c90")
    reaper.Main_OnCommand(commandID9, 0) -- Custom: ReaTrak Set to Bridge Post Fill
    end

function btn_click_bridge()
    commandID10 = reaper.NamedCommandLookup("_41fcba1bbfc22647825c27de49981278")
    reaper.Main_OnCommand(commandID10, 0) -- Custom: ReaTrak Set to Bridge
    end

function btn_click_bridge_fill()
    commandID11 = reaper.NamedCommandLookup("_0760f57fdfe45641ba1da32b9e6155aa")
    reaper.Main_OnCommand(commandID11, 0) -- Custom: ReaTrak Set to Bridge Fill
    end
    
function btn_click_pre_chorus_post_fill()
    commandID12 = reaper.NamedCommandLookup("_715ac062b062dc4ba22ddc50252f1e76")
    reaper.Main_OnCommand(commandID12, 0) -- Custom: ReaTrak Set to Pre Chorus Post Fill
    end

function btn_click_pre_chorus()
    commandID13 = reaper.NamedCommandLookup("_cbf39ae594389349ba38f9a5b1175059")
    reaper.Main_OnCommand(commandID13, 0) -- Custom: ReaTrak Set to Pre Chorus
    end

function btn_click_pre_chorus_fill()
    commandID14 = reaper.NamedCommandLookup("_3fe2d48d4d0eba4eae0ddd0731d3410f")
    reaper.Main_OnCommand(commandID14, 0) -- Custom: ReaTrak Set to Pre Chorus Fill
    end
    
function btn_click_chorus_post_fill()
    commandID15 = reaper.NamedCommandLookup("_9f3494ace8dc654ca2f8731d56fba4c4")
    reaper.Main_OnCommand(commandID15, 0) -- Custom: ReaTrak Set to Chorus Post Fill
    end

function btn_click_chorus()
    commandID16 = reaper.NamedCommandLookup("_11153a391144ba4c959ddd4915885bfd")
    reaper.Main_OnCommand(commandID16, 0) -- Custom: ReaTrak Set to Chorus
    end

function btn_click_chorus_fill()
    commandID17 = reaper.NamedCommandLookup("_226c876dff5f82488ad78626dfce652b")
    reaper.Main_OnCommand(commandID17, 0) -- Custom: ReaTrak Set to Chorus Fill
    end
    
function btn_click_chorus_ending()
    commandID18 = reaper.NamedCommandLookup("_f2f3a75e68c966459bdf4fa0460389a8")
    reaper.Main_OnCommand(commandID18, 0) -- Custom: ReaTrak Set to Ending Chorus
    end    
    
---Sections Row 3

function btn_click_rest()
    commandID22 = reaper.NamedCommandLookup("_c7b48c7e54f8e94f9f3437b58f81d549")
    reaper.Main_OnCommand(commandID22, 0) -- Custom: ReaTrak Set to Rest
    end

function btn_click_shot()
    commandID23 = reaper.NamedCommandLookup("_929e978567d96b439647f7437c867c86")
    reaper.Main_OnCommand(commandID23, 0) -- Custom: ReaTrak Set to Shot
    end
    
function btn_click_hold()
    commandID24 = reaper.NamedCommandLookup("_36088becd3ad3948b6d69148121ae590")
    reaper.Main_OnCommand(commandID24, 0) -- Custom: ReaTrak Set to Hold
    end    



-- Button Position Adjustment add e.g x = -10 or x = 0 or x = 10
x1 = -5
y1 = 210 

--GUI.New("lb_Sect",      "Label",           3, 20+x1, 20+y1, "ReaTrak Sections", true, 1)

--GUI.New("sect_help_btn",      "Button",           3, 225+x1, 32+y1, 40, 17, "HELP", btn_click_sect_help)
--GUI.elms.sect_help_btn.col_txt = "btn_txt1"
--GUI.elms.sect_help_btn.col_fill = "green"
--GUI.elms.sect_help_btn.font = ("version")

--GUI.New("lb_Sect_info",      "Label",           3, 285+x1, 32+y1, "set the chord region to the song section", true, 3)

--Label          name,      z,      x,      y,          caption[, shadow, font, color, bg]
--os_type = reaper.GetOS()
--poz = 656 font_type = "i" font_size = 50
--if os_type ~= "Win32" and os_type ~= "Win64" then poz = 670 font_type = "r" font_size = 56 end


--GUI.New("lb_reatrack",      "Label",           3, poz+x1, 10+y1, "REATRAK", true, 1, "verse_fill", "wnd_bg" )
--GUI.elms.lb_reatrack.col_txt = "verse_fill"
--GUI.elms.lb_reatrack.font = {"Impact", font_size, font_type}
--GUI.elms.lb_reatrack.font = {"LeagueGothic-CondensedItalic", font_size, font_type}

--GUI.New("lb_studio",      "Label",           3, 734+x1, 17+y1, "Studio", true, 1, "white", "wnd_bg" )
--GUI.elms.lb_studio.col_txt = "verse_fill"
--GUI.elms.lb_studio.font = {"Arial", 40, "bi"}
--[[

GUI.New("count_in_btn",      "Button",           3, 16+x1, 65+y1, 70, 20, "Count-In", btn_click_count_in)
GUI.elms.count_in_btn.col_txt = "btn_txt3"
GUI.elms.count_in_btn.col_fill = "count_in" 

GUI.New("intro_post_fill_btn",      "Button",           3, 90+x1, 65+y1, 95, 20, "Intro Post Fill", btn_click_intro_post_fill)
GUI.elms.intro_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.intro_post_fill_btn.col_fill = "intro_post_fill" 

GUI.New("intro_btn",      "Button",           3, 190+x1, 65+y1, 60, 20, "Intro", btn_click_intro)
GUI.elms.intro_btn.col_txt = "btn_txt1"
GUI.elms.intro_btn.col_fill = "intro"

GUI.New("intro_fill_btn",      "Button",           3, 255+x1, 65+y1, 60, 20, "Intro Fill", btn_click_intro_fill)
GUI.elms.intro_fill_btn.col_txt = "btn_txt3"
GUI.elms.intro_fill_btn.col_fill = "intro_fill"

GUI.New("verse_post_fill_btn",      "Button",           3, 320+x1, 65+y1, 95, 20, "Verse Post Fill", btn_click_verse_post_fill)
GUI.elms.verse_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.verse_post_fill_btn.col_fill = "verse_post_fill"

GUI.New("verse_btn",      "Button",           3, 420+x1, 65+y1, 65, 20, "Verse", btn_click_verse)
GUI.elms.verse_btn.col_txt = "btn_txt1"
GUI.elms.verse_btn.col_fill = "verse"

GUI.New("verse_fill_btn",      "Button",           3, 490+x1, 65+y1, 70, 20, "Verse Fill", btn_click_verse_fill)
GUI.elms.verse_fill_btn.col_txt = "btn_txt3"
GUI.elms.verse_fill_btn.col_fill = "verse_fill"

GUI.New("verse_ending_btn",      "Button",           3, 565+x1, 65+y1, 90, 20, "Verse Ending ", btn_click_verse_ending)
GUI.elms.verse_ending_btn.col_txt = "btn_txt3"
GUI.elms.verse_ending_btn.col_fill = "verse_ending"

GUI.New("set_drum_riff_btn1",      "Button",           3, 660+x1, 65+y1, 75, 20, "Drum Riff", btn_click_set_drum_riff_btn1)
GUI.elms.set_drum_riff_btn1.col_txt = "btn_txt1"
GUI.elms.set_drum_riff_btn1.col_fill = "drum_riff"

-- Sections Row 2
 
GUI.New("bridge_post_fill_btn",      "Button",           3, 16+x1, 95+y1, 95, 20, "Bridge Post Fill", btn_click_bridge_post_fill)
GUI.elms.bridge_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.bridge_post_fill_btn.col_fill = "bridge_post_fill" 

GUI.New("bridge_btn",      "Button",           3, 115+x1, 95+y1, 60, 20, "Bridge", btn_click_bridge)
GUI.elms.bridge_btn.col_txt = "btn_txt3"
GUI.elms.bridge_btn.col_fill = "bridge"

GUI.New("bridge_fill_btn",      "Button",           3, 180+x1, 95+y1, 70, 20, "Bridge Fill", btn_click_bridge_fill)
GUI.elms.bridge_fill_btn.col_txt = "btn_txt3"
GUI.elms.bridge_fill_btn.col_fill = "bridge_fill"

GUI.New("pre_chorus_post_fill_btn",      "Button",           3, 255+x1, 95+y1, 115, 20, "Pre Chorus Post Fill", btn_click_pre_chorus_post_fill)
GUI.elms.pre_chorus_post_fill_btn.col_txt = "btn_txt3"
GUI.elms.pre_chorus_post_fill_btn.col_fill = "pre_chorus_post_fill"

GUI.New("pre_chorus_btn",      "Button",           3, 375+x1, 95+y1, 75, 20, "Pre Chorus", btn_click_pre_chorus)
GUI.elms.pre_chorus_btn.col_txt = "btn_txt3"
GUI.elms.pre_chorus_btn.col_fill = "pre_chorus"

GUI.New("pre_chorus_fill_btn",      "Button",           3, 455+x1, 95+y1, 95, 20, "Pre Chorus Fill", btn_click_pre_chorus_fill)
GUI.elms.pre_chorus_fill_btn.col_txt = "btn_txt3"
GUI.elms.pre_chorus_fill_btn.col_fill = "pre_chorus_fill"

GUI.New("chorus_post_fill_btn",      "Button",           3, 555+x1, 95+y1, 95, 20, "Chorus Post Fill", btn_click_chorus_post_fill)
GUI.elms.chorus_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.chorus_post_fill_btn.col_fill = "chorus_post_fill"

GUI.New("chorus_btn",      "Button",           3, 655+x1, 95+y1, 55, 20, "Chorus", btn_click_chorus)
GUI.elms.chorus_btn.col_txt = "btn_txt1"
GUI.elms.chorus_btn.col_fill = "chorus"

GUI.New("chorus_fill_btn",      "Button",           3, 715+x1, 95+y1, 70, 20, "Chorus Fill", btn_click_chorus_fill)
GUI.elms.chorus_fill_btn.col_txt = "btn_txt3"
GUI.elms.chorus_fill_btn.col_fill = "chorus_fill"

GUI.New("chorus_ending_btn",      "Button",           3, 790+x1, 95+y1, 90, 20, "Chorus Ending ", btn_click_chorus_ending)
GUI.elms.chorus_ending_btn.col_txt = "btn_txt3"
GUI.elms.chorus_ending_btn.col_fill = "chorus_ending"

-- Sections Row 2


GUI.New("rest_btn",      "Button",           3, 375+x1, 125+y1, 40, 20, "Rest", btn_click_rest)
GUI.elms.rest_btn.col_txt = "btn_txt1"
GUI.elms.rest_btn.col_fill = "rest"

GUI.New("shot_btn",      "Button",           3, 420+x1, 125+y1, 40, 20, "Shot", btn_click_shot)
GUI.elms.shot_btn.col_txt = "btn_txt1"
GUI.elms.shot_btn.col_fill = "shot"

GUI.New("hold_btn",      "Button",           3, 465+x1, 125+y1, 40, 20, "Hold", btn_click_hold)
GUI.elms.hold_btn.col_txt = "btn_txt3"
GUI.elms.hold_btn.col_fill = "hold"

GUI.New("btn_frm",     "Frame",          3, 0, 156, GUI.w, 4, true, true)

--]]
------------------------------------
-------- Subwindow and -------------
-------- its elements  -------------
------------------------------------


GUI.New("wnd_test", "Window", 10, 0, 0, 312, 244, "Dialog Box", {9, 10})
GUI.New("lbl_elms", "Label", 9, 16, 16, "", false, 4)
GUI.New("lbl_vals", "Label", 9, 96, 16, "", false, 4, nil, elm_bg)
GUI.New("btn_close", "Button", 9, 0, 184, 48, 24, "OK", wnd_OK)

-- We want these elements out of the way until the window is opened
GUI.elms_hide[9] = true
GUI.elms_hide[10] = true


-- :onopen is a hook provided by the Window class. This function will be run
-- every time the window opens.
function GUI.elms.wnd_test:onopen()
    
    -- :adjustelm places the element's specified x,y coordinates relative to
    -- the Window. i.e. creating an element at 0,0 and adjusting it will put
    -- the element in the Window's top-left corner.
    self:adjustelm(GUI.elms.btn_close)
    
    -- Buttons look nice when they're centered.
    GUI.elms.btn_close.x, _ = GUI.center(GUI.elms.btn_close, self)    
    
    self:adjustelm(GUI.elms.lbl_elms)
    self:adjustelm(GUI.elms.lbl_vals)
    
    -- Set the Window's title
  local tab_num = GUI.Val("tabs")
    self.caption = "Element values for Tab " .. tab_num
  
    -- This Window provides a readout of the values for every element
    -- on the current tab.
    local strs_v, strs_val = get_values_for_tab(tab_num)
    
    GUI.Val("lbl_elms", table.concat(strs_v, "\n"))
    GUI.Val("lbl_vals", table.concat(strs_val, "\n"))
    
end

---------------------------------------------------------------------
--Chords Tab 3 (layers 2,5)
---------------------------------------------------------------------

--Chord Input

local function chord_input()
   --[[
   retval, num_markers, num_regionsOut = reaper.CountProjectMarkers(0)
   
   desired_region_id = num_regionsOut
   
   time = reaper.GetCursorPosition()
   
   markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, time)
   
   retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, regionidx)
   
   if time == pos then goto finish end
   
   if time < rgnend then
   
   reaper.SetProjectMarker3( 0, markrgnindexnumber, 1, pos, time, name, color )
   
   reaper.AddProjectMarker2(0, 1, time, rgnend, name, desired_region_id, color)
   
   goto finish 
   end
   
   ::finish::
   
    time = reaper.GetCursorPosition()
    markrgnindexnumber, rgnendOut = reaper.GetLastMarkerAndCurRegion(0, time)
    retval, isrgnOut, posOut, rgnendOut, nameOut, markrgnindexnumberOut = reaper.EnumProjectMarkers(rgnendOut)
    clear_name_flag = 0 --this flag is needed in the SetProjectMarker4 function to enable the region name to be cleared
   --]]
    root_numbers = GUI.Val("root_choice2")
    root_names = { [1] = "C", [2] = "C#", [3] = "Db", [4] = "D", [5] = "D#", [6] = "Eb", [7] = "E", [8] = "F", [9] = "F#", [10] = "Gb", [11] = "G", [12] = "G#", [13] = "Ab", [14] = "A", [15] = "A#", [16] = "Bb", [17] = "B"}
    root_name = root_names[root_numbers]    
      
    --root_name = GUI.elms.root_choice.optarray[ GUI.Val("root_choice") ]
    newName = (root_name .. chord_type) --newName = ("C" .. chord_type)
    write_markers(newName)
--Msg(newName)
    --[[
    --- if newName == "" then clear_name_flag = 1 end --if removing the -L leaves an empty name string pass the 1 flag to clear name
    reaper.SetProjectMarker4(0, markrgnindexnumberOut, true, posOut, rgnendOut, newName, 0, clear_name_flag)
    chord_type = ""
    commandID74 = reaper.NamedCommandLookup("_RSce47da3c9b1238de71cc94a1cb99732b9abd5e41")
    reaper.Main_OnCommand(commandID74, 0) -- Script: ReaTrak Go to start of next region.lua
    commandID75 = reaper.NamedCommandLookup("_RS0b4230c08f384a4318c16aac4e2404c9fef86887")
    reaper.Main_OnCommand(commandID75, 0) -- Script: ReaTrak Snap all regions to grid.eel
    --]] 
end
    
  
local function chord_input2()
   --[[
   retval, num_markers, num_regionsOut = reaper.CountProjectMarkers(0)
   
   desired_region_id = num_regionsOut
   
   time = reaper.GetCursorPosition()
   
   markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, time)
   
   retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, regionidx)
   
   if time == pos then goto finish end
   
   if time < rgnend then
   
   reaper.SetProjectMarker3( 0, markrgnindexnumber, 1, pos, time, name, color )
   
   reaper.AddProjectMarker2(0, 1, time, rgnend, name, desired_region_id, color)
   
   goto finish 
   end
   
   ::finish::
   
    time = reaper.GetCursorPosition()
    markrgnindexnumber, rgnendOut = reaper.GetLastMarkerAndCurRegion(0, time)
    retval, isrgnOut, posOut, rgnendOut, nameOut, markrgnindexnumberOut = reaper.EnumProjectMarkers(rgnendOut)
    clear_name_flag = 0 --this flag is needed in the SetProjectMarker4 function to enable the region name to be cleared
   --]]
    root_numbers = GUI.Val("root_choice2")
    root_names = { [1] = "C", [2] = "C#", [3] = "Db", [4] = "D", [5] = "D#", [6] = "Eb", [7] = "E", [8] = "F", [9] = "F#", [10] = "Gb", [11] = "G", [12] = "G#", [13] = "Ab", [14] = "A", [15] = "A#", [16] = "Bb", [17] = "B"}
    root_name = root_names[root_numbers]    
      
    --root_name = GUI.elms.root_choice.optarray[ GUI.Val("root_choice") ]
    newName = (root_name .. chord_type) --newName = ("C" .. chord_type)
    write_markers(newName)
--Msg(newName)
    --[[
    --- if newName == "" then clear_name_flag = 1 end --if removing the -L leaves an empty name string pass the 1 flag to clear name
    reaper.SetProjectMarker4(0, markrgnindexnumberOut, true, posOut, rgnendOut, newName, 0, clear_name_flag)
    chord_type = ""
    commandID74 = reaper.NamedCommandLookup("_RSce47da3c9b1238de71cc94a1cb99732b9abd5e41")
    reaper.Main_OnCommand(commandID74, 0) -- Script: ReaTrak Go to start of next region.lua
    commandID75 = reaper.NamedCommandLookup("_RS0b4230c08f384a4318c16aac4e2404c9fef86887")
    reaper.Main_OnCommand(commandID75, 0) -- Script: ReaTrak Snap all regions to grid.eel
    --]] 
end   


-- Major Chords Functions        
    
function btn_click_Maj()
    chord_type = ""
    chord_input ()
    end  

function btn_click_6()
    chord_type = "6"
    chord_input ()
    end         
    
function btn_click_6sus4()
    chord_type = "6sus4"
    chord_input ()
    end         

function btn_click_69()
    chord_type = "69"
    chord_input ()
    end         

function btn_click_Maj7()
    chord_type = "Maj7"
    chord_input ()
    end         

function btn_click_Maj7b5()
    chord_type = "Maj7b5"
    chord_input ()
    end         

function btn_click_Maj7s5()
    chord_type = "Maj7#5"
    chord_input ()
    end         

function btn_click_Maj7s11()
    chord_type = "Maj7#11"
    chord_input ()
    end 

function btn_click_Maj7add13()
    chord_type = "Maj7add13"
    chord_input ()
    end         

function btn_click_Maj9()
    chord_type = "Maj9"
    chord_input ()
    end         

function btn_click_Maj9sus4()
    chord_type = "Maj9sus4"
    chord_input ()
    end         

function btn_click_Maj9s5()
    chord_type = "Maj9#5"
    chord_input ()
    end         

function btn_click_Maj9s11()
    chord_type = "Maj9#11"
    chord_input ()
    end         

function btn_click_Maj11()
    chord_type = "Maj11"
    chord_input ()
    end         

function btn_click_Maj13()
    chord_type = "Maj13"
    chord_input ()
    end 

function btn_click_Maj13s11()
    chord_type = "Maj13#11"
    chord_input ()
    end 

      

    
-- Major Chords Buttons 
-- Button Position Adjustment add e.g x = -10 or x = 0 or x = 10
x5 = 0
y5 = 0   
    

GUI.New("lb_Major",      "Label",           4, 20+x5, 20+y5, "Major", true, 1)
GUI.New("chord_Maj",      "Button",           4, 16+x5, 55+y5, 85, 20, "Maj", btn_click_Maj)
GUI.New("chord_Maj6",      "Button",           4, 16+x5, 80+y5, 85, 20, "6", btn_click_6)
GUI.New("chord_Maj6sus4",      "Button",           4, 16+x5, 105+y5, 85, 20, "6sus4", btn_click_6sus4)
GUI.New("chord_Maj69",      "Button",           4, 16+x5, 130+y5, 85, 20, "69", btn_click_69)
GUI.New("chord_Maj7",      "Button",           4, 16+x5, 155+y5, 85, 20, "Maj7", btn_click_Maj7)
GUI.New("chord_Maj7b5",      "Button",           4, 16+x5, 180+y5, 85, 20, "Maj7b5", btn_click_Maj7b5)
GUI.New("chord_Maj7#5",      "Button",           4, 16+x5, 205+y5, 85, 20, "Maj7#5", btn_click_Maj7s5)
GUI.New("chord_Maj7#11",      "Button",           4, 16+x5, 230+y5, 85, 20, "Maj7#11", btn_click_Maj7s11)
GUI.New("chord_Maj7add13",      "Button",           4, 16+x5, 255+y5, 85, 20, "Maj7add13", btn_click_Maj7add13)
GUI.New("chord_Maj9",      "Button",           4, 16+x5, 280+y5, 85, 20, "Maj9", btn_click_Maj9)
GUI.New("chord_Maj9sus4",      "Button",           4, 16+x5, 305+y5, 85, 20, "Maj9sus4", btn_click_Maj9sus4)
GUI.New("chord_Maj9#5",      "Button",           4, 16+x5, 330+y5, 85, 20, "Maj9#5", btn_click_Maj9s5)
GUI.New("chord_Maj9#11",      "Button",           4, 16+x5, 355+y5, 85, 20, "Maj9#11", btn_click_Maj9s11)
GUI.New("chord_Maj11",      "Button",           4, 16+x5, 380+y5, 85, 20, "Maj11", btn_click_Maj11)
GUI.New("chord_Maj13",      "Button",           4, 16+x5, 405+y5, 85, 20, "Maj13", btn_click_Maj13)
GUI.New("chord_Maj13#11",      "Button",           4, 16+x5, 430+y5, 85, 20, "Maj13#11", btn_click_Maj13s11)

-- Major Chords Buttons Column 2
--GUI.New("chord_Maj2",      "Button",           5, 105+x5, 55+y5, 85, 20, "Maj", btn_click_Maj)


--GUI.New("btn_frm5",     "Frame",          5, 0, 465, 300, 4, true, true)
--GUI.New("btn_frm6",     "Frame",          5, 298, 465, 4, 160, true, true)
--GUI.New("btn_frm7",     "Frame",          5, 0, 620, 300, 4, true, true)



function btn_click_dim()
    chord_type = "dim"
    chord_input ()
    end

function btn_click_dim7()
    chord_type = "dim7"
    chord_input ()
    end
function btn_click_m7b5()
    chord_type = "m7b5"
    chord_input ()
    end

function btn_click_m9b5()
    chord_type = "m9b5"
    chord_input ()
    end




--Diminished Chords Buttons

GUI.New("lb_Dim",      "Label",           4, 40+x5, 470+y5, "Dim", true, 1)
GUI.New("chord_dim",      "Button",           4, 16+x5, 505+y5, 85, 20, "dim", btn_click_dim)
GUI.New("chord_dim7",      "Button",           4, 16+x5,530+y5, 85, 20, "dim7", btn_click_dim7)
GUI.New("chord_m7b5",      "Button",           4, 16+x5,555+y5, 85, 20, "m7b5", btn_click_m7b5)
GUI.New("chord_m9b5",      "Button",           4, 16+x5, 580+y5, 85, 20, "m9b5", btn_click_m9b5)



--Minor Chords Functions

function btn_click_m()
    chord_type = "m"
    chord_input ()
    end         

function btn_click_ms5()
    chord_type = "m#5"
    chord_input ()
    end 
    
function btn_click_m6()
    chord_type = "m6"
    chord_input ()
    end         

function btn_click_m6add9()
    chord_type = "m6add9"
    chord_input ()
    end         

function btn_click_m7()
    chord_type = "m7"
    chord_input ()
    end         

function btn_click_m7b9()
    chord_type = "m7b9"
    chord_input ()
    end         

function btn_click_m7add11()
    chord_type = "m7add11"
    chord_input ()
    end         

function btn_click_m7add13()
    chord_type = "m7add13"
    chord_input ()
    end         

function btn_click_mMaj7add13()
    chord_type = "mMaj7add13"
    chord_input ()
    end

function btn_click_mMaj7()
    chord_type = "mMaj7"
    chord_input ()
    end         

function btn_click_mMaj7add11()
    chord_type = "mMaj7add11"
    chord_input ()
    end         

function btn_click_mMaj7add13()
    chord_type = "mMaj7add13"
    chord_input ()
    end         

function btn_click_m9()
    chord_type = "m9"
    chord_input ()
    end         

function btn_click_mMaj9()
    chord_type = "mMaj9"
    chord_input ()
    end         

function btn_click_m11()
    chord_type = "m11"
    chord_input ()
    end         

function btn_click_mMaj11()
    chord_type = "mMaj11"
    chord_input ()
    end         

function btn_click_m13()
    chord_type = "m13"
    chord_input ()
    end         

function btn_click_mMaj13()
    chord_type = "mMaj13"
    chord_input ()
    end         



--Minor Chords Buttons

GUI.New("lb_Minor",      "Label",           4, 195+x5, 20+y5, "Minor", true, 1)
GUI.New("chord_m",      "Button",           4, 193+x5, 55+y5, 85, 20, "m", btn_click_m)
GUI.New("chord_m#5",      "Button",           4, 193+x5, 80+y5, 85, 20, "m#5", btn_click_ms5)
GUI.New("chord_m6",      "Button",           4, 195+x5, 105+y5, 85, 20, "m6", btn_click_m6)
GUI.New("chord_madd9",      "Button",           4, 195+x5, 130+y5, 85, 20, "m6add9", btn_click_m6add9)
GUI.New("chord_m7",      "Button",           4, 195+x5, 155+y5, 85, 20, "m7", btn_click_m7)
GUI.New("chord_m7b9",      "Button",           4, 195+x5, 180+y5, 85, 20, "m7b9", btn_click_m7b9)
GUI.New("chord_m7add11",      "Button",           4, 195+x5, 205+y5, 85, 20, "m7add11", btn_click_m7add11)
GUI.New("chord_m7add13",      "Button",           4, 195+x5, 230+y5, 85, 20, "m7add13", btn_click_m7add13)
GUI.New("chord_m7b5(2)",      "Button",           4, 193+x5, 255+y5, 85, 20, "m7b5", btn_click_m7b5)
GUI.New("chord_m7#5(2)",      "Button",           4, 193+x5, 280+y5, 85, 20, "m7#5", btn_click_m7s5)
GUI.New("chord_mMaj7",      "Button",           4, 195+x5, 305+y5, 85, 20, "mMaj7", btn_click_mMaj7)
GUI.New("chord_mMaj7add11",      "Button",           4, 195+x5, 330+y5, 85, 20, "mMaj7add1", btn_click_mMaj7add11)
GUI.New("chord_mMaj7add13",      "Button",           4, 195+x5, 355+y5, 85, 20, "mMaj7add13", btn_click_mMaj7add13)
GUI.New("chord_m9",      "Button",           4, 195+x5, 380+y5, 85, 20, "m9", btn_click_m9)
GUI.New("chord_mMaj9",      "Button",           4, 195+x5, 405+y5, 85, 20, "mMaj9", btn_click_mMaj9)
GUI.New("chord_m11",      "Button",           4, 195+x5, 430+y5, 85, 20, "m11", btn_click_m11)

--Minor Chords Buttons Column 2

GUI.New("chord_mMaj11",      "Button",           4, 281+x5, 55+y5, 85, 20, "mMaj11", btn_click_mMaj11)
GUI.New("chord_m13",      "Button",           4, 281+x5, 80+y5, 85, 20, "m13", btn_click_m13)
GUI.New("chord_mMaj13",      "Button",           4, 281+x5, 105+y5, 85, 20, "mMaj13", btn_click_mMaj13)


--Augmented Chords Buttons Fuctions

function btn_click_aug()
    chord_type = "aug"
    chord_input ()
    end

function btn_click_aug7()
    chord_type = "aug7"
    chord_input ()
    end


--Augmented Chords Buttons

GUI.New("lb_Aug",      "Label",           4, 200+x5, 470+y5, "Aug", true, 1)
GUI.New("chord_Aug",      "Button",           4, 195+x5, 505+y5, 85, 20, "aug", btn_click_aug)
GUI.New("chord_Aug7",      "Button",           4, 195+x5, 530+y5, 85, 20, "aug7", btn_click_aug7)




--Dominant Chords Buttons Functions

function btn_click_7()
    chord_type = "7"
    chord_input ()
    end  

function btn_click_7b5()
    chord_type = "7b5"
    chord_input ()
    end         
    
function btn_click_7s5()
    chord_type = "7#5"
    chord_input ()
    end         

function btn_click_7b9()
    chord_type = "7b9"
    chord_input ()
    end         

function btn_click_7s9()
    chord_type = "7#9"
    chord_input ()
    end         

function btn_click_7b5b9()
    chord_type = "7b5b9"
    chord_input ()
    end         

function btn_click_7b5b13()
    chord_type = "7b5b13"
    chord_input ()
    end 
    
function btn_click_7b5b9b13()
    chord_type = "7b5b9b13"
    chord_input ()
    end   
  
function btn_click_7b5s9()
    chord_type = "7b5#9"
    chord_input ()
    end 

function btn_click_7b9b13()
    chord_type = "7b9b13"
    chord_input ()
    end

function btn_click_7b9s13()
    chord_type = "7b9#s13"
    chord_input ()
    end
    
function btn_click_7b5s9()
    chord_type = "7b5#9"
    chord_input ()
    end

function btn_click_7b9s11()
    chord_type = "7b9#11"
    chord_input ()
    end

function btn_click_7b9s11b13()
    chord_type = "7b9#11b13"
    chord_input ()
    end
    
function btn_click_7b13()
    chord_type = "7b13"
    chord_input ()
    end

function btn_click_7s5b9()
    chord_type = "7#5b9"
    chord_input ()
    end
              
function btn_click_7add11()
    chord_type = "7add11"
    chord_input ()
    end         

function btn_click_7s5s9()
    chord_type = "7#5#9"
    chord_input ()
    end

function btn_click_7s5s11()
    chord_type = "7#5#11"
    chord_input ()
    end

function btn_click_7s5s11b13()
    chord_type = "7#5#11b13"
    chord_input ()
    end  

function btn_click_7b9s13()
    chord_type = "7b9#13"
    chord_input ()
    end
function btn_click_7s9b13()
    chord_type = "7#9b13"
    chord_input ()
    end
function btn_click_9b5b13()
    chord_type = "9b5b13"
    chord_input ()
    end 

function btn_click_9s5s11()
    chord_type = "9#5#11"
    chord_input ()
    end

function btn_click_9s11b13()
    chord_type = "9#11b13"
    chord_input ()
    end
          
function btn_click_7s11()
    chord_type = "7#11"
    chord_input ()
    end 

function btn_click_7s11b13()
    chord_type = "7#11b13"
    chord_input ()
    end
    
function btn_click_7add13()
    chord_type = "7add13"
    chord_input ()
    end         


--Dominant Chords Buttons Functions Column 2

function btn_click_9()
    chord_type = "9"
    chord_input ()
    end         

function btn_click_9b5()
    chord_type = "9b5"
    chord_input ()
    end         

function btn_click_9s5()
    chord_type = "9#5"
    chord_input ()
    end         

function btn_click_9s11()
    chord_type = "9#11"
    chord_input ()
    end         

function btn_click_9b13()
    chord_type = "9b13"
    chord_input ()
    end         

function btn_click_11()
    chord_type = "11"
    chord_input ()
    end         

function btn_click_11b9()
    chord_type = "11b9"
    chord_input ()
    end         

function btn_click_13()
    chord_type = "13"
    chord_input ()
    end         

function btn_click_13b5()
    chord_type = "13b5"
    chord_input ()
    end         

function btn_click_13b5b9()
    chord_type = "13b5b9"
    chord_input ()
    end
    
function btn_click_13b9()
    chord_type = "13b9"
    chord_input ()
    end  
     
function btn_click_13b9s11()
    chord_type = "13b9#11"
    chord_input ()
    end
    
function btn_click_13s5()
    chord_type = "13#5"
    chord_input ()
    end    

function btn_click_13s5b9()
    chord_type = "13#5b9"
    chord_input ()
    end

function btn_click_13s5s11()
    chord_type = "13#5#11"
    chord_input ()
    end
    
function btn_click_13s5b9s11()
    chord_type = "13#5b9#11"
    chord_input ()
    end

function btn_click_13s5s9s11()
    chord_type = "13#5#9#11"
    chord_input ()
    end
        
function btn_click_13s9()
    chord_type = "13#9"
    chord_input ()
    end         

function btn_click_13s9s11()
    chord_type = "13#9#11"
    chord_input ()
    end
      
function btn_click_13s11()
    chord_type = "13#11"
    chord_input ()
    end





--Dominant Chords Buttons

GUI.New("lb_Dom",      "Label",           4, 370+x5, 20+y5, "Dom", true, 1)
GUI.New("chord_7",      "Button",           4, 369+x5, 55+y5, 85, 20, "7", btn_click_7)
GUI.New("chord_7b5",      "Button",           4, 369+x5, 80+y5, 85, 20, "7b5", btn_click_7b5)
GUI.New("chord_7b5b9",      "Button",           4, 369+x5, 105+y5, 85, 20, "7b5b9", btn_click_7b5b9)
GUI.New("chord_7b5b13",      "Button",           4, 369+x5, 130+y5, 85, 20, "7b5b13", btn_click_7b5b13)
GUI.New("chord_7b5b9b13",      "Button",           4, 369+x5, 155+y5, 85, 20, "7b5b9b13", btn_click_7b5b9b13)
GUI.New("chord_7b5#9",      "Button",           4, 369+x5, 180+y5, 85, 20, "7b5#9", btn_click_7b5s9)
GUI.New("chord_7b9",      "Button",           4, 369+x5, 205+y5, 85, 20, "7b9", btn_click_7b9)
GUI.New("chord_7b9b13",      "Button",           4, 369+x5, 230+y5, 85, 20, "7b9b13", btn_click_7b9b13)
GUI.New("chord_7b9#11",      "Button",           4, 369+x5, 255+y5, 85, 20, "7b9#11", btn_click_7b9s11)
GUI.New("chord_7b9#11b13",      "Button",           4, 369+x5, 280+y5, 85, 20, "7b9#11b13", btn_click_7b9s11b13)
GUI.New("chord_7b13",      "Button",           4, 369+x5, 305+y5, 85, 20, "7b13", btn_click_7b13)
GUI.New("chord_7#5b9",      "Button",           4, 369+x5, 330+y5, 85, 20, "7#5b9", btn_click_7s5b9)
GUI.New("chord_7#5",      "Button",           4, 369+x5, 355+y5, 85, 20, "7#5", btn_click_7s5)
GUI.New("chord_7#5#9",      "Button",           4, 369+x5, 380+y5, 85, 20, "7#5#9", btn_click_7s5s9)
GUI.New("chord_7#5#11",      "Button",           4, 369+x5, 405+y5, 85, 20, "7#5#11", btn_click_7s5s11)
GUI.New("chord_7#9",      "Button",           4, 369+x5, 430+y5, 85, 20, "7#9", btn_click_7s9)
GUI.New("chord_7#9#11b13",      "Button",           4, 369+x5, 455+y5, 85, 20, "7#9#11b13", btn_click_7s9s11b13)
GUI.New("chord_7#9b13",      "Button",           4, 369+x5, 480+y5, 85, 20, "7#9b13", btn_click_7s9b13)
GUI.New("chord_7#11",      "Button",           4, 369+x5, 505+y5, 85, 20, "7#11", btn_click_7s11)
GUI.New("chord_7#11b13",      "Button",           4, 369+x5, 530+y5, 85, 20, "7#11b13", btn_click_7s11b13)
GUI.New("chord_7add11",      "Button",           4, 369+x5, 555+y5, 85, 20, "7add11", btn_click_7add11)
GUI.New("chord_7add13",      "Button",           4, 369+x5, 580+y5, 85, 20, "7add13", btn_click_7add13)

--Dominant Chords Buttons Column 2

GUI.New("chord_9",      "Button",           4, 457+x5, 55+y5, 85, 20, "9", btn_click_9)
GUI.New("chord_9b5",      "Button",           4, 457+x5, 80+y5, 85, 20, "9b5", btn_click_9b5)
GUI.New("chord_9b5b13",      "Button",           4, 457+x5, 105+y5, 85, 20, "9b5b13", btn_click_9b5b13)
GUI.New("chord_9b13",      "Button",           4, 457+x5, 130+y5, 85, 20, "9b13", btn_click_9b13)
GUI.New("chord_9#5",      "Button",           4, 457+x5, 155+y5, 85, 20, "9#5", btn_click_9s5)
GUI.New("chord_9#5#11",      "Button",           4, 457+x5, 180+y5, 85, 20, "9#5#11", btn_click_9s5s11)
GUI.New("chord_9#11",      "Button",           4, 457+x5, 205+y5, 85, 20, "9#11", btn_click_9s11)
GUI.New("chord_9#11b13",      "Button",           4, 457+x5, 230+y5, 85, 20, "9#11b13", btn_click_9s11b13)
GUI.New("chord_11",      "Button",           4, 457+x5, 255+y5, 85, 20, "11", btn_click_11)
GUI.New("chord_11b9",      "Button",           4, 457+x5, 280+y5, 85, 20, "11b9", btn_click_11b9)
GUI.New("chord_13",      "Button",           4, 457+x5, 305+y5, 85, 20, "13", btn_click_13)
GUI.New("chord_13b5",      "Button",           4, 457+x5, 330+y5, 85, 20, "13b5", btn_click_13b5)
GUI.New("chord_13b5b9",      "Button",           4, 457+x5, 355+y5, 85, 20, "13b5b9", btn_click_13b5b9)
GUI.New("chord_13b9",      "Button",           4, 457+x5, 380+y5, 85, 20, "13b9", btn_click_13b9)
GUI.New("chord_13b9#11",      "Button",           4, 457+x5, 405+y5, 85, 20, "13b9#11", btn_click_13b9s11)
GUI.New("chord_13#5",      "Button",           4, 457+x5, 430+y5, 85, 20, "13#5", btn_click_13s5)
GUI.New("chord_13#5b9",      "Button",           4, 457+x5, 455+y5, 85, 20, "13#5b9", btn_click_13s5b9)
GUI.New("chord_13#5b9#11",      "Button",           4, 457+x5, 480+y5, 85, 20, "13#5b9#11", btn_click_13s5b9s11)
GUI.New("chord_13#5#9#11",      "Button",           4, 457+x5, 505+y5, 85, 20, "13#5#9#11", btn_click_13s5s9s11)
GUI.New("chord_13#5#11",      "Button",           4, 457+x5, 530+y5, 85, 20, "13#5#11", btn_click_13s5s11)
GUI.New("chord_13#9",      "Button",           4, 457+x5, 555+y5, 85, 20, "13#9", btn_click_13s9)
GUI.New("chord_13#9#11",      "Button",           4, 457+x5, 580+y5, 85, 20, "13#9#11", btn_click_13s9s11)
GUI.New("chord_13#11",      "Button",           4, 457+x5, 605+y5, 85, 20, "13#11", btn_click_13s11)


--Suspended Chords Buttons Fuctions

function btn_click_sus2()
    chord_type = "sus2"
    chord_input ()
    end


function btn_click_7sus2()
    chord_type = "7sus2"
    chord_input ()
    end
    
function btn_click_9sus2()
    chord_type = "9sus2"
    chord_input ()
    end

function btn_click_sus4()
    chord_type = "7sus"
    chord_input ()
    end
    
function btn_click_7sus4()
    chord_type = "7sus4"
    chord_input ()
    end    

function btn_click_9sus4()
    chord_type = "9sus4"
    chord_input ()
    end
    
function btn_click_7susb5()
    chord_type = "7susb5"
    chord_input ()
    end

function btn_click_7susb5b9()
    chord_type = "7susb5b9"
    chord_input ()
    end
function btn_click_7susb5b9b13()
    chord_type = "7susb5b9b13"
    chord_input ()
    end
function btn_click_7susb5b13()
    chord_type = "7susb5b13"
    chord_input ()
    end
function btn_click_7susb5s9()
    chord_type = "7susb5#9"
    chord_input ()
    end
function btn_click_7susb5s9b13()
    chord_type = "7susb5#9b13"
    chord_input ()
    end
function btn_click_7susb9()
    chord_type = "7susb9"
    chord_input ()
    end
function btn_click_7susb9b13()
    chord_type = "7susb9b13"
    chord_input ()
    end
function btn_click_7susb9s11()
    chord_type = "7susb9s11"
    chord_input ()
    end
function btn_click_7susb9s11b13()
    chord_type = "7susb9#11b13"
    chord_input ()
    end
function btn_click_7susb13()
    chord_type = "7susb13"
    chord_input ()
    end
function btn_click_7suss5()
    chord_type = "7sus#5"
    chord_input ()
    end
function btn_click_7suss5b9()
    chord_type = "7sus#5b9"
    chord_input ()
    end
function btn_click_7suss5s9()
    chord_type = "7sus#5#9"
    chord_input ()
    end
function btn_click_7suss5s9s11()
    chord_type = "7sus#5#9#11"
    chord_input ()
    end
function btn_click_7suss5s11()
    chord_type = "7sus#5#11"
    chord_input ()
    end
function btn_click_7suss9()
    chord_type = "7sus#9"
    chord_input ()
    end
function btn_click_7suss9b13()
    chord_type = "7sus#9b13"
    chord_input ()
    end
function btn_click_7suss9s11b13()
    chord_type = "7sus#9#11b13"
    chord_input ()
    end
function btn_click_7suss11()
    chord_type = "7sus#11"
    chord_input ()
    end
function btn_click_7suss11b13()
    chord_type = "7sus#11b13"
    chord_input ()
    end

function btn_click_9sus()
    chord_type = "9sus"
    chord_input ()
    end

function btn_click_9susb5()
    chord_type = "9susb5"
    chord_input ()
    end
    
function btn_click_9susb5b13()
    chord_type = "9susb5b13"
    chord_input ()
    end
    
function btn_click_9suss11()
    chord_type = "9sus#11"
    chord_input ()
    end
    
function btn_click_9suss5()
    chord_type = "9sus#5"
    chord_input ()
    end
    
function btn_click_9suss5s11()
    chord_type = "9sus#5#11"
    chord_input ()
    end
    
function btn_click_13sus()
    chord_type = "13sus"
    chord_input ()
    end
    
function btn_click_13susb5()
    chord_type = "13susb5"
    chord_input ()
    end
    
function btn_click_13susb5s9()
    chord_type = "13susb5#9"
    chord_input ()
    end

function btn_click_13susb5b9()
    chord_type = "13susb5b9"
    chord_input ()
    end
    
function btn_click_13susb9()
    chord_type = "13susb9"
    chord_input ()
    end
    
function btn_click_13susb9s11()
    chord_type = "13susb9#11"
    chord_input ()
    end
    
function btn_click_13suss5()
    chord_type = "13sus#5"
    chord_input ()
    end
    
function btn_click_13suss5b9()
    chord_type = "13sus#5b9"
    chord_input ()
    end
    
function btn_click_13suss5b9s11()
    chord_type = "13sus#5b9#11"
    chord_input ()
    end
    
function btn_click_13suss5s11()
    chord_type = "13sus#5#11"
    chord_input ()
    end
    
function btn_click_13suss5s9s11()
    chord_type = "13sus#5#9#11"
    chord_input ()
    end
    
function btn_click_13suss9()
    chord_type = "13sus#9"
    chord_input ()
    end
    
function btn_click_13suss9s11()
    chord_type = "13sus#9#11"
    chord_input ()
    end
    
function btn_click_13suss11()
    chord_type = "13sus#11"
    chord_input ()
    end

function btn_click_quartal()
    chord_type = "quartal"
    chord_input ()
    end
function btn_click_sowhat()
    chord_type = "sowhat"
    chord_input ()
    end

--Suspended Chords Buttons

GUI.New("lb_Sus",      "Label",           4, 635+x5, 20+y5, "Suspended", true, 1)
GUI.New("lb_Sus2",      "Label",           4, 635+x5, 55+y5, "Sus2", true, 2)
GUI.New("chord_sus2",      "Button",           4, 635+x5, 80+y5, 85, 20, "sus2", btn_click_sus2)
GUI.New("chord_7sus2",      "Button",           4, 635+x5, 105+y5, 85, 20, "7sus2", btn_click_7sus2)
GUI.New("chord_9sus3",      "Button",           4, 635+x5, 130+y5, 85, 20, "9sus2", btn_click_9sus2)
GUI.New("chord_9sus4",      "Button",           4, 635+x5, 230+y5, 85, 20, "9sus4", btn_click_9sus4)
GUI.New("lb_Sus4",      "Label",           4, 640+x5, 155+y5, "Sus4", true, 2)

GUI.New("chord_sus4",      "Button",           4, 635+x5, 180+y5, 85, 20, "sus4", btn_click_sus4)
GUI.New("chord_7sus4",      "Button",           4, 635+x5, 205+y5, 85, 20, "7sus4", btn_click_7sus4)
GUI.New("chord_7susb5",      "Button",           4, 635+x5, 255+y5, 85, 20, "7susb5", btn_click_7susb5)
GUI.New("chord_7susb5b9",      "Button",           4, 635+x5, 280+y5, 85, 20, "7susb5b9", btn_click_7susb5b9)
GUI.New("chord_7susb5b9b13",      "Button",           4, 635+x5, 305+y5, 85, 20, "7susb5b9b13", btn_click_7susb5b9b13)
GUI.New("chord_7susb5b13",      "Button",           4, 635+x5, 330+y5, 85, 20, "7susb5b13", btn_click_7susb5b13)
GUI.New("chord_7susb5#9",      "Button",           4, 635+x5, 355+y5, 85, 20, "7susb5#9", btn_click_7susb5s9)
GUI.New("chord_7susb5#9b13",      "Button",           4, 635+x5, 380+y5, 85, 20, "7susb5#9b13", btn_click_7susb5s9b13)
GUI.New("chord_7susb9",      "Button",           4, 635+x5, 405+y5, 85, 20, "7susb9", btn_click_7susb9)
GUI.New("chord_7susb9b13",      "Button",           4, 635+x5, 430+y5, 85, 20, "7susb9b13", btn_click_7susb9b13)
GUI.New("chord_7susb9#11",      "Button",           4, 635+x5, 455+y5, 85, 20, "7susb9#11", btn_click_7susb9s11)
GUI.New("chord_7susb9#11b13",      "Button",           4, 635+x5, 480+y5, 85, 20, "7susb9#11b13", btn_click_7susb9s11b13)
GUI.New("chord_7susb13",      "Button",           4, 635+x5, 505+y5, 85, 20, "7susb13", btn_click_7susb13)
GUI.New("chord_7sus#5",      "Button",           4, 635+x5, 530+y5, 85, 20, "7sus#5", btn_click_7suss5)
GUI.New("chord_7sus#5b9",      "Button",           4, 635+x5, 555+y5, 85, 20, "7sus#5b9", btn_click_7suss5b9)
GUI.New("chord_7sus#5#9",      "Button",           4, 635+x5, 580+y5, 85, 20, "7sus#5#9", btn_click_7suss5s9)
GUI.New("chord_7sus#5#9#11",      "Button",           4, 635+x5, 605+y5, 85, 20, "7sus#5#9#11", btn_click_7suss5s9s11)



--Suspended Chords Buttons Column 2

GUI.New("chord_7sus#5#11",      "Button",           4, 725+x5, 55+y5, 85, 20, "7sus#5#11", btn_click_7suss5s11)
GUI.New("chord_7sus#9",      "Button",           4, 725+x5, 80+y5, 85, 20, "7sus#9", btn_click_7suss9)
GUI.New("chord_7sus#9b13",      "Button",           4, 725+x5, 105+y5, 85, 20, "7sus#9b13", btn_click_7suss9b13)
GUI.New("chord_7sus#9#11b13 ",      "Button",           4, 725+x5, 130+y5, 85, 20, "7sus#9#11b13", btn_click_7suss9s11b13 )
GUI.New("chord_7sus#11",      "Button",           4, 725+x5, 155+y5, 85, 20, "7sus#11", btn_click_7suss11)
GUI.New("chord_7sus#11b13",      "Button",           4, 725+x5, 180+y5, 85, 20, "7sus#11b13", btn_click_7suss11b13)

GUI.New("chord_9sus",      "Button",           4, 725+x5, 205+y5, 85, 20, "9sus", btn_click_9sus)
GUI.New("chord_9susb5",      "Button",           4, 725+x5, 230+y5, 85, 20, "9susb5", btn_click_9susb5)
GUI.New("chord_9susb5b13",      "Button",           4, 725+x5, 255+y5, 85, 20, "9susb5b13", btn_click_9susb5b13)
GUI.New("chord_9sus#11",      "Button",           4, 725+x5, 280+y5, 85, 20, "9sus#11", btn_click_9suss11)
GUI.New("chord_9sus#5",      "Button",           4, 725+x5, 305+y5, 85, 20, "9sus#5", btn_click_9suss5)
GUI.New("chord_9sus#5#11",      "Button",           4, 725+x5, 330+y5, 85, 20, "9sus#5#11", btn_click_9suss5s11)
GUI.New("chord_13sus",      "Button",           4, 725+x5, 355+y5, 85, 20, "13sus", btn_click_13sus)
GUI.New("chord_13susb5",      "Button",           4, 725+x5, 380+y5, 85, 20, "13susb5", btn_click_13susb5)
GUI.New("chord_13susb5#9",      "Button",           4, 725+x5, 405+y5, 85, 20, "13susb5#9", btn_click_13susb5s9)
GUI.New("chord_13susb5b9",      "Button",           4, 725+x5, 430+y5, 85, 20, "13susb5b9", btn_click_13susb5b9)
GUI.New("chord_13susb9",      "Button",           4, 725+x5, 455+y5, 85, 20, "13susb9", btn_click_13susb9)
GUI.New("chord_13susb9#11",      "Button",           4, 725+x5, 480+y5, 85, 20, "13susb9#11", btn_click_13susb9s11)
GUI.New("chord_13sus#5",      "Button",           4, 725+x5, 505+y5, 85, 20, "13sus#5", btn_click_13suss5)
GUI.New("chord_13sus#5b9",      "Button",           4, 725+x5, 530+y5, 85, 20, "13sus#5b9", btn_click_13suss5b9)
GUI.New("chord_13sus#5b9#11",      "Button",           4, 725+x5, 555+y5, 85, 20, "13sus#5b9#11", btn_click_13suss5b9s11)
GUI.New("chord_13sus#5#11",      "Button",           4, 725+x5, 580+y5, 85, 20, "13sus#5#11", btn_click_13suss5s11)
GUI.New("chord_13sus#5#9#11",      "Button",           4, 725+x5, 605+y5, 85, 20, "13sus#5#9#11", btn_click_13suss5s9s11)


--Suspended Chords Buttons Column 3

GUI.New("chord_13sus#9",      "Button",           4, 815+x5, 55+y5, 85, 20, "13sus#9", btn_click_13suss9)
GUI.New("chord_13sus#9#11",      "Button",           4, 815+x5, 80+y5, 85, 20, "13sus#9#11", btn_click_13suss9s11)
GUI.New("chord_13sus#11",      "Button",           4, 815+x5, 105+y5, 85, 20, "13sus#11", btn_click_13suss11)
GUI.New("chord_quartal",      "Button",           4, 815+x5, 130+y5, 85, 20, "quartal", btn_click_quartal)
GUI.New("chord_sowhat",      "Button",           4, 815+x5, 155+y5, 85, 20, "So What", btn_click_sowhat)



local function chord_add_root_note()
    time = reaper.GetCursorPosition()
    markrgnindexnumber, rgnendOut = reaper.GetLastMarkerAndCurRegion(0, time)
    
    
    retval, isrgnOut, posOut, rgnendOut, nameOut, markrgnindexnumberOut = reaper.EnumProjectMarkers(rgnendOut)
    
    clear_name_flag = 0 --this flag is needed in the SetProjectMarker4 function to enable the region name to be cleared
            --set to 0 the name is not cleared and when set to 1 the name is cleared regardless of newName value

    --root_name = GUI.elms.root_choice.optarray[ GUI.Val("root_choice") ]
    root_numbers = GUI.Val("root_choice")
    root_names = { [1] = "C", [2] = "C#", [3] = "Db", [4] = "D", [5] = "D#", [6] = "Eb", [7] = "E", [8] = "F", [9] = "F#", [10] = "Gb", [11] = "G", [12] = "G#", [13] = "Ab", [14] = "A", [15] = "A#", [16] = "Bb", [17] = "B"}
    root_name = root_names[root_numbers]

      
    newName = (nameOut .. "/" .. root_name) --newName = ("C" .. chord_type)
--Msg(newName)
     
   --- if newName == "" then clear_name_flag = 1 end --if removing the -L leaves an empty name string pass the 1 flag to clear name
    
     
     
    reaper.SetProjectMarker4(0, markrgnindexnumberOut, true, posOut, rgnendOut, newName, 0, clear_name_flag)
    
   
    chord_type = ""
 
    
end
    

local function chord_add_root_note2()
    time = reaper.GetCursorPosition()
    markrgnindexnumber, rgnendOut = reaper.GetLastMarkerAndCurRegion(0, time)
    
    
    retval, isrgnOut, posOut, rgnendOut, nameOut, markrgnindexnumberOut = reaper.EnumProjectMarkers(rgnendOut)
    
    clear_name_flag = 0 --this flag is needed in the SetProjectMarker4 function to enable the region name to be cleared
            --set to 0 the name is not cleared and when set to 1 the name is cleared regardless of newName value

    --root_name = GUI.elms.root_choice.optarray[ GUI.Val("root_choice") ]
    root_numbers = GUI.Val("root_choice2")
    root_names = { [1] = "C", [2] = "C#", [3] = "Db", [4] = "D", [5] = "D#", [6] = "Eb", [7] = "E", [8] = "F", [9] = "F#", [10] = "Gb", [11] = "G", [12] = "G#", [13] = "Ab", [14] = "A", [15] = "A#", [16] = "Bb", [17] = "B"}
    root_name = root_names[root_numbers]

      
    newName = (nameOut .. "/" .. root_name) --newName = ("C" .. chord_type)
--Msg(newName)
     
   --- if newName == "" then clear_name_flag = 1 end --if removing the -L leaves an empty name string pass the 1 flag to clear name
    
     
     
    reaper.SetProjectMarker4(0, markrgnindexnumberOut, true, posOut, rgnendOut, newName, 0, clear_name_flag)
    
   
    chord_type = ""
 
    
end    
    
-- Chords Next Previous Add Split All Tabs (1) Functions 

local function btn_click_chord_add_root_note()
    chord_type = ""
    chord_add_root_note()
    end

local function btn_click_chord_pre()
    commandID100 = reaper.NamedCommandLookup("_RSa269108c0ba744d947b179c93a57c34399b55a43")
    reaper.Main_OnCommand(commandID100, 0) -- Script: ReaTrak Go to start of previous region.lua
    end
 
local function btn_click_bar_pre()
    reaper.Main_OnCommand(41043, 0) -- Move edit cursor back one measure
    time = reaper.GetCursorPosition()
    grid_pos = reaper.SnapToGrid(0, time)
    reaper.SetEditCurPos2(0, grid_pos, false, false)
    end

local function btn_click_beat_pre()
    reaper.Main_OnCommand(41045, 0) -- Move edit cursor back one beat
    time = reaper.GetCursorPosition()
    grid_pos = reaper.SnapToGrid(0, time)
    reaper.SetEditCurPos2(0, grid_pos, false, false)
    end
  
local function btn_click_chord_next()
    commandID102 = reaper.NamedCommandLookup("_RSce47da3c9b1238de71cc94a1cb99732b9abd5e41")
    reaper.Main_OnCommand(commandID102, 0) -- Script: ReaTrak Go to start of next region.lua
    end

local function btn_click_bar_next()
    --reaper.Main_OnCommand(41040, 0) -- Move edit cursor to start of next measure
    reaper.Main_OnCommand(41042, 0) -- Move edit cursor forward one measure
    time = reaper.GetCursorPosition()
    grid_pos = reaper.SnapToGrid(0, time)
    reaper.SetEditCurPos2(0, grid_pos, false, false)    
    end

local function btn_click_beat_next()
    reaper.Main_OnCommand(41044, 0) -- Move edit cursor forward one beat
    time = reaper.GetCursorPosition()
    grid_pos = reaper.SnapToGrid(0, time)
    reaper.SetEditCurPos2(0, grid_pos, false, false)    
    end
  
local function btn_click_play_stop()
    reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
    end  
      
local function btn_click_new_region()
    commandID103 = reaper.NamedCommandLookup("_RScacdeb459aacbafc0dffd42686df0541849b9267")
    reaper.Main_OnCommand(commandID103, 0) -- Script: ReaTrak insert measures region.lua
    end

local function btn_click_remove_chord_region()
    commandID104 = reaper.NamedCommandLookup("_RS6c1d47c18a8623f9bec4db6a38f5f3244340130b")
    reaper.Main_OnCommand(commandID104, 0) -- Script: ReaTrak merge region under cursor and the previous one.eel
    commandID102 = reaper.NamedCommandLookup("_RSce47da3c9b1238de71cc94a1cb99732b9abd5e41")
    reaper.Main_OnCommand(commandID102, 0) -- Script: ReaTrak Go to start of next region.lua    
    end 

--[[ 
local function btn_click_chord_new_selection()
    commandID104 = reaper.NamedCommandLookup("_bd132e9bcaddef4b964432e63a02034b")
    reaper.Main_OnCommand(commandID104, 0) -- Custom: ReaTrak insert chord region in time selection
    end    
--]]

local function btn_click_edit_chord()
    reaper.Main_OnCommand(40616, 0) -- Markers: Edit region near cursor
    end

local function btn_click_chord_split()
    commandID105 = reaper.NamedCommandLookup("_RS8fa94cd55cd82c3d9b0a066f7f5ceec2009c7180")
    reaper.Main_OnCommand(commandID105, 0) -- Script: ReaTrak Split region under cursor.eel
    end

local function btn_click_chord_sharp_flat()
    commandID106 = reaper.NamedCommandLookup("_RS1004c26d8d7356510044c4e72d5a01625106f68a")
    reaper.Main_OnCommand(commandID106, 0) -- Script: ReaTrak flat sharp change.lua
    end
 



-- Chords Next Previous Add Split All Tabs (layer 1), Tabs 2,3 only (layer 2)
-- Button Position Adjustment add e.g x = -10 or x = 0 or x = 10
x6 = -35
y6 = -250  
--[[
GUI.New("chord_add_root_note_btn",      "Button",           3, 50+x6, 520+y6, 115, 20, "Add Root to Chord /", btn_click_chord_add_root_note)
GUI.elms.chord_add_root_note_btn.col_txt = "yellow"
GUI.elms.chord_add_root_note_btn.col_fill = "shot"

GUI.New("chord_add_root_note2_btn",      "Button",           4, 50+x6, 870+y6, 115, 20, "Add Root to Chord /", btn_click_chord_add_root_note)
GUI.elms.chord_add_root_note2_btn.col_txt = "yellow"
GUI.elms.chord_add_root_note2_btn.col_fill = "shot"
--]]
--[[
GUI.New("chord_pre_btn",      "Button",           3, 170+x6, 620+y6, 115, 20, "< Previous Chord", btn_click_chord_pre)
GUI.elms.chord_pre_btn.col_txt = "yellow"
GUI.elms.chord_pre_btn.col_fill = "shot"
GUI.New("bar_pre_btn",      "Button",           3, 170+x6, 645+y6, 50, 20, "< Bar", btn_click_bar_pre)
GUI.elms.bar_pre_btn.col_txt = "yellow"
GUI.elms.bar_pre_btn.col_fill = "shot"
GUI.New("beat_pre_btn",      "Button",           3, 290+x6, 645+y6, 45, 20, "< Beat", btn_click_beat_pre)
GUI.elms.beat_pre_btn.col_txt = "yellow"
GUI.elms.beat_pre_btn.col_fill = "shot"
GUI.New("chord_next_btn",      "Button",           3, 290+x6, 620+y6, 95, 20, "Next Chord >", btn_click_chord_next)
GUI.elms.chord_next_btn.col_txt = "yellow"
GUI.elms.chord_next_btn.col_fill = "shot"
GUI.New("bar_next_btn",      "Button",           3, 235+x6, 645+y6, 50, 20, "Bar >", btn_click_bar_next)
GUI.elms.bar_next_btn.col_txt = "yellow"
GUI.elms.bar_next_btn.col_fill = "shot"
GUI.New("beat_next_btn",      "Button",           3, 340+x6, 645+y6, 45, 20, "Beat >", btn_click_beat_next)
GUI.elms.beat_next_btn.col_txt = "yellow"
GUI.elms.beat_next_btn.col_fill = "shot"
--]]

GUI.New("play_stop_btn",      "Button",           3, 180+x6, 480+y6, 45, 20, "■ >", btn_click_play_stop) -- alt 254
GUI.elms.play_stop_btn.col_txt = "yellow"
GUI.elms.play_stop_btn.col_fill = "shot"

GUI.New("play_stop2_btn",      "Button",           4, 410+x6, 870+y6, 45, 20, "■ >", btn_click_play_stop) -- alt 254
GUI.elms.play_stop2_btn.col_txt = "yellow"
GUI.elms.play_stop2_btn.col_fill = "shot"

--[[
GUI.New("new_region_btn",      "Button",           3, 390+x6, 620+y6, 125, 20, "New Region at Cursor", btn_click_new_region)
GUI.elms.new_region_btn.col_txt = "yellow"
GUI.elms.new_region_btn.col_fill = "shot"
GUI.New("remove_chord_region_btn",      "Button",           3, 520+x6, 620+y6, 135, 20, "Remove Chord Region", btn_click_remove_chord_region)
GUI.elms.remove_chord_region_btn.col_txt = "yellow"
GUI.elms.remove_chord_region_btn.col_fill = "shot"
--[[
GUI.New("chord_new_selection_btn",      "Button",           6, 520+x6, 620+y6, 135, 20, "New Chord in Selection", btn_click_chord_new_selection)
GUI.elms.chord_new_selection_btn.col_txt = "yellow"
GUI.elms.chord_new_selection_btn.col_fill = "shot"

GUI.New("edit_chord2_btn",      "Button",           3, 660+x6, 620+y6, 70, 20, "Edit Chord", btn_click_edit_chord)
GUI.elms.edit_chord2_btn.col_txt = "yellow"
GUI.elms.edit_chord2_btn.col_fill = "shot"
GUI.New("chord_split_btn",      "Button",           3, 735+x6, 620+y6, 125, 20, "Split Chord at Cursor", btn_click_chord_split)
GUI.elms.chord_split_btn.col_txt = "yellow"
GUI.elms.chord_split_btn.col_fill = "shot"
GUI.New("chord_sharp_flat_btn",      "Button",           3, 865+x6, 620+y6, 40, 20, "♯ / b", btn_click_chord_sharp_flat)
GUI.elms.chord_sharp_flat_btn.col_txt = "yellow"
GUI.elms.chord_sharp_flat_btn.col_fill = "shot"
GUI.New("my_frm2",      "Frame",           3, 500+x6, 650+y6, 410, 40, false, false, "elm_bg", 4)
GUI.elms.my_frm2.text = "Alt Drag Chord Region to move or Drag ends to increase/decrease Length, Alt click to Del"
GUI.elms.my_frm2.col_txt = "white"

--]]
--GUI.New("my_frm",      "Frame",           3, 500+x6, 560+y6, 340, 35, true, true, "elm_bg", 4)
--GUI.New("root_choice",     "Radio",          3, 42+x6, 560+y6, 415, 64, "Slash Root", "C,C♯,Db,D,D♯,Eb,E,F,F♯,Gb,G,G♯,Ab,A,A♯,Bb,B", "h", 4)
--Msg("root_choice")
--GUI.elms.my_frm.text = " Choose the Root of the Chord then the Chord type or add the Root Note for / Slash Chords"
--GUI.elms.my_frm.col_txt = "white"


GUI.New("my_frm3",      "Frame",           4, 500+x6, 900+y6, 340, 35, true, true, "elm_bg", 4)
GUI.New("root_choice2",     "Radio",          4, 42+x6, 900+y6, 415, 64, "Chord Root", "C,C♯,Db,D,D♯,Eb,E,F,F♯,Gb,G,G♯,Ab,A,A♯,Bb,B", "h", 4)
--Msg("root_choice")
GUI.elms.my_frm3.text = " Set the Root of the Chord First"
GUI.elms.my_frm3.col_txt = "white"



--GUI.New("file_list", "Listbox",  5,  100,  40,  600, 608, midi_path_files2, false, "Files")
GUI.New("file_list", "Listbox",  5,  150,  40,  600, 608, midi_path_files2, false, "")
 
GUI.New("insert_file_btn",      "Button",           5, 10, 150, 65, 20, "Insert", btn_click_insert_file) 
GUI.elms.insert_file_btn.col_txt = "yellow"
GUI.elms.insert_file_btn.col_fill = "shot"

GUI.New("play_file_btn",      "Button",           5, 10, 175, 65, 20, "Play", btn_click_play_file) 
GUI.elms.play_file_btn.col_txt = "yellow"
GUI.elms.play_file_btn.col_fill = "shot"

GUI.New("stop_btn",      "Button",           5, 10, 200, 65, 20, "Stop", btn_click_stop) 
GUI.elms.stop_btn.col_txt = "yellow"
GUI.elms.stop_btn.col_fill = "shot"

GUI.New("time_sel_btn",      "Button",           5, 10, 225, 105, 20, "Time Sel Item", time_sel_item) 
GUI.elms.time_sel_btn.col_txt = "yellow"
GUI.elms.time_sel_btn.col_fill = "shot"

GUI.New("del_mark_btn",      "Button",           5, 10, 250, 105, 20, "Del Item Markers", remove_markers) 
GUI.elms.del_mark_btn.col_txt = "yellow"
GUI.elms.del_mark_btn.col_fill = "shot"

GUI.New("show_mark_btn",      "Button",           5, 10, 275, 105, 20, "Show Markers", show_midi_markers) 
GUI.elms.show_mark_btn.col_txt = "yellow"
GUI.elms.show_mark_btn.col_fill = "shot"

--GUI.New("show_path_btn",      "Button",           5, 10, 275, 105, 20, "Show Path", btn_click_show_path2) 
--GUI.elms.show_path_btn.col_txt = "yellow"
--GUI.elms.show_path_btn.col_fill = "shot"

GUI.New("browse_btn",      "Button",           5, 10, 300, 105, 20, "Browse Path", browse_folder) 
GUI.elms.browse_btn.col_txt = "yellow"
GUI.elms.browse_btn.col_fill = "shot"


--GUI.New("chk_opts",     "Checklist",     5, 10, 102, 192, 96, "Options", "Filename,Pathname", "v", 4)
--GUI.New("view_opt",     "Menubox",          5, 800, 50,  100, 20, "View:", "Filename,Pathname")

--GUI.New("my_frm4",      "Frame",           5, 50, 900, 340, 35, true, true, "elm_bg", 4)
--GUI.elms.my_frm4.text = "midifile_path"
--GUI.elms.my_frm4.col_txt = "white"

GUI.New("my_frm4",      "Frame",           5, 190+x6, 900+y6, 590, 35, true, true, "elm_bg", 4)
GUI.elms.my_frm4.text = "midifile_path"
GUI.elms.my_frm4.col_txt = "white"


--GUI.New("file_list2", "Listbox",  3,  150,  300,  600, 408, midi_path_files2, false, "Files")


GUI.New("file_list2", "Listbox",  3,  150,  300,  600, 408, midi_path_files2, false, "")

GUI.New("set_chord_btn",      "Button",           3, 10, 195, 115, 20, "Set Chord Name", btn_click_set_chord_name) 
GUI.elms.set_chord_btn.col_txt = "black"
GUI.elms.set_chord_btn.col_fill = "verse_fill"

GUI.New("octave_up2_btn",      "Button",           3, 10, 220, 115, 20, "Chord Octave Up", btn_click_octave_up) 
GUI.elms.octave_up2_btn.col_txt = "white"
GUI.elms.octave_up2_btn.col_fill = "verse"

GUI.New("octave_down2_btn",      "Button",           3, 10, 245, 115, 20, "Chord Octave Down", btn_click_octave_down) 
GUI.elms.octave_down2_btn.col_txt = "white"
GUI.elms.octave_down2_btn.col_fill = "verse"

GUI.New("chord_semi_up2_btn",      "Button",           3, 10, 270, 115, 20, "Chord semi +", btn_click_chord_semi_up) 
GUI.elms.chord_semi_up2_btn.col_txt = "white"
GUI.elms.chord_semi_up2_btn.col_fill = "verse"

GUI.New("chord_semi_down2_btn",      "Button",           3, 10, 295, 115, 20, "Chord semi -", btn_click_chord_semi_down) 
GUI.elms.chord_semi_down2_btn.col_txt = "white"
GUI.elms.chord_semi_down2_btn.col_fill = "verse"

GUI.New("snap_scale_btn",      "Button",           3, 10, 320, 115, 20, "Snap to Scale", btn_click_snap_scale) 
GUI.elms.snap_scale_btn.col_txt = "black"
GUI.elms.snap_scale_btn.col_fill = "verse_fill"

GUI.New("set_bass_root_btn",      "Button",           3, 795, 500, 105, 20, "Set Bass Root", btn_click_set_bass_root) 
GUI.elms.set_bass_root_btn.col_txt = "black"
GUI.elms.set_bass_root_btn.col_fill = "verse_fill"

GUI.New("bass_semi_up2_btn",      "Button",           3, 795, 525, 105, 20, "Bass Semi +", btn_click_bass_semi_up) 
GUI.elms.bass_semi_up2_btn.col_txt = "white"
GUI.elms.bass_semi_up2_btn.col_fill = "verse"

GUI.New("bass_semi_down2_btn",      "Button",           3, 795, 550, 105, 20, "Bass Semi -", btn_click_bass_semi_down) 
GUI.elms.bass_semi_down2_btn.col_txt = "white"
GUI.elms.bass_semi_down2_btn.col_fill = "verse"
 
GUI.New("insert_file2_btn",      "Button",           3, 10, 350, 65, 20, "Insert", btn_click_insert_file) 
GUI.elms.insert_file2_btn.col_txt = "yellow"
GUI.elms.insert_file2_btn.col_fill = "shot"

GUI.New("play_file2_btn",      "Button",           3, 10, 375, 65, 20, "Play", btn_click_play_file2) 
GUI.elms.play_file2_btn.col_txt = "white"
GUI.elms.play_file2_btn.col_fill = "chorus"

GUI.New("stop_btn2",      "Button",           3, 10, 400, 65, 20, "Stop", btn_click_stop) 
GUI.elms.stop_btn2.col_txt = "white"
GUI.elms.stop_btn2.col_fill = "red"

GUI.New("time_sel2_btn",      "Button",           3, 10, 425, 105, 20, "Time Sel Item", time_sel_item) 
GUI.elms.time_sel2_btn.col_txt = "yellow"
GUI.elms.time_sel2_btn.col_fill = "shot"

GUI.New("del_mark2_btn",      "Button",           3, 10, 450, 105, 20, "Del Item Markers", remove_markers) 
GUI.elms.del_mark2_btn.col_txt = "white"
GUI.elms.del_mark2_btn.col_fill = "rest"

GUI.New("del_mark2_sel_btn",      "Button",           3, 10, 475, 105, 20, "Del Sel Markers", remove_markers_selection) 
GUI.elms.del_mark2_sel_btn.col_txt = "white"
GUI.elms.del_mark2_sel_btn.col_fill = "verse"

GUI.New("show_mark2_btn",      "Button",          3, 10, 500, 105, 20, "Show Markers", show_midi_markers) 
GUI.elms.show_mark2_btn.col_txt = "yellow"
GUI.elms.show_mark2_btn.col_fill = "shot"

--GUI.New("show_path2_btn",      "Button",           3, 10, 475, 105, 20, "Show Path", btn_click_show_path) 
--GUI.elms.show_path2_btn.col_txt = "yellow"
--GUI.elms.show_path2_btn.col_fill = "shot"

GUI.New("browse2_btn",      "Button",           3, 10, 525, 105, 20, "Browse Path", browse_folder) 
GUI.elms.browse2_btn.col_txt = "yellow"
GUI.elms.browse2_btn.col_fill = "shot"

GUI.New("octave_notes_opt",     "Menubox",          3, 80, 70,  100, 20, "Octave Notes", "No,Yes")

GUI.New("keyswitch_opt",     "Menubox",          3, 80, 100,  100, 20, "Keyswitches:", "No,Yes")
--GUI.New("lb_keyswitch_info",      "Label",           3, 85, 120, "Select Yes to Ignore Keyswitch Notes", true, 2)


--GUI.New("chk_opts",     "Checklist",     5, 10, 102, 192, 96, "Options", "Filename,Pathname", "v", 4)
--GUI.New("view_opt",     "Menubox",          5, 800, 50,  100, 20, "View:", "Filename,Pathname")

GUI.New("keyswitch_info_frm",      "Frame",           3, 5, 130,  200, 60, true, true, "wnd_bg", 4)
GUI.elms.keyswitch_info_frm.text = "Select Yes to move extra chord notes to next octave, No to mute & Yes to ignore Keyswitch notes"
GUI.elms.keyswitch_info_frm.col_txt = "white"

GUI.New("my_frm6",      "Frame",           3, 190+x6, 960+y6, 590, 35, true, true, "elm_bg", 4)
GUI.elms.my_frm6.text = "midifile_path2"
GUI.elms.my_frm6.col_txt = "white"
--[[
    wnd_bg = {64, 64, 64, 255},      -- Window BG
    tab_bg = {56, 56, 56, 255},      -- Tabs BG
    elm_bg = {48, 48, 48, 255},      -- Element BG
    elm_frame = {96, 96, 96, 255},    -- Element Frame
    elm_fill = {64, 192, 64, 255},    -- Element Fill
    elm_outline = {32, 32, 32, 255},  -- Element Outline
--]]
function GUI.elms.keyswitch_opt:onmouseup()
    GUI.Menubox.onmouseup(self)
    keyswitch_opt = GUI.elms.keyswitch_opt.optarray[ GUI.Val("keyswitch_opt") ]
    
end

function GUI.elms.octave_notes_opt:onmouseup()
    GUI.Menubox.onmouseup(self)
    octave_notes_opt = GUI.elms.octave_notes_opt.optarray[ GUI.Val("octave_notes_opt") ]
    
end

--btn_click_refresh()


function GUI.elms.file_list:onmouseup()
  
    GUI.Listbox.onmouseup(self)
    listbox_val = GUI.Val("file_list")
    midifile_path = midi_path_files[listbox_val]

    --reaper.ShowConsoleMsg("Current index: " .. tree[listbox_val] .."\n")
    GUI.elms.my_frm4:ondelete()
    GUI.New("my_frm4",      "Frame",           5, 190+x6, 900+y6, 590, 35, true, true, "elm_bg", 4)
    GUI.elms.my_frm4.text = midi_path_files[listbox_val]  
    GUI.elms.my_frm4.col_txt = "white"
    GUI.elms.my_frm4:init()
      
end

function GUI.elms.file_list2:onmouseup()
  
    GUI.Listbox.onmouseup(self)
    listbox_val2 = GUI.Val("file_list2")
    midifile_path2 = midi_path_files[listbox_val2]

    --reaper.ShowConsoleMsg("Current index2: " .. midifile_path2 .."\n")
    GUI.elms.my_frm6:ondelete()
    GUI.New("my_frm6",      "Frame",           3, 190+x6, 960+y6, 590, 35, true, true, "elm_bg", 4)
    GUI.elms.my_frm6.text = midi_path_files[listbox_val2]
    GUI.elms.my_frm6.col_txt = "white"
    GUI.elms.my_frm6:init()  
  
end


--[[
function GUI.elms.file_list:ondoubleclick()
    GUI.Listbox.ondoubleclick(self)
    listbox_val = GUI.Val("file_list")
    midifile_path = midi_path_files[listbox_val]
    reaper.ShowConsoleMsg("Current index: " .. midi_path_files[listbox_val] .."\n")
    btn_click_file()  
end
--]]




------------------------------------
-------- Main functions ------------
------------------------------------

-- This will be run on every update loop of the GUI script; anything you would put
-- inside a reaper.defer() loop should go here. (The function name doesn't matter)
local function Main()

  

  --GetFiles(path)
  --GetPathSeparator()
  --filename_table()
  
  --[[
  
  GUI.New("file_list", "Listbox",  5,  100,  40,  600, 608, midi_path_files2, false, "Files")
  
  GUI.New("file_list2", "Listbox",  3,  150,  300,  600, 408, midi_path_files2, false, "Files")
  
  function GUI.elms.file_list:onmouseup()
      GUI.Listbox.onmouseup(self)
      listbox_val = GUI.Val("file_list")
      midifile_path = midi_path_files[listbox_val]
  
      --reaper.ShowConsoleMsg("Current index: " .. midi_path_files[listbox_val] .."\n")
      GUI.elms.my_frm4:ondelete()
      GUI.New("my_frm4",      "Frame",           5, 140+x6, 900+y6, 590, 35, true, true, "elm_bg", 4)
      GUI.elms.my_frm4.text = midi_path_files[listbox_val] --" Choose the Root of the Chord then the Chord type or add the Root Note for / Slash Chords"
      GUI.elms.my_frm4.col_txt = "white"
      GUI.elms.my_frm4:init()
      
  end
  
  function GUI.elms.file_list2:onmouseup()
      GUI.Listbox.onmouseup(self)
      listbox_val = GUI.Val("file_list2")
      midifile_path = midi_path_files[listbox_val]
  
      --reaper.ShowConsoleMsg("Current index: " .. midi_path_files[listbox_val] .."\n")
      GUI.elms.my_frm6:ondelete()
      GUI.New("my_frm6",      "Frame",           3, 190+x6, 960+y6, 590, 35, true, true, "elm_bg", 4)
      GUI.elms.my_frm6.text = midi_path_files[listbox_val] --" Choose the Root of the Chord then the Chord type or add the Root Note for / Slash Chords"
      GUI.elms.my_frm6.col_txt = "white"
      GUI.elms.my_frm6:init()    
  end
  --]]

  --[[
  -- Prevent the user from resizing the window
  if GUI.resized then
    
    -- If the window's size has been changed, reopen it
    -- at the current position with the size we specified
    local __,x,y,w,h = gfx.dock(-1,0,0,0,0)
    gfx.quit()
    gfx.init(GUI.name, GUI.w, GUI.h, 0, x, y)
    GUI.redraw_z[0] = true
  end    
  --]]
end


-- Open the script window and initialize a few things
GUI.Init()

-- Tell the GUI library to run Main on each update loop
-- Individual elements are updated first, then GUI.func is run, then the GUI is redrawn
GUI.func = Main

-- How often (in seconds) to run GUI.func. 0 = every loop.
GUI.freq = 0


-- Start the main loop
GUI.Main()
