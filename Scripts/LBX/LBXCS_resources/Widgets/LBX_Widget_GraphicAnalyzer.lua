  -- Required params to init values:
  -- main bitmap index (supplied by stripper)
  
  -- self.data should only contain data to be stored and recalled
  
  local Widget = {}
  local fxnotfound = {}
  local fftsizes = {16,32,64,128,256,512,1024,2048,4096,8192,16384,32768}
  local SCRIPT = 'LBX_Widget_GraphicsAnalyzer'
  
  local function F_limit(val,min,max)
    if val == nil or min == nil or max == nil then return end
    local val_out = val
    if val < min then val_out = min end
    if val > max then val_out = max end
    return val_out
  end
   
  function Widget:new(o)
    o = o or {data = {fx = {}, 
                      showcontrols = false, 
                      fxidx = 1, 
                      highlight_selected = false,               
                      bgcol = 0x000000,
                      gridintensity = 0.25,
                      dimbtnamt = 0.5,
                      pinctls = true,
                      usetrackcolor = true,
                      initplug = true,
                     },
              area = {},
              knob = {},
              button = {},
              bitmap_index = -2,
              extra_bitmaps = 0,
              extra_bitmap_index = {},
              scale = 1,
              knobclick = {},
              zoomclick = {},
              buttonclick = {},
              refresh = 1,
              }
    setmetatable(o, self)
    self.__index = self
    --self:init()
    return o
  end

  function Widget:setdata(datatab)
    self.data = datatab
    self.data.fxidx = self.data.fxidx or 1
    self.data.gridintensity =  self.data.gridintensity or 0.25
    self.data.dimbtnamt = self.data.dimbtnamt or 0.5
    self.data.bgcol = self.data.bgcol or 0x000000
    self.gfx_update = true
    if self.data.fx[self.data.fxidx] and self.data.fx[self.data.fxidx].fxguid then
      fxnotfound[self.data.fx[self.data.fxidx].fxguid] = nil
    end
  end
  --[[function Widget:setfxguids(datatab)
    self.fxguids = datatab
  end]]

  function Widget:createknobs()
    local scale = self.scale
    local gap = 34*scale
    local xx = self.area[1].w - 40*scale
    local yy = 10*scale
    local wh = 30*scale
    self.knob[1] = {x = xx, y = yy, w = wh, h = wh}
    self.knob[2] = {x = xx, y = yy + gap, w = wh, h = wh}
    self.knob[3] = {x = xx, y = yy + gap*2, w = wh, h = wh}
    self.knob[4] = {x = xx, y = yy + gap*3, w = wh, h = wh}
    self.knob[5] = {x = xx, y = yy + gap*4, w = wh, h = wh}
    self.knob[6] = {x = xx, y = yy + gap*5, w = wh, h = wh}
    
    self.button[1] = {x = 5*scale, y = 5*scale, w = 20*scale, h = 20*scale}
    self.button[2] = {x = 30*scale, y = 5*scale, w = 20*scale, h = 20*scale}
    self.button[3] = {x = 0, y = 0, w = 0, h = 0}
    self.button[4] = {x = self.area[1].w/2-80, y = 0, w = 160, h = 20}
    self.button[5] = {x = 55*scale, y = 5*scale, w = 40*scale, h = 20*scale}

    local xx = self.button[5].x + self.button[5].w + 20 --30
    local yy = self.button[2].y
    local wh = 20*scale
    local gap = 24*scale
  
    self.knob[7] = {x = xx, y = yy, w = wh, h = wh}
    self.knob[8] = {x = xx + gap, y = yy, w = wh, h = wh}
    self.knob[9] = {x = xx + gap*2, y = yy, w = wh, h = wh}
  end

  function Widget:init()
    local buttonheight = 0 --math.floor(16*self.scale)
    local w, h = gfx.getimgdim(self.bitmap_index)
    self.posh = 10
    self.area[1] = {x = 0, y = 0, w = w, h = h-buttonheight}
    
    self.oscale = self.scale
    self:createknobs()
    self.gfx_update = true
    --self.area[2] = {x = 0, y = self.area[1].y+self.area[1].h, w = w/2, h = buttonheight}
    --self.area[3] = {x = self.area[2].x+self.area[2].w+1, y = self.area[1].y+self.area[1].h, w = w/2, h = buttonheight}
    --local offs = self.posh*self.scale
    --self.area[4] = {x = offs, y = offs, w = w-2*offs, h = h-buttonheight-2*offs}
  end

  local function GetTrack(trn)
    if trn == -1 then
      return reaper.GetMasterTrack(0)
    else
      return reaper.GetTrack(0, trn)
    end
  end
  
  local function CheckFX(fxguid, trn, fxn)
    if trn and fxn then
      local track = GetTrack(trn)
      if track then
        local cfxguid = reaper.TrackFX_GetFXGUID(track, fxn)
        if cfxguid ~= fxguid then
          --find
          for f = 0, reaper.TrackFX_GetCount(track)-1 do
            local cfxguid = reaper.TrackFX_GetFXGUID(track, f)
            if cfxguid == fxguid then
              --found
              local cfxn = f
              local ctrn = trn
              return true, ctrn, reaper.GetTrackGUID(track), cfxn, cfxguid 
            end
          end
        else
          if fxnotfound[cfxguid] then
            local cfxn = fxn
            local ctrn = trn
            return true, ctrn, reaper.GetTrackGUID(track), cfxn, cfxguid 
          else
            return true
          end
        end
      else
        
      end
    end

    for t = -1, reaper.CountTracks(0)-1 do
      if t ~= trn then
        local track = GetTrack(t)
        local trn2 = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
        for f = 0, reaper.TrackFX_GetCount(track)-1 do
          local cfxguid = reaper.TrackFX_GetFXGUID(track, f)
          if cfxguid == fxguid then
            --found
            local cfxn = f
            local ctrn = math.max(trn2-1,-1)
            return true, ctrn, reaper.GetTrackGUID(track), cfxn, cfxguid 
          end
        end
      end
    end
  end
  
  function Widget:update(info)
    
    if reaper.time_precise() > (self.lastrefresh or 0) then
      reaper.gmem_attach('lbx_gfxanalyzer')
      --self.refresh = reaper.gmem_read(8000000) or 0
      self.refresh = tonumber(reaper.GetExtState(SCRIPT, 'refreshrate')) or 0
      if self.refresh < 1 then
        self.lastrefresh = reaper.time_precise() + 0.1*(1-self.refresh)
      end
      
      self.info = info
      
      local ox = self.data.xpos
      local oy = self.data.ypos
  
      if self.scale ~= self.oscale then
        self:createknobs()
      end
  
      if self.drawcontrols and reaper.time_precise() > self.drawcontrols then
        if next(self.knobclick) == nil then
          self.drawcontrols = nil
          self.gfx_update = true
        end
      end
  
      local ret = false
      for f = 1, #self.data.fx do
        if self.data.fx[f] and not fxnotfound[self.data.fx[f].fxguid] then
          local fnd, trn, trguid, fxnum, fxguid = CheckFX(self.data.fx[f].fxguid, self.data.fx[f].trn, self.data.fx[f].fxnum)
          if fnd then
            if trn then
              fxnotfound[self.data.fx[f].fxguid] = nil
              self.data.fx[f].trn = trn
              self.data.fx[f].trguid = trguid
              self.data.fx[f].fxnum = fxnum
            end
          else
            fxnotfound[self.data.fx[f].fxguid] = true
          end
    
          if not fxnotfound[self.data.fx[f].fxguid] then
            local fx = self.data.fx[f]
            local track = GetTrack(fx.trn)
            if track then
            
              local enabled = reaper.TrackFX_GetEnabled(track, fx.fxnum)
              local offline = reaper.TrackFX_GetOffline(track, fx.fxnum)
              local tfxenabled = reaper.GetMediaTrackInfo_Value(track, 'I_FXEN') 
              local mute = reaper.GetMediaTrackInfo_Value(track, 'B_MUTE')
              local update = reaper.TrackFX_GetParam(track, fx.fxnum, 7)
              if enabled and not offline and mute ~= 1 and tfxenabled ~= 0 and update == 1 then
                fx.last_update = reaper.time_precise()
                fx.vis = true
                ret = true
              else
                if reaper.time_precise() < (fx.last_update or 0)+0.1 then
                  fx.vis = true
                  ret = true
                else
                  fx.vis = false
                end
              end
            end
          end
        end
      end

      local update = ret or self.gfx_update
      if update or (#self.data.fx == 0) then
        update = true
        self:draw2(ox, oy)
      end
      return update
    end
  end

  function Widget:draw()

    local scale = self.scale
    local w, h = gfx.getimgdim(self.bitmap_index)
    
    gfx.a = 1
    gfx.dest = self.bitmap_index
    
    local grey = 0.5
    local padarea = self.area[1]
    gfx.r, gfx.g, gfx.b = 0,0,0
    gfx.rect(padarea.x,padarea.y,padarea.w,padarea.h,1)
    gfx.r, gfx.g, gfx.b = grey,grey,grey
    gfx.rect(padarea.x,padarea.y,padarea.w,padarea.h,0)
    
    return true

  end

  function Widget:draw2(ox, oy)
  
    local scale = self.scale
    local w, h = gfx.getimgdim(self.bitmap_index)
    
    gfx.a = 1
    gfx.dest = self.bitmap_index
    
    local grey = 0.5
    local grey2 = 1
    local padarea = self.area[1]
    --DBG(padarea.w)
    self.smallmode = 0
    if padarea.w < 270 then
      self.smallmode = 2
      self.data.showcontrols = false
    elseif padarea.w < 600 then
      self.smallmode = 1
    end
    
    gfx.b, gfx.g, gfx.r = ((self.data.bgcol&0xFF0000)>>16)/255,((self.data.bgcol&0xFF00)>>8)/255,(self.data.bgcol&0xFF)/255
    gfx.rect(padarea.x,padarea.y,padarea.w,padarea.h,1)
    
    local fx = self.data.fx[1]
    local datafx = self.data.fx
    if fx then
      
      local dim, dim2 = 1, 1
      if (self.data.showcontrols) and (self.drawcontrols or self.data.pinctls) and not next(self.zoomclick) then
        dim = 0.5
        dim2 = 0.75
      end
      gfx.setfont(1,'Lucida Console',12)
    
      local track = GetTrack(fx.trn)
      reaper.gmem_attach('lbx_gfxanalyzer')
      --local bands = reaper.TrackFX_GetParam(track, fx.fxnum, 7)
      local fftsize = fftsizes[reaper.TrackFX_GetParam(track, fx.fxnum, 0)+1]
      local offset = reaper.TrackFX_GetParam(track, fx.fxnum, 1)

      local hop = reaper.TrackFX_GetParam(track, fx.fxnum, 12)
      local hzm = reaper.TrackFX_GetParam(track, fx.fxnum, 13)
      local pw = padarea.w * hzm
      local hoffset = math.floor((pw - padarea.w) * hop)
      
      --local w = ((pw - 4) / bands)
      --local x = 2
      --local col_r, col_g, col_b = 0.2, 0.2, 1

      --gain grid
      sc=(padarea.h)*20/(-offset * math.log(10));

      gfx.r = grey2*dim*self.data.gridintensity
      gfx.g = grey2*dim*self.data.gridintensity
      gfx.b = grey2*dim*self.data.gridintensity
      
      gv = 1
      cnt = 100
      gfx.y = -100
      while gfx.y < padarea.h-10 and cnt > 0 do
        local y=1-math.log(gv)*sc
        if y > gfx.y then
          gfx.line(0,y,pw,y,0)
          --bottom_line = gfx_y;
          gfx.x=0;
          gfx.y=y+2
          gfx.drawnumber(math.log(gv,10)*20,0)
          gfx.drawstr('dB')
          gfx.y=gfx.y + gfx.texth
        end
        gv=gv*0.5
        cnt=cnt-1
        
      end
      
      --grid
      local wsc=pw/math.log(1+400)
      local f = 20
      local ret, srate = reaper.GetAudioDeviceInfo('SRATE','') --reaper.GetSetProjectInfo(0, 'PROJECT_SRATE', 0, false)
      --gfx.r = grey2*dim
      --gfx.g = grey2*dim
      --gfx.b = grey2*dim
      local adjust = 7
      local lx=gfx.x+4
      srate = tonumber(srate)
      
      if srate then
        while f < srate*0.5 do
        
          tx = math.log(1.0+(f/srate*2.0)*400)*wsc -hoffset
          
          dotext = (tx > gfx.x) and (f~=40) and (f~=4000) and (f ~= 15000) and
               ((f<400) or (f >= 1000) or (f == 500)) and ((f<6000) or (f>=10000))
          --DBG(tostring(dotext)..'  '..f)
          if tx > lx then
            local vadj = 0
            if not dotext then
              vadj = gfx.texth+5
            end
            gfx.line(tx,1,tx,padarea.h-2-vadj, false)
          end
          
          if dotext then
            gfx.x = tx +3
            gfx.y = padarea.h - (gfx.texth+3)
            if f >= 1000 then gfx.printf("%dkHz",f*.001) else gfx.printf("%dHz",f) end
          end
            
          if f < 100 then
            f = f + 10
          elseif f < 1000 then
            f = f + 100
          elseif f < 10000 then
            f = f + 1000
          else
            f = f + 5000
          end
        
        end
        
        local dim3 = 1
        if self.data.highlight_selected then
          dim3 = self.data.dimbtnamt
        end
  
        for ffidx = 1, #datafx do
        
          if ffidx ~= self.data.fxidx then
            if not datafx[ffidx].disabled and dim3 > 0 then
              local fx = datafx[ffidx]
              local track = GetTrack(fx.trn)
              
              --check bypass/offline
              --[[local enabled = reaper.TrackFX_GetEnabled(track, fx.fxnum)
              local offline = reaper.TrackFX_GetOffline(track, fx.fxnum)
              local tfxenabled = reaper.GetMediaTrackInfo_Value(track, 'I_FXEN') 
              local mute = reaper.GetMediaTrackInfo_Value(track, 'B_MUTE')
              local update = reaper.TrackFX_GetParam(track, fx.fxnum, 7)
              if enabled and not offline and mute ~= 1 and tfxenabled ~= 0 and update == 1 then]]
              if fx.vis == true then
                --fx.vis = true
                local fftsize = fftsizes[reaper.TrackFX_GetParam(track, fx.fxnum, 0)+1]
                local idx = reaper.TrackFX_GetParam(track, fx.fxnum, 8)
                
                if self.data.usetrackcolor then
                  local bcol = reaper.GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
                  if not bcol or not (bcol & 0x1000000 == 0x1000000) then
                    --default color
                    bcol = 0x1404040
                  end
                  if bcol and (bcol & 0x1000000 == 0x1000000) then
                    local r,g,b = reaper.ColorFromNative(bcol)
                    gfx.r = (r/255) * dim2 * dim3
                    gfx.g = (g/255) * dim2 * dim3
                    gfx.b = (b/255) * dim2 * dim3
                  end
                else
                  gfx.r = (reaper.TrackFX_GetParam(track, fx.fxnum, 9)/255) * dim2 * dim3
                  gfx.g = (reaper.TrackFX_GetParam(track, fx.fxnum, 10)/255) * dim2 * dim3
                  gfx.b = (reaper.TrackFX_GetParam(track, fx.fxnum, 11)/255) * dim2 * dim3
                end
                
                gfx.x = -hoffset
                gfx.y = 0
                
                local xscale=800/(fftsize-4);
        
                if reaper.gmem_read(idx*16384) then
                  for i = 0, fftsize/2 do
                    tx = math.log(1.0+i*xscale)*wsc -hoffset
                    val = reaper.gmem_read(idx*16384+i) --math.floor(reaper.TrackFX_GetParam(track, fx.fxnum, 9+i)) --(idx*128+i)
                    if val then
                      gfx.lineto(tx, math.min(padarea.y+padarea.h-val*padarea.h+2,padarea.y+padarea.h-1),1)
                      if tx > padarea.x+padarea.w then
                        break
                      end
                    end
                  end
                end
              else
                --DBG('XXX')
                --fx.vis = false
              end
              
            end
          end
          
        end
        
        --show selected on top
        local ffidx = self.data.fxidx
        if not datafx[ffidx].disabled then
          local fx = datafx[ffidx]
          local track = GetTrack(fx.trn)
          --check bypass/offline
          --[[local enabled = reaper.TrackFX_GetEnabled(track, fx.fxnum)
          local offline = reaper.TrackFX_GetOffline(track, fx.fxnum)
          local tfxenabled = reaper.GetMediaTrackInfo_Value(track, 'I_FXEN') 
          local mute = reaper.GetMediaTrackInfo_Value(track, 'B_MUTE')
          local update = reaper.TrackFX_GetParam(track, fx.fxnum, 7)

          if enabled and not offline and mute ~= 1 and tfxenabled ~= 0 and update == 1 then]]
          if fx.vis == true then
            --fx.vis = true
            local fftsize = fftsizes[reaper.TrackFX_GetParam(track, fx.fxnum, 0)+1]
            if fftsize then
              local idx = reaper.TrackFX_GetParam(track, fx.fxnum, 8)
              
              if self.data.usetrackcolor then
                local bcol = reaper.GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
                if not bcol or not (bcol & 0x1000000 == 0x1000000) then
                  --default color
                  bcol = 0x1404040
                end
                if bcol and (bcol & 0x1000000 == 0x1000000) then
                  local r,g,b = reaper.ColorFromNative(bcol)
                  gfx.r = (r/255) * dim2 --* dim3
                  gfx.g = (g/255) * dim2 --* dim3
                  gfx.b = (b/255) * dim2 --* dim3
                end
              else
                gfx.r = (reaper.TrackFX_GetParam(track, fx.fxnum, 9)/255) * dim2 --* dim3
                gfx.g = (reaper.TrackFX_GetParam(track, fx.fxnum, 10)/255) * dim2 --* dim3
                gfx.b = (reaper.TrackFX_GetParam(track, fx.fxnum, 11)/255) * dim2 --* dim3
              end
              
              gfx.x = -hoffset
              gfx.y = 0
              
              local xscale=800/(fftsize-4);
      
              if reaper.gmem_read(idx*16384) then
                for i = 0, fftsize/2 do
                  tx = math.log(1.0+i*xscale)*wsc -hoffset
                  val = reaper.gmem_read(idx*16384+i) --math.floor(reaper.TrackFX_GetParam(track, fx.fxnum, 9+i)) --(idx*128+i)
                  if val then
                    gfx.lineto(tx, math.min(padarea.y+padarea.h-val*padarea.h+2,padarea.y+padarea.h-1),1)
                    if tx > padarea.x+padarea.w then
                      break
                    end
                  end
                end
              end
            end
          else
            --DBG('XXX')
            --fx.vis = false
          end
        end
        
        --if reaper.gmem_read(idx*16384) then
          --draw controls
          if self.smallmode ~= 2 and (self.drawcontrols or self.data.pinctls) and not next(self.zoomclick) then
          
            if self.data.showcontrols then
              local alpha = 0.75
              local cc = 0xB0B0B0
            
              --tracks
              local yyy = self.button[1].y + self.button[1].h + 20
              gfx.y = yyy
              gfx.x = 10
              
              self.button[3].x = gfx.x
              self.button[3].y = gfx.y -5
              self.button[3].w = 0
              
              local tab = {}
              local wwsel = gfx.measurestr(' <---')
              for ffidx = 1, #datafx do
                local fx = datafx[ffidx]
                local track = GetTrack(fx.trn)
                --local idx = reaper.TrackFX_GetParam(track, fx.fxnum, 8)
                
                local r,g,b
                if self.data.usetrackcolor then
                  local bcol = reaper.GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
                  if not bcol or not (bcol & 0x1000000 == 0x1000000) then
                    --default color
                    bcol = 0x1404040
                  end
                  if bcol and (bcol & 0x1000000 == 0x1000000) then
                    r,g,b = reaper.ColorFromNative(bcol)
                    r = r/255
                    g = g/255
                    b = b/255
                  end
                else
                  r = (reaper.TrackFX_GetParam(track, fx.fxnum, 9)/255) --* dim2 * dim3
                  g = (reaper.TrackFX_GetParam(track, fx.fxnum, 10)/255) --* dim2 * dim3
                  b = (reaper.TrackFX_GetParam(track, fx.fxnum, 11)/255) --* dim2 * dim3
                end
                
                local _, tname = reaper.GetTrackName(track)
                local _, fxname = reaper.TrackFX_GetFXName(track, fx.fxnum, "")
                local txt
                if self.smallmode == 1 then
                  txt = string.format('%i',fx.trn+1)
                else
                  txt = string.format('%i',fx.trn+1) .. ': '..tname..' - '..string.format('%i',fx.fxnum+1)
                            ..': '..fxname
                end
                local ww = gfx.measurestr(txt) + wwsel
                self.button[3].w = math.max(self.button[3].w, ww)
                tab[ffidx] = {r = r, g = g, b = b, txt = txt}
                
                gfx.x = 10
                gfx.y = gfx.y + 20
              end
              self.button[3].h = gfx.y-self.button[3].y
    
              --[[local b3 = self.button[3]
              local maxy = self.knob[4].y + self.knob[4].h + 10
              gfx.r, gfx.g, gfx.b = 0,0,0
              gfx.a = 0.5
              gfx.rect(0,0,padarea.w --[[b3.x+b3.w+10] ],padarea.h --[[math.max(b3.y+b3.h,maxy)] ],1)
              gfx.a = 1]]
              
              gfx.y = yyy
              gfx.x = 10
              for ffidx = 1, #datafx do
    
                if self.data.fx[ffidx].disabled then
                  gfx.r = tab[ffidx].r * 0.5
                  gfx.g = tab[ffidx].g * 0.5
                  gfx.b = tab[ffidx].b * 0.5
                else
                  gfx.r = tab[ffidx].r  
                  gfx.g = tab[ffidx].g  
                  gfx.b = tab[ffidx].b
                end
                gfx.drawstr(tab[ffidx].txt, 4)
                if not self.data.fx[ffidx].disabled and not self.data.fx[ffidx].vis then
                  gfx.r = 1 
                  gfx.g = 0
                  gfx.b = 0
                  gfx.drawstr(' X ',4)
                end
                if ffidx == self.data.fxidx then
                  gfx.r = 1 
                  gfx.g = 1
                  gfx.b = 1
                  gfx.drawstr(' <---',4)
                end
                
                gfx.x = 10
                gfx.y = gfx.y + 20
              end
  
              local txt
              local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 1)
              local _, dv = reaper.TrackFX_GetFormattedParamValue(track, fx.fxnum, 1, "")
              self:drawknob(self.knob[1],alpha,v,cc)
              if self.smallmode == 1 then
                txt = 'Flr'
              elseif self.smallmode == 0 then
                txt = 'Floor'
              end
              self:drawknoblabel(self.knob[1], txt, dv)
              local _, dv = reaper.TrackFX_GetFormattedParamValue(track, fx.fxnum, 4, "")
              local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 4)
              self:drawknob(self.knob[2],alpha,v,cc)
              if self.smallmode == 1 then
                txt = 'Time'
              elseif self.smallmode == 0 then
                txt = 'Integration time (ms)'
              end
              self:drawknoblabel(self.knob[2], txt, dv)
              local _, dv = reaper.TrackFX_GetFormattedParamValue(track, fx.fxnum, 5, "")
              local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 5)
              self:drawknob(self.knob[3],alpha,v,cc)
              if self.smallmode == 1 then
                txt = 'Slope'
              elseif self.smallmode == 0 then
                txt = 'Slope (dB/octave)'
              end
              self:drawknoblabel(self.knob[3], txt, dv)
              local _, dv = reaper.TrackFX_GetFormattedParamValue(track, fx.fxnum, 0, "")
              local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 0)
              self:drawknob(self.knob[4],alpha,v,cc)
              if self.smallmode == 1 then
                txt = 'FFT'
              elseif self.smallmode == 0 then
                txt = 'FFT size'
              end
              self:drawknoblabel(self.knob[4], txt, dv)

              local v = self.refresh
              self:drawknob(self.knob[6],alpha,v,cc)
              if self.smallmode == 1 then
                txt = 'Rfrsh'
              elseif self.smallmode == 0 then
                txt = 'Refresh rate'
              end
              self:drawknoblabel(self.knob[6], txt, math.floor(self.refresh*100)..'%')
    
              local fx = self.data.fx[self.data.fxidx]
              local track = GetTrack(fx.trn)
              if not self.data.usetrackcolor then
                local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 9)
                self:drawknob(self.knob[7],alpha,v,0xFF0000)
                local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 10)
                self:drawknob(self.knob[8],alpha,v,0x00FF00)
                local v = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 11)
                self:drawknob(self.knob[9],alpha,v,0x0000FF)
              end
              
              self:drawbutton(self.button[1], '-', cc)
              self:drawbutton(self.button[2], '+', cc)
              if self.data.highlight_selected then
                self:drawbutton(self.button[5], 'DIM', cc)
              else
                self:drawbutton(self.button[5], 'DIM', 0x7F7F7F)
              end
              
              if self.data.pinctls then
                if self.smallmode == 1 then
                  self:drawbutton(self.button[4], '<Hide>', 0xC0C0C0, true)
                elseif self.smallmode == 0 then
                  self:drawbutton(self.button[4], '< Hide Controls >', 0xC0C0C0, true)
                end
              else
                if self.smallmode == 1 then
                  self:drawbutton(self.button[4], 'Hide', 0xC0C0C0, true)
                elseif self.smallmode == 0 then
                  self:drawbutton(self.button[4], 'Hide Controls', 0xC0C0C0, true)
                end
              end
              
            else
              if self.data.pinctls then
                if self.smallmode == 1 then
                  self:drawbutton(self.button[4], '<Show>', 0xC0C0C0, true)
                elseif self.smallmode == 0 then
                  self:drawbutton(self.button[4], '< Show Controls >', 0xC0C0C0, true)
                end
              else
                if self.smallmode == 1 then
                  self:drawbutton(self.button[4], 'Show', 0xC0C0C0, true)
                elseif self.smallmode == 0 then
                  self:drawbutton(self.button[4], 'Show Controls', 0xC0C0C0, true)
                end
              end
            end
          end
        --end
      end
      
    else
      gfx.setfont(1,'Lucida Console',12)
      local cc = 0xB0B0B0
      local pad = 10
      local xywh = {x = padarea.x+pad, y = padarea.y+pad, w = padarea.w - pad*2, h = padarea.h - pad*2}
      self:drawbutton(xywh, 'Add Plugin', cc)
    end
    gfx.r, gfx.g, gfx.b = 0,0,0 --grey,grey,grey
    gfx.rect(padarea.x,padarea.y,padarea.w,padarea.h,0)
    
    self.gfx_update = false
    return true
  
  end

  function Widget:drawbutton(btnarea, txt, col, noborder)
  
    local scale = self.scale
    col = col or 0xFFFFFF
    local floor = math.floor
    
    gfx.r = ((col & 0xFF0000) >> 16) / 255
    gfx.g = ((col & 0x00FF00) >> 8) / 255
    gfx.b = (col & 0x0000FF) / 255
    gfx.a = 1
    if not noborder then
      gfx.rect(floor(btnarea.x), floor(btnarea.y), floor(btnarea.w), floor(btnarea.h), 0)
    end
    gfx.x = btnarea.x
    gfx.y = btnarea.y
    gfx.drawstr(txt, 5, btnarea.x+btnarea.w, btnarea.y+btnarea.h)

  end
  
  function Widget:drawknoblabel(knobarea, title, value)
    if self.smallmode == 0 then
      local gw, gh = gfx.measurestr(title)
      local th = gh*2+3
      local offset = math.floor((knobarea.h - th)/2)
      gfx.x = knobarea.x - gw - 10
      gfx.y = knobarea.y + offset
      gfx.drawstr(title, 4)
      local gw, gh = gfx.measurestr(value)
      gfx.x = knobarea.x - gw - 10
      gfx.y = knobarea.y + offset + gh + 3
      gfx.drawstr(value, 4)
    else
      local txt = title..': '..value
      local gw, gh = gfx.measurestr(txt)
      local th = gh
      local offset = math.floor((knobarea.h - th)/2)
      gfx.x = knobarea.x - gw - 10
      gfx.y = knobarea.y + offset
      gfx.drawstr(txt, 4)
    end
  end

  function Widget:drawknob(knobarea, inalpha, value, col, incol)
  
    local scale = self.scale
    
    local x = knobarea.x + knobarea.w/2
    local y = knobarea.y + knobarea.h/2
    local size = knobarea.w
    local insize = knobarea.w - 3*scale

    col = col or 0xFFFFFF
    local floor = math.floor
    
    gfx.r = ((col & 0xFF0000) >> 16) / 255
    gfx.g = ((col & 0x00FF00) >> 8) / 255
    gfx.b = (col & 0x0000FF) / 255
    gfx.a = 1
    gfx.circle(floor(x), floor(y), floor(size/2), 1, 1)
    
    if insize then
      gfx.a = inalpha or 1
      incol = incol or 0x000000
      gfx.r = ((incol & 0xFF0000) >> 16) / 255
      gfx.g = ((incol & 0x00FF00) >> 8) / 255
      gfx.b = (incol & 0x0000FF) / 255
      
      gfx.circle(floor(x), floor(y), floor(insize/2), 1, 1)
      gfx.a = 1
    end
  
    gfx.r = ((col & 0xFF0000) >> 16) / 255
    gfx.g = ((col & 0x00FF00) >> 8) / 255
    gfx.b = (col & 0x0000FF) / 255
    local theta = value * (math.pi*2*0.75) + (0.125*(math.pi*2))
    local outer = (size-insize)
    
    local vx = x - math.sin(theta) * (insize/2 - 3*scale) 
    local vy = y + math.cos(theta) * (insize/2 - 3*scale)
    gfx.circle(floor(vx), floor(vy), math.ceil(1*scale), 1, 1)
    
  end

  function Widget:setscale(s)
    self.scale = s
    self:init()
    self:draw()
  end
  
  function Widget:getextrabitmaps()
    return self.extra_bitmaps or 0
  end

  function Widget:getbitmapindex()
    return self.bitmap_index
  end

  function Widget:setbitmapindex(idx)
    self.bitmap_index = idx
  end

  function Widget:setextrabitmapindex(i, idx)
    self.extra_bitmap_index[i] = idx
  end

  --[[function Widget:onclick(lb, rb, mx, my)
    if lb then
      local ret, t = reaper.GetUserInputs('Enter widget text', 1, 'text:,extrawidth=200', self.data.text)
      if ret then
        self.data.text = tostring(t)
        self:draw()
      end
    end
  end]]

  local function GetFXTab(track)
    local tab = {}
    local pos = 0
    local mstr = ''
    local otn
    for t = 0, reaper.CountTracks()-1 do
    
      local track = reaper.GetTrack(0, t)
      local fxcnt = reaper.TrackFX_GetCount(track)
      for f = 0, fxcnt-1 do
      
        local r, fxid = reaper.TrackFX_GetNamedConfigParm(track, f, 'fx_ident')
        if string.match(fxid, 'gfxanalyzer_lbxstrippermod$') then
        
          local _, fxname = reaper.TrackFX_GetFXName(track, f, "")
          local _, tname = reaper.GetTrackName(track)
          if tname ~= otn then
            if mstr ~= '' then
              mstr = string.match(mstr, '(.+|)')..'<'..string.match(mstr, '.+|(.*)')
            end
            mstr = mstr .. '|>' .. tname
            otn = tname
          end
          tab[pos] = {}
          tab[pos].trnum = math.max(reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')-1,-1)
          tab[pos].trguid = reaper.GetTrackGUID(track)
          tab[pos].fxnum = f
          tab[pos].fxguid = reaper.TrackFX_GetFXGUID(track, f)
          tab[pos].fxname = fxname
        
          mstr = mstr ..'|'..string.format('%i',f+1)..': '..string.gsub(fxname,'|','\\')
          pos = pos + 1
        end
      end
    end
    return tab, mstr
  end
  
  function Widget:SetAllParams()
  
    local fx = self.data.fx
    local p1, p4, p5, p0
    for f = 1, #self.data.fx do
      if f == 1 then
        local track = reaper.GetTrack(0, fx[f].trn)
        if track then
          if reaper.TrackFX_GetFXGUID(track, fx[f].fxnum) == fx[f].fxguid then
            p0 = reaper.TrackFX_GetParamNormalized(track, fx[f].fxnum, 0)
            p1 = reaper.TrackFX_GetParamNormalized(track, fx[f].fxnum, 1)
            p4 = reaper.TrackFX_GetParamNormalized(track, fx[f].fxnum, 4)
            p5 = reaper.TrackFX_GetParamNormalized(track, fx[f].fxnum, 5)
          end
        end
      elseif p0 and p1 and p4 and p5 then
        local track = reaper.GetTrack(0, fx[f].trn)
        if track then
          if reaper.TrackFX_GetFXGUID(track, fx[f].fxnum) == fx[f].fxguid then
            reaper.TrackFX_SetParamNormalized(track, fx[f].fxnum, 0, p0)      
            reaper.TrackFX_SetParamNormalized(track, fx[f].fxnum, 1, p1)      
            reaper.TrackFX_SetParamNormalized(track, fx[f].fxnum, 4, p4)      
            reaper.TrackFX_SetParamNormalized(track, fx[f].fxnum, 5, p5)      
          end
        end
      end
    end
  
  end
  
  function Widget:NewPlug()
    local track
    local seltr = Widg_GetStripTrack()
    if self.data.fx[1] then
      track = GetTrack(self.data.fx[1].trn)
    else
      track = seltr.track
    end
    if track then
    
      local fxn = 'gfxanalyzer_lbxstrippermod'
      if reaper.TrackFX_AddByName(track, fxn, false, -1) == -1 then
        reaper.MB("Cannot find analyzer plugin - please check/rescan fx and try again","Add Analyzer Plugin", 0)
        return
      end
    
      --rename
      local ret, chunk = reaper.GetTrackStateChunk(track, '', false)
      if chunk then
        --find last instance of fxn
        local instance = 0
        for t = 0, reaper.CountTracks(0)-1 do
          local tr = reaper.GetTrack(0, t)
          for f = 0, reaper.TrackFX_GetCount(tr)-1 do
            local _, fxname = reaper.TrackFX_GetFXName(tr, f, "")
            local i2 = string.match(fxname,'LBXAnalyzer (%d+)')
            if i2 then
              instance = math.max(tonumber(i2),instance)
            end
          end
        end
        
        local a,b,c = string.match(chunk,'(.+)(<JS.-gfxanalyzer_lbxstrippermod.*%"%")(.*)')
        if b then
          b = string.gsub(b, '%"%"', '"LBXAnalyzer '..string.format('%i',instance+1)..'"')
          local nchunk = a..b..c
          reaper.SetTrackStateChunk(track, nchunk, false)
        end
      end
      
      local trn = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      local fxnum = reaper.TrackFX_GetCount(track)-1
      local _, fxname = reaper.TrackFX_GetFXName(track, fxnum, "")
      local ptab = {}
      ptab.trn = trn-1
      ptab.trguid = reaper.GetTrackGUID(track)
      ptab.fxnum = fxnum
      ptab.fxguid = reaper.TrackFX_GetFXGUID(track, fxnum)
      ptab.fxname = fxname
      
      self.data.fx = self.data.fx or {}
      local idx = #self.data.fx + 1
      self.data.fx[idx] = ptab
      self.data.fxidx = idx
      
      if idx == 1 then
        self.data.fxguid_id = ptab.fxguid
      end
      self:SetAllParams()
      
    end
  end
  
  function Widget:delete(idx, removeplugin)
    
    if idx > 1 then
    
      if removeplugin then
        local fx = self.data.fx[idx]
        local track = reaper.GetTrack(0, fx.trn)
        if reaper.TrackFX_GetFXGUID(track, fx.fxnum) == fx.fxguid then
          reaper.TrackFX_Delete(track, fx.fxnum)
        end
      end
    
      local tab = {}
      for i = 1, #self.data.fx do
    
        if i ~= idx then
          tab[#tab+1] = self.data.fx[i]
        end
    
      end
      self.data.fx = tab
      self.data.fxidx = math.min(self.data.fxidx, #tab)
    end
    
  end
  
  local function clicked(area, mx, my)
    if mx >= area.x and mx <= area.x+area.w and 
       my >= area.y and my <= area.y+area.h then
       return true
    end
  end

  function Widget:mouseover()
    self.drawcontrols = reaper.time_precise() + 0.1
    self.gfx_update = true
  end

  function Widget:lb_doubleclick(idx, mx, my, shift, ctrl, alt)

    local showctls = self.data.showcontrols
    local knob = self.knob
    local button = self.button
    if showctls and clicked(button[3],mx,my) then
          
      local ty = math.floor((my - button[3].y) / 20) + 1
      self.data.fxidx = F_limit(ty, 1, #self.data.fx)
    
      if self.data.fx[self.data.fxidx].disabled then
        self.data.fx[self.data.fxidx].disabled = nil
      else
        self.data.fx[self.data.fxidx].disabled = true
      end
      
      self.gfx_update = true
      
    elseif clicked(button[4],mx,my) then
    
      self.data.pinctls = not (self.data.pinctls or false)
      self.data.showcontrols = not self.data.showcontrols
      
      self.gfx_update = true
      
    end
  end
  
  function Widget:lb_down(idx, mx, my, shift, ctrl, alt)

    self.gfx_update = true
    if not self.data.initplug then

      local showctls = self.data.showcontrols
      local knob = self.knob
      local button = self.button
      if showctls and clicked(knob[1],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 1
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif showctls and clicked(knob[2],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 4
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif showctls and clicked(knob[3],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 5
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif showctls and clicked(knob[4],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 0
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif showctls and clicked(knob[6],mx,my) then
        local param = -1
        local val = self.refresh
        self.knobclick[idx] = {param = param, val = val, my = my}
  
      --[[elseif clicked(knob[5],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 13
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif clicked(knob[6],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 12
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end]]
      
      elseif showctls and clicked(knob[7],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 9
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif showctls and clicked(knob[8],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 10
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      elseif showctls and clicked(knob[9],mx,my) then
        local fx = self.data.fx[self.data.fxidx]
        if fx then
          local track = GetTrack(fx.trn)
          local param = 11
          local val = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, param)
          self.knobclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = param, val = val, my = my}
        end
      
      elseif showctls and clicked(button[1],mx,my) then
        
        if self.data.fxidx > 1 then
          self:delete(self.data.fxidx, alt)
        end
        
      elseif showctls and clicked(button[2],mx,my) then
        local fxtab, mstr = GetFXTab()
        if self.info then
          gfx.x = self.info.screenx + mx
          gfx.y = self.info.screeny + my
        else
          gfx.x = mx
          gfx.y = my
        end
        mstr = 'New Analyzer Plugin||'..mstr
        local res = OpenMenu(mstr)
        if res > 0 then
          if res == 1 then
            self:NewPlug()
          else
            local ptab = {}
            ptab.trn = fxtab[res-2].trnum
            ptab.trguid = fxtab[res-2].trguid
            ptab.fxnum = fxtab[res-2].fxnum
            ptab.fxguid = fxtab[res-2].fxguid
            ptab.fxname = fxtab[res-2].fxname
    
            self.data.fx = self.data.fx or {}
            local idx = #self.data.fx + 1
            self.data.fx[idx] = ptab
            if idx == 1 then
              self.data.fxguid_id = fxtab[res-2].fxguid
            end
            
            self:SetAllParams()
            --self:draw()
            --return true
          end
        end
      
      elseif showctls and clicked(button[3],mx,my) then
        
        if alt then
          local ty = math.floor((my - button[3].y) / 20) + 1
          self:delete(ty, true)
        else
          local ty = math.floor((my - button[3].y) / 20) + 1
          self.data.fxidx = F_limit(ty, 1, #self.data.fx)
          
          if shift and ctrl then
            for f = 1, #self.data.fx do
              self.data.fx[f].disabled = nil
            end
          elseif shift then
            if self.data.fx[self.data.fxidx].disabled then
              self.data.fx[self.data.fxidx].disabled = nil
            else
              self.data.fx[self.data.fxidx].disabled = true
            end
          elseif ctrl then
            for f = 1, #self.data.fx do
              if f ~= self.data.fxidx then
                self.data.fx[f].disabled = true
              else
                self.data.fx[f].disabled = nil
              end
            end
          end
        end
        
      elseif clicked(button[4],mx,my) then
        self.data.showcontrols = not (self.data.showcontrols or false)
        
      elseif clicked(button[5],mx,my) then
      
        if shift then
          self.buttonclick[idx] = {param = 1, val = self.data.dimbtnamt, my = my}
        else
          self.data.highlight_selected = not (self.data.highlight_selected or false)
        end
        
      else
        --zoom/pos
        
        --calc pos
        local fx = self.data.fx[1]
        if fx and not next(self.zoomclick) then
          local track = GetTrack(fx.trn)
          local z = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 13)
          local zm = z*7 + 1
          local pos = reaper.TrackFX_GetParamNormalized(track, fx.fxnum, 12)
          local area = self.area[1]
          local w = area.w
          
          local zm2 = ((w)*zm)
          local offx = math.ceil(pos*zm2 - w/2)
          offx = math.max(offx,0)
          offx = math.min(offx,(w)*zm-w)
          local val = (mx+offx)/(w*zm)
          reaper.TrackFX_SetParamNormalized(track,fx.fxnum,12,val)
  
          self.zoomclick[idx] = {trn = fx.trn, fxnum = fx.fxnum, param = 13, val = z, my = my, mx = mx}   
        end
        
      end
      
    else
      self:NewPlug()
      self.data.initplug = false
    end
    
  end

  function Widget:lb_move(idx, mx, my, shift, ctrl, alt)
  
    if self.knobclick[idx] then
      local kc = self.knobclick[idx]
      if kc.param == -1 then
      
        --refresh
        local dy = kc.my - my
        local nval = F_limit(kc.val + dy*0.002,0,1)
        self.refresh = nval
        --reaper.gmem_attach('lbx_gfxanalyzer')
        --reaper.gmem_write(8000000, nval)
        reaper.SetExtState(SCRIPT, 'refreshrate', nval, true)
      else
      
        local dy = kc.my - my
        local nval = F_limit(kc.val + dy*0.002,0,1)
        
        if kc.param == 9 or kc.param == 10 or kc.param == 11 then
          local track = GetTrack(kc.trn)
          reaper.TrackFX_SetParamNormalized(track, kc.fxnum, kc.param, nval)
        else
          for i = 1, #self.data.fx do
            local fx = self.data.fx[i]
            local track = GetTrack(fx.trn)
            reaper.TrackFX_SetParamNormalized(track, fx.fxnum, kc.param, nval)
          end
        end
      end
      self.gfx_update = true
      
    elseif self.zoomclick[idx] then
      local zc = self.zoomclick[idx]
      local track = GetTrack(zc.trn)
      local dy = zc.my - my
      local nval = F_limit(zc.val + dy*0.002,0,1)
      reaper.TrackFX_SetParamNormalized(track, zc.fxnum, zc.param, nval)
      
      local pos = reaper.TrackFX_GetParamNormalized(track, zc.fxnum, 12)
      local dx = zc.mx - mx
      local zm = nval*7 + 1
      local area = self.area[1]
      local w = area.w
      local zm2 = ((w)*zm)
      
      if zm2-w ~= 0 then
        pos = F_limit(pos + (dx/(zm2-w)),0,1)
        reaper.TrackFX_SetParamNormalized(track,zc.fxnum,12,pos)
        zc.mx = mx
      end
      self.gfx_update = true
    
    elseif self.buttonclick[idx] then
      local bc = self.buttonclick[idx]
      if bc.param == 1 then
        local dy = bc.my - my
        local nval = F_limit(bc.val + dy*0.01,0,1)
        self.data.dimbtnamt = nval
      end
      self.gfx_update = true
    end
  end

  function Widget:lb_up(idx, mx, my, shift, ctrl, alt)
    if self.knobclick[idx] then 
      self.knobclick[idx] = nil
    end
    if self.zoomclick[idx] then
      self.zoomclick[idx] = nil
    end
    if self.buttonclick[idx] then
      self.buttonclick[idx] = nil
    end
  end

  function Widget:rb_down(idx, mx, my, shift, ctrl, alt)
    
    self.gfx_update = true
    
    local showctls = self.data.showcontrols
    local knob = self.knob
    local button = self.button
    if showctls and clicked(button[5],mx,my) then
      local tk1 = ''
      if self.data.usetrackcolor then
        tk1 = '!'
      end
      local mstr = 'Grid Color|Grid Brightness: '..self.data.gridintensity..'||'..tk1..'Use Track Colors||Refresh Plugin Instances'
      if self.info then
        gfx.x = self.info.screenx + mx
        gfx.y = self.info.screeny + my
      else
        gfx.x = mx
        gfx.y = my
      end
      local res = OpenMenu(mstr)
      if res > 0 then
        if res == 1 then
          local col = self.data.bgcol
          local retval, c = reaper.GR_SelectColor(_,col)
          if retval ~= 0 then
            --if lvar.Mac_revcol then c = MacRevC(c) end
            self.data.bgcol = c
          end
          
        elseif res == 2 then
          local ret, val = reaper.GetUserInputs('Grid Brightness',1,'Brightness (0-1):', self.data.gridintensity)
          val = tonumber(val)
          if ret and val then
            if val >= 0 and val <= 1 then
              self.data.gridintensity = val
            end
          end
        elseif res == 3 then
          self.data.usetrackcolor = not (self.data.usetrackcolor or false)
        elseif res == 4 then
          --In Stripper lua
          ScanResetAnalyzers()
        end
      end
    elseif showctls then
      local seltr = Widg_GetStripTrack()
      if seltr then
        local track = seltr.track
        if track then
        
          local trn = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
          local trguid = reaper.GetTrackGUID(track)
          
          local fxtab, mstr = GetFXTab(track)
          if self.info then
            gfx.x = self.info.screenx + mx
            gfx.y = self.info.screeny + my
          else
            gfx.x = mx
            gfx.y = my
          end
          local res = OpenMenu(mstr)
          if res > 0 then
            local ptab = {}
            ptab.trn = fxtab[res-1].trn
            ptab.trguid = fxtab[res-1].trguid
            ptab.fxnum = fxtab[res-1].fxnum
            ptab.fxguid = fxtab[res-1].fxguid
            ptab.fxname = fxtab[res-1].fxname
  
            self.data.fx = self.data.fx or {}
            self.data.fx[self.data.fxidx] = ptab
            self.data.fxguid_id = fxtab[res-1].fxguid
            --self:draw()
            return true
          end
        end
      end
    else
      --ctls hidden
      if shift then
        self.data.fxidx = self.data.fxidx + 1
        if self.data.fxidx > #self.data.fx then
          self.data.fxidx = 1
        end
      elseif ctrl then
      else
        self.data.highlight_selected = not (self.data.highlight_selected or false)
      end
    end
    
  end
  
  function Widget:rb_move(idx, mx, my, shift, ctrl, alt)
  end
  
  function Widget:rb_up(idx, mx, my, shift, ctrl, alt)
  end

  --function Widget:wheel(mx, my, shift, ctrl, alt, amt)
  --end
  
  function Widget:request_fontlist(fontlist)
  end
  
  return Widget
