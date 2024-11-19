--[[
   * ReaScript Name: Export Text Items to TXT
   * Author: Hector Corcin (HeDa)
   * Author URI: http://reaper.hector-corcin.com
   * Licence: Copyright © 2015-2016, Hector Corcin
]]






_Settings={}


_Settings["timestamps"] = false
-- true or false to include timestamps

_Settings["format"] = 5
-- time formatting mode overrides: -1=proj default.
-- 0=time
-- 1=measures.beats + time
-- 2=measures.beats
-- 3=seconds
-- 4=samples
-- 5=h:m:s:f





---------------------------------------------------------------------------------------
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
dofile(script_path .. "HeDa_Export Text Items to TXT " .. mode .. v7 .. ".dat")