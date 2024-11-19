dofile(reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua")

local rewgs_reaper_scripts_root = reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts"
-- local rewgs_scripts = rewgs_reaper_scripts_root .. "/scripts"
local rewgs_modules = rewgs_reaper_scripts_root .. "/modules"

-- reaper.ShowConsoleMsg(rewgs_reaper_scripts_root .. "\n")
-- reaper.ShowConsoleMsg(rewgs_scripts .. "\n")
-- reaper.ShowConsoleMsg(rewgs_modules .. "\n")


local function get_file_name(file)
    return file:match("[^/]*.lua$")
end

local info = debug.getinfo(1, 'S')
local this_file_name = get_file_name(info.source)
-- TODO: see if the line below can replace the above line (and its associated function)
-- local this_file_name = info.source:match("[^/]*.lua$")
local this_file_path = rewgs_modules .. "/" .. this_file_name

-- reaper.ShowConsoleMsg(info.source)
-- reaper.ShowConsoleMsg(this_file_path)

-- Returns all subdirectories and files within a given path.
-- Might take some time with many folders/files.
-- Optionally, you can filter for specific keywords(follows Lua's pattern-matching)
-- Returns -1 in case of an error.
-- Lua: integer found_dirs, array dirs_array, integer found_files, array files_array = ultraschall.GetAllRecursiveFilesAndSubdirectories(string path, optional string dir_filter, optional string dir_case_sensitive, optional string file_filter, optional string file_case_sensitive)
local num_found_dirs, dirs_array, num_found_files, files_array = ultraschall.GetAllRecursiveFilesAndSubdirectories(rewgs_modules)

-- Imports all files found in the modules directory.
-- Never imports the name of the file that's calling it -- this allows modules to use the same
-- `dofile()` line as scripts: dofile(reaper.GetResourcePath() .. "/Scripts/rewgs-reaper-scripts/modules/init.lua")
-- TODO: filter only .lua files
for _, file in ipairs(files_array) do
    if file ~= this_file_path then
        -- reaper.ShowConsoleMsg(file .. "\n")
        dofile(file)
    end
end

-- test_import()
