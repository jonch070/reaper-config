dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

hwnd = ultraschall.GetVideoHWND()
retval, left, top, right, bottom = reaper.JS_Window_GetClientRect(hwnd)
ultraschall.CaptureScreenAreaAsPNG("/Users/jonathankawchuk/Downloads/tempvideo2.png", left, top, right-left, bottom-top)
