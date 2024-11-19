--[[
  NoIndex: true
  About: Use this script to split items on mouse cursor position.
]]
reaper.Undo_BeginBlock()

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DOSTORECURPOS"),0) --Xenakios/SWS: Store edit cursor position

OPERATION = "split"
local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
dofile(script_path .. "lkc_hover_edit-fade_split.lua")

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DORECALLCURPOS"),0) --Xenakios/SWS: Recall edit cursor position

reaper.Undo_EndBlock("LKC - HOVER EDIT - Split", -1)

