-----DEBUG CONTROL--------------------------------------------------------------

debug_output = false -- true/false --display debug messages in the console

-----DISPLAY CONSOLE MESSAGE----------------------------------------------------

-- Display a message in the console for debugging, message can be a number variable
-- or a string but not mixed. No line feed character is added.
function Msg(value)
  --returns nothing

  if debug_output then --check if flag is set true (at the start of this script)
    reaper.ShowConsoleMsg(tostring(value).."\n")
  end
end


-- NoIndex: true

--[[
  Lokasenna_GUI example

  - Getting user input before running an action; i.e. replacing GetUserInputs

]]--

--------------------------------
 --REATRAK LOCAL GUI LIBRARY start
--------------------------------
local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
--Msg("script_path "..script_path)
local lib_path = script_path --reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
--if not lib_path or lib_path == "" then
    --reaper.MB("Couldn't load the ReaTrak Lokasenna_GUI library. Please check Scripts/ReaTrak/ReaTrak_Classes/", "Whoops!", 0)
    --return
--end

loadfile(script_path .. "ReaTrak_Core.lua")()

GUI.req(script_path .. "ReaTrak_Classes/Class - Label.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Knob.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Tabs.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Slider.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Button.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Menubox.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Textbox.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Frame.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Options.lua")()
GUI.req(script_path .. "ReaTrak_Classes/Class - Window.lua")()

--------------------------------
 --REATRAK LOCAL GUI LIBRARY end
--------------------------------

--[[
--------------------------------
 --LOKASENNA GUI LIBRARY start
--------------------------------

-- NoIndex: true

--[[
  Lokasenna_GUI example

  - Getting user input before running an action; i.e. replacing GetUserInputs

]]--


--[[
-- The Core library must be loaded prior to anything else
reaper.MB("Using Lokasenna_GUI library", "Notice", 0)
    
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
GUI.req("Classes/Class - Frame.lua")()
GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Window.lua")()

--------------------------------
 --LOKASENNA GUI LIBRARY end
--------------------------------
--]]

-- If any of the requested libraries weren't found, abort the script nicely.
if missing_lib then return 0 end

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
GUI.colors["stop"] = {151, 0, 75, 255}

--Text Colors

GUI.colors["btn_txt1"] = {255, 255, 255, 255} --white
GUI.colors["btn_txt2"] = {155, 155, 155, 255} --gray
GUI.colors["btn_txt3"] = {0, 0, 0, 255} --black


------------------------------------
-------- Functions  ----------------
------------------------------------

-----COPY MEDIA ITEM------------------------------------------------------------

function CopyMediaItem(is_drum_track, item, track, position)
  ---***may not need is_drum_track flag here
  ---*** debug

  --Msg(" to pos "..tostring(position).."\n")

  ---***
  --returns new_item media itme
  local new_item = reaper.AddMediaItemToTrack(track)
  local retval, new_item_chunk = reaper.GetItemStateChunk(new_item, '')
  local new_iid = new_item_chunk:match('\nIID (%d+)')

  local retval, item_chunk = reaper.GetItemStateChunk(item, '')

  new_item_chunk = item_chunk:gsub('GUID ({[%x|-]+})\n', 'GUID ' .. reaper.genGuid('') .. '\n' )
  new_item_chunk = new_item_chunk:gsub('\nIID (%d+)', '\nIID ' .. new_iid)

  reaper.SetItemStateChunk(new_item, new_item_chunk)

-- ADDED get tenpo at current position
  local item = reaper.GetSelectedMediaItem(0, 0)
  local take = reaper.GetMediaItemTake(item, 0)
  local timesig_num, timesig_denom, current_tempo = reaper.TimeMap_GetTimeSigAtTime(0, position)
  local retval, take_name = reaper.GetSetMediaItemTakeInfo_String( take, "P_NAME", "", false )
  local org_bpm = tonumber(take_name:match('(%d+)bpm')) or 120
  local playrate = current_tempo / org_bpm
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", playrate )
-- ADDED
  reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", position)
  reaper.UpdateItemInProject(new_item)

  return new_item

end --END OF COPY MEDIA ITEM FUNCTION

-----CHECK IF WITHIN TIME SELECTION---------------------------------------------
function IsInTimeSelection( s, e )
  --returns true or false

  if s >= start_time and e <= end_time then return true end
  return false
end --END OF IS IN TIME SELCTION FUNCTION

-----GET STANDARDIZED NAME AND OTHERS-------------------------------------------

--Processes given take, item and region names to return
--std_full_name, std_root_name, std_chord_name, switches, alias_full_name, alias_root_name
--where
--std_full_name = the standardised full name of root note and chord type
--std_root_name = the preferred root note name
--std_chord_name = the standardised chord type name
--switches = any optional switches after the given name designated by a "-" character
--alias_full_name = the full name using the alias root note name
--alias_root_name = the alias root note name

--*** Note that many of these returned variables are not used but there is needed

function GetStdName ( full_name )
  --returns std_full_name, std_root_name, std_chord_name, switches, alias_full_name, alias_root_name
  --if not is_drum_track then
  local root_alias = { ["Ab"] = "G#", ["A"] = "A", ["A#"] = "Bb",
    ["Bb"] = "A#", ["B"] = "Cb", ["B#"] = "C",
    ["Cb"] = "B", ["C"] = "B#", ["C#"] = "Db",
    ["Db"] = "C#", ["D"] = "D", ["D#"] = "Eb",
    ["Eb"] = "D#", ["E"] = "Fb", ["E#"] = "F",
    ["Fb"] = "E", ["F"] = "E#", ["F#"] = "Gb",
    ["Gb"] = "F#", ["G"] = "G", ["G#"] = "Ab",
  ["xb"] = "x", ["x"] = "x", ["x#"] = "x" }

  local root_pref = { ["Ab"] = "G#", ["A"] = "A", ["A#"] = "A#",
    ["Bb"] = "A#", ["B"] = "B", ["B#"] = "C",
    ["Cb"] = "B", ["C"] = "C", ["C#"] = "C#",
    ["Db"] = "C#", ["D"] = "D", ["D#"] = "D#",
    ["Eb"] = "D#", ["E"] = "E", ["E#"] = "F",
    ["Fb"] = "E", ["F"] = "F", ["F#"] = "F#",
    ["Gb"] = "F#", ["G"] = "G", ["G#"] = "G#",
  ["xb"] = "x", ["x"] = "x", ["#x"] = "x" }

  local switches = "" --return string of -Switches found at end
  local root_name = ""
  local chord_name = ""
  local std_chord_name = "" --return string with standardised chord name


  if full_name == "" then full_name = "x" end --no name or switches
  if string.match( full_name, "@.*") then full_name = "x" end --region is ignored
  full_name = string.gsub(full_name, "-5", "(b5)") --if there is a -5 chord make it (b5)
  --switches = string.match( full_name, "-.*") --save any switches then remove them from full name
  switches = string.match( full_name, "-%a.*") --save any switches then remove them from full name
  --flat5, switches = string.match( full_name, "(-5?)(-%a.*)") --save any switches then remove them from full name

  if switches then full_name = string.sub(full_name, 1, string.find(full_name, "%s*-") - 1 ) end
  if full_name == "" then full_name = "x" end --switches but no name
  root_name, chord_name = string.match(full_name, "(%w[#b]?)(.*)$")
  std_chord_name = chord_name


  if not chord_name or #chord_name == 0 then std_chord_name = "Maj" end --if no Major or minor indicated make it Major
  --std_chord_name = string.gsub(std_chord_name, "-5", "(b5)") --if there is a -5 make it (b5)
  --if flat5 then std_chord_name = "-5" end
  --if string.match(full_name, "-5") then std_chord_name = "(b5)" end
  std_chord_name = string.gsub(std_chord_name, "maj", "Maj") --if there is a maj make it Maj
  std_chord_name = string.gsub(std_chord_name, "[Mm]in", "m") --if there is a Min or min make it m
  std_chord_name = string.gsub(std_chord_name, "Sus", "sus") --if there is Sus replace it with just sus


  local std_root_name = root_pref[root_name] --return string with standardised root chord name
  local std_full_name = std_root_name .. std_chord_name --return string standardised full name
  local alias_root_name = root_alias[root_name] --return string alias root name
  local alias_full_name = alias_root_name .. std_chord_name --return string alias full name


  return std_full_name, std_root_name, std_chord_name, switches, alias_full_name, alias_root_name



  --end



end --END OF GET STD NAM FUNCTION

-----GET ITEM LENGTH------------------------------------------------------------

function GetItemLength(item)
  --return item_len

  local item_len = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )

  return item_len
end --END OF GET ITEM LENGTH FUNCTION

-----GET REGION LENGTH----------------------------------------------------------
--returns the length of a regular region or contigous colour regions in the case of a drum track
function GetRegionLength(is_drum_track, region)
  --return region_len
  local retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color
  if is_drum_track then --if this is a drum track then get length of the contiguous drum regions from tables
   region_pos = drum_region_start[region]
   region_end = drum_region_end[region]

  else
  retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, region)
  end
  local region_len = region_end - region_pos

  return region_len
end --END OF GET REGION LENGTH FUNCTION

-----GET DRUM REGION------------------------------------------------------------
--returns the drum region index when given a time value
function GetDrumRegion(time)
  --time: time value on track
  --returns: drum_region_idx at that time value

  for i = 1, #drum_region_start do
    if time >= drum_region_start[i] and time <= drum_region_end[i] then
      local drum_region_idx = i
      return drum_region_idx
    end
  end
  --***what to return if time value does not correspond to any drum region?
end

-----MOVE MATCHED ITEMS CONTAINED IN A TABLE TO FILL A REGION-------------------
--Move single items stored in a table to their matching regions

function MoveMatches(is_drum_track, first_link_flag, first_link_length, last_link_flag, last_link_length, move_table, region)

  --is_drum_track:    is a boolean flag true if this is a drum track being fitted
  --first_link_flag:  is a boolean flag and if true then -L1 linked items will have priority of fitting this region
  --                  and the function will leave room for the -L1 item to be fitted at the end of the region when
  --                  the MoveLinkedItems function is called later (avoids overlaying two items in the region).
  --last_link_flag:   is a boolean flag and if true then -L_1ast linked items will have priority of fitting this region
  --                  and the function will leave room for the -L_last item to be fitted at the start of the region when
  --                  the MoveLinkedItems function is called later (avoids overlaying two items in the region).
  --first_link_length:is the length of the first linked item (used indicate the amount of space needed at end of the region)
  --last_link_length: is the length of the last linked item (used indicate the amount of space needed at start of the region)
  --move_table:       is a table of items that match this region that can be picked from at random to fill the
  --                  region.
  --region:           is the region id to fit the items to.
  --
  --returns:          nothing  --***maybe return rnd values

  local retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color
  if is_drum_track then
    region_pos = drum_region_start[region]
    region_end = drum_region_end[region]

  else retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, region)
  end


  --save space at end of first linked region and end of last linked region


  if first_link_flag and not last_link_flag then --first link to be placed at the end of region so save space at end
    --check if there is room for any unlinked items left
    if (region_end - first_link_length - region_pos) < 0.00005 then return end --no spare room so dont fit any ***rounding errors here
    region_end = region_end - first_link_length

  elseif not first_link_flag and last_link_flag then --last link to be placed at the start of region so save space
    --check if there is room for any unlinked items left
    if (region_end - region_pos - last_link_length) < 0.00005 then return end --no spare room so dont fit any ***rounding errors here
    region_pos = region_pos + last_link_length

  elseif first_link_flag and last_link_flag then --linked sections sharing a common region with link at each end if room
    if (region_end - region_pos - first_link_length - last_link_length) < 0.00005 then Msg(" Ret203 ") return end --no spare room so dont fit any ***rounding errors
    region_end = region_end - first_link_length --save space at both ends of region
    region_pos = region_pos + last_link_length

    --check if there is room for any unlinked items left

  end


  new_items_table = {} --table to keep track of items copied to this region in the order they were fitted ***not needed??

  if #move_table > 0 then --some matches found so ready to move them
    --just modified Xray's code here to change table from items to move_table
    local last_end = region_pos
    repeat
      local id = math.random( 1, #move_table ) --pick random entries from move table #gives total number in table
      local track = reaper.GetMediaItemTrack( move_table[id] )
      --local item_len = reaper.GetMediaItemInfo_Value( move_table[id], "D_LENGTH" )
      local item_len  = GetItemLength(move_table[id])

      ---*** debug
      if region == 2 or region == 3 or region == 1 then
        Msg("Copying item length "..tostring(item_len).." to "..tostring(last_end).."\n")
      end
      ---***
  --returns new_item media itme

      --***check item is shorter than the region
      local new_item = CopyMediaItem(is_drum_track, move_table[id], track, last_end)
      --local new_item_len = reaper.GetMediaItemInfo_Value( new_item, "D_LENGTH" )
      local new_item_len = GetItemLength(new_item)
      table.insert(new_items_table, new_item) --*** maybe not needed
      local new_item_end = last_end + new_item_len
      --check if new item added goes beyond end of region and trim its length if needed.
      --***debug
      if region == 2 or region == 3 or region == 1 then
        Msg("new item length = "..tostring(new_item_len).." new item end = "..tostring(new_item_end).."\n")
      end
      --***
      if new_item_end > region_end then reaper.SetMediaItemInfo_Value( new_item, "D_LENGTH", region_end - last_end ) end
      last_end = new_item_end
      --***debug
      if region == 2 or region == 3 or region == 1 then
         Msg("last end = "..tostring(last_end).." region end = "..tostring(region_end)..tostring(last_end + 0.00005 >= region_end).."\n")
      end
      --***
    until last_end + 0.00005 >= region_end
  end

end --END OF MOVE MATCHES FUNCTION


-----MOVE MATCHED LINKED SECTION------------------------------------------------

--Move a section of linked items stored in a table to their matching regions
--if an item is shorter than the matching region decide whether this item is copied to the start or end of the region
--if item is a single linked one ie L1 only then fit it to start of first region --***??
--otherwise fit first to end of region
--copy mid ones to mid regions (should be exact size of mid regions)
--fit last one to beginning of last region
--like this:
--                            -L1        -L2        -L3
-- [R1],[R3],[R3] --> [----********][************][********--------]
--the unused areas of the regions will be flagged to be filled by other suitable non-linked matches
--which are copied first. When the linked sections are copied any previously copied items are deleted (or shortened)

function MoveLinkedItems(is_drum_track, move_link_table, region)
  --is_drum_track:    is a boolean flag, set true if this is a drum track
  --move_link_table:  is a table of consecutive matching linked items for the region.
  --region:           specifies the location that the -L1 item is to be placed in. The -L1 is placed at the
  --                  end of this region and consecutive linked sections are fitted to the start of the
  --                  consecutive regions. ***what happens if mid item too big or too small?
  --
  --returns:          nothing

  --[[--delete item code
      local track = reaper.GetMediaItemTrack(item)
      reaper.DeleteTrackMediaItem( track, item )
    --]]
  local retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color
  --fit first item to end of first region
  if is_drum_track then
    region_pos = drum_region_start[region]
    region_end = drum_region_end[region]
  else retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, region) --***chk other enum calls
  end
  local track = reaper.GetMediaItemTrack(move_link_table[1])

  -------------------*** for debuug
  --if region == 1 then
  --  reaper.DeleteTrackMediaItem(track, new_items_table[2]) end
  -------------------

  --local item_len = reaper.GetMediaItemInfo_Value( move_link_table[1], "D_LENGTH" )
  local item_len = GetItemLength(move_link_table[1])
  if #move_link_table == 1 then CopyMediaItem(is_drum_track, move_link_table[1], track, region_pos) --if it is the only linked item put it at the start of region



  else

  ---*** debug

  --Msg("MLI In Region "..tostring(region).." Copying -L* length "..tostring(item_len))

  ---***
  --returns new_item media itme



    CopyMediaItem(is_drum_track, move_link_table[1], track, region_end - item_len) --if there are multiple linked items put it at the end of region
  end

  for j = 2, #move_link_table do
    --fit item to start of region (*** no checking for item size)
    if is_drum_track then
    region_pos = drum_region_start[region + j - 1]
    region_end = drum_region_end[region +j -1]
    else
    retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, region + j - 1)
    end
    local track = reaper.GetMediaItemTrack( move_link_table[j] )

  ---*** debug

  --item_len = reaper.GetMediaItemInfo_Value( move_link_table[j], "D_LENGTH" )
  item_len = GetItemLength(move_link_table[j])
  --Msg("In RegIDX "..tostring(region_index - 1).." Copying -L* length "..tostring(item_len))

  ---***
  --returns new_item media itme



    CopyMediaItem(is_drum_track, move_link_table[j], track, region_pos ) --***check CopyMediaItem may copy item several times if region is big

  end

  return
end --END OF MOVE LINKED ITEMS FUNCTION

-----CHECK FOR MATCHES BETWEEN ITEM AND REGION-------------


function CheckMatch(is_drum_track, item_id, region)

  --is_drum_track: a boolean flag set true if this is a drum track
  --returns match_flag, match_priority, linked_item, link_level

  --item_match_flag = true when a match or multiple matches are found
  --match_priority = the type of matching criteria satisfied
  --             1 = Color of region and item match and this is a style track item
  --             1 = Color of region and item match and this is a drum track item
  --             2 = Name of region and item match and item is 'fit anywhere red' color
  --             3 = Name of region and item match and region is chorus fill or post fill and item is chorus colour
  --             4 = Name of region and item match and region is verse fill or post fill and item is verse colour
  --             5 = Name of region and item match and colors match
  --             6 =
  --linked_item = true if the item is linked to other items
  --link_level = 1,2,3 etc if item is linked and item name contains -L1,-L2,-L3 etc


  --Function to check if item matches region.

  local match_flag = false
  local match_priority = 0

  --if (region) > count_markers_regions - 1 or (item_id) > count_sel_items then
  --  Msg("break - outside range\n")
  --end --check items and region in range
  local retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color
  local full_region_name, region_root, std_region_chord, _, alias_full_region_name, alias_region_root
  local region_verse_fills
  local region_chorus_fills
  --Get region details
  if is_drum_track then
    region_pos = drum_region_start[region]
    region_end = drum_region_end[region]
    region_color = drum_region_color[region]
  else
    retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, region)


    full_region_name, region_root, std_region_chord, _, alias_full_region_name, alias_region_root = GetStdName(region_name)

    region_verse_fills = ((region_color == verse_post_fill_color) or (region_color == verse_fill_color)) --verse fills flag
    region_chorus_fills = ((region_color == chorus_post_fill_color) or (region_color == chorus_fill_color)) --chorus fills flag
  end
  local region_length = region_end - region_pos

  --Get item details
  local linked_item = false --default to non linked item
  local link_level = 0 --the number after the -L if current item is linked
  local use_chord_anywhere = false --default to non fit anywhere colour

  local item = init_sel_items[item_id]
  local take = reaper.GetActiveTake( item )
  if take then take_name = reaper.GetTakeName( take ) end

  --check if item is too big for the region and if so just return with no match --***deprecated
  local item_len = GetItemLength(item)
  --if item_len - 0.00005 > region_length then return match_flag, match_priority, linked_item, link_level end --allow for rounding errors in floating point calculations and fit even if slightly over sized

  local item_color = reaper.GetMediaItemInfo_Value( item, "I_CUSTOMCOLOR" )
  local full_item_name, item_root, std_item_chord, switches, alias_full_item_name, alias_root_name = GetStdName(take_name)

  use_chord_anywhere = (item_color == anywhere_color) --use_chord_anywhere is set to 'true' if item is fit anywhere color



  if switches then linked_item = (string.find( take_name, "-L[12345]") ~= nil) end --linked_item is set true if match with -Lx found
  if linked_item then --this is a linked item so flag this for funtion return
    link_level = tonumber(string.match( switches, "-L([12345])")) --return the link level (= 0 if not a linked item)


  end

  --MATCH TESTS FOR DIFFERENT PRIORITY MATCHES
  ----------------------------------------------------------------------------
  --1a. If it is a style track and there wont be any items to match the post
  --fill regions so we match the main chorus or verse etc. items instead

  if is_style_track then

    --check if style track item is a straight match of colour
    if region_color == item_color then
      match_flag = true
      match_priority = 1 --indicates a main style item colour only match

    --now check if the non-fill item can fit the post fill region
    --ie chorus -> chorus post-fill, verse -> verse post-fill, etc.
    elseif (region_color == chorus_post_fill_color and item_color == chorus_color
        or region_color == pre_chorus_post_fill_color and item_color == pre_chorus_color
        or region_color == verse_post_fill_color and item_color == verse_color
        or region_color == intro_post_fill_color and item_color == intro_color
        or region_color == bridge_post_fill_color and item_color == bridge_color ) then --if main colour for post fill
      match_flag = true
      match_priority = 1 --indicates a post-fill match for style items
    else
      --no match found
      match_flag = false
      match_priority = 0
    end

    --no other match tests needed for style track items so return
    return match_flag, match_priority, linked_item, link_level
  end
  --1. Only check if color matches (used for exact matching of drums items to regions)
  --this will take priority over the near matches of the main items for post fill regions
  --***do we need to check for item too big to fit here and in tests below?

  if is_drum_track then
    --check if the item and region colors match
    if (region_color == item_color) then --if just color match
      match_flag = true
      match_priority = 1 --indicates an exact color only match for drum items including post fills
    else
      match_flag = false
      match_priority = 0
    end


    return match_flag, match_priority, linked_item, link_level

    --get any name aliases and standard names and check for special regions such as fills and set flags if found
  --2. test if both name and color match for linked and non-linked items
  elseif ((full_item_name == full_region_name or alias_full_item_name == full_region_name) and (region_color == item_color)) then
    match_flag = true
    match_priority = 5 --indicates a full name and color match

  --3. Name and verse color match and this is a verse fills region
  elseif((full_item_name == full_region_name or alias_full_item_name == full_region_name) and region_verse_fills and (verse_color == item_color)) then
    match_flag = true
    match_priority = 4 --indicates a name and verse color match

  --4. Name and chorus color match and this is a chorus fills region
  elseif((full_item_name == full_region_name or alias_full_item_name == full_region_name) and region_chorus_fills and (chorus_color == item_color)) then
    match_flag = true
    match_priority = 3 --indicates a name and chorus color match for single item

  --5. Only check if name matches if the color of the item is the 'fit anywhere' red (R G B = hex E4 1A 27)
  elseif (use_chord_anywhere and (full_item_name == full_region_name or alias_full_item_name == full_region_name)) then
    match_flag = true
    match_priority = 2 --indicates a name and universal red color match for single item
--[[
  --5.5. Match any region (used for matching scale items to any regions)
  elseif (is_scale_track and use_chord_anywhere and (take_name == "")) then --if just scale match
    match_flag = true
    match_priority = 2 --indicates a name and universal red color match for single item
--]]

  --6. Match any region (used for matching scale items to any regions)
  elseif (is_scale_track and (take_name == "")) then --if just scale match
    match_flag = true
    match_priority = 2 --indicates a name and universal red color match for single item


  end --END OF MATCH TESTS

  return match_flag, match_priority, linked_item, link_level
end --END OF CHECK MATCH FUNCTION

--------------------------------------------------------------------------------


-----CHECK FOR COMPLETE MATCHING LINKED SECTIONS--------------------------------

function CheckSectionMatch(is_drum_track, region, link_match_table)
  --returns move_link_table - a list of matching linked section chosen at random from all matching sections

  --Msg("\n\nmatching -L1 items for region "..tostring(region).." = ")
  for j = 1, #link_match_table do
    --Msg(tostring(link_match_table[j]).." ")
  end
  --Msg("\n")
  local linked_section_done = false
  local section_match_table = {}
  for j = 1, 20 do
    section_match_table[j] = {} --create a table of tables to cater for 20 possible matching sections
  end
  local match_flag = false
  local match_priority = 0
  local linked_item = false
  local next_link_level = 0
  local item_ID
  local test_region = region
  local move_link_table = {}

  --process each of the -L1 items looking for further matching links in that section
  --MAIN LOOP THROUGH SECTIONS WITH MATCHING -L1 PASSED BY link_match_table
  for s = 1, #link_match_table do
    linked_section_done = false --starting to check a new linked section so not done yet
    local link_level = 1
    item_ID = link_match_table[s] --set item ID to first -L1 entry in table
    test_region = region
    --there is one section_match_table for each potential matching section
    table.insert(section_match_table[s], init_sel_items[item_ID]) --push the matching -L1 item onto table end
    -- now check if the next items and regions match for all consecutive -L items
    while linked_section_done == false do --loop through consecutive items and regions
      --get next item
      item_ID = item_ID + 1
      --check if this item is still in the selected range
      if item_ID > #init_sel_items then
        --linked_section_done = true
        break
      end

      --compare it with next region item
      --get next region
      test_region = test_region + 1
      --check if this region is still in the selected range
      if test_region > end_region then
        break
      end
      --if in range make comparison
      match_flag, match_priority, linked_item, next_link_level = CheckMatch(is_drum_track, item_ID, test_region)

      if match_flag then
        --check if this match item is a linked one and that the link level is the next consecutive one
        link_level = link_level + 1
        if next_link_level == link_level then
          table.insert(section_match_table[s], init_sel_items[item_ID])
        end
      else --if no further linked matches check if we have at least two so far otherwise delete the single -L1 entry from table
        if link_level == 1 then
          section_match_table[s] = {}
        end
        break
      end

    end -- end of consecutive linked items and regions while loop

  end -- end of match section (s) loop

  --Create a table of linked items to move by picking at random any of the complete matching sections (some may be empty)
  --Search the original table of -L1 items to see which formed complete links
  local random_section = {} --a table of sucessful link sections ids (s)
  for s = 1, #link_match_table do
    if #section_match_table[s] ~= 0 then
      table.insert(random_section, s) --push the good section id onto the random_section table
    end
    --now check that there were some matching sections and pick a random one
  end

  if #random_section ~= 0 then
    local id = math.random( 1, #random_section ) --pick random section id from table
    move_link_table = section_match_table[random_section[id]]
  end
  return move_link_table
end --END OF CHECK SECTION MATCH FUNCTION
--------------------------------------------------------------------------------

-----DELAY FUNCTION FOR DEBUG---------------------------------------------
function Sleep(n) -- wait n seconds
  local t0 = clock()
  while clock() - t0 <= n do
  end
end --END OF SLEEP FUNCTION

function wait(n)
  os.execute("wait " .. tonumber(n))
end


--Loops through all of the items for each region looking for matches
-----MAIN FUNCTION--------------------------------------------------------------
function Main_move_match()
   Msg("RUN MAIN")
  -----SCRIPT STARTS HERE---------------------------------------------------------
  
  -- Check if there are items selected
  count_sel_items = reaper.CountSelectedMediaItems(0)
  Msg("count_sel_items "..count_sel_items)
  --reaper.MB( "Pause", "Pause", 0 )
  count_markers_regions, num_markers, num_regions = reaper.CountProjectMarkers( 0 )
  
  if count_sel_items > 0 or num_regions == 0 then
    --reaper.PreventUIRefresh(1)
    --reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    --reaper.ClearConsole()
    init_sel_items = {}
    -- Save item selection
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
      init_sel_items[i + 1] = reaper.GetSelectedMediaItem(0, i)
    end
  end



  local clock = os.clock
  local take = reaper.GetActiveTake( init_sel_items[1] ) --get active take for the selected media
  local source = reaper.GetMediaItemTake_Source( take ) --if not MIDI then get the wav or mp3 etc

        if reaper.TakeIsMIDI( take ) then

           inipath = reaper.get_ini_file()
           
           Msg("It is MIDI and path = "..inipath.."\n")

           retval, filename = reaper.BR_Win32_GetPrivateProfileString("reaper", "reatrakfilename", "", inipath)
           
           Msg("MIDI filename = "..filename.."\n")

        else filename = reaper.GetMediaSourceFileName( source, "" ) --Get file name of source media
        end



  --initialize color table values to suit operating system running
  local os_type = reaper.GetOS() --Find out whether program is running on a Windows or Mac or Linux

  --Color code table Windows                 R  G  B
  anywhere_color = 19340004 -----------------E4 1A 27 the color to signify use anywhere 0x01271AE4
  any_ending_color = 30536770 ---------------42 F4 D1 R66 G244 B209 play as verse or chorus ending
  count_in_color = 29393151 -----------------FF 80 C0
  intro_post_fill_color = 28184951 ----------77 11 AE
  intro_color = 31987359 --------------------9F 16 E8
  intro_fill_color = 32342199 ---------------B7 80 ED
  verse_post_fill_color = 28190481 ----------11 27 AE
  verse_color = 32208439 --------------------37 76 EB
  verse_fill_color = 32620145 ---------------71 BE F1
  verse_ending_color = 32886935 -------------9E FE B6
  bridge_post_fill_color = 18115022 ---------CE 69 14
  bridge_color = 19957226 -------------------EA 85 30
  bridge_fill_color = 23373039 --------------EF A4 64
  pre_chorus_post_fill_color = 18133966 -----CE B3 14
  pre_chorus_color = 19976426 ---------------EA D0 30
  pre_chorus_fill_color = 26732532 ----------F4 E7 97
  chorus_post_fill_color = 19362827 ---------0B 74 27
  chorus_color = 20688401 -------------------11 AE 3B
  chorus_fill_color = 24898896 --------------50 ED 7B
  chorus_ending_color = 28769950 ------------9E F5 B6  old 9E FE B6
  drum_riff_color = 17897331 ----------------73 17 11
  hold_color = 29343679 ---------------------7F 7F 7F R 127 G 127 B 127 #7F7F7F
  shot_color = 25132927 ---------------------BF BF BF R 191 G 191 B 191 #BFBFBF
  rest_color = 16777216 ---------------------00 00 00

  --Color code table if NOT Windows (ie MacOS or Linux)
  if os_type ~= "Win32" and os_type ~= "Win64" then
    --color code table Mac                          R  G  B
    anywhere_color = 31726119 ---------------------E4 1A 27 the color to signify use anywhere 0x01271AE4
    --any_ending_color = 21165265 -------------------42 F4 D1 R66 G244 B209 play as verse or chorus ending
    count_in_color = 33521856 ---------------------FF 80 C0
    intro_post_fill_color = 24580526 --------------77 11 AE
    intro_color = 27203304 ------------------------9F 16 E8
    intro_fill_color = 28803309 -------------------B7 80 ED
    verse_post_fill_color = 17901486 --------------11 27 AE
    verse_color = 20412139 ------------------------37 76 EB
    verse_fill_color = 24231665 -------------------71 BE F1
    verse_ending_color = 26726654 -----------------97 D0 FE
    bridge_post_fill_color = 30304532 -------------CE 69 14
    bridge_color = 32146736 -----------------------EA 85 30
    bridge_fill_color = 32482404 ------------------EF A4 64
    pre_chorus_post_fill_color = 30323476 ---------CE B3 14
    pre_chorus_color = 32165936 -------------------EA D0 30
    pre_chorus_fill_color = 32827287 --------------F4 E7 97
    chorus_post_fill_color = 17527847 -------------0B 74 27
    chorus_color = 17935931 -----------------------11 AE 3B
    chorus_fill_color = 22080891 ------------------50 ED 7B
    chorus_ending_color = 27197110 ----------------9E F5 B6  old 9E FE B6 
    drum_riff_color = 24319761 --------------------73 17 11
    hold_color = 29343679 -------------------------BF BF BF
    shot_color = 25132927 -------------------------7F 7F 7F
    rest_color = 16777216 -------------------------00 00 00
  end


  --Check if the media is a drum track, style track or scale track from its file name

  is_style_track = string.match( filename, "[rR][eE][aA][sS][tT][yY][lL][eE]") ~= nil --if it is style track (reastyle) set as true
  is_drum_track = string.match( filename, "[Dd]rum") ~= nil --if it is drum track set as true
  is_scale_track = string.match( filename, "[Ss]cale") ~= nil --if it is scale track set as true
  Msg("drum track = "..tostring(is_drum_track).."\n")
  Msg("style track = "..tostring(is_style_track).."\n")
  Msg("scale track = "..tostring(is_scale_track).."\n")
  Msg("#init_sel_items = "..tostring(#init_sel_items).."\n")

  local cursor_pos = reaper.GetCursorPosition()
  local markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, cursor_pos)
  local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  Msg("start time = "..tostring(start_time).."   end time = "..tostring(end_time).."\n")

  --get the first and last regions in the time selection
  --***check if it is a drum track and if so adjust start and end regions to color only drum regions do later after forming drum region tables
  markeridx, start_region = reaper.GetLastMarkerAndCurRegion(0, start_time)
  markeridx, end_region = reaper.GetLastMarkerAndCurRegion(0, end_time - 0.5) --the -0.5 is just a fudge to stop the next
  --region being included when the time selection is
  --exactly on the region boundary


  --first check if these are drum track items being fitted as we handle them differently
  if is_drum_track then
    --build drum_regions of contiguous colour regions from the region table.
    --loop through consecutive selected regions and increment the drum_region when there is a change of region colour

    --make these global tables so accessible to functions
    drum_region_start = {}
    drum_region_end = {}
    drum_region_color = {}

    local drum_region_idx = 1
    local retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, start_region)
      drum_region_color[1] = region_color
      drum_region_start[1] = region_pos
      drum_region_end[1] = region_end
    --if a range of regions is selcted
    --***should we make range end at end of same color rather than time selection?
    --***could add small while loop after for loop to extend last drum region to include rest of same color outside selection
    for dr = start_region + 1, end_region do
      --get color of region dr
      retval_region, is_rgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(0, dr)
      --if it is the same color and joins directly to the last region (no gaps)
      if region_color == drum_region_color[drum_region_idx] and region_pos == drum_region_end[drum_region_idx] then

        drum_region_end[drum_region_idx]=region_end --extend the end of the drum region as more same color found

      else
        drum_region_idx = drum_region_idx + 1
        drum_region_color[drum_region_idx] = region_color
        drum_region_start[drum_region_idx] = region_pos
        drum_region_end[drum_region_idx] = region_end
      end
    end

    --get start and end drum regions from the selected time range
    start_region = GetDrumRegion(start_time)
    end_region = GetDrumRegion(end_time - 0.5) --the -0.5 is just a fudge to stop the next

    ---***debug

    Msg("Drum Start Region = "..tostring(start_region).."  Drum End Region = "..tostring(end_region).."\n")

    for dr = 1, #drum_region_color do
      Msg("Drum region "..tostring(dr).." = Color: "..tostring(drum_region_color[dr]).." Start: "..tostring(drum_region_start[dr]).." End: "..tostring(drum_region_end[dr]).."\n")
    end


  end --end if drum track loop


  --------------------------------------------------------------------------


  --MAIN REGION AND ITEM LOOPS FOLLOW HERE

  --Variables to initialize and define before starting the region loop
  --------------------------------------------------------------------------
  local match_flag = false
  local match_priority = 0
  local linked_item = false
  local link_level = 0
  local r = start_region --start region loop at start of time selection
  local single_region_only = false
  local first_link_length , last_link_length = 0,0 --length of first and last links in a found matching section
  local fit_links = false --flag to fit linked items section at this region or not?
  local last_link_flag = false --flag idicating a -L_last (ie. move_table[#move_table]) link will fit to the region
  local first_link_flag = false --flag indicating a -L1 link will fit to the region
  local link_length = 0 ----length of the linked item we have to save room for
  local previous_link_region = false
  local previous_last_link_length = 0

  if start_time == end_time then -- If no time selection
    single_region_only = true
    r = regionidx
  end --single region only
  ----------------------------------------------------------------------------

  Msg("Start region = "..tostring(start_region).."  EndRegion = "..tostring(end_region).."\n")
  --REGION LOOP START

  while r <= end_region do

          ---*** debug

          Msg("\nrLoop in region "..tostring(r))

          ---***



    local match_table = {} --Tables of matching non-linked items
    local link_match_table = {} --Table of item_ID of linked items
    for j = 1, 5 do
      match_table[j] = {} --start off each priority table empty at beginning of item loop
    end
    --ITEM LOOP START
    for i, item in ipairs(init_sel_items) do
      Item = item --make Item a global copy of local item
      ------------------------------------------------------------------------

      --*** dynamic debug output to specify a range of region and items to look at
      --debug_output = false
      --if (r >= 0) and(r < 79) and (i >= 0) and (i < 99) then debug_output = true end
      --***
      ------------------------------------------------------------------------
      --check if region and item match

      match_flag, match_priority, linked_item, link_level = CheckMatch(is_drum_track, i, r) --call check match function here
      if match_flag then
        if linked_item then
          if link_level == 1 then --check if the matching item is first item of a linked section
            table.insert(link_match_table, i) --push matching -L1 item-ID onto the end of the table
          end

        else --push matching items into different tables based on priority of match
          for j = 1, 5 do -- 5 levels of priority
            if match_priority == j then
              table.insert(match_table[j], init_sel_items[i]) --push matching item onto the end of the table
            end
          end
        end
      end
    end --END OF ITEMS LOOP
    --------------------------------------------------------------------------


    --MOVE THE MATCHING ITEMS
    --------------------------------------------------------------------------

    --CHECK FOR MATCHING LINKED ITEMS AND GET A RANDOM MATCHING SECTION
    local move_link_table = {}

    if #link_match_table > 0 then
      move_link_table = CheckSectionMatch(is_drum_track, r, link_match_table) --generate table of linked items to move from function call
    end

    --RANDOMLY CHOOSE TO FIT ANY LINKED SECTIONS OR NOT
    --------------------------------------------------------------------------
    first_link_flag = false --flag indicating a -L1 link will fit to the region

    --make a random choice whether to fit a linked section if there are any
    --flip the coin and see if to fit the next linked section
    fit_links = ((math.random(0, 1) == 1) or fit_all_links) and not fit_no_links  --or force all to fit if fit_all_links flag is set or none to be fitted if fit_no_links is set

    --check if there are any linked sections to move
    if #move_link_table == 0 then
      fit_links = false --no links to fit
    elseif #move_link_table >= 2 then --shortest linked section can be two links (-L1 alone should not be valid)


      --***check that this is not fitting over the end of a previous linked section
      --***and process end of last linked section before fit_links becomes invalid from last region processed


      if fit_links then first_link_flag = true end --first_link_flag set as processing this region now
      --dont set last_link_flag true until linked items are fitted later
      first_link_length = GetItemLength(move_link_table[1])
      previous_last_link_length = last_link_length --save the last_link_length in case next section shares region
      last_link_length = GetItemLength(move_link_table[#move_link_table])
    end
    --***may not need these
    if first_link_flag then link_length = first_link_length end --set the space in region to keep empty to fit first link
    if last_link_flag then link_length = last_link_length end --set the space in region to keep empty to fit last link


    --MOVE MATCHING ITEMS
    --------------------------------------------------------------------------
    local move_table = {} --this table is a list of valid matches for linked sections to be randomly moved to this region

    --get highest priority table of matches to move
    for j = 1, 5 do
      if #match_table[j] > 0 then --test for all other priority matches
        move_table = match_table[j] --move_table becomes alias name for the higest priority match_table.
        --nb. the match_table is not actually copied in lua
      end
    end

  ---*** debug

  Msg(" #mvt= "..tostring(#move_table).." #mt1= "..tostring(#match_table[1]).." #mt2= "..tostring(#match_table[2]).." #mt3= "..tostring(#match_table[3]).." #mt4= "..tostring(#match_table[4]).." #mt5= "..tostring(#match_table[5]).."#mlt= "..tostring(#move_link_table).." fl= "..tostring(fit_links).." plr= "..tostring(previous_link_region).." flf= "..tostring(first_link_flag).." fll= "..tostring(first_link_length).." llf= "..tostring(last_link_flag).." lll= "..tostring(last_link_length).." plll= "..tostring(previous_last_link_length).."\n")
  ---***

    if #move_table > 0 then --if there are any matching non-linked items to move
      if previous_link_region then --if we are fitting items to the end of a previous linked section
        last_link_flag = true
        last_link_length = previous_last_link_length
        MoveMatches(is_drum_track, first_link_flag, first_link_length, last_link_flag, last_link_length, move_table, r)
        last_link_flag = false --turn off the last_link_flag after the non linked items have been fitted to the unused end part
        previous_link_region = false

      else MoveMatches(is_drum_track, first_link_flag, first_link_length, last_link_flag, last_link_length, move_table, r) --call move matches function
      last_link_flag = false --turn off the last_link_flag after the non linked items have been fitted to the unused end part

      end
    end
    --***need to check if move matches cant move any matches because they are too big for region then need to see if there are any lower priority matches that might fit
    ----------------------------------------------------------------------------

    --MOVE LINKED ITEMS
    ----------------------------------------------------------------------------
    --If any -L1 matches found check for higher order linked matches from table of -Lx matches

  ---*** debug

  --Msg("MoveAnyLinks? # mlt= "..tostring(#move_link_table).." fl= "..tostring(fit_links).." plr= "..tostring(previous_link_region).."\n")

  ---***


 if #move_link_table >= 2 and fit_links then

---*** debug

--Msg("yes links to move")

---
      MoveLinkedItems(is_drum_track, move_link_table, r)
      --after moving links check if last link filled entire region so we know if any more items needed to fill this last region
      if GetItemLength(move_link_table[#move_link_table]) == GetRegionLength(is_drum_track, r + #move_link_table - 1) then
        previous_link_region = false --it did fill entire region so set flag to know no more items needed
        r = r + #move_link_table -1 -- and point r to region after last link

        ---***debug

        --Msg("and last link filled region\n")

        ---
      else r = r + #move_link_table - 2 --increment region count so that next item to fit is at the same region as the last
      --linked item fitted (so that the unfilled end of region can be filled with matching
      --non linked items. Nb. the region count get incremented by 1 below so allow for this
      last_link_flag = true --now set last_link_flag true so next time around region loop matching non linked items
      --will know to fill just the unfilled end of the region
      previous_link_region = true --remember that this region had a linked section moved to it before moving to next region
      previous_last_link_length = last_link_length

      ---***debug

      --Msg("and last link did not fill region\n")

      ---
      end
    else previous_link_region = false --remember that this region did not have links copied to it next time around loop
    end

    ----------------------------------------------------------------------------

    r = r + 1
  end --END OF REGIONS LOOP

  ------------------------------------------------------------------------------
  --delete the unmoved items
  for i, item in ipairs( init_sel_items ) do
    local track = reaper.GetMediaItemTrack(item)
    reaper.DeleteTrackMediaItem( track, item )
  end

end --END OF MAIN FUNCTION

--------------------------------------------------------------------------------




-- Save item selection
function SaveSelectedItems (table)
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    table[i+1] = reaper.GetSelectedMediaItem(0, i)
  end
end

function RestoreSelectedItems (table)
  for _, item in ipairs(table) do
    reaper.SetMediaItemSelected(item, true)
  end
end
--[[
-- Display a message in the console for debugging
function Msg(value)
  if console then
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
  end
end
--]]
-- Count the number of times a value occurs in a table
function CountOccurencesTable(tt, item)
  local count = 0
  for ii,xx in pairs(tt) do
    if item == xx then count = count + 1 end
  end
  return count
end -- CountOccurencesTable()

-- Remove duplicates from a table array
function RemoveTableDuplicates(tt)
  local newtable = {}
  for ii,xx in ipairs(tt) do
    if (CountOccurencesTable(newtable, xx) == 0) then
      newtable[#newtable+1] = xx
    end
  end
  return newtable
end -- RemoveTableDuplicates()

function MultiSplitMediaItem(item, times) --splits 'item' up into a table of segments returned as 'items'
                                          --'times' is a table of all the split points
  table.sort(times)

  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_end = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + item_pos

  -- create array then reserve some space in array
  local items = {}

  -- add 'item' to 'items' array
  table.insert(items, item)

  -- for each time in times array do...
  for i, time in ipairs(times) do

    if time > item_end then break end

    if time > item_pos and time < item_end then
      --Msg( 'i = ' .. i .. " --- >".. time )

      if item then
        -- store item so we can split it next time around
        item = reaper.SplitMediaItem(item, time)

        -- add resulting item to array
        table.insert(items, item)
      end

    end

  end

  -- return 'items' array
  return items

end

-- CSV to Table
-- http://lua-users.org/wiki/LuaCsv
function ParseCSVLine (line,sep)
  local res = {}
  local pos = 1
   sep = sep or ','
  while true do
    local c = string.sub(line,pos,pos)
    if (c == "") then break end
    if (c == '"') then
      -- quoted value (ignore separator within)
      local txt = ""
      repeat
        local startp,endp = string.find(line,'^%b""',pos)
        txt = txt..string.sub(line,startp+1,endp-1)
        pos = endp + 1
        c = string.sub(line,pos,pos)
        if (c == '"') then txt = txt..'"' end
        -- check first char AFTER quoted string, if it is another
        -- quoted string without separator, then append it
        -- this is the way to "escape" the quote char in a quote. example:
        -- value1,"blub""blip""boing",value3 will result in blub"blip"boing for the middle
      until (c ~= '"')
      table.insert(res,txt)
      assert(c == sep or c == "")
      pos = pos + 1
    else
      -- no quotes used, just look for the first separator
      local startp,endp = string.find(line,sep,pos)
      if (startp) then
        table.insert(res,string.sub(line,pos,startp-1))
        pos = endp + 1
      else
        -- no separator found -> use rest of string and terminate
        table.insert(res,string.sub(line,pos))
        break
      end
    end
  end
  return res
end

function MeasureToSecond( measure, bpm, beat_per_measure, unit )
  local beat_speed = 1 / bpm * 60
  local beat_measure_count = measure[1] * beat_per_measure - beat_per_measure
  local beat_solo_count = measure[2] - 1
  local beat_incomplete = measure[3] * beat_speed / 100
  local beat_total = beat_measure_count + beat_solo_count + beat_incomplete
  return beat_total * beat_speed / ( unit / 4 )
end

function read_lines(filepath)

  local lines = {}

  local f = io.input(filepath)
  repeat

    s = f:read ("*l") -- read one line

    if s then -- if not end of file (EOF)
      table.insert(lines, ParseCSVLine( s, ',' ))
    end

  until not s -- until end of file

  f:close()

  return lines --'lines' is a table of values of table 'line' so like a excel array of csv values

end

function DeleteItems( items )

  for i, item in ipairs( items ) do
    local track = reaper.GetMediaItemTrack( item )
    reaper.DeleteTrackMediaItem( track, item )
  end

end

function SetItemFromBPMToBPM( item, bpm_source, bpm_target )

  local take = reaper.GetActiveTake(item)
  
  local take_type = reaper.TakeIsMIDI( take )
  
  if take_type then goto Midi 
  end 
  do
    local rate = bpm_target / bpm_source
   
    if take then 
      reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", rate)
    end

    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len * ( bpm_source / bpm_target ) )
  
    return rate
  end
::Midi::  

end
--------------------------------------------------------- END OF UTILITIES

-- Main_csv function
function Main_csv() --Start running here

  -- USER CONFIG AREA -----------------------------------------------------------
  
  console = true -- true/false: display debug messages in the console
  
  replace_name = true -- Replace items names by region names from CSV
  
  delete_items = true -- Delete items outside regions
  
  ------------------------------------------------------- END OF USER CONFIG AREA

  -- See if there is items selected  
  count_sel_items = reaper.CountSelectedMediaItems(0)
  
  if count_sel_items < 1 then
    no_sel_items = 1
    goto end_csv
  end  
  
  if count_sel_items > 0 then
  
    --reaper.PreventUIRefresh(1)
  
    --reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
  
    --reaper.ClearConsole()
  
    init_sel_items2 = {}
    SaveSelectedItems(init_sel_items2)
  
    
  
    --reaper.Undo_EndBlock("ReaTrak Split to regions CSV", -1) -- End of the undo block. Leave it at the bottom of your main function.
  
    --reaper.UpdateArrange()
  
    --reaper.PreventUIRefresh(-1)
  end
  
  master_tempo = reaper.Master_GetTempo() -- Note: Not current

  for i, item in ipairs(init_sel_items2) do --In simple instance only one item selected

    local take = reaper.GetActiveTake( item ) --get active take for the selected media 

    local csv_exists = false
    local csv_filename = nil

    if take and not reaper.TakeIsMIDI( take ) then --check it is not MIDI media
      local source = reaper.GetMediaItemTake_Source( take ) --if not MIDI then get the wav or mp3 etc
      local filename = reaper.GetMediaSourceFileName( source, "" ) --Get file name of source media
      csv_filename = filename:gsub("%.(.+)", '.csv') --Change extension to csv
      csv_exists = reaper.file_exists( csv_filename ) --Check if csv file with same name exists
    end
    
    if take and reaper.TakeIsMIDI( take ) then --check it is MIDI media
      os_type = reaper.GetOS()
      sep = string.match(os_type, "Win") and "\\" or "/"
      inipath = reaper.get_ini_file()
      local item_source = reaper.GetMediaItemTake_Source( take )
      local item_filename = reaper.GetMediaSourceFileName( item_source, "" )
      local take_name = reaper.GetTakeName(take)
      --take_name_short = string.match(take_name, "- (.*)") --- not needed done by Script: ReaTrak set midi take name to filename.lua
      retval, midi_location = reaper.BR_Win32_GetPrivateProfileString("reaper", "importpath", "", inipath)
      local filename = tostring(midi_location) .. sep ..(take_name)
      --csv_filename = filename:gsub("%.(.+)", '.csv') --Change extension to csv
      csv_filename = filename:gsub("%.[^%.]+$", '.csv') --Change extension to csv disregard any "." within the filename
      csv_exists = reaper.file_exists( csv_filename ) --Check if csv file with same name exists
    end    

    if not csv_exists then --If csv file is not found in the same directory then ask to import it
      csv_exists, csv_filename = reaper.GetUserFileNameForRead("", "Import items and regions from CSV", "csv")
    end

    if not csv_exists then break end --no luck finding a csv so can't do anything

    local lines = read_lines(csv_filename) --gets csv file data in table 'lines'

    local splits = {} 

    local bpm = tonumber(csv_filename:match('(%d+)bpm')) or 120 -- BPM From file name or default 120

    --local beats, unit = csv_filename:match('bpm[ |_](%d+)-(%d+)') --beats and unit from file name
    local beats, unit = csv_filename:match('(%d+)-(%d+)') --beats and unit from file name
    beats = tonumber( beats )
    unit = tonumber( unit )
    if not beats then beats = 4 end --default to beats = 4
    if not unit then unit = 4 end --default to ubits = 4

    local measure_count = lines[#lines][4] or 4 -- Simply taken from last entry in CSV, assuming it is last position

    
    SetItemFromBPMToBPM( item, bpm, master_tempo )
    local ratio = bpm / master_tempo

    local item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION")
    local offset = ( ( MeasureToSecond( ParseCSVLine( lines[2][3], '%.' ), bpm, beats, unit ) + item_pos ) * ratio ) or 0

    for j, line in ipairs( lines ) do

      if line[1]:find('R') then -- If line is Region and not header or marker

        for column = 3, 5 do
          line[column] = ( MeasureToSecond( ParseCSVLine( line[column], '%.' ), bpm, beats, unit ) + item_pos ) * ratio
        end

        line[3] = line[3] - offset + item_pos -- negative marker compensation (for negative project start) and absolute
                                              --time (CSV is from proj start)
        line[4] = line[4] - offset + item_pos
        -- Insert split position to splits table as start1,end1,start2,end2,start3,end3 ... etc
        table.insert(splits, line[3])
        table.insert(splits, line[4])

      end

    end
        splits = RemoveTableDuplicates(splits) --end1=start2 and end2=start3 etc so remove the duplicates
        new_items = MultiSplitMediaItem(item, splits) --gets table of all the new item segments
    
    delete_items = {}

    for z, new_item in ipairs( new_items ) do

      local take = reaper.GetActiveTake( new_item )
      if take then
        local item_pos = reaper.GetMediaItemInfo_Value( new_item, "D_POSITION")
        local item_end = reaper.GetMediaItemInfo_Value( new_item, "D_LENGTH") + item_pos
        local take_name = reaper.GetTakeName( take )

        local set = false
        --Msg("")
        for k, line in ipairs( lines ) do

          set = false

          if line[1]:find('R') then -- If line is Region and not header or marker
            -- Msg(line[1])
            -- Msg(item_pos .. '=' .. line[3])
            if item_pos == line[3] then

-- check here which of the new_items created by the split correspond to regions and assign color from region to them
        local hex_color = line[6]
        hex = hex_color:gsub("#","") --if # sign is used in front of color code delete it
        local R = tonumber("0x"..hex:sub(1,2)) --Color codes are in reverse order in line table, B is last two digits
        local G = tonumber("0x"..hex:sub(3,4)) --so separate out the R G B components into 2 char strings and get
        local B = tonumber("0x"..hex:sub(5,6)) --decimal value for each component separately
        --color_int = (R + 256 * G + 65536 * B)|16777216  --recombine the components in right order R is least
                                                        --significant, G stays in middle and B is most significant
                                                        --OR with 0x1000000 (16777216 in decimal) to add 1 as 7th hex
                                                        --digit
        --reaper.SetMediaItemInfo_Value(new_item, "I_CUSTOMCOLOR", color_int)
        reaper.SetMediaItemInfo_Value(new_item, "I_CUSTOMCOLOR", reaper.ColorToNative( R, G, B ) |0x1000000) -- Works with Mac Color
        
-- now name the new items
              if replace_name then
                local retval, a_take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", line[2], 1)
              else
                local retval, a_take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name .. "-" .. line[2], 1)
              end
              set = true
              break
            end

          end

        end

        if not set then -- for the last items
          table.insert( delete_items, new_item )
        end

      end

    end

    if delete_items then
      DeleteItems( delete_items )
    end

  end
::end_csv::
end  




function btn_choose()

  start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  reaper.SetEditCurPos( start_time, 0, 0 )

  reaper.Main_OnCommand(40018, 0) -- Insert media files...
  
  reaper.Main_OnCommand(41173, 0) -- Item navigation: Move cursor to start of items
  
  -- Set midi take name to file name
  selitem = reaper.GetSelectedMediaItem( 0, 0 )
  
  if not selitem then goto end_choose end
  
  take = reaper.GetMediaItemTake(selitem, 0)
  
  if take and reaper.TakeIsMIDI( take ) then
  
     takename = reaper.GetTakeName(take)
     
     new_takename = string.match(takename, "- (.*)")
     
     if not new_takename then new_takename = takename end 
     
     retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_takename, 1)
  
  else
      new_takename = reaper.GetTakeName(take)
       
      end
  
  inipath = reaper.get_ini_file()
  
  reaper.BR_Win32_WritePrivateProfileString( "reaper", "reatrakfilename", new_takename, inipath )  
  -- Set midi take name to file name <END>  
  
  reaper.Main_OnCommand(40699, 0) -- Edit: Cut items
  
  ::end_choose:: 
end

function btn_reatrak()

  -- Move cursor to time selection
  start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if start_time == end_time then
    reaper.MB( "Set Time Selection", "Select Track & Time Selection", 0 )
    goto skip
  
  end
  
  get_track =  reaper.CountSelectedTracks2( 0, 0 )
  if get_track ~= 1 then
    reaper.MB( "Select One Target Track", "Select Track & Time Selection", 0 )
    goto skip
  
  end
  
  reaper.SetEditCurPos( start_time, 0, 0 )
  
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
  
  reaper.Main_OnCommand(40718, 0) -- Item: Select all items on selected tracks in current time selection
  
  reaper.Main_OnCommand(40006, 0) -- Item: Remove items

  --commandID1 = reaper.NamedCommandLookup("_RSbe31a3de2526d47fa8357af06379275cceb291c2")
  reaper.Main_OnCommand(40058, 0) -- Item: Paste items/tracks (old-style handling of hidden tracks)
  
  reaper.Main_OnCommand(41173, 0) -- Item navigation: Move cursor to start of items

  no_sel_items = 0
  
  Main_csv() 
  
  if no_sel_items == 1 then
    reaper.MB( "Select Instrument or Drums First", "Select Instrument/Drums", 0 )
    goto skip
  end  
  
  --commandID1 = reaper.NamedCommandLookup("_RSef3a489d9791ceb057ab746d66b82ba461bb33d1")
  --reaper.Main_OnCommand(commandID1, 0) -- Script: ReaTrak Split to regions CSV.lua 

  --reaper.MB( "Pause", "Pause", 0 )  
  Main_move_match()
  --commandID1 = reaper.NamedCommandLookup("_RSd396b5c9d44a2318be8cf27878cc081ca5c5ba9c")
  --reaper.Main_OnCommand(commandID1, 0) -- Script: ReaTrak Move and match.lua  
  
  reaper.UpdateArrange()
  ::skip::
end

function get_region()

  time = reaper.GetCursorPosition()
  markeridx, regionidx = reaper.GetLastMarkerAndCurRegion( 0, time )
  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3( 0, regionidx )

end


function btn_click_count_in()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(255,128,192)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_intro_post_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(119,17,174)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_intro()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(159, 22, 232)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_intro_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(183, 128, 237)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_anywhere()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(228, 26, 39)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_verse_post_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(17, 39, 174)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_verse()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(55, 118, 235)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_verse_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(113, 190, 241)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_verse_ending()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(151, 208, 245)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_set_drum_riff_btn1()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(115, 23, 17, 255)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_bridge_post_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(206, 105, 20)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_bridge()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(234, 133, 48)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_bridge_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(239, 164, 100)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_pre_chorus_post_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(206, 179, 20)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_pre_chorus()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(234, 208, 48)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_pre_chorus_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(244, 231, 151)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_chorus_post_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(11, 116, 39)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_chorus()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(17, 174, 59)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_chorus_fill()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(80, 237, 123)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_chorus_ending()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(158, 254, 182)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_rest()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(0, 0, 0)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_shot()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(127, 127, 127)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_click_hold()
  get_region()
  reaper.SetProjectMarker4( 0, markrgnindexnumber, 1, pos, rgnend, name, reaper.ColorToNative(191, 191, 191)|0x1000000, 0)
  reaper.SetEditCurPos2( 0, rgnend, 0, 0 )
end

function btn_insert_region()

  retval_measures, insert_measures_retvals_csv = reaper.GetUserInputs( "Insert Measures", 1, "Number of Measures", "" )
  
  
  time = reaper.GetCursorPosition()
  
  reaper.Main_OnCommand(40625,0) -- Time selection: Set start point
  
  if retval_measures == true then
    for i = 0, insert_measures_retvals_csv - 1 do
      reaper.Main_OnCommand(41042,0) -- Move edit cursor forward one measure
    end
  
    reaper.Main_OnCommand(40626,0) -- Time selection: Set end point
  
    reaper.Main_OnCommand(40174,0) -- Markers: Insert region from time selection
  
    reaper.Main_OnCommand(40635,0)  -- Time selection: Remove time selection 
  
  
    ----Snap all regions to grid
  
              
    reaper.SetEditCurPos(time, 1, 0)
    
    reaper.Main_OnCommand(40616, 0)  -- Markers: Edit region near cursor
  
  end
  
  reaper.Main_OnCommand(40754, 0) -- Enable snap
  
  region_count , num_markersOut, num_regionsOut = reaper.CountProjectMarkers(0)
  
  for i=0, region_count -1 do
  
    --EnumProjectMarkers(i, is_region, region_start, region_end, #name, region_id)
    retval, isrgnOut, posOut, rgnendOut, region_name, markrgnindexnumberOut, colorOut = reaper.EnumProjectMarkers3(0, i)      
  
    region_snapped_start =  reaper.SnapToGrid(0, posOut)
    region_snapped_end =  reaper.SnapToGrid(0, rgnendOut) 
   
    reaper.SetProjectMarker3( 0, markrgnindexnumberOut, isrgnOut, region_snapped_start, region_snapped_end, region_name , colorOut )
   
  end
  
  



end

function btn_region_plus()
  transpose = "1"
  transpose_chords(transpose)
end

function btn_region_minus()
  transpose = "2"
  transpose_chords(transpose)

end


function transpose_chords(transpose)

    --Msg("transpose "..transpose)
    region_count , num_markersOut, num_regionsOut = reaper.CountProjectMarkers(0)
        
      
    start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    
    markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())       
    retval1, isrgnOut1, posOut1, rgnendOut1, region_name1, markrgnindexnumberOut1, colorOut1 = reaper.EnumProjectMarkers3(0, regionidx)
    
    if start_time == end_time then
      start_time = posOut1
      end_time = rgnendOut1
    end

              
    for i=0, region_count -1 do
  --Msg("region_name")
  --Msg(region_name)
        region_name = ""      
        --markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())       
        retval, isrgnOut, posOut, rgnendOut, region_name, markrgnindexnumberOut, colorOut = reaper.EnumProjectMarkers3(0, i)      
        --cursor_pos = reaper.GetCursorPosition()
        --if cursor_pos >= end_time then break end    
        --Msg(markrgnindexnumberOut.." "..region_name)
        chord, p = nil, 0
        root, chord = string.match(region_name, "(%w[#b]?)(.*)$")
        --switches = string.match( region_name, "-%a.*")
        --if not chord or #chord == 0 then chord = "" end
        if string.match( region_name, "%s *") then root = "" chord = "" i=i +1 end -- skip region marked @ ignore
        
        if region_name == "" then root = "" chord = "" i=i +1 end
        
         
        if string.find(region_name, "-%a.*")  == 1 then root = "" chord = "" end  
   
        var = chord
          
         if ("" == root and (transpose == "1" or transpose == "2")) then new_region_name = region_name
         elseif ("C" == root and (transpose == "1")) then new_region_name = "C#"..var 
         elseif ("C#" == root and (transpose == "1")) then new_region_name = "D"..var
         elseif ("Db" == root and (transpose == "1")) then new_region_name = "D"..var
         elseif ("D" == root and (transpose == "1")) then new_region_name = "D#"..var
         elseif ("D#" == root and (transpose == "1")) then new_region_name = "E"..var
         elseif ("Eb" == root and (transpose == "1")) then new_region_name = "E"..var
         elseif ("E" == root and (transpose == "1")) then new_region_name = "F"..var
         elseif ("F" == root and (transpose == "1")) then new_region_name = "F#"..var
         elseif ("F#" == root and (transpose == "1")) then new_region_name = "G"..var
         elseif ("Gb" == root and (transpose == "1")) then new_region_name = "G"..var
         elseif ("G" == root and (transpose == "1")) then new_region_name = "G#"..var
         elseif ("G#" == root and (transpose == "1")) then new_region_name = "A"..var
         elseif ("Ab" == root and (transpose == "1")) then new_region_name = "A"..var
         elseif ("A" == root and (transpose == "1")) then new_region_name = "A#"..var
         elseif ("A#" == root and (transpose == "1")) then new_region_name = "B"..var
         elseif ("Bb" == root and (transpose == "1")) then new_region_name = "B"..var
         elseif ("B" == root and (transpose == "1")) then new_region_name = "C"..var
         
          
         elseif ("" == root and (transpose == "2")) then new_region_name = region_name
         elseif ("C" == root and (transpose == "2")) then new_region_name = "B"..var
         elseif ("C#" == root and (transpose == "2")) then new_region_name = "C"..var
         elseif ("Db" == root and (transpose == "2")) then new_region_name = "C"..var
         elseif ("D" == root and (transpose == "2")) then new_region_name = "C#"..var
         elseif ("D#" == root and (transpose == "2")) then new_region_name = "D"..var
         elseif ("Eb" == root and (transpose == "2")) then new_region_name = "D"..var
         elseif ("E" == root and (transpose == "2")) then new_region_name = "D#"..var
         elseif ("F" == root and (transpose == "2")) then new_region_name = "E"..var
         elseif ("F#" == root and (transpose == "2")) then new_region_name = "F"..var
         elseif ("Gb" == root and (transpose == "2")) then new_region_name = "F"..var
         elseif ("G" == root and (transpose == "2")) then new_region_name = "F#"..var
         elseif ("G#" == root and (transpose == "2")) then new_region_name = "G"..var
         elseif ("Ab" == root and (transpose == "2")) then new_region_name = "G"..var
         elseif ("A" == root and (transpose == "2")) then new_region_name = "G#"..var
         elseif ("A#" == root and (transpose == "2")) then new_region_name = "A"..var
         elseif ("Bb" == root and (transpose == "2")) then new_region_name = "A"..var
         elseif ("B" == root and (transpose == "2")) then new_region_name = "A#"..var
         
         end
         
         
         --Msg(markrgnindexnumberOut.." "..region_name)
    
         if new_region_name and posOut >= start_time and posOut < end_time then 
           --Msg("new_region_name "..new_region_name)
           --reaper.SetProjectMarker3(0, markrgnindexnumberOut, true, posOut, rgnendOut, new_region_name, colorOut)
           reaper.SetProjectMarker4(0, markrgnindexnumberOut, true, posOut, rgnendOut, new_region_name, 0, 0) 
         end
       
    
    end


end


function btn_decay()

  cursor_pos = reaper.GetCursorPosition()
  
  --Msg("Cursor Position "..cursor_pos)
  
  --commandID1 = reaper.NamedCommandLookup("_RS8271ddb3a652d6fe57b7abc7efadff407c8da2d0")
      --reaper.Main_OnCommand(commandID1, 0) --Script: ReaTrak move edit cursor to start of project.lua
  --reaper.MB("Cursor at Start", "Information", 0)
  commandID2 = reaper.NamedCommandLookup("_XENAKIOS_SELFIRSTITEMSOFTRACKS")
      reaper.Main_OnCommand(commandID2, 0) --Xenakios Extensions : Select first item(s) of selected track(s)
      --reaper.MB("Select firt item", "Information", 0)
  --commandID3 = reaper.NamedCommandLookup("_RS4067e957c605022af2990333666ab2b593383147")
      --reaper.Main_OnCommand(commandID3, 0) --Script: ReaTrak Move edit cursor to first selected item snap offset.lua    
  
  -- Move edit cursor to first selected item snap offset      
  -- USER CONFIG AREA -----
  move_view = false -- false, true
  -------------------------
  
  item = reaper.GetSelectedMediaItem(0, 0)
  
  if item ~= nil then
    
    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    
    item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    
    pos = item_pos + item_snap
    
    reaper.SetEditCurPos(pos, move_view, false)
      
    reaper.Undo_EndBlock("Move edit cursor to first selected item snap offset", -1) -- End of the undo block. Leave it at the bottom of your main function.
    
    reaper.UpdateArrange() -- Update the arrangement (often needed)
        
  end
  
  goto check
      
  ::check::     
    item = reaper.GetSelectedMediaItem(0,0)
    --if not chord or #chord == 0 then
    if item == nil then goto finish end
    take = reaper.GetMediaItemTake(item, 0)
  
    takename = reaper.GetTakeName(take)
   -- Msg("Take Name :"..takename)
     --if = string.find(takename, "-D,?(%d*)", 1, true) -- set to check for -D1 or -D2 1 bar or 2 bar decay
     if string.match(takename, "-D1", 1, true) then goto decay1 end
     if string.match(takename, "-D2", 1, true) then goto decay2 end
     if string.match(takename, "-D", 1, true) then goto decay end
     
    reaper.Main_OnCommand(40289, 0) --Item: Unselect all items
    reaper.Main_OnCommand(40417, 0) --Item navigation: Select and move to next item
     
    goto check
  
  
  ::decay1::
  --Msg("1 Bar Decay set on:"..takename)
  
  -- MODIFY TAKE
  --newtakename =""
  
  newtakename = string.gsub(takename, "-D1", "") 
  retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newtakename, 1)
  
  reaper.Main_OnCommand(40319, 0) --Item navigation: Move cursor right to edge of item
  reaper.Main_OnCommand(41042, 0) --Move edit cursor forward one measure
  --reaper.Main_OnCommand(41042, 0) --Move edit cursor forward one measure
  reaper.Main_OnCommand(41045, 0) --Move edit cursor back one beat
  reaper.Main_OnCommand(40611, 0) --Item: Set item end to cursor
  
   
   
  commandID3 = reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
      reaper.Main_OnCommand(commandID3, 0) -- Xenakios Extensions : Select items under edit cursor on selected tracks _XENAKIOS_SELITEMSUNDEDCURSELTX
  
  --commandID4 = reaper.NamedCommandLookup("_eb97fc0933296c48a1ddfff48d6c3f22")
      --reaper.Main_OnCommand(commandID4, 0) -- Custom: ReaTrak remove crossfade
   
      -- Move edit cursor to first selected item snap offset      
      -- USER CONFIG AREA -----
      move_view = false -- false, true
      -------------------------
      
      item = reaper.GetSelectedMediaItem(0, 0)
      
      if item ~= nil then
        
        reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
        
        item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        
        item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
        
        pos = item_pos + item_snap
        
        reaper.SetEditCurPos(pos, move_view, false)
          
        reaper.Undo_EndBlock("Move edit cursor to first selected item snap offset", -1) -- End of the undo block. Leave it at the bottom of your main function.
        
        reaper.UpdateArrange() -- Update the arrangement (often needed)
            
      end
      
  
    reaper.Main_OnCommand(40289, 0) --Item: Unselect all items
    reaper.Main_OnCommand(40417, 0) --Item navigation: Select and move to next item   
    reaper.Main_OnCommand(40416, 0) --Item navigation: Select and move to previous item
      
      
  goto check
  
  
  ::decay2::
  --Msg("2 Bar Decay set on:"..takename)
  
  -- MODIFY TAKE
  --newtakename =""
  
  newtakename = string.gsub(takename, "-D2", "")
  retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newtakename, 1)
  
  reaper.Main_OnCommand(40319, 0) --Item navigation: Move cursor right to edge of item
  reaper.Main_OnCommand(41042, 0) --Move edit cursor forward one measure
  reaper.Main_OnCommand(41042, 0) --Move edit cursor forward one measure
  reaper.Main_OnCommand(41045, 0) --Move edit cursor back one beat
  reaper.Main_OnCommand(40611, 0) --Item: Set item end to cursor
  
  
   
   
  commandID3 = reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
      reaper.Main_OnCommand(commandID3, 0) -- Xenakios Extensions : Select items under edit cursor on selected tracks _XENAKIOS_SELITEMSUNDEDCURSELTX
  
  --commandID4 = reaper.NamedCommandLookup("_eb97fc0933296c48a1ddfff48d6c3f22")
      --reaper.Main_OnCommand(commandID4, 0) -- Custom: ReaTrak remove crossfade
      
  -- Move edit cursor to first selected item snap offset      
  -- USER CONFIG AREA -----
  move_view = false -- false, true
  -------------------------
  
  item = reaper.GetSelectedMediaItem(0, 0)
  
  if item ~= nil then
    
    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    
    item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    
    pos = item_pos + item_snap
    
    reaper.SetEditCurPos(pos, move_view, false)
      
    reaper.Undo_EndBlock("Move edit cursor to first selected item snap offset", -1) -- End of the undo block. Leave it at the bottom of your main function.
    
    reaper.UpdateArrange() -- Update the arrangement (often needed)
        
  end    
      
    reaper.Main_OnCommand(40289, 0) --Item: Unselect all items
    --reaper.Main_OnCommand(40417, 0) --Item navigation: Select and move to next item
    --reaper.Main_OnCommand(41044, 0) --Move edit cursor forward one beat  
    reaper.Main_OnCommand(41043, 0) --Move edit cursor back one measure
    reaper.Main_OnCommand(41043, 0) --Move edit cursor back one measure
  commandID5 = reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
      reaper.Main_OnCommand(commandID5, 0) -- Xenakios Extensions : Select items under edit cursor on selected tracks _XENAKIOS_SELITEMSUNDEDCURSELTX
        
  reaper.Main_OnCommand(40417, 0) --Item navigation: Select and move to previous item          
      
  goto check
  
  
  ::decay::
  --Msg("Decay set on:"..takename)
  
  -- MODIFY TAKE
  --newtakename =""
  
  newtakename = string.gsub(takename, "-D", "")
  retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newtakename, 1)
  
  reaper.Main_OnCommand(40319, 0) --Item navigation: Move cursor right to edge of item
  reaper.Main_OnCommand(41042, 0) --Move edit cursor forward one measure
  reaper.Main_OnCommand(41042, 0) --Move edit cursor forward one measure
  reaper.Main_OnCommand(41045, 0) --Move edit cursor back one beat
  reaper.Main_OnCommand(40611, 0) --Item: Set item end to cursor
  
   
   
  commandID3 = reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
      reaper.Main_OnCommand(commandID3, 0) -- Xenakios Extensions : Select items under edit cursor on selected tracks _XENAKIOS_SELITEMSUNDEDCURSELTX
  
  --commandID4 = reaper.NamedCommandLookup("_eb97fc0933296c48a1ddfff48d6c3f22")
      --reaper.Main_OnCommand(commandID4, 0) -- Custom: ReaTrak remove crossfade
      
  -- Move edit cursor to first selected item snap offset      
  -- USER CONFIG AREA -----
  move_view = false -- false, true
  -------------------------
  
  item = reaper.GetSelectedMediaItem(0, 0)
  
  if item ~= nil then
    
    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    
    item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    
    pos = item_pos + item_snap
    
    reaper.SetEditCurPos(pos, move_view, false)
      
    reaper.Undo_EndBlock("Move edit cursor to first selected item snap offset", -1) -- End of the undo block. Leave it at the bottom of your main function.
    
    reaper.UpdateArrange() -- Update the arrangement (often needed)
        
  end    
      
    reaper.Main_OnCommand(40289, 0) --Item: Unselect all items
    --reaper.Main_OnCommand(40417, 0) --Item navigation: Select and move to next item
    --reaper.Main_OnCommand(41044, 0) --Move edit cursor forward one beat  
    reaper.Main_OnCommand(41043, 0) --Move edit cursor back one measure
    reaper.Main_OnCommand(41043, 0) --Move edit cursor back one measure
  commandID5 = reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
      reaper.Main_OnCommand(commandID5, 0) -- Xenakios Extensions : Select items under edit cursor on selected tracks _XENAKIOS_SELITEMSUNDEDCURSELTX
        
  reaper.Main_OnCommand(40417, 0) --Item navigation: Select and move to previous item     
      
  goto check
  
  
  ::finish::
  --Msg("Move Cursor to "..cursor_pos)
  reaper.SetEditCurPos(cursor_pos, true, true)



end




------------------------------------
-------- Window settings -----------
------------------------------------


GUI.name = "Instant Traks Instrument/Drums"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 400, 300
GUI.anchor, GUI.corner = "mouse", "C"




------------------------------------
-------- GUI Elements --------------
------------------------------------


--[[     

  Button          z,      x,      y,      w,      h, caption, func[, ...]
  Checklist     z,      x,      y,      w,      h, caption, opts[, dir, pad]
  Menubox          z,      x,      y,      w,      h, caption, opts, pad, noarrow]
  Slider          z,      x,      y,      w,      caption, min, max, defaults[, inc, dir]
  
]]--
--[[
GUI.New("mnu_mode",     "Menubox",          1, 64,     32,  72, 20, "Mode:", "Auto,Punch,Step")
GUI.New("chk_opts",     "Checklist",     1, 192,     32,  192, 96, "Options", "Only in time selection,Only on selected track,Glue items when finished", "v", 4)
GUI.New("sldr_thresh", "Slider",     1, 32,  96, 128, "Threshold", -60, 0, 48, nil, "h")
GUI.New("btn_go",     "Button",          1, 168, 152, 64, 24, "Go!", btn_click)

GUI.New("my_txt",   "Textbox",     1, 50, 130, 120, 20, "Text:", 4)

GUI.Val("my_txt") --Returns the contents of the textbox.
GUI.Val("my_txt", "Hello, world!") --Sets the contents of the textbox.
--]]
GUI.New("my_lbl",   "Label",     1, 100, 10, "Instant Trak Creator", true, 1)

GUI.New("btn_choose",     "Button",          1, 34, 50, 160, 24, "Browse Instrument/Drum", btn_choose)
GUI.elms.btn_choose.col_txt = "black"
GUI.elms.btn_choose.col_fill = "verse_fill"

GUI.New("btn_reatrak",     "Button",          1, 200, 50, 160, 24, "ReaTrack Section", btn_reatrak)
GUI.elms.btn_reatrak.col_txt = "white"
GUI.elms.btn_reatrak.col_fill = "green"

GUI.New("btn_insert_region",     "Button",          1, 120, 85, 120, 24, "Insert Region", btn_insert_region)
GUI.elms.btn_insert_region.col_txt = "white"
GUI.elms.btn_insert_region.col_fill = "black"

GUI.New("btn_region_plus",     "Button",          1, 10, 85, 30, 18, "+", btn_region_plus)
GUI.elms.btn_region_plus.font = {"Arial", 00, "b"}
GUI.elms.btn_region_plus.col_txt = "white"
GUI.elms.btn_region_plus.col_fill = "black"

GUI.New("btn_region_minus",     "Button",          1, 10, 110, 30, 18, "-", btn_region_minus)
GUI.elms.btn_region_minus.font = {"Arial", 00, "b"}
GUI.elms.btn_region_minus.col_txt = "white"
GUI.elms.btn_region_minus.col_fill = "black"

GUI.New("btn_decay",     "Button",          1, 280, 85, 70, 24, "Decay -D", btn_decay)
GUI.elms.btn_decay.col_txt = "white"
GUI.elms.btn_decay.col_fill = "gray"

x1 = 1
y1 = 80


GUI.New("my_lb2",   "Label",     1, 130+x1, 40+y1, "Set Region Color", true, 2)

GUI.New("count_in_btn",      "Button",           3, 10+x1, 65+y1, 70, 20, "Count-In", btn_click_count_in)
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

GUI.New("anywhere_btn",      "Button",           3, 320+x1, 65+y1, 60, 20, "Anywhere", btn_click_anywhere)
GUI.elms.anywhere_btn.col_txt = "btn_txt1"
GUI.elms.anywhere_btn.col_fill = "play_anywhere"

GUI.New("verse_post_fill_btn",      "Button",           3, 10+x1, 95+y1, 95, 20, "Verse Post Fill", btn_click_verse_post_fill)
GUI.elms.verse_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.verse_post_fill_btn.col_fill = "verse_post_fill"

GUI.New("verse_btn",      "Button",           3, 110+x1, 95+y1, 95, 20, "Verse", btn_click_verse)
GUI.elms.verse_btn.col_txt = "btn_txt1"
GUI.elms.verse_btn.col_fill = "verse"

GUI.New("verse_fill_btn",      "Button",           3, 210+x1, 95+y1, 70, 20, "Verse Fill", btn_click_verse_fill)
GUI.elms.verse_fill_btn.col_txt = "btn_txt3"
GUI.elms.verse_fill_btn.col_fill = "verse_fill"

GUI.New("verse_ending_btn",      "Button",           3, 285+x1, 95+y1, 90, 20, "Verse Ending ", btn_click_verse_ending)
GUI.elms.verse_ending_btn.col_txt = "btn_txt3"
GUI.elms.verse_ending_btn.col_fill = "verse_ending"


-- Sections Row 2
 
GUI.New("bridge_post_fill_btn",      "Button",           3, 10+x1, 125+y1, 95, 20, "Bridge Post Fill", btn_click_bridge_post_fill)
GUI.elms.bridge_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.bridge_post_fill_btn.col_fill = "bridge_post_fill" 

GUI.New("bridge_btn",      "Button",           3, 110+x1, 125+y1, 60, 20, "Bridge", btn_click_bridge)
GUI.elms.bridge_btn.col_txt = "btn_txt3"
GUI.elms.bridge_btn.col_fill = "bridge"

GUI.New("bridge_fill_btn",      "Button",           3, 175+x1, 125+y1, 70, 20, "Bridge Fill", btn_click_bridge_fill)
GUI.elms.bridge_fill_btn.col_txt = "btn_txt3"
GUI.elms.bridge_fill_btn.col_fill = "bridge_fill"

GUI.New("pre_chorus_post_fill_btn",      "Button",           3, 10+x1, 155+y1, 115, 20, "Pre Chorus Post Fill", btn_click_pre_chorus_post_fill)
GUI.elms.pre_chorus_post_fill_btn.col_txt = "btn_txt3"
GUI.elms.pre_chorus_post_fill_btn.col_fill = "pre_chorus_post_fill"

GUI.New("pre_chorus_btn",      "Button",           3, 135+x1, 155+y1, 75, 20, "Pre Chorus", btn_click_pre_chorus)
GUI.elms.pre_chorus_btn.col_txt = "btn_txt3"
GUI.elms.pre_chorus_btn.col_fill = "pre_chorus"

GUI.New("pre_chorus_fill_btn",      "Button",           3, 215+x1, 155+y1, 95, 20, "Pre Chorus Fill", btn_click_pre_chorus_fill)
GUI.elms.pre_chorus_fill_btn.col_txt = "btn_txt3"
GUI.elms.pre_chorus_fill_btn.col_fill = "pre_chorus_fill"

GUI.New("chorus_post_fill_btn",      "Button",           3, 10+x1, 185+y1, 95, 20, "Chorus Post Fill", btn_click_chorus_post_fill)
GUI.elms.chorus_post_fill_btn.col_txt = "btn_txt1"
GUI.elms.chorus_post_fill_btn.col_fill = "chorus_post_fill"

GUI.New("set_drum_riff_btn1",      "Button",           3, 315+x1, 155+y1, 75, 20, "Drum Riff", btn_click_set_drum_riff_btn1)
GUI.elms.set_drum_riff_btn1.col_txt = "btn_txt1"
GUI.elms.set_drum_riff_btn1.col_fill = "drum_riff"

GUI.New("chorus_btn",      "Button",           3, 110+x1, 185+y1, 85, 20, "Chorus", btn_click_chorus)
GUI.elms.chorus_btn.col_txt = "btn_txt1"
GUI.elms.chorus_btn.col_fill = "chorus"

GUI.New("chorus_fill_btn",      "Button",           3, 200+x1, 185+y1, 70, 20, "Chorus Fill", btn_click_chorus_fill)
GUI.elms.chorus_fill_btn.col_txt = "btn_txt3"
GUI.elms.chorus_fill_btn.col_fill = "chorus_fill"

GUI.New("chorus_ending_btn",      "Button",           3, 275+x1, 185+y1, 90, 20, "Chorus Ending ", btn_click_chorus_ending)
GUI.elms.chorus_ending_btn.col_txt = "btn_txt3"
GUI.elms.chorus_ending_btn.col_fill = "chorus_ending"

-- Sections Row 2


GUI.New("rest_btn",      "Button",           3, 255+x1, 125+y1, 40, 20, "Rest", btn_click_rest)
GUI.elms.rest_btn.col_txt = "btn_txt1"
GUI.elms.rest_btn.col_fill = "rest"

GUI.New("shot_btn",      "Button",           3, 305+x1, 125+y1, 40, 20, "Shot", btn_click_shot)
GUI.elms.shot_btn.col_txt = "btn_txt1"
GUI.elms.shot_btn.col_fill = "shot"

GUI.New("hold_btn",      "Button",           3, 350+x1, 125+y1, 40, 20, "Hold", btn_click_hold)
GUI.elms.hold_btn.col_txt = "btn_txt3"
GUI.elms.hold_btn.col_fill = "hold"


GUI.Init()
GUI.Main()
