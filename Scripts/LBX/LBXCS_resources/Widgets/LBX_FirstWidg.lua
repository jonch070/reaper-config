  -- Required params to init values:
  -- main bitmap index (supplied by stripper)
  
  -- self.data should only contain data to be stored and recalled
  
  local Widget = {}
  local redraw_bitmap
    
  function Widget:new(o)
    o = o or {data = {text = 'This is my first widget.......', textcolor = '0 0 0', textsize = 24}, 
              bitmap_index = -2,
              extra_bitmaps = 1,
              extra_bitmap_index = {},
              scale = 1}
    setmetatable(o, self)
    self.__index = self
    redraw_bitmap = true
    return o
  end

  function Widget:setdata(datatab)
    self.data = datatab
  end
  
  function Widget:update()

    local dirty = self:draw()
    return dirty
  end

  local function RedrawBitmap(self)
    local iidx = self.extra_bitmap_index[1]
    if iidx then
      gfx.r = self.data.r or 1
      gfx.g = self.data.g or 1
      gfx.b = self.data.b or 1
      gfx.setfont(1, 'Arial', self.data.textsize*self.scale)
      local tw, th = gfx.measurestr(self.data.text)

      local w, h = gfx.getimgdim(self.bitmap_index)
      gfx.setimgdim(iidx,-1,-1)
      gfx.setimgdim(iidx,tw,h)
      
      gfx.dest = iidx
      gfx.x = 0
      gfx.y = 0
      gfx.drawstr(self.data.text,4,tw,h)
      
    end
  end

  function Widget:draw()

    local scale = self.scale    
    if redraw_bitmap then
      RedrawBitmap(self)
      redraw_bitmap = false
    end
    
    local w, h = gfx.getimgdim(self.bitmap_index)
    gfx.setimgdim(self.bitmap_index,-1,-1)
    gfx.setimgdim(self.bitmap_index,w,h)
    
    gfx.a = 1
    gfx.dest = self.bitmap_index
    
    local diff = (self.data.speed or 1)*scale
    self.pos = ((self.pos or 0)+diff)

    local tw, th = gfx.getimgdim(self.extra_bitmap_index[1])
    gfx.blit(self.extra_bitmap_index[1],1,0,0,0,tw,th,math.floor(w-self.pos),0)

    if (self.data.speed or 1) > 0 then
      if self.pos > w+tw --[[math.floor(w-self.pos) < 0]] then
        self.pos = 0
      end
    else
      if self.pos < 0 then
        self.pos = w+tw
      end
    end
    return true

  end

  function Widget:setscale(s)
    self.scale = s
    redraw_bitmap = true
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

  function Widget:lb_down(idx, mx, my, shift, ctrl, alt)
    if shift then
      local ret, t = reaper.GetUserInputs('Enter widget text size', 1, 'size:,extrawidth=200', self.data.textsize)
      if ret and tonumber(t) then
        self.data.textsize = tonumber(t)
        redraw_bitmap = true
        self:draw()
      end
    elseif ctrl then
      local ret, t = reaper.GetUserInputs('Enter widget text', 1, 'text:,extrawidth=200', self.data.text)
      if ret then
        self.data.text = tostring(t)
        redraw_bitmap = true
        self:draw()
      end
    else
      self.data.r = math.random()
      self.data.g = math.random()
      self.data.b = math.random()
      redraw_bitmap = true
      self:draw()
    end
  end

  function Widget:lb_move(idx, mx, my, shift, ctrl, alt)
  end

  function Widget:lb_up(idx, mx, my, shift, ctrl, alt)
  end

  function Widget:rb_down(idx, mx, my, shift, ctrl, alt)
  end
  
  function Widget:rb_move(idx, mx, my, shift, ctrl, alt)
  end
  
  function Widget:rb_up(idx, mx, my, shift, ctrl, alt)
  end

  function Widget:wheel(mx, my, shift, ctrl, alt, amt)
    local val = amt/120
    if shift then
      self.data.speed = (self.data.speed or 1)+(val*1)
    else
      self.data.textsize = self.data.textsize + val
      redraw_bitmap = true
      self:draw()
    end
  end
  
  function Widget:request_fontlist(fontlist)
  end
  
  return Widget
