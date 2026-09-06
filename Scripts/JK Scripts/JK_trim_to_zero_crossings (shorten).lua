--[[
  Trim selected items to nearest zero crossings (shorten both sides).
  For each selected media item, moves the start later and the end earlier to the
  nearest interior zero crossing of the take's audio. Shorten only - never extends.
  Click-free edits without fades.

  Install: Actions > Show action list > New action > Load ReaScript... > pick this file.
  Tweak MAX_TRIM_MS below if needed.
]]--

local MAX_TRIM_MS = 30   -- max distance (ms) to search inward for a zero crossing per edge

local function find_zero_crossing(take, edge_time_in_take, sr, search_s, direction)
  -- direction: +1 search forward from edge (for start), -1 search backward (for end)
  local n = math.floor(search_s * sr)
  if n < 2 then return 0 end
  local acc = reaper.CreateTakeAudioAccessor(take)
  local nch = reaper.GetMediaSourceNumChannels(reaper.GetMediaItemTake_Source(take))
  if nch < 1 then nch = 1 end
  local buf = reaper.new_array(n * nch)
  buf.clear()
  local start_t = (direction > 0) and edge_time_in_take or (edge_time_in_take - search_s)
  reaper.GetAudioAccessorSamples(acc, sr, nch, start_t, n, buf)

  local prev, found_offset = nil, nil
  for i = 0, n - 1 do
    -- index sweeps in real time order; for end-edge we want the LAST crossing
    local idx = i
    local s = buf[idx * nch + 1] or 0   -- channel 1 (mono / left)
    if prev ~= nil then
      if (prev <= 0 and s > 0) or (prev >= 0 and s < 0) then
        local t = start_t + (idx / sr)            -- crossing time in take
        if direction > 0 then
          found_offset = t - edge_time_in_take     -- first crossing after start
          break
        else
          found_offset = t - edge_time_in_take     -- keep updating -> last before end
        end
      end
    end
    prev = s
  end
  reaper.DestroyAudioAccessor(acc)
  return found_offset or 0
end

local cnt = reaper.CountSelectedMediaItems(0)
if cnt == 0 then
  reaper.ShowMessageBox("Select one or more media items first.", "Trim to zero crossings", 0)
  return
end

reaper.Undo_BeginBlock()
local search_s = MAX_TRIM_MS / 1000
local trimmed = 0

for i = 0, cnt - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  if take and not reaper.TakeIsMIDI(take) then
    local src = reaper.GetMediaItemTake_Source(take)
    local sr = reaper.GetMediaSourceSampleRate(src)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local soffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if rate <= 0 then rate = 1 end

    -- edges expressed in take/source time
    local start_in_take = soffs
    local end_in_take = soffs + len * rate

    local head = find_zero_crossing(take, start_in_take, sr, search_s, 1)   -- >=0
    local tail = find_zero_crossing(take, end_in_take, sr, search_s, -1)    -- <=0
    if head < 0 then head = 0 end
    if tail > 0 then tail = 0 end

    -- convert take-time deltas to project-time using playrate
    local new_pos = pos + (head / rate)
    local new_len = len + (tail / rate) - (head / rate)
    if new_len > 0.0005 then
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", soffs + head)
      trimmed = trimmed + 1
    end
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Trim items to nearest zero crossings", -1)
reaper.ShowMessageBox("Trimmed " .. trimmed .. " of " .. cnt .. " item(s).", "Trim to zero crossings", 0)
