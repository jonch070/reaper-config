local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

item_count = reaper.CountSelectedMediaItems(0)
_, marker_count = reaper.CountProjectMarkers(0)

start_sel, end_sel = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

reaper.Undo_BeginBlock2(0)

if item_count > 0 and marker_count > 0 then
  -- find all markers in time selection and save their positions in a table
  local markers = {}
  for i = 0, marker_count - 1 do
    local rv, isrgn, pos = reaper.EnumProjectMarkers(i)
    if not isrgn then
      if pos >= start_sel and pos <= end_sel then
        table.insert(markers, pos)
      end
    end
  end

  if #markers > 0 then
    -- cache all selected items per track in track_items table
    local track_items = {}

    for i = 0, item_count - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)

      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

      local track = reaper.GetMediaItemTrack(item)
      if not track_items[track] then
        track_items[track] = {}
      end
      table.insert(track_items[track], item)
    end
    -- unselect all media items
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items

    -- iterate items per track and align to markers in time selection
    for _, items in pairs(track_items) do
      local count = 0 -- count for passed markers
      -- set edit cursor to first marker
      local lap = 0
      reaper.SetEditCurPos(markers[1], true, true)

      for idx, cur_pos in ipairs(markers) do
        local item = items[idx - #items * lap]
        if lap > 0 then
          -- if there are more markers than items, duplicate with ApplyNudge to current marker positions
          reaper.SetMediaItemSelected(item, true)
          reaper.ApplyNudge(0, 1, 5, 1, cur_pos, false, 1)
          reaper.SetMediaItemSelected(item, false)
        else
          local item = items[idx]
          local offset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")

          reaper.SetMediaItemPosition(item, cur_pos - offset, true)
        end

        -- increase the lap for each idx MOD items passed
        if (idx % #items) == 0 then lap = lap + 1 end
      end
    end
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
