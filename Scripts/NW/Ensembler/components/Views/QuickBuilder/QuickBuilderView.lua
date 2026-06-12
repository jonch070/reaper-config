-- QuickBuilderView.lua - Quick Ensemble Builder Interface

require('types/types')

local QuickBuilderView = {}

-- Local state for UI
local selectedInstruments = {
    woods = {},
    brass = {},
    strings = {}
}

---@type table<string, QuickBuilderVoicingMode>
local voicingMode = {
    woods = "closed",
    brass = "closed",
    strings = "closed"
}

---@type table<string, QuickBuilderCombineMode>
local combineMode = {
    woods = "aligned",
    brass = "aligned",
    strings = "aligned"
}

---@type table<string, QuickBuilderLowMode>
local lowMode = {
    woods = "voiced",
    brass = "voiced",
    strings = "voiced"
}

---@type QuickBuilderStringSize
local stringSize = "chamber"

--------------------------------------------------------------------------------
-- Ensemble Generation
--------------------------------------------------------------------------------

---Regenerate the ensemble from current selections
local function regenerateEnsemble()
    QuickBuilder.generateEnsemble(selectedInstruments, voicingMode, combineMode, lowMode, stringSize)
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

---Render a toggle button that shows selected/unselected state
---@param ctx ImGui_Context
---@param label string
---@param isSelected boolean
---@param width number
---@return boolean clicked
local function renderToggleButton(ctx, label, isSelected, width)
    if isSelected then
        -- Selected: filled button with blue background
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4A7AC7FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x5A8AD7FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x3A6AB7FF)
    else
        -- Unselected: hollow button (transparent background, visible border)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)  -- Transparent
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x4A7AC733)  -- Slightly visible on hover
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x3A6AB766)  -- Slightly more visible on click
    end

    local clicked = reaper.ImGui_Button(ctx, label, width, 0)

    reaper.ImGui_PopStyleColor(ctx, 3)

    return clicked
end

---Render a row of instrument toggle buttons
---@param ctx ImGui_Context
---@param instruments table<string, string> Map of id -> display label
---@param section string Section name (woods/brass/strings)
---@param enabled boolean Whether buttons are enabled or disabled
local function renderInstrumentRow(ctx, instruments, section, enabled)
    local buttonWidth = 50
    local count = 0

    for id, label in pairs(instruments) do
        local isSelected = selectedInstruments[section][id] or false

        if not enabled then
            reaper.ImGui_BeginDisabled(ctx)
        end

        local clicked = renderToggleButton(ctx, label, isSelected, buttonWidth)

        if not enabled then
            reaper.ImGui_EndDisabled(ctx)
        end

        if clicked and enabled then
            selectedInstruments[section][id] = not isSelected
        end

        count = count + 1
        if count < #instruments then
            reaper.ImGui_SameLine(ctx)
        end
    end
end

---Render voicing mode buttons
---@param ctx ImGui_Context
---@param section string Section name (woods/brass/strings)
---@param enabled boolean Whether buttons are enabled or disabled
local function renderVoicingButtons(ctx, section, enabled)
    local modes

    if section == "strings" then
        modes = {
            {id = "unison", label = "Unison"},
            {id = "closed", label = "Closed"},
            {id = "open", label = "Open"}
        }
    else
        modes = {
            {id = "solo", label = "Solo"},
            {id = "unison", label = "Unison"},
            {id = "closed", label = "Closed"},
            {id = "open", label = "Open"}
        }
    end

    local currentMode = voicingMode[section]

    for i, mode in ipairs(modes) do
        local isSelected = (currentMode == mode.id)
        local buttonId = mode.label .. "##voicing_" .. section .. "_" .. mode.id

        if not enabled then
            reaper.ImGui_BeginDisabled(ctx)
        end

        local clicked = renderToggleButton(ctx, buttonId, isSelected, 70)

        if not enabled then
            reaper.ImGui_EndDisabled(ctx)
        end

        if clicked and enabled then
            voicingMode[section] = mode.id
            regenerateEnsemble()
        end

        if i < #modes then
            reaper.ImGui_SameLine(ctx)
        end
    end
end

---Check if any low instruments are selected in a section
---@param section string Section name (woods/brass/strings)
---@return boolean
local function hasLowInstrumentsSelected(section)
    local lowInstruments = {
        woods = {"bsn", "cbsn"},
        brass = {"tbn", "btbn", "tba"},
        strings = {"vc", "cb"}
    }

    if not lowInstruments[section] then
        return false
    end

    for _, instId in ipairs(lowInstruments[section]) do
        if selectedInstruments[section][instId] then
            return true
        end
    end

    return false
end

---Render low mode buttons
---@param ctx ImGui_Context
---@param section string Section name (woods/brass/strings)
---@param enabled boolean Whether buttons are enabled or disabled
local function renderLowButtons(ctx, section, enabled)
    local modes = {
        {id = "voiced", label = "Voiced"},
        {id = "unison_root", label = "Unison Root"},
        {id = "root_octaves", label = "Root Octaves"}
    }

    local currentMode = lowMode[section]

    for i, mode in ipairs(modes) do
        local isSelected = (currentMode == mode.id)
        local buttonId = mode.label .. "##low_" .. section .. "_" .. mode.id

        if not enabled then
            reaper.ImGui_BeginDisabled(ctx)
        end

        local clicked = renderToggleButton(ctx, buttonId, isSelected, 95)

        if not enabled then
            reaper.ImGui_EndDisabled(ctx)
        end

        if clicked and enabled then
            lowMode[section] = mode.id
            regenerateEnsemble()
        end

        if i < #modes then
            reaper.ImGui_SameLine(ctx)
        end
    end
end

---Render string size buttons
---@param ctx ImGui_Context
---@param enabled boolean Whether buttons are enabled or disabled
local function renderStringSizeButtons(ctx, enabled)
    local sizes = {
        {id = "solo", label = "Solo"},
        {id = "chamber", label = "Chamber"},
        {id = "symphony", label = "Symphony"}
    }

    for i, size in ipairs(sizes) do
        local isSelected = (stringSize == size.id)
        local buttonId = size.label .. "##stringsize_" .. size.id

        if not enabled then
            reaper.ImGui_BeginDisabled(ctx)
        end

        local clicked = renderToggleButton(ctx, buttonId, isSelected, 70)

        if not enabled then
            reaper.ImGui_EndDisabled(ctx)
        end

        if clicked and enabled then
            stringSize = size.id
            regenerateEnsemble()
        end

        if i < #sizes then
            reaper.ImGui_SameLine(ctx)
        end
    end
end

---Render combine mode buttons
---@param ctx ImGui_Context
---@param section string Section name (woods/brass/strings)
---@param enabled boolean Whether buttons are enabled or disabled
local function renderCombineButtons(ctx, section, enabled)
    local modes = {
        {id = "aligned", label = "Aligned"},
        {id = "stacked", label = "Stacked"},
        {id = "octaves", label = "Octaves"},
        {id = "interlocked", label = "Interlocked"},
        {id = "overlap", label = "Overlap"},
        {id = "enclosure", label = "Enclosed"}
    }

    local currentMode = combineMode[section]

    for i, mode in ipairs(modes) do
        local isSelected = (currentMode == mode.id)
        local buttonId = mode.label .. "##combine_" .. section .. "_" .. mode.id

        if not enabled then
            reaper.ImGui_BeginDisabled(ctx)
        end

        local clicked = renderToggleButton(ctx, buttonId, isSelected, 70)

        if not enabled then
            reaper.ImGui_EndDisabled(ctx)
        end

        if clicked and enabled then
            combineMode[section] = mode.id
            regenerateEnsemble()
        end

        if i < #modes then
            reaper.ImGui_SameLine(ctx)
        end
    end
end

--------------------------------------------------------------------------------
-- Main Render
--------------------------------------------------------------------------------

---Render the Quick Builder view
---@param ctx ImGui_Context
function QuickBuilderView.render(ctx)
    reaper.ImGui_Text(ctx, "Quick Ensemble Builder")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Woodwinds Section
    reaper.ImGui_Text(ctx, "Woods:")
    reaper.ImGui_SameLine(ctx)

    local woodsInstruments = {
        {id = "picc", label = "Picc"},
        {id = "fl", label = "Fl"},
        {id = "ob", label = "Ob"},
        {id = "eh", label = "EH"},
        {id = "cl", label = "Cl"},
        {id = "bcl", label = "BCl"},
        {id = "bsn", label = "Bsn"},
        {id = "cbsn", label = "C.Bsn"}
    }

    for i, inst in ipairs(woodsInstruments) do
        local isSelected = selectedInstruments.woods[inst.id] or false
        local buttonId = inst.label .. "##woods_" .. inst.id
        local clicked = renderToggleButton(ctx, buttonId, isSelected, 55)

        if clicked then
            selectedInstruments.woods[inst.id] = not isSelected
            regenerateEnsemble()
        end

        if i < #woodsInstruments then
            reaper.ImGui_SameLine(ctx)
        end
    end

    -- Voicing controls for woods
    reaper.ImGui_Text(ctx, "  Voicing:")
    reaper.ImGui_SameLine(ctx)
    renderVoicingButtons(ctx, "woods", true)

    -- Combine By controls for woods
    reaper.ImGui_Text(ctx, "Combine By:")
    reaper.ImGui_SameLine(ctx)
    renderCombineButtons(ctx, "woods", true)

    -- Low settings for woods
    reaper.ImGui_Text(ctx, " Low Woods:")
    reaper.ImGui_SameLine(ctx)
    renderLowButtons(ctx, "woods", true)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Brass Section
    reaper.ImGui_Text(ctx, "Brass:")
    reaper.ImGui_SameLine(ctx)

    local brassInstruments = {
        {id = "tpt", label = "Tpt"},
        {id = "hrn", label = "Hrn"},
        {id = "tbn", label = "Tbn"},
        {id = "btbn", label = "B.Tbn"},
        {id = "tba", label = "Tba"}
    }

    for i, inst in ipairs(brassInstruments) do
        local isSelected = selectedInstruments.brass[inst.id] or false
        local buttonId = inst.label .. "##brass_" .. inst.id
        local clicked = renderToggleButton(ctx, buttonId, isSelected, 55)

        if clicked then
            selectedInstruments.brass[inst.id] = not isSelected
            regenerateEnsemble()
        end

        if i < #brassInstruments then
            reaper.ImGui_SameLine(ctx)
        end
    end

    -- Voicing controls for brass
    reaper.ImGui_Text(ctx, "  Voicing:")
    reaper.ImGui_SameLine(ctx)
    renderVoicingButtons(ctx, "brass", true)

    -- Combine By controls for brass
    reaper.ImGui_Text(ctx, "Combine By:")
    reaper.ImGui_SameLine(ctx)
    renderCombineButtons(ctx, "brass", true)

    -- Low settings for brass
    reaper.ImGui_Text(ctx, " Low Brass:")
    reaper.ImGui_SameLine(ctx)
    renderLowButtons(ctx, "brass", true)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Strings Section
    reaper.ImGui_Text(ctx, "Strings:")
    reaper.ImGui_SameLine(ctx)

    local stringsInstruments = {
        {id = "vln1", label = "Vln1"},
        {id = "vln2", label = "Vln2"},
        {id = "vla", label = "Vla"},
        {id = "vc", label = "Vc"},
        {id = "cb", label = "Cb"}
    }

    for i, inst in ipairs(stringsInstruments) do
        local isSelected = selectedInstruments.strings[inst.id] or false
        local buttonId = inst.label .. "##strings_" .. inst.id
        local clicked = renderToggleButton(ctx, buttonId, isSelected, 55)

        if clicked then
            selectedInstruments.strings[inst.id] = not isSelected
            regenerateEnsemble()
        end

        if i < #stringsInstruments then
            reaper.ImGui_SameLine(ctx)
        end
    end

    -- String size selector
    reaper.ImGui_Text(ctx, "     Size:")
    reaper.ImGui_SameLine(ctx)
    renderStringSizeButtons(ctx, true)

    -- Voicing controls for strings
    reaper.ImGui_Text(ctx, "  Voicing:")
    reaper.ImGui_SameLine(ctx)
    renderVoicingButtons(ctx, "strings", true)

    -- Combine By controls for strings
    reaper.ImGui_Text(ctx, "Combine By:")
    reaper.ImGui_SameLine(ctx)
    renderCombineButtons(ctx, "strings", true)

    -- Low settings for strings
    reaper.ImGui_Text(ctx, "Low Strings:")
    reaper.ImGui_SameLine(ctx)
    renderLowButtons(ctx, "strings", true)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

end

return QuickBuilderView
