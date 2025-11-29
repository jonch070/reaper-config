local renderingblocksize = 8192 -- set block size to use 

local prev_renderbsnew = reaper.SNM_GetIntConfigVar("renderbsnew", 0) -- save current block size
reaper.SNM_SetIntConfigVar("renderbsnew", renderingblocksize) -- set block render size for faster render
local retval, RENDER_STATS = reaper.GetSetProjectInfo_String(0, "RENDER_STATS", "43349", false) -- dry Run using latest settings
reaper.SNM_SetIntConfigVar("renderbsnew", prev_renderbsnew) -- restore block render size
