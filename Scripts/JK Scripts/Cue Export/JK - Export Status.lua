-- @description Show whether this version's export of the cue exists and is complete
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local rows, info = dofile(script_path .. "jk_export.lua").export_status()
if not rows then return reaper.ShowMessageBox(info, "Export status", 0) end
local lines = { string.format("%s  (%.2f - %.2f s)", reaper.GetProjectName(0), info.start, info.finish), "" }
for _, r in ipairs(rows) do
    lines[#lines + 1] = string.format("%-16s %s%s", r.label, r.state:upper(), r.detail ~= "" and ("  " .. r.detail) or "")
end
reaper.ShowMessageBox(table.concat(lines, "\n"), "Export status", 0)
