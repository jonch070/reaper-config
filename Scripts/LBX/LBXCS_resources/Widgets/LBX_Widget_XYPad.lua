  -- Required params to init values:
  -- main bitmap index (supplied by stripper)
  
  -- self.data should only contain data to be stored and recalled
  
  local Widget = {}
  local fxnotfound = {}
  
  function Widget:new(o)
    o = o or {data = {},
              area = {},
              bitmap_index = -2,
              extra_bitmaps = 0,
              extra_bitmap_index = {},
              scale = 1}
    setmetatable(o, self)
    self.__index = self
    --self:init()
    return o
  end

  function Widget:setdata(datatab)
    self.data = datatab
    if self.data.x_param.fxguid then
      fxnotfound[self.data.x_param.fxguid] = nil
    end
    if self.data.y_param.fxguid then
      fxnotfound[self.data.y_param.fxguid] = nil
    end
  end
  --[[function Widget:setfxguids(datatab)
    self.fxguids = datatab
  end]]

  function Widget:init()
    local buttonheight = math.floor(16*self.scale)
    local w, h = gfx.getimgdim(self.bitmap_index)
    self.posh = 10
    self.area[1] = {x = 0, y = 0, w = w, h = h-buttonheight}
    self.area[2] = {x = 0, y = self.area[1].y+self.area[1].h, w = w/2, h = buttonheight}
    self.area[3] = {x = self.area[2].x+self.area[2].w+1, y = self.area[1].y+self.area[1].h, w = w/2, h = buttonheight}
    local offs = self.posh*self.scale
    self.area[4] = {x = offs, y = offs, w = w-2*offs, h = h-buttonheight-2*offs}
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
    self.info = info
    
    local ox = self.data.xpos
    local oy = self.data.ypos

    local ret = false
    if self.data.x_param and not fxnotfound[self.data.x_param.fxguid] then
      local fnd, trn, trguid, fxnum, fxguid = CheckFX(self.data.x_param.fxguid, self.data.x_param.trn, self.data.x_param.fxnum)
      if fnd then
        --DBG('fnd '..tostring(fnd)..'  '..tostring(trn)..'  '..tostring(trguid))
        if trn then
          fxnotfound[self.data.x_param.fxguid] = nil
          self.data.x_param.trn = trn
          self.data.x_param.trguid = trguid
          self.data.x_param.fxnum = fxnum
        end
      else
        fxnotfound[self.data.x_param.fxguid] = true
      end

      if not fxnotfound[self.data.x_param.fxguid] then
        local track = GetTrack(self.data.x_param.trn)
        if track then
          local val = reaper.TrackFX_GetParamNormalized(track, self.data.x_param.fxnum, self.data.x_param.pnum) 
          if val ~= self.data.xpos then
            self.data.xpos = val
            ret = true
          end
        end
      end
    end
    if self.data.y_param and not fxnotfound[self.data.y_param.fxguid] then

      local fnd, trn, trguid, fxnum, fxguid = CheckFX(self.data.y_param.fxguid, self.data.y_param.trn, self.data.y_param.fxnum)
      if fnd then
        if trn then
          fxnotfound[self.data.y_param.fxguid] = nil
          self.data.y_param.trn = trn
          self.data.y_param.trguid = trguid
          self.data.y_param.fxnum = fxnum
        end
      else
        fxnotfound[self.data.y_param.fxguid] = true
      end
      
      if not fxnotfound[self.data.y_param.fxguid] then
        
        local track = GetTrack(self.data.y_param.trn)
        if track then
          local val = reaper.TrackFX_GetParamNormalized(track, self.data.y_param.fxnum, self.data.y_param.pnum) 
          if 1-val ~= self.data.ypos then
            self.data.ypos = 1-val
            ret = true
          end
        end
      end
    end

    if ret then
      self:draw2(ox, oy)
    end
    return ret
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

    local padarea = self.area[4]
    local x = (self.data.xpos or 0.5)*padarea.w+padarea.x
    local y = (self.data.ypos or 0.5)*padarea.h+padarea.y
    
    gfx.circle(x,y,(self.posh-2)*self.scale,0,1)
    
    local b1 = self.area[2]
    local b2 = self.area[3]
    gfx.rect(b1.x,b1.y,b1.w,b1.h,1)
    gfx.rect(b2.x,b2.y,b2.w,b2.h,1)
    
    gfx.r, gfx.g, gfx.b = 0,0,0
    gfx.setfont(1, 'Arial', 12*self.scale)
    local pad = 4
    local fx = self.data.x_param
    if fx then
      gfx.x = b1.x+pad
      gfx.y = b1.y
      gfx.drawstr(fx.pname,4,b1.x+b1.w-2*pad,b1.y+b1.h)
    end
    local fx = self.data.y_param
    if fx then
      gfx.x = b2.x+pad
      gfx.y = b2.y
      gfx.drawstr(fx.pname,4,b2.x+b2.w-2*pad,b2.y+b2.h)
    end
    
    return true

  end

  function Widget:draw2(ox, oy)
  
    local scale = self.scale
    local w, h = gfx.getimgdim(self.bitmap_index)
    
    gfx.a = 1
    gfx.dest = self.bitmap_index
    
    local grey = 0.5
    gfx.r, gfx.g, gfx.b = 0,0,0
  
    local padarea = self.area[4]
    local x,y
    local r = math.floor((self.posh-2)*self.scale)
    if ox and oy then
      x = (ox)*padarea.w+padarea.x
      y = (oy)*padarea.h+padarea.y
      gfx.circle(x,y,r+1,1,1)
    end    
    
    gfx.r, gfx.g, gfx.b = grey,grey,grey
    local padarea2 = self.area[1]
    gfx.rect(padarea2.x,padarea2.y,padarea2.w,padarea2.h,0)
    
    local x = (self.data.xpos or 0.5)*padarea.w+padarea.x
    local y = (self.data.ypos or 0.5)*padarea.h+padarea.y
    gfx.circle(x,y,r,0,1)
    
    return true
  
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
    local fxcnt = reaper.TrackFX_GetCount(track)
    for f = 0, fxcnt-1 do
    
      local _, fxname = reaper.TrackFX_GetFXName(track, f)
      mstr = mstr ..'|>'..string.gsub(fxname,'|','\\')
      
      local pcnt = reaper.TrackFX_GetNumParams(track, f)
      for p = 0, pcnt-1 do
        tab[pos] = {}
        tab[pos].trnum = math.max(reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')-1,-1)
        tab[pos].trguid = reaper.GetTrackGUID(track)
        tab[pos].fxnum = f
        tab[pos].fxguid = reaper.TrackFX_GetFXGUID(track, f)
        _, tab[pos].fxname = fxname
        tab[pos].pnum = p
        _, tab[pos].pname = reaper.TrackFX_GetParamName(track, f, p)

        if p == pcnt-1 then
          mstr = mstr ..'|<'..string.gsub(tab[pos].pname,'|','\\')
        else
          mstr = mstr ..'|'..string.gsub(tab[pos].pname,'|','\\')
        end
        pos=pos+1

      end
    end
    return tab, mstr
  end
  
  local function SetParams(self, x, y)
    local area = self.area[4]
    local poff = self.posh*self.scale
    self.data.xpos = math.max(math.min((x-poff)/area.w,1),0)
    self.data.ypos = math.max(math.min((y-poff)/area.h,1),0)
    local fx = self.data.x_param
    if fx and not fxnotfound[fx.fxguid] then
      local track = GetTrack(fx.trn)
      if track then
        reaper.TrackFX_SetParamNormalized(track, fx.fxnum, fx.pnum, self.data.xpos)
      end
    end
    local fx = self.data.y_param
    if fx and not fxnotfound[fx.fxguid] then
      local track = GetTrack(fx.trn)
      if track then
        reaper.TrackFX_SetParamNormalized(track, fx.fxnum, fx.pnum, 1-self.data.ypos)
      end
    end
    return true
  end

  function Widget:lb_down(idx, mx, my, shift, ctrl, alt)
    if my < self.area[1].y + self.area[1].h then
      self.active = idx
      local ox = self.data.xpos
      local oy = self.data.ypos
      if SetParams(self,mx,my) then
        self:draw2(ox,oy)
        return true
      end
    end
    
  end

  function Widget:lb_move(idx, mx, my, shift, ctrl, alt)
    if self.active == idx then
      local ox = self.data.xpos
      local oy = self.data.ypos
      if SetParams(self,mx,my) then
        self:draw2(ox,oy)
        return true
      end
    end
  end

  function Widget:lb_up(idx, mx, my, shift, ctrl, alt)
    if self.active == idx then
      self.active = nil
    end
    if my > self.area[2].y and my < self.area[2].y + self.area[2].h then
      local idx
      if mx <= self.area[2].x+self.area[2].w then
        idx = 1
      else
        idx = 2
      end
      local seltr = Widg_GetStripTrack()
      if seltr then
        local track = seltr.track
        if track then
        
          local trn = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
          local trguid = reaper.GetTrackGUID(track)
          
          local fxtab, mstr = GetFXTab(track)
          if self.info then
            gfx.x = self.info.screenx --mx
            gfx.y = self.info.screeny + self.info.widget_h --my
          else
            gfx.x = mx
            gfx.y = my
          end
          local res = OpenMenu(mstr)
          if res > 0 then
            local ptab = {}
            ptab.trn = trn
            ptab.trguid = trguid
            ptab.fxnum = fxtab[res-1].fxnum
            ptab.fxguid = fxtab[res-1].fxguid
            ptab.fxname = fxtab[res-1].fxname
            ptab.pnum = fxtab[res-1].pnum
            ptab.pname = fxtab[res-1].pname
  
            if idx == 1 then
              self.data.x_param = ptab
            else
              self.data.y_param = ptab
            end
            self:draw()
            return true
          end
        end
      end
    end
  end

  function Widget:rb_down(idx, mx, my, shift, ctrl, alt)
  end
  
  function Widget:rb_move(idx, mx, my, shift, ctrl, alt)
  end
  
  function Widget:rb_up(idx, mx, my, shift, ctrl, alt)
  end

  function Widget:wheel(mx, my, shift, ctrl, alt, amt)
  end
  
  function Widget:request_fontlist(fontlist)
  end
  
  return Widget
