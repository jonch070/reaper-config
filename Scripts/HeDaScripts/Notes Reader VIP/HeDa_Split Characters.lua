--[[
   * ReaScript Name: Split Characters
   * Author: Hector Corcin (HeDa)
   * Author URI: http://reaper.hector-corcin.com
   * Licence: Copyright © 2015-2017, Hector Corcin
]]

includespaces=true

-----------------------------------------------------------------
local OS = reaper.GetOS()
local mode="x64"
if OS == "Win32" or OS == "OSX32" then mode="x32" end
local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
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
dofile(script_path .. "HSC" .. mode .. v7 ..".dat")