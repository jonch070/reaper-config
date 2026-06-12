-- components/FilterInput.lua - Filterable Input Component
-- TODO - This is very track/instrument specific right now, would be good to modify to just take a generic list and have good callbacks so it can be used for other data.

local FilterInput = {}

local ImGui = reaper.ImGui_CreateContext and reaper or nil

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.UI)
end

-- Internal state management
---@type FilterInputPopupState|nil
local activePopup = nil
---@type FilterInputConfig|nil
local activePopupConfig = nil
---@type boolean
local focusInputNextFrame = false
---@type FilterInputScrollState
local scrollState = {
    selected_index = 1,
    should_scroll = false,
    selection_changed = false
}

---@type FilterInputDropdownState
local dropdown_state = {
    search_query = "",
    dropdown_was_open = false,
    clear_search_next_frame = false,
    dropdown_clicked = false
}
local debugToggleValue = nil -- used to only log something when it changes

-- Configuration for popup positioning
local POPUP_POSITION_OFFSET_X = 0.6  -- 60% of button width
local POPUP_POSITION_OFFSET_Y = 0.6  -- 60% of button height

--------------------------------------------------------------------------------
-- New Popup API Functions
--------------------------------------------------------------------------------

-- Public API functions
---@return FilterInputPopupState|nil
function FilterInput.getActivePopup()
    return activePopup
end

---@return FilterInputConfig|nil
function FilterInput.getActivePopupConfig()
    return activePopupConfig
end

---@return boolean
function FilterInput.shouldFocusInputNextFrame()
    return focusInputNextFrame
end

function FilterInput.clearFocusFlag()
    focusInputNextFrame = false
end

-- Set popup to appear at the current button position with configuration
-- This must be called immediately after the button that clicked it, OR with a custom rect
---@param config FilterInputConfig
---@param customRect? Rect Optional custom position rectangle
function FilterInput.setPopupToAppear(config, customRect)
    -- Use custom rect if provided, otherwise capture current item position
    local buttonX, buttonY, buttonWidth, buttonHeight
    
    if customRect then
        buttonX = customRect.x
        buttonY = customRect.y
        buttonWidth = customRect.width
        buttonHeight = customRect.height
    else
        -- Capture button position and size
        local ctx = State.imgui.ctx
        buttonX, buttonY = ImGui.ImGui_GetItemRectMin(ctx)
        buttonWidth, buttonHeight = ImGui.ImGui_GetItemRectSize(ctx)
    end
    
    -- Calculate popup position using offset formula
    local popupX = buttonX + (buttonWidth * POPUP_POSITION_OFFSET_X)
    local popupY = buttonY + (buttonHeight * POPUP_POSITION_OFFSET_Y)
    
    -- Set popup state
    activePopup = {
        positionX = popupX,
        positionY = popupY
    }
    
    -- Store configuration
    activePopupConfig = config
    
    -- Set focus flag for text input
    focusInputNextFrame = true
end

-- Render active popup if one exists
function FilterInput.renderActivePopups()
    local ctx = State.imgui.ctx
    
    if (debugToggleValue == activePopup) then
    else
        debugToggleValue = activePopup
        debug_log("activeFilterPopup")
        debug_log(activePopup)
    end
    
    -- Only render popup if one is active
    if not activePopup then
        return
    end
    
    local popup = activePopup
    local config = activePopupConfig
    
    -- Position the popup window
    ImGui.ImGui_SetNextWindowPos(ctx, popup.positionX, popup.positionY)
    
    -- Calculate popup size
    local popup_width = 200
    local max_results_height = 120
    local search_input_height = ImGui.ImGui_GetTextLineHeightWithSpacing(ctx) + 8
    local popup_height = search_input_height + max_results_height + 16 -- padding
    
    ImGui.ImGui_SetNextWindowSize(ctx, popup_width, popup_height)
    
    -- Create popup window
    local popup_id = "##filter_input_popup"
    local popup_visible = ImGui.ImGui_Begin(ctx, popup_id, nil, 
            ImGui.ImGui_WindowFlags_NoTitleBar() |
            ImGui.ImGui_WindowFlags_NoMove() |
            ImGui.ImGui_WindowFlags_NoResize() |
            ImGui.ImGui_WindowFlags_NoSavedSettings() |
            ImGui.ImGui_WindowFlags_AlwaysAutoResize() |
            ImGui.ImGui_WindowFlags_TopMost() | 
            ImGui.ImGui_WindowFlags_NoDocking())
    
    if popup_visible then
        local shouldClose = false
        local track_selected = nil
        
        -- Search input
        ImGui.ImGui_PushItemWidth(ctx, popup_width - 16)
        local search_id = "##search_instrument_popup"
        
        -- Set keyboard focus if this search was just activated
        if focusInputNextFrame then
            ImGui.ImGui_SetKeyboardFocusHere(ctx)
            focusInputNextFrame = false
        end
        
        local hintText = config and config.hintText or "Select an item"
        local changed, new_query = ImGui.ImGui_InputTextWithHint(ctx, search_id, 
            hintText, dropdown_state.search_query or "")
        ImGui.ImGui_PopItemWidth(ctx)
        
        if changed then
            dropdown_state.search_query = new_query
            -- Only call getFilteredList if not loading
            if config and (not config.isLoading or not config.isLoading()) then
                dropdown_state.filtered_items = config.getFilteredList(new_query)
            else
                dropdown_state.filtered_items = {}
            end
            scrollState.selected_index = 1
        end
        
        -- Get input field info for focus state
        local input_active = ImGui.ImGui_IsItemActive(ctx)
        local input_hovered = ImGui.ImGui_IsItemHovered(ctx)
        
        -- Determine if we should show results
        local hasSearchQuery = dropdown_state.search_query and dropdown_state.search_query ~= ""
        local shouldShowResults = hasSearchQuery or (config and config.showAllWhenEmpty)
        
        if shouldShowResults then
            local isCurrentlyLoading = config and config.isLoading and config.isLoading()
            local filtered = dropdown_state.filtered_items or {}
            
            -- If no search query but showAllWhenEmpty is true, get all items
            if not hasSearchQuery and config and config.showAllWhenEmpty and not isCurrentlyLoading then
                filtered = config.getFilteredList("")
            end
            
            -- Create scrollable child window for results
            if reaper.ImGui_BeginChild(ctx, "##filter_results_popup", 0, max_results_height, reaper.ImGui_ChildFlags_Borders()) then
                
                if isCurrentlyLoading then
                    -- Show loading state
                    Utils.push_disabled_text(ctx)
                    ImGui.ImGui_Text(ctx, "Loading...")
                    Utils.pop_text_color(ctx)
                elseif #filtered > 0 then
                    -- Use internal scroll state for smart scrolling
                    local scroll_state = scrollState
                    
                    -- Initialize scroll state when dropdown first appears
                    if not dropdown_state.dropdown_was_open then
                        scroll_state.selected_index = 1
                        scroll_state.should_scroll = true
                    end
                    
                    -- Handle keyboard navigation
                    local old_selected_index = scroll_state.selected_index
                    if ImGui.ImGui_IsKeyPressed(ctx, ImGui.ImGui_Key_DownArrow()) then
                        scroll_state.selected_index = math.min(scroll_state.selected_index + 1, #filtered)
                    elseif ImGui.ImGui_IsKeyPressed(ctx, ImGui.ImGui_Key_UpArrow()) then
                        scroll_state.selected_index = math.max(scroll_state.selected_index - 1, 1)
                    elseif ImGui.ImGui_IsKeyPressed(ctx, ImGui.ImGui_Key_Enter()) then
                        -- Select the currently highlighted item
                        if scroll_state.selected_index >= 1 and scroll_state.selected_index <= #filtered then
                            track_selected = filtered[scroll_state.selected_index]
                            dropdown_state.dropdown_clicked = true
                        end
                    elseif ImGui.ImGui_IsKeyPressed(ctx, ImGui.ImGui_Key_Escape()) then
                        track_selected = "clear"
                        dropdown_state.dropdown_clicked = true
                    end
                    
                    -- Track selection changes for smart scrolling
                    if scroll_state.selected_index ~= old_selected_index then
                        scroll_state.selection_changed = true
                    else
                        scroll_state.selection_changed = false
                    end
                    
                    -- Render filtered items
                    for i, item in ipairs(filtered) do
                        local is_highlighted = (i == scroll_state.selected_index)
                        local label = item.name
                        
                        if ImGui.ImGui_Selectable(ctx, label, is_highlighted) then
                            debug_log("clicked!")
                            track_selected = item
                            dropdown_state.dropdown_clicked = true
                        end
                        
                        -- Smart scrolling logic
                        if is_highlighted then
                            ImGui.ImGui_SetItemDefaultFocus(ctx)
                            
                            -- Get scroll info for smart positioning
                            local scroll_y = ImGui.ImGui_GetScrollY(ctx)
                            local item_height = ImGui.ImGui_GetTextLineHeightWithSpacing(ctx)
                            local item_pos_y = (i - 1) * item_height
                            local buffer_zone = item_height * 1
                            
                            local should_adjust_scroll = false
                            local new_scroll_y = scroll_y
                            
                            if scroll_state.should_scroll then
                                new_scroll_y = math.max(0, item_pos_y - buffer_zone)
                                should_adjust_scroll = true
                                scroll_state.should_scroll = false
                            elseif scroll_state.selection_changed then
                                local visible_top = scroll_y
                                local visible_bottom = scroll_y + max_results_height
                                
                                local too_close_to_top = item_pos_y < (visible_top + buffer_zone)
                                local too_close_to_bottom = (item_pos_y + item_height) > (visible_bottom - buffer_zone)
                                
                                if too_close_to_top then
                                    new_scroll_y = math.max(0, item_pos_y - buffer_zone)
                                    should_adjust_scroll = true
                                elseif too_close_to_bottom then
                                    new_scroll_y = item_pos_y + item_height + buffer_zone - max_results_height
                                    should_adjust_scroll = true
                                end
                                
                                scroll_state.selection_changed = false
                            end
                            
                            if should_adjust_scroll then
                                ImGui.ImGui_SetScrollY(ctx, new_scroll_y)
                            end
                        end
                    end
                    
                else
                    -- Show "no matches" message
                    Utils.push_disabled_text(ctx)
                    local no_match_text = "Nothing matches \"" .. dropdown_state.search_query .. "\""
                    if ImGui.ImGui_Selectable(ctx, no_match_text, false) then
                        track_selected = "clear"
                        dropdown_state.dropdown_clicked = true
                    end
                    Utils.pop_text_color(ctx)
                end
                
                reaper.ImGui_EndChild(ctx)
            end
            
            dropdown_state.dropdown_was_open = true
        else
            dropdown_state.dropdown_was_open = false
            -- Show placeholder text when no search query
            reaper.ImGui_BeginChild(ctx, "##filter_placeholder_popup", 0, max_results_height, reaper.ImGui_ChildFlags_Borders())
            Utils.push_disabled_text(ctx)
            local placeholderText = config and config.placeholderText or "Type to search..."
            ImGui.ImGui_Text(ctx, placeholderText)
            Utils.pop_text_color(ctx)
            reaper.ImGui_EndChild(ctx)
        end
        
        -- Check if clicked outside popup to close
        local popup_hovered = ImGui.ImGui_IsWindowHovered(ctx, 
            ImGui.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem() | ImGui.ImGui_HoveredFlags_AllowWhenBlockedByPopup())
        local popup_focused = ImGui.ImGui_IsWindowFocused(ctx)
        local mouse_clicked = ImGui.ImGui_IsMouseClicked(ctx, ImGui.ImGui_MouseButton_Left())
        
        -- If mouse was clicked, check if it was outside the popup bounds
        if mouse_clicked and not dropdown_state.dropdown_clicked then
            local mouse_x, mouse_y = ImGui.ImGui_GetMousePos(ctx)
            local win_x, win_y = ImGui.ImGui_GetWindowPos(ctx)
            local win_width, win_height = ImGui.ImGui_GetWindowSize(ctx)
            
            -- Check if click was outside popup window bounds
            local clicked_outside = mouse_x < win_x or mouse_x > (win_x + win_width) or
                                   mouse_y < win_y or mouse_y > (win_y + win_height)
            
            if clicked_outside then
                debug_log("set: should close 1 - clicked outside popup")
                shouldClose = true
            end
        end
        
        -- Call callback if item was selected
        if track_selected and config then
            if track_selected == "clear" then
                FilterInput.clear_search()
            else
                config.onItemSelected(track_selected)
                FilterInput.clear_search()
            end
            debug_log("set: should close 2")
            shouldClose = true
        end
        
        -- Close popup if needed
        if shouldClose then
            debug_log("should close")
            activePopup = nil
            activePopupConfig = nil
            FilterInput.clear_search()
        end
        
        ImGui.ImGui_End(ctx)
    end
    
    dropdown_state.dropdown_clicked = false
end

-- Clear search state
function FilterInput.clear_search()
    dropdown_state.search_query = ""
    dropdown_state.filtered_items = {}
    dropdown_state.show_search_popup = false
    
    -- Reset scroll state
    scrollState.selected_index = 1
    scrollState.should_scroll = false
    scrollState.selection_changed = false
end

return FilterInput