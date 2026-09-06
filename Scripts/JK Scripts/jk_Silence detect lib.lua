--[[
@description jk_Silence detect lib — shared silence-boundary helpers
@version 0.1
@about
  Library functions for finding the boundaries of silence around a position
  on the project timeline. NOT a runnable script on its own.

  Usage from another script:
    local lib = dofile(reaper.GetResourcePath() ..
      "/Scripts/JK Scripts/jk_Silence detect lib.lua")
    local left  = lib.find_silence_edge_left (pos, threshold_db, max_seconds)
    local right = lib.find_silence_edge_right(pos, threshold_db, max_seconds)

  Returns the timestamp where audio amplitude first exceeds the threshold,
  walking outward from `pos`. If no audio exceeds threshold within
  `max_seconds`, returns pos ± max_seconds.

  Reads the SUM of all tracks at the given position via a master-track
  audio accessor. So it picks up any item under the marker, regardless of
  which track it lives on.
]]--

local M = {}

local DEFAULT_WINDOW_SECONDS = 5.0   -- how far outward we'll walk by default
local CHUNK_SECONDS = 0.05           -- read in 50ms chunks
local DEFAULT_THRESHOLD_DB = -60.0


-- ── Helpers ─────────────────────────────────────────────────

local function db_to_amplitude(db)
  return 10 ^ (db / 20)
end


-- Return the SAMPLE block of the master mix between t_start and t_end.
-- Mono-summed for amplitude detection (we don't need stereo here).
local function read_samples_mono(t_start, t_end, sample_rate)
  if t_end <= t_start then return nil, 0 end
  -- Use master track (index -1) so we sum every track
  local accessor = reaper.CreateTrackAudioAccessor(reaper.GetMasterTrack(0))
  local nsamps_per_ch = math.floor((t_end - t_start) * sample_rate + 0.5)
  if nsamps_per_ch <= 0 then
    reaper.DestroyAudioAccessor(accessor)
    return nil, 0
  end
  local nch = 2  -- master is typically stereo; ask for 2 channels
  local buf = reaper.new_array(nsamps_per_ch * nch)
  buf.clear()
  local ok = reaper.GetAudioAccessorSamples(
    accessor, sample_rate, nch, t_start, nsamps_per_ch, buf
  )
  reaper.DestroyAudioAccessor(accessor)
  if ok ~= 1 then return nil, 0 end
  return buf, nsamps_per_ch
end


-- Scan a samples array for the first index whose absolute amplitude exceeds
-- threshold. Returns the sample-index relative to the buffer (1-based) or nil.
local function first_nonsilent_index(buf, nsamps_per_ch, nch, amplitude_threshold, reverse)
  if not buf or nsamps_per_ch == 0 then return nil end
  local total = nsamps_per_ch * nch
  if reverse then
    -- walk backwards through the buffer
    for i = nsamps_per_ch, 1, -1 do
      local s_idx = (i - 1) * nch
      for c = 1, nch do
        local v = buf[s_idx + c]
        if v < 0 then v = -v end
        if v > amplitude_threshold then return i end
      end
    end
  else
    for i = 1, nsamps_per_ch do
      local s_idx = (i - 1) * nch
      for c = 1, nch do
        local v = buf[s_idx + c]
        if v < 0 then v = -v end
        if v > amplitude_threshold then return i end
      end
    end
  end
  return nil
end


-- ── Public ──────────────────────────────────────────────────

-- Walk LEFT from `pos`, return the timestamp of the last non-silent sample.
-- (i.e. where speech ends before the silence we care about.)
function M.find_silence_edge_left(pos, threshold_db, max_seconds)
  threshold_db = threshold_db or DEFAULT_THRESHOLD_DB
  max_seconds = max_seconds or DEFAULT_WINDOW_SECONDS
  local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if sr <= 0 then sr = 48000 end
  local amp_thresh = db_to_amplitude(threshold_db)
  local nch = 2

  local cursor = pos
  local stop_at = pos - max_seconds
  while cursor > stop_at do
    local block_start = math.max(stop_at, cursor - CHUNK_SECONDS)
    local buf, n = read_samples_mono(block_start, cursor, sr)
    local hit = first_nonsilent_index(buf, n, nch, amp_thresh, true)
    if hit then
      -- hit is 1-based; convert to time
      local frac = hit / n
      return block_start + frac * (cursor - block_start)
    end
    cursor = block_start
  end
  return stop_at
end


-- Walk RIGHT from `pos`, return the timestamp of the first non-silent sample.
function M.find_silence_edge_right(pos, threshold_db, max_seconds)
  threshold_db = threshold_db or DEFAULT_THRESHOLD_DB
  max_seconds = max_seconds or DEFAULT_WINDOW_SECONDS
  local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if sr <= 0 then sr = 48000 end
  local amp_thresh = db_to_amplitude(threshold_db)
  local nch = 2

  local cursor = pos
  local stop_at = pos + max_seconds
  while cursor < stop_at do
    local block_end = math.min(stop_at, cursor + CHUNK_SECONDS)
    local buf, n = read_samples_mono(cursor, block_end, sr)
    local hit = first_nonsilent_index(buf, n, nch, amp_thresh, false)
    if hit then
      local frac = (hit - 1) / n
      return cursor + frac * (block_end - cursor)
    end
    cursor = block_end
  end
  return stop_at
end


-- Convenience: measure existing silence around `pos` (the gap from where
-- audio ends on the left side to where audio begins on the right side).
function M.measure_silence_at(pos, threshold_db, max_seconds)
  local left  = M.find_silence_edge_left (pos, threshold_db, max_seconds)
  local right = M.find_silence_edge_right(pos, threshold_db, max_seconds)
  return {
    silence_start = left,
    silence_end   = right,
    duration      = right - left,
    threshold_db  = threshold_db or DEFAULT_THRESHOLD_DB,
  }
end


return M
