-- components/Draggable.lua - Custom Drag & Drop System with Multi-element Support
-- Uses only basic mouse/hover detection, no ReaImGui native drag/drop

Draggable = {}

-- Module-level state for active drags - now per-element
---@type DragState[]
local drag_states = {}  -- drag_states[element_id] = individual_drag_state
local mainDraggedId = nil

-- Individual drag state structure:
-- {
--   is_active = false,
--   payload = nil,
--   offset_x = 0, offset_y = 0,
--   render_fn = nil,
--   item_rect = { min_x = 0, min_y = 0 }  -- stored rect for offset calculations
--   item_copy_rect = { min_x = 0, min_y = 0 }  -- stored rect for offset calculations
-- }

--------------------------------------------------------------------------------
-- Internal Helper Functions
--------------------------------------------------------------------------------

---Start drag operation for a specific element
---@param ctx ImGui_Context
---@param elementId string
---@param payloadData any
local function startDragForElement(ctx, elementId, payloadData)
    local mouseX, mouseY = reaper.ImGui_GetMousePos(ctx)
    
    -- Use stored rect for offset calculation
    local offsetX = mouseX - drag_states[elementId].item_rect.min_x
    local offsetY = mouseY - drag_states[elementId].item_rect.min_y
    
    -- Update drag state
    drag_states[elementId].is_active = true
    drag_states[elementId].payload = payloadData
    drag_states[elementId].offset_x = offsetX
    drag_states[elementId].offset_y = offsetY
end

--------------------------------------------------------------------------------
-- Main Draggable Wrapper
--------------------------------------------------------------------------------

---Makes any UI element draggable using custom mouse detection
---Now supports linked elements for section dragging
---@param ctx ImGui_Context
---@param elementId string Unique identifier for this specific draggable element
---@param payloadData any Data to pass when dropped
---@param renderFn function Function that renders UI content - receives (is_original, is_dragging)
---@param linkedElements? string[] Optional array of element IDs to drag together
---@return any Returns whatever the render_fn returns
function Draggable.render(ctx, elementId, payloadData, renderFn, linkedElements)
    if not ctx or not elementId or not renderFn then
        return nil
    end
    
    linkedElements = linkedElements or {}
    
    -- Initialize drag state if it doesn't exist
    if not drag_states[elementId] then
        drag_states[elementId] = {
            is_active = false
        }
    end
    
    -- Store whether this draggable has linked elements (making it a group handle)
    drag_states[elementId].hasLinkedElements = linkedElements and #linkedElements > 0
    
    local elementDragState = drag_states[elementId]
    
    -- Render the UI element
    local result = renderFn(true, elementDragState.is_active)
    
    -- Save current rect (always, whether dragging or not)
    local itemMinX, itemMinY = reaper.ImGui_GetItemRectMin(ctx)
    drag_states[elementId].item_rect = { min_x = itemMinX, min_y = itemMinY }

    -- Save the render function and payload
    drag_states[elementId].render_fn = renderFn
    drag_states[elementId].payload = payloadData
    
    -- Check if should start dragging
    if reaper.ImGui_IsItemActive(ctx) and reaper.ImGui_IsMouseDragging(ctx, 0) then
        if not elementDragState.is_active then
            -- Start dragging for this element
            mainDraggedId = elementId
            startDragForElement(ctx, elementId, payloadData)
            
            -- Start dragging for linked elements immediately
            for _, linkedId in ipairs(linkedElements) do
                if drag_states[linkedId] and not drag_states[linkedId].is_active then
                    startDragForElement(ctx, linkedId, nil)
                end
            end
        end
    end
    
    return result
end

--------------------------------------------------------------------------------
-- End of Frame Processing
--------------------------------------------------------------------------------

---Call this once at the end of your render loop
---Handles floating element rendering and drag cleanup for all active drags
---@param ctx ImGui_Context
function Draggable.end_of_frame(ctx)
    -- Render floating elements for all active drags
    for elementId, elementDragState in pairs(drag_states) do
        if elementDragState.is_active then
            local mouseX, mouseY = reaper.ImGui_GetMousePos(ctx)
            local floatX = mouseX - elementDragState.offset_x
            local floatY = mouseY - elementDragState.offset_y
            
            reaper.ImGui_SetCursorScreenPos(ctx, floatX, floatY)
            elementDragState.render_fn(false, true)  -- is_original=false, is_dragging=true

            -- Store the copied rect position to use for drop target calculations
            elementDragState.item_copy_rect = Utils.getItemRect(ctx)
        end
    end
    
    -- Clean up on mouse release
    if reaper.ImGui_IsMouseReleased(ctx, 0) then
        Draggable.end_all_active_drags()
    end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

---Check if any drag operation is currently active
---@return boolean
function Draggable.is_dragging()
    return drag_states[mainDraggedId] and drag_states[mainDraggedId].is_active
end

---Get the current drag payload for a specific element (if any)
---@return any|nil
function Draggable.get_current_payload(elementId)
    if drag_states[elementId] and drag_states[elementId].is_active then
        return drag_states[elementId].payload
    end
    return nil
end

---Check if a draggable element is a group handle (has linked elements)
---@param elementId string
---@return boolean
function Draggable.is_group_handle(elementId)
    return drag_states[elementId] and drag_states[elementId].hasLinkedElements or false
end

---End all active drag operations
function Draggable.end_all_active_drags()
    for elementId, elementDragState in pairs(drag_states) do
        if elementDragState.is_active then
            if drag_states[elementId] then
                drag_states[elementId].is_active = false
                drag_states[elementId].payload = nil
                drag_states[elementId].render_fn = nil
                drag_states[elementId].offset_x = 0
                drag_states[elementId].offset_y = 0
                drag_states[elementId].item_copy_rect = nil
                -- Keep item_rect for future drags
            end
        end
    end
    mainDraggedId = nil
end

function Draggable.getDragStates()
    return drag_states
end

return Draggable