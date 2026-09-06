--[[
@description jk_Count selected items
@version 0.1
@author Jonathan Kawchuk
@about
  Shows how many items are currently selected.
]]--

local count = reaper.CountSelectedMediaItems(0)
reaper.ShowConsoleMsg(tostring(count) .. " items selected\n")
