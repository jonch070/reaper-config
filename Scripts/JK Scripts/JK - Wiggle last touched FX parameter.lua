-- @description JK - Wiggle last touched FX parameter (random LFO around base value)
-- @version 1.0
-- @author JK
-- @website http://forum.cockos.com/showthread.php?t=188335

local DEFAULT_STRENGTH = 0.15
local DEFAULT_SPEED = 0.124573
local DEFAULT_TEMPO_SYNC = false
local DEFAULT_DIRECTION = 0
local DEFAULT_SHAPE = 5

local function get_track(tracknumber)
  local trid = tracknumber & 0xFFFF
  local itid = (tracknumber >> 16) & 0xFFFF
  if itid > 0 then return nil end
  if trid == 0 then return reaper.GetMasterTrack(0) end
  return reaper.GetTrack(0, trid - 1)
end

local function main()
  local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
  if not retval or fxnumber < 0 or paramnumber < 0 then
    reaper.ShowMessageBox('Touch a parameter on an FX first, then run again.', 'Wiggle', 0)
    return
  end
  local tr = get_track(tracknumber)
  if not tr then return end

  local cfg = 'param.' .. paramnumber .. '.'
  local ret_mod, mod_active = reaper.TrackFX_GetNamedConfigParm(tr, fxnumber, cfg .. 'mod.active')
  local ret_lfo, lfo_active = reaper.TrackFX_GetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.active')

  if ret_mod and ret_lfo and tonumber(mod_active) == 1 and tonumber(lfo_active) == 1 then
    reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'mod.active', '0')
    reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.active', '0')
    return
  end

  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'mod.active', '1')
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.active', '1')
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.shape', tostring(DEFAULT_SHAPE))
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.dir', tostring(DEFAULT_DIRECTION))
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.speed', tostring(DEFAULT_SPEED))
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.strength', tostring(DEFAULT_STRENGTH))
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.temposync', DEFAULT_TEMPO_SYNC and '1' or '0')
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.free', '0')
  reaper.TrackFX_SetNamedConfigParm(tr, fxnumber, cfg .. 'lfo.phase', '0.5')
end

reaper.Undo_BeginBlock2(0)
main()
reaper.Undo_EndBlock2(0, 'Wiggle last touched FX parameter', -1)
