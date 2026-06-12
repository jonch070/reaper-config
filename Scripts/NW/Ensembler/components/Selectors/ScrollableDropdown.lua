-- components/ScrollableDropdown.lua - Generic Scrollable List Component

local ScrollableDropdown = {}

local ImGui = reaper.ImGui_CreateContext and reaper or nil

-- Initialize dropdown state for an identifier if it doesn't exist
local function init_dropdown_state(dropdown_id)
    if not State.ui.scrollable_dropdown_state then
        State.ui.scrollable_dropdown_state = {}
    end
    
    if not State.ui.scrollable_dropdown_state[dropdown_id] then
        State.ui.scrollable_dropdown_state[dropdown_id] = {
            selected_index = 1,
            dropdown_just_opened = false,
            should_scroll = false,
            selection_changed = false
        }
    end
    
    return State.ui.scrollable_dropdown_state[dropdown_id]
end

-- Find index of current value in items list
local function find_current_index(items, current_value, get_item_value)
    for i, item in ipairs(items) do
        if get_item_value(item) == current_value then
            return i
        end
    end
    return 1 -- Default to first item if not found
end

-- Render scrollable dropdown list with smart scrolling and keyboard navigation
-- config = {
--   dropdown_id = "unique_id_for_this_dropdown",
--   items = array of items to display,
--   current_value = currently selected value (to highlight),
--   format_item = function(item) -> string to display,
--   get_item_value = function(item) -> value for comparison/selection,
--   child_height = height of scrollable area (optional, default 200),
--   dropdown_just_opened = true if this is first frame after opening (optional),
--   on_selection = function(selected_value) called when item selected (optional),
--   action_button_label = string label for optional action button below list (optional),
--   on_action = function() called when action button clicked (optional)
-- }
function ScrollableDropdown.render(ctx, config)
    local dropdown_id = config.dropdown_id
    local items = config.items or {}
    local current_value = config.current_value
    local format_item = config.format_item or function(item) return tostring(item) end
    local get_item_value = config.get_item_value or function(item) return item end
    local child_height = config.child_height or 200
    local dropdown_just_opened = config.dropdown_just_opened or false
    local on_selection = config.on_selection
    
    local selected_value = nil
    
    -- Initialize dropdown state
    local dropdown_state = init_dropdown_state(dropdown_id)
    
    -- If dropdown just opened, initialize selection to current value
    if dropdown_just_opened then
        dropdown_state.selected_index = find_current_index(items, current_value, get_item_value)
        dropdown_state.dropdown_just_opened = true
        dropdown_state.should_scroll = true  -- Scroll to show current value
    end
    
    -- Create scrollable region for the item list
    if reaper.ImGui_BeginChild(ctx, "scrollable_list_" .. dropdown_id, 0, child_height, reaper.ImGui_ChildFlags_Borders()) then
        
        -- Handle keyboard navigation
        local old_selected_index = dropdown_state.selected_index
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) then
            dropdown_state.selected_index = math.min(dropdown_state.selected_index + 1, #items)
        elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) then
            dropdown_state.selected_index = math.max(dropdown_state.selected_index - 1, 1)
        elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
            -- Select the currently highlighted item
            if dropdown_state.selected_index >= 1 and dropdown_state.selected_index <= #items then
                local selected_item = items[dropdown_state.selected_index]
                selected_value = get_item_value(selected_item)
            end
        elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            selected_value = "escape" -- Signal to close without selection
        end
        
        -- If selection changed via keyboard, check if we need to scroll
        if dropdown_state.selected_index ~= old_selected_index then
            dropdown_state.selection_changed = true
        else
            dropdown_state.selection_changed = false
        end
        
        -- Render items
        for i, item in ipairs(items) do
            local is_current = (get_item_value(item) == current_value)
            local is_highlighted = (i == dropdown_state.selected_index)
            local item_label = format_item(item)
            
            -- Always allow selection of any item, including the current one
            if reaper.ImGui_Selectable(ctx, item_label, is_highlighted) then
                selected_value = get_item_value(item)
            end
            
            -- Set initial focus and handle smart scrolling
            if is_highlighted then
                reaper.ImGui_SetItemDefaultFocus(ctx)
                
                -- Get scroll info for smart positioning
                local scroll_y = reaper.ImGui_GetScrollY(ctx)
                local item_height = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)
                local item_pos_y = (i - 1) * item_height
                local buffer_zone = item_height * 1 -- 1 row buffer from edges
                
                local should_adjust_scroll = false
                local new_scroll_y = scroll_y
                
                -- On dropdown open, position current item at top of safe zone
                if dropdown_state.should_scroll then
                    new_scroll_y = math.max(0, item_pos_y - buffer_zone)
                    should_adjust_scroll = true
                    dropdown_state.should_scroll = false
                -- Smart scroll when selection changed via keyboard
                elseif dropdown_state.selection_changed then
                    local visible_top = scroll_y
                    local visible_bottom = scroll_y + child_height
                    
                    -- Check if item is too close to edges
                    local too_close_to_top = item_pos_y < (visible_top + buffer_zone)
                    local too_close_to_bottom = (item_pos_y + item_height) > (visible_bottom - buffer_zone)
                    
                    if too_close_to_top then
                        -- Scroll up just enough to put item in safe zone
                        new_scroll_y = math.max(0, item_pos_y - buffer_zone)
                        should_adjust_scroll = true
                    elseif too_close_to_bottom then
                        -- Scroll down just enough to put item in safe zone  
                        new_scroll_y = item_pos_y + item_height + buffer_zone - child_height
                        should_adjust_scroll = true
                    end
                    
                    dropdown_state.selection_changed = false
                end
                
                -- Apply the calculated scroll position
                if should_adjust_scroll then
                    reaper.ImGui_SetScrollY(ctx, new_scroll_y)
                end
            end
        end
        
        -- Clear the "just opened" flag after first frame
        dropdown_state.dropdown_just_opened = false

        reaper.ImGui_EndChild(ctx)
    end

    -- Render optional action button below the list
    if config.action_button_label and config.on_action then
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, config.action_button_label, -1, 0) then
            selected_value = "action"
            config.on_action()
        end
    end

    -- Call callback if selection was made
    if selected_value and on_selection then
        on_selection(selected_value)
    end

    return selected_value
end

-- Clear dropdown state for cleanup
function ScrollableDropdown.clear_state(dropdown_id)
    if State.ui.scrollable_dropdown_state and State.ui.scrollable_dropdown_state[dropdown_id] then
        State.ui.scrollable_dropdown_state[dropdown_id] = nil
    end
end

return ScrollableDropdown