-- DataSerialization.lua - Shared data serialization utilities
DataSerialization = {}

---Save data to file with serialization  
---@param data table Data to serialize and save
---@param filePath string Full path to save file
---@return boolean success
function DataSerialization.saveToFile(data, filePath)
    local serializedData = DataSerialization.tableToString(data)
    return FileUtils.saveFile(filePath, serializedData)
end

---Load data from file with deserialization
---@param filePath string Full path to load file
---@return table|nil data Deserialized data or nil if failed
function DataSerialization.loadFromFile(filePath)
    if not FileUtils.fileExists(filePath) then
        return nil
    end
    
    local success, data = pcall(dofile, filePath)
    if not success then
        debug_log("Failed to load data file (syntax error): " .. filePath .. " - " .. tostring(data))
        return nil
    end
    
    if not data or type(data) ~= "table" then
        debug_log("Invalid data in file: " .. filePath)
        return nil
    end
    
    return data
end

---Convert table to string for serialization
---@param data table Data to serialize
---@return string serializedData
function DataSerialization.tableToString(data)
    local function escapeString(str)
        -- Escape quotes and backslashes for safe string serialization
        return str:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
    end
    
    local function serializeValue(value, indent)
        indent = indent or 0
        local spacing = string.rep("  ", indent)
        
        if type(value) == "nil" then
            return "nil"
        elseif type(value) == "boolean" then
            return tostring(value)
        elseif type(value) == "number" then
            return tostring(value)
        elseif type(value) == "string" then
            return '"' .. escapeString(value) .. '"'
        elseif type(value) == "table" then
            local result = "{\n"
            for k, v in pairs(value) do
                local key_str
                if type(k) == "string" then
                    key_str = '["' .. escapeString(k) .. '"]'
                else
                    key_str = "[" .. tostring(k) .. "]"
                end
                result = result .. spacing .. "  " .. key_str .. " = " .. serializeValue(v, indent + 1) .. ",\n"
            end
            result = result .. spacing .. "}"
            return result
        else
            -- Skip unsupported types like functions
            return "nil"
        end
    end
    
    return "return " .. serializeValue(data)
end

---Convert string back to table for deserialization
---@param stringData string Serialized data string
---@return table|nil data Deserialized table or nil if failed
function DataSerialization.stringToTable(stringData)
    if not stringData or stringData == "" then
        return nil
    end
    
    -- Use pcall for safe execution with error handling
    local success, result = pcall(load, stringData)
    
    if not success then
        debug_log("Error deserializing data: " .. tostring(result))
        return nil
    end
    
    -- Execute the loaded function to get the table
    local executeSuccess, data = pcall(result)
    
    if not executeSuccess then
        debug_log("Error executing deserialized data: " .. tostring(data))
        return nil
    end
    
    return data
end

return DataSerialization