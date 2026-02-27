-- UI module for Batch Create Cues
-- Handles ImGui settings dialog with ExtState persistence

local ImGui = reaper.ImGui_CreateContext and reaper or nil --[[@as ImGui]]
local CueCreator = require("CueCreator")

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local WINDOW_WIDTH = 550
local WINDOW_HEIGHT = 435
local EXTSTATE_SECTION = "NW_BatchCreateCues"
local REGION_INFO_UPDATE_INTERVAL = 0.7  -- seconds between region info refreshes

-- ============================================================================
-- STATE
-- ============================================================================

---@type ImGui_Context?
local ctx = nil

---@class BatchCueSettings
---@field templatePath string Path to template RPP file
---@field outputFolder string Output folder for cue projects
---@field spotNotesPath string Optional path to SpotNotes CSV
---@field cueStartBar number Bar number where MX IN lands
---@field defaultTempo number BPM for new cues
---@field endMarkerOffset number Seconds after MX OUT for =END marker
---@field markerTrackName string Name of track for MX IN/OUT items in cue project
---@field cuesTrackName string Name of track in video project for subproject insertion
---@field altCuesTrackName string Optional alternate track for overlapping cues
---@field filenameSuffix string Version tag inserted after cue ID (e.g., "_v1a" → ALI-1m01_v1a - Title.rpp)

---@type BatchCueSettings
local settings = {
    templatePath = "",
    outputFolder = "",
    spotNotesPath = "",
    cueStartBar = 5,
    defaultTempo = 90,
    endMarkerOffset = 10,
    markerTrackName = "Picture Markers",
    cuesTrackName = "Cues",
    altCuesTrackName = "",
    filenameSuffix = "_v1a",
}

local uiState = {
    shouldClose = false,
    initialized = false,
    regionCount = 0,
    existingCueCount = 0,
    missingCount = 0,
    isProcessing = false,
    showingProgress = false,  -- True while showing progress/results view
    statusMessage = "",
    progressCurrent = 0,
    progressTotal = 0,
    currentCueId = "",
    cancelRequested = false,
    progressLog = {},  -- Array of {cueId, success, message}
    createdFiles = {}, -- Array of {filePath, mediaItem?, mediaTrack?} for potential cleanup
}

-- Region selection state
local regionData = {
    classified = {},   -- ClassifiedRegion[]
    selected = {},     -- boolean[] parallel to classified
}

-- Callbacks and external refs
local videoProj = nil
local videoProjectPath = nil
local onSubmitCallback = nil
local getRegionsCallback = nil
local classifyRegionsCallback = nil

-- ============================================================================
-- EXTSTATE PERSISTENCE
-- ============================================================================

---Loads settings from ExtState
local function loadSettings()
    local function getString(key, default)
        local hasVal, val = reaper.GetProjExtState(videoProj, EXTSTATE_SECTION, key)
        if hasVal > 0 and val ~= "" then
            return val
        end
        -- Fallback to global ExtState
        val = reaper.GetExtState(EXTSTATE_SECTION, key)
        return val ~= "" and val or default
    end

    local function getProjectString(key, default)
        local hasVal, val = reaper.GetProjExtState(videoProj, EXTSTATE_SECTION, key)
        if hasVal > 0 and val ~= "" then
            return val
        end
        return default
    end

    local function getNumber(key, default)
        local val = getString(key, tostring(default))
        return tonumber(val) or default
    end

    settings.templatePath = getString("templatePath", "")
    settings.outputFolder = getString("outputFolder", "")
    -- SpotNotes path is project-specific - don't load from global ExtState
    settings.spotNotesPath = getProjectString("spotNotesPath", "")
    settings.cueStartBar = getNumber("cueStartBar", 5)
    settings.defaultTempo = getNumber("defaultTempo", 90)
    settings.endMarkerOffset = getNumber("endMarkerOffset", 10)
    settings.markerTrackName = getString("markerTrackName", "Picture Markers")
    settings.cuesTrackName = getString("cuesTrackName", "Cues")
    settings.altCuesTrackName = getString("altCuesTrackName", "")
    settings.filenameSuffix = getString("filenameSuffix", "_v1a")
end

---Saves settings to ExtState (both project and global, except spotNotesPath)
local function saveSettings()
    local function setString(key, val)
        reaper.SetProjExtState(videoProj, EXTSTATE_SECTION, key, val)
        reaper.SetExtState(EXTSTATE_SECTION, key, val, true)
    end

    local function setProjectOnly(key, val)
        reaper.SetProjExtState(videoProj, EXTSTATE_SECTION, key, val)
    end

    setString("templatePath", settings.templatePath)
    setString("outputFolder", settings.outputFolder)
    -- SpotNotes path is project-specific - don't persist to global ExtState
    setProjectOnly("spotNotesPath", settings.spotNotesPath)
    setString("cueStartBar", tostring(settings.cueStartBar))
    setString("defaultTempo", tostring(settings.defaultTempo))
    setString("endMarkerOffset", tostring(settings.endMarkerOffset))
    setString("markerTrackName", settings.markerTrackName)
    setString("cuesTrackName", settings.cuesTrackName)
    setString("altCuesTrackName", settings.altCuesTrackName)
    setString("filenameSuffix", settings.filenameSuffix)
end

-- ============================================================================
-- FILE/FOLDER PICKERS
-- ============================================================================

---Opens a file picker dialog
---@param title string Dialog title
---@param filter string File filter (e.g., "ReaperProject (*.rpp)\0*.rpp\0")
---@param initialPath string Initial path
---@return string? path Selected path, or nil if cancelled
local function openFilePicker(title, filter, initialPath)
    local initialDir = initialPath:match("^(.+)[/\\]") or ""
    local initialFile = initialPath:match("[/\\]([^/\\]+)$") or ""

    local retval, selectedPath = reaper.GetUserFileNameForRead(initialDir .. "/" .. initialFile, title, filter)
    if retval then
        return selectedPath
    end
    return nil
end

---Opens a folder picker dialog (requires js_ReaScriptAPI)
---@param title string Dialog title
---@param initialPath string Initial path
---@return string? path Selected path, or nil if cancelled or API unavailable
local function openFolderPicker(title, initialPath)
    if reaper.JS_Dialog_BrowseForFolder then
        local retval, selectedPath = reaper.JS_Dialog_BrowseForFolder(title, initialPath)
        if retval == 1 then
            return selectedPath
        end
    else
        -- Fallback: use GetUserFileNameForRead and extract directory
        reaper.ShowMessageBox(
            "Folder picker requires js_ReaScriptAPI extension.\n\n" ..
            "Please install it from ReaPack or manually enter the path.",
            "Missing Extension", 0
        )
    end
    return nil
end

-- ============================================================================
-- TRACK HELPERS
-- ============================================================================

---Returns a filename example using the first region, or a generic fallback
---@return string example e.g. "ALI-1m01_v1a - Love Theme.rpp"
local function getExampleFilename()
    if #regionData.classified > 0 then
        return CueCreator.createCueFileName(regionData.classified[1].region.name, settings.filenameSuffix)
    end
    return "CUEID" .. (settings.filenameSuffix or "") .. " - Title.rpp"
end

---Finds a track by exact name in the video project
---@param trackName string Track name to find
---@return MediaTrack? track The track if found
local function findTrackByExactName(trackName)
    return NW.ReaperTracksAndFolders.findTrackByName(videoProj, trackName)
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

---Validates settings and returns error message if invalid
---@return string? error Error message if validation failed
local function validateSettings()
    if settings.templatePath == "" then
        return "Template RPP path is required"
    end

    -- Check template file exists
    local f = io.open(settings.templatePath, "r")
    if not f then
        return "Template file not found: " .. settings.templatePath
    end
    f:close()

    if settings.outputFolder == "" then
        return "Output folder is required"
    end

    if settings.cueStartBar < 1 then
        return "Cue start bar must be at least 1"
    end

    if settings.defaultTempo < 20 or settings.defaultTempo > 400 then
        return "Tempo must be between 20 and 400 BPM"
    end

    if settings.endMarkerOffset < 0 then
        return "End marker offset cannot be negative"
    end

    if uiState.regionCount == 0 then
        return "No regions found in project"
    end

    -- Validate cues track exists (required)
    if settings.cuesTrackName == "" then
        return "Cues track name is required"
    end
    if not findTrackByExactName(settings.cuesTrackName) then
        return "Could not find track named \"" .. settings.cuesTrackName .. "\" in project"
    end

    -- Validate alt cues track exists (if specified)
    if settings.altCuesTrackName ~= "" then
        if not findTrackByExactName(settings.altCuesTrackName) then
            return "Could not find alternate track named \"" .. settings.altCuesTrackName .. "\" in project"
        end
    end

    -- Frame rate settings are read from the saved RPP file on disk
    if reaper.IsProjectDirty(videoProj) == 1 then
        return "Please save the video project first (Cmd+S). Frame rate and timecode settings are read from the saved file."
    end

    return nil
end

-- ============================================================================
-- UI COMPONENTS
-- ============================================================================
---@diagnostic disable: param-type-mismatch

---Draws a path input with browse button
---@param label string Field label
---@param id string ImGui ID
---@param value string Current value
---@param browseCallback function Called when browse button clicked
---@return string newValue Updated value
local function drawPathInput(label, id, value, browseCallback)
    ImGui.ImGui_Text(ctx, label)

    ImGui.ImGui_SetNextItemWidth(ctx, -70)
    local rv, newValue = ImGui.ImGui_InputText(ctx, "##" .. id, value)

    ImGui.ImGui_SameLine(ctx)
    if ImGui.ImGui_Button(ctx, "Browse##" .. id, 60, 0) then
        local selected = browseCallback()
        if selected then
            newValue = selected
        end
    end

    return newValue
end

---Counts how many regions are currently selected
---@return number selectedCount
local function getSelectedCount()
    local count = 0
    for _, sel in ipairs(regionData.selected) do
        if sel then count = count + 1 end
    end
    return count
end

---Counts how many selected regions have existing cues
---@return number existingSelectedCount
local function getExistingSelectedCount()
    local count = 0
    for i, cr in ipairs(regionData.classified) do
        if regionData.selected[i] and cr.hasExistingCue then
            count = count + 1
        end
    end
    return count
end

---Draws the region picker modal popup
local function drawRegionPicker()
    ImGui.ImGui_SetNextWindowSize(ctx, 450, 500, ImGui.ImGui_Cond_Appearing())
    local visible, open = ImGui.ImGui_BeginPopupModal(ctx, "Select Cues", true)
    if visible then
        if not open then
            ImGui.ImGui_CloseCurrentPopup(ctx)
        end

        -- Helper buttons
        if ImGui.ImGui_Button(ctx, "Select All") then
            for i = 1, #regionData.selected do
                regionData.selected[i] = true
            end
        end
        ImGui.ImGui_SameLine(ctx)
        if ImGui.ImGui_Button(ctx, "Deselect All") then
            for i = 1, #regionData.selected do
                regionData.selected[i] = false
            end
        end
        ImGui.ImGui_SameLine(ctx)
        if ImGui.ImGui_Button(ctx, "New Only") then
            for i, cr in ipairs(regionData.classified) do
                regionData.selected[i] = not cr.hasExistingCue
            end
        end

        ImGui.ImGui_Separator(ctx)
        ImGui.ImGui_Spacing(ctx)

        -- Scrollable region list
        local doneButtonHeight = 32 + 8
        if ImGui.ImGui_BeginChild(ctx, "##region_list", -1, -doneButtonHeight, ImGui.ImGui_ChildFlags_Borders()) then
            for i, cr in ipairs(regionData.classified) do
                local rv, checked = ImGui.ImGui_Checkbox(ctx, cr.region.name .. "##region" .. i, regionData.selected[i] or false)
                if rv then
                    regionData.selected[i] = checked
                end
                if cr.hasExistingCue then
                    ImGui.ImGui_SameLine(ctx)
                    ImGui.ImGui_TextColored(ctx, 0xFFAA44FF, "(exists)")
                end
            end
            ImGui.ImGui_EndChild(ctx)
        end

        ImGui.ImGui_Spacing(ctx)

        if ImGui.ImGui_Button(ctx, "Done", -1, 32) then
            ImGui.ImGui_CloseCurrentPopup(ctx)
        end

        ImGui.ImGui_EndPopup(ctx)
    end
end

---Draws the settings form (when not processing)
local function drawSettingsForm()
    local rv

    -- Template RPP
    settings.templatePath = drawPathInput(
        "Template RPP:",
        "template",
        settings.templatePath,
        function()
            -- Default to REAPER's ProjectTemplates folder if no path set
            local initialPath = settings.templatePath
            if initialPath == "" then
                local resourcePath = reaper.GetResourcePath()
                local sep = resourcePath:match("[/\\]") or "/"
                initialPath = resourcePath .. sep .. "ProjectTemplates" .. sep
            end
            return openFilePicker("Select Template RPP", "*.rpp", initialPath)
        end
    )

    ImGui.ImGui_Spacing(ctx)

    -- Output Folder
    settings.outputFolder = drawPathInput(
        "Output Folder:",
        "output",
        settings.outputFolder,
        function()
            return openFolderPicker("Select Output Folder", settings.outputFolder)
        end
    )

    ImGui.ImGui_Spacing(ctx)

    -- SpotNotes CSV (optional)
    settings.spotNotesPath = drawPathInput(
        "Include spotting notes from SpotNotes CSV:",
        "spotnotes",
        settings.spotNotesPath,
        function()
            return openFilePicker("Select SpotNotes CSV", "*.csv", settings.spotNotesPath)
        end
    )

    ImGui.ImGui_Spacing(ctx)
    ImGui.ImGui_Separator(ctx)
    ImGui.ImGui_Spacing(ctx)

    -- Cue Start Bar
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "Cue Start Bar:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 50)
    local startBarStr
    rv, startBarStr = ImGui.ImGui_InputText(ctx, "##startbar", tostring(settings.cueStartBar))
    settings.cueStartBar = tonumber(startBarStr) or settings.cueStartBar

    ImGui.ImGui_Spacing(ctx)

    -- Default Tempo
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "Default Tempo:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 50)
    local tempoStr
    rv, tempoStr = ImGui.ImGui_InputText(ctx, "##tempo", tostring(settings.defaultTempo))
    settings.defaultTempo = tonumber(tempoStr) or settings.defaultTempo

    ImGui.ImGui_Spacing(ctx)

    -- End marker offset
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "=END offset from MX OUT:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 50)
    local endOffsetStr
    rv, endOffsetStr = ImGui.ImGui_InputText(ctx, "##endoffset", tostring(settings.endMarkerOffset))
    settings.endMarkerOffset = tonumber(endOffsetStr) or settings.endMarkerOffset
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "seconds")

    ImGui.ImGui_Spacing(ctx)

    -- Version tag
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "Version Tag:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 80)
    rv, settings.filenameSuffix = ImGui.ImGui_InputText(ctx, "##filesuffix", settings.filenameSuffix)
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_TextDisabled(ctx, getExampleFilename())

    ImGui.ImGui_Spacing(ctx)

    -- Marker track name (in cue project template)
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "Marker Track Name:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 200)
    rv, settings.markerTrackName = ImGui.ImGui_InputText(ctx, "##markertrack", settings.markerTrackName)

    ImGui.ImGui_Spacing(ctx)
    ImGui.ImGui_Separator(ctx)
    ImGui.ImGui_Spacing(ctx)

    -- Cues track name (in video project)
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "Cues Track:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 200)
    rv, settings.cuesTrackName = ImGui.ImGui_InputText(ctx, "##cuestrack", settings.cuesTrackName)

    ImGui.ImGui_Spacing(ctx)

    -- Alt cues track name (optional, for overlapping cues)
    ImGui.ImGui_AlignTextToFramePadding(ctx)
    ImGui.ImGui_Text(ctx, "Alt Cues Track:")
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_SetNextItemWidth(ctx, 200)
    rv, settings.altCuesTrackName = ImGui.ImGui_InputText(ctx, "##altcuestrack", settings.altCuesTrackName)
    ImGui.ImGui_SameLine(ctx)
    ImGui.ImGui_TextDisabled(ctx, "(optional, for overlaps)")

    ImGui.ImGui_Spacing(ctx)
    ImGui.ImGui_Separator(ctx)
    ImGui.ImGui_Spacing(ctx)

    -- Cue selection
    local selectedCount = getSelectedCount()
    local existingSelectedCount = getExistingSelectedCount()

    if #regionData.classified == 0 then
        ImGui.ImGui_Text(ctx, "No regions found in project")
    else
        local selText = string.format("%d of %d cues selected", selectedCount, #regionData.classified)
        if existingSelectedCount > 0 then
            selText = selText .. string.format(" (%d will be re-created)", existingSelectedCount)
        end
        ImGui.ImGui_AlignTextToFramePadding(ctx)
        ImGui.ImGui_Text(ctx, selText)
        ImGui.ImGui_SameLine(ctx)
        if ImGui.ImGui_Button(ctx, "Select Cues...") then
            ImGui.ImGui_OpenPopup(ctx, "Select Cues")
        end
    end

    drawRegionPicker()

    ImGui.ImGui_Spacing(ctx)

    -- Status message (for errors, etc)
    if uiState.statusMessage ~= "" then
        ImGui.ImGui_TextColored(ctx, 0xFFFF88FF, uiState.statusMessage)
        ImGui.ImGui_Spacing(ctx)
    end

    -- Create button (disabled when nothing selected)
    local nothingToProcess = selectedCount == 0
    if nothingToProcess then
        ImGui.ImGui_BeginDisabled(ctx)
    end
    if ImGui.ImGui_Button(ctx, "Create Cues", -1, 32) then
        local err = validateSettings()
        if err then
            reaper.ShowMessageBox(err, "Batch Create Cues - Error", 0)
        else
            -- Confirm if re-creating existing cues
            local proceed = true
            if existingSelectedCount > 0 then
                local response = reaper.ShowMessageBox(
                    string.format(
                        "%d of the selected cue(s) already have projects.\n\n" ..
                        "Re-creating will rename existing files to _old and generate new ones.\n\n" ..
                        "Continue?",
                        existingSelectedCount
                    ),
                    "Confirm Re-creation",
                    4  -- Yes/No
                )
                if response ~= 6 then  -- Not Yes
                    proceed = false
                end
            end

            if proceed then
                -- Extract selected regions
                local regionsToProcess = {}
                for i, cr in ipairs(regionData.classified) do
                    if regionData.selected[i] then
                        table.insert(regionsToProcess, cr.region)
                    end
                end

                saveSettings()
                if onSubmitCallback then
                    uiState.isProcessing = true
                    uiState.showingProgress = true
                    uiState.progressCurrent = 0
                    uiState.progressTotal = #regionsToProcess
                    uiState.statusMessage = "Starting..."
                    onSubmitCallback(settings, regionsToProcess)
                end
            end
        end
    end
    if nothingToProcess then
        ImGui.ImGui_EndDisabled(ctx)
    end
end

---Draws the progress view (when processing or showing results)
local function drawProgressView()
    -- Header showing current cue or completion status
    if uiState.isProcessing then
        if uiState.currentCueId ~= "" then
            ImGui.ImGui_Text(ctx, "Creating " .. uiState.currentCueId .. "...")
        else
            ImGui.ImGui_Text(ctx, "Starting...")
        end
    else
        ImGui.ImGui_Text(ctx, "Complete")
    end

    ImGui.ImGui_Spacing(ctx)

    -- Progress bar
    if uiState.progressTotal > 0 then
        local progress = uiState.progressCurrent / uiState.progressTotal
        ImGui.ImGui_ProgressBar(ctx, progress, -1, 0,
            string.format("%d / %d", uiState.progressCurrent, uiState.progressTotal))
        ImGui.ImGui_Spacing(ctx)
    end

    ImGui.ImGui_Separator(ctx)
    ImGui.ImGui_Spacing(ctx)

    -- Progress log (scrollable) - reserve space for button at bottom
    ImGui.ImGui_Text(ctx, "Progress:")
    local buttonHeight = 32 + 8  -- button height + spacing
    if ImGui.ImGui_BeginChild(ctx, "##progress_log", -1, -buttonHeight, ImGui.ImGui_ChildFlags_Borders()) then
        for _, entry in ipairs(uiState.progressLog) do
            if entry.success then
                local action = entry.isRecreation and "re-created" or "created"
                ImGui.ImGui_TextColored(ctx, 0x88FF88FF, entry.cueId .. " - " .. action)
            else
                ImGui.ImGui_TextColored(ctx, 0xFF8888FF, entry.cueId .. " - " .. (entry.message or "failed"))
            end
        end

        -- Auto-scroll to bottom when new entries are added
        if ImGui.ImGui_GetScrollY(ctx) >= ImGui.ImGui_GetScrollMaxY(ctx) - 20 then
            ImGui.ImGui_SetScrollHereY(ctx, 1.0)
        end

        ImGui.ImGui_EndChild(ctx)
    end

    ImGui.ImGui_Spacing(ctx)

    -- Cancel button (during processing) or Close button (after completion)
    if uiState.isProcessing then
        if uiState.cancelRequested then
            ImGui.ImGui_BeginDisabled(ctx)
            ImGui.ImGui_Button(ctx, "Cancelling...", -1, 32)
            ImGui.ImGui_EndDisabled(ctx)
        else
            if ImGui.ImGui_Button(ctx, "Cancel", -1, 32) then
                uiState.cancelRequested = true
            end
        end
    else
        if ImGui.ImGui_Button(ctx, "Close", -1, 32) then
            uiState.shouldClose = true
        end
    end
end

---Draws the main UI
local function drawUI()
    if uiState.showingProgress then
        drawProgressView()
    else
        drawSettingsForm()
    end
end

---Updates region classification and selection state
local function updateRegionData()
    if not getRegionsCallback then return end

    local regions = getRegionsCallback()

    if classifyRegionsCallback and settings.cuesTrackName ~= "" then
        local classified = classifyRegionsCallback(regions, settings.cuesTrackName, settings.altCuesTrackName, settings.filenameSuffix)

        -- If region count changed, reinitialize selections (default: select missing only)
        if #classified ~= #regionData.classified then
            regionData.classified = classified
            regionData.selected = {}
            for i, cr in ipairs(classified) do
                regionData.selected[i] = not cr.hasExistingCue
            end
        else
            -- Preserve user selections, just update classification status
            regionData.classified = classified
        end

        -- Update counts for validation and display
        local existingCount = 0
        for _, cr in ipairs(classified) do
            if cr.hasExistingCue then
                existingCount = existingCount + 1
            end
        end
        uiState.regionCount = #classified
        uiState.existingCueCount = existingCount
        uiState.missingCount = #classified - existingCount
    else
        regionData.classified = {}
        regionData.selected = {}
        uiState.regionCount = #regions
        uiState.existingCueCount = 0
        uiState.missingCount = #regions
    end
end

---Main UI loop
local function loop()
    -- Initialize on first run
    if not uiState.initialized then
        loadSettings()

        -- Set default output folder if not set
        if settings.outputFolder == "" and videoProjectPath then
            -- Default to parent of video project folder
            local videoProjDir = videoProjectPath:match("^(.+)[/\\][^/\\]+$")
            if videoProjDir then
                settings.outputFolder = videoProjDir:match("^(.+)[/\\][^/\\]+$") or videoProjDir
            end
        end

        updateRegionData()
        uiState.initialized = true
    end

    -- Check if we should close
    if uiState.shouldClose then
        return
    end

    -- Update region counts periodically (in case user adds/removes regions)
    local now = reaper.time_precise()
    if not uiState.lastRegionUpdate or (now - uiState.lastRegionUpdate) >= REGION_INFO_UPDATE_INTERVAL then
        updateRegionData()
        uiState.lastRegionUpdate = now
    end

    -- Set window size
    ImGui.ImGui_SetNextWindowSize(ctx, WINDOW_WIDTH, WINDOW_HEIGHT, ImGui.ImGui_Cond_FirstUseEver())

    local visible, open = ImGui.ImGui_Begin(ctx, "Batch Create Cues from Regions", true)

    if visible then
        drawUI()
        ImGui.ImGui_End(ctx)
    end

    if open then
        reaper.defer(loop)
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local UI = {}

---Runs the Batch Create Cues UI
---@param vidProj ReaProject The video project
---@param vidProjectPath string Path to the video project
---@param options table Options table
---   - onSubmit: function(settings, regionsToProcess) Called when user clicks Create
---   - getRegions: function() Returns all regions
---   - classifyRegions: function(regions, cuesTrackName, altCuesTrackName, filenameSuffix) Returns ClassifiedRegion[]
function UI.run(vidProj, vidProjectPath, options)
    videoProj = vidProj
    videoProjectPath = vidProjectPath
    onSubmitCallback = options.onSubmit
    getRegionsCallback = options.getRegions
    classifyRegionsCallback = options.classifyRegions

    -- Reset UI state
    uiState.shouldClose = false
    uiState.initialized = false
    uiState.isProcessing = false
    uiState.showingProgress = false
    uiState.statusMessage = ""
    uiState.progressCurrent = 0
    uiState.progressTotal = 0
    uiState.currentCueId = ""
    uiState.cancelRequested = false
    uiState.progressLog = {}
    uiState.createdFiles = {}

    -- Reset region selection state
    regionData.classified = {}
    regionData.selected = {}

    -- Create ImGui context
    ctx = ImGui.ImGui_CreateContext("Batch Create Cues")

    -- Start the UI loop
    reaper.defer(loop)
end

---Closes the UI
function UI.close()
    uiState.shouldClose = true
end

---Updates status message and optionally progress
---@param message string Status message to display
---@param current number? Current progress (optional)
---@param total number? Total items (optional)
function UI.setStatus(message, current, total)
    uiState.statusMessage = message
    if current then
        uiState.progressCurrent = current
    end
    if total then
        uiState.progressTotal = total
    end
end

---Updates progress
---@param current number Current progress
---@param total number Total items
function UI.setProgress(current, total)
    uiState.progressCurrent = current
    uiState.progressTotal = total
end

---Marks processing as complete (keeps progress visible for review)
function UI.processingComplete()
    uiState.isProcessing = false
    uiState.currentCueId = ""
end

---Sets the current cue being processed
---@param cueId string The cue ID being created
function UI.setCurrentCue(cueId)
    uiState.currentCueId = cueId
end

---Adds an entry to the progress log
---@param cueId string The cue ID
---@param success boolean Whether creation succeeded
---@param message string? Optional message (for failures)
---@param isRecreation boolean? Whether this was a re-creation of an existing cue
function UI.addLogEntry(cueId, success, message, isRecreation)
    table.insert(uiState.progressLog, {
        cueId = cueId,
        success = success,
        message = message,
        isRecreation = isRecreation,
    })
end

---Tracks a created cue for potential cleanup on cancel
---@param filePath string Path to the created file
---@param mediaItem MediaItem? The inserted subproject item
---@param mediaTrack MediaTrack? The track the item was inserted on
function UI.addCreatedFile(filePath, mediaItem, mediaTrack)
    table.insert(uiState.createdFiles, {
        filePath = filePath,
        mediaItem = mediaItem,
        mediaTrack = mediaTrack,
    })
end

---Checks if cancellation was requested
---@return boolean cancelled True if user clicked cancel
function UI.isCancelRequested()
    return uiState.cancelRequested
end

---Gets list of created cues (for cleanup on cancel)
---@return table[] createdCues Array of {filePath: string, mediaItem?: MediaItem, mediaTrack?: MediaTrack}
function UI.getCreatedFiles()
    return uiState.createdFiles
end

---Gets current settings
---@return BatchCueSettings
function UI.getSettings()
    return settings
end

return UI
