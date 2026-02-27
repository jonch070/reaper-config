-- @description File system utility functions for REAPER scripts
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Functions for working with files and directories in REAPER scripts.

---@class FileUtils
local FileUtils = {}

-- ============================================================================
-- DIRECTORY OPERATIONS
-- ============================================================================

---Ensures that the parent directory for a file path exists
---@param filePath string Full path to a file (e.g., "/dir/foo/bar/file.rpp")
---@return boolean success True if directory exists or was created
function FileUtils.ensureParentDirectory(filePath)
    -- Extract directory from file path
    local dirPath = filePath:match("^(.+)[/\\][^/\\]+$")
    if not dirPath then
        return false  -- Invalid path
    end

    -- RecursiveCreateDirectory returns >0 on success, 0 on failure
    local result = reaper.RecursiveCreateDirectory(dirPath, 0)
    return result > 0
end

return FileUtils
