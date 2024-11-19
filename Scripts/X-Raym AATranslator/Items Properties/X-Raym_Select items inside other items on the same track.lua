--[[
 * ReaScript Name: Select items inside other items on the same track
 * Instructions: Run.
 * Author: X-Raym
 * Author URI: https://www.extremraym.com
 * Repository: GitHub > X-Raym > Premium Scripts
 * Licence: GPL v3
 * REAPER: 5.0
 * Version: 1.0
--]]

--[[
 * Changelog:
 * v1.0 (2017-11-17)
  + Initial release
--]]

-- For Michael @AATranslator

-- USER CONFIG AREA -----------------------------------------------------------

console = false -- true/false: display debug messages in the console

------------------------------------------------------- END OF USER CONFIG AREA

-- UTILITIES -------------------------------------------------------------

local reaper = reaper

-- Display a message in the console for debugging
function Msg(value)
  if console then
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

--------------------------------------------------------- END OF UTILITIES

-- Main function
function Main()

  count_tracks = reaper.CountTracks(0)
  for i = 0, count_tracks - 1 do
    local track = reaper.GetTrack( 0, i )
    local count_tracks_items = reaper.CountTrackMediaItems( track )
    items = {}
    for j = 0, count_tracks_items - 1 do
      local item = {}
      item.item = reaper.GetTrackMediaItem(track, j)
      item.pos = reaper.GetMediaItemInfo_Value(item.item, "D_POSITION")
      item.len = reaper.GetMediaItemInfo_Value(item.item, "D_LENGTH")
      item.end_pos = item.pos + item.len
      item.id = reaper.GetMediaItemInfo_Value(item.item, "IP_ITEMNUMBER")
      table.insert(items, item)
    end

    -- Inside other items means that one of the items before the current analysed one ends after
    for j, current in ipairs( items ) do
      for z, before in ipairs( items ) do
        if before.id < current.id then
          if before.end_pos >= current.end_pos then reaper.SetMediaItemSelected(current.item,true) end
        else
          break -- no need to analyse items after. They will have their own analyses pass.
        end
      end
    end

  end

end

-- INIT

-- See if there is items selected
count_items = reaper.CountMediaItems(0)

if count_items > 0 then

  reaper.PreventUIRefresh(1)

  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.

  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items

  Main()

  reaper.Undo_EndBlock("Select items inside other items on the same track", -1) -- End of the undo block. Leave it at the bottom of your main function.

  reaper.UpdateArrange()

  reaper.PreventUIRefresh(-1)

end

