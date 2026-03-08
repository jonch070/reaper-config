local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

files = ReaSoundly.GetFiles()
items = ReaSoundly.CacheSelectedItems()

reaper.Undo_BeginBlock2(0)

-- Cache take names and marker lengths
local marker_lengths = ReaSoundly.CacheMarkerLengths(items, files)

reaper.Main_OnCommand(40224, 0) -- Take: Explode takes of items across tracks
-- delete the original items, and move all items up by one
for _, item in pairs(items) do
  local track = reaper.GetMediaItemTrack(item)
  reaper.DeleteTrackMediaItem(track, item)
end
reaper.Main_OnCommand(40117, 0) -- Item edit: Move items/envelope points up one track/a bit

for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  -- iterate each item and apply marker lengths to the new items
  local item = reaper.GetSelectedMediaItem(0, i)
  local take_name = reaper.GetTakeName(reaper.GetActiveTake(item))

  local length = table.remove(marker_lengths[take_name], 1)

  if length then reaper.SetMediaItemLength(item, length, false) end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
