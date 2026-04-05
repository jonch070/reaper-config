-- JK_RoomTone_DetectAndDelete.lua
-- Scans audio under the mouse cursor to locate a silence region, then deletes it.
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
-- Dependencies: SWS Extension (BR_GetMouseCursorContext)

-- ============================================================
-- CONFIG
-- ============================================================
local THRESHOLD_DB    = -60     -- dB below which audio is treated as silence
local PAD_MS          = 30      -- ms of silence preserved on each side of the gap
local CROSSFADE_MS    = 15      -- ms fade applied to neighbouring item edges
local COARSE_CHUNK_MS = 100     -- first-pass scan resolution (larger = faster on long silences)
local FINE_CHUNK_MS   = 5       -- refinement resolution at the detected boundary

-- ============================================================
-- HELPERS
-- ============================================================
local EXT_NS = "JK_RoomTone"    -- shared ExtState namespace

local function dbToLinear(db)
    return 10 ^ (db / 20)
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

-- Scan leftward from start_pos to find the right edge of the audio block to the left.
-- Uses a coarse pass then refines near the boundary.
local function scanLeft(accessor, samplerate, nch, start_pos, item_start, threshold)
    local coarse_sec = COARSE_CHUNK_MS / 1000
    local fine_sec   = FINE_CHUNK_MS   / 1000

    local pos = start_pos
    while pos > item_start do
        local t0 = math.max(pos - coarse_sec, item_start)
        local n  = math.floor((pos - t0) * samplerate)
        if n > 0 and peakInRange(accessor, samplerate, nch, t0, n) > threshold then
            -- Audio found in [t0, pos]. Find the rightmost loud fine-chunk (= where audio ends).
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
            return last_loud_end  -- silence starts here
        end
        pos = t0
    end
    return item_start
end

-- Scan rightward from start_pos to find the left edge of the audio block to the right.
local function scanRight(accessor, samplerate, nch, start_pos, item_end, threshold)
    local coarse_sec = COARSE_CHUNK_MS / 1000
    local fine_sec   = FINE_CHUNK_MS   / 1000

    local pos = start_pos
    while pos < item_end do
        local t1 = math.min(pos + coarse_sec, item_end)
        local n  = math.floor((t1 - pos) * samplerate)
        if n > 0 and peakInRange(accessor, samplerate, nch, pos, n) > threshold then
            -- Audio found in [pos, t1]. Find the leftmost loud fine-chunk (= where audio begins).
            local rp = pos
            while rp < t1 do
                local rt1 = math.min(rp + fine_sec, t1)
                local rn  = math.floor((rt1 - rp) * samplerate)
                if rn > 0 and peakInRange(accessor, samplerate, nch, rp, rn) > threshold then
                    return rp  -- silence ends here
                end
                rp = rt1
            end
            return pos  -- fallback to coarse boundary
        end
        pos = t1
    end
    return item_end
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

    -- No item under cursor: silently exit (the Insert/Advance scripts are harmless when
    -- called with nothing to follow up on).
    if not item or not take then return end

    local source     = reaper.GetMediaItemTake_Source(take)
    local samplerate = reaper.GetMediaSourceSampleRate(source)
    local nch        = reaper.GetMediaSourceNumChannels(source)
    if samplerate <= 0 or nch <= 0 then return end

    local item_pos  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end  = item_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local threshold = dbToLinear(THRESHOLD_DB)

    -- Clamp scan start to item interior
    local scan_pos = math.max(item_pos + 0.001, math.min(cursor_time, item_end - 0.001))

    local accessor = reaper.CreateTakeAudioAccessor(take)

    -- Gate: is the cursor actually in a silence region?
    local check_n     = math.max(1, math.floor(samplerate * FINE_CHUNK_MS / 1000))
    local center_peak = peakInRange(accessor, samplerate, nch, scan_pos, check_n)
    if center_peak > threshold then
        reaper.DestroyAudioAccessor(accessor)
        reaper.ShowConsoleMsg("[JK RoomTone] Cursor is over audio (above " .. THRESHOLD_DB .. " dB threshold) — nothing done.\n")
        return
    end

    local left_bound  = scanLeft (accessor, samplerate, nch, scan_pos, item_pos, threshold)
    local right_bound = scanRight(accessor, samplerate, nch, scan_pos, item_end, threshold)
    reaper.DestroyAudioAccessor(accessor)

    if right_bound - left_bound < 0.010 then
        reaper.ShowConsoleMsg("[JK RoomTone] Silence region too short (< 10 ms) — nothing done.\n")
        return
    end

    -- Determine delete boundaries, preserving PAD_MS on each side
    local pad_sec       = PAD_MS       / 1000
    local crossfade_sec = CROSSFADE_MS / 1000
    local left_split    = left_bound  + pad_sec
    local right_split   = right_bound - pad_sec

    -- If silence is shorter than 2× pad, delete only the very centre (1 ms each side)
    if right_split <= left_split + 0.001 then
        local mid   = (left_bound + right_bound) / 2
        left_split  = mid - 0.001
        right_split = mid + 0.001
    end

    local track = reaper.GetMediaItemTrack(item)

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- Split at left_split  → item  = [item_start … left_split]
    --                       → temp = [left_split … item_end]
    local temp = reaper.SplitMediaItem(item, left_split)
    if not temp then
        reaper.PreventUIRefresh(-1)
        reaper.Undo_EndBlock("JK RoomTone DetectAndDelete (aborted)", -1)
        reaper.ShowConsoleMsg("[JK RoomTone] Split failed at left boundary.\n")
        return
    end

    -- Split at right_split → temp       = [left_split  … right_split]  (silence chunk)
    --                      → right_item = [right_split … item_end]
    local right_item = reaper.SplitMediaItem(temp, right_split)

    -- Delete the silence chunk; with ripple ON, right_item shifts left
    reaper.DeleteTrackMediaItem(track, temp)

    -- Soft fades at the edges of the surrounding content
    if crossfade_sec > 0 then
        reaper.SetMediaItemInfo_Value(item,       "D_FADEOUTLEN", crossfade_sec)
        if right_item then
            reaper.SetMediaItemInfo_Value(right_item, "D_FADEINLEN",  crossfade_sec)
        end
    end

    -- Position cursor and select track for the Insert script
    reaper.SetEditCurPos(left_split, false, false)
    reaper.SetOnlyTrackSelected(track)

    -- Persist insertion point so Insert script can verify position if needed
    reaper.SetExtState(EXT_NS, "insert_pos", string.format("%.6f", left_split), false)

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("JK RoomTone: detect and delete silence", -1)
end

main()
