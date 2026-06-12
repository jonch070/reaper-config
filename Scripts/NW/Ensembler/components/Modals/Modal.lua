-- Modal.lua - Reusable Modal Dialog Component

require('types/types')

local Modal = {}

---@type string|nil 
local inputText = nil

---Render a text input modal dialog (following RealmGUI demo pattern)
---@param ctx ImGui_Context
---@param modalId string Unique identifier for this modal
---@param title string Title of the modal
---@param message string Message to display
---@param options table Options: confirmText, cancelText, initialText, onConfirm, onCancel
---@return boolean handled True if modal was confirmed or cancelled
function Modal.renderTextInput(ctx, modalId, title, message, options)
    options = options or {}
    local confirmText = options.confirmText or "OK"
    local cancelText = options.cancelText or "Cancel"
    
    if not inputText then 
        inputText = options.initialText or ""
    end
    
    -- Center the modal
    local center_x, center_y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
    reaper.ImGui_SetNextWindowPos(ctx, center_x, center_y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
    
    if reaper.ImGui_BeginPopupModal(ctx, modalId, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize() | reaper.ImGui_WindowFlags_NoTitleBar()) then
        -- Message text
        reaper.ImGui_Text(ctx, message)
        reaper.ImGui_Separator(ctx)
        
        -- Text input
        reaper.ImGui_SetNextItemWidth(ctx, 250)
        local changed, newText = reaper.ImGui_InputText(ctx, '##modal_input', inputText)
        if changed then
            inputText = newText
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Buttons
        local canConfirm = inputText ~= ""
        if not canConfirm then
            reaper.ImGui_BeginDisabled(ctx)
        end
        
        if reaper.ImGui_Button(ctx, confirmText, 120, 0) and canConfirm then
            reaper.ImGui_CloseCurrentPopup(ctx)
            if options.onConfirm then
                options.onConfirm(inputText)
            end
            inputText = nil
        end
        
        if not canConfirm then
            reaper.ImGui_EndDisabled(ctx)
        end
        
        reaper.ImGui_SetItemDefaultFocus(ctx)
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, cancelText, 120, 0) then
            reaper.ImGui_CloseCurrentPopup(ctx)
            if options.onCancel then
                options.onCancel()
            end
            inputText = nil
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
    
    return false
end

---Render a confirmation modal dialog (following RealmGUI demo pattern)
---@param ctx ImGui_Context
---@param modalId string Unique identifier for this modal
---@param title string Title of the modal
---@param message string Message to display (supports multiline with \n)
---@param options table Options: confirmText, cancelText, onConfirm, onCancel
---@return boolean handled True if modal was confirmed or cancelled
function Modal.renderConfirmation(ctx, modalId, title, message, options)
    options = options or {}
    local confirmText = options.confirmText or "Yes"
    local cancelText = options.cancelText or "Cancel"
    
    -- Center the modal
    local center_x, center_y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
    reaper.ImGui_SetNextWindowPos(ctx, center_x, center_y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
    
    if reaper.ImGui_BeginPopupModal(ctx, modalId, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize() | reaper.ImGui_WindowFlags_NoTitleBar()) then
        -- Message text (support multi-line)
        local lines = {}
        for line in message:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        
        for _, line in ipairs(lines) do
            reaper.ImGui_Text(ctx, line)
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Buttons
        if reaper.ImGui_Button(ctx, confirmText, 120, 0) then
            reaper.ImGui_CloseCurrentPopup(ctx)
            if options.onConfirm then
                options.onConfirm()
            end
        end
        
        reaper.ImGui_SetItemDefaultFocus(ctx)
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, cancelText, 120, 0) then
            reaper.ImGui_CloseCurrentPopup(ctx)
            if options.onCancel then
                options.onCancel()
            end
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
    
    return false
end

return Modal