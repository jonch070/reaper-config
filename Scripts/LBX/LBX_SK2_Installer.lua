  local SCRIPT = 'LBX_SK2_Installer'
  local SCRIPT_NAME = 'LBX_SK2_Installer'
  local gui_size = {w = 400, h = 400}
  local mouse = {}
  
  local resize_display = true
  local update_gfx = true
  
  local DBG_mode = false
  
  local lvar = {}
  lvar.swsok = false
  lvar.jsok = false
  lvar.optional = {}
  lvar.showopt = false
  lvar.optbcnt = 8
  lvar.installfolder = false
  
  lvar.mainSK2Lua = 'LBX_SmartKnobs2.lua'
  lvar.checkresources = '/Scripts/LBX/SmartKnobs2_DATA/invisible.cur'
  
  ----------------------------------------------------------
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end

  function DBGHex(str)
    str=tostring(str)
    if str==nil then str="nil" end
    for c = 1, string.len(str) do
      reaper.ShowConsoleMsg(string.byte(string.sub(str,c,c+1))..' ')
    end
    reaper.ShowConsoleMsg('\n')
    --reaper.ShowConsoleMsg(tostring(str).."\n")
  end
  
  function DBGOut(msg)
  
    if DBG_mode then
      DBG(msg)
    end
  
  end
  
  ----------------------------------------------------------
  
  function GetGUI_vars()
    gfx.mode = 0
    
    local gui = {}
      gui.aa = 1
      gui.fontname = 'Calibri'
      gui.fontsz = 18
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz = gui.fontsz - 5 end
      
      gui.color = {['back'] = '87 109 130',
                    ['back2'] = '87 109 130',
                    ['black'] = '0 0 0',
                    ['green'] = '87 109 130',
                    ['blue'] = '87 109 130',
                    ['white'] = '205 205 205',
                    ['red'] = '255 42 0',
                    ['green_dark'] = '0 0 0',
                    ['yellow'] = '87 109 130',
                    ['pink'] = '87 109 130',
                    }
    return gui
  end
  
  function GetObjects()
    
    local obj = {sections = {}}
  
    local bh = math.max(42,math.floor(gfx1.main_h / 5)-2)
    lvar.optbh = math.max(25,math.floor(gfx1.main_h / lvar.optbcnt)-2)
  
    --err sws/js
    obj.sections[1] = {x = 2, y = 0, w = gfx1.main_w-4, h = bh}
    obj.sections[2] = {x = 2, y = bh+2, w = gfx1.main_w-4, h = bh}
    --install
    obj.sections[5] = {x = 2, y = (bh+2)*2, w = gfx1.main_w-4, h = bh}
    obj.sections[3] = {x = 2, y = (bh+2)*3, w = gfx1.main_w-4, h = bh}
    obj.sections[4] = {x = 2, y = (bh+2)*4, w = gfx1.main_w-4, h = bh}
  
    obj.sections[99] = {x = 0, y = 0, w = gfx1.main_w, h = gfx1.main_h}
    return obj
    
  end
  
  
  ----------------------------------------------------------
    
  function GES(key, nilallowed)
    if nilallowed == nil then nilallowed = false end
    
    local val = reaper.GetExtState(SCRIPT,key)
    if nilallowed then
      if val == '' then
        val = nil
      end
    end
    return val
  end
  
  ----------------------------------------------------------
  
  function Lokasenna_Window_At_Center (w, h)
    -- thanks to Lokasenna 
    -- http://forum.cockos.com/showpost.php?p=1689028&postcount=15    
    local l, t, r, b = 0, 0, w, h    
    local __, __, screen_w, screen_h = reaper.my_getViewport(l, t, r, b, l, t, r, b, 1)    
    local x, y = (screen_w - w) / 2, (screen_h - h) / 2    
    gfx.init(SCRIPT_NAME, w, h, 0, x, y)  
  end

  ----------------------------------------------------------
  
  function init()
  
    local x, y = GES('win_x',true), GES('win_y',true)
    local ww, wh = GES('win_w',true), GES('win_h',true)
    local d = GES('dock',true)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if d == nil then d = gfx.dock(-1) end    
    if ww ~= nil and wh ~= nil then
      gfx1 = {main_w = tonumber(ww),
              main_h = tonumber(wh)}
      gfx.init(SCRIPT_NAME, gfx1.main_w, gfx1.main_h, 0, x, y)
      gfx.dock(d)
    else
      gfx1 = {main_w = gui_size.w, main_h = gui_size.h}
      Lokasenna_Window_At_Center(gfx1.main_w,gfx1.main_h)  
    end
  
  end

  ----------------------------------------------------------
  
  function quit()
  
    SaveSettings()      
    
    gfx.quit()
    
  end

  ----------------------------------------------------------
  
  function SaveSettings()
  
    a,x,y,w,h = gfx.dock(-1,1,1,1,1)
    if gfx1 then
      reaper.SetExtState(SCRIPT,'dock',a or 0,true)
      reaper.SetExtState(SCRIPT,'win_x',x or 0,true)
      reaper.SetExtState(SCRIPT,'win_y',y or 0,true)    
      reaper.SetExtState(SCRIPT,'win_w',gfx1.main_w or 400,true)
      reaper.SetExtState(SCRIPT,'win_h',gfx1.main_h or 400,true)
    end
  
  end

  ----------------------------------------------------------

  function f_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  
  ------------------------------------------------------------
    
  function GUI_text(gui, xywh, text, flags, col, tsz, justifyiftoobig)
  
    if col == nil then col = '205 205 205' end
    if tsz == nil then tsz = 0 end
    
    f_Get_SSV(col)  
    gfx.a = 1 
    gfx.setfont(1, gui.fontname, gui.fontsz+tsz)
    gfx.x, gfx.y = xywh.x,xywh.y
    local r, b
    r, b = xywh.x+xywh.w, xywh.y+xywh.h 
    if justifyiftoobig then
      local tw = gfx.measurestr(text)
      if tw < xywh.w-4 then
        gfx.drawstr(text, flags, r, b)
      else
        gfx.drawstr(text, justifyiftoobig, r, b)      
      end
    else
      gfx.drawstr(text, flags, r, b)
    end
  end
  
  ------------------------------------------------------------

  function GUI_draw()
  
    if resize_display then    
      gfx.setimgdim(1, -1, -1)  
      gfx.setimgdim(1, gfx1.main_w,gfx1.main_h)
      
      obj = GetObjects()
      
      f_Get_SSV('0 0 0')
      gfx.rect(0,
               0,
               gfx1.main_w,
               gfx1.main_h, 1) 
               
    end

    gfx.dest = 1
    
    if update_gfx then
      gfx.a = 1
      
      f_Get_SSV('0 0 0')
      gfx.rect(0,
               0,
               gfx1.main_w,
               gfx1.main_h, 1) 

      local triw = 20
      if not lvar.showopt then
        local sws = 'SWS OK'
        local swscol = '0 205 0'
        if not lvar.swsok then
          sws = 'Required SWS version not installed'
          swscol = '205 0 0'
        end
        local js = 'JS API OK'
        local jscol = '0 205 0'
        if not lvar.jsok then
          js = 'Required JS API version not installed'
          jscol = '205 0 0'
        end

        local installfoldercol = '0 205 0'
        local installfoldercol2
        if not lvar.jsok or not lvar.swsok then
          installfoldercol = '64 64 64'
        elseif not lvar.installfolder then
          installfoldercol = '205 128 64'
        else
          installfoldercol2 = '0 102 0'
        end
        
        local installcol = '0 205 0'
        if not lvar.jsok or not lvar.swsok or not lvar.installfolder then
          installcol = '64 64 64'
        end
  
        local optioncol = '64 64 64'
        if #lvar.optional > 0 then
          optioncol = '205 128 64'
        end
  
        if not lvar.swsok then
          f_Get_SSV(swscol)
          gfx.rect(obj.sections[1].x,
                   obj.sections[1].y,
                   obj.sections[1].w,
                   obj.sections[1].h, 0) 
          gfx.triangle(obj.sections[1].x,obj.sections[1].y,
                       obj.sections[1].x,obj.sections[1].y+obj.sections[1].h-1,
                       obj.sections[1].x+triw, obj.sections[1].y+obj.sections[1].h/2)
        end
        if not lvar.jsok then
          f_Get_SSV(jscol)
          gfx.rect(obj.sections[2].x,
                   obj.sections[2].y,
                   obj.sections[2].w,
                   obj.sections[2].h, 0)
          gfx.triangle(obj.sections[2].x,obj.sections[2].y,
                       obj.sections[2].x,obj.sections[2].y+obj.sections[2].h-1,
                       obj.sections[2].x+triw, obj.sections[2].y+obj.sections[2].h/2)
        end
        if lvar.jsok and lvar.swsok then
          f_Get_SSV(installfoldercol)
          if lvar.installfolder then
            gfx.a = 0.5
          end
          gfx.rect(obj.sections[5].x,
                   obj.sections[5].y,
                   obj.sections[5].w,
                   obj.sections[5].h, 0) 
          gfx.a = 1
          
          if lvar.installfolder then
          
            f_Get_SSV(installcol)
            gfx.rect(obj.sections[3].x,
                     obj.sections[3].y,
                     obj.sections[3].w,
                     obj.sections[3].h, 0)
            gfx.triangle(obj.sections[3].x,obj.sections[3].y,
                         obj.sections[3].x,obj.sections[3].y+obj.sections[3].h-1,
                         obj.sections[3].x+triw, obj.sections[3].y+obj.sections[3].h/2)
          else
            gfx.triangle(obj.sections[5].x,obj.sections[5].y,
                         obj.sections[5].x,obj.sections[5].y+obj.sections[5].h-1,
                         obj.sections[5].x+triw, obj.sections[5].y+obj.sections[5].h/2)
          end
          
        end
        if #lvar.optional > 0 then
          f_Get_SSV(optioncol)
          gfx.rect(obj.sections[4].x,
                   obj.sections[4].y,
                   obj.sections[4].w,
                   obj.sections[4].h, 0) 
          gfx.triangle(obj.sections[4].x,obj.sections[4].y,
                       obj.sections[4].x,obj.sections[4].y+obj.sections[4].h-1,
                       obj.sections[4].x+triw, obj.sections[4].y+obj.sections[4].h/2)
        end
        GUI_text(gui, obj.sections[1], sws, 5, swscol, 8)
        GUI_text(gui, obj.sections[2], js, 5, jscol, 8)
        if lvar.srcpath then
          GUI_text(gui, obj.sections[5], --[['SOURCE INSTALL FOLDER: '..]]string.gsub(lvar.srcpath,'\\','/'), 5, installfoldercol2, 2)
        else
          GUI_text(gui, obj.sections[5], 'LOCATE INSTALL.SK2 FILE', 5, installfoldercol, 4)
        end
        if lvar.ver then
          GUI_text(gui, obj.sections[3], 'INSTALL SK2 (v'..lvar.ver..')', 5, installcol, 8)
        else
          GUI_text(gui, obj.sections[3], 'INSTALL SK2', 5, installcol, 8)
        end
        GUI_text(gui, obj.sections[4], 'INSTALL OPTIONAL COMPONENTS', 5, optioncol, 4)
      
      else
        local xywh = {x = 2, y = 0, w = gfx1.main_w-4, h = lvar.optbh}
        local optioncol = '205 128 64'
        for i = 1, #lvar.optional do
          f_Get_SSV(optioncol)
          gfx.rect(xywh.x,
                   xywh.y,
                   xywh.w,
                   xywh.h, 0) 
          GUI_text(gui, xywh, lvar.optional[i].name, 5, optioncol, 4)
          gfx.triangle(xywh.x,xywh.y,
                       xywh.x,xywh.y+xywh.h-1,
                       xywh.x+triw, xywh.y+xywh.h/2)
        end
      end
    end
    
    
    gfx.dest = -1
    gfx.a = 1
    gfx.blit(1, 1, 0, 
      0,0, gfx1.main_w,gfx1.main_h,
      0,0, gfx1.main_w,gfx1.main_h, 0,0)
    
    resize_display = false
    update_gfx = false
  
  end

  function MOUSE_click(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.LB 
      and not mouse.last_LB then
     return true 
    end 
  end
  
  function TrimStr(s)
    return string.match(s,"^%s*(.-)%s*$")
  end
  
  function open_url(url)
    local OS = reaper.GetOS()
    if OS == "OSX32" or OS == "OSX64" then
      os.execute('open "" "' .. url .. '"')
    else
      os.execute('start "" "' .. url .. '"')
    end
  end
  
  function CheckReqs()

    local app = '5.974'
    local sws = '2.12.0.1'
    local js = '0.961'
    local err
    
    local imageappdev = '6.13+dev0809a'
    
    --DBG(reaper.GetAppVersion())
    local appstr = (string.match(reaper.GetAppVersion(),'(.+)[/]') or reaper.GetAppVersion())
    if appstr < app then
      DBG('Requires Reaper version '..app..' or later')
      err = true
    end

    if reaper.APIExists('CF_GetSWSVersion') then
      local buf = reaper.CF_GetSWSVersion('')
      --DBGByte(string.gsub(reaper.CF_GetSWSVersion(''),'%.',''))
      local buf2 = string.gsub(buf,'%.','')
      if (tonumber(buf2) or -1) < tonumber(TrimStr(string.gsub(sws,'%.',''))) then
        DBG('Requires SWS version '..sws..' or later')
        err = true
      else
        DBGOut('SWS OK')
        lvar.swsok = true
      end
    else
      DBG('Requires SWS version '..sws..' or later')
      err = true
    end

    if reaper.APIExists('JS_ReaScriptAPI_Version') then
      local ver = reaper.JS_ReaScriptAPI_Version()
      --DBG(ver)
      if ver < tonumber(js) then
        DBG('Requires JS_ReascriptAPI version '..js..' or later')
        err = true
      else
        DBGOut('JS API OK')
        lvar.jsok = true
      end
    else
      DBG('Requires JS_ReascriptAPI version '..js..' or later')
      err = true
    end

    if err then
      --DBG('Running incorrect versions may result in crashes when performing certain functions, or functions not working.')
    end
    
    return not err
    
  end
  
  function split2(str,sep)
  
      local array = {}
      local reg = string.format("([^%s]+)",sep)
      local cnt = 1
      for mem in string.gmatch(str,reg) do
        array[cnt] = mem
        cnt = cnt + 1
      end
      return array
  end
  
  function LocateInstallFolder()

    local deffol = reaper.GetExtState('LBX_SK2_INSTALL','FOL')
    --local ret, installfol = reaper.JS_Dialog_BrowseForFolder('Please select the downloaded SK2_Install folder',deffol or '')
    local ret, installtxtfn = reaper.JS_Dialog_BrowseForOpenFiles('Please open the install.sk2 file from the SK2_Install folder',
                                                                deffol,'install.sk2',"SK2 install files (.sk2)\0*.sk2\0\0", false)
    if ret == 1 then
      local srcpath = string.match(installtxtfn,'(.+[/\\])')
      --local srcpath = installfol..'/'
      --local installtxtfn = srcpath..'install.sk2'
      if reaper.file_exists(installtxtfn) then

        local verfn = 'Lua/'..lvar.mainSK2Lua
        local ver
        local file = io.open(srcpath..verfn, 'rb')
        if file then
          local content = file:read('*a')
          file:close()
          ver = string.match(content,"lvar.version = '(.-)'")
        end
        if ver then
          lvar.srcpath = srcpath
          lvar.ver = ver
          lvar.installfolder = true
          local lfol = lvar.srcpath
          reaper.SetExtState('LBX_SK2_INSTALL','FOL',lfol,true)

          lvar.optional = {}
          
          local lines = {}
          for line in io.lines(installtxtfn) do
            if line ~= '' then
              lines[#lines+1] = string.gsub(line, '[\r]', '') --Sort for Macs
              
              if string.match(line,'^%[OPTION<') then
                local idx = #lvar.optional+1
                local optname, optstring = string.match(line,'^%[OPTION<(.-)>%](.*)') 
                lvar.optional[idx] = split2(optstring,'|')
                lvar.optional[idx].name = optname
              end
            end
          end
          lvar.lines = lines
        
        else
          reaper.MB('Error in installation data.  Please re-download.','Error',0)
        end

        update_gfx = true
      else
        reaper.MB('The folder you selected was not a valid installation folder.','Error',0)    
      end
    end
  end
  
  function InstallSK2()
    
    if lvar.srcpath and lvar.lines then

      local srcpath = lvar.srcpath --installfol..'/'
      lvar.srcpath = srcpath
      
      local installtxtfn = srcpath..'install.sk2'
      if reaper.file_exists(installtxtfn) then
        
        if lvar.ver then

          if reaper.MB('Install SK2 version: '..lvar.ver..'?','Install SK2',4) == 6 then
        
            local lines = lvar.lines
            local reaperdir = reaper.GetResourcePath()
            DBG('Installing SK2 to: '..reaperdir)
            DBG('-----------------------------------------------------------------------')
            
            for l = 1, #lines do
            
              if string.match(lines[l],'^%[CDIR%]') then
                local fol = string.match(lines[l],'^%[CDIR%](.*)')
                fol = string.gsub(fol,'<Reaper>',reaperdir)
                fol = string.gsub(fol, '[\r]', '')
                DBG('Create directory: '..fol)
                --DBGHex(fol)
                
                reaper.RecursiveCreateDirectory(fol,1)
              elseif string.match(lines[l],'^%[CP<') then
                local srcfol, dstfol = string.match(lines[l],'^%[CP<(.-)>%](.*)')
                dstfol = string.gsub(dstfol,'<Reaper>',reaperdir)
                dstfol = string.gsub(dstfol, '[\r]', '')
                DBG('Copy folder:' .. srcpath..srcfol ..' -> '..dstfol)
                CopyFolder(srcpath..srcfol, dstfol)
              elseif string.match(lines[l],'^%[REGISTER%]') then
                local scriptfn = string.match(lines[l],'^%[REGISTER%](.*)')
                scriptfn = string.gsub(scriptfn,'<Reaper>',reaperdir)
                scriptfn = string.gsub(scriptfn, '[\r]', '')
                DBG('Adding script: '..scriptfn)
                reaper.AddRemoveReaScript(true,0,scriptfn,true)
              end
            
            end

            --copy installer luas
            DBG('-----------------------------------------------------------------------')
            DBG('Moving and re-registering Installer lua script')
            local sk2installer_src = srcpath..'LBX_SK2_Installer.lua'
            local sk2installer_dest = reaperdir..'/Scripts/LBX/LBX_SK2_Installer.lua'
            DBG(sk2installer_src..' -> '..sk2installer_dest)
            copyfile(sk2installer_src,sk2installer_dest)
            copyfile(srcpath..'LBX_SK2_RestorePrefs.lua',reaperdir..'/Scripts/LBX/LBX_SK2_RestorePrefs.lua')
            copyfile(srcpath..'LBX_SK2_SetPrefs.lua',reaperdir..'/Scripts/LBX/LBX_SK2_SetPrefs.lua')
            reaper.AddRemoveReaScript(false,0,sk2installer_src,true)
            reaper.AddRemoveReaScript(true,0,sk2installer_dest,true)
            DBG('-----------------------------------------------------------------------')
            
            if reaper.MB('Would you like to set the Reaper preferences required by SK2?\n\n'
                         ..'Not doing so may prevent SK2 from functioning correctly.\nA backup will be made of your previous preferences.','SK2 Setup',4) == 6 then
               dofile(srcpath..'LBX_SK2_SetPrefs.lua')          
            end
            
            reaper.MB("SK2 Installation Complete! :)\n\nPlease locate the "..lvar.mainSK2Lua.." script in Reaper's action list to start SK2.",'Installation Complete',0)
          end
        
        else
          reaper.MB('Error in installation data.','Error',0)
        end
      else
        reaper.MB('The folder you selected was not a valid installation folder.','Error',0)    
      end
    end
    update_gfx = true
    
  end

  function InstallOption(idx)
  
    --check sk2 install
    local reaperdir = reaper.GetResourcePath()
    if lvar.optional[idx] then
    
      local srcpath = lvar.srcpath
      
      local lines = lvar.optional[idx]
      for l = 1, #lines do
                  
        if string.match(lines[l],'^%[CDIR%]') then
          local fol = string.match(lines[l],'^%[CDIR%](.*)')
          fol = string.gsub(fol,'<Reaper>',reaperdir)
          fol = string.gsub(fol, '[\r]', '')
          DBG('Create directory: '..fol)
          reaper.RecursiveCreateDirectory(fol,1)
        elseif string.match(lines[l],'^%[CP<') then
          local srcfol, dstfol = string.match(lines[l],'^%[CP<(.-)>%](.*)')
          dstfol = string.gsub(dstfol,'<Reaper>',reaperdir)
          dstfol = string.gsub(dstfol, '[\r]', '')
          DBG('Copy folder:' .. srcpath..srcfol ..' -> '..dstfol)
          CopyFolder(srcpath..srcfol, dstfol)
        elseif string.match(lines[l],'^%[REGISTER%]') then
          local scriptfn = string.match(lines[l],'^%[REGISTER%](.*)')
          scriptfn = string.gsub(scriptfn,'<Reaper>',reaperdir)
          scriptfn = string.gsub(scriptfn, '[\r]', '')
          DBG('Adding script: '..scriptfn)
          reaper.AddRemoveReaScript(true,0,scriptfn,true)
        end
      
      end
      
    end
  
  end
  
  function copyfile(src, dest)
    local file = io.open(src, 'rb')
    if file then
      local content = file:read('*a')
      file:close()
      dest = string.gsub(dest, '[\r]', '')
      
      local file = io.open(dest, 'wb')
      --[[if string.match(dest,'lua$') then
      DBGHex(dest)
      end]]
      
      if file then
        file:write(content)
        file:close()
      else
        DBG('------------------------------------------------------------')
        DBG('ERROR: opening file for write: '..dest)
        DBG('------------------------------------------------------------')
      end
    end
  end
  
  function CopyFolder(srcfol, dstfol)
  
    --copy files
    local idx = 0
    local fn = reaper.EnumerateFiles(srcfol, idx)
    while fn do
      DBG('copying file: '..srcfol..'/'..fn)
      copyfile(srcfol..'/'..fn, dstfol..fn)
    
      idx=idx+1
      fn = reaper.EnumerateFiles(srcfol, idx)
    end
    
    --copy folders
    local idx = 0
    local fl = reaper.EnumerateSubdirectories(srcfol, idx)
    while fl do
      DBG('copying folder: '..srcfol..'/'..fl)
      reaper.RecursiveCreateDirectory(dstfol..fl,1)
      CopyFolder(srcfol..'/'..fl, dstfol..fl..'/')
      idx=idx+1
      fl = reaper.EnumerateSubdirectories(srcfol, idx)
    end
  
  end
  
  function BackupWarning()
  
    reaper.MB('WARNING:\n\nInstalling optional components may overwrite your data files.\n\n'
              ..'If this is not a fresh installation - it is highly recommended you backup your LBXSK_resources folder before installing any optional components.',
              'Optional components',0)
  
  end
  
  ----------------------------------------------------------
  
  function run()
  
    mouse.mx, mouse.my = gfx.mouse_x, gfx.mouse_y
    mouse.LB = gfx.mouse_cap&1==1
    mouse.RB = gfx.mouse_cap&2==2
    mouse.ctrl = gfx.mouse_cap&4==4
    mouse.shift = gfx.mouse_cap&8==8
    mouse.alt = gfx.mouse_cap&16==16
    
    if gfx.w ~= gfx1.main_w or gfx.h ~= gfx1.main_h then
    
      local r = false
      if not r or gfx.dock(-1) > 0 then 
      
        gfx1.main_w = math.max(380,gfx.w)
        gfx1.main_h = gfx.h
        win_w = gfx.w
        win_h = gfx.h
        --DBG(win_w..'  '..win_h)
        resize_display = true
        update_gfx = true
        
      end
    end
    
    GUI_draw()
    
    if not lvar.showopt then
      if MOUSE_click(obj.sections[5]) and lvar.swsok and lvar.jsok then
        LocateInstallFolder()
      elseif MOUSE_click(obj.sections[3]) and lvar.swsok and lvar.jsok and lvar.installfolder then
        InstallSK2()
      elseif MOUSE_click(obj.sections[1]) and not lvar.swsok then
        open_url('https://www.sws-extension.org/')
      elseif MOUSE_click(obj.sections[2]) and not lvar.jsok then
        open_url('https://forum.cockos.com/showthread.php?t=212174')
      elseif MOUSE_click(obj.sections[4]) and #lvar.optional > 0 then
        local reaperdir = reaper.GetResourcePath()
        local resfol = reaperdir..lvar.checkresources
        if reaper.file_exists(resfol) then
          BackupWarning()
          lvar.showopt = true
          update_gfx = true
        else
          reaper.MB('SK2 resources folder not found.  Please install SK2 first','Error',0)
        end

      end
    else
      if mouse.RB then
        lvar.showopt = false
        update_gfx = true
      end
      if MOUSE_click(obj.sections[99]) then
      
        local idx = math.floor(mouse.my / (lvar.optbh+2)) + 1
        if lvar.optional[idx] then
        
          InstallOption(idx)
        
        end
      end
    end
    
    -----------------------------------------------
    
    local char = gfx.getchar() 
    if char then 
      --if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
      if char>=0 and char~=27 then reaper.defer(run) end
    else
      reaper.defer(run)
    end
    gfx.update()
    mouse.last_LB = mouse.LB
    mouse.last_RB = mouse.RB
    mouse.last_x = mouse.mx
    mouse.last_y = mouse.my
    if mouse.LB then
      mouse.lastLBclicktime = rt
    end
    gfx.mouse_wheel = 0
    
  end --run
  
  ---------------------------------------------------------
  
  gui = GetGUI_vars()  
  
  init()

  obj = GetObjects()
  
  CheckReqs()
  
  run()
  reaper.atexit(quit)
  
