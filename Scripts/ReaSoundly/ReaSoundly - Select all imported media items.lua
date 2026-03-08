local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

files = ReaSoundly.GetFiles()
local ids = ReaSoundly.CacheImportedItemsById(files)
ReaSoundly.SelectItemsById(ids, true)
