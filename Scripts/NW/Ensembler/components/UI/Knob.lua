-- Knob.lua - ReaImGui knob component with scale and fixed variants

-- Configuration constants
local DEFAULT_DIAMETER = 25
local RING_THICKNESS_RATIO = 0.3
local DOT_SIZE_RATIO = 1.1
local ANGLE_RANGE = 135
local MOUSE_SENSITIVITY = 0.005
local NUM_SEGMENTS = 36

-- Default colors (RGBA as 32-bit integers)
local DEFAULT_COLORS = {
    ring = 0x31332eFF,
    dot = 0xFFFFFFFF,
    negativeArc = 0xaa4242FF,  -- Red for left/negative
    positiveArc = 0x42aa76FF   -- Green for right/positive
}

-- Math utilities
local PI = math.pi
local function degToRad(degrees)
    return degrees * PI / 180
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

---@class KnobOptions
---@field diameter? number
---@field colors? table
---@field labelFormatter? fun(value: number): string Optional function to format the display label
---@field defaultValue? number Default value for double-click reset (defaults to 1.0)

local Knob = {}

---Render a knob component
---@param ctx ImGui_Context
---@param id string Unique identifier for the knob
---@param knobType string "scale" or "fixed"
---@param value number 0.0 to 2.0 for scale (1.0 = center), 0.0 to 1.0 for fixed
---@param callback function Called with new value when changed
---@param options? KnobOptions Optional configuration
---@return number newValue The current/updated value
function Knob.render(ctx, id, knobType, value, callback, options)
    options = options or {}
    local diameter = options.diameter or DEFAULT_DIAMETER
    local colors = {}
    
    -- Merge default colors with provided colors
    if options.colors then
        for k, v in pairs(DEFAULT_COLORS) do
            colors[k] = options.colors[k] or v
        end
    else
        colors = DEFAULT_COLORS
    end
    
    local radius = diameter * 0.5
    local ringThickness = radius * RING_THICKNESS_RATIO
    local centerOfRingRadius = radius - ringThickness / 2
    local dotRadius = ringThickness * DOT_SIZE_RATIO / 2
    
    -- Convert value to angle
    local angle
    if knobType == "scale" then
        -- Scale: 0 to 2 maps to -135° to +135° (1.0 = center)
        angle = (value - 1.0) * ANGLE_RANGE
    else
        -- Fixed: 0 to 1 maps to -135° to +135°
        angle = (value * ANGLE_RANGE * 2) - ANGLE_RANGE
    end
    
    -- Begin group to treat entire knob (button + drawing + label) as single unit
    reaper.ImGui_BeginGroup(ctx)
    
    -- Get current position and create invisible button for interaction
    local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local center_x = pos_x + radius
    local center_y = pos_y + radius
    
    -- Handle mouse interaction
    reaper.ImGui_InvisibleButton(ctx, id, diameter, diameter)
    local isActive = reaper.ImGui_IsItemActive(ctx)
    local isDoubleClicked = reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
    
    local newValue = value
    
    -- Handle double-click reset to default
    if isDoubleClicked then
        local defaultVal = options.defaultValue or 1.0
        newValue = defaultVal
        if callback then
            callback(newValue)
        end
    elseif isActive and reaper.ImGui_IsMouseDragging(ctx, 0) then
        local mouse_delta_x, mouse_delta_y = reaper.ImGui_GetMouseDelta(ctx)
        local mouseDelta = -mouse_delta_y + mouse_delta_x
        local angleDelta = mouseDelta * MOUSE_SENSITIVITY * 180
        
        local newAngle = angle + angleDelta
        
        -- Clamp angle to valid range
        newAngle = clamp(newAngle, -ANGLE_RANGE, ANGLE_RANGE)
        
        -- Convert angle back to value
        if knobType == "scale" then
            newValue = (newAngle / ANGLE_RANGE) + 1.0
            newValue = clamp(newValue, 0.0, 2.0)
        else
            -- Fixed: convert angle back to 0-1 range
            newValue = (newAngle + ANGLE_RANGE) / (ANGLE_RANGE * 2)
            newValue = clamp(newValue, 0.0, 1.0)
        end
        
        if newValue ~= value and callback then
            callback(newValue)
        end
    end
    
    -- Drawing
    local drawList = reaper.ImGui_GetWindowDrawList(ctx)
    
    -- Draw outer ring
    reaper.ImGui_DrawList_AddCircle(drawList, center_x, center_y, centerOfRingRadius, colors.ring, NUM_SEGMENTS, ringThickness)
    
    -- Draw colored arc for scale type
    if knobType == "scale" and newValue ~= 1.0 then
        local arcStartAngle = degToRad(-90)  -- Top center
        local arcEndAngle = degToRad(-90 + ((newValue - 1.0) * ANGLE_RANGE))
        local arcColor = newValue > 1.0 and colors.positiveArc or colors.negativeArc
        local arcRadius = centerOfRingRadius - 0.6
        
        -- Ensure we draw arc in correct direction
        if newValue < 1.0 then
            arcStartAngle, arcEndAngle = arcEndAngle, arcStartAngle
        end
        
        reaper.ImGui_DrawList_PathArcTo(drawList, center_x, center_y, arcRadius, arcStartAngle, arcEndAngle, NUM_SEGMENTS)
        reaper.ImGui_DrawList_PathStroke(drawList, arcColor, 0, ringThickness)

        -- Overdraw the top center edge with a small vertical line for sharp edge
        if math.abs(newValue - 1.0) > 0.01 then  -- Only if arc is visible
            local overDrawStartAngle = newValue > 1.0 and degToRad(-90) or degToRad(-90)
            local overDrawEndAngle = newValue < 1.0 and degToRad(-90) or degToRad(-90)
            reaper.ImGui_DrawList_PathArcTo(drawList, center_x, center_y, arcRadius, overDrawStartAngle, overDrawEndAngle, NUM_SEGMENTS)
            reaper.ImGui_DrawList_PathStroke(drawList, arcColor, 0, ringThickness)
        end
    end
    
    -- Calculate dot position
    local finalAngle = knobType == "scale" and (newValue - 1.0) * ANGLE_RANGE or ((newValue * ANGLE_RANGE * 2) - ANGLE_RANGE)
    local dotAngle = degToRad(-90 + finalAngle)  -- -90 to start from top
    local dotRadiusPosition = centerOfRingRadius - 0.4
    local dot_x = center_x + math.cos(dotAngle) * dotRadiusPosition
    local dot_y = center_y + math.sin(dotAngle) * dotRadiusPosition
    
    -- Draw dot (use fewer segments since it's smaller)
    reaper.ImGui_DrawList_AddCircleFilled(drawList, dot_x, dot_y, dotRadius, colors.dot, math.max(12, NUM_SEGMENTS // 3))
    
    -- Move cursor past the knob
    reaper.ImGui_SetCursorScreenPos(ctx, pos_x, pos_y + diameter)
    
    -- Display value text below knob
    local valueText
    if options.labelFormatter then
        valueText = options.labelFormatter(newValue)
    else
        valueText = string.format("%.2f", newValue)
    end
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, valueText)
    reaper.ImGui_SetCursorScreenPos(ctx, center_x - text_w * 0.5, pos_y + diameter + 5)
    reaper.ImGui_Text(ctx, valueText)
    
    -- End group - now IsItemClicked(), IsItemHovered() etc. work on entire knob
    reaper.ImGui_EndGroup(ctx)
    
    return newValue
end

return Knob