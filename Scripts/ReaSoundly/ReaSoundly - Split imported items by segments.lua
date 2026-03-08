local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

files = ReaSoundly.GetFiles()
items = ReaSoundly.CacheSelectedItems()
ReaSoundly.SetItemsSelected(items, false)

reaper.Undo_BeginBlock2(0)

ReaSoundly.LoadSettings()

for _, item in pairs(items) do
  local file = ReaSoundly.FindTakeInFiles(files, item)
  aaa = file
  
  if file then
    ReaSoundly.SplitItemBySegments(item, file)
  end
end

-- Reselect all items
ReaSoundly.SetItemsSelected(items, true)

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
