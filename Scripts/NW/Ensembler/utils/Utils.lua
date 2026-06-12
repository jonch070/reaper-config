-- Utils.lua - Shared Utilities and Constants
-- TODO Revisit how much these are shared and if they should live in this file or just where they are actually used

Utils = {}

local ImGui = reaper.ImGui_CreateContext and reaper or nil

-- Mathematical utilities
---Round a number to the nearest integer
---@param x number The number to round
---@return number The rounded integer
function Utils.round(x)
    return math.floor(x + 0.5)
end

-- Color conversion utilities
function Utils.int_to_rgba(color_int)
    local r = (color_int >> 0) & 0xFF
    local g = (color_int >> 8) & 0xFF
    local b = (color_int >> 16) & 0xFF
    local a = (color_int >> 24) & 0xFF
    return r/255, g/255, b/255, a/255
end

function Utils.rgba_to_int(r, g, b, a)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor((b or 1) * 255)
    a = math.floor((a or 1) * 255)
    return (a << 24) | (b << 16) | (g << 8) | r
end

-- Common UI styling helpers
function Utils.push_button_colors(ctx, r, g, b, a)
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_Button(), Utils.rgba_to_int(r*0.3, g*0.3, b*0.3, a or 1))
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_ButtonHovered(), Utils.rgba_to_int(r*0.4, g*0.4, b*0.4, a or 1))
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_ButtonActive(), Utils.rgba_to_int(r*0.5, g*0.5, b*0.5, a or 1))
end

function Utils.pop_button_colors(ctx)
    ImGui.ImGui_PopStyleColor(ctx, 3)
end

-- Text styling helpers
function Utils.push_disabled_text(ctx)
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_Text(), 0x808080FF)
end

function Utils.push_gray_text(ctx)
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_Text(), 0xCCCCCCFF)
end

function Utils.pop_text_color(ctx)
    ImGui.ImGui_PopStyleColor(ctx)
end

-- Transparent button styling (for clickable labels)
function Utils.push_transparent_button(ctx)
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_Button(), 0x00000000) -- Transparent
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_ButtonHovered(), 0x33333333) -- Light hover
    ImGui.ImGui_PushStyleColor(ctx, ImGui.ImGui_Col_ButtonActive(), 0x55555555) -- Light active
end

function Utils.pop_transparent_button(ctx)
    ImGui.ImGui_PopStyleColor(ctx, 3)
end

function Utils.getItemRect(ctx)
    local x, y = reaper.ImGui_GetItemRectMin(ctx)
    local width, height = reaper.ImGui_GetItemRectSize(ctx)
    return {
        x = x,
        y = y,
        width = width,
        height = height
    }
end

---Calculate if two rectangles are mostly overlapping (50% or more of either rect overlaps)
---@param rect1 Rect
---@param rect2 Rect
---@return boolean
function Utils.doRectsMostlyOverlap(rect1, rect2)
    if (rect1 == nil or rect2 == nil) then return false end

    -- Calculate intersection bounds
    local intersectLeft = math.max(rect1.x, rect2.x)
    local intersectTop = math.max(rect1.y, rect2.y)
    local intersectRight = math.min(rect1.x + rect1.width, rect2.x + rect2.width)
    local intersectBottom = math.min(rect1.y + rect1.height, rect2.y + rect2.height)
    
    -- Check if there's any intersection at all
    if intersectLeft >= intersectRight or intersectTop >= intersectBottom then
        return false
    end
    
    -- Calculate intersection area
    local intersectionArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop)
    
    -- Calculate areas of both rectangles
    local rect1Area = rect1.width * rect1.height
    local rect2Area = rect2.width * rect2.height
    
    -- Check if intersection is 50% or more of either rectangle
    local overlapThreshold = 0.4
    return (intersectionArea >= rect1Area * overlapThreshold) or 
           (intersectionArea >= rect2Area * overlapThreshold)
end

-- Table utilities

---Create a shallow copy of an array
---@param array table The array to copy
---@return table A new array with the same elements
function Utils.shallowCopy(array)
    local copy = {}
    for i, v in ipairs(array) do
        copy[i] = v
    end
    return copy
end

return Utils