-- RetroactiveRecord.lua - MIDI Output Capture for Retrospective Recording

-- ============================================================================
-- RETROACTIVE RECORDING - JSFX ↔ LUA COMMUNICATION SYSTEM
-- ============================================================================
--
-- PURPOSE:
-- Captures MIDI output from JSFX plugins to enable accurate retrospective
-- MIDI recording that reflects post-processing (voice division, transforms).
--
-- WHY THIS EXISTS:
-- Reaper's built-in retrospective MIDI record captures raw input BEFORE Input FX
-- processing. When using Ensembler's voice division, this means all tracks get
-- all notes instead of their individual voice assignments. This system solves
-- that by capturing the actual MIDI output from each JSFX instance.
--
-- HOW IT WORKS:
--
-- 1. JSFX LAYER (EnsemblerFilter-retroactive.jsfx-inc):
--    - Every midisend() is wrapped by sendMidiToTrackAndRetroBuffer()
--    - Events saved to GMEM circular buffer: 500 events per instrument
--    - Buffer capacity: ~2 seconds of dense playing (16th notes + CCs)
--    - GMEM location: gmem[100000 + (slotNumber * 3002)]
--    - Event format: 6 slots (projectTime, sampleTime, type, data1, data2, data3)
--
-- 2. LUA LAYER (this module):
--    - Polls GMEM buffers every 250ms during active ensemble
--    - Transfers new events to long-term Lua storage (10 minute buffer)
--    - Tracks lastReadHead position to avoid re-reading events
--    - Auto-prunes events older than buffer duration
--
-- 3. BUFFER COORDINATION:
--    - Each instrument assigned sequential slot number (0, 1, 2, etc.) via InstrumentMemorySlots
--    - Lua tracks GMEM write_head to detect new events
--    - Wraparound detection: if (write_head - lastReadHead) > 500, buffer cycled
--    - Lua sets JSFX slider24 to communicate slot number to each plugin
--
-- 4. LIFECYCLE:
--    - Buffers created lazily on first poll after ensemble update
--    - Polling active only while State.ensemble.is_active
--    - Buffers persist through ensemble deactivation (user can retro later!)
--    - Buffers cleared only when new ensemble loads/creates
--
-- 5. MEMORY LAYOUT:
--    JSFX GMEM (per instrument, 3,002 slots):
--      [base + 0]     write_head (ever-incrementing)
--      [base + 1]     event_count (capped at 500)
--      [base + 2...]  event data (circular buffer)
--
--    Lua Storage (per instrument):
--      events[]       Array of RetroMidiEvent (~10 minutes)
--      lastReadHead   Last write_head value read from GMEM
--      slotNumber     Sequential index for GMEM address calculation
--
-- ============================================================================

local GMEM = require('modules/GMEM')

RetroactiveRecord = {}

-- Temporary wrapper for gradual migration to Debug API
local function debug_log(msg)
    Debug.log(msg, Debug.FEATURE.RETRO)
end

-- ============================================================================
-- CONFIGURATION - MUST STAY IN SYNC WITH JSFX
-- ============================================================================
-- ⚠️ WARNING: These constants MUST match EnsemblerFilter-retroactive.jsfx-inc
-- If you change these, you MUST update both files simultaneously!
-- ============================================================================

local RETRO_GMEM_BASE = 100000              -- Start of retroactive zone in GMEM
local RETRO_MAX_EVENTS = 500                -- Events per instrument buffer
local RETRO_SLOTS_PER_EVENT = 6             -- Slots per event (time, type, data)
local RETRO_SLOTS_PER_INSTRUMENT = 3002     -- 2 metadata + (500 * 6) event slots
local RETRO_BUFFER_DURATION_SECONDS = 600   -- 10 minutes of storage
local RETRO_POLL_INTERVAL_SECONDS = 0.150    -- Poll GMEM every x seconds

-- Recent cursor movement configuration (for "recent" vs "all" retro mode)
local RETRO_IDLE_TIMEOUT_SECONDS = 60       -- Move recent cursor after X seconds without MIDI input
local RETRO_RECENT_MODE_THRESHOLD = 0.9     -- Item < 90% of buffer span = "recent" mode

-- Reaper's retroactive record take name (used to detect retro items vs normal recorded items)
local REAPER_RETRO_TAKE_NAME = "retroactively recorded MIDI"
local ENSEMBLER_RETRO_TAKE_NAME = "retroactively recorded MIDI from Ensembler"

-- ============================================================================
-- PRIVATE STATE
-- ============================================================================

---@type RetroActiveBuffersMap
local activeBuffers = {}

---@type number
local lastPollTime = 0

---@type boolean
local isInitialized = false

---@type table<string, table<string, boolean>>
local trackedItemGuids = {}  -- instrumentId → {itemGuid → true} (for detection)

---@type number|nil
local lastPlayState = nil  -- Track play state changes in poll loop (for recent cursor movement)

---@type number|nil
local lastPlayStateInInput = nil  -- Track play state changes in onNewInput (for state transition detection)

---@type boolean
local shouldMoveRecentCursorOnNextInput = true  -- Global flag for recent cursor movement

-- ============================================================================
-- PRIVATE HELPER FUNCTIONS
-- ============================================================================

---Calculate GMEM base address for an instrument's buffer
---@param slotNumber integer Sequential slot number (0-based)
---@return integer gmemBase
local function calculateBufferBase(slotNumber)
    return RETRO_GMEM_BASE + (slotNumber * RETRO_SLOTS_PER_INSTRUMENT)
end


---Read a single event from GMEM at the specified read position
---@param bufferBase integer GMEM base address
---@param readPos integer Position within circular buffer (0-499)
---@param currentTime number Current Reaper time for polledTime
---@return RetroMidiEvent
local function readEventFromGMEM(bufferBase, readPos, currentTime)
    local slotBase = bufferBase + 2 + (readPos * RETRO_SLOTS_PER_EVENT)

    ---@type RetroMidiEvent
    local event = {
        projectTime = reaper.gmem_read(slotBase + 0),
        sampleTime = reaper.gmem_read(slotBase + 1),
        eventType = math.floor(reaper.gmem_read(slotBase + 2)),
        data1 = math.floor(reaper.gmem_read(slotBase + 3)),
        data2 = math.floor(reaper.gmem_read(slotBase + 4)),
        data3 = math.floor(reaper.gmem_read(slotBase + 5)),
        polledTime = currentTime
    }

    return event
end

---Remove events older than buffer duration
---@param buffer RetroInstrumentBuffer
---@param currentTime number Current Reaper time
local function pruneOldEvents(buffer, currentTime)
    local cutoffTime = currentTime - RETRO_BUFFER_DURATION_SECONDS
    local keepIndex = 1

    -- Find first event to keep
    for i, event in ipairs(buffer.events) do
        if event.polledTime >= cutoffTime then
            keepIndex = i
            break
        end
    end

    -- Remove old events if needed
    if keepIndex > 1 then
        for i = 1, keepIndex - 1 do
            table.remove(buffer.events, 1)
        end
    end
end

---Move recent cursor to current end of buffer (start new "recent" session)
---@param buffer RetroInstrumentBuffer
local function moveRecentCursorToEnd(buffer)
    local oldCursor = buffer.recentCursor
    buffer.recentCursor = #buffer.events
end

---Move recent cursor for all buffers and clear the flag
---@param reason string Reason for cursor movement (for logging)
local function moveAllRecentCursorsAndClearFlag(reason)
    for _, buf in pairs(activeBuffers) do
        moveRecentCursorToEnd(buf)
    end
    shouldMoveRecentCursorOnNextInput = false

    Debug.log(string.format("Moved cursor (Reason: %s)", reason), Debug.FEATURE.RETRO)
end

---Check if any buffer has been idle and should trigger recent cursor movement
---@param currentTime number Current Reaper time
local function checkIdleTimeout(currentTime)
    for _, buffer in pairs(activeBuffers) do
        if buffer.lastInputTime > 0 then
            local idleDuration = currentTime - buffer.lastInputTime
            if idleDuration >= RETRO_IDLE_TIMEOUT_SECONDS then
                shouldMoveRecentCursorOnNextInput = true
                return
            end
        end
    end
end

-- Move recent cursor depending on changes to playState
local function flagRecentCursorIfNeededBasedOnPlayState() 
    -- Get current play state
    local playState = reaper.GetPlayState()
    local isRecording = (playState & 4) ~= 0
    local isPlaying = (playState & 1) ~= 0

    -- Check if play state changed since last input (state transition detection)
    if lastPlayStateInInput and playState ~= lastPlayStateInInput then
        -- State changed - check if playback or recording just started
        local wasPlaying = (lastPlayStateInInput & 1) ~= 0
        local wasRecording = (lastPlayStateInInput & 4) ~= 0

        if (isPlaying and not wasPlaying) or (isRecording and not wasRecording) then
            -- Playback or recording just started - flag cursor for movement
            shouldMoveRecentCursorOnNextInput = true
            Debug.log("shouldMoveRecentCursor: \n"
                .." isPlaying: "..tostring(isPlaying)
                .." wasPlaying: "..tostring(wasPlaying)
                .." isRecording: "..tostring(isRecording)
                .." wasRecording: "..tostring(wasRecording),
                Debug.FEATURE.RETRO)
        end
    end

    -- Update last play state
    lastPlayStateInInput = playState
end 

---Handle new input events (check idle timeout and move recent cursor if needed)
---@param currentTime number Current Reaper time
local function onNewInput(currentTime)
    Debug.log("onNewInput "..currentTime, Debug.FEATURE.RETRO)
    -- Check if idle timeout triggered recent cursor movement flag (global check)
    checkIdleTimeout(currentTime)

    flagRecentCursorIfNeededBasedOnPlayState()

    -- Move recent cursor if flagged
    if shouldMoveRecentCursorOnNextInput then
        if (lastPlayStateInInput & 4) ~= 0 then -- isRecording
            -- Wait for recording to end before moving cursor
            -- (Keep flag set, don't move yet)
        elseif (lastPlayStateInInput & 1) ~= 0 then -- isPlaying
            -- Playing: move cursor now (first input after playback started)
            moveAllRecentCursorsAndClearFlag("Playback started")
        else
            -- Stopped: move cursor now (first input after recording ended/idle/retro)
            moveAllRecentCursorsAndClearFlag("First input after recording ended/idle/retro")
        end
    end
end

---Mark recent cursor for movement on next input (called on session boundary triggers)
local function markRecentCursorForMovement()
    shouldMoveRecentCursorOnNextInput = true
end

---Poll a single instrument's GMEM buffer and transfer new events
---@param instrumentId string Track GUID
---@param buffer RetroInstrumentBuffer
local function pollInstrumentBuffer(instrumentId, buffer)
    local bufferBase = calculateBufferBase(buffer.slotNumber)
    local currentWriteHead = math.floor(reaper.gmem_read(bufferBase + 0))
    local eventCount = math.floor(reaper.gmem_read(bufferBase + 1))
    local currentTime = reaper.time_precise()

    -- Calculate new events since last poll
    local newEventCount = currentWriteHead - buffer.lastReadHead

    -- Handle wraparound detection
    if newEventCount > RETRO_MAX_EVENTS then
        -- Buffer wrapped! We missed some events (extremely rare - UI freeze?)
        -- Read only the most recent 500 events (what's still valid in buffer)
        reaper.ShowConsoleMsg(string.format(
            "RetroactiveRecord WARNING: Buffer wraparound detected for instrument %s. Some events lost.\n",
            instrumentId
        ))
        buffer.lastReadHead = currentWriteHead - eventCount
        newEventCount = eventCount
    end

    -- Skip if no new events
    if newEventCount <= 0 then
        return
    end

    -- Handle new input (check idle timeout and move recent cursor if needed)
    onNewInput(currentTime)

    -- Transfer events from GMEM to Lua
    for i = 0, newEventCount - 1 do
        local readPos = (buffer.lastReadHead + i) % RETRO_MAX_EVENTS
        local event = readEventFromGMEM(bufferBase, readPos, currentTime)
        table.insert(buffer.events, event)
    end

    -- Update tracking
    buffer.lastReadHead = currentWriteHead
    buffer.lastInputTime = currentTime

    -- Prune old events to prevent unbounded growth
    pruneOldEvents(buffer, currentTime)
end

-- ============================================================================
-- ITEM DETECTION & REPLACEMENT
-- ============================================================================

---Create new MIDI item from buffered events
---@param track MediaTrack Reaper track object
---@param itemStart number Item start position in project time
---@param itemLength number Item length in seconds
---@param events RetroMidiEvent[] Buffered events to insert
---@param useAbsoluteTiming boolean True to use projectTime, false to use sampleTime for relative positioning
---@param globalStartTime number Global start time across all instruments (used for relative timing)
---@return MediaItem|nil newItem The created item, or nil if creation failed
local function createMidiItemFromEvents(track, itemStart, itemLength, events, useAbsoluteTiming, globalStartTime)
    -- Create new MIDI item
    local item = reaper.CreateNewMIDIItemInProj(track, itemStart, itemStart + itemLength, false)
    if not item then
        return nil
    end

    local take = reaper.GetActiveTake(item)
    if not take then
        reaper.DeleteTrackMediaItem(track, item)
        return nil
    end

    -- For relative timing, use global start time as offset
    -- This ensures all instruments position their events relative to the same global baseline
    local timeOffset = 0
    if not useAbsoluteTiming then
        timeOffset = globalStartTime
    end

    -- Insert buffered events
    -- Track which note-ons we've already processed to avoid duplicates
    ---@type table<string, boolean>
    local processedNoteOns = {}

    for _, event in ipairs(events) do
        if event.eventType == 1 then
            -- Note On - find matching note off
            -- Use sampleTime in key to handle repeated notes (same note played multiple times)
            local noteKey = string.format("%d_%d_%.6f", event.data1, event.data3, event.sampleTime)

            if not processedNoteOns[noteKey] then
                processedNoteOns[noteKey] = true

                -- Find matching note off (first one with same note+channel after this note-on)
                local noteOffEvent = nil
                for _, evt2 in ipairs(events) do
                    if evt2.eventType == 0 and
                       evt2.data1 == event.data1 and  -- Same note number
                       evt2.data3 == event.data3 and  -- Same channel
                       evt2.sampleTime > event.sampleTime then  -- Later time
                        noteOffEvent = evt2
                        break
                    end
                end

                if noteOffEvent then
                    local startPpq, endPpq

                    if useAbsoluteTiming then
                        -- Use projectTime for absolute positioning (playback was active)
                        startPpq = reaper.MIDI_GetPPQPosFromProjTime(take, event.projectTime)
                        endPpq = reaper.MIDI_GetPPQPosFromProjTime(take, noteOffEvent.projectTime)
                    else
                        -- Use sampleTime for relative positioning (playback was stopped)
                        -- sampleTime is already in seconds (from time_precise()), just calculate delta
                        local startSeconds = event.sampleTime - timeOffset
                        local endSeconds = noteOffEvent.sampleTime - timeOffset
                        startPpq = reaper.MIDI_GetPPQPosFromProjTime(take, itemStart + startSeconds)
                        endPpq = reaper.MIDI_GetPPQPosFromProjTime(take, itemStart + endSeconds)
                    end

                    reaper.MIDI_InsertNote(take, false, false, startPpq, endPpq, event.data3, event.data1, event.data2, false)
                end
            end
        elseif event.eventType == 2 then
            -- CC
            local ppq

            if useAbsoluteTiming then
                ppq = reaper.MIDI_GetPPQPosFromProjTime(take, event.projectTime)
            else
                -- sampleTime is already in seconds (from time_precise())
                local ccSeconds = event.sampleTime - timeOffset
                ppq = reaper.MIDI_GetPPQPosFromProjTime(take, itemStart + ccSeconds)
            end

            reaper.MIDI_InsertCC(take, false, false, ppq, 0xB0, event.data3, event.data1, event.data2)
        end
    end

    reaper.MIDI_Sort(take)

    -- Set take name to identify our items
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", ENSEMBLER_RETRO_TAKE_NAME, true)

    return item
end

---Get the time span of Reaper's native retro buffer (for mode determination)
---@return number spanSeconds Duration in seconds, or 0 if no events
local function getReaperRetroBufferSpan()
    -- Parameter order: retval, buf, ts, devIdx, projPos, projLoopCnt
    local retval, _, ts, _, projPos = reaper.MIDI_GetRecentInputEvent(0)

    if retval == 0 then
        return 0
    end

    -- Initialize tracking with first event values
    local firstProjPos = projPos
    local lastProjPos = projPos
    local firstTs = ts
    local lastTs = ts
    local idx = 1

    -- Scan all events to find span (matches Test_MIDI_GetRecentInputEvent.lua pattern)
    while true do
        local ret, _, eventTs, _, eventProjPos = reaper.MIDI_GetRecentInputEvent(idx)
        if ret == 0 then
            break
        end

        -- Update projPos span tracking (only if valid)
        if eventProjPos and eventProjPos >= 0 then
            if eventProjPos < firstProjPos or firstProjPos < 0 then
                firstProjPos = eventProjPos
            end
            if eventProjPos > lastProjPos then
                lastProjPos = eventProjPos
            end
        end

        -- Always update ts span tracking
        if eventTs < firstTs then
            firstTs = eventTs
        end
        if eventTs > lastTs then
            lastTs = eventTs
        end

        idx = idx + 1
    end

    -- Determine which timing to use and calculate span
    if projPos and projPos >= 0 then
        -- Playing: use project positions (already in seconds)
        return lastProjPos - firstProjPos
    else
        -- Stopped: use timestamps (convert from samples to seconds)
        local success, srateStr = reaper.GetAudioDeviceInfo("SRATE")
        local sampleRate = success and tonumber(srateStr) or 48000
        return (lastTs - firstTs) / sampleRate
    end
end

---Get events for "recent" mode using recent cursor position
---@param buffer RetroInstrumentBuffer
---@return RetroMidiEvent[]
local function getRecentEvents(buffer)
    ---@type RetroMidiEvent[]
    local recent = {}

    -- Return all events after the recent cursor (session boundary marker)
    for i = buffer.recentCursor + 1, #buffer.events do
        table.insert(recent, buffer.events[i])
    end

    return recent
end

---Aggregate events from multiple instruments for global timing calculation
---@param instrumentEvents table<string, RetroMidiEvent[]> Map of instrumentId → events
---@param useAbsoluteTiming boolean True to use projectTime, false to use sampleTime
---@return number globalStart Global start time across all instruments
---@return number globalLength Global length across all instruments
local function calculateGlobalTiming(instrumentEvents, useAbsoluteTiming)
    local allEvents = {}

    -- Collect all events from all instruments
    for _, events in pairs(instrumentEvents) do
        for _, event in ipairs(events) do
            table.insert(allEvents, event)
        end
    end

    if #allEvents == 0 then
        return 0, 0
    end

    -- Find earliest and latest times across all events
    local earliestTime, latestTime

    if useAbsoluteTiming then
        -- Use projectTime for absolute positioning
        earliestTime = allEvents[1].projectTime
        latestTime = allEvents[1].projectTime

        for _, event in ipairs(allEvents) do
            if event.projectTime < earliestTime then
                earliestTime = event.projectTime
            end
            if event.projectTime > latestTime then
                latestTime = event.projectTime
            end
        end
    else
        -- Use sampleTime for relative positioning
        earliestTime = allEvents[1].sampleTime
        latestTime = allEvents[1].sampleTime

        for _, event in ipairs(allEvents) do
            if event.sampleTime < earliestTime then
                earliestTime = event.sampleTime
            end
            if event.sampleTime > latestTime then
                latestTime = event.sampleTime
            end
        end
    end

    local globalLength = latestTime - earliestTime
    return earliestTime, globalLength
end

---Replace retro item MIDI content with correct buffered events (batch version)
---@param retroBatch table<string, {track: MediaTrack, item: MediaItem}> Map of instrumentId → {track, item}
local function replaceRetroItemsBatch(retroBatch)
    if not next(retroBatch) then
        return
    end

    -- Force-poll all buffers one last time to ensure we have the latest GMEM data
    for instrumentId, _ in pairs(retroBatch) do
        local buffer = activeBuffers[instrumentId]
        if buffer then
            pollInstrumentBuffer(instrumentId, buffer)
        end
    end

    -- Get first item to determine mode and timing parameters from Reaper's retro item
    -- (Note: when using absolute timing, we'll recalculate position from event data)
    local firstInstrumentId = next(retroBatch)
    local firstItem = retroBatch[firstInstrumentId].item
    local reaperItemStart = reaper.GetMediaItemInfo_Value(firstItem, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(firstItem, "D_LENGTH")

    -- Determine mode: compare item length to Reaper's native retro buffer span
    local reaperBufferSpan = getReaperRetroBufferSpan()
    local isRecentMode = itemLength < (RETRO_RECENT_MODE_THRESHOLD * reaperBufferSpan)
    isRecentMode = true -- disabling support for full mode for now

    debug_log(string.format("RetroRecord: Processing retro batch (%d instruments)",
        (function() local n=0; for _ in pairs(retroBatch) do n=n+1 end; return n end)()))
    debug_log(string.format("  Reaper item start: %.3fs, Item length: %.3fs, Reaper buffer span: %.3fs",
        reaperItemStart, itemLength, reaperBufferSpan))
    debug_log(string.format("  Mode: %s", isRecentMode and "RECENT" or "FULL"))

    -- Collect events for each instrument based on mode
    ---@type table<string, RetroMidiEvent[]>
    local instrumentEvents = {}

    for instrumentId, _ in pairs(retroBatch) do
        local buffer = activeBuffers[instrumentId]
        if buffer then
            local events
            if isRecentMode then
                events = getRecentEvents(buffer)
                debug_log(string.format("  %s: recent_cursor=%d, events_after_cursor=%d",
                    instrumentId, buffer.recentCursor, #events))
            else
                events = buffer.events
                debug_log(string.format("  %s: total buffered events=%d",
                    instrumentId, #events))
            end

            -- Only include instruments with events
            if #events > 0 then
                instrumentEvents[instrumentId] = events
            else
                debug_log(string.format("  %s: skipping (zero events)", instrumentId))
            end
        end
    end

    -- If no instruments have events, leave all retro items as-is
    if not next(instrumentEvents) then
        debug_log("  No events across any instrument, leaving all retro items as-is")
        return
    end

    -- Determine timing mode based on recent events across all instruments
    local useAbsoluteTiming

    if not isRecentMode then
        -- Full mode: always use relative timing
        useAbsoluteTiming = false
        debug_log("  Timing mode: RELATIVE (full mode)")
    else
        -- Recent mode: check if any instrument has events without valid projectTime
        local hasValidProjectTime = true
        for _, events in pairs(instrumentEvents) do
            -- Check last 10 events for each instrument
            for i = #events, math.max(1, #events - 10), -1 do
                if events[i].projectTime < 0 then
                    hasValidProjectTime = false
                    break
                end
            end
            if not hasValidProjectTime then
                break
            end
        end

        useAbsoluteTiming = hasValidProjectTime
        debug_log(string.format("  Timing mode: %s (recent mode)",
            useAbsoluteTiming and "ABSOLUTE" or "RELATIVE"))
    end

    -- Calculate global timing across all instruments
    local globalStart, globalLength = calculateGlobalTiming(instrumentEvents, useAbsoluteTiming)

    -- Validation: if using absolute timing but globalStart is invalid, fall back to leaving items as-is
    if useAbsoluteTiming and (not globalStart or globalStart < 0) then
        debug_log("  ERROR: Absolute timing mode but invalid projectTime data!")
        debug_log("  Leaving Reaper's retro items as-is")
        return
    end

    debug_log(string.format("  Global timing: start=%.6f, length=%.3fs", globalStart, globalLength))

    -- Calculate actual item start position
    local itemStart
    if useAbsoluteTiming then
        -- Absolute timing: use the earliest projectTime from events (playhead was moving)
        itemStart = globalStart
        debug_log(string.format("  Using event-based start position: %.6f (absolute timing)", itemStart))
    else
        -- Relative timing: use Reaper's retro item position (playhead was stopped)
        itemStart = reaperItemStart
        debug_log(string.format("  Using Reaper's item start position: %.6f (relative timing)", itemStart))
    end

    -- Move edit cursor to start position (only for relative timing)
    -- For absolute timing, we don't move the cursor before creating items
    if not useAbsoluteTiming then
        reaper.SetEditCurPos(itemStart, false, false)
        debug_log("  Moved edit cursor to item start (relative timing)")
    end

    -- Delete all original retro items
    for instrumentId, data in pairs(retroBatch) do
        reaper.DeleteTrackMediaItem(data.track, data.item)
    end
    reaper.UpdateArrange()

    -- Create new items for instruments with events (using shared global timing)
    for instrumentId, events in pairs(instrumentEvents) do
        local data = retroBatch[instrumentId]
        createMidiItemFromEvents(data.track, itemStart, globalLength, events, useAbsoluteTiming, globalStart)
        debug_log(string.format("  Created item for %s with %d events", instrumentId, #events))
    end
    reaper.UpdateArrange()

    -- Move edit cursor to end of created items (match Reaper's behavior)
    if not useAbsoluteTiming then
        reaper.SetEditCurPos(itemStart + globalLength, false, false)
        debug_log(string.format("  Moved edit cursor to end: %.6f", itemStart + globalLength))
    end

    -- Mark recent cursor to move on next input (new session started)
    markRecentCursorForMovement()
    debug_log("  Marked recent cursor for movement on next input (retro insert completed)")
end

---Detect new retro items and replace their content with buffered events
---Called from poll() to check for retro item insertion
local function detectAndHandleRetroItems()
    local instruments = Ensemble.getAllInstruments()
    if not instruments then
        return
    end

    -- Collect all new retro items (retro creates items on all tracks simultaneously)
    ---@type table<string, {track: MediaTrack, item: MediaItem}>
    local retroBatch = {}
    local hasAnyNewItems = false

    for _, instrument in ipairs(instruments) do
        local track = instrument.trackData.reaperTrack
        local instrumentId = instrument.trackData.guid

        if track then
            -- Initialize tracked GUIDs for this instrument if needed
            if not trackedItemGuids[instrumentId] then
                trackedItemGuids[instrumentId] = {}
            end

            local currentItemCount = reaper.CountTrackMediaItems(track)
            local trackedGuids = trackedItemGuids[instrumentId]

            -- Build set of current item GUIDs
            ---@type table<string, MediaItem>
            local currentItems = {}
            for i = 0, currentItemCount - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                if item then
                    local itemGuid = reaper.BR_GetMediaItemGUID(item)
                    if itemGuid then
                        currentItems[itemGuid] = item
                    end
                end
            end

            -- Find new items (items in current set but not in tracked set)
            for itemGuid, item in pairs(currentItems) do
                if not trackedGuids[itemGuid] then
                    -- New item detected!
                    hasAnyNewItems = true
                    trackedGuids[itemGuid] = true

                    local take = reaper.GetActiveTake(item)
                    if take then
                        local takeName = reaper.GetTakeName(take)
                        if takeName == REAPER_RETRO_TAKE_NAME then
                            -- Retro item from Reaper - add to batch for processing
                            retroBatch[instrumentId] = {
                                track = track,
                                item = item
                            }
                        elseif takeName == ENSEMBLER_RETRO_TAKE_NAME then
                            -- Our own retro item - ignore (already processed)
                            -- No action needed
                        else
                            -- Non-retro item (recorded) - mark recent cursor to move on next input
                            debug_log(string.format("RetroRecord: Detected recorded item (not retro) for %s, take name: '%s'",
                                instrumentId, takeName))
                            debug_log("  Marking recent cursor for movement on next input")
                            markRecentCursorForMovement()
                        end
                    end
                end
            end

            -- Clean up tracked GUIDs for items that no longer exist
            for guid in pairs(trackedGuids) do
                if not currentItems[guid] then
                    trackedGuids[guid] = nil
                end
            end
        end
    end

    -- Process all retro items together if any were detected
    if hasAnyNewItems and next(retroBatch) then
        replaceRetroItemsBatch(retroBatch)
    end
end

---Initialize item tracking for current ensemble
---Called when ensemble is loaded/updated
local function initializeItemTracking()
    trackedItemGuids = {}

    local instruments = Ensemble.getAllInstruments()
    if not instruments then
        return
    end

    for _, instrument in ipairs(instruments) do
        local track = instrument.trackData.reaperTrack
        local instrumentId = instrument.trackData.guid

        if track then
            trackedItemGuids[instrumentId] = {}
            local itemCount = reaper.CountTrackMediaItems(track)

            -- Track all existing items by GUID
            for i = 0, itemCount - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                if item then
                    local itemGuid = reaper.BR_GetMediaItemGUID(item)
                    if itemGuid then
                        trackedItemGuids[instrumentId][itemGuid] = true
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Initialize retroactive recording system (attach to GMEM)
---@return boolean success
function RetroactiveRecord.initialize()
    if isInitialized then
        return true
    end

    -- Attach to ensembler GMEM space (should already be done by AppController)
    -- Just verify we can read
    local testValue = reaper.gmem_read(0)
    if not testValue then
        reaper.ShowConsoleMsg("RetroactiveRecord ERROR: Failed to attach to GMEM\n")
        return false
    end

    isInitialized = true
    return true
end

---Initialize buffers for current ensemble configuration
---Called by INFX.ensembleWasUpdated()
---@param instruments Instrument[]
---@return RetroSlotNumberMap slotNumbers Map for INFX to set slider24
function RetroactiveRecord.initializeForEnsemble(instruments)
    if not RetroactiveRecord.initialize() then
        return {}
    end

    -- Assign slot numbers sequentially
    local slotNumbers = GMEM.assignInstrumentSlots(instruments)

    -- Create or update buffers for each instrument
    for _, instrument in ipairs(instruments) do
        local instrumentId = instrument.trackData.guid
        local slotNumber = slotNumbers[instrumentId]

        if not activeBuffers[instrumentId] then
            -- Create new buffer
            ---@type RetroInstrumentBuffer
            activeBuffers[instrumentId] = {
                events = {},
                lastReadHead = 0,
                slotNumber = slotNumber,
                instrumentId = instrumentId,
                recentCursor = 0,
                lastInputTime = 0
            }
        else
            -- Update existing buffer's slot number (might have changed if instruments reordered)
            activeBuffers[instrumentId].slotNumber = slotNumber
        end
    end

    -- Initialize item tracking for retro detection
    initializeItemTracking()

    return slotNumbers
end

---Poll all active instrument buffers (called from AppController.loop)
---Rate-limited internally to poll interval
function RetroactiveRecord.poll()
    if not isInitialized then
        return
    end

    local currentTime = reaper.time_precise()

    -- Rate limiting: only poll every RETRO_POLL_INTERVAL_SECONDS
    if currentTime - lastPollTime < RETRO_POLL_INTERVAL_SECONDS then
        return
    end

    lastPollTime = currentTime

    -- Check for play state changes
    flagRecentCursorIfNeededBasedOnPlayState()

    -- Poll each active buffer
    for instrumentId, buffer in pairs(activeBuffers) do
        pollInstrumentBuffer(instrumentId, buffer)
    end

    -- Detect and handle retro items
    detectAndHandleRetroItems()
end

---Clear all buffers (called when new ensemble loads)
function RetroactiveRecord.clearAllBuffers()
    activeBuffers = {}
    lastPollTime = 0
end

---Get events for an instrument within time range
---Used by Phase 3 for creating retrospective MIDI items
---@param instrumentId string Track GUID
---@param startTime number|nil Project time start (nil = all events)
---@param endTime number|nil Project time end (nil = all events)
---@return RetroMidiEvent[]
function RetroactiveRecord.getEvents(instrumentId, startTime, endTime)
    local buffer = activeBuffers[instrumentId]
    if not buffer then
        return {}
    end

    -- If no time range specified, return all events
    if not startTime and not endTime then
        return buffer.events
    end

    -- Filter by time range
    ---@type RetroMidiEvent[]
    local filtered = {}
    for _, event in ipairs(buffer.events) do
        -- Check if event is within time range
        local inRange = true
        if startTime and event.projectTime >= 0 and event.projectTime < startTime then
            inRange = false
        end
        if endTime and event.projectTime >= 0 and event.projectTime > endTime then
            inRange = false
        end

        if inRange then
            table.insert(filtered, event)
        end
    end

    return filtered
end

---Get buffer statistics for debugging
---@param instrumentId string Track GUID
---@return string stats Human-readable buffer statistics
function RetroactiveRecord.getBufferStats(instrumentId)
    local buffer = activeBuffers[instrumentId]
    if not buffer then
        return "No buffer for instrument"
    end

    local eventCount = #buffer.events
    local oldestTime = eventCount > 0 and buffer.events[1].polledTime or 0
    local newestTime = eventCount > 0 and buffer.events[eventCount].polledTime or 0
    local duration = newestTime - oldestTime

    return string.format(
        "Slot %d | Events: %d | Duration: %.1fs | Head: %d",
        buffer.slotNumber,
        eventCount,
        duration,
        buffer.lastReadHead
    )
end

return RetroactiveRecord
