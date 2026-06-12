-- QuickBuilder.lua - Quick Ensemble Builder Logic

require('types/types')

QuickBuilder = {}

-- Configuration
local instrumentConfig = nil

-- Orchestral order for Stacked and Interlocked modes (high to low)
local ORCHESTRAL_ORDER = {
    -- Woodwinds
    picc = 1,
    fl = 2,
    ob = 3,
    eh = 4,
    cl = 5,
    bcl = 6,
    bsn = 7,
    cbsn = 8,
    -- Brass
    tpt = 9,
    hrn = 10,
    tbn = 11,
    btbn = 12,
    tba = 13,
    -- Strings
    vln1 = 14,
    vln2 = 15,
    vla = 16,
    vc = 17,
    cb = 18
}

--------------------------------------------------------------------------------
-- Configuration Loading
--------------------------------------------------------------------------------

---Load instrument configuration from Lua file (lazy loading)
---@return boolean success
local function ensureConfigLoaded()
    if instrumentConfig then
        return true
    end

    local configPath = State.config.CONFIG_PATH .. "quick_builder_instruments.lua"

    local success, config = pcall(dofile, configPath)
    if not success then
        Debug.error("QuickBuilder: Failed to load config file: " .. configPath .. " - " .. tostring(config), Debug.FEATURE.QUICK_BUILDER)
        return false
    end

    if not config or type(config) ~= "table" then
        Debug.error("QuickBuilder: Invalid config data", Debug.FEATURE.QUICK_BUILDER)
        return false
    end

    instrumentConfig = config
    Debug.log("QuickBuilder: Config loaded successfully", Debug.FEATURE.QUICK_BUILDER)
    return true
end

--------------------------------------------------------------------------------
-- Ensemble Generation
--------------------------------------------------------------------------------

---Generate an ensemble from Quick Builder selections
---@param selectedInstruments table<string, table<string, boolean>> Selected instrument IDs by section
---@param voicingModes table<string, QuickBuilderVoicingMode> Voicing mode per section
---@param combineModes table<string, QuickBuilderCombineMode> Combine mode per section
---@param lowModes table<string, QuickBuilderLowMode> Low instrument mode per section
---@param stringSize QuickBuilderStringSize Size of string ensemble (solo/chamber/symphony)
function QuickBuilder.generateEnsemble(selectedInstruments, voicingModes, combineModes, lowModes, stringSize)
    -- Ensure config is loaded
    if not ensureConfigLoaded() then
        Debug.error("QuickBuilder: Failed to load config", Debug.FEATURE.QUICK_BUILDER)
        return
    end

    -- Determine voice count based on voicing modes
    -- Solo/Unison = 1 voice, Closed/Open = 3 voices
    local needsThreeVoices = false
    for section, mode in pairs(voicingModes) do
        if mode == "closed" or mode == "open" then
            needsThreeVoices = true
            break
        end
    end

    local targetVoiceCount = needsThreeVoices and 3 or 1

    -- Reset ensemble to clean state
    State.ensemble.initializeDefaultEnsemble()
    -- TODO: Voice count not changing properly when switching between Solo/Unison and Closed
    -- Logic appears correct but UI doesn't update - investigate redistributeVoices behavior
    if State.ensemble.voiceCount ~= targetVoiceCount then
        State.ensemble.redistributeVoices(targetVoiceCount)
    end

    -- Remove the default section created by initializeDefaultEnsemble
    -- We'll create our own sections based on selections
    local allSections = State.ensemble.getActiveSectionsSorted()
    for _, section in ipairs(allSections) do
        State.ensemble.deleteSection(section.sectionId)
    end

    -- Generate each section
    for sectionKey, selectedIds in pairs(selectedInstruments) do
        if instrumentConfig and instrumentConfig[sectionKey] then
            local sectionConfig = instrumentConfig[sectionKey]
            local voicingMode = voicingModes[sectionKey] or "closed"
            local combineMode = combineModes[sectionKey] or "aligned"
            local lowMode = lowModes[sectionKey] or "voiced"
            QuickBuilder.generateSection(sectionKey, sectionConfig, selectedIds, voicingMode, combineMode, targetVoiceCount, lowMode, stringSize)
        end
    end

    Debug.log("QuickBuilder: Ensemble generation complete", Debug.FEATURE.QUICK_BUILDER)
end

-- Low instrument configuration by section
local LOW_INSTRUMENTS = {
    woods = {bsn = true, cbsn = true},
    brass = {tbn = true, btbn = true, tba = true},
    strings = {vc = true, cb = true}
}

---Generate a section of the ensemble
---@param sectionKey string Section key (woods/brass/strings)
---@param sectionConfig table Configuration for this section
---@param selectedIds table<string, boolean> Map of instrument IDs to selection state
---@param voicingMode QuickBuilderVoicingMode Voicing mode
---@param combineMode QuickBuilderCombineMode Combine mode
---@param voiceCount number Number of voices in the ensemble
---@param lowMode QuickBuilderLowMode Low instrument mode
---@param stringSize QuickBuilderStringSize Size of string ensemble (solo/chamber/symphony)
function QuickBuilder.generateSection(sectionKey, sectionConfig, selectedIds, voicingMode, combineMode, voiceCount, lowMode, stringSize)
    -- Collect all instruments, separating low instruments from regular ones if needed
    ---@type table<string, Instrument[]>
    local instrumentsByFamily = {}
    ---@type table<string, Instrument[]>
    local lowInstrumentsByFamily = {}

    local lowInstrumentsConfig = LOW_INSTRUMENTS[sectionKey] or {}
    local shouldSeparateLowInstruments = (lowMode ~= "voiced")

    for instId, isSelected in pairs(selectedIds) do
        if isSelected and sectionConfig[instId] then
            local instDef = sectionConfig[instId]

            -- Get track names based on section type
            local trackNames
            if sectionKey == "strings" and type(instDef.tracks) == "table" and instDef.tracks[stringSize] then
                -- Strings section with size-specific tracks
                trackNames = instDef.tracks[stringSize]
            elseif sectionKey == "strings" and type(instDef.tracks) == "table" then
                -- Strings but this instrument doesn't have tracks for this size (e.g., solo vln2)
                Debug.log("QuickBuilder: No tracks for " .. instId .. " in " .. stringSize .. " mode, skipping", Debug.FEATURE.QUICK_BUILDER)
                trackNames = nil
            else
                -- Other sections (woods/brass) or legacy format
                trackNames = instDef.tracks
            end

            if trackNames then
                local isLowInstrument = lowInstrumentsConfig[instId] or false

                -- Choose the appropriate table based on whether this is a low instrument and mode
                local targetTable
                if isLowInstrument and shouldSeparateLowInstruments then
                    targetTable = lowInstrumentsByFamily
                else
                    targetTable = instrumentsByFamily
                end
                targetTable[instId] = {}

                for _, trackName in ipairs(trackNames) do
                    local trackData = ReaperTracks.findByName(trackName)
                    if trackData then
                        ---@type Instrument
                        local instrument = State.ensemble.createInstrumentFromTrack(trackData.track)
                        table.insert(targetTable[instId], instrument)
                    else
                        Debug.warn("QuickBuilder: Track not found: " .. trackName, Debug.FEATURE.QUICK_BUILDER)
                    end
                end
            end
        end
    end

    -- Count total instruments to see if we should create a section
    local totalInstruments = 0
    for _, familyInstruments in pairs(instrumentsByFamily) do
        totalInstruments = totalInstruments + #familyInstruments
    end
    for _, familyInstruments in pairs(lowInstrumentsByFamily) do
        totalInstruments = totalInstruments + #familyInstruments
    end

    if totalInstruments == 0 then
        return
    end

    -- Create the section with capitalized name
    local sectionName = sectionKey:sub(1,1):upper() .. sectionKey:sub(2)
    if sectionName == "Woods" then sectionName = "Woodwinds" end
    local section = State.ensemble.createSection(sectionName)

    -- Apply voicing algorithm for regular instruments
    if voicingMode == "solo" then
        QuickBuilder.applySoloVoicing(instrumentsByFamily, section.sectionId, combineMode)
    elseif voicingMode == "unison" then
        QuickBuilder.applyUnisonVoicing(instrumentsByFamily, section.sectionId, combineMode, sectionKey)
    elseif voicingMode == "closed" then
        QuickBuilder.applyClosedVoicing(instrumentsByFamily, section.sectionId, voiceCount, combineMode)
    elseif voicingMode == "open" then
        -- TODO: Implement open voicing
        Debug.log("QuickBuilder: Open voicing not yet implemented", Debug.FEATURE.QUICK_BUILDER)
    end

    -- Apply low instrument handling
    if next(lowInstrumentsByFamily) ~= nil then
        QuickBuilder.applyLowInstruments(lowInstrumentsByFamily, section.sectionId, lowMode)
    end
end

--------------------------------------------------------------------------------
-- Voicing Algorithms
--------------------------------------------------------------------------------

---Apply solo voicing (first instrument from each family at v1o0)
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param combineMode QuickBuilderCombineMode Combine mode
function QuickBuilder.applySoloVoicing(instrumentsByFamily, sectionId, combineMode)
    if combineMode == "octaves" then
        -- Each family goes to a different octave in orchestral order
        QuickBuilder.applyCombineOctaves(instrumentsByFamily, sectionId, 1)
    else
        -- Default: all families at v1o0
        for _, familyInstruments in pairs(instrumentsByFamily) do
            if #familyInstruments > 0 then
                State.ensemble.addInstrumentToSectionAtVoiceAndOctave(familyInstruments[1], sectionId, 1, 0)
            end
        end
    end
end

---Apply unison voicing (all instruments at v1o0)
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param combineMode QuickBuilderCombineMode Combine mode
---@param sectionKey string Section key (for brass-specific logic)
function QuickBuilder.applyUnisonVoicing(instrumentsByFamily, sectionId, combineMode, sectionKey)
    if combineMode == "octaves" then
        -- Each family goes to a different octave in orchestral order (all instruments per family)
        QuickBuilder.applyCombineOctaves(instrumentsByFamily, sectionId, 1)
    else
        -- Default: all instruments at v1o0
        for familyId, familyInstruments in pairs(instrumentsByFamily) do
            -- Brass unison: only use 4 horns
            -- if sectionKey == "brass" and familyId == "hrn" then
            --     for i = 1, math.min(4, #familyInstruments) do
            --         State.ensemble.addInstrumentToSectionAtVoiceAndOctave(familyInstruments[i], sectionId, 1, 0)
            --     end
            -- else
                for _, instrument in ipairs(familyInstruments) do
                    State.ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, sectionId, 1, 0)
                end
            -- end
        end
    end
end

---Helper: Get family ID from instrument name by looking it up in instrumentConfig
---@param instrument Instrument
---@return string|nil familyId The instrument family ID (picc, fl, ob, etc.)
local function getFamilyIdFromInstrument(instrument)
    if not instrumentConfig then return nil end

    -- Search through all sections to find this instrument's track
    for _, sectionConfig in pairs(instrumentConfig) do
        for familyId, familyDef in pairs(sectionConfig) do
            for _, trackName in ipairs(familyDef.tracks) do
                if instrument.name == trackName then
                    return familyId
                end
            end
        end
    end
    return nil
end

---Apply closed voicing (instruments spread across voices)
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number Number of voices to spread across
---@param combineMode QuickBuilderCombineMode How to combine multiple families
function QuickBuilder.applyClosedVoicing(instrumentsByFamily, sectionId, voiceCount, combineMode)
    if combineMode == "aligned" then
        QuickBuilder.applyCombineAligned(instrumentsByFamily, sectionId, voiceCount)
    elseif combineMode == "stacked" then
        QuickBuilder.applyCombineStacked(instrumentsByFamily, sectionId, voiceCount)
    elseif combineMode == "interlocked" then
        QuickBuilder.applyCombineInterlocked(instrumentsByFamily, sectionId, voiceCount)
    elseif combineMode == "enclosure" then
        QuickBuilder.applyCombineEnclosure(instrumentsByFamily, sectionId, voiceCount)
    elseif combineMode == "overlap" then
        QuickBuilder.applyCombineOverlap(instrumentsByFamily, sectionId, voiceCount)
    elseif combineMode == "octaves" then
        QuickBuilder.applyCombineOctaves(instrumentsByFamily, sectionId, voiceCount)
    end
end

--------------------------------------------------------------------------------
-- Combination Algorithms
--------------------------------------------------------------------------------

---Aligned: All families share the same voices (doubling)
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number
function QuickBuilder.applyCombineAligned(instrumentsByFamily, sectionId, voiceCount)
    -- Sort families by orchestral order to ensure consistent placement
    ---@type table<number, {familyId: string, instruments: Instrument[]}>
    local familiesByOrder = {}

    for familyId, familyInstruments in pairs(instrumentsByFamily) do
        local order = ORCHESTRAL_ORDER[familyId] or 999

        -- Sort by name descending within family (2 before 1)
        table.sort(familyInstruments, function(a, b)
            return a.name > b.name
        end)

        table.insert(familiesByOrder, {
            familyId = familyId,
            order = order,
            instruments = familyInstruments
        })
    end

    -- Sort families by orchestral order (high to low)
    table.sort(familiesByOrder, function(a, b)
        return a.order < b.order
    end)

    -- Each family gets the same voice/octave assignments
    for _, family in ipairs(familiesByOrder) do
        for i, instrument in ipairs(family.instruments) do
            local voice = ((i - 1) % voiceCount) + 1
            local octave = math.floor((i - 1) / voiceCount)
            State.ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, sectionId, voice, octave)
        end
    end
end

---Stacked: Families fill voices in orchestral order (high to low)
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number
function QuickBuilder.applyCombineStacked(instrumentsByFamily, sectionId, voiceCount)
    -- Collect all instruments with their family IDs
    ---@type table<number, {familyId: string, instrument: Instrument}>
    local allInstrumentsWithFamily = {}

    for familyId, familyInstruments in pairs(instrumentsByFamily) do
        for _, instrument in ipairs(familyInstruments) do
            table.insert(allInstrumentsWithFamily, {
                familyId = familyId,
                instrument = instrument
            })
        end
    end

    -- Sort by orchestral order first, then by name descending within family
    table.sort(allInstrumentsWithFamily, function(a, b)
        local orderA = ORCHESTRAL_ORDER[a.familyId] or 999
        local orderB = ORCHESTRAL_ORDER[b.familyId] or 999

        if orderA ~= orderB then
            return orderA > orderB  -- Higher instruments first (lower order number)
        else
            -- Same family: sort by name descending (2 before 1)
            return a.instrument.name > b.instrument.name
        end
    end)

    -- Assign voices sequentially
    for i, entry in ipairs(allInstrumentsWithFamily) do
        local voice = ((i - 1) % voiceCount) + 1
        local octave = math.floor((i - 1) / voiceCount)
        State.ensemble.addInstrumentToSectionAtVoiceAndOctave(entry.instrument, sectionId, voice, octave)
    end
end

---Interlocked: Alternate between families in orchestral order, starting from lowest
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number
function QuickBuilder.applyCombineInterlocked(instrumentsByFamily, sectionId, voiceCount)
    -- Organize instruments by family with orchestral order
    ---@type table<number, {familyId: string, instruments: Instrument[]}>
    local familiesByOrder = {}

    for familyId, familyInstruments in pairs(instrumentsByFamily) do
        local order = ORCHESTRAL_ORDER[familyId] or 999

        -- Sort instruments within family by name descending (2 before 1)
        table.sort(familyInstruments, function(a, b)
            return a.name > b.name
        end)

        table.insert(familiesByOrder, {
            familyId = familyId,
            order = order,
            instruments = familyInstruments
        })
    end

    -- Sort families by orchestral order (lowest first for interlocking)
    table.sort(familiesByOrder, function(a, b)
        return a.order > b.order  -- Reverse order (lowest family first)
    end)

    -- Interlock: alternate taking from each family starting from lowest instrument
    ---@type Instrument[]
    local interlocked = {}
    local maxInstruments = 0
    for _, family in ipairs(familiesByOrder) do
        if #family.instruments > maxInstruments then
            maxInstruments = #family.instruments
        end
    end

    -- Take instruments in reverse order (lowest first)
    for i = maxInstruments, 1, -1 do
        for _, family in ipairs(familiesByOrder) do
            if family.instruments[i] then
                table.insert(interlocked, family.instruments[i])
            end
        end
    end

    -- Assign voices
    for i, instrument in ipairs(interlocked) do
        local voice = ((i - 1) % voiceCount) + 1
        local octave = math.floor((i - 1) / voiceCount)
        State.ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, sectionId, voice, octave)
    end
end

---Enclosure: Alternate between outer families, building from outside in
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number
function QuickBuilder.applyCombineEnclosure(instrumentsByFamily, sectionId, voiceCount)
    -- TODO: Implement enclosure algorithm (currently disabled due to bugs)
    -- Fall back to stacked for now
    QuickBuilder.applyCombineStacked(instrumentsByFamily, sectionId, voiceCount)
end

---Overlap: Like stacked but instruments overlap by one voice when switching families
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number
function QuickBuilder.applyCombineOverlap(instrumentsByFamily, sectionId, voiceCount)
    -- Collect all instruments with their family IDs
    ---@type table<number, {familyId: string, instrument: Instrument}>
    local allInstrumentsWithFamily = {}

    for familyId, familyInstruments in pairs(instrumentsByFamily) do
        for _, instrument in ipairs(familyInstruments) do
            table.insert(allInstrumentsWithFamily, {
                familyId = familyId,
                instrument = instrument
            })
        end
    end

    -- Sort by orchestral order first, then by name descending within family
    table.sort(allInstrumentsWithFamily, function(a, b)
        local orderA = ORCHESTRAL_ORDER[a.familyId] or 999
        local orderB = ORCHESTRAL_ORDER[b.familyId] or 999

        if orderA ~= orderB then
            return orderA < orderB  -- Higher instruments first
        else
            return a.instrument.name > b.instrument.name  -- 2 before 1
        end
    end)

    -- Assign voices with overlap: when switching families, overlap by one voice
    local currentVoice = 1
    local currentOctave = 0
    local lastFamilyId = nil

    for i, entry in ipairs(allInstrumentsWithFamily) do
        -- Check if we're switching to a new family
        if lastFamilyId ~= nil and entry.familyId ~= lastFamilyId then
            -- We're switching families - don't advance voice (overlap)
            -- Just stay on current voice for first instrument of new family
        else
            -- Same family or first instrument overall - advance normally
            if i > 1 then
                currentVoice = currentVoice + 1
                if currentVoice > voiceCount then
                    currentVoice = 1
                    currentOctave = currentOctave + 1
                end
            end
        end

        State.ensemble.addInstrumentToSectionAtVoiceAndOctave(entry.instrument, sectionId, currentVoice, currentOctave)
        lastFamilyId = entry.familyId
    end
end

---Octaves: Each family goes to a different octave in orchestral order
---@param instrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param voiceCount number
function QuickBuilder.applyCombineOctaves(instrumentsByFamily, sectionId, voiceCount)
    -- Organize families by orchestral order
    ---@type table<number, {familyId: string, instruments: Instrument[]}>
    local familiesByOrder = {}

    for familyId, familyInstruments in pairs(instrumentsByFamily) do
        local order = ORCHESTRAL_ORDER[familyId] or 999

        -- Sort instruments within family by name descending (2 before 1)
        table.sort(familyInstruments, function(a, b)
            return a.name > b.name
        end)

        table.insert(familiesByOrder, {
            familyId = familyId,
            order = order,
            instruments = familyInstruments
        })
    end

    -- Sort families by orchestral order (high to low)
    table.sort(familiesByOrder, function(a, b)
        return a.order < b.order
    end)

    -- Assign each family to successive octaves
    for familyIndex, family in ipairs(familiesByOrder) do
        local octave = familyIndex - 1  -- First family at o0, second at o1, etc.

        for instrumentIndex, instrument in ipairs(family.instruments) do
            if voiceCount == 1 then
                -- Solo/Unison: all instruments at v1
                State.ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, sectionId, 1, octave)
            else
                -- Closed: spread instruments across voices within the octave
                local voice = ((instrumentIndex - 1) % voiceCount) + 1
                local extraOctaves = math.floor((instrumentIndex - 1) / voiceCount)
                State.ensemble.addInstrumentToSectionAtVoiceAndOctave(instrument, sectionId, voice, octave + extraOctaves)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Low Instrument Handling
--------------------------------------------------------------------------------

---Apply low instrument mode (places low instruments on chord tone positions)
---@param lowInstrumentsByFamily table<string, Instrument[]>
---@param sectionId string
---@param lowMode QuickBuilderLowMode
function QuickBuilder.applyLowInstruments(lowInstrumentsByFamily, sectionId, lowMode)
    if lowMode == "unison_root" then
        -- All low instruments at root, C3
        for _, familyInstruments in pairs(lowInstrumentsByFamily) do
            for _, instrument in ipairs(familyInstruments) do
                State.ensemble.addInstrumentToSectionAtChordTone(instrument, sectionId, "C3", 0)
            end
        end
    elseif lowMode == "root_octaves" then
        -- Each family gets its own root octave in orchestral order
        -- Sort families by orchestral order
        ---@type table<number, {familyId: string, order: number, instruments: Instrument[]}>
        local familiesByOrder = {}

        for familyId, familyInstruments in pairs(lowInstrumentsByFamily) do
            local order = ORCHESTRAL_ORDER[familyId] or 999

            -- Sort instruments within family by name descending (2 before 1)
            table.sort(familyInstruments, function(a, b)
                return a.name > b.name
            end)

            table.insert(familiesByOrder, {
                familyId = familyId,
                order = order,
                instruments = familyInstruments
            })
        end

        -- Sort families by orchestral order (high to low)
        table.sort(familiesByOrder, function(a, b)
            return a.order < b.order
        end)

        -- Assign each family to descending root octaves
        -- First family at C3, second at C2, third at C1, etc.
        for familyIndex, family in ipairs(familiesByOrder) do
            local octaveNum = 4 - familyIndex  -- C3 (4-1=3), C2 (4-2=2), C1 (4-3=1), etc.
            local targetNote = "C" .. octaveNum

            for _, instrument in ipairs(family.instruments) do
                State.ensemble.addInstrumentToSectionAtChordTone(instrument, sectionId, targetNote, 0)
            end
        end
    end
end

return QuickBuilder
