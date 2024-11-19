--[[
  NoIndex: true
  About: Cuts right part of item where mouse (or edit cursor, if mouse not hovering) are positioned and will shorten length of fadeout, like Pro Tools.
]]
reaper.Undo_BeginBlock()

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DOSTORECURPOS"),0) --Xenakios/SWS: Store edit cursor position

OPERATION = "right_trim"
local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
dofile(script_path .. "lkc_hover_edit-trim.lua")

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DORECALLCURPOS"),0) --Xenakios/SWS: Recall edit cursor position

reaper.Undo_EndBlock("LKC - HOVER EDIT - Trim from right", -1)
