-- JK_TrimSilenceSelectedItems.lua
-- Trims leading and trailing silence from all selected media items.
-- Scans from the start of each item inward to find the first audio transient,
-- and from the end inward to find the last. Adjusts item boundaries accordingly.
--
-- This is a standalone script — NOT part of the room-tone macro chain.
-- It is useful for tightening items before or after room-tone replacement,
-- or as a general-purpose cleanup tool.
--
-- How trimming works in REAPER:
--   Trimming the START: advances D_POSITION and D_STARTOFFS by the same amount,
--                       shortens D_LENGTH — source audio is preserved, just hidden.
--   Trimming the END:   shortens D_LENGTH — same principle.
--
-- Ripple edit: the script moves item start points, which DOES shift item positions.
-- If ripple is ON, downstream items will shift. Run with ripple OFF if you want
-- items to stay in place while their edges are trimmed inward.

-- ============================================================
-- CONFIG
-- ============================================================
-- Threshold is shared with JK_RoomTone_DetectAndDelete.
-- Run JK_RoomTone_Settings.lua to change it (persists across sessions).
-- The fallback value below is used only if Settings has never been run.
local _stored_db      = tonumber(reaper.GetExtState("JK_RoomTone", "threshold_db"))
local THRESHOLD_DB    = _stored_db or -60   -- dB below which audio is silence

local PAD_MS          = 10      -- ms of silence left at each trimmed edge (softens clicks)
local COARSE_CHUNK_MS = 50      -- first-pass scan resolution
local FINE_CHUNK_MS   = 2       -- boundary refinement resolution

-- ============================================================
-- HELPERS
-- ============================================================
local function dbToLinear(db)
    return 10 ^ (db / 20)
end

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

-- Scan from item_start rightward; returns project-time of first audio onset.
local function findAudioStart(accessor, samplerate, nch, item_start, item_end, threshold)
    local coarse_sec = COARSE_CHUNK_MS / 1000
    local fine_sec   = FINE_CHUNK_MS   / 1000
    local pos = item_start
    while pos < item_end do
        local t1 = math.min(pos + coarse_sec, item_end)
        local n  = math.floor((t1 - pos) * samplerate)
        if n > 0 and peakInRange(accessor, samplerate, nch, pos, n) > threshold then
            -- Refine: find leftmost loud fine-chunk
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
    return item_end  -- entire item is silent
end

-- Scan from item_end leftward; returns project-time where audio last ends.
local function findAudioEnd(accessor, samplerate, nch, item_start, item_end, threshold)
    local coarse_sec = COARSE_CHUNK_MS / 1000
    local fine_sec   = FINE_CHUNK_MS   / 1000
    local pos = item_end
    while pos > item_start do
        local t0 = math.max(pos - coarse_sec, item_start)
        local n  = math.floor((pos - t0) * samplerate)
        if n > 0 and peakInRange(accessor, samplerate, nch, t0, n) > threshold then
            -- Refine: scan [t0, pos] left-to-right; find rightmost loud fine-chunk
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
    return item_start  -- entire item is silent
end

-- ============================================================
-- MAIN
-- ============================================================
local function main()
    local sel_count = reaper.CountSelectedMediaItems(0)
    if sel_count == 0 then
        reaper.ShowConsoleMsg("[JK TrimSilence] No items selected.\n")
        return
    end

    local threshold = dbToLinear(THRESHOLD_DB)
    local pad_sec   = PAD_MS / 1000
    local trimmed   = 0
    local skipped   = 0

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for i = 0, sel_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if not take then
            skipped = skipped + 1
            goto continue
        end

        local source     = reaper.GetMediaItemTake_Source(take)
        local samplerate = reaper.GetMediaSourceSampleRate(source)
        local nch        = reaper.GetMediaSourceNumChannels(source)
        if samplerate <= 0 or nch <= 0 then
            skipped = skipped + 1
            goto continue
        end

        local item_pos    = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end    = item_pos + item_length
        local start_offs  = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

        local accessor = reaper.CreateTakeAudioAccessor(take)

        local audio_start = findAudioStart(accessor, samplerate, nch, item_pos, item_end, threshold)
        local audio_end   = findAudioEnd  (accessor, samplerate, nch, item_pos, item_end, threshold)

        reaper.DestroyAudioAccessor(accessor)

        -- Apply pad: back off slightly from the detected boundary
        local new_item_start = math.max(item_pos,  audio_start - pad_sec)
        local new_item_end   = math.min(item_end,  audio_end   + pad_sec)

        -- Skip if audio_start >= audio_end (item is entirely silent or something went wrong)
        if audio_start >= audio_end then
            reaper.ShowConsoleMsg("[JK TrimSilence] Item " .. (i+1) .. " appears entirely silent — skipped.\n")
            skipped = skipped + 1
            goto continue
        end

        -- Skip if no trimming needed (within 1ms of current edges)
        local trim_start = new_item_start - item_pos
        local trim_end   = item_end - new_item_end
        if trim_start < 0.001 and trim_end < 0.001 then
            goto continue
        end

        -- Apply start trim: advance position and source offset together
        if trim_start > 0.001 then
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_start)
            reaper.SetMediaItemInfo_Value(item, "D_LENGTH",   item_length - trim_start)
            reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", start_offs + trim_start)
            -- Reread length for end trim
            item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        end

        -- Apply end trim: shorten length
        if trim_end > 0.001 then
            reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_length - trim_end)
        end

        reaper.UpdateItemInProject(item)
        trimmed = trimmed + 1

        ::continue::
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("JK TrimSilence: trim " .. trimmed .. " item(s)", -1)

    reaper.ShowConsoleMsg(
        "[JK TrimSilence] Done — trimmed: " .. trimmed ..
        (skipped > 0 and ("  |  skipped: " .. skipped) or "") .. "\n")
end

main()
