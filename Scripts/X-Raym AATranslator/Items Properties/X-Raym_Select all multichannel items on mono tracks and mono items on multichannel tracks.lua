--[[
 * ReaScript Name: Select all multichannel items on mono tracks and mono items on multichannel tracks
 * Instructions: Run.
 * Screenshot: https://i.imgur.com/wtykbVt.gifv
 * Author: X-Raym
 * Author URI: https://www.extremraym.com
 * Repository: X-Raym Premium Scripts
 * Licence: GPL v3
 * REAPER: 5.0
 * Version: 1.0.2
--]]

--[[
 * Changelog:
 * v1.0.2 (2019-02-24)
  # Bug fixes
 * v1.0.1 (2019-02-19)
  # Bug fixes
 * v1.0 (2019-02-18)
  + Initial release
--]]

-- USER CONFIG AREA -----------------------------------------------------------

console = false -- true/false: display debug messages in the console

mono_suffix = "mono"
-- stereo_suffix = "stereo"

------------------------------------------------------- END OF USER CONFIG AREA

-- UTILITIES -------------------------------------------------------------

local reaper = reaper

-- Display a message in the console for debugging
function Msg(value)
  if console then
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

function IsMonoItem( item )

  local is_mono_item = false

  local take = reaper.GetActiveTake( item )

  -- Empty item
  if not take or reaper.TakeIsMIDI(take ) then
    is_mono_item = true
    Msg('no take')
  else
    Msg('\n' .. reaper.GetTakeName(take))
  end

  -- Downmix
  if not is_mono_item and reaper.GetMediaItemTakeInfo_Value( take, "I_CHANMODE" ) >= 2 and reaper.GetMediaItemTakeInfo_Value( take, "I_CHANMODE" ) < 67 then --  (0=normal, 1=revstereo, 2=downmix, 3=l, 4=r)
    is_mono_item = true
    Msg('Downmix')
  end

  -- Source is mono
  if not is_mono_item and reaper.GetMediaItemTakeInfo_Value( take, "I_CHANMODE" ) == 0 then
    local source =  reaper.GetMediaItemTake_Source( take )
    if source then
      local source_type = reaper.GetMediaSourceType(source,"")
      if source_type == "SECTION" then
        source = reaper.GetMediaSourceParent(source)
      end
      local chan_num = reaper.GetMediaSourceNumChannels( source )
      if chan_num == 1 then
        is_mono_item = true
        Msg('Mono Source' .. chan_num)
      end
    end
  end

  -- Has take pan
  if is_mono_item and take and reaper.GetMediaItemTakeInfo_Value( take, "D_PAN" ) ~= 0 then
    Msg('Take Pan')
    is_mono_item = false
  end

  -- Has take envelope
  if take and reaper.GetTakeEnvelopeByName( take, 'Pan' ) then
    is_mono_item = true
    local env = reaper.GetTakeEnvelopeByName( take, 'Pan' )
    if reaper.BR_EnvAlloc then
      local br_env =  reaper.BR_EnvAlloc( env, false )
      active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
      if active then
        is_mono_item = false
        Msg('Pan envelope active')
      end
      reaper.BR_EnvFree( br_env, 0 )
    else
      Msg('Pan envelope')
      is_mono_item = false
    end
  end

  return is_mono_item

end

--------------------------------------------------------- END OF UTILITIES

-- Main function
function Main()

  for i = 0, count_items - 1 do

    local item = reaper.GetMediaItem( 0, i )
    local is_mono_item = IsMonoItem( item )
    Msg(is_mono_item)
    local track = reaper.GetMediaItemTrack( item )
    local retval, track_name = reaper.GetTrackName(track, '')
    track_name = track_name:lower()
    if (track_name:find('mono') and not is_mono_item) or (not track_name:find('mono') and is_mono_item) then
      reaper.SetMediaItemSelected( item, true )
    end
  end

end

-- INIT

-- See if there is items selected
count_items = reaper.CountMediaItems(0)

if count_items > 0 then

  reaper.PreventUIRefresh(1)

  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.

  reaper.ClearConsole()

  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items

  Main()

  reaper.Undo_EndBlock("Select all multichannel items on mono tracks and mono items on multichannel tracks", -1) -- End of the undo block. Leave it at the bottom of your main function.

  reaper.UpdateArrange()

  reaper.PreventUIRefresh(-1)

end
