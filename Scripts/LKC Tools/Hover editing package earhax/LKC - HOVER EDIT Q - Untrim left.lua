--[[
  NoIndex: true

]]
reaper.Undo_BeginBlock()

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DOSTORECURPOS"),0) --Xenakios/SWS: Store edit cursor position

OPERATION = "left_untrim"
local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
dofile(script_path .. "lkc_hover_edit-untrim.lua")

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DORECALLCURPOS"),0) --Xenakios/SWS: Recall edit cursor position

reaper.Undo_EndBlock("LKC - HOVER EDIT - Untrim from left", -1)
