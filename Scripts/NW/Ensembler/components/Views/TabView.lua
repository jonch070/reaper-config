-- TabView.lua - Modular Tab Component

require('types/types')

local TabView = {}

-- Internal state for active tab
local activeTab = nil

---Set the active tab
---@param tabId string
function TabView.setActiveTab(tabId)
    activeTab = tabId
end

---Get the current active tab
---@return string|nil
function TabView.getActiveTab()
    return activeTab
end

---Render the tab view with headers and content
---@param ctx ImGui_Context
---@param tabConfigs TabConfig[]
function TabView.render(ctx, tabConfigs)
    if not tabConfigs or #tabConfigs == 0 then
        reaper.ImGui_Text(ctx, "No tabs configured")
        return
    end
    
    -- Initialize active tab to first tab if not set
    if not activeTab then
        activeTab = tabConfigs[1].id
    end
    
    -- Render tab headers
    TabView.renderTabHeaders(ctx, tabConfigs)
    
    reaper.ImGui_Separator(ctx)
    
    -- Render active tab content
    TabView.renderActiveTabContent(ctx, tabConfigs)
end

---Render the tab headers
---@param ctx ImGui_Context
---@param tabConfigs TabConfig[]
function TabView.renderTabHeaders(ctx, tabConfigs)
    for i, tab in ipairs(tabConfigs) do
        local isActive = (activeTab == tab.id)
        
        -- Style active tab differently
        if isActive then
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4A4A4AFF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x5A5A5AFF)
        end
        
        local clicked = reaper.ImGui_Button(ctx, tab.name, 100, 25)
        
        if isActive then
            reaper.ImGui_PopStyleColor(ctx, 2)
        end
        
        if clicked then
            activeTab = tab.id
        end
        
        -- Add spacing between tabs except for the last one
        if i < #tabConfigs then
            reaper.ImGui_SameLine(ctx)
        end
    end
end

---Render the content of the currently active tab
---@param ctx ImGui_Context
---@param tabConfigs TabConfig[]
function TabView.renderActiveTabContent(ctx, tabConfigs)
    -- Find the active tab and render its content
    for _, tab in ipairs(tabConfigs) do
        if tab.id == activeTab then
            if tab.renderFunction then
                tab.renderFunction(ctx)
            else
                -- Placeholder text if no render function provided
                reaper.ImGui_Text(ctx, "Content for " .. tab.name .. " tab")
                reaper.ImGui_Text(ctx, "Tab ID: " .. tab.id)
            end
            return
        end
    end
    
    -- Fallback if no active tab found
    reaper.ImGui_Text(ctx, "No active tab")
end

return TabView