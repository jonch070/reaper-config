-- Toggle_Record_Disable_Selected_Tracks.lua
-- Toggles track record mode between disabled (-1) and input (0) on selected tracks.
-- Tracks stay armed for monitoring but won’t print when disabled.

local proj = 0
local num = reaper.CountSelectedTracks(proj)
if num == 0 then return end

reaper.Undo_BeginBlock()
for i = 0, num-1 do
  local tr = reaper.GetSelectedTrack(proj, i)
  local mode = reaper.GetMediaTrackInfo_Value(tr, "I_RECMODE")
  if mode == -1 then
    reaper.SetMediaTrackInfo_Value(tr, "I_RECMODE", 0)  -- back to normal input
  else
    reaper.SetMediaTrackInfo_Value(tr, "I_RECMODE", -1) -- disable (input monitoring only)
  end
end
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Toggle record disable on selected tracks", -1)

