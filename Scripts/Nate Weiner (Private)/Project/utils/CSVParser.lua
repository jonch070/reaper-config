-- @description CSV parser for SpotNotes spotting notes
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Parses SpotNotes CSV export files to extract cue information.
--   Returns a map of cue IDs to their spotting note data.

---@class CSVParser
local CSVParser = {}

---@class SpotNote
---@field cueId string The cue identifier (e.g., "1m01")
---@field title string Cue title
---@field type string? Cue type (optional)
---@field inTimecode string MX IN timecode (HH:MM:SS:FF)
---@field inDescription string? Description of IN point
---@field outTimecode string MX OUT timecode (HH:MM:SS:FF)
---@field outDescription string? Description of OUT point
---@field duration string? Duration string
---@field notes string Spotting notes text

-- ============================================================================
-- CSV PARSING UTILITIES
-- ============================================================================

---Parses a single CSV line handling quoted fields with commas and newlines
---@param line string The CSV line to parse
---@return string[] fields Array of field values
local function parseCSVLine(line)
    local fields = {}
    local inQuotes = false
    local currentField = ""

    local i = 1
    while i <= #line do
        local char = line:sub(i, i)

        if char == '"' then
            if inQuotes and line:sub(i + 1, i + 1) == '"' then
                -- Escaped quote inside quoted field
                currentField = currentField .. '"'
                i = i + 1
            else
                -- Toggle quote state
                inQuotes = not inQuotes
            end
        elseif char == ',' and not inQuotes then
            -- End of field
            table.insert(fields, currentField)
            currentField = ""
        else
            currentField = currentField .. char
        end

        i = i + 1
    end

    -- Add the last field
    table.insert(fields, currentField)

    return fields
end

---Normalizes a timecode string to use colons
---@param tc string? Timecode with dots or colons
---@return string normalized Timecode with colons, or empty string if nil
local function normalizeTimecode(tc)
    if not tc or tc == "" then
        return ""
    end
    return tc:gsub("%.", ":")
end

---Trims whitespace from a string
---@param s string? String to trim
---@return string trimmed Trimmed string, or empty string if nil
local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

-- ============================================================================
-- CSV FILE PARSING
-- ============================================================================

---Reads and parses a CSV file, handling multi-line quoted fields
---@param csvPath string Path to CSV file
---@return string[][] rows Array of row arrays (each row is array of field values)
---@return string[] headers Array of header names (second return value)
local function readCSVFile(csvPath)
    local file = io.open(csvPath, "r")
    if not file then
        return {}, {}
    end

    local content = file:read("*all")
    file:close()

    local rows = {}
    local headers = {}
    local currentLine = ""
    local inQuotes = false
    local isFirstRow = true

    -- Process character by character to handle multi-line quoted fields
    local i = 1
    while i <= #content do
        local char = content:sub(i, i)

        if char == '"' then
            currentLine = currentLine .. char
            -- Check for escaped quote
            if content:sub(i + 1, i + 1) == '"' then
                currentLine = currentLine .. '"'
                i = i + 1
            else
                inQuotes = not inQuotes
            end
        elseif char == '\n' and not inQuotes then
            -- End of row (ignore \r)
            currentLine = currentLine:gsub("\r$", "")
            if currentLine ~= "" then
                local fields = parseCSVLine(currentLine)
                if isFirstRow then
                    headers = fields
                    isFirstRow = false
                else
                    table.insert(rows, fields)
                end
            end
            currentLine = ""
        elseif char == '\r' then
            -- Skip carriage returns, handle in \n
        else
            currentLine = currentLine .. char
        end

        i = i + 1
    end

    -- Handle last line if no trailing newline
    if currentLine ~= "" then
        currentLine = currentLine:gsub("\r$", "")
        local fields = parseCSVLine(currentLine)
        if isFirstRow then
            headers = fields
        else
            table.insert(rows, fields)
        end
    end

    return rows, headers
end

---Finds the index of a header by name (case-insensitive)
---@param headers string[] Array of header names
---@param name string Header name to find
---@return number? index 1-based index, or nil if not found
local function findHeaderIndex(headers, name)
    local lowerName = name:lower()
    for i, header in ipairs(headers) do
        if trim(header):lower() == lowerName then
            return i
        end
    end
    return nil
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Parses a SpotNotes CSV file
---@param csvPath string Path to the CSV file
---@return table<string, SpotNote> spotNotes Map of cueId -> SpotNote
---@return string? error Error message if parsing failed
function CSVParser.parse(csvPath)
    local rows, headers = readCSVFile(csvPath)

    if #headers == 0 then
        return {}, "Could not read CSV file or file is empty: " .. csvPath
    end

    -- Find column indices
    local cueIdIdx = findHeaderIndex(headers, "Cue ID")
    local titleIdx = findHeaderIndex(headers, "Title")
    local typeIdx = findHeaderIndex(headers, "Type")
    local inIdx = findHeaderIndex(headers, "IN")
    local inDescIdx = findHeaderIndex(headers, "IN Description")
    local outIdx = findHeaderIndex(headers, "OUT")
    local outDescIdx = findHeaderIndex(headers, "OUT Description")
    local durationIdx = findHeaderIndex(headers, "Duration")
    local notesIdx = findHeaderIndex(headers, "Notes")

    if not cueIdIdx then
        return {}, "CSV missing required 'Cue ID' column"
    end
    if not inIdx then
        return {}, "CSV missing required 'IN' column"
    end
    if not outIdx then
        return {}, "CSV missing required 'OUT' column"
    end

    local spotNotes = {}

    for _, row in ipairs(rows) do
        local cueId = trim(row[cueIdIdx])

        -- Skip rows without a cue ID
        if cueId and cueId ~= "" then
            ---@type SpotNote
            local note = {
                cueId = cueId,
                title = titleIdx and trim(row[titleIdx]) or "",
                type = typeIdx and trim(row[typeIdx]) or nil,
                inTimecode = normalizeTimecode(trim(row[inIdx])),
                inDescription = inDescIdx and trim(row[inDescIdx]) or nil,
                outTimecode = normalizeTimecode(trim(row[outIdx])),
                outDescription = outDescIdx and trim(row[outDescIdx]) or nil,
                duration = durationIdx and trim(row[durationIdx]) or nil,
                notes = notesIdx and trim(row[notesIdx]) or ""
            }

            spotNotes[cueId] = note
        end
    end

    return spotNotes, nil
end

---Gets a SpotNote by cue ID, with flexible matching
---Tries exact match first, then tries adding/removing leading zeros
---@param spotNotes table<string, SpotNote> Map of cueId -> SpotNote
---@param cueId string The cue ID to look up
---@return SpotNote? spotNote The matching SpotNote, or nil if not found
function CSVParser.findByCueId(spotNotes, cueId)
    -- Exact match
    if spotNotes[cueId] then
        return spotNotes[cueId]
    end

    -- Try normalizing the cue ID format
    -- Common formats: "1m01", "01m01", "m01", "1M01"
    local normalized = cueId:lower()

    -- Try matching with different zero padding
    for id, note in pairs(spotNotes) do
        local normalizedId = id:lower()
        if normalizedId == normalized then
            return note
        end

        -- Extract number parts and compare
        local inputNum, inputSuffix = normalized:match("(%d+)m(%d+)")
        local noteNum, noteSuffix = normalizedId:match("(%d+)m(%d+)")

        if inputNum and noteNum then
            -- Compare numeric values
            if tonumber(inputNum) == tonumber(noteNum) and
               tonumber(inputSuffix) == tonumber(noteSuffix) then
                return note
            end
        end
    end

    return nil
end

return CSVParser
