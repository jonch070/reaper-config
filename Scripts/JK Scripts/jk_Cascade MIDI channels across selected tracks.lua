local track_count = reaper.CountSelectedTracks(0)
if track_count == 0 then
  reaper.ShowMessageBox("Select at least one track", "Error", 0)
  return
end

reaper.Undo_BeginBlock()

for i = 0, track_count - 1 do
  local track = reaper.GetSelectedTrack(0, i)
  local ch = (i % 16) + 1
  local current = reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT")

  if current >= 4096 then
    local base = current & (~31)
    reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", base | ch)
  end
end

reaper.Undo_EndBlock("Cascade MIDI channels across selected tracks", -1)
reaper.UpdateArrange()
