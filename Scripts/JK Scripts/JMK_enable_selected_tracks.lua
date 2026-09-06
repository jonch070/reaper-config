-- JMK_enable_selected_tracks.lua  (REAPER ReaScript)
-- Enable the SELECTED tracks: all FX online (normal + input chain) and show in TCP/MCP.
-- This is the "enable" action Ensembler calls on offline ensemble tracks.
-- After installing, copy this action's command ID and paste it into
-- Ensembler/modules/ReaperTracks.lua line ~295 (replacing Nate's hardcoded ID).

reaper.Undo_BeginBlock()
local n = reaper.CountSelectedTracks(0)
for i = 0, n - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  for fx = 0, reaper.TrackFX_GetCount(tr) - 1 do
    reaper.TrackFX_SetOffline(tr, fx, false)                 -- normal FX online
  end
  for fx = 0, reaper.TrackFX_GetRecCount(tr) - 1 do
    reaper.TrackFX_SetOffline(tr, 0x1000000 + fx, false)     -- input FX online
  end
  reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", 1)
  reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINMIXER", 1)
  -- Optional (Nate also unlocks here): add a track-unlock step if you lock your palette.
end
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("JMK: Enable selected tracks (FX online + show)", -1)
