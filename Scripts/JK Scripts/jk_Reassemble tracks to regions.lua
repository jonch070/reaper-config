-- @description Reassemble tracks back to sequential regions
-- @author Jonathan Kawchuk (generated)
-- @version 1.1
-- @about
--   Two modes:
--
--   MODE A - "Restore" (if tracks have stored region data from explode script):
--     Reads JK_REGION_START from each track's extended state.
--     Shifts all items back to their original positions.
--     Recreates the original region with name and color.
--     Moves all items to Track 1 (or first track).
--     Deletes the now-empty tracks.
--
--   MODE B - "Sequential" (if no stored data, or fresh tracks):
--     Goes through each track in order (top to bottom).
--     Places each track's items sequentially on the timeline
--     (track 1 at 0:00, track 2 after track 1 ends, etc.)
--     Creates a region for each track's span, named after the track.
--     Moves all items to Track 1.
--     Deletes the now-empty tracks.
--
--   Works with the companion script: jk_Explode regions to tracks.lua
--
--   THE POSITION RULE
--
--   Explode writes each item at its offset FROM THE REGION START: an item
--   sitting exactly on the region start becomes 0 on the exploded track.
--   Reassemble therefore just adds the region start back. Whatever offset an
--   item has on the exploded track is preserved, which is the whole point
--   once you start cropping.
--
--   Crop the head off an item and its position moves right — that is Reaper
--   trimming the left edge, not the audio moving. Trim 0.49s off the front
--   and the item now starts at 0.49 on the exploded track, so it belongs at
--   region_start + 0.49 when it goes back. The audio you kept stays exactly
--   where it always was, with silence where the trimmed head used to be.
--
-- @changelog
--   1.1 — Fix restore: cropped items were being dragged to the region start.
--          The offset was `stored_start - first_pos`, which normalises the
--          earliest item on the track to the region start. That is a no-op
--          while nothing has been cropped (first_pos is 0), and wrong the
--          moment a head is trimmed: an item cropped by 0.49s was pulled
--          0.49s early, taking every later item on that track with it.
--          The offset is now just `stored_start`.
--          Sequential mode had the same normalisation and is fixed the same
--          way, so a leading gap — head silence — is no longer swallowed.
--   1.0 — Initial.

function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local track_count = reaper.CountTracks(0)
  if track_count == 0 then
    reaper.ShowMessageBox("No tracks found.", "Reassemble", 0)
    return
  end

  -- Check if tracks have stored region data
  local has_stored_data = false
  for t = 0, track_count - 1 do
    local track = reaper.GetTrack(0, t)
    local retval, val = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:JK_REGION_START", "", false)
    if retval and val ~= "" then
      has_stored_data = true
      break
    end
  end

  -- Collect track info
  local tracks_data = {}
  for t = 0, track_count - 1 do
    local track = reaper.GetTrack(0, t)
    local retval_name, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local num_items = reaper.CountTrackMediaItems(track)

    if num_items > 0 then
      -- Get item range on this track
      local first_pos = math.huge
      local last_end = 0
      local items = {}

      for i = 0, num_items - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        first_pos = math.min(first_pos, pos)
        last_end = math.max(last_end, pos + len)
        table.insert(items, item)
      end

      -- Get stored region data if available
      local retval_start, stored_start = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:JK_REGION_START", "", false)
      local retval_end, stored_end = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:JK_REGION_END", "", false)
      local retval_color, stored_color = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:JK_REGION_COLOR", "", false)

      table.insert(tracks_data, {
        track = track,
        track_idx = t,
        name = name,
        items = items,
        first_pos = first_pos,
        last_end = last_end,
        -- Span measured from the track's 0, not from the first item. A gap
        -- before the first item is head silence and part of the region.
        span = last_end,
        stored_start = (retval_start and stored_start ~= "") and tonumber(stored_start) or nil,
        stored_end = (retval_end and stored_end ~= "") and tonumber(stored_end) or nil,
        stored_color = (retval_color and stored_color ~= "") and tonumber(stored_color) or nil,
      })
    end
  end

  if #tracks_data == 0 then
    reaper.ShowMessageBox("No tracks with items found.", "Reassemble", 0)
    return
  end

  -- Determine mode
  local mode = "sequential"
  if has_stored_data then
    local answer = reaper.ShowMessageBox(
      "Stored region positions found from a previous explode.\n\n" ..
      "YES = Restore to original positions\n" ..
      "NO = Place sequentially (ignore stored positions)",
      "Reassemble Mode", 3)
    if answer == 6 then
      mode = "restore"
    elseif answer == 2 then
      -- Cancel
      reaper.PreventUIRefresh(-1)
      return
    end
  end

  -- Create destination track at index 0
  reaper.InsertTrackAtIndex(0, false)
  local dest_track = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(dest_track, "P_NAME", "Reassembled", true)

  -- Sort tracks by stored position (restore) or by track order (sequential)
  if mode == "restore" then
    table.sort(tracks_data, function(a, b)
      local a_start = a.stored_start or 0
      local b_start = b.stored_start or 0
      return a_start < b_start
    end)
  end

  local cursor = 0  -- Running position for sequential mode
  local regions_created = 0

  for _, td in ipairs(tracks_data) do
    local offset

    if mode == "restore" and td.stored_start then
      -- Explode wrote positions relative to the region start, so adding it
      -- back is the whole restore. Do NOT subtract first_pos: that snaps
      -- whatever item happens to be earliest onto the region start, which
      -- silently undoes any head crop and drags the rest of the track with it.
      offset = td.stored_start
    else
      -- Sequential: this track's 0 goes after the previous track's span.
      offset = cursor
    end

    -- Move items to dest track and apply offset
    for _, item in ipairs(td.items) do
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      -- Track indices shifted by 1 because we inserted dest_track at 0
      reaper.MoveMediaItemToTrack(item, dest_track)
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + offset)
    end

    -- Create region
    local rgn_start, rgn_end, rgn_color

    if mode == "restore" and td.stored_start then
      -- The original region, not one refitted around the cropped items. The
      -- region is the chapter boundary; cropping trims audio inside it.
      rgn_start = td.stored_start
      rgn_end = td.stored_end or (td.stored_start + td.span)
      rgn_color = td.stored_color or 0
    else
      rgn_start = cursor
      rgn_end = cursor + td.span
      rgn_color = 0
    end

    reaper.AddProjectMarker2(0, true, rgn_start, rgn_end, td.name, -1, rgn_color)
    regions_created = regions_created + 1

    -- Advance cursor for sequential mode
    cursor = rgn_end
  end

  -- Delete the now-empty source tracks (go backwards, skip track 0 which is dest)
  -- Track indices shifted because we inserted at 0
  local total_tracks = reaper.CountTracks(0)
  for t = total_tracks - 1, 1, -1 do
    local track = reaper.GetTrack(0, t)
    local num_items = reaper.CountTrackMediaItems(track)
    if num_items == 0 then
      reaper.DeleteTrack(track)
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Reassemble tracks to regions", -1)

  reaper.ShowMessageBox(
    regions_created .. " tracks reassembled into regions.\n" ..
    "Mode: " .. mode .. "\n\n" ..
    "All items now on 'Reassembled' track.",
    "Reassemble", 0)
end

main()
