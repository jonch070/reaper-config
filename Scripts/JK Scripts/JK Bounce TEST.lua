-- @description JK Bounce - TEST
-- @author Jonathan Kawchuk
-- @version 2.0
-- @about
--   Save-point bounce for musical ideas.
--   Queues a WAV to ./bounces beside the session and (except TEST) an MP3
--   proxy into the Ideas and Sketches pool, then runs the render queue.
--
--   Uses the render queue rather than firing two renders back to back.
--   Direct renders are asynchronous, so v1.0 raced itself and produced two
--   MP3s in the pool and no WAV at all. Queue-adds are synchronous, so the
--   settings for each job are captured before the next one overwrites them.

------------------------------------------------------------------ config
local SUBTYPE   = "TEST"
local MAKE_POOL = false

local POOL_DIR  = "/Users/jonathankawchuk/Documents/Projects/Ideas and Sketches/_Proxies"
local LOCAL_DIR = "./bounces"

local WAV_FMT   = "ZXZhdxgAAA=="                                     -- WAV 24-bit
local MP3_FMT   = "bDNwbUABAAAAAAAACgAAAP////8EAAAAQAEAAAAAAAA="     -- MP3

local WAV_SRATE = 0        -- 0 = follow project rate
local MP3_SRATE = 48000

local WRITE_METADATA = true   -- harmless if the Embed>Metadata box is off

-- Action IDs. 41823 is confirmed. If the queue does not run, get the right
-- id via Actions window > right-click the action > Copy selected action ID.
local ACT_QUEUE_ADD  = 41823   -- File: Add project to render queue, using most recent render settings
local ACT_QUEUE_RUN  = 41207   -- File: Render all queued renders
local AUTO_RUN_QUEUE = true    -- false = just queue them, run the queue yourself
------------------------------------------------------------------------

local PATTERN = "$project_" .. SUBTYPE .. "_$year$month$day-$hour$minute"

local function setmeta(key, val)
  reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", key .. "|" .. val, true)
end

local function getstr(key)
  local _, v = reaper.GetSetProjectInfo_String(0, key, "", false)
  return v
end

local _, projfn = reaper.EnumProjects(-1)
if projfn == "" then
  reaper.MB("Save the project first.\n\n$project and ./bounces cannot resolve on an unsaved project.",
            "JK Bounce - " .. SUBTYPE, 0)
  return
end

local old = {
  fmt     = getstr("RENDER_FORMAT"),
  file    = getstr("RENDER_FILE"),
  pattern = getstr("RENDER_PATTERN"),
  srate   = reaper.GetSetProjectInfo(0, "RENDER_SRATE", 0, false),
  bounds  = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false),
}

if WRITE_METADATA then
  setmeta("ID3:TCON", SUBTYPE)
  setmeta("ID3:COMM", SUBTYPE .. " | $projectnotes")
  setmeta("ID3:TBPM", "$tempo")
  setmeta("BWF:Description", SUBTYPE .. " | $tempo bpm | $projectnotes")
end

-- time selection if there is one, otherwise the whole project
local ts_a, ts_b = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", (ts_b > ts_a) and 2 or 1, true)
reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", PATTERN, true)

-- queue 1: working WAV beside the session
reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", WAV_FMT, true)
reaper.GetSetProjectInfo_String(0, "RENDER_FILE", LOCAL_DIR, true)
reaper.GetSetProjectInfo(0, "RENDER_SRATE", WAV_SRATE, true)
reaper.Main_OnCommand(ACT_QUEUE_ADD, 0)

-- queue 2: MP3 proxy into the pool
if MAKE_POOL then
  reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", MP3_FMT, true)
  reaper.GetSetProjectInfo_String(0, "RENDER_FILE", POOL_DIR, true)
  reaper.GetSetProjectInfo(0, "RENDER_SRATE", MP3_SRATE, true)
  reaper.Main_OnCommand(ACT_QUEUE_ADD, 0)
end

-- put the render dialog back how we found it
reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", old.fmt, true)
reaper.GetSetProjectInfo_String(0, "RENDER_FILE", old.file, true)
reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", old.pattern, true)
reaper.GetSetProjectInfo(0, "RENDER_SRATE", old.srate, true)
reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", old.bounds, true)

if AUTO_RUN_QUEUE then reaper.Main_OnCommand(ACT_QUEUE_RUN, 0) end
