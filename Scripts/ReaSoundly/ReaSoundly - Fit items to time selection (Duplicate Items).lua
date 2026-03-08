local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
dofile(script_path .. '/ReaSoundly - Fit Items to Time Selection.lua')

ExecuteScript(true)