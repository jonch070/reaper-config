-- Start script: Lil Chordbox
--[[ -- ___Startup_Manager___ local chord_box_cmd_name = '_RSff0957acd908ac1a809c8b9aa70a0aa73d2ce162' ]]
--[[ -- ___Startup_Manager___ reaper.Main_OnCommand(reaper.NamedCommandLookup(chord_box_cmd_name), 0) ]]
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSff0957acd908ac1a809c8b9aa70a0aa73d2ce162"), 0) -- Script: Lil Chordbox.lua


reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS897e26f8708b2d436c4eda18bd495f149c65b7aa"), -1) -- Run HeDaScripts updates checker
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSc18de16721a3c34e4867889bd9bf02450163b2f8"), 0) -- Script: HeDa_Track Inspector 2 VIP.lua

-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS64c58143c69f93c74347ca8caed894d680cec4a5"), 0) -- Script: solger_ReaLauncher.lua
-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS46ef68cefefd381d79a3389dbbc0c31e821d6a68"), 0) -- Script: HeDa_Track Inspector 2 VIP_Master.lua
-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSa75502a6bd6e746a5776d4c51d8a14f851f0c55f"), 0) -- Script: LKC - RenderBlocks - Content Navigator.lua
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS33c36901779e76d0ef0542466abe875e36c6b57d"), 0) -- Script: HeDa_Region Tracks VIP.lua
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSdbf64708ea8abea46b82a08cabc050148d65176c"), 0) -- Script: BirdBird_Global Sampler.lua
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSffa88234af6d0278615a8b8b967c0dbb42a91461"), 0) -- Script: NateWeiner - Set project frame rate from video.lua

--HOVER EDITING
hover_editing = tonumber(reaper.GetExtState("LKC_TOOLS","hover_editing_state"))
if hover_editing == nil then hover_editing = 1 end
command = reaper.NamedCommandLookup("_RS8277b238cd7341ba4a3c9ff870f30876ce76160b")
reaper.SetToggleCommandState(0, command, hover_editing)
reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS02de4a63cf12c72510b6da7254c3f3df05dba45c"), 0) -- Script: Gridbox.lua
