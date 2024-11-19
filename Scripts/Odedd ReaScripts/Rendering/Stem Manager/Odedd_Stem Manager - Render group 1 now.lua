-- This file was created by Stem Manager on Tue Nov 12 17:39:57 2024

local r = reaper
local context = 'Odedd_Stem_Manager'
local script_name = 'Odedd_Stem Manager.lua'
local cmd = 'render_rg 1'

function getScriptId(script_name)
  local file = io.open(r.GetResourcePath().."/".."reaper-kb.ini")
  if not file then return "" end
  local content = file:read("*a")
  file:close()
  local santizedSn = script_name:gsub("([^%w])", "%%%1")
  if content:find(santizedSn) then
    return content:match('[^\r\n].+(RS.+) "Custom: '..santizedSn)
  end
end

local cmdId = getScriptId(script_name)

if cmdId then
  if r.GetExtState(context, 'defer') ~= '1' then
    local intId = r.NamedCommandLookup('_'..cmdId)
    if intId ~= 0 then r.Main_OnCommand(intId,0) end
  end
  r.SetExtState(context, 'EXTERNAL COMMAND',cmd, false)
else
  r.MB(script_name..' not installed', script_name,0)
end