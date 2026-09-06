-- @description Utilities Module for Reanspiration
-- @version 1.2 (Added Weighted Random)
-- @author Hosi
-- @about
--   Chứa các hàm tiện ích chung (xử lý chuỗi, bảng, file path, REAPER API helpers)
--   được tách ra từ Hosi_Reanspiration_Pro.lua để tối ưu hóa cấu trúc.

local Utils = {}
local reaper = reaper

-----------------------------------------------------------
-- 1. File & Path Helpers
-----------------------------------------------------------

-- Lấy đường dẫn thư mục chứa script hiện tại
function Utils.getScriptPath()
    local script_path_info = debug.getinfo(1, "S")
    if not script_path_info or not script_path_info.source then
        return nil
    end
    -- Loại bỏ ký tự '@' ở đầu đường dẫn
    local clean_source_path = script_path_info.source:gsub("^@", "")
    -- Lấy đường dẫn thư mục
    local script_path = clean_source_path:match(".*[/\\]")
    return script_path
end

-----------------------------------------------------------
-- 2. Table Helpers
-----------------------------------------------------------

-- Chọn một phần tử ngẫu nhiên từ danh sách
function Utils.selectRandom(list)
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

-- Chọn ngẫu nhiên có trọng số (Dùng cho Markov Chain)
-- weights: bảng {giá_trị = trọng_số}, ví dụ: {A=10, B=50, C=40}
function Utils.weightedRandom(weights)
    local sum = 0
    for _, w in pairs(weights) do
        sum = sum + w
    end
    local rand = math.random() * sum
    local current = 0
    for key, w in pairs(weights) do
        current = current + w
        if rand <= current then
            return key
        end
    end
    return nil
end

-- Kiểm tra xem bảng có chứa phần tử hay không
function Utils.tableContains(tbl, element)
    if not tbl then return false end
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

-- Tìm chỉ số (index) của một giá trị trong bảng
function Utils.indexOf(t, value)
    if not t then return nil end
    for i, v in ipairs(t) do
        if v == value then return i end
    end
    return nil
end

-- Xoay vòng bảng (Dùng cho Euclidean Rotation)
function Utils.rotateTable(tbl, amount)
    if not tbl or #tbl == 0 then return tbl end
    local len = #tbl
    local rotation = amount % len
    if rotation == 0 then return tbl end

    local new_tbl = {}
    if rotation > 0 then
        -- Rotate Right (Clockwise)
        local pivot = len - rotation
        for i = pivot + 1, len do table.insert(new_tbl, tbl[i]) end
        for i = 1, pivot do table.insert(new_tbl, tbl[i]) end
    else
        -- Rotate Left
        local pivot = math.abs(rotation)
        for i = pivot + 1, len do table.insert(new_tbl, tbl[i]) end
        for i = 1, pivot do table.insert(new_tbl, tbl[i]) end
    end
    return new_tbl
end

-----------------------------------------------------------
-- 3. REAPER Specific Helpers
-----------------------------------------------------------

-- Tìm Track theo tên
function Utils.findTrackByName(name)
    if not name or name == "" then return nil end
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if trackName == name then
            return track
        end
    end
    return nil
end

-----------------------------------------------------------
-- 4. Serialization Helpers (Lưu trữ dữ liệu)
-----------------------------------------------------------

-- Serialize table thành string (Dùng cho Custom Menu)
function Utils.serializeTable(val)
    if type(val) == "string" then
        return string.format("%q", val)
    elseif type(val) == "number" or type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "table" then
        local parts = {}
        local is_array = true
        local n = 0
        for k, _ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= n then
                is_array = false
            end
        end
        if n ~= #val then is_array = false end

        for k, v in ipairs(val) do
            table.insert(parts, Utils.serializeTable(v))
        end
        if not is_array then
            for k, v in pairs(val) do
                if type(k) == "number" and k > 0 and k <= #val and val[k] == v then
                    -- already handled
                else
                    table.insert(parts, string.format("[%s]=%s", Utils.serializeTable(k), Utils.serializeTable(v)))
                end
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

-- Serialize note data thành string (Dùng cho Undo State)
function Utils.notesTableToString(tbl)
    local result = {}
    for _, note in ipairs(tbl) do
        table.insert(result, string.format("%d,%d,%d,%d,%d,%d,%d,%d",
            note.startppqpos, note.endppqpos, note.chan, note.pitch, note.vel, note.selected and 1 or 0, note.muted and 1 or 0, note.index))
    end
    return table.concat(result, ";")
end

-- Deserialize string thành note data table (Dùng cho Undo State)
function Utils.stringToNotesTable(str)
    local result = {}
    for noteStr in string.gmatch(str, "([^;]+)") do
        local startppqpos, endppqpos, chan, pitch, vel, selected, muted, index = string.match(noteStr, "(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
        table.insert(result, {
            startppqpos = tonumber(startppqpos),
            endppqpos = tonumber(endppqpos),
            chan = tonumber(chan),
            pitch = tonumber(pitch),
            vel = tonumber(vel),
            selected = tonumber(selected) == 1,
            muted = tonumber(muted) == 1,
            index = tonumber(index)
        })
    end
    return result
end

-----------------------------------------------------------
-- 5. Mathematical Algorithms
-----------------------------------------------------------

-- Tạo pattern Euclidean (Bjorklund's algorithm concept)
function Utils.generateEuclideanPattern(steps, hits)
    local pattern = {}
    if hits >= steps then
        for i = 1, steps do table.insert(pattern, true) end
        return pattern
    elseif hits <= 0 then
        for i = 1, steps do table.insert(pattern, false) end
        return pattern
    end

    pattern = {}
    for i = 0, steps - 1 do
        if ((i * hits) % steps) < hits then
            table.insert(pattern, true) 
        else
            table.insert(pattern, false)
        end
    end
    
    return pattern
end

-- Deep Copy Table
function Utils.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.deepCopy(orig_key)] = Utils.deepCopy(orig_value)
        end
        setmetatable(copy, Utils.deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return Utils