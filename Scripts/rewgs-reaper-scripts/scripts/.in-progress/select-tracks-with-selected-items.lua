original_action = reaper.GetMouseModifier("MM_CTX_ITEM", 0)
-- reaper.ShowConsoleMsg(original_action)
reaper.SetMouseModifier("MM_CTX_ITEM_CLK", 0, 0)

-- num_tracks = reaper.GetNumTracks()
-- for i = 0, num_tracks - 1 do
--     track = reaper.GetTrack(0, i)
--     num_items = reaper.GetTrackNumMediaItems(track)

--     for j = 0, num_items - 1 do
--         item = reaper.GetMediaItem(0, j)

--         if reaper.IsMediaItemSelected(item) then
--             reaper.SetTrackSelected(track, true)
--         end
--     end
-- end

-- selected_item = reaper.GetSelectedMediaItem(0, 0)
-- reaper.ShowConsoleMsg(tostring(selected_item))
