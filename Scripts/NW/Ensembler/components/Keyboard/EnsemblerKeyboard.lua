-- components/EnsemblerKeyboard.lua - Ensembler Keyboard Display Component

local EnsemblerKeyboard = {}

local Keyboard = require('components/Keyboard/Keyboard')
local Ensembler_INFX_Monitor = require('utils/Ensembler_INFX_Monitor')

-- Base color constants (0xRRGGBBAA)
local BASE_COLORS = {
    VOICE = 0x487ed4FF,      -- Blue for playable voices
    CHORD_TONE = 0xdb2a2aFF, -- Red for chord tones  
    UNASSIGNED = 0x808080FF  -- Gray for held but not voiced
}

-- Helper function to extract RGBA components from color integer
local function color_to_rgba(color_int)
    local r = (color_int & 0xFF) / 255.0
    local g = ((color_int >> 8) & 0xFF) / 255.0
    local b = ((color_int >> 16) & 0xFF) / 255.0
    local a = ((color_int >> 24) & 0xFF) / 255.0
    return r, g, b, a
end

-- Helper function to convert RGBA components back to color integer
local function rgba_to_color(r, g, b, a)
    r = math.floor(math.min(math.max(r, 0), 1) * 255)
    g = math.floor(math.min(math.max(g, 0), 1) * 255)
    b = math.floor(math.min(math.max(b, 0), 1) * 255)
    a = math.floor(math.min(math.max(a, 0), 1) * 255)
    return r | (g << 8) | (b << 16) | (a << 24)
end

-- Apply transposition-based color variation using opacity simulation
local function apply_color_variation(base_color, transposition)
    if transposition == 0 then
        return base_color
    end
    
    -- Calculate octaves of transposition
    local octaves = transposition / 12.0
    
    -- 30% change per octave, capped at ±70%
    local variation_amount = math.min(math.max(octaves * 0.3, -0.7), 0.7)
    
    local r, g, b, a = color_to_rgba(base_color)
    
    if variation_amount > 0 then
        -- Positive transposition: interpolate toward white (simple lightening)
        r = r + (1.0 - r) * variation_amount
        g = g + (1.0 - g) * variation_amount
        b = b + (1.0 - b) * variation_amount
    else
        -- Negative transposition: interpolate toward black (simple darkening)
        local factor = 1.0 + variation_amount -- variation_amount is negative
        r = r * factor
        g = g * factor
        b = b * factor
    end
    
    return rgba_to_color(r, g, b, a)
end

-- Get appropriate color for a lane note
local function get_lane_color(lane_type, transposition)
    local base_color
    
    if lane_type == "chord_tone" then
        base_color = BASE_COLORS.CHORD_TONE
    else
        base_color = BASE_COLORS.VOICE
    end
    
    return apply_color_variation(base_color, transposition)
end

-- Update keyboard display from current MIDI state
local function update_keyboard_display()
    local midi_data = Ensembler_INFX_Monitor.get_current_state()

    -- Clear all existing notes
    Keyboard.clear_all()

    -- Add voiced notes with transposition-aware colors
    for _, instrument_note in pairs(midi_data.instrument_notes) do
        local color = get_lane_color(instrument_note.lane_type, instrument_note.transposition)
        Keyboard.note_on(instrument_note.note, color)
    end

    -- Add unassigned notes (always gray)
    for _, note in ipairs(midi_data.unassigned_notes) do
        Keyboard.note_on(note, BASE_COLORS.UNASSIGNED)
    end
end

-- Main render function
function EnsemblerKeyboard.render(ctx, width, height, orientation)
    -- Update keyboard display if ensemble is active
    if State.ensemble.is_active then
        update_keyboard_display()
    else
        -- Clear keyboard if ensemble is not active
        Keyboard.clear_all()
    end
    
    -- Render the keyboard
    Keyboard.render(ctx, width, height, orientation)
end

-- Get base colors for external reference (if needed)
function EnsemblerKeyboard.get_base_colors()
    return BASE_COLORS
end

return EnsemblerKeyboard