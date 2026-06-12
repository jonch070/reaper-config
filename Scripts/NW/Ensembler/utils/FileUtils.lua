-- FileUtils.lua - File system utilities

FileUtils = {}

local debug_log = State.debug_log

---Ensure directory exists (creates all parent directories as needed)
---@param path string Directory path to create
function FileUtils.ensureDirectory(path)
    local separator = package.config:sub(1,1)
    local currentPath = ""
    for folder in path:gmatch("[^" .. separator .. "]+") do
        currentPath = currentPath .. folder .. separator
        reaper.RecursiveCreateDirectory(currentPath, 1)
    end
end

---Save string content to file
---@param filePath string Full path to file
---@param content string Content to save
---@return boolean success
function FileUtils.saveFile(filePath, content)
    local file = io.open(filePath, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

---Read file content as string
---@param filePath string Full path to file
---@return string|nil content File content or nil if failed
function FileUtils.readFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    return content
end

---Check if file exists
---@param filePath string Full path to file
---@return boolean exists
function FileUtils.fileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

---Delete file
---@param filePath string Full path to file
function FileUtils.deleteFile(filePath)
    os.remove(filePath)
end

---Enumerate files in directory with given extension
---@param dirPath string Directory path
---@param extension string|nil File extension (without dot) or nil for all files
---@return string[] files Array of filenames without extension
function FileUtils.enumerateFiles(dirPath, extension)
    local files = {}
    local i = 0
    repeat
        local file = reaper.EnumerateFiles(dirPath, i)
        if file and (not extension or file:match("%." .. extension .. "$")) then
            local name = extension and file:gsub("%." .. extension .. "$", "") or file
            table.insert(files, name)
        end
        i = i + 1
    until not file
    
    return files
end

return FileUtils