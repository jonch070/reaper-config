
  local multitouch = {}
  
  multitouch.ohwnd_set = false
  multitouch.overlayhwnd = nil
  multitouch.active = false
  multitouch.vkeys = {key = {}, idx = {}, idx2 = {}, repeatdelay = {}}
  multitouch.keytranslate = {}
  multitouch.keytranslate_mod = {}
  --multitouch.adjust = {x = 0, y = 0}
  multitouch.offset = 0
  multitouch.offsetv = 0
  multitouch.space = 1
  multitouch.try = 0
  multitouch.overlayfn = ''
  multitouch.init = true
  
  multitouch.overlay_window = "LBX_Overlay"
  multitouch.parent_window = ""

  local mw_lastid, nocalib_msg, calib_error_msg

  function multitouch.Init(fn)
    --DBG('Initializing')
    
    if reaper.file_exists(fn) then
      for line in io.lines(fn) do
        local idx, val = string.match(line,'^%[(.+)%](.*)') --decipher(line)
        if idx then
          multitouch[idx] = tonumber(val) or val
        end
      end
    else
      DBG('MultiTouch: Init data file not found!')
    end
    multitouch.FindParent()
  end
  
  function multitouch.FindParent(wintitle)
    wintitle = multitouch.parent_window
    multitouch.whwnd = reaper.JS_Window_Find(wintitle,true)
    return multitouch.whwnd
  end

  function multitouch.IsLoaded()
    local ohwnd = reaper.JS_Window_Find(multitouch.overlay_window,true)
    if ohwnd then
      return true
    end
  end
  
  function multitouch.LoadOverlay(fn)
    --local fn = reaper.GetResourcePath() ..'\\Scripts\\LBX\\TouchInputData\\LBXTouchOverlay.exe'
    multitouch.overlayfn = fn
    if reaper.file_exists(fn) then
      reaper.CF_ShellExecute(fn)
      multitouch.calibrate_timer = reaper.time_precise()+1.5
    else
      reaper.ShowConsoleMsg('Cannot find overlay executable.')
    end
    
  end
  
  function multitouch.LoadKeymap(fn)
    multitouch.keytranslate = {}
    multitouch.keytranslate_mod = {}
    multitouch.keytranslate_mod['CSA'] = {}
    multitouch.keytranslate_mod['CS'] = {}
    multitouch.keytranslate_mod['CA'] = {}
    multitouch.keytranslate_mod['SA'] = {}
    multitouch.keytranslate_mod['A'] = {}
    multitouch.keytranslate_mod['C'] = {}
    multitouch.keytranslate_mod['S'] = {}
    
    --local fn = reaper.GetResourcePath()..'/Scripts/LBX/TouchInputData/keydata.txt'
    if reaper.file_exists(fn) then
      for line in io.lines(fn) do
        local idx, val = string.match(line,'^%[(.+)%](.*)') --decipher(line)
        if idx then
          local a, b = string.match(val,'(%d+) ([%-]?%d+)')
          if a and b then
            if string.match(idx, '_CSA_') then
              multitouch.keytranslate_mod['CSA'][tonumber(a)] = tonumber(b)
            elseif string.match(idx, '_CS_') then
              multitouch.keytranslate_mod['CS'][tonumber(a)] = tonumber(b)
            elseif string.match(idx, '_CA_') then
              multitouch.keytranslate_mod['CA'][tonumber(a)] = tonumber(b)
            elseif string.match(idx, '_SA_') then
              multitouch.keytranslate_mod['SA'][tonumber(a)] = tonumber(b)
            elseif string.match(idx, '_A_') then
              multitouch.keytranslate_mod['A'][tonumber(a)] = tonumber(b)
            elseif string.match(idx, '_C_') then
              multitouch.keytranslate_mod['C'][tonumber(a)] = tonumber(b)
            elseif string.match(idx, '_S_') then
              multitouch.keytranslate_mod['S'][tonumber(a)] = tonumber(b)
            else
              --DBG(idx..'  '..a..'  '..b)
              multitouch.keytranslate[tonumber(a)] = tonumber(b)
            end
          end
        end
      end
    end
  end

  function multitouch.HideOverlay()

    if multitouch.active then
      local ohwnd = reaper.JS_Window_Find(multitouch.overlay_window,true)
      if ohwnd then
        multitouch.overlayhwnd = ohwnd
        local WS_VISIBLE = 0x10000000
        local style = reaper.JS_Window_GetLong(ohwnd, 'STYLE')
        if style and (style & WS_VISIBLE) ~= 0 then
          reaper.JS_Window_Show(ohwnd, 'HIDE')
          reaper.JS_Window_SetForeground(multitouch.whwnd)
          multitouch.active = false
        end
      end
    end
    
  end

  function multitouch.Calibrate()
  
    local tab
    
    local trect = {x = 0, y = 0, w = 16, h = 16}
    local gdi_dc = reaper.JS_GDI_GetClientDC(multitouch.overlayhwnd)
    local lice_bmp = reaper.JS_LICE_CreateBitmap(true, trect.w, trect.h)
    local lice_dc = reaper.JS_LICE_GetDC(lice_bmp)
    reaper.JS_GDI_Blit(lice_dc, 0, 0, gdi_dc, trect.x, trect.y, trect.w, trect.h)
    reaper.JS_GDI_ReleaseDC(gdi_dc, ohwnd)
    reaper.JS_GDI_ReleaseDC(lice_dc, lice_bmp)
    
    local str = ''
    for y = 0, 15 do
      local fnd
      for x = 0, 15 do
        local idx = y*16+x
        local col = reaper.JS_LICE_GetPixel(lice_bmp, x, y) & 0xFF
        if col == 1 then
          multitouch.offset = x
          multitouch.offsetv = y --math.floor(col/16)
          fnd = true
          multitouch.calibrated = true
          --DBG(col..' '..x..' '..y..' offx '..multitouch.offset..'  offy '..multitouch.offsetv)
          --str = str .. 'calibrate: '..x..' '..y..' '.. col ..'\n'
          break
        elseif col > 0 then
          DBG('Error calibrating multitouch overlay window.  Please increase offsets in initdata.txt file.')
          fnd = true
          break
        end
      end
      if fnd then break end
      --DBG('calibrate: ')
    end
    --[[if str ~= '' then
    DBG(str)
    end]]
    reaper.JS_LICE_DestroyBitmap(lice_bmp)
    
  end
  
  function ResetCalibration()
    multitouch.try = (multitouch.try or 0) + 1
    
    if multitouch.try < 5 then
      
      --Run Restart script
      --reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSf5c6a830a5c31e47f950977b0fdf5e32a1485c66"),-1)
      
    elseif multitouch.try == 5 then
      DBG('5 Retries failed :( - maybe try reloading script...')
    end
  end
  
  function multitouch.RunOverlay()
    
    local mouse = {}
    mouse.mx, mouse.my = gfx.mouse_x, gfx.mouse_y
    mouse.mouse_wheel = 0
    
    local points = {point = {}, idx = {}}
    local vkeys = multitouch.vkeys
    
    local ohwnd = multitouch.overlayhwnd or reaper.JS_Window_Find(multitouch.overlay_window,true)
    multitouch.overlayhwnd = ohwnd

    local space = multitouch.space 
    if ohwnd then
      --check visibility
      local WS_VISIBLE = 0x10000000
      local style = reaper.JS_Window_GetLong(ohwnd, 'STYLE')
      if style and (style & WS_VISIBLE) == 0 then
        reaper.JS_Window_Show(ohwnd, 'SHOW')
        multitouch.active = true
      end
    
      --DBG(reaper.JS_WindowMessage_Intercept(ohwnd, 0x0102, true))
      --multitouch.ohwnd = ohwnd
      local border = 0
      if not multitouch.ohwnd_set or (multitouch.resetontimer
        and reaper.JS_Mouse_GetState(0xFF)==0) then
        multitouch.resetontimer = nil
        reaper.JS_Window_SetParent(ohwnd)
        reaper.JS_Window_Show(ohwnd,'SHOWNOACTIVATE')
        reaper.JS_Window_SetOpacity(ohwnd, "ALPHA", 0.01)
        
        local ret, w, h = reaper.JS_Window_GetClientSize(multitouch.whwnd)
        reaper.JS_Window_SetPosition(ohwnd, border, border, w-border*2, h-border*2)
        local rethwnd = reaper.JS_Window_SetParent(ohwnd, multitouch.whwnd)
        if rethwnd == nil then
          if not calib_error_msg then
            calib_error_msg = true
            DBG('Failed to link touch overlay window with Stripper window - Restarting Stripper...') --.. tostring(rethwnd)..'  '..tostring(ohwnd))
            multitouch.active = true
          end
        else
          multitouch.active = true
          multitouch.ohwnd_set = true
        end
        --DBG('resetting size '..w..'  '..h)
        
      else
      end
      
      if multitouch.active then
        local ret, l, t, r, b = reaper.JS_Window_GetRect(multitouch.whwnd)
        --local ret, l2, t2, r2, b2 = reaper.JS_Window_GetRect(ohwnd)
        --DBG(l..' '..t..' '..r-l..' '..b-t..' '..l2..' '..t2..' '..r2-l2..' '..b2-t2..' '..
        --    tostring( multitouch.active)..' '.. tostring(multitouch.ohwnd_set))
        local w = r-l
        local h = b-t
  
        if (w ~= multitouch.oldw or h ~= multitouch.oldh) then
          multitouch.oldw = w
          multitouch.oldh = h
          multitouch.resetontimer = true --reaper.time_precise() + 0.5
          --DBG('reset size')
        else
        
          if reaper.time_precise() < (multitouch.calibrate_timer or 0) then
            if not multitouch.calibrated then
              multitouch.Calibrate()
              if multitouch.calibrated then
                --DBG('Calibration Succeeded')
              end
              nocalib_msg = 0
            end
            return points, mouse, vkeys, char
          elseif not multitouch.calibrated then
            --calibration failed - reset
            ResetCalibration()
            multitouch.init = false
            return points, mouse, vkeys, char
            
          end
        
        
          local forg = reaper.JS_Window_GetForeground()
  
          local offset = multitouch.offset
          local offsetv = multitouch.offsetv
          
          local trect = {x = offset, y = offsetv, w = 16*space, h = 8*space}
          local gdi_dc = reaper.JS_GDI_GetClientDC(ohwnd)
          local lice_bmp = reaper.JS_LICE_CreateBitmap(true, trect.w, trect.h)
          local lice_dc = reaper.JS_LICE_GetDC(lice_bmp)
          reaper.JS_GDI_Blit(lice_dc, 0, 0, gdi_dc, trect.x, trect.y, trect.w, trect.h)
          reaper.JS_GDI_ReleaseDC(gdi_dc, ohwnd)
          reaper.JS_GDI_ReleaseDC(lice_dc, lice_bmp)
          
          --[[local offset = 0
          local s = ''
          local g = false
          for i = 0, 10 do
            local col = reaper.JS_LICE_GetPixel(lice_bmp, 1, i) & 0xFFFF
            s = s ..col..' '
            if col > 0 then
              g = true
            end
          end
          if g then
            reaper.ShowConsoleMsg(s..'\n')
          end]]
          
          local i = 1
          local col = reaper.JS_LICE_GetPixel(lice_bmp, i*space, 0) & 0xFFFF
          if col > 0 then
            --DBG(i..' '..col)
            while col > 0 and i <= 10 do 
              local col2 = (reaper.JS_LICE_GetPixel(lice_bmp, i*space, space) & 0xFFFF) --+multitouch.adjust.x
              local col3 = (reaper.JS_LICE_GetPixel(lice_bmp, i*space, 2*space) & 0xFFFF) --+multitouch.adjust.y
              
              points.point[col] = {x = col2, y = col3}
              points.idx[i] = col
              --reaper.ShowConsoleMsg(col..'\n')
              i=i+1
              col = reaper.JS_LICE_GetPixel(lice_bmp, i*space, 0) & 0xFFFF
            end
          end  
    
          local function convmouse(v)
            if v == 255 then
              return true
            else
              return false
            end
          end
          
          --local touch = false
          if forg == ohwnd then
            mouse.LB = --[[convmouse((reaper.JS_LICE_GetPixel(lice_bmp, 1*space + offset, 4*space) & 0xFF0000) >> 16) and]] reaper.JS_Mouse_GetState(1)==1
            mouse.RB = --[[convmouse((reaper.JS_LICE_GetPixel(lice_bmp, 2*space + offset, 4*space) & 0xFF0000) >> 16) and]] reaper.JS_Mouse_GetState(2)==2
            mouse.MB = --[[convmouse((reaper.JS_LICE_GetPixel(lice_bmp, 3*space + offset, 4*space) & 0xFF0000) >> 16) and]] reaper.JS_Mouse_GetState(64)==64
          else
            mouse.LB = false
            mouse.RB = false
            mouse.MB = false
          end
          --if mouse.LB or mouse.RB or mouse.MB or #points.idx > 0 then
          --  touch = true
          --end
  
          local refocus = ((reaper.JS_LICE_GetPixel(lice_bmp, 6*space, 4*space) & 0xFF0000) >> 16)
          if refocus ~= 0 then
            refocus_latch = true
          end
          if refocus_latch then
            if refocus == 0 then
              multitouch.refocus = true
              refocus_latch = false
            end
          end
  
          local mw = ((reaper.JS_LICE_GetPixel(lice_bmp, 4*space, 4*space) & 0xFF0000) >> 16)
          local mw_id = ((reaper.JS_LICE_GetPixel(lice_bmp, 4*space, 4*space) & 0x0000FF))
          
          if mw ~= 0 and mw_id ~= mw_lastid then
            mw_lastid = mw_id
            mouse.mouse_wheel=mw-128
            --DBG(mw_id)
          end
          
          local col = (reaper.JS_LICE_GetPixel(lice_bmp, 1*space, 3*space) & 0xFF0000) >> 16
          local i = 1
          vkeys.idx = {}
          vkeys.idx2 = {}
          
          local keypressed = {}
          if col > 0 then
  
            while col > 0 and i <= 16 do
            
              keypressed[col] = true
              if vkeys.key[col] then
                vkeys.key[col] = -1
                vkeys.idx[i] = col
                vkeys.idx2[col] = i
              else
                vkeys.key[col] = 1
                vkeys.repeatdelay[col] = reaper.time_precise() + 0.25
                vkeys.idx[i] = col
                vkeys.idx2[col] = i
              end
              --cnt=cnt+1
              i=i+1
              col = (reaper.JS_LICE_GetPixel(lice_bmp, i*space, 3*space) & 0xFF0000) >> 16
            end
            vkeys.idx[i] = nil
          end
          
          for col, state in pairs(vkeys.key) do
            if not keypressed[col] then
              vkeys.key[col] = nil
            end
          end
          
          if tostring(forg) == tostring(multitouch.whwnd) and reaper.JS_Mouse_GetState(0xFF) == 0 then
            reaper.JS_Window_SetForeground(ohwnd)
          end
          --reaper.js_window_g
          --if tostring(forg) == tostring(multitouch.ohwnd) and touch then
            --reaper.JS_Window_SetZOrder(multitouch.whwnd, 'TOP')
            --DBG('x')
          --end
    
          reaper.JS_LICE_DestroyBitmap(lice_bmp)
          
        end
      end
      
    elseif multitouch.ohwnd_set then
      multitouch.ohwnd_set = false
      --DBG('no overlay')
    end
  
    local char
    for a, b in pairs(vkeys.key) do
      if b == 1 then
        local c = multitouch.keytranslate[a]
        --DBG('in '..tostring(a)..'  '..tostring(c))
        if (c or 0) > 0 then
          char = c
        elseif (c or 0) < 0 then
          if c == -1 then
            mouse.shift = true
          elseif c == -2 then
            mouse.ctrl = true
          elseif c == -3 then
            mouse.alt = true
          end
        end
      elseif b == -1 then
        local c = multitouch.keytranslate[a]
        if (c or 0) < 0 then
          if c == -1 then
            mouse.shift = true
          elseif c == -2 then
            mouse.ctrl = true
          elseif c == -3 then
            mouse.alt = true
          end
        elseif (c or 0) > 0 then
          if reaper.time_precise() > vkeys.repeatdelay[a] then
            vkeys.repeatdelay[a] = reaper.time_precise() + 0.01
            char = c
          end
        end
      end
    end

    if char then
      local k = ''
      if mouse.ctrl then k = k .. 'C' end
      if mouse.shift then k = k .. 'S' end
      if mouse.alt then k = k .. 'A' end
      --DBG(k..'  '..char..'  '..tostring(multitouch.keytranslate_mod[k]))
      if multitouch.keytranslate_mod[k] then
        --DBG('xx '..tostring(multitouch.keytranslate_mod[k][char]))
        char = multitouch.keytranslate_mod[k][char] or char
      end
      --DBG(char)
    end
    return points, mouse, vkeys, char
    
  end
  
  return multitouch
