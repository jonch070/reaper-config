--[[
   * ReaScript Name: HeDa MIDI Dynamics
   * Author: Hector Corcin (HeDa)
   * Author URI: https://reaper.hector-corcin.com
   * Licence: Copyright © 2017, Hector Corcin
]]

-- OPTIONS


-- Don't need to modify below here:-----------------------------------------------------------------
sectionname="HeDaMIDIDynamics"
name_script="MIDI Dynamics"
name_scriptVIP="MIDI Dynamics VIP"
name_script_settings="MIDI Dynamics"

local OS = reaper.GetOS()
local mode="x64"
if OS == "Win32" or OS == "OSX32" then mode="x32" end
-- local info = debug.getinfo(1,'S');
-- script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
-- script_path2 = script_path:match("(.*) settings")
-- if script_path2 then 
-- 	custom_instance=instance
-- 	script_path=script_path2 .. "/"
-- end
resourcepath=reaper.GetResourcePath()
scripts_path=resourcepath.."/Scripts/"
hedascripts_path=scripts_path.."HeDaScripts/"
script_path = hedascripts_path .. name_script .. "/"

REAPERv = tonumber(reaper.GetAppVersion():match("^(%d+)%..*"))
local v7=""
if REAPERv then 
   if REAPERv>=7 then 
      v7="_7"
   end
end
dofile(script_path .. "HMD" .. mode .. v7 .. ".dat")