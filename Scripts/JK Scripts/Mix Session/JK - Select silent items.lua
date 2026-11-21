-- @description Select silent audio items (peak below a threshold). Uses the selected items, or all items if none are selected.
-- @author Jonathan Kawchuk (generated with Claude)
-- Reads the actual audio, so it is exact (a silent stem is digital zero or below the threshold),
-- and works in short slices so REAPER stays responsive on a big session. Early-exits on the first
-- loud sample, so only genuinely silent items are read to the end.
local SECTION = "JK_SilentItems"
local BLOCK = 65536     -- samples per channel per read
local BUDGET = 0.03     -- seconds of work per defer cycle

local last = reaper.GetExtState(SECTION, "db")
local ok, csv = reaper.GetUserInputs("Select silent items", 1, "Silent if peak is below (dBFS),extrawidth=80", last ~= "" and last or "-80")
if not ok then return end
local db = tonumber(csv)
if not db then reaper.ShowMessageBox("Enter a number in dBFS, e.g. -80.", "Select silent items", 0) return end
reaper.SetExtState(SECTION, "db", tostring(db), true)
local thr = 10 ^ (db / 20)

-- items to examine
local items, use_selection = {}, reaper.CountSelectedMediaItems(0) > 0
if use_selection then
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do items[#items + 1] = reaper.GetSelectedMediaItem(0, i) end
else
    for i = 0, reaper.CountMediaItems(0) - 1 do items[#items + 1] = reaper.GetMediaItem(0, i) end
end
if #items == 0 then reaper.ShowMessageBox("No items.", "Select silent items", 0) return end

local silent, skipped, idx = {}, 0, 0
local cur -- { item, acc, sr, nch, pos, t1 }

local function finish()
    reaper.Undo_BeginBlock()
    reaper.SelectAllMediaItems(0, false)
    for _, it in ipairs(silent) do reaper.SetMediaItemSelected(it, true) end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Select silent items", -1)
    reaper.ShowMessageBox(string.format("%d of %d items are silent (peak below %g dBFS) and are now selected.%s",
        #silent, #items - skipped, db, skipped > 0 and ("\n" .. skipped .. " items skipped (MIDI, empty or unreadable).") or ""),
        "Select silent items", 0)
end

local function open_next()
    while idx < #items do
        idx = idx + 1
        local item = items[idx]
        local take = reaper.GetActiveTake(item)
        if not take or reaper.TakeIsMIDI(take) then
            skipped = skipped + 1
        else
            local src = reaper.GetMediaItemTake_Source(take)
            local sr = src and reaper.GetMediaSourceSampleRate(src) or 0
            local nch = src and reaper.GetMediaSourceNumChannels(src) or 0
            local acc = reaper.CreateTakeAudioAccessor(take)
            if acc and sr > 0 and nch > 0 then
                local t0, t1 = reaper.GetAudioAccessorStartTime(acc), reaper.GetAudioAccessorEndTime(acc)
                if t1 > t0 then
                    cur = { item = item, acc = acc, sr = sr, nch = nch, pos = t0, t1 = t1, buf = reaper.new_array(BLOCK * nch) }
                    return true
                end
                reaper.DestroyAudioAccessor(acc)
            elseif acc then
                reaper.DestroyAudioAccessor(acc)
            end
            skipped = skipped + 1
        end
    end
    return false
end

local function step()
    local t_end = reaper.time_precise() + BUDGET
    while reaper.time_precise() < t_end do
        if not cur and not open_next() then finish() return end
        local n = math.min(BLOCK, math.ceil((cur.t1 - cur.pos) * cur.sr))
        if n <= 0 then
            silent[#silent + 1] = cur.item -- reached the end without a loud sample
            reaper.DestroyAudioAccessor(cur.acc)
            cur = nil
        else
            cur.buf.clear()
            local r = reaper.GetAudioAccessorSamples(cur.acc, cur.sr, cur.nch, cur.pos, n, cur.buf)
            local loud = false
            if r == 1 then
                local t = cur.buf.table(1, n * cur.nch)
                for i = 1, #t do
                    local v = t[i]
                    if v > thr or v < -thr then loud = true break end
                end
            end
            if loud then
                reaper.DestroyAudioAccessor(cur.acc)
                cur = nil
            else
                cur.pos = cur.pos + n / cur.sr
            end
        end
    end
    reaper.defer(step)
end

reaper.defer(step)
