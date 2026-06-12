-- components/DropTarget.lua - Custom Drop Target System
-- Works with the custom Draggable system using simple hover detection

local DropTarget = {}

-- ==============================================================================
-- MAIN DROP TARGET WRAPPER
-- ==============================================================================
-- Makes any UI element accept dropped items using custom hover detection
--
-- Parameters:
--   ctx: RealmGUI context
--   render_fn: Function that renders the UI content
--              Receives: (is_hover_target, payload_data)
--              - is_hover_target: true when a compatible draggable is hovering
--              - payload_data: the payload from the draggable (nil when not hovering)
--   options: {
--       can_accept: function(payload_data) -> bool (optional, defaults to true)
--                   Determines if this target can accept the payload
--       on_drop: function(payload_data) -> void (optional)
--                Called when an item is dropped
--   }
--
-- Returns: whatever the render_fn returns
-- ==============================================================================
function DropTarget.render(ctx, render_fn, options)
    if not ctx or not render_fn then
        return nil
    end
    
    options = options or {}
    local can_accept_fn = options.can_accept or function(payload) return true end
    local on_drop_fn = options.on_drop
    
    -- First render to establish the item for hover detection
    local result = render_fn(false, nil)
    local item_hovered = reaper.ImGui_IsItemHovered(ctx, 
        reaper.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()
    )
    local dropTargetRect = Utils.getItemRect(ctx)

    -- Check overlaps with dragged item copies, but exclude group handles
    local draggedElementIdOverlapsWithTarget = nil
    local dragStates = Draggable.getDragStates()
    for draggedElementId, elementDragState in pairs(dragStates) do
        if Utils.doRectsMostlyOverlap(dropTargetRect, elementDragState.item_copy_rect) then
            -- Skip group handles - they shouldn't be accepted by drop targets
            if not Draggable.is_group_handle(draggedElementId) then
                draggedElementIdOverlapsWithTarget = draggedElementId
                break
            end
        end
    end
    if (item_hovered and Draggable.is_dragging() and draggedElementIdOverlapsWithTarget == nil) then
        Debug.log("not detecting right?", Debug.FEATURE.UI)
        Debug.log(dropTargetRect, Debug.FEATURE.UI)
        Debug.log(dragStates, Debug.FEATURE.UI)
    end 
    
    -- Check if we should show hover state and handle drops
    if Draggable.is_dragging() then
        local current_payload = Draggable.get_current_payload(draggedElementIdOverlapsWithTarget)
        local mouse_released = reaper.ImGui_IsMouseReleased(ctx, 0)
        
        if draggedElementIdOverlapsWithTarget and current_payload then -- and can_accept_fn(current_payload) then
            -- We're hovering with a compatible item

            -- YOU LEFT OFF HERE TRYING TO GET THIS METHOD TO HANDLE MULTI-DROPS 
            -- I think the issue is that end_all_active_drags is getting called before others are done
            -- Need to delay that until the end of the frame perhaps
            
            -- Check for drop (mouse just released while hovering)
            if mouse_released then
                if on_drop_fn then
                    on_drop_fn(current_payload)
                end
            else
                -- Just hovering - show hover state
                -- Re-render with hover feedback
                local cursor_x, cursor_y = reaper.ImGui_GetCursorPos(ctx)
                local item_min_x, item_min_y = reaper.ImGui_GetItemRectMin(ctx)
                local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)
                local offset_x = item_min_x - screen_x
                local offset_y = item_min_y - screen_y
                
                reaper.ImGui_SetCursorPos(ctx, cursor_x + offset_x, cursor_y + offset_y)
                result = render_fn(true, current_payload)
            end
        end
    end
    
    return result
end

-- ==============================================================================
-- UTILITY FUNCTIONS
-- ==============================================================================

-- Helper to create a simple highlight overlay for drop targets
-- This is optional - components can implement their own hover visualization
function DropTarget.render_hover_overlay(ctx, width, height, color)
    color = color or 0x40FFFFFF  -- Default to semi-transparent white
    
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local x, y = reaper.ImGui_GetItemRectMin(ctx)
    local x2, y2 = reaper.ImGui_GetItemRectMax(ctx)
    
    -- If width/height provided, use those instead
    if width and height then
        x2 = x + width
        y2 = y + height
    end
    
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x2, y2, color)
end

return DropTarget