-- Jump to Next Video Cut (with Cache)
-- Uses ffmpeg scene detection to find video cuts and jump to the next one
-- Caches results in project ExtState for instant subsequent use
-- Author: Nate Weiner (https://nateweiner.com)

-- Bootstrap NW environment
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+)$")
local sharedPath = scriptPath:match("^(.+)[/\\][^/\\]+$") .. "/Shared/"
package.path = package.path .. ";" .. sharedPath .. "?.lua"

require("NWInit")({
    debug = false,
    feature = "CursorToCut",
    libs = { "ReaperUtils" },
    undo = "Move edit cursor to next video cut",
})
if not NW then return end

-- Add local paths for this package's modules
package.path = package.path .. ";" .. NW.scriptDir .. "/?.lua"
package.path = package.path .. ";" .. NW.scriptDir .. "/utils/?.lua"

NW.log("EntryNext", "=== Script startup ===")
NW.log("EntryNext", "scriptDir: " .. (NW.scriptDir or "nil"))

-- Load package modules
NW.log("EntryNext", "Loading VideoCutJumpUtils...")
local VideoCutJumpUtils = require("VideoCutJumpUtils")
NW.log("EntryNext", "VideoCutJumpUtils loaded successfully")

---Main entry point
local function main()
    VideoCutJumpUtils.queueJumpRequest("next", "[Jump Next]")
end

NW.run(main)
