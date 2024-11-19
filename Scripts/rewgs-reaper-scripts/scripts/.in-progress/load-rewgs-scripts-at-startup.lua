-- THIS DOES NOT WORK YET
-- maybe do stuff from this video? https://www.youtube.com/watch?v=N5hDEuexfUk&t=103s

local rewgs_scripts = reaper.GetResourcesPath() .. "/Scripts/rewgs/"
-- dofile(reaper.GetResourcePath() .. "/Scripts/rewgs/*.lu")
dofile(rewgs_scripts .. "*/*.lua")
