-- get the number of selected tracks
num_sel_tracks = reaper.CountSelectedTracks(0)

-- loop through each selected track
for i = 0, num_sel_tracks-1 do
  -- get the i-th selected track
  track = reaper.GetSelectedTrack(0, i)

  -- get the parent track
  parent_track = reaper.GetParentTrack(track)

  -- get the name of the parent track, or "Master" if there is no parent track
  if parent_track ~= nil then
    _, parent_track_name = reaper.GetSetMediaTrackInfo_String(parent_track, "P_NAME", "", false)
  else
    parent_track_name = "Master"
  end

  -- get the current name of the track
  _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", true)

  -- get the original name of the track
  _, original_track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

  -- prepend parent track name and underscore to track name
  new_track_name = parent_track_name .. "_" .. track_name

  -- append original track name after the underscore
  new_track_name = new_track_name .. "_" .. original_track_name

  -- set the new track name
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", new_track_name, true)
end

