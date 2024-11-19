--[[
 * ReaScript Name: Select all items with active take pan offset and unselect the others
 * Instructions: Run.
 * Screenshot: https://i.imgur.com/2ogqvNc.gifv
 * Author: X-Raym
 * Author URI: https://www.extremraym.com
 * Repository: X-Raym Premium Scripts
 * Licence: GPL v3
 * REAPER: 5.0
 * Version: 1.0
--]]

--[[
 * Changelog:
 * v1.0 (2018-01-05)
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

  for i = 0, count_items - 1 do

    local item = reaper.GetMediaItem( 0, i )
    local take = reaper.GetActiveTake( item )
    if take then
      local pan = reaper.GetMediaItemTakeInfo_Value( take, "D_PAN" )
      if pan ~= 0 then
        reaper.SetMediaItemSelected( item, true )
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

  reaper.Undo_EndBlock("Select all items with active take pitch offset and unselect the others", -1) -- End of the undo block. Leave it at the bottom of your main function.

  reaper.UpdateArrange()

  reaper.PreventUIRefresh(-1)

end
