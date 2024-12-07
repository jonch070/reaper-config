-- Start script: Lil Chordbox
--[[ -- ___Startup_Manager___ local chord_box_cmd_name = '_RSff0957acd908ac1a809c8b9aa70a0aa73d2ce162' ]]
--[[ -- ___Startup_Manager___ reaper.Main_OnCommand(reaper.NamedCommandLookup(chord_box_cmd_name), 0) ]]
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSff0957acd908ac1a809c8b9aa70a0aa73d2ce162"), 0) -- Script: Lil Chordbox.lua


reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS897e26f8708b2d436c4eda18bd495f149c65b7aa"), -1) -- Run HeDaScripts updates checker
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSc18de16721a3c34e4867889bd9bf02450163b2f8"), 0) -- Script: HeDa_Track Inspector 2 VIP.lua

-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS64c58143c69f93c74347ca8caed894d680cec4a5"), 0) -- Script: solger_ReaLauncher.lua
-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS46ef68cefefd381d79a3389dbbc0c31e821d6a68"), 0) -- Script: HeDa_Track Inspector 2 VIP_Master.lua
