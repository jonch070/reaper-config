--[[
   * ReaScript Name: Projects
   * Author: Hector Corcin (HeDa)
   * Author URI: https://reaper.hector-corcin.com
   * Licence: Copyright © 2022-2023, Hector Corcin
]]



-- OPTIONS -------------------------------------------------------------------















-- Don't need to modify below here:-----------------------------------------------------------------
sectionname="Projects"
local OS = reaper.GetOS()
local mode="x64"
if OS == "Win32" or OS == "OSX32" then mode="x32" end
local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
script_path2 = script_path:match("(.*) settings")
if script_path2 then 
	custom_instance=instance
	script_path=script_path2 .. "/"
end
resourcepath=reaper.GetResourcePath()
scripts_path=resourcepath.."/Scripts/"
hedascripts_path=scripts_path.."HeDaScripts/"
REAPERv = tonumber(reaper.GetAppVersion():match("^(%d+)%..*"))
local v7=""
if REAPERv then 
   if REAPERv>=7 then 
      v7="_7"
   end
end
dofile(script_path .. "HP" .. mode .. v7 .. ".dat")