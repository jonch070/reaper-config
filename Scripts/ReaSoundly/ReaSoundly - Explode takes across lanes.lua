local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

files = ReaSoundly.GetFiles()
items = ReaSoundly.CacheSelectedItems()

reaper.Undo_BeginBlock2(0)

-- Cache take names and marker lengths
local marker_lengths = ReaSoundly.CacheMarkerLengths(items, files)

reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SELTRKWITEM"), 0) -- SWS: Select only track(s) with selected item(s)
reaper.Main_OnCommand(42635, 0) -- Take: Explode takes on selected tracks to fixed lanes

for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  -- iterate each item and apply marker lengths from table based on the lane idx
  local item = reaper.GetSelectedMediaItem(0, i)
  local take_name = reaper.GetTakeName(reaper.GetActiveTake(item))
  local lane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE") + 1
  local length = marker_lengths[take_name][lane]

  if length then reaper.SetMediaItemLength(item, length, false) end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
