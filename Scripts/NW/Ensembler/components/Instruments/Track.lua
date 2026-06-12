-- components/Track.lua - Track Display Component

local Track = {}

local Utils = Utils
local ImGui = reaper.ImGui_CreateContext and reaper or nil

-- Render a single track pill (display and removal)
function Track.render(ctx, voice_idx, track_idx, track_data, is_disabled)
    local r, g, b, a = Utils.int_to_rgba(track_data.color)
    
    -- Gray out if voice is disabled
    if is_disabled then
        r, g, b = 0.3, 0.3, 0.3
    end
    
    -- Apply track color styling
    Utils.push_button_colors(ctx, r, g, b, 1)
    
    local label = track_data.name .. " ×##pill_" .. voice_idx .. "_" .. track_idx
    local clicked = ImGui.ImGui_Button(ctx, label)
    
    Utils.pop_button_colors(ctx)
    
    if ImGui.ImGui_IsItemHovered(ctx) and not is_disabled then
        ImGui.ImGui_SetTooltip(ctx, "Click to remove track")
    end
    
    return clicked
end

return Track