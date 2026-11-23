-- @description Make short-named copies of multitrack stems whose filenames are too long for Pro Tools / the interleaver (originals are kept)
-- @author Jonathan Kawchuk (generated with Claude)
-- Scans <root>/<cue>/exports/<version>/<version> MULTITRACK/DRY and /WET for every cue. A stem longer than
-- 165 characters gets a short-named COPY beside it; the original stays, and each folder gets a
-- _long_names.tsv (short name, original name) so the mix builder uses the short copy and skips the original.
-- Safe to run again: existing copies are never overwritten.
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local names = dofile(script_path .. "jk_stemnames.lua")
local root = reaper.GetExtState("JK_MixNotes", "root")
if root == "" then root = "/Users/jonathankawchuk/Documents/Projects/Film/Hunt for the Grey Ghost/HGG Reaper Projects" end
local ok, picked = reaper.JS_Dialog_BrowseForFolder("Folder holding the cue folders (1M01 - ..., 1M02 - ...)", root)
if ok ~= 1 or not picked or picked == "" then return end
root = picked

local function subdirs(dir)
    local out, i = {}, 0
    while true do
        local d = reaper.EnumerateSubdirectories(dir, i)
        if not d then break end
        out[#out + 1] = d
        i = i + 1
    end
    return out
end

local made, folders, problems, lines = 0, 0, {}, {}
for _, cue in ipairs(subdirs(root)) do
    for _, ver in ipairs(subdirs(root .. "/" .. cue .. "/exports")) do
        for _, kind in ipairs({ "DRY", "WET" }) do
            local dir = root .. "/" .. cue .. "/exports/" .. ver .. "/" .. ver .. " MULTITRACK/" .. kind
            if reaper.EnumerateFiles(dir, 0) then
                local res = names.shorten_folder(dir, "copy")
                if res.made > 0 then
                    folders = folders + 1
                    made = made + res.made
                    lines[#lines + 1] = string.format("%s %s: %d copies", ver, kind, res.made)
                end
                for _, p in ipairs(res.problems) do problems[#problems + 1] = ver .. " " .. kind .. ": " .. p end
            end
        end
    end
end
local text = string.format("%d short-named copies made in %d folders. Originals kept.\n\n%s", made, folders, table.concat(lines, "\n"))
if #problems > 0 then text = text .. "\n\nProblems:\n" .. table.concat(problems, "\n") end
reaper.ShowMessageBox(text, "Shorten long stem names", 0)
