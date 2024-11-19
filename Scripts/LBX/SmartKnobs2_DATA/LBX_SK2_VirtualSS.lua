  local SCRIPT = 'LBXVSS'
  local SCRIPT_NAME = 'LBX_SK2_VirtualSS'
  local REMSCRIPT='LBX_SK2_REMOTE'
  
  local gui_size = {w = 1000, h = 100}
  local mouse = {}
  
  local resize_display = true
  local update_gfx = true
  
  local nextcheck = -1
  local lvar = {}
  
  lvar.poslocked = false
  lvar.noborder = true
  
  lvar.showfullinfo = false
  lvar.valorient = 1
  lvar.sizew = 100
  lvar.sizeh_off = 0
  lvar.theight = 20
  lvar.theight_off = 0
  lvar.cp_size = 250
  lvar.old_cp_size = 250
  lvar.rowoff = 0
  lvar.showvalbars = true
  
  local tab_xtouch_color_menu = {'Black','Red','Green','Yellow','Blue','Magenta','Cyan','White','Invert Top Line','Invert Bottom Line'}
  local tab_xtouch_colors = {}
  tab_xtouch_colors[0] = {v = 0, c = '0 0 0', tc = '205 205 205', r = 32/255, g = 32/255, b = 32/255}
  tab_xtouch_colors[1] = {v = 1, c = '255 0 0', r = 255/255, g = 0, b = 0}
  tab_xtouch_colors[2] = {v = 2, c = '0 255 0', r = 0, g = 255/255, b = 0}
  tab_xtouch_colors[3] = {v = 3, c = '255 216 0', r = 255/255, g = 216/255, b = 0}
  tab_xtouch_colors[4] = {v = 4, c = '0 38 255', r = 0, g = 38/255, b = 255/255}
  tab_xtouch_colors[5] = {v = 5, c = '255 0 220', r = 255/255, g = 0, b = 220/255}
  tab_xtouch_colors[6] = {v = 6, c = '0 255 255', r = 0, g = 255/255, b = 255/255}
  tab_xtouch_colors[7] = {v = 7, c = '255 255 255', r = 255/255, g = 255/255, b = 255/255}
  
  lvar.master_image = 2
  lvar.btn_image = 3
  lvar.cp_image1 = 4
  lvar.cp_image2 = 5
  lvar.cp_image3 = 6
  lvar.bgcolor = '16 16 16'
  lvar.bgcolor2 = '0 0 0'
  
  local contexts = {movewin = 1,
                    }
  
  ----------------------------------------------------------
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
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
  
  function tobool(b)
  
    local ret = false
    if tostring(b) == 'true' then
      ret = true
    end
    return ret
    
  end
  
  function LoadLocation()
    if reaper.JS_Window_SetLong then
      local fn = reaper.GetResourcePath()..'/Scripts/LBX/SmartKnobs2_DATA/location.txt'
      if reaper.file_exists(fn) then
        local flines = io.lines
        local data = {}
        local match = string.match
        
        for line in flines(fn) do
          local idx, val = match(line,'^%[(.-)%](.*)') --decipher(line)
          if idx then
            data[idx] = val
          end
        end
        
        local x = tonumber(data['x3'])
        local y = tonumber(data['y3'])
        local w = tonumber(data['w3'])
        local h = tonumber(data['h3'])
        local frameless = tonumber(data['frameless3'])
        if x and y and w and h then
          return true,x,y,w,h,frameless
        end
      end
    end
  end
  
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
  
    gui.fontname = GES('fontname',true) or gui.fontname
    lvar.showvalbars = tobool(GES('showvalbars',true) or lvar.showvalbars)
    lvar.showfullinfo = tobool(GES('showfullinfo',true) or lvar.showfullinfo)
    
    lvar.poslocked = tobool(GES('poslocked',true) or lvar.poslocked)
    lvar.sizew = tonumber(GES('sizew',true)) or lvar.sizew
    lvar.sizeh_off = tonumber(GES('sizeh_off',true)) or lvar.sizeh_off
    lvar.theight_off = tonumber(GES('theight_off',true)) or lvar.theight_off
    lvar.cp_size = tonumber(GES('cp_size',true)) or lvar.cp_size
    lvar.old_cp_size = tonumber(GES('old_cp_size',true)) or lvar.old_cp_size
    if lvar.old_cp_size == 0 then
      lvar.old_cp_size = 250
    end
    
    local win = reaper.JS_Window_Find(SCRIPT_NAME, true)
    if win then
      local style = reaper.JS_Window_GetLong(win, 'STYLE')
      if style then
        
        if not lvar.noborder then
          style = style & (0xFFFFFFFF - 0x00C40000)
          reaper.JS_Window_SetLong(win, "STYLE", style)
          
          style = style | 0x00040000
          reaper.JS_Window_SetLong(win, "STYLE", style)
          if ww ~= nil and wh ~= nil then
            reaper.JS_Window_Resize(win, ww, wh)
          end
        else
          local ret,x,y,w,h,frameless = LoadLocation()
          if ret then
            if frameless then
              style = style & (0xFFFFFFFF - 0x00C40000)
              reaper.JS_Window_SetLong(win, "STYLE", style)
            else
              style = style & (0xFFFFFFFF - 0x00C40000)
              reaper.JS_Window_SetLong(win, "STYLE", style)
              
              style = style | 0x00040000
              reaper.JS_Window_SetLong(win, "STYLE", style)
            end
            reaper.JS_Window_SetPosition(win,x,y,w,h) 
          else
            style = style & (0xFFFFFFFF - 0x00C40000)
            reaper.JS_Window_SetLong(win, "STYLE", style)
            
            style = style | 0x00040000
            reaper.JS_Window_SetLong(win, "STYLE", style)
            
            if ww ~= nil and wh ~= nil then
              reaper.JS_Window_Resize(win, ww, wh)
            end
          end
        end
      end
    end
    
    SetUp()
    
    LoadFontList()
  
  end

  function LoadFontList()
  
    local function trim1(s)
      return (s:gsub("^%s*(.-)%s*$", "%1"))
    end
  
    local respath = reaper.GetResourcePath()..'/Scripts/LBX/SmartKnobs2_DATA/'
    local ffn=respath..'lbx_font_list.txt'
    if reaper.file_exists(ffn) ~= true then
      --DBG('Missing file: '..ffn)
      return 0
    end
    fontlist = {}
  
    data = {}
    local i = 1
    for line in io.lines(ffn) do
      line = trim1(line)
      if line ~= '' and line ~= ' ' and line ~= '----' and line ~= 'Name' then
        --DBG(i..' : '..line)
        fontlist[i] = line
        i=i+1
      end
    end
  
  end
  
  function GetFontList()
    local OS = reaper.GetOS()
    if OS == 'Win64' or OS == 'Win32' then
      local respath = reaper.GetResourcePath()..'/Scripts/LBX/SmartKnobs2_DATA/'
      local fp = string.gsub(respath,"/","\\")..'lbx_font_list_tmp.txt'
      local fp2 = string.gsub(respath,"/","\\")..'lbx_font_list.txt'
      local psfp = string.gsub(respath,"/","\\")..'UpdateFontsScript.ps1'
      local txt = '[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")\n'..
                  '(New-Object System.Drawing.Text.InstalledFontCollection).Families | Out-File -FilePath '..fp..'\n'
                  ..'Get-Content '..fp..' | Set-Content -Encoding ascii '..fp2..'\n'
      
      file=io.open(psfp,"w")
      if file then
        file:write(txt)
      end
      file:close()
      local rs = 'powershell.exe '..psfp

      --run script
      reaper.ExecProcess(rs, 0)
      os.remove(fp)
      
      LoadFontList()
    end
  end

  function SetUp()
  
    lvar.ssdata = {idx = {}, data = {}}
    lvar.ssdata.count = tonumber(reaper.GetExtState('LBXVSS','[SSCNT]')) or 0
    if lvar.ssdata.count > 0 then
      for i = 1, lvar.ssdata.count do
        lvar.ssdata.idx[i] = tonumber(reaper.GetExtState('LBXVSS','[SS_'..i..']'))
      end
    end
    
    gfx.loadimg(2, reaper.GetResourcePath()..'/Scripts/LBX/SmartKnobs2_DATA/gfx/vss_button.png')

  end

  ----------------------------------------------------------
  
  function quit()
  
    SaveSettings()      
    
    gfx.quit()
    
  end

  ----------------------------------------------------------
  
  function SaveSettings()
  
    local win = reaper.JS_Window_Find(SCRIPT_NAME, true)
    local retval, left, top, right, bottom
    if win then
      retval, left, top, right, bottom = reaper.JS_Window_GetRect(win)
    end
    
    a,x,y,w,h = gfx.dock(-1,1,1,1,1)
    if gfx1 then
      reaper.SetExtState(SCRIPT,'dock',a or 0,true)
      reaper.SetExtState(SCRIPT,'win_x',x or 0,true)
      reaper.SetExtState(SCRIPT,'win_y',y or 0,true)
      if right then
        reaper.SetExtState(SCRIPT,'win_w',(right-left) or 400,true)
        reaper.SetExtState(SCRIPT,'win_h',(bottom-top) or 200,true)
      else
        reaper.SetExtState(SCRIPT,'win_w',w or 400,true)
        reaper.SetExtState(SCRIPT,'win_h',h or 200,true)
      end
    end
  
    reaper.SetExtState(SCRIPT,'poslocked',tostring(lvar.poslocked),true)
    reaper.SetExtState(SCRIPT,'showvalbars',tostring(lvar.showvalbars),true)
    reaper.SetExtState(SCRIPT,'showfullinfo',tostring(lvar.showfullinfo),true)
    
    reaper.SetExtState(SCRIPT,'sizew',lvar.sizew,true)
    reaper.SetExtState(SCRIPT,'sizeh_off',lvar.sizeh_off,true)
    reaper.SetExtState(SCRIPT,'theight_off',lvar.theight_off,true)
    reaper.SetExtState(SCRIPT,'cp_size',lvar.cp_size,true)
    reaper.SetExtState(SCRIPT,'old_cp_size',lvar.old_cp_size,true)
    reaper.SetExtState(SCRIPT,'fontname',gui.fontname,true)
  
  end

  ----------------------------------------------------------

  function f_Get_SSV_dim(s, p)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1]*p, t[2]*p, t[3]*p
  end
  
  function f_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  
  ------------------------------------------------------------
    
  function GUI_text(gui, xywh, text, flags, col, tsz, justifyiftoobig, pad)
  
    if col == nil then col = '205 205 205' end
    if tsz == nil then tsz = 0 end
    if pad == nil then pad = 0 end
    
    f_Get_SSV(col)  
    gfx.a = 1 
    gfx.setfont(1, gui.fontname, tsz)
    gfx.x, gfx.y = xywh.x+pad,xywh.y
    local r, b
    r, b = xywh.x+xywh.w-pad, xywh.y+xywh.h 
    if justifyiftoobig then
      local tw = gfx.measurestr(text)
      if tw < xywh.w-4-pad then
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
  
    gfx.mode = 4
    
    if resize_display then    
      gfx.setimgdim(1, -1, -1)  
      gfx.setimgdim(1, gfx1.main_w,gfx1.main_h)

      gfx.dest = 1
      
      --[[f_Get_SSV(lvar.bgcolor)
      gfx.rect(0,
               0,
               gfx1.main_w,
               gfx1.main_h, 1)]]
      update_gfx = true
      
    end

    gfx.dest = 1
    
    if update_gfx or update_cp then
    
      --draw cp
      gfx.a = 1
      
      f_Get_SSV(lvar.bgcolor)
      
      gfx.rect(0,0,lvar.cp_size, win_h, 1)
      gfx.rect(win_w-lvar.cp_size,0,lvar.cp_size, win_h, 1)
    
      gfx.blit(lvar.cp_image1, 1, 0, 0, 0, lvar.ss_loc.title.w, lvar.ss_loc.title.h, lvar.ss_loc.title.x, lvar.ss_loc.title.y)
      GUI_text(gui, lvar.ss_loc.title, lvar.ssdata.title, 5, '200 200 200', lvar.theight)

      gfx.blit(lvar.cp_image2, 1, 0, 0, 0, lvar.ss_loc.layerswitch.w, lvar.ss_loc.layerswitch.h, lvar.ss_loc.layerswitch.x, lvar.ss_loc.layerswitch.y)
      
      --[[gfx.muladdrect(lvar.ss_loc.layerswitch.x, lvar.ss_loc.layerswitch.y, lvar.ss_loc.layerswitch.w, lvar.ss_loc.layerswitch.h,
                     lvar.ssdata.layer_color_r,lvar.ssdata.layer_color_g,lvar.ssdata.layer_color_b)]]
      GUI_text(gui, lvar.ss_loc.layerswitch, lvar.ssdata.layer_info, 5, lvar.ssdata.layer_color or '200 200 200', lvar.theight-6)
      
      
      gfx.blit(lvar.cp_image3, 1, 0, 0, 0, lvar.ss_loc.layerswitch2.w, lvar.ss_loc.layerswitch2.h, lvar.ss_loc.layerswitch2.x, lvar.ss_loc.layerswitch2.y)
      gfx.blit(lvar.cp_image3, 1, 0, 0, 0, lvar.ss_loc.layerswitch3.w, lvar.ss_loc.layerswitch3.h, lvar.ss_loc.layerswitch3.x, lvar.ss_loc.layerswitch3.y)
      GUI_text(gui, lvar.ss_loc.layerswitch2, '<', 5, '160 160 160', lvar.theight-6)
      GUI_text(gui, lvar.ss_loc.layerswitch3, '>', 5, '160 160 160', lvar.theight-6)

      f_Get_SSV('0 0 0')
      gfx.rect(0,0,win_w,1,1)
    
      f_Get_SSV(lvar.bgcolor2)
      gfx.rect(lvar.cp_size,0,win_w-2*lvar.cp_size,win_h,1)
    end
    
    local redraw
    local dim = 0.25
    local yoff = lvar.sizeh/16 
    local roff
    local force
    if lvar.scrollss then
      local dt = math.min(1,(reaper.time_precise() - lvar.scrollss.st) / (lvar.scrollss.et - lvar.scrollss.st))
      local ro = (lvar.scrollss.ep - lvar.scrollss.sp) * dt + lvar.scrollss.sp
      roff = math.floor(-ro*(lvar.sizeh+10))
      force = true
      if dt == 1 then
        roff = -lvar.rowoff*(lvar.sizeh+10)
        lvar.scrollss = nil
      end
      f_Get_SSV(lvar.bgcolor2)
      gfx.rect(lvar.cp_size,0,win_w-2*lvar.cp_size,win_h,1)
    else
      roff = -lvar.rowoff*(lvar.sizeh+10)
    end
    local xywh1 = {w = lvar.sizew, h = lvar.sizeh/2}
    local pad = 6
    for i = 1, lvar.ssdata.count do
      local ssidx = lvar.ssdata.idx[i]
      local data = lvar.ssdata.data[i]
      if data and (data.dirty == 1 or update_gfx or force) then
        data.dirty = 0
        redraw = true
        gfx.a = 1
        f_Get_SSV(lvar.bgcolor)
        gfx.rect(lvar.ss_loc[i].x, lvar.ss_loc[i].y + roff, lvar.ss_loc[i].w, lvar.ss_loc[i].h, 1)
        gfx.blit(lvar.btn_image, 1, 0, 0, 0, lvar.sizew, lvar.sizeh, lvar.ss_loc[i].x, lvar.ss_loc[i].y + roff)
        local xcol = tab_xtouch_colors[data.color]
        if xcol then
          gfx.muladdrect(lvar.ss_loc[i].x, lvar.ss_loc[i].y + roff, lvar.sizew, lvar.sizeh, xcol.r*dim, xcol.g*dim, xcol.b*dim)
          xywh1.x = lvar.ss_loc[i].x
          xywh1.y = lvar.ss_loc[i].y + yoff + roff --+ 10
          GUI_text(gui, xywh1, data.str1, 5, xcol.c or '0 0 0', lvar.theight, 4, pad)
          xywh1.y = lvar.ss_loc[i].y + lvar.sizeh/2 -yoff + roff -- lvar.theight - 10
          GUI_text(gui, xywh1, data.str2, 5, xcol.c or '0 0 0', lvar.theight, 4, pad)
        end
        
        if data.val > -1 and lvar.showvalbars and xcol then
          f_Get_SSV_dim(xcol.c, 0.4)
          if lvar.valorient == 1 then
            local pad = 2
            local w = (lvar.ss_loc[i].w - pad*2) * data.val + 1
            gfx.rect(lvar.ss_loc[i].x+pad, lvar.ss_loc[i].y+roff+lvar.ss_loc[i].h-5, w, 3, 1)
          else
            local pad = 2
            local h = math.max(1,(lvar.ss_loc[i].h) * data.val)
            local y = lvar.ss_loc[i].y+roff+lvar.ss_loc[i].h - h
            gfx.rect(lvar.ss_loc[i].x+lvar.ss_loc[i].w-pad, y, 1, h, 1)
          end
        end
      end
    end
    
    if update_gfx or redraw then
      gfx.dest = -1
      gfx.a = 1
      gfx.blit(1, 1, 0, 
        0,0, gfx1.main_w,gfx1.main_h,
        0,0)
    end
    
    gfx.update()

    resize_display = false
    update_gfx = false
    update_cp = false
  
  end

  ----------------------------------------------------------
  
  local match = string.match
  function trim(s) --trim7
     return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
  end
  
  function ResizeImage(src, dst, sizew, sizeh, border, r, g, b)
  
    gfx.dest = dst
    local srcw, srch = gfx.getimgdim(src)
    --DBG(src..' '..srcw..' '..srch)
    gfx.setimgdim(dst, -1, -1)
    gfx.setimgdim(dst, sizew, sizeh)
    
    --gfx.mode = -8
    gfx.blit(src, 1, 0, 0, 0, border, border, 0, 0)
    gfx.blit(src, 1, 0, srcw-border, 0, border, border, sizew-border, 0)
    gfx.blit(src, 1, 0, 0, srch-border, border, border, 0, sizeh-border)
    gfx.blit(src, 1, 0, srcw-border, srch-border, border, border, sizew-border, sizeh-border)
  
    gfx.blit(src, 1, 0, 0, border, border, srch-border*2, 0, border, border, sizeh-border*2)
    gfx.blit(src, 1, 0, border, 0, srcw-border*2, border, border, 0, sizew-border*2, border)
    gfx.blit(src, 1, 0, srcw-border, border, border, srch-border*2, sizew-border, border, border, sizeh-border*2)
    gfx.blit(src, 1, 0, border, srch-border, srcw-border*2, border, border, sizeh-border, sizew-border*2, border)
    
    gfx.blit(src, 1, 0, border, border, srcw-border*2, srch-border*2, border, border, sizew-border*2, sizeh-border*2)
    
    if r or g or b then
      gfx.muladdrect(0,0,sizew,sizeh,r or 1,g or 1,b or 1)
    end
    --gfx.mode = 1
    
  end
  
  function MOUSE_click(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.LB 
      and not mouse.last_LB then
     return true 
    end 
  end

  function MOUSE_click_RB(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.RB 
      and not mouse.last_RB then
     return true 
    end 
  end
  
  function Menu()
    
    local lw = ''
    if lvar.poslocked then
      lw = '!'
    end
    local vb = ''
    if lvar.showvalbars then
      vb = '!'
    end
    local fi = ''
    if lvar.showfullinfo then
      fi = '!'
    end
    local fontstr = '|>Font|Enter Font|'
    if fontlist then
      for i = 1, #fontlist do
        fontstr = fontstr .. '|' .. fontlist[i]
      end
    end
    local mstr = lw..'Lock Window Position||Hide Nav Controls|'..vb..'Show Value Bars|'..fi..'Show Full Info||Update Font List (Windows only)|'..fontstr
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        lvar.poslocked = not lvar.poslocked
      elseif res == 2 then
        if lvar.cp_size == 0 then
          lvar.cp_size = lvar.old_cp_size
          update_gfx = true
        else
          lvar.old_cp_size = lvar.cp_size
          lvar.cp_size = 0
          update_gfx = true
        end
        lvar.resize = true --force resize
      elseif res == 3 then
        lvar.showvalbars = not lvar.showvalbars
        update_gfx = true
      elseif res == 4 then
        lvar.showfullinfo = not lvar.showfullinfo
        update_gfx = true
        lvar.readdata = true
        
      elseif res == 5 then
        GetFontList()
      elseif res >= 6 then
        if res == 6 then
          local ret, fontn = reaper.GetUserInputs("Enter Font", 1, "Font name:", gui.fontname)
          if ret and fontn ~= '' then
            gui.fontname = fontn
            gfx.setfont(1, gui.fontname)
            local str = ''
            local idx, str = gfx.getfont()
            if string.lower(str) ~= string.lower(fontn) then
              gui.fontname = str
              reaper.MB('Font not found - using '..str, 'Enter Font',0)
            else
              gui.fontname = str
            end
            update_gfx = true
          end
        else
          local idx = res-6
          gui.fontname = fontlist[idx]
          update_gfx = true
        end
      end
    end
    
  end
  
  function F_limit(val,min,max)
    if val == nil or min == nil or max == nil then return end
    local val_out = math.max(math.min(val, max),min)
    --if val < min then val_out = min end
    --if val > max then val_out = max end
    return val_out
  end  
  
  function run()
  
    mouse.mx, mouse.my = gfx.mouse_x, gfx.mouse_y
    mouse.LB = gfx.mouse_cap&1==1
    mouse.RB = gfx.mouse_cap&2==2
    mouse.ctrl = gfx.mouse_cap&4==4
    mouse.shift = gfx.mouse_cap&8==8
    mouse.alt = gfx.mouse_cap&16==16
    
    local rt = reaper.time_precise()

    --if rt > nextcheck then
    
    --  nextcheck = rt+0.1
    
    local resize = lvar.resize
    
    if gfx.mouse_wheel ~= 0 then
    
      local add = gfx.mouse_wheel/120 --1
      --[[if gfx.mouse_wheel < 0 then
        add = -1
      end]]
      gfx.mouse_wheel = 0
      
      if mouse.shift then
        lvar.sizew = math.max(60, lvar.sizew + (add*2))
        resize = true
      elseif mouse.ctrl then
        lvar.sizeh_off = math.max(0,lvar.sizeh_off + add)
        resize = true
      elseif mouse.alt then
        lvar.theight_off = lvar.theight_off + add
        resize = true
      else
        if not lvar.scrollss then
          local ro = F_limit(lvar.rowoff - add,0,lvar.maxr)
          lvar.scrollss = {st = reaper.time_precise(), et = reaper.time_precise()+0.1, sp = lvar.rowoff, ep = ro}
          lvar.rowoff = ro
          --update_gfx = true
        end
      end
    end
    
    if gfx.w ~= gfx1.main_w or gfx.h ~= gfx1.main_h or not lvar.sizeh or resize then
      lvar.resize = nil
      
      local r = false
      if not r or gfx.dock(-1) > 0 then 
      
        gfx1.main_w = gfx.w
        gfx1.main_h = gfx.h
        win_w = gfx.w
        win_h = gfx.h
  
        resize_display = true
        update_gfx = true
        
        --size
        lvar.pnl_size = win_w - lvar.cp_size*2 - 20
        d = 1
        while (lvar.sizew+10) * math.ceil(lvar.ssdata.count / d) > lvar.pnl_size and d < lvar.ssdata.count do
          d = d + 1
        end
        local xcnt = math.max(1, math.floor(lvar.ssdata.count / d))
        
        lvar.sizeh = math.max(50, (win_h - 10) / d - 10) + lvar.sizeh_off
        --lvar.sizew = math.floor(lvar.sizeh * 2)
        local xoff = math.floor(math.max(0, (lvar.pnl_size-10) - (lvar.sizew+10) * xcnt) / 2)
        lvar.ss_loc = {}
        local cont = true
        local y = 0
        while cont do
          for x = 0, xcnt-1 do
          --for i = 1, lvar.ssdata.count do
            local i = x + y*xcnt + 1
            if i <= lvar.ssdata.count then
              lvar.ss_loc[i] = {x = lvar.cp_size+10+10+xoff+(10 + lvar.sizew)*(x), y = 10+y*(lvar.sizeh+10), w = lvar.sizew, h = lvar.sizeh}
              lvar.maxr = y
            else
              cont = false
            end
          --end
          end
          y = y + 1
        end
        lvar.theight = math.floor(math.min(lvar.sizew/4, lvar.sizeh/2-2) + lvar.theight_off)
        
        lvar.ss_loc.gui = {x = 0, y = 0, w = win_w, h = win_h}
        lvar.ss_loc.title = {x = 10, y = 10, w = lvar.cp_size-20, h = lvar.sizeh}
        lvar.ss_loc.layerswitch = {x = win_w - lvar.cp_size + 10, y = 10, w = ((lvar.cp_size-20)/2), h = lvar.sizeh}
        lvar.ss_loc.layerswitch2 = {x = win_w - lvar.cp_size/2 + 5, y = 10, w = ((lvar.cp_size-40)/4), h = lvar.sizeh}
        lvar.ss_loc.layerswitch3 = {x = win_w - lvar.cp_size/2 + 10 + lvar.ss_loc.layerswitch2.w , y = 10, w = ((lvar.cp_size-40)/4), h = lvar.sizeh}
        ResizeImage(lvar.master_image, lvar.btn_image, lvar.sizew, lvar.sizeh, 10)
        ResizeImage(lvar.master_image, lvar.cp_image1, lvar.cp_size-20, lvar.sizeh, 10, 0.2, 0.2, 0.2)
        ResizeImage(lvar.master_image, lvar.cp_image2, lvar.ss_loc.layerswitch.w, lvar.ss_loc.layerswitch.h, 10, 0.2, 0.2, 0.2)
        ResizeImage(lvar.master_image, lvar.cp_image3, lvar.ss_loc.layerswitch2.w, lvar.ss_loc.layerswitch2.h, 10, 0.2, 0.2, 0.2)
      end
    end
    
    --end
    
    for i = 1, lvar.ssdata.count do
      local ssidx = lvar.ssdata.idx[i]
      local key = '[VSS_'..ssidx
      local d = tonumber(reaper.GetExtState('LBXVSS',key..'_DIRTY]'))
      if d == 1 or update_gfx or lvar.readdata then
        local str1, str2
        if lvar.showfullinfo then
          str1 = trim(reaper.GetExtState('LBXVSS',key..'_GSTR1]'))
          str2 = trim(reaper.GetExtState('LBXVSS',key..'_GSTR2]'))
        else
          str1 = string.sub(trim(reaper.GetExtState('LBXVSS',key..'_STR1]')),1,7)
          str2 = string.sub(trim(reaper.GetExtState('LBXVSS',key..'_STR2]')),1,7)
        end
        local color = tonumber(reaper.GetExtState('LBXVSS',key..'_COLOR]'))
        local val = tonumber(reaper.GetExtState('LBXVSS',key..'_VAL]'))
        --DBG(str1..'  '..str2..'  '..color)
        lvar.ssdata.data[i] = {str1 = str1, str2 = str2, color = color or 0, val = val or -1, dirty = 1}
        
        reaper.SetExtState('LBXVSS',key..'_DIRTY]',0,false)
      end
    end
    lvar.readdata = nil
    
    local d = tonumber(reaper.GetExtState('LBXVSS','[TITLE_DIRTY]'))
    if d == 1 or update_gfx then
      lvar.ssdata.title = reaper.GetExtState('LBXVSS','[TITLE1]')
      update_cp = true
      reaper.SetExtState('LBXVSS','[TITLE_DIRTY]',0,false)
    end

    local d = tonumber(reaper.GetExtState('LBXVSS','[DATA_DIRTY]'))
    if d == 1 or update_gfx then
      lvar.ssdata.layer_info = reaper.GetExtState('LBXVSS','[LAYER_INFO]')
      lvar.ssdata.layer_color = reaper.GetExtState('LBXVSS','[LAYER_COLOR]')
      local r,g,b = string.match(lvar.ssdata.layer_color, '(%d+) (%d+) (%d+)')
      if tonumber(r) then
        lvar.ssdata.layer_color_r = tonumber(r)/255
        lvar.ssdata.layer_color_g = tonumber(g)/255
        lvar.ssdata.layer_color_b = tonumber(b)/255
        ResizeImage(lvar.master_image, lvar.cp_image2, lvar.ss_loc.layerswitch.w, lvar.ss_loc.layerswitch.h, 10, 0.2, 0.2, 0.2)
        gfx.dest = lvar.cp_image2
        gfx.muladdrect(0, 0, lvar.ss_loc.layerswitch.w, lvar.ss_loc.layerswitch.h,
                       lvar.ssdata.layer_color_r,lvar.ssdata.layer_color_g,lvar.ssdata.layer_color_b)
      else
        lvar.ssdata.layer_color = '205 205 205'
        lvar.ssdata.layer_color_r = 205/255
        lvar.ssdata.layer_color_g = 205/255
        lvar.ssdata.layer_color_b = 205/255
      end
      
      update_cp = true
      reaper.SetExtState('LBXVSS','[DATA_DIRTY]',0,false)
    end
    
    if not mouse.context then
      local btn = lvar.ss_loc
      if lvar.cp_size > 0 and MOUSE_click(btn.layerswitch) then
        reaper.SetExtState(REMSCRIPT, 'REMOTE_CTL', 'SK2_TOGGLE_GLOBALLAYOUT', false)
      elseif lvar.cp_size > 0 and MOUSE_click(btn.layerswitch2) then
        reaper.SetExtState(REMSCRIPT, 'REMOTE_CTL', 'SK2_PREVLAYER', false)
      elseif lvar.cp_size > 0 and MOUSE_click(btn.layerswitch3) then
        reaper.SetExtState(REMSCRIPT, 'REMOTE_CTL', 'SK2_NEXTLAYER', false)
      elseif MOUSE_click(btn.gui) then
        if not lvar.poslocked then
          local win = reaper.JS_Window_Find(SCRIPT_NAME, true)
          if win then
            mouse.context = contexts.movewin
            local mx, my = reaper.GetMousePosition()
            local ret, wx, wy, wr, wb = reaper.JS_Window_GetRect(win)
            lvar.movewin = {mx = mx, my = my, winx = wx, winy = wy, winw = wr-wx, winh = wb-wy, hwnd = win}
          end
        end
      elseif MOUSE_click_RB(btn.gui) then
        Menu()
      end
    else
      if mouse.context == contexts.movewin then
        local mx, my = reaper.GetMousePosition()
        local dx = lvar.movewin.mx - mx
        local dy = lvar.movewin.my - my
        reaper.JS_Window_SetPosition(lvar.movewin.hwnd, lvar.movewin.winx - dx, lvar.movewin.winy - dy, lvar.movewin.winw, lvar.movewin.winh)
      end
    end
    
    GUI_draw()
    
    -----------------------------------------------


    -----------------------------------------------
    
    local char = gfx.getchar() 
    if char then 
      if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
      if char>=0 and char~=27 then reaper.defer(run) end
    else
      reaper.defer(run)
    end
    --gfx.update()
    mouse.last_LB = mouse.LB
    mouse.last_RB = mouse.RB
    mouse.last_x = mouse.mx
    mouse.last_y = mouse.my
    if mouse.LB then
      mouse.lastLBclicktime = rt
    end
    if not mouse.LB then
      mouse.context = nil
    end
    gfx.mouse_wheel = 0
    
  end --run
  
  ---------------------------------------------------------
  
  gui = GetGUI_vars()  
  
  init()
  
  run()
  reaper.atexit(quit)
  
