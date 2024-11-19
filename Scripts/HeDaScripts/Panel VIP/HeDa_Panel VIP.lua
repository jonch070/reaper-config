--[[
   * ReaScript Name: HeDa Panel
   * Author: Hector Corcin (HeDa)
   * Author URI: https://reaper.hector-corcin.com
   * Licence: Copyright © 2024, Hector Corcin
]]

-- OPTIONS -------------------------------------------------------------------
-- panelconfig = "Unsaved"




-- Don't need to modify below here:-----------------------------------------------------------------
sectionname = "HeDaPanel"
OS = reaper.GetOS()
OSarch = "x64"
if OS == "Win32" or OS == "OSX32" then OSarch = "x32" end
resourcepath = reaper.GetResourcePath()
scripts_path = resourcepath .. "/Scripts/"
hedascripts_path = scripts_path .. "HeDaScripts/"
REAPERv = tonumber(reaper.GetAppVersion():match("^(%d+)%..*"))
v7 = ""
if REAPERv then if REAPERv >= 7 then v7 = "_7" end end
local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
local namescript = script_path:gsub("\\", "/"):gsub("/$", "")
local name2 = namescript:match(".*/(.*) settings$")
local filename = "HP" .. OSarch .. v7 .. ".dat"
if name2 then
   local fileload = hedascripts_path .. name2 .. " VIP/" .. filename
   if reaper.file_exists(fileload) then
      name_script2 = name2 .. " VIP"
      script_path2 = hedascripts_path .. name_script2 .. "/"
      script_path = script_path2
      dofile(fileload)
   else
      script_path2 = hedascripts_path .. name2 .. "/"
      name_script2 = name2
      script_path = script_path2
      dofile(script_path2 .. name2 .. "/" .. filename)
   end
else
   dofile(script_path .. filename)
end
