local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')
peak_marker = "-PEAK"

files = ReaSoundly.GetFiles()
items = ReaSoundly.CacheSelectedItems()
ReaSoundly.SetItemsSelected(items, false)

reaper.Undo_BeginBlock2(0)

for _, item in pairs(items) do
  local file = ReaSoundly.FindTakeInFiles(files, item)

  if file then
    local cur_pos = reaper.GetCursorPositionEx(0)
    local found = false

    for i = 1, #file.markers do
      local marker = file.markers[i]
  
      for time, marker_name in pairs(marker) do
        local time = tonumber(time)
        if marker_name == peak_marker and time > 0 then
          if cur_pos - time < 0 then
            reaper.SetEditCurPos(time, true, true)
          end
      
          reaper.SetMediaItemPosition(item, cur_pos - time, true)
          found = true
          break
        end
      end

      if found then break end
    end
  end
end

-- Reselect all items
ReaSoundly.SetItemsSelected(items, true)

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
