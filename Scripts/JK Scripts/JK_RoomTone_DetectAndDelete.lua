-- JK_RoomTone_DetectAndDelete.lua
-- Scans audio under the mouse cursor to locate a silence region, then deletes it.
-- Also handles the case where the cursor is in an inter-item GAP (empty space between
-- two items) — closes the gap and positions the cursor for room-tone insertion.
-- Leaves PAD_MS of silence on each side for crossfading.
-- Positions the edit cursor and selects the track for a subsequent Insert script.
-- Does NOT insert room-tone or advance markers — use in a REAPER custom action:
--
--   Macro examples (build in Actions > Show action list > New custom action):
--     SB fix:   JK_RoomTone_DetectAndDelete → JK_RoomTone_Insert_2.5s → JK_RoomTone_AdvanceMarker
--     PBP fix:  JK_RoomTone_DetectAndDelete → JK_RoomTone_Insert_1.7s → JK_RoomTone_AdvanceMarker
--     PMS fix:  JK_RoomTone_DetectAndDelete → JK_RoomTone_Insert_0.5s → JK_RoomTone_AdvanceMarker
--     Del only: JK_RoomTone_DetectAndDelete → JK_RoomTone_AdvanceMarker
--
-- Ripple mode: expects Ripple Edit (all tracks) ON. Works with ripple OFF but
-- leaves a gap that the Insert script fills exactly only when ripple is ON.
--
-- THRESHOLD: configure via JK_RoomTone_Settings.lua (persists across sessions).
-- Hardcoded defaults below are used only until Settings has been run once.
--
-- Dependencies: SWS Extension (BR_GetMouseCursorContext)

-- ============================================================
-- CONFIG DEFAULTS  (overridden by JK_RoomTone_Settings.lua values)
-- ============================================================
local DEFAULT_THRESHOLD_DB = -60    -- dB below which audio is treated as silence
local PAD_MS               = 30     -- ms of silence preserved on each side of the gap
local CROSSFADE_MS         = 15     -- ms fade applied to neighbouring item edges
local COARSE_CHUNK_MS      = 100    -- first-pass scan resolution
local FINE_CHUNK_MS        = 5      -- boundary refinement resolution

-- ============================================================
-- HELPERS
-- ============================================================
local EXT_NS = "JK_RoomTone"

local function dbToLinear(db)
    return 10 ^ (db / 20)
end

local function getThreshold()
    local stored = reaper.GetExtState(EXT_NS, "threshold_db")
    local db = tonumber(stored)
    if not db then db = DEFAULT_THRESHOLD_DB end
    return dbToLinear(db), db
end

-- Returns peak amplitude across all channels for num_samples starting at start_sec (project time)
local function peakInRange(accessor, samplerate, nch, start_sec, num_samples)
    if num_samples <= 0 then return 0 end
    local buf = reaper.new_array(num_samples * nch)
    local ok  = reaper.GetAudioAccessorSamples(accessor, samplerate, nch, start_sec, num_samples, buf)
    if ok == 0 then return 0 end
    local peak = 0
    for i = 1, num_samples * nch do
        local v = math.abs(buf[i])
        if v > peak then peak = v end
    end
    return peak
end

-- Scan leftward from start_pos; returns the position where audio ends (silence begins).
local function scanLeft(accessor, samplerate, nch, start_pos, item_start, threshold)
    local coarse_sec = COARSE_CHUNK_MS / 1000
    local fine_sec   = FINE_CHUNK_MS   / 1000
    local pos = start_pos
    while pos > item_start do
        local t0 = math.max(pos - coarse_sec, item_start)
        local n  = math.floor((pos - t0) * samplerate)
        if n > 0 and peakInRange(accessor, samplerate, nch, t0, n) > threshold then
            -- Refine: scan [t0, pos] left-to-right to find last loud fine-chunk
            local last_loud_end = t0
            local rp = t0
            while rp < pos do
                local rt1 = math.min(rp + fine_sec, pos)
                local rn  = math.floor((rt1 - rp) * samplerate)
                if rn > 0 and peakInRange(accessor, samplerate, nch, rp, rn) > threshold then
                    last_loud_end = rt1
                end
                rp = rt1
            end
            return last_loud_end
        end
        pos = t0
    end
    return item_start
end

-- Scan rightward from start_pos; returns the position where silence ends (audio begins).
local function scanRight(accessor, samplerate, nch, start_pos, item_end, threshold)
    local coarse_sec = COARSE_CHUNK_MS / 1000
    local fine_sec   = FINE_CHUNK_MS   / 1000
    local pos = start_pos
    while pos < item_end do
        local t1 = math.min(pos + coarse_sec, item_end)
        local n  = math.floor((t1 - pos) * samplerate)
        if n > 0 and peakInRange(accessor, samplerate, nch, pos, n) > threshold then
            -- Refine: find first loud fine-chunk in [pos, t1]
            local rp = pos
            while rp < t1 do
                local rt1 = math.min(rp + fine_sec, t1)
                local rn  = math.floor((rt1 - rp) * samplerate)
                if rn > 0 and peakInRange(accessor, samplerate, nch, rp, rn) > threshold then
                    return rp
                end
                rp = rt1
            end
            return pos
        end
        pos = t1
    end
    return item_end
end

-- ============================================================
-- GAP HANDLER
-- Called when the cursor is in empty space between two items.
-- Closes the gap (preserving pad on each side) and positions
-- the edit cursor for room-tone insertion on the same track.
-- Only shifts items on the cursor's track (suitable for single
-- voice-track audiobook sessions).
-- ============================================================
local function handleGap(track, cursor_time)
    local pad_sec       = PAD_MS       / 1000
    local crossfade_sec = CROSSFADE_MS / 1000
    local n_items       = reaper.CountTrackMediaItems(track)

    -- Find the item ending just before cursor and starting just after
    local left_item, right_item
    local gap_start, gap_end

    for i = 0, n_items - 1 do
        local it     = reaper.GetTrackMediaItem(track, i)
        local it_pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
        local it_end = it_pos + reaper.GetMediaItemInfo_Value(it, "D_LENGTH")

        if it_end <= cursor_time + 0.001 then
            -- Candidate for left neighbour — keep the rightmost one before cursor
            if not left_item or it_end > gap_start then
                left_item  = it
                gap_start  = it_end
            end
        elseif it_pos >= cursor_time - 0.001 and not right_item then
            right_item = it
            gap_end    = it_pos
        end
    end

    if not left_item or not right_item then return false end
    local gap_size = gap_end - gap_start
    if gap_size < 0.005 then return false end  -- trivially small gap, nothing to do

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- Shift right_item and everything after it leftward to close the gap,
    -- leaving pad_sec of empty space on each side.
    local keep  = math.min(pad_sec, gap_size / 2)
    local shift = gap_size - 2 * keep  -- how much to remove from the gap interior

    if shift > 0.001 then
        -- Iterate from rightmost to leftmost to avoid position conflicts
        for i = n_items - 1, 0, -1 do
            local it     = reaper.GetTrackMediaItem(track, i)
            local it_pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
            if it_pos >= gap_end - 0.001 then
                reaper.SetMediaItemInfo_Value(it, "D_POSITION", it_pos - shift)
            end
        end
    end

    -- Apply fades to the bounding items
    if crossfade_sec > 0 then
        reaper.SetMediaItemInfo_Value(left_item,  "D_FADEOUTLEN", crossfade_sec)
        reaper.SetMediaItemInfo_Value(right_item, "D_FADEINLEN",  crossfade_sec)
    end

    local insert_pos = gap_start + keep
    reaper.SetEditCurPos(insert_pos, false, false)
    reaper.SetOnlyTrackSelected(track)
    reaper.SetExtState(EXT_NS, "insert_pos", string.format("%.6f", insert_pos), false)

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("JK RoomTone: close inter-item gap", -1)
    return true
end

-- ============================================================
-- MAIN
-- ============================================================
local function main()
    if not reaper.BR_GetMouseCursorContext then
        reaper.ShowMessageBox(
            "SWS Extension is required.\nGet it at: https://www.sws-extension.org",
            "JK RoomTone", 0)
        return
    end

    reaper.BR_GetMouseCursorContext()
    local window = reaper.BR_GetMouseCursorContext()
    if window ~= "arrange" then return end

    local item        = reaper.BR_GetMouseCursorContext_Item()
    local take        = reaper.BR_GetMouseCursorContext_Take()
    local cursor_time = reaper.BR_GetMouseCursorContext_Position()

    -- No item under cursor: try to handle as an inter-item gap
    if not item or not take then
        local track = reaper.BR_GetMouseCursorContext_Track()
        if track then handleGap(track, cursor_time) end
        return
    end

    local threshold, threshold_db = getThreshold()

    local source     = reaper.GetMediaItemTake_Source(take)
    local samplerate = reaper.GetMediaSourceSampleRate(source)
    local nch        = reaper.GetMediaSourceNumChannels(source)
    if samplerate <= 0 or nch <= 0 then return end

    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    -- Clamp scan start to item interior
    local scan_pos = math.max(item_pos + 0.001, math.min(cursor_time, item_end - 0.001))

    local accessor = reaper.CreateTakeAudioAccessor(take)

    -- Gate: is the cursor actually in a silence region?
    local check_n     = math.max(1, math.floor(samplerate * FINE_CHUNK_MS / 1000))
    local center_peak = peakInRange(accessor, samplerate, nch, scan_pos, check_n)
    if center_peak > threshold then
        reaper.DestroyAudioAccessor(accessor)
        reaper.ShowConsoleMsg(
            "[JK RoomTone] Cursor is over audio (above " .. threshold_db .. " dB threshold) — nothing done.\n")
        return
    end

    local left_bound  = scanLeft (accessor, samplerate, nch, scan_pos, item_pos, threshold)
    local right_bound = scanRight(accessor, samplerate, nch, scan_pos, item_end, threshold)
    reaper.DestroyAudioAccessor(accessor)

    if right_bound - left_bound < 0.010 then
        reaper.ShowConsoleMsg("[JK RoomTone] Silence region too short (< 10 ms) — nothing done.\n")
        return
    end

    local pad_sec       = PAD_MS       / 1000
    local crossfade_sec = CROSSFADE_MS / 1000
    local left_split    = left_bound  + pad_sec
    local right_split   = right_bound - pad_sec

    if right_split <= left_split + 0.001 then
        local mid   = (left_bound + right_bound) / 2
        left_split  = mid - 0.001
        right_split = mid + 0.001
    end

    local track = reaper.GetMediaItemTrack(item)

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local temp = reaper.SplitMediaItem(item, left_split)
    if not temp then
        reaper.PreventUIRefresh(-1)
        reaper.Undo_EndBlock("JK RoomTone DetectAndDelete (aborted)", -1)
        reaper.ShowConsoleMsg("[JK RoomTone] Split failed at left boundary.\n")
        return
    end

    local right_item = reaper.SplitMediaItem(temp, right_split)
    reaper.DeleteTrackMediaItem(track, temp)

    if crossfade_sec > 0 then
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", crossfade_sec)
        if right_item then
            reaper.SetMediaItemInfo_Value(right_item, "D_FADEINLEN", crossfade_sec)
        end
    end

    reaper.SetEditCurPos(left_split, false, false)
    reaper.SetOnlyTrackSelected(track)
    reaper.SetExtState(EXT_NS, "insert_pos", string.format("%.6f", left_split), false)

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("JK RoomTone: detect and delete silence", -1)
end

main()
