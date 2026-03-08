local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

files = ReaSoundly.GetFiles()
items = ReaSoundly.CacheSelectedItems()
ReaSoundly.SetItemsSelected(items, false)

reaper.Undo_BeginBlock2(0)

ReaSoundly.LoadSettings()

for _, item in pairs(items) do
  -- skip if item already has takes
  if reaper.CountTakes(item) == 1 then
    local file, take = ReaSoundly.FindTakeInFiles(files, item)

    if file then
      -- Set take offset to 0 if only one item is imported
      if #files == 1 then
        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", 0)
        reaper.SetMediaItemLength(item, file.audioFileDuration, false)
      end

      local splits = ReaSoundly.SplitItemBySegments(item, file)
      if splits then
        ReaSoundly.SetItemsSelected(splits, true)
        reaper.Main_OnCommand(40543, 0) -- Take: Implode items on same track into takes
        ReaSoundly.SetItemsSelected(items, false)
      end
    end
  end
end

-- Reselect all items
ReaSoundly.SetItemsSelected(items, true)

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
