--new window title
title = "- LBXAnalyzer -"
plugname = 'JS: gfxanalyzer'
oplugname = ''

plugname = reaper.GetExtState('LBXANALYZER','ANALYZERNAME') or ''
if plugname == 'Off' or plugname == '' then
  plugname = 'JS: gfxanalyzer'
end

--add analyzer plugin to selected track
--reaper.TrackFX_AddByName(reaper.GetSelectedTrack2(0,0,true),'gfxanalyzer',false,1)

--obtain analyzer plugin hwnd and get size
win2 = reaper.JS_Window_Find(plugname,false)
--reaper.ShowConsoleMsg('start  '..plugname..'  '..tostring(win2)..'\n')

rt,l,t,r,b = reaper.JS_Window_GetClientRect(win2)
winOff = 25
winW,winH=r-l,b-t-winOff

--create window for plugin gui duplication
window = reaper.JS_Window_Create(title, "myClass", 120, 120, winW, winH, "POPUP,DISABLED,MINIMIZE,EX_TRANSPARENT")

--create bitmap for compositing to new window (big enough to cope with gui reizing)
--bm = reaper.JS_LICE_CreateBitmap(true, 2048, 2048)

--link bitmap to new window
--reaper.JS_Composite(window, 0, 0, winW, winH, bm, 0, 0, winW, winH)

function loop()
  --check hwnds valid
  if reaper.ValidatePtr(window, "HWND") then
    plugname = reaper.GetExtState('LBXANALYZER','ANALYZERNAME') or ''
    --reaper.ShowConsoleMsg('check  '..plugname..'  '..tostring(win2)..'\n')
    if plugname == 'Off' then exit() end
    if plugname ~= oplugname then
      rescan = reaper.time_precise()
      oplugname = plugname
    end
    if (rescan and reaper.time_precise() >= rescan) or not reaper.ValidatePtr(win2, "HWND") then
      --plug hwnd not valid - search for plugin gui every 0.5 seconds
      if not nextcheck then
        nextcheck = reaper.time_precise()+0.2
      end
      if reaper.time_precise() > nextcheck or rescan then
        win2 = reaper.JS_Window_Find(plugname,false)
        --reaper.ShowConsoleMsg(plugname..'\n')
        nextcheck = reaper.time_precise()+0.2
      end
      rescan = nil
    elseif reaper.ValidatePtr(win2, "HWND") --[[and not plugname == 'Idle']] then
    
      --check if plugin gui has changed dimensions - 
      local _,_,ww,hh = GetBounds(win2)
      if ww ~= winW or hh ~= winH then
        winW = ww
        winH = hh-winOff
        --reaper.JS_Composite_Unlink(win2, bm)
        --reaper.JS_Composite(window, 0, 0, winW, winH, bm, 0, 0, winW, winH)                
      end
      --reaper.ShowConsoleMsg(winW..'  '..winH)
      if plugname ~= idle then
        hDC = reaper.JS_GDI_GetWindowDC(window)
        hDC2 = reaper.JS_GDI_GetClientDC(win2)
        --hDC3 = reaper.JS_LICE_GetDC(bm)
  
        --reaper.JS_GDI_Blit(hDC3,0,0,hDC,0,winOff,winW,winH,"SRCCOPY")      
        reaper.JS_GDI_Blit(hDC,0,0,hDC2,0,winOff,winW,winH,"SRCCOPY")      
  
        reaper.JS_Window_InvalidateRect(window, 0, 0, winW, winH, true)
        reaper.JS_GDI_ReleaseDC(window, hDC)
        reaper.JS_GDI_ReleaseDC(win2, hDC2)
        --reaper.JS_GDI_ReleaseDC(bm, hDC3)
      end
    end
    reaper.defer(loop)
  end
end

function GetBounds(hwnd)
  local _, left, top, right, bottom = reaper.JS_Window_GetClientRect(hwnd)
  return left, top, right-left, bottom-top
end
 
function exit()
  --reaper.ShowConsoleMsg(tostring(hDC))
  --reaper.ShowConsoleMsg('exit')
  
  reaper.JS_GDI_ReleaseDC(window, hDC)
  reaper.JS_GDI_ReleaseDC(win2, hDC2)
  if win2 and bm then
    --reaper.JS_Composite_Unlink(win2, bm)
  end
  reaper.JS_Window_Destroy(window) 
  --reaper.JS_LICE_DestroyBitmap(bm)
end

reaper.atexit(exit)

loop()
