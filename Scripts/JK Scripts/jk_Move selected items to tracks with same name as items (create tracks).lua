-- @description Move selected items to tracks with same name as items (creates tracks if needed)
-- @version 1.0
-- @author JK

local function get_take_name_no_ext(take)
  local name = reaper.GetTakeName(take)
  local base = name:match('^(.+)%.[^%.]+$')
  return base or name
end

local function get_track_index(track)
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetTrack(0, i) == track then return i end
  end
  return nil
end

local function find_or_create_track(name, insert_idx)
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, tr_name = reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', '', false)
    if tr_name == name then return tr, insert_idx end
  end
  local idx = insert_idx or reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', name, true)
  return tr, idx + 1
end

local function main()
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then return end

  local items = {}
  for i = 0, item_count - 1 do
    items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
  end

  -- New tracks are created directly under the currently selected track,
  -- stacking in order; falls back to appending at the bottom of the
  -- session if no track is selected (the old behavior).
  local sel_track = reaper.GetSelectedTrack(0, 0)
  local next_insert_idx = sel_track and get_track_index(sel_track)
  next_insert_idx = next_insert_idx and (next_insert_idx + 1) or nil

  for i = 1, #items do
    local item = items[i]
    local take = reaper.GetActiveTake(item)
    if take then
      local name = get_take_name_no_ext(take)
      if name ~= '' then
        local tr, updated_idx = find_or_create_track(name, next_insert_idx)
        next_insert_idx = updated_idx
        if reaper.GetMediaItem_Track(item) ~= tr then
          reaper.MoveMediaItemToTrack(item, tr)
        end
      end
    end
  end

  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock('Move selected items to tracks with same name as items (create tracks)', -1)
