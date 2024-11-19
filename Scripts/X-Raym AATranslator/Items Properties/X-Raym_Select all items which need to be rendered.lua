--[[
 * ReaScript Name: Select all items which need to be rendered
 * Instructions: Run.
 * Screenshot: https://i.imgur.com/K4sDKWb.gifv
 * About: A way to select all items which may need to be rendered, for AATranslator workflow for eg.
 * Author: X-Raym
 * Author URI: https://www.extremraym.com
 * Repository: X-Raym Premium Scripts
 * Licence: GPL v3
 * REAPER: 5.0
 * Version: 1.5.9
--]]

--[[
 * Changelog:
 * v1.5.9 (2024-09-23)
  # Fix for envelopes
 * v1.5.8 (2024-09-22)
  # Field to ignore volume envelope for AAT v2
 * v1.5.7 (2024-09-20)
  # Only consider active env (need REAPER v7+)
 * v1.5.5 (2024-09-20)
  # Fix take env break
 * v1.5.4 (2023-12-08)
  # Support special character in media FilePath
  # Path debug info
 * v1.5.3 (2023-07-17)
  # SWS dependency warning
 * v1.5.2 (2023-05-06)
  # SWS dependency warning
 * v1.5 (2021-04-05)
  + Preset file support
  # better get bith depth function
 * v1.4 (2020-09-24)
  # Fix input
  # Add save last input
 * v1.3.1 (2020-01-15)
  # Fix project sample rate
 * v1.3 (2019-11-03)
  + items not in project folder
 * v1.2.2 (2019-10-07)
  # select invalid source
 * v1.2.1 (2019-10-07)
  # Take envelope except volume become all envelopes
 * v1.2 (2018-07-01)
  + User input
  # Bug fix
 * v1.1.4 (2018-06-21)
  * Don't select missing files
 * v1.1.3 (2018-06-21)
  * Fix fades shapes by deactivating auto-crossfade
 * v1.1.2 (2018-06-20)
  # sel fix
 * v1.1.1 (2018-06-20)
  # loop detection fades fix
 * v1.1 (2018-06-15)
  # No BWFMetaEdit dependency
  # Loop correction
  # Console optimization
 * v1.0.1 (2018-06-15)
  # deactivate console
 * v1.0 (2018-06-15)
  + Initial release
--]]

-- For Vijay Rathinam

-- USER CONFIG AREA -----------------------------------------------------------

select_missing_files = false

console = true -- true/false: display debug messages in the console

popup = true

vars = vars or {}
vars.project_bit_depth = 24
vars.reverse = "y"
vars.playrate = "y"
vars.channel = "y"
vars.stretch = "y"
vars.pitch = "y"
vars.takefx = "y"
vars.notwav = "y"
vars.env = "y"
vars.vol_env = "y"
vars.rate = "y"
vars.loop = "y"
vars.bit = "y"
vars.folder = "y"

undo_text = "Select all items which need to be rendered"
input_title = "Selection conditions"

------------------------------------------------------- END OF USER CONFIG AREA

vars_order = {"project_bit_depth", "reverse", "playrate", "channel", "stretch", "pitch", "takefx", "notwav", "env", "vol_env", "rate", "loop", "bit", "folder"}
ext_name = "XR_SelItemsToRender"

sep = "\n"
extrawidth = ""
separator = "separator=" .. sep

instructions = instructions or {}
instructions.project_bit_depth = "Project bit depth?"
instructions.reverse  = "Reversed? (y/n)"
instructions.playrate = "Playrate ~= 1? (y/n)"
instructions.channel  = "Channel not default? (y/n)"
instructions.stretch = "Stretch Markers? (y/n)"
instructions.pitch  = "Pitch offset? (y/n)"
instructions.takefx  = "Take FX? (y/n)"
instructions.notwav  = "Not WAV file? (y/n)"
instructions.env = "Take envelope? (y/n)"
instructions.vol_env = "... and Take Volume Env? (y/n)"
instructions.rate = "Sample rate not ≠ to project? (y/n)"
instructions.loop = "Loop? (y/n)"
instructions.bit = "Bit depth ≠ project? (y/n)"
instructions.folder = "Src not in ProjDir? (y/n)"

-- UTILITIES -------------------------------------------------------------

local reaper = reaper
local msg = {}
-- Display a message in the console for debugging
function Msg(value)
  if console then
    table.insert( msg, tostring( value ) )
  end
end

-- Console Message
function Msg2(g)
  if console then
    reaper.ShowConsoleMsg(tostring(g).."\n")
  end
end


function PrintMsg()
  if console then
    reaper.ShowConsoleMsg(table.concat(msg, '\n'))
  end
end

-----------------------------------------------------------
-- STATES --
-----------------------------------------------------------
function SaveState()
  for k, v in pairs( vars ) do
    reaper.SetExtState( ext_name, k, tostring(v), true )
  end
end

function GetExtState( var, val )
  local t = type( val )
  if reaper.HasExtState( ext_name, var ) then
    val = reaper.GetExtState( ext_name, var )
  end
  if t == "boolean" then val = toboolean( val )
  elseif t == "number" then val = tonumber( val )
  else
  end
  return val
end

function GetValsFromExtState()
  for k, v in pairs( vars ) do
    vars[k] = GetExtState( k, vars[k] )
  end
end

function ConcatenateVarsVals(t, sep, vars_order)
  local vals = {}
  for i, v in ipairs( vars_order ) do
    vals[i] = t[v]
  end
  return table.concat(vals, sep)
end

function ParseRetvalCSV( retvals_csv, sep, vars_order )
  local t = {}
  local i = 0
  for line in retvals_csv:gmatch("[^" .. sep .. "]*") do
  i = i + 1
  t[vars_order[i]] = line
  end
  return t
end

function ValidateVals( vars, vars_order )
  local validate = true
  for i, v in ipairs( vars_order ) do
    if vars[v] == nil then
      validate = false
      break
    end
  end
  return validate
end

function toboolean( val )
  local out = nil
  if val == "false" then out = false
  elseif val == "y" then out = true
  elseif val == "n" then out = false
  elseif val == "true" then out = true
  elseif val == 0 then out = false
  elseif val == 1 then out = true
  elseif val == "" then out = false
  elseif type(val) == "table" then out = false
  else out = nil end
  return out
end

-- https://helloacm.com/split-a-string-in-lua/
function split(s, delimiter)
  result = {}
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match)
  end
  return result
end

--------------------------------------------------------- END OF UTILITIES

-- Main function
function Main()

  select_items = {}

  --project_sample_rate = tonumber(reaper.format_timestr_pos( 1, '', 4 ))
  project_sample_rate = reaper.GetSetProjectInfo( 0, "PROJECT_SRATE", 0, false )

  for i = 0, count_items - 1 do

    local select = false
    local missing = false

    local item = reaper.GetMediaItem( 0, i )
    local take = reaper.GetActiveTake( item )
    if take and not reaper.TakeIsMIDI( take ) then

      local take_name = reaper.GetTakeName( take ) -- For debug

      local source =  reaper.GetMediaItemTake_Source( take )

      if not source then

        select = true
        Msg(take_name .. "Invalid source")

      else

        local source_section = reaper.GetMediaSourceParent( source ) -- Necesseary for reversed section cause reversed section have 'SECTION' section type
        if source_section then source = source_section end

      end

      -- Reverse
      if vars.reverse and not select then
        local retval, section, start, length, fade, reverse = reaper.BR_GetMediaSourceProperties( take )
        if reverse then
          select = true
          Msg(take_name .. " = reversed")
        end
      end

      -- Playrate not 1
      if vars.playrate and not select then
        local playrate = reaper.GetMediaItemTakeInfo_Value( take, "D_PLAYRATE" )
        if playrate ~= 1 then
          select = true
          Msg(take_name .. " = playrate not 1")
        end
      end

      -- Channel
      if vars.channel and not select then
        local chan = reaper.GetMediaItemTakeInfo_Value( take, "I_CHANMODE" )
        if chan ~= 0 then
          select = true
          Msg(take_name .. " = chan not default")
        end
      end

      -- Stretch markers > 1
      if vars.stretch and not select then
        local stretch_markers = reaper.GetTakeNumStretchMarkers( take )
        if stretch_markers > 0 then
          select = true
          Msg(take_name .. " = stretch markers > 0 ")
        end
      end

      -- Pitch offset
      if vars.pitch and not select then
        local pitch = reaper.GetMediaItemTakeInfo_Value( take, "D_PITCH" )
        if pitch ~= 0 then
          select = true
          Msg(take_name .. " = pitch offset ")
        end
      end

      -- Take FX
      if vars.takefx and not select then
        local take_fx = reaper.TakeFX_GetCount( take )
        if take_fx > 0 then
          select = true
          Msg(take_name .. " = take_fx ")
        end
      end

      -- Source not WAV
      if vars.notwav and not select then
        local typebuf = reaper.GetMediaSourceType( source, '' )
        if typebuf ~= 'WAVE' then
          select = true
          Msg(take_name .. " = not WAVE ")
        end
      end

      -- Take Env not Volume
      if vars.env and not select then
        count_env = reaper.CountTakeEnvelopes( take )
        --for j = 0, count_env - 1 do
          --local env = reaper.GetTakeEnvelope( take, j )
          --local retval, env_name = reaper.GetEnvelopeName(env, '')
          --if env_name ~= 'Volume' then
        if count_env > 0 then
          if reaper.GetSetEnvelopeInfo_String then -- check if active
            for envidx = 0, count_env - 1 do
              local env = reaper.GetTakeEnvelope( take, envidx )
              local retval, env_name = reaper.GetEnvelopeName( env )
              local retval, str = reaper.GetSetEnvelopeInfo_String( env, "ACTIVE", "", false )
              if str == '1' and (env_name ~= "Volume" or vars.vol_env) then
                select = true
                Msg(take_name .. " = envelopes > 0")
                break
              end
            end
          
          else -- select anyway
            select = true 
            -- Msg(take_name .. " = take envelopes ~= Volume")
            Msg(take_name .. " = envelopes > 0")
          end
        end
      end

      -- Sample Rate
      if vars.rate and not select then
        local sample_rate = reaper.GetMediaSourceSampleRate( source )
        if sample_rate ~= project_sample_rate then
          select = true
          if sample_rate == 0 then
            missing = true
            Msg(take_name .. " = missing file =\t select: " .. tostring( select_missing_files ) )
          else
            Msg(take_name .. " = sample rate =\t" .. sample_rate)
          end
        end
      end

      -- Loop
      if vars.loop and not select then
        if IsTakeLooping( item, take ) then
          select = true
          Msg(take_name .. " = loop")
        end
      end

      -- Bit Depth
      if vars.bit and not select and project_bit_depth then
        source_bit_depth =  reaper.CF_GetMediaSourceBitDepth( source )
        if project_bit_depth and project_bit_depth ~= source_bit_depth  then
          select = true
          Msg(take_name .. " = bit_depth = " .. source_bit_depth)
        end
      end

      -- Project Folder
      if vars.folder and not select then
        local FilePath  = reaper.GetMediaSourceFileName(source , "")  -- Source FilePath
        local project_dir = reaper.GetProjectPath('')
        local FileFolder = FilePath:match("(.*[\\|/])")
        if FileFolder ~= project_dir then
          select = true
          Msg(take_name .. " = Not in project dir")
          Msg( "\tFile = " .. FilePath )
          Msg( "\tProj = " .. project_dir )
        end
      end

      -- Select
      if select then
        if missing == false or ( select_missing_files and missing ) then
          table.insert( select_items, item )
        end
      end

    end

  end

  for i, item in ipairs( select_items )  do
    reaper.SetMediaItemSelected( item, true )
  end

end

-- Functions
function IsTakeLooping( item, take )

  local entry = {}
  entry.item = item
  entry.take = take

  entry.item_properties = {}
  entry.item_properties.D_POSITION = reaper.GetMediaItemInfo_Value(item, "D_POSITION" )
  entry.item_properties.D_LENGTH = reaper.GetMediaItemInfo_Value(item, "D_LENGTH" )
  entry.item_properties.D_FADEINLEN_AUTO = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO" )
  entry.item_properties.D_FADEOUTLEN_AUTO = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO" )
  entry.item_properties.D_FADEINLEN = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN" )
  entry.item_properties.D_FADEOUTLEN = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN" )
  entry.item_properties.D_FADEINDIR = reaper.GetMediaItemInfo_Value(item, "D_FADEINDIR" )
  entry.item_properties.D_FADEOUTDIR = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTDIR" )
  entry.item_properties.D_FADEINSHAPE = reaper.GetMediaItemInfo_Value(item, "D_FADEINSHAPE" )
  entry.item_properties.D_FADEOUTSHAPE = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTSHAPE" )
  entry.item_properties.B_LOOPSRC = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC" )
  entry.item_properties.B_UISEL = reaper.GetMediaItemInfo_Value(item, "B_UISEL" )

  entry.take_properties = {}
  entry.take_properties.D_PLAYRATE = reaper.GetMediaItemTakeInfo_Value( take, "D_PLAYRATE" )
  entry.take_properties.D_STARTOFFS = reaper.GetMediaItemTakeInfo_Value( take, "D_STARTOFFS" )

  reaper.SetMediaItemSelected( item, true )
  reaper.Main_OnCommand(40612, 0) -- Item: Set items length to source media lengths
  reaper.SetMediaItemSelected( item, false )

  local is_looping
  cur_len = reaper.GetMediaItemInfo_Value(entry.item, "D_LENGTH")
  if cur_len >= entry.item_properties.D_LENGTH  and not (entry.item_properties.B_LOOPSRC == 0 and entry.take_properties.D_STARTOFFS < 0) then
    is_looping = false
  else
    is_looping = true
  end

  for key, value in pairs( entry.item_properties ) do
    reaper.SetMediaItemInfo_Value( entry.item, key, value )
  end
  -- Restore Item Properties
  for key, value in pairs( entry.take_properties ) do
    reaper.SetMediaItemTakeInfo_Value( entry.take, key, value )
  end

  return is_looping
end

-- INIT

-----------------------------------------------------------
-- INIT --
-----------------------------------------------------------
function Init()

  -- See if there is items selected
  count_items = reaper.CountMediaItems(0)
  if count_items == 0 then return false end

  if not reaper.BR_SetItemEdges then
    reaper.MB("SWS extension is required by this script.\nPlease download it on http://www.sws-extension.org/", "Warning", 0)
    return
  end

  if popup then

    if not preset_file_init and not reset then
      GetValsFromExtState()
    end

    retval, retvals_csv = reaper.GetUserInputs(input_title, #vars_order, ConcatenateVarsVals(instructions, sep, vars_order) .. sep .. extrawidth .. sep .. separator, ConcatenateVarsVals(vars, sep, vars_order) )
    if retval then
      vars = ParseRetvalCSV( retvals_csv, sep, vars_order )
      if vars.project_bit_depth then vars.project_bit_depth = tonumber( vars.project_bit_depth ) end
      -- CUSTOM SANITIZATION HERE
    end
  end

  if not popup or ( retval and ValidateVals(vars, vars_order) ) then -- if user complete the fields

      reaper.PreventUIRefresh(1)

      reaper.Undo_BeginBlock()

      if not clear_console_init then reaper.ClearConsole() end

      if popup then SaveState() end

      reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items

      auto_fade = reaper.GetToggleCommandState( 40041 )

      project_bit_depth = vars.project_bit_depth -- legacy

      reaper.Main_OnCommand( 41119, 0 ) -- Options: Disable auto-crossfades

      for k, v in pairs( vars ) do
        vars[k] = toboolean( vars[k] )
      end

      Main() -- Execute your main function

      if auto_fade == 1 then
        reaper.Main_OnCommand( 41118, 0 ) -- Options: Enable auto-crossfades
      end

      if #msg > 0 then
        PrintMsg()
      end

      reaper.Undo_EndBlock(undo_text, -1)

      reaper.UpdateArrange()

      reaper.PreventUIRefresh(-1)

  end
end

if not preset_file_init then
  Init()
end

