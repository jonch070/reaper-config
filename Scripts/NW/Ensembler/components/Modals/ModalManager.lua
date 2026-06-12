-- ModalManager.lua - Centralized modal management for the application

local ModalManager = {}

-- Popup queue for next frame
local popupQueue = {}

-- Modal render functions queue for this frame
local modalRenderFunctions = {}

---Queue a popup to open on the next frame
---@param popupId string
function ModalManager.openPopupOnNextFrame(popupId)
    table.insert(popupQueue, popupId)
end

---Open pending popups from queue
---@param ctx ImGui_Context
function ModalManager.openPendingPopups(ctx)
    for _, popupId in ipairs(popupQueue) do
        reaper.ImGui_OpenPopup(ctx, popupId)
    end
    popupQueue = {} -- Clear queue
end

---Queue a modal render function to be called this frame
---@param renderFunction fun(ctx: ImGui_Context): nil
function ModalManager.addModalRenderer(renderFunction)
    table.insert(modalRenderFunctions, renderFunction)
end

---Render all modals (call once per frame from main window)
---@param ctx ImGui_Context
function ModalManager.renderAllModals(ctx)
    -- Open any pending popups first
    ModalManager.openPendingPopups(ctx)
    
    -- Render all queued modal functions
    for _, renderFunction in ipairs(modalRenderFunctions) do
        renderFunction(ctx)
    end
end

return ModalManager