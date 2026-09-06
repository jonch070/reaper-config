-- JMK_disable_selected_tracks.lua  (REAPER ReaScript)
-- Disable the SELECTED tracks: all FX offline (normal + input chain) and hide from TCP/MCP.
-- Matches Ensembler's isTrackDisabled test (all normal FX offline = "disabled").
-- Use this to set your palette to disabled-by-default for fast template loading:
-- select the instrument tracks you want asleep, run this, then let Ensembler wake them on demand.

reaper.Undo_BeginBlock()
local n = reaper.CountSelectedTracks(0)
for i = 0, n - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  for fx = 0, reaper.TrackFX_GetCount(tr) - 1 do
    reaper.TrackFX_SetOffline(tr, fx, true)                  -- normal FX offline
  end
  for fx = 0, reaper.TrackFX_GetRecCount(tr) - 1 do
    reaper.TrackFX_SetOffline(tr, 0x1000000 + fx, true)      -- input FX offline
  end
  reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", 0)
  reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINMIXER", 0)
  -- Optional (Nate also locks here): add a track-lock step to prevent accidental edits.
end
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("JMK: Disable selected tracks (FX offline + hide)", -1)
