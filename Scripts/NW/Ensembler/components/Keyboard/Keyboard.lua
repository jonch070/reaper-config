-- Keyboard.lua - Piano Keyboard Component for ReaImGui
-- A standalone piano keyboard widget with note highlighting
-- Supports both horizontal and vertical orientations

local Keyboard = {}

-- Configuration constants
local WHITE_KEY_COLOR = 0xF8F8F8FF
local BLACK_KEY_COLOR = 0x2A2A2AFF
local WHITE_KEY_BORDER = 0xC0C0C0FF
local BLACK_KEY_BORDER = 0x1A1A1AFF
local DEFAULT_HIGHLIGHT_COLOR = 0x4080FFFF
local OCTAVE_LABEL_COLOR = 0x808080FF

local WHITE_KEY_ROUNDING = 2.0
local BLACK_KEY_ROUNDING = 1.5

-- MIDI note range (88-key piano)
local LOWEST_NOTE = 21  -- A0
local HIGHEST_NOTE = 108 -- C8

-- Component state
local active_notes = {} -- [midi_note] = color

-- Helper function to convert note name to MIDI number
local function note_name_to_midi(note_name)
    if type(note_name) == "number" then
        return note_name
    end
    
    -- Parse note name like "C3", "F#4", "Bb2"
    local note_part = note_name:match("^([A-Ga-g][#b]?)")
    local octave_part = tonumber(note_name:match("([%-]?%d+)$"))
    
    if not note_part or not octave_part then
        return nil
    end
    
    -- Note to semitone mapping
    local note_to_semitone = {
        ["C"] = 0, ["C#"] = 1, ["Db"] = 1,
        ["D"] = 2, ["D#"] = 3, ["Eb"] = 3,
        ["E"] = 4,
        ["F"] = 5, ["F#"] = 6, ["Gb"] = 6,
        ["G"] = 7, ["G#"] = 8, ["Ab"] = 8,
        ["A"] = 9, ["A#"] = 10, ["Bb"] = 10,
        ["B"] = 11
    }
    
    local semitone = note_to_semitone[note_part:upper()]
    if not semitone then
        return nil
    end
    
    return (octave_part + 1) * 12 + semitone
end

-- Helper function to check if a MIDI note is a white key
local function is_white_key(midi_note)
    local note_in_octave = midi_note % 12
    -- White keys are: C(0), D(2), E(4), F(5), G(7), A(9), B(11)
    return note_in_octave == 0 or note_in_octave == 2 or note_in_octave == 4 or 
           note_in_octave == 5 or note_in_octave == 7 or note_in_octave == 9 or note_in_octave == 11
end

-- Helper function to get white key index (0-based, counting only white keys)
local function get_white_key_index(midi_note)
    if not is_white_key(midi_note) then
        return nil
    end
    
    local count = 0
    for note = LOWEST_NOTE, midi_note do
        if is_white_key(note) then
            if note == midi_note then
                return count
            end
            count = count + 1
        end
    end
    return nil
end

-- Helper function to get octave number for a MIDI note
local function get_octave_number(midi_note)
    return math.floor(midi_note / 12) - 1
end

-- Helper function to check if a note is C
local function is_c_note(midi_note)
    return (midi_note % 12) == 0
end

-- Count total white keys in our range
local function count_white_keys()
    local count = 0
    for note = LOWEST_NOTE, HIGHEST_NOTE do
        if is_white_key(note) then
            count = count + 1
        end
    end
    return count
end

-- Horizontal rendering implementation
local function render_horizontal(ctx, width, height, canvas_x, canvas_y, draw_list)
    local total_white_keys = count_white_keys()
    local white_key_width = width / total_white_keys
    local white_key_height = height
    local black_key_width = white_key_width * 0.6
    local black_key_height = white_key_height * 0.65
    
    -- Draw white keys first
    for note = LOWEST_NOTE, HIGHEST_NOTE do
        if is_white_key(note) then
            local white_index = get_white_key_index(note)
            if white_index then
                local x1 = canvas_x + white_index * white_key_width
                local y1 = canvas_y
                local x2 = x1 + white_key_width - 1 -- -1 for border spacing
                local y2 = y1 + white_key_height
                
                -- Determine color (highlighted or default)
                local color = active_notes[note] or WHITE_KEY_COLOR
                
                -- Draw filled rectangle with rounded corners
                reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color, WHITE_KEY_ROUNDING)
                
                -- Draw border
                reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, WHITE_KEY_BORDER, WHITE_KEY_ROUNDING)
                
                -- Add octave number label if this is a C note
                if is_c_note(note) then
                    local octave = get_octave_number(note)
                    local text = tostring(octave)
                    local text_x = x1 + white_key_width * 0.5 - 4 -- Roughly center the number
                    local text_y = y2 - 20 -- Near bottom of key
                    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, OCTAVE_LABEL_COLOR, text)
                end
            end
        end
    end
    
    -- Draw black keys on top
    for note = LOWEST_NOTE, HIGHEST_NOTE do
        if not is_white_key(note) then
            -- Find the white key to the left of this black key
            local white_note_below = note - 1
            while white_note_below >= LOWEST_NOTE and not is_white_key(white_note_below) do
                white_note_below = white_note_below - 1
            end
            
            if white_note_below >= LOWEST_NOTE then
                local white_index = get_white_key_index(white_note_below)
                if white_index then
                    -- Position black key between white keys
                    local white_key_x = canvas_x + white_index * white_key_width
                    local x1 = white_key_x + white_key_width - (black_key_width * 0.5)
                    local y1 = canvas_y
                    local x2 = x1 + black_key_width
                    local y2 = y1 + black_key_height
                    
                    -- Determine color (highlighted or default)
                    local color = active_notes[note] or BLACK_KEY_COLOR
                    
                    -- Draw filled rectangle with rounded corners
                    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color, BLACK_KEY_ROUNDING)
                    
                    -- Draw border
                    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, BLACK_KEY_BORDER, BLACK_KEY_ROUNDING)
                end
            end
        end
    end
end

-- Vertical rendering implementation  
local function render_vertical(ctx, width, height, canvas_x, canvas_y, draw_list)
    local total_white_keys = count_white_keys()
    local white_key_width = width
    local white_key_height = height / total_white_keys
    local black_key_width = white_key_width * 0.65
    local black_key_height = white_key_height * 0.6
    
    -- Draw white keys first (from top to bottom, highest to lowest notes)
    local white_key_count = 0
    for note = HIGHEST_NOTE, LOWEST_NOTE, -1 do  -- Reverse order for top-to-bottom
        if is_white_key(note) then
            local y1 = canvas_y + white_key_count * white_key_height
            local x1 = canvas_x
            local x2 = x1 + white_key_width
            local y2 = y1 + white_key_height - 1 -- -1 for border spacing
            
            -- Determine color (highlighted or default)
            local color = active_notes[note] or WHITE_KEY_COLOR
            
            -- Draw filled rectangle with rounded corners
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color, WHITE_KEY_ROUNDING)
            
            -- Draw border
            reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, WHITE_KEY_BORDER, WHITE_KEY_ROUNDING)
            
            -- Add octave number label if this is a C note
            if is_c_note(note) then
                local octave = get_octave_number(note)
                local text = tostring(octave)
                local text_x = x2 - 15 -- Near right edge of key (so it's not covered by black keys)
                local text_y = y1 + white_key_height * 0.5 - 8 -- Roughly center vertically
                reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, OCTAVE_LABEL_COLOR, text)
            end
            
            white_key_count = white_key_count + 1
        end
    end
    
    -- Draw black keys on top (on the left side, like piano roll)
    white_key_count = 0
    for note = HIGHEST_NOTE, LOWEST_NOTE, -1 do  -- Reverse order for top-to-bottom
        if is_white_key(note) then
            -- Check if there's a black key below this white key (since we're iterating high to low)
            local black_note_below = note - 1
            if black_note_below >= LOWEST_NOTE and not is_white_key(black_note_below) then
                local white_y = canvas_y + white_key_count * white_key_height
                local x1 = canvas_x -- Black keys on left side (like piano roll)
                local y1 = white_y + white_key_height - (black_key_height * 0.5)
                local x2 = x1 + black_key_width
                local y2 = y1 + black_key_height
                
                -- Determine color (highlighted or default)
                local color = active_notes[black_note_below] or BLACK_KEY_COLOR
                
                -- Draw filled rectangle with rounded corners
                reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color, BLACK_KEY_ROUNDING)
                
                -- Draw border
                reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, BLACK_KEY_BORDER, BLACK_KEY_ROUNDING)
            end
            
            white_key_count = white_key_count + 1
        end
    end
end

-- Main render function
function Keyboard.render(ctx, width, height, orientation)
    if not ctx then return end
    
    -- Default to horizontal if no orientation specified
    orientation = orientation or "horizontal"
    
    -- Get drawing position and create draw list
    local canvas_x, canvas_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    
    -- Route to appropriate rendering function
    if orientation == "vertical" then
        render_vertical(ctx, width, height, canvas_x, canvas_y, draw_list)
    else
        render_horizontal(ctx, width, height, canvas_x, canvas_y, draw_list)
    end
    
    -- Create invisible button to advance cursor
    reaper.ImGui_InvisibleButton(ctx, "keyboard", width, height)
end

-- Note on function
function Keyboard.note_on(note, color)
    local midi_note = note_name_to_midi(note)
    if midi_note and midi_note >= LOWEST_NOTE and midi_note <= HIGHEST_NOTE then
        active_notes[midi_note] = color or DEFAULT_HIGHLIGHT_COLOR
    end
end

-- Note off function
function Keyboard.note_off(note)
    local midi_note = note_name_to_midi(note)
    if midi_note then
        active_notes[midi_note] = nil
    end
end

-- Clear all active notes
function Keyboard.clear_all()
    active_notes = {}
end

-- Get current active notes (for debugging/inspection)
function Keyboard.get_active_notes()
    return active_notes
end

return Keyboard