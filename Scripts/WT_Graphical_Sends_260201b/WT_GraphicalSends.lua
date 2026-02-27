sTitle = "WT Graphical Sends"

reaper.ClearConsole()
local function msg(str) reaper.ShowConsoleMsg(tostring(str) .. '\n') end
OS = reaper.GetOS()
script_path = ({reaper.get_action_context()})[2]:match('^.*[/\\]'):sub(1,-2)

function math.Clamp(val, min, max)
  return math.min(math.max(val, min), max)
end

function math.Round(number, decimalPlaces) 
  local precision = 10^(decimalPlaces*-1)
  local number = number + (precision / 2); -- make value >#.5 round up and <#.5 to round down.
  return math.floor(number / precision) * precision
end

local width, height = 600, 600
gfx.init(sTitle, 
  tonumber(reaper.GetExtState(sTitle,"wndw")) or 600,
  tonumber(reaper.GetExtState(sTitle,"wndh")) or 600,
  tonumber(reaper.GetExtState(sTitle,"dock")) or 0,
  tonumber(reaper.GetExtState(sTitle,"wndx")) or 100,
  tonumber(reaper.GetExtState(sTitle,"wndy")) or 50
  )
  
--activePage = 'settings' -- if debugging

cableStyleAssign = {
  master = tonumber(reaper.GetExtState(sTitle,"cableStyleAssignMaster")) or 3,
  send = tonumber(reaper.GetExtState(sTitle,"cableStyleAssignSend")) or 6,
  send3plus = tonumber(reaper.GetExtState(sTitle,"cableStyleAssignSend3plus")) or 5,
  receive = tonumber(reaper.GetExtState(sTitle,"cableStyleAssignReceive")) or 4,
  receive3plus = tonumber(reaper.GetExtState(sTitle,"cableStyleAssignReceive3plus")) or 5
  }
  
cableCols = {
  master = {reaper.ColorFromNative(tonumber(reaper.GetExtState(sTitle,"cableColMaster")) or 9013633)},
  send = {reaper.ColorFromNative(tonumber(reaper.GetExtState(sTitle,"cableColSend")) or 9013633)},
  receive = {reaper.ColorFromNative(tonumber(reaper.GetExtState(sTitle,"cableColReceive")) or 9013633)},
  send3plus = {reaper.ColorFromNative(tonumber(reaper.GetExtState(sTitle,"cableColSend3plus")) or 9013633)},
  receive3plus = {reaper.ColorFromNative(tonumber(reaper.GetExtState(sTitle,"cableColReceive3plus")) or 9013633)}
}

cableUseCCol = {
  master = tonumber(reaper.GetExtState(sTitle,"cableUseCColMaster")) or 1,
  send = tonumber(reaper.GetExtState(sTitle,"cableUseCColSend")) or 1,
  send3plus = tonumber(reaper.GetExtState(sTitle,"cableUseCColSend3plus")) or 0,
  receive = tonumber(reaper.GetExtState(sTitle,"cableUseCColReceive")) or 1,
  receive3plus = tonumber(reaper.GetExtState(sTitle,"cableUseCColReceive3plus")) or 0
}

msr = {
  showMaster = tonumber(reaper.GetExtState(sTitle,"msrShowMaster")) or 1,
  showSend = tonumber(reaper.GetExtState(sTitle,"msrShowSend")) or 1,
  showReceive = tonumber(reaper.GetExtState(sTitle,"msrShowReceive")) or 1
}

showLinks = tonumber(reaper.GetExtState(sTitle, 'showLinks')) or 1
customColStrength = {value = tonumber(reaper.GetExtState(sTitle, 'customColStrength')) or 10}
minimumCustomColLum = {value = tonumber(reaper.GetExtState(sTitle, 'minimumCustomColLum')) or 33}
toolbarCablePreviews = tonumber(reaper.GetExtState(sTitle, 'toolbarCablePreviews')) or 1
maxRecentSendTargets = {value = tonumber(reaper.GetExtState(sTitle, 'maxRecentSendTargets')) or 3}
maxPopularSends = {value = tonumber(reaper.GetExtState(sTitle, 'maxPopularSends')) or 3}


  ---------- SCALING -----------

gfx.ext_retina = 1 

function scaleToDrawImg(self)
  local i = self.img
  if scaleMult == 1.5 then i = self.img..'_150' end
  if scaleMult == 2 then i = self.img..'_200' end 
  return i
end

function setScale(scale)
  scaleMult = scale
  if scaleMult == 1 then textScaleOffs = 0 end
  if scaleMult == 1.5 then textScaleOffs = 4 end
  if scaleMult == 2 then textScaleOffs = 8 end
  doArrange = true
  
  pixelScale = 1
  if OS:find("Win") == nil and OS ~= 'Other' then
    pixelScale = scaleMult -- because OSX pretends everything is 1x, use to convert returned measurements to actual pixels
  end
  
end

if scaleMult == nil then -- set initial scaleMult 
  local nScale = 1
  if gfx.ext_retina > 1.33 then nScale = 1.5 end
  if gfx.ext_retina > 1.66 then nScale = 2 end
  setScale(nScale)
  ext_retinaOld = gfx.ext_retina
end

function scaleDimension(el, dim, scale)
  local scaledProp = 'scaled' .. dim:sub(1,1):upper() .. dim:sub(2)
  el[scaledProp] = el[dim] * scale
end



  ---------- COLOURS -----------

function luminanceFromRGB(r, g, b) return math.sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b) end

function luminanceToRGB(r, g, b, targetLum) -- force RGB to the given luminance

  local thisLum = luminanceFromRGB(r, g, b) 
  if thisLum == 0 then r,g,b,thisLum = 1,1,1,1 end -- black causes a divide by zero, nudge it to prevent that

  local scale = targetLum / thisLum
  local newR, newG, newB, resultLum, i, continue = nil,nil,nil, nil, 0, true
  while continue and i<20 do -- keep increaing rgb until the luminance is more unwrong
    newR, newG, newB = math.Clamp(r*scale, 0, 255), math.Clamp(g*scale, 0, 255), math.Clamp(b*scale, 0, 255)
    resultLum = luminanceFromRGB(newR, newG, newB)
    if math.abs(resultLum - targetLum) <= 0.5 then  -- is that near enough to the chosen targetLum?
      continue = false -- yeah, near enough, stop here
    else 
      scale = scale * (targetLum / resultLum) -- still too dark, increase scale by the ratio of the difference and go again
      i = i+1
    end
  end
  
  return newR, newG, newB
end

function getTrackCustomColor(track)
  local trackCol = reaper.GetTrackColor(track)
  if trackCol == 0 then return nil end -- nope
  local r,g,b = reaper.ColorFromNative(trackCol)
  local currentLum = luminanceFromRGB(r, g, b) 
  local targetLum = minimumCustomColLum.value*2.55 -- minimumCustomColLum is a percentage, because humans
  if currentLum < targetLum then r,g,b = luminanceToRGB(r,g,b, targetLum) end -- fix custom color luminance if its too low
  return {r,g,b}
end

function setCol(col)
  if col[1] and col[2] and col[3] then
    local r = col[1] / 255
    local g = col[2] / 255
    local b = col[3] / 255
    local a = 1
    if col[4] ~= nil then a = col[4] / 255 end
    gfx.set(r,g,b,a)
  else
    gfx.a = 1
  end
end

colEmptyArea = {51,51,51}

function compositeCols(c1, c2, s) 
  -- composite c2 over c1 with strength s (0-1). Ignores opacity in c1, c2.
  local r = (1-s)*c1[1] + s*c2[1]
  local g = (1-s)*c1[2] + s*c2[2]
  local b = (1-s)*c1[3] + s*c2[3]
  return {r,g,b}
end

  ---------- TEXT -----------

textPadding = 6

if OS:find("Win") ~= nil then

  gfx.setfont(1, "Calibri", 13)
  gfx.setfont(2, "Calibri", 15)
  gfx.setfont(3, "Calibri", 18)
  gfx.setfont(4, "Calibri", 22)
  
  gfx.setfont(5, "Calibri", 19)
  gfx.setfont(6, "Calibri", 22)
  gfx.setfont(7, "Calibri", 27)
  gfx.setfont(8, "Calibri", 33)
  
  gfx.setfont(9, "Calibri", 26)
  gfx.setfont(10, "Calibri", 30)
  gfx.setfont(11, "Calibri", 36)
  gfx.setfont(12, "Calibri", 44)
  
  baselineShift = {}

elseif OS == 'Other' then

  gfx.setfont(1, "Ubuntu", 10)
  gfx.setfont(2, "Ubuntu", 12)
  gfx.setfont(3, "Ubuntu", 14)
  gfx.setfont(4, "Ubuntu", 17)
  
  gfx.setfont(5, "Ubuntu", 13)
  gfx.setfont(6, "Ubuntu", 15)
  gfx.setfont(7, "Ubuntu", 20)
  gfx.setfont(8, "Ubuntu", 24)
  
  gfx.setfont(9, "Ubuntu", 19)
  gfx.setfont(10, "Ubuntu", 23)
  gfx.setfont(11, "Ubuntu", 28)
  gfx.setfont(12, "Ubuntu", 32)
  
  baselineShift = {}

else

  gfx.setfont(1, "Helvetica", 9)
  gfx.setfont(2, "Helvetica", 11)
  gfx.setfont(3, "Helvetica", 14)
  gfx.setfont(4, "Helvetica", 16)
  
  gfx.setfont(5, "Helvetica", 13)
  gfx.setfont(6, "Helvetica", 15)
  gfx.setfont(7, "Helvetica", 18)
  gfx.setfont(8, "Helvetica", 22)
  
  gfx.setfont(9, "Helvetica", 18)
  gfx.setfont(10, "Helvetica", 20)
  gfx.setfont(11, "Helvetica", 26)
  gfx.setfont(12, "Helvetica", 30)
  
  baselineShift = {2,2,2,3,
                   1,3,4,4,
                   3,2,3,3}
  
end



function text(str,x,y,w,h,align,col,style,lineSpacing,vCenter,wrap)
  local lineSpace = (lineSpacing or 11)*scaleMult
  setCol(col or {255,255,255})
  gfx.setfont(style or 1)
  local lines = nil
  if wrap == true then lines = textWrap(str,w)
  else
    lines = {}
    for s in string.gmatch(str or '', "([^#]+)") do
      table.insert(lines, s)
    end
  end
  if vCenter ~= false and #lines > 1 then y = y - lineSpace/2 end
  for k,v in ipairs(lines) do
    gfx.x, gfx.y = x,y
    gfx.drawstr(v,align or 0,x+(w or 0),y+(h or 0))
    y = y + lineSpace
  end
end

function textWrap(str,w) -- returns array of lines
  local lines,curlen,curline,last_sspace = {}, 0, "", false
  -- already translated text
  -- enumerate words
  for s in str:gmatch("([^%s-/]*[-/]* ?)") do
    local sspace = false -- set if space was the delimiter
    if s:match(' $') then
      sspace = true
      s = s:sub(1,-2)
    end
    local measure_s = s
    if curlen ~= 0 and last_sspace == true then
      measure_s = " " .. measure_s
    end
    last_sspace = sspace

    local length = gfx.measurestr(measure_s)
    if length > w then
      if curline ~= "" then
        table.insert(lines,curline)
        curline = ""
      end
      curlen = 0
      while w>0 and  length>w do -- split up a long word, decimating measure_s as we go
        local wlen = string.len(measure_s) - 1
        while wlen > 0 do
          local sstr = string.format("%s%s",measure_s:sub(1,wlen), wlen>1 and "-" or "")
          local slen = gfx.measurestr(sstr)
          if slen <= w or wlen == 1 then
            table.insert(lines,sstr)
            measure_s = measure_s:sub(wlen+1)
            length = gfx.measurestr(measure_s)
            break
          end
          wlen = wlen - 1
        end
      end
    end
    if measure_s ~= "" then
      if curlen == 0 or curlen + length <= w then
        curline = curline .. measure_s
        curlen = curlen + length
      else -- word would not fit, add without leading space and remeasure
        table.insert(lines,curline)
        curline = s
        curlen = gfx.measurestr(s)
      end
    end
  end
  if curline ~= "" then
    table.insert(lines,curline)
  end
  return lines
end


  --------- IMAGES ----------
  
imgBufferOffset = 500  
bufferPinkValues ={}

function loadImage(idx, name)
  
  local i = idx 
  if i then
    local str = script_path.."/WT_GraphicalSends_Images/"..name..".png"
    if OS:find("Win") ~= nil then str = str:gsub("/","\\") end
    if gfx.loadimg(i, str) == -1 then 
      msg(str.." not found")
    end
  end
  
  -- look for pink
  gfx.dest = idx
  gfx.x,gfx.y = 0,0
  if isPixelPink(gfx.getpixel()) then --top left is pink
    local bufW,bufH = gfx.getimgdim(idx)
    gfx.x,gfx.y = bufW-1,bufH-1
    if isPixelPink(gfx.getpixel()) then --bottom right also pink
      local tx, ly, bx, ry = 0,0,0,0
      
      gfx.x,gfx.y = 0,0 
      while isPixelPink(gfx.getpixel()) do
        tx = math.floor(gfx.x+1)
        gfx.x = gfx.x+1
      end
      
      gfx.x,gfx.y = 0,0
      while isPixelPink(gfx.getpixel()) do
        ly = math.floor(gfx.y+1)
        gfx.y = gfx.y+1
      end
      
      gfx.x,gfx.y = bufW-1,bufH-1 
      while isPixelPink(gfx.getpixel()) do
        bx = math.floor(bufW - gfx.x)
        gfx.x = gfx.x-1
      end
      
      gfx.x,gfx.y = bufW-1,bufH-1 
      while isPixelPink(gfx.getpixel()) do
        ry = math.floor(bufH - gfx.y)
        gfx.y = gfx.y-1
      end
      
      --reaper.ShowConsoleMsg(name..' top x pink = '..tx..', left y pink = '..ly..', bottom x pink = '..bx..', right y pink = '..ry..'\n')
      bufferPinkValues[idx] = {tx=tx, ly=ly, bx=bx, ry=ry} -- apparently lua understands this, nice
      
    end
  end
  gfx.dest = -1 -- reset that
  
end

function isPixelPink(r,g,b) 
  if (r==1 and g==0 and b==1) or (r==1 and g==1 and b==0) then -- yellow is also pink. The world's a weird place.
    return true 
  else return false 
  end 
end

function getImage(img)
  if imageIndex == nil then imageIndex = {} end
  for i,v in pairs(imageIndex) do
    if i==img then return v end
  end
  
  --not already in a buffer, make a new one
  local buf = nil
  local i = imgBufferOffset
  while buf == nil do -- find the next empty buffer and assign
    local h,w = gfx.getimgdim(i)
    if h==0 and w==0 then buf=i end
    i = i+1
  end
  imageIndex[img] = buf
  --msg('image: '..img..' to '..buf)
  loadImage(buf, img)  
  return buf
end

function pinkBlit(img, srcx, srcy, destx, desty, tx, ly, bx, ry, unstretchedC2W, unstretchedR2H, stretchedC2W, stretchedR2H, imageTile, buffer, bufferPreexists)
  
  if imageTile == true and ((stretchedC2W>unstretchedC2W) or (stretchedR2H>unstretchedR2H)) then -- will not directly pinkBlit, it will recursively pinkBlit a grid of tiles
    
    if buffer and not bufferPreexists then 
      --msg('\n set buffer '..buffer..' for imageTiling pinkBlit')
      gfx.dest = buffer
      gfx.setimgdim(buffer, tx+bx+stretchedC2W-2, ly+ry+stretchedR2H-2) -- create the buffer for this mask.
      destx, desty = 0, 0
    end
    
    local tileW, tileH = tx + unstretchedC2W + bx - 2, ly + unstretchedR2H + ry - 2 --size of one full tile
    local numTilesX, numTilesY = math.floor(stretchedC2W / tileW), math.floor(stretchedR2H / tileH) -- how many full tiles will fit?
    local remainderW, remainderH = stretchedC2W - (numTilesX * tileW), stretchedR2H - (numTilesY * tileH) -- the remainder bits

    for row = 0, numTilesY - 1 do -- draw the grid of full unsullied tiles with direct blit (no pink stretching)
      for col = 0, numTilesX - 1 do
        gfx.blit(img, 1, 0, srcx + 1, srcy + 1, tileW, tileH, destx + (col * tileW), desty + (row * tileH), tileW, tileH)
      end
    end
    
    if remainderW > 0 then -- draw the right edge column with pink stretching
      for row = 0, numTilesY - 1 do 
      pinkBlit(img, srcx, srcy, destx + (numTilesX * tileW), desty + (row * tileH), tx, ly, bx, ry, unstretchedC2W, unstretchedR2H, remainderW, unstretchedR2H, false, buffer, true)
        --end
      end
    end
    if remainderH > 0 then -- draw the bottom edge row with pink stretching
      for col = 0, numTilesX - 1 do 
        pinkBlit(img, srcx, srcy, destx + (col * tileW), desty + (numTilesY * tileH), tx, ly, bx, ry, unstretchedC2W, unstretchedR2H, unstretchedC2W, remainderH, false, buffer, true)
      end
    end
    if remainderW > 0 and remainderH > 0 then -- draw the bottom right corner tile with pink stretching
      pinkBlit(img, srcx, srcy, destx + (numTilesX * tileW), desty + (numTilesY * tileH), tx, ly, bx, ry, unstretchedC2W, unstretchedR2H, remainderW, remainderH, false, buffer, true)
    end
    
    return
    
  else
  
    -- stretching pinkBlit --
    
    if not bufferPreexists then
      
      if buffer then 
        --msg('\n set buffer '..buffer..' for stretching pinkBlit')
        gfx.dest = -1
        gfx.setimgdim(buffer, tx+bx+stretchedC2W-2, ly+ry+stretchedR2H-2) -- create the buffer for this mask.
        gfx.dest = buffer
        destx, desty = 0, 0
      end
    end
    
    gfx.blit(img, 1, 0, srcx +1, srcy +1, tx-1, ly-1, destx, desty, tx-1, ly-1)
    gfx.blit(img, 1, 0, srcx +tx, srcy +1, unstretchedC2W, ly-1, destx+tx-1, desty, stretchedC2W, ly-1)
    gfx.blit(img, 1, 0, srcx +tx +unstretchedC2W, srcy +1, bx-1, ly-1, destx+tx-1+stretchedC2W, desty, bx-1, ly-1)
    
    gfx.blit(img, 1, 0, srcx+1, ly, tx-1, unstretchedR2H, destx, desty+ly-1, tx-1, stretchedR2H)
    gfx.blit(img, 1, 0, srcx +tx, ly, unstretchedC2W, unstretchedR2H, destx+tx-1, desty+ly-1, stretchedC2W, stretchedR2H)
    gfx.blit(img, 1, 0, srcx +tx +unstretchedC2W, ly, bx-1, unstretchedR2H, destx+tx-1+stretchedC2W, desty+ly-1, bx-1, stretchedR2H)
    
    gfx.blit(img, 1, 0, srcx+1, ly +unstretchedR2H, tx-1, ry-1, destx, desty+ly-1+stretchedR2H, tx-1, ry-1)
    gfx.blit(img, 1, 0, srcx +tx, ly +unstretchedR2H, unstretchedC2W, ry-1, destx+tx-1, desty+ly-1+stretchedR2H, stretchedC2W, ry-1)
    gfx.blit(img, 1, 0, srcx +tx +unstretchedC2W, ly +unstretchedR2H, bx-1, ry-1, destx+tx-1+stretchedC2W, desty+ly-1+stretchedR2H, bx-1, ry-1)
    
  end
  
end


function findBiggestFlowY(el)
  local previousElBiggestY = 0
  if el.flowEl then -- recursively run this while this flow element has its own flow element
    previousElBiggestY = findBiggestFlowY(el.flowEl) or 0 
  end
  local eY, eH = (el.arrY or el.y), (el.arrH or el.h)
  if previousElBiggestY > (eY + eH) then 
    return previousElBiggestY 
    else return eY + eH 
  end
end

function getTrackYPos(track)
  local _, screentoclientY = gfx.screentoclient(0,0)
  if reaper.ValidatePtr(track, 'MediaTrack*')==true then
    if OS:find("Win") == nil and OS ~= 'Other' then -- then OSX, count screen y backwards
      return (screentoclientY - reaper.GetMediaTrackInfo_Value(track, "I_TCPSCREENY")) * pixelScale -- pixelScale converts OSX pseudo-measurements to actual pixels
    else
      return reaper.GetMediaTrackInfo_Value(track, "I_TCPSCREENY")
    end
  end
end

function toEdge(self,edge,weight) -- sets an edge to another element's edge. Called by el:arrange()
  local weight  = weight or 1
  if edge == 'left' then -- my left edge
     if self.l[3] == 'left' then msg('left toEdge left is redundant') end
     if self.l[3] == 'right' then return (((self.l[2].arrX or self.l[2].x) + (self.l[2].arrW or self.l[2].w)) * weight) + self.arrX end
   end
   if edge == 'top' then -- my top edge
     if self.t[3] == 'top' then return self.t[2].arrY + self.y end
     if self.t[3] == 'bottom' then return (((self.t[2].arrY or self.t[2].y) + (self.t[2].arrH or self.t[2].h)) * weight) - self.arrH end
     if self.t[3] == 'parentBottom' then return math.floor((self.parent.arrH or self.parent.h) * weight) + self.arrY end
   end
   if edge == 'right' then -- my right edge
     if self.r[3] == 'left' then msg('right toEdge left not available') end
     if self.r[3] == 'right' then return (((self.r[2].arrX or self.r[2].x) + (self.r[2].arrW or self.r[2].w)) * weight) - self.arrX + self.arrW end
   end
   if edge == 'bottom' then -- my bottom edge
     if self.b[3] == 'top' then msg('bottom toEdge top not available') end
     if self.b[3] == 'bottom' then return (((self.b[2].arrY or self.b[2].y) + (self.b[2].arrH or self.b[2].h)) * weight) - self.arrY + self.arrH end
   end
end




---------- ELEMENTS ----------


els = {}

function adoptChild(parent, child)
  if parent.children then parent.children[#parent.children + 1] = child
  else parent.children = {child}
  end
end

function AddEl(o)

  if o.parent then adoptChild(o.parent, o) end
  els[#els + 1] = o

  if o.mouseOver==nil then o.mouseOver = function(self)
      if o.img and o.iType==3 then 
        --msg('mouseover '..(self.arrX or self.x or 'nope'))
        self.iFrame=1
        doDraw=true
      end
    end
  end
  
  if o.showTooltip~=nil then o.showTooltip(o) 
  else o.showTooltip = function(self)
      if self.toolTip ~= nil then
        --msg('adding a toolTip timer')
        if addTimer(self,'toolTip',0.5) == true then
          if self.onTimerComplete == nil then self.onTimerComplete = {} end
          self.onTimerComplete.toolTip = function()
            --msg('showTooltip '..(self.arrX or self.x or 'nope'))
            local windX, windY = reaper.GetMousePosition()
            reaper.TrackCtl_SetToolTip(self.toolTip, windX + (12*scaleMult), windY + (16*scaleMult), false)
          end
        end
      end
    end
  end
  
  if o.mouseAway~=nil then o.mouseAway(o) 
  else o.mouseAway = function(self)
    if o.img and o.iType==3 and o.iFrame~=0 then
      o.iFrame=0
      doDraw=true
    end
    --msg('mouiseAway')
    reaper.TrackCtl_SetToolTip('',0,0,true)
    if self.toolTip ~= nil then removeTimer(o,'toolTip') end
  end
    
  end
  
  if o.mouseDown~=nil then o.mouseDown(o) 
  else o.mouseDown = function(self)
      if o.img and o.iType==3 then 
        self.iFrame=2
        doDraw=true
      end
      if o.onMouseDown then o.onMouseDown(o) end
      if o.onDrag then
        dX, dY = mouseDrag(self)
        o.onDrag(dX, dY, self)
      end
    end
  end
  if o.mouseUp~=nil then o.mouseUp(o) 
  else o.mouseUp = function(self)
    --msg('mouseUp '..(self.arrX or self.x or 'nope'))
    end
  end
  if o.mouseWheel~=nil then o.mouseWheel(o) 
  else o.mouseWheel = function(self)
    --msg('mouseUp '..(self.arrX or self.x or 'nope'))
    end
  end
  
  o.scaleDimensions = function()
    if o.x then scaleDimension(o, 'x', scaleMult) end
    if o.y then scaleDimension(o, 'y', scaleMult) end
    if o.w then scaleDimension(o, 'w', scaleMult) end
    if o.h then scaleDimension(o, 'h', scaleMult) end
    if o.innerPadding then scaleDimension(o, 'innerPadding', scaleMult) end
    if o.xInnerPadding then scaleDimension(o, 'xInnerPadding', scaleMult) end
    if o.yInnerPadding then scaleDimension(o, 'yInnerPadding', scaleMult) end
  end
  
  o:scaleDimensions()
  
  if o.valueDependants then -- go to any valueDependants and add this El to their valueDependantOf
    for i, dependant in ipairs(o.valueDependants) do
      if not dependant.valueDependantOf then dependant.valueDependantOf = {} end
      table.insert(dependant.valueDependantOf, {el=o})
    end
  end
  
  if o.valueDependantOf then -- conversely, if this El has valueDependantOf set, add it to those El's valueDependants
    for i, dependantOf in ipairs(o.valueDependantOf) do
      if not dependantOf.valueDependants then dependantOf.valueDependants = {} end
      table.insert(dependantOf.valueDependants, {el=o})
    end
  end
  
  o.updateValueDependants = function(self)
    if self.valueDependants then
      for i, dependant in ipairs(self.valueDependants) do
        if not dependant.disregard and dependant.el.onValueChange then
          dependant.el:onValueChange() -- onValueChange all my valueDependants, except any marked to disregard
        end
      end
      for i, dependant in ipairs(self.valueDependants) do dependant.disregard = nil end --all done now, so clear any disregard marks
    end
  end

end

function mouseDrag(self)
  if dragStart == nil then 
    dragStart = {x=gfx.mouse_x, y=gfx.mouse_y}
    draggingEl = self
  end
  local dX, dY = gfx.mouse_x - dragStart.x, gfx.mouse_y - dragStart.y
  
  local ctrl = gfx.mouse_cap&4
  if ctrl == 4 then -- ctrl
    if dragStart.fine ~= true then
      dragStart = {x=dragStart.x+dX, y=dragStart.y+dY}
      dragStart.fine = true
    end
    dX, dY = (gfx.mouse_x - dragStart.x)*0.25, (gfx.mouse_y - dragStart.y)*0.25
  end
  return dX/scaleMult, dY/scaleMult --divide by scaleMult because all calculations are at 100%
end

El = {}
function El:new(o)
  local o = o or {}
  self.__index = self
  if o.parent == 'none' then o.parent = nil
  else o.parent = o.parent or canvas 
  end
  
  o.arrange = function(self)
 
    o.arrX, o.arrY, o.arrW, o.arrH = o.scaledX or 0, o.scaledY or 0, o.scaledW or 0, o.scaledH or 0
    local preArrX, preArrY, preArrW, preArrH = o.arrX, o.arrY, o.arrW, o.arrH
 
    if o.parent then
      o.flowHidden, o.parentClippedHidden = nil, nil
      local parentScrollbarW = 0
      local availableParentW = (o.parent.arrW or o.parent.w) - parentScrollbarW -- width may be lost to a scrollBar
      local xPadding, yPadding = 0,0
      if o.parent.scaledXInnerPadding then xPadding = o.parent.scaledXInnerPadding end
      if o.parent.scaledYInnerPadding then yPadding = o.parent.scaledYInnerPadding end
      if xPadding==0 and yPadding==0 and o.parent.scaledInnerPadding then
        xPadding, yPadding = o.parent.scaledInnerPadding, o.parent.scaledInnerPadding
      end
      
      if o.flowEl~=nil then
        local fx = o.arrX + (o.flowEl.arrX or o.flowEl.x) + (o.flowEl.arrW or o.flowEl.w) + xPadding
        local fy = o.arrY + (o.flowEl.arrY or o.flowEl.y)
        if (fx + xPadding + o.arrW) > (o.parent.arrX + availableParentW) then -- then flow to the next row
          fx = o.x + (o.parent.arrX or o.parent.x or 0) + xPadding
          fy = o.y + findBiggestFlowY(self.flowEl) + (self.y or 0) + yPadding
        end
        o.arrX, o.arrY = fx, fy
        
        if ((o.arrY or o.y) + (o.arrH or o.h) + yPadding) > ((o.parent.arrY or o.parent.y) + (o.parent.arrH or o.parent.h)) and o.parent.isScrollbarParentY~=true then
          o.flowHidden = true -- el has extended below the bottom of its parent
        end
        
      else
        o.arrX = (o.parent.arrX or o.parent.x or 0) + o.arrX + xPadding
        if o.screenY then -- an absolute screen position has been set
          local _, screentoclientY = gfx.screentoclient(0,0)
          if OS:find("Win") == nil and OS ~= 'Other' then o.arrY = o.screenY
          else o.arrY = o.screenY + screentoclientY
          end
        else o.arrY = (o.parent.arrY or o.parent.y or 0) + o.arrY + yPadding 
        end
      end
      
      if o.parent.isScrollbarParentY==true and o.ignoreScrollY ~= true then
        if o.arrY+o.arrH+yPadding-o.parent.arrY > (o.parent.scrollableH or 0) then o.parent.scrollableH = o.arrY+o.arrH+yPadding-o.parent.arrY end -- I am the deepest scroll
      end
      
      if o.arrX+o.arrW+xPadding > (o.parent.arrX or o.parent.x) + availableParentW then o.parentClippedHidden = true end -- doesn't fit inside parent
      if o.arrY+o.arrH+yPadding > (o.parent.arrY or o.parent.y) + (o.parent.arrH or o.parent.h) then o.parentClippedHidden = true end -- doesn't fit inside parent
      if o.ignoreParentClippedHidden and o.ignoreParentClippedHidden~=false then o.parentClippedHidden = nil end
      
    end

    --add e.g. to element definition : b={toEdge, canvas, 'bottom', 0.5}
    if o.l ~= nil then o.arrX = o.l[1](self,'left',o.l[4]) end
    if o.t ~= nil then o.arrY = o.t[1](self,'top',o.t[4]) end
    if o.r ~= nil then o.arrW = o.r[1](self,'right',o.r[4]) end
    if o.b ~= nil then o.arrH = o.b[1](self,'bottom',o.b[4]) end
    if o.minW ~= nil and o.arrW < o.minW then o.arrW = o.minW end
    if o.minH ~= nil and o.arrH < o.minH then o.arrH = o.minH end
    
    if o.offStage == true then o.arrW, o.arrH = nil, nil end -- I'm not even here, so I shouldn't affect flow or whatnot
    
    if o.arrX~=preArrX or o.arrY~=preArrY or o.arrW~=preArrW or o.arrH~=preArrH then --check if arrange has changed the el's bounds
      doDraw = true
    end
    
    if self.isScrollbarParentY==true then self:propagateScrollParentY(self) end -- I am scrollParentY, recursively set that in all my children
    
    if o.onArrange then o:onArrange() end

  end -- end of arrange function
  
  o.draw = function(self)
    if self.col then setCol(self.col) end
    
    --override the drawing of an el by returning false here, for example...
    if o.offStage == true then return false end -- I was intentionally set as it not being all about me
    if o.flowHidden == true then return false end -- arrange flowed me outside my parent
    if o.parent and o.parent.flowHidden == true then return false end -- my parent was flowHidden so I am too
    if o.parentClippedHidden == true then return false end -- I don't fit in my parent
    if o.parent and o.parent.parentClippedHidden == true then return false end -- my parent was clippedHidden so I am too
    
    if o.onDraw then o:onDraw(self) end
  end
  
  if o.onFps then needing_fps[#needing_fps + 1] = o end
  
  AddEl(o)
  setmetatable(o, self)
  return o
end


function El:purge()
  --msg('purging')
  for j,k in pairs(els) do
    if k == self then
      if self.children ~= nil then 
        for l,m in pairs(self.children) do
          m:purge() 
        end 
      end
      table.remove(els,j)
    end
  end
end


function El:setOffStage(bool)
  local setting = bool or false
  if self.children ~= nil then 
    for l,m in pairs(self.children) do
      m:setOffStage(bool) 
    end 
  end
  self.offStage = setting
end

function El:propagateScrollParentY(parent)
  if self.children ~= nil then 
    for j,k in pairs(self.children) do
      if k.ignoreScrollY~=true then -- I don't scroll, and neither do my children
        k:propagateScrollParentY(parent)
        k.scrollParentY = parent
      end
    end 
  end
end


function El:primative(props)
  local o = self:new(props)
  o.shape = props.shape or "rect"
  o.x = props.x or 0
  o.y = props.y or 0
  o.w = props.w or 50
  o.h = props.h or 50
  o.col = props.col or {0,0,0,0}
  local base_draw, base_arrange = o.draw, o.arrange -- Save the base element's methods
  o.arrange = function(self)
    base_arrange(self) -- call the inherited arrange
  end
  
  o.draw = function(self)
    
    local scrollY = 0
    if self.scrollParentY then scrollY = self.scrollParentY.scrollY end
    local drawX, drawY, drawW, drawH = self.arrX or self.x, (self.arrY or self.y) + scrollY, self.arrW or self.w, self.arrH or self.h
    if base_draw(self) ~= false then -- call the inherited draw, which also checks if the el is hidden and returns false
      
      gfx.dest = -1
      if self.shape == "circle" then
        if drawW&1==0 then -- cicle width is an even number but Reaper circles must be odd
          local x,y,w = drawX-1, drawY, drawW
          gfx.circle(x+w/2,y+(w/2),(w-2)/2,1,1) 
          gfx.circle(x+w/2,y+(w/2)-1,(w-2)/2,1,1)
          gfx.circle(x+(w/2)+1,y+(w/2)-1,(w-2)/2,1,1)
          gfx.circle(x+(w/2)+1,y+(w/2),(w-2)/2,1,1)
        else
          local radius = drawW/2
          gfx.circle(drawX + radius , drawY + radius, radius, 1)
        end
        
      elseif self.shape == 'poly' then
        local passList = {}
        for i,v in pairs(self.coords) do
          table.insert(passList, (v[1]*scaleMult) + drawX)
          table.insert(passList, (v[2]*scaleMult) + drawY)
        end
        gfx.triangle(table.unpack(passList))
      elseif self.shape == "rect" and self.w and self.h then
        gfx.rect(drawX, drawY, drawW, drawH, 1)
      end
      
      if self.img ~= nil then
        
        maskBuffer = nil
        if self.maskedCol then maskBuffer = 1023 end
        local imageTile = self.tile or false
        gfx.a = (self.img.a or 255) / 255
        self.drawImg = scaleToDrawImg(self) -- adds _150 or _200 to name
        if self.imgIdx == nil then self.imgIdx = getImage(self.drawImg) end
        if self.measuredImgW==nil or self.measuredImgH==nil then self.measuredImgW, self.measuredImgH = gfx.getimgdim(self.imgIdx) end
        local pinkAdjustedImgW, pinkAdjustedImgH = self.measuredImgW, self.measuredImgH
        local srcX, srcY, pinkXY, pinkWH = 0, 0, 1, 2
        if bufferPinkValues[self.imgIdx] then pinkAdjustedImgW, pinkAdjustedImgH = self.measuredImgW-2, self.measuredImgH-2 end

        local frameW = nil
        if self.iType ~= nil then
          if self.iType == 3 or self.iType == '3_manual' then 
            frameW = pinkAdjustedImgW/3 -- pinkAdjustedImgW is just measuredImgW, or that minus pink
            srcX = (self.iFrame or 0) * (frameW or 0)
          end
        end
        
        if bufferPinkValues[self.imgIdx] then -- image has pink
          local tx, ly, bx, ry = bufferPinkValues[self.imgIdx].tx, bufferPinkValues[self.imgIdx].ly, bufferPinkValues[self.imgIdx].bx, bufferPinkValues[self.imgIdx].ry
          local needsStretching = not ((frameW or self.measuredImgW) == drawW and pinkAdjustedImgH == drawH) -- could be pink stretched, but isn't being
          
          if needsStretching then -- do pink stretching 
            local srcW = (frameW and frameW+2-tx-bx) or (self.measuredImgW-tx-bx)
            pinkBlit(self.imgIdx, srcX, srcY, drawX, drawY, tx, ly, bx, ry, srcW, self.measuredImgH-ly-ry, drawW-tx-bx+pinkWH, drawH-ly-ry+pinkWH, imageTile, maskBuffer)
          else --its a pink image, but its going to drawn at size, so just simple blit it.
            if maskBuffer then msg('Error : tried simplified blitting of a complex mask image') end
            gfx.blit(self.imgIdx, 1, 0, srcX+pinkXY, srcY+pinkXY, drawW, drawH, drawX, drawY, drawW, drawH)
          end
          
          if maskBuffer and needsStretching then -- pinkBlit will have prepared a mask instead of drawing to screen, now use it
            gfx.dest = maskBuffer 
            gfx.muladdrect(0, 0, drawW, drawH, 0, 0, 0, 1, self.maskedCol[1]/255, self.maskedCol[2]/255, self.maskedCol[3]/255, 0)
            gfx.dest = -1
            gfx.blit(maskBuffer, 1, 0, 0, 0, drawW, drawH, drawX, drawY, drawW, drawH)
            gfx.setimgdim(maskBuffer, 0, 0)
          end
        else --image with no pink, simple blit
          if maskBuffer then gfx.setimgdim(maskBuffer, drawW, drawH) end -- create the buffer for this mask. UNTESTED.
          gfx.blit(self.imgIdx, 1, 0, srcX, srcY, frameW or self.measuredImgW, self.measuredImgH, drawX, drawY, drawW, drawH)
        end
      end
      
      if self.text ~= nil then
        local p = self.text.padding or textPadding
        local tx,tw = drawX + p, drawW - 2*p
        local style = (self.text.style + textScaleOffs) or 1
        local thisBaselineShift = baselineShift[style] or 0
        text(self.text.str,tx,drawY+thisBaselineShift,tw,drawH,self.text.align,self.text.col,style,self.text.lineSpacing,self.text.vCenter,self.text.wrap)
      end
      
    end
  end -- end of draw function
  
  if o.img then
    o.onDpiChange = function(self)
      o.drawImg, o.imgIdx, o.measuredImgW, measuredImgH = nil, nil, nil, nil
    end
  end
  
  return o
end

function El:rect(props)
  props = props or {}
  props.shape = "rect"
  return self:primative(props)
end

function El:button(props)
  props = props or {}
  if props.img and props.iType==nil then props.iType=3 end
  
  local providedOnMouseDown = props.onMouseDown
  props.onMouseDown = function(self)
    if providedOnMouseDown then providedOnMouseDown(self) end
    if not self.onDrag then activeMouseElement = nil end --non-dragging buttons should respond to the initial mouseDown then stop listening
  end
  
  return self:primative(props)
end


function El:toggleValueButton(props)
  props = props or {}
  local button = self:button(props)
  
  button.onMouseDown = function(self)
    if props.onToggle then 
      local currentValue = props.getValue and props.getValue(self) or 0
      props.onToggle(self, currentValue)
    end
    activeMouseElement = nil
  end
  
  button.onReaperChange = function(self)
    local currentValue = props.getValue and props.getValue(self) or 0
    if self.paramV == nil or self.paramV ~= currentValue then
      local imgName = props.img:gsub('_off$', ''):gsub('_on$', '') -- image name without '_off' or '_on'
      if currentValue==0 or currentValue==false or currentValue==nil then self.img = imgName..'_off'
      else self.img = imgName..'_on'
      end
      self.imgIdx = nil
      self.paramV = currentValue
    end
  end
  
  button:onReaperChange() -- run it when you first make it
  return button
end


function El:circle(props) -- draws a circle centred at xy if radius provided, otherwise fitting a box from xy to xy+wh
  props = props or {}
  props.shape = "circle"
    if props.radius ~= nil then
      props.x = props.x - props.radius
      props.y = props.y - props.radius
      props.w, props.h = props.radius*2, props.radius*2
      props.radius = nil -- go away
    end
  return self:primative(props)
end

function El:polygon(props)
  props = props or {}
  props.shape = "poly"
  return self:primative(props)
end

function El:dropDown(props)
  props = props or {}
  props.options = props.options or {'Option 1', 'Option 2', 'Option 3'}
  props.selectedIndex = props.selectedIndex or 1
  props.img = props.img or 'dropDown'
  
  local container = self:rect(props)
  container.options = props.options
  container.selectedIndex = props.selectedIndex
  container.dropAnchor = El:rect{parent=container, x=0, y=0, t={toEdge, container, 'bottom', 1}, col={255,0,0,255}, ignoreParentClippedHidden=true} -- where the drop will drop from
  
  container.onMouseDown = function(self)
    
    local menuItems = {} -- build the string for gfx.showmenu : a list of fields separated by '|' , prefix '!' for checked
    for i, option in ipairs(self.options) do 
      if i == self.selectedIndex then table.insert(menuItems, '!' .. option) -- the chosen one
      else table.insert(menuItems, option) -- others
      end
    end
    local str = table.concat(menuItems, '|') -- concat it into a single string
    
    gfx.x, gfx.y = self.dropAnchor.arrX or self.dropAnchor.x, self.dropAnchor.arrY or self.dropAnchor.y
    local rtn = gfx.showmenu(str)
    if rtn > 0 then
      self.selectedIndex = rtn
      self.text.str = self.options[self.selectedIndex]
      if props.onChange then props.onChange(self.selectedIndex, self.options[self.selectedIndex], self) end
      doDraw = true
    end
  end
  
  container.text = {style = 2, align = 4, str = props.options[props.selectedIndex], col = props.text.col or {255,255,255} }
  
  return container
end

function El:colPreset(props)
  props.w, props.h, props.col = 36, 36, {0,50,150,0}
  local container = self:rect(props)
  
  El:rect({parent=container, x=4, y=4, w=28, h=28, col=props.presetCol, interactive=false  })
  El:button{parent=container, w=36, h=36, img='swatch', swatchCol=props.presetCol,
    onMouseDown = function(self)
      cableCols[self.parent.parent.cableType] = self.swatchCol
      self.parent.parent.rollerFill.col = cableCols[self.parent.parent.cableType]
      doPopulate = true
    end
  }

  return container
end

function El:colChooser(props)
  props.w, props.h, props.col, props.activeCol = 160,54, {100,50,50,0}, props.activeCol or {0,0,0}
  local container = self:rect(props)
  
  container.rollerFill = El:primative({parent=container, x=-1, y=-1, w=78, h=52, shape='poly', coords={{2,26}, {26,2}, {77,52}, {28,52}}, col=cableCols[props.cableType], interactive=false  })
  container.roller = El:button{parent=container, w=78, h=52, img='colChooser',
    onMouseDown = function(self)
      local retval, col = reaper.GR_SelectColor()
      if retval==1 then
        cableCols[self.parent.cableType] = {reaper.ColorFromNative(col)}
        self.parent.rollerFill.col = cableCols[self.parent.cableType]
        doPopulate = true
      end
    end
  }
  
  El:colPreset({parent=container, x=60, y=18, w=78, h=52, presetCol = props.presets[1] })
  El:colPreset({parent=container, x=92, y=18, w=78, h=52, presetCol = props.presets[2] })
  El:colPreset({parent=container, x=124, y=18, w=78, h=52, presetCol = props.presets[3] })
  
  return container
end

function El:readout(props)
  props = props or {}
  local container = self:rect(props)
  props.value = props.value or {value=nil} -- value needs to be wrapped in a table so it can be changed withouit breaking the pointer
  
  if props.units and props.units.units then
    local unitsStyle = (props.units.style or props.text.style) + textScaleOffs
    gfx.setfont(unitsStyle)
    local unitsWidth = (gfx.measurestr(props.units.units) + 14)/scaleMult -- Measure units string
    local marginEater = -8/scaleMult 
    local initialStr = props.value.value or props.text.str
    if props.decimals and props.value.value then initialStr = string.format("%."..props.decimals.."f", props.value.value) end
    container.valueText = El:rect{parent=container, x=0, y=0, w=-1*unitsWidth - marginEater, h=props.h, r={toEdge, container, 'right', 1},
      text={style=props.text.style, align=props.text.align, str=initialStr, col=props.text.col}, col={255,0,0,0}, interactive=false }
    container.unitsText = El:rect{parent=container, x=marginEater, y=0, w=unitsWidth, h=props.h, flow=true,
      text={style=props.units.style or props.text.style, align=4, str=props.units.units, col=props.units.col}, col={0,0,255,0}, interactive=false }
  end
  
  container.onValueChange = function(self)
    --msg('readout container.onValueChange')
    if self.decimals then self.valueText.text.str = string.format("%."..self.decimals.."f", math.Round(self.value.value, self.decimals))
    else self.valueText.text.str = self.value.value
    end
    doDraw = true
  end
  
  container.doubleClick = props.doubleClick or function(self)
    
    local retval, user_input = reaper.GetUserInputs('Enter Value ('..self.units.units..')', 1, 'Value ('..self.valMin..self.units.units..' to '..self.valMax..self.units.units..'):', self.value.value)
    if retval then
      local newVal = tonumber(user_input)
      if newVal and newVal >= self.valMin and newVal <= self.valMax then
        self.value.value = newVal
        
        if self.valueDependantOf then -- If this readout is dependantOf an element, mark it as disregard in that element's valueDependants and trigger parent's onValueChange
          for i, dependantOf in ipairs(self.valueDependantOf) do
            if dependantOf.el.valueDependants then
              for j, dependant in ipairs(dependantOf.el.valueDependants) do
                if dependant.el == self then dependant.disregard = true break end
              end
            end
            if dependantOf.el.onValueChange then dependantOf.el.onValueChange() end -- Tell the element I'm dependantOf to do onValueChange
          end
        end
        
        self:onValueChange()
      else
        local retry = reaper.ShowMessageBox("Enter a value from "..self.valMin.." to "..self.valMax..", retry?", 'Value out of range', 1)
        if retry == 1 then self:doubleClick() end
      end
    end
    
  end
  return container
end




function El:knob(props)
  props = props or {}
  local dragGearing = props.dragGearing or 1
  
  local container = El:rect{parent=props.parent, x=props.x, y=props.y,  w=props.w, h=props.h, col=props.col or {100,0,0,0}, value=props.value, valMin=props.valMin, valMax=props.valMax,
    decimals=props.decimals, valueDependants = props.valueDependants, ignoreParentClippedHidden = props.ignoreParentClippedHidden, interactive=false}
 
  container.onValueChange = function(dVal, isDrag)

    if dVal==0 and isDrag==true then 
      container.dragCatcher.initDragVal = container.value.value -- reset drag starting value ro current value when dragging but dVal is zero
    end 
    if isDrag~=true then 
      container.dragCatcher.initDragVal = nil -- not a drag, discard any stored drag starting value
      if dVal then container.value.value = math.Clamp(container.value.value + dVal, props.valMin, props.valMax) end
    else 
      dVal = dVal * dragGearing -- is a drag, perhaps rescale for finer input
      local newVal = math.Clamp(container.dragCatcher.initDragVal + dVal, props.valMin, props.valMax)
      container.value.value = newVal
    end
    if container.decimals then container.value.value =  math.Round(container.value.value, container.decimals) end
    container:updateValueDependants()
    
  end
  
  container.dragCatcher = El:rect{parent=container, w=props.w, h=props.h,  
    onDrag = function(dX, dY, self)
      local dVal = dX - dY
      container.onValueChange(dVal, true)
    end,
    mouseWheel = function(self, wheel_amt)
      if wheel_amt then container.onValueChange(wheel_amt, false) end
    end
  }
  
  return container
end




function El:sweepIndicatorKnob(props)
  props = props or {} 
  
  local outerCircle = El:circle{parent=props.parent, x=props.x, y=props.y, flow=props.flow, w=props.circleSize, h=props.circleSize, col=props.colOutline, interactive=false}
  local innerCircle = El:circle{parent=outerCircle, x=2, y=2, w=props.circleSize-4, h=props.circleSize-4, col=props.colBG, interactive=false}
  
  local sweepSize = props.circleSize-8
  local sweepIndicator = El:sweepIndicator{parent=outerCircle, x=4, y=4, w=sweepSize, h=sweepSize, maskImg = props.maskImg or 'sweepIndicator_mask',
    startAngleOffs = props.startAngleOffs, endAngleOffs=props.endAngleOffs, value=props.value, valMin=props.valMin, valMax=props.valMax,
    col=props.colSweep, segmentUnlitCol=props.colBG }
  
  local valueDependants = {{el = sweepIndicator}} -- a table of elements that should update when the readout has a new value (because double click)
  local readout = nil
  if props.readout then -- don't prvide readout props if you don't want a readout
    readout = El:readout{parent=props.parent, x=props.readout.x, y=props.readout.y, w=props.readout.w, h=props.readout.h, flow=props.readout.flow, col = props.colBG, 
      value=props.value, valMin=props.valMin, valMax=props.valMax, decimals = props.decimals, units = props.readout.units,
      text={style=props.text.style, align=6, str=props.text.str, col=props.colSweep}, ignoreParentClippedHidden = props.ignoreParentClippedHidden }
    table.insert(valueDependants, {el = readout})
  end
  
  local knob = El:knob{parent=outerCircle, x=0, y=0, w=props.circleSize, h=props.circleSize, ignoreParentClippedHidden = props.ignoreParentClippedHidden,
    value=props.value, decimals=props.decimals, valMin=props.valMin, valMax=props.valMax, dragGearing = props.dragGearing, valueDependants = valueDependants}
  return knob, readout
end




function El:sweepIndicator(props)
  props = props or {}
  local segmentUnlitCol = props.segmentUnlitCol or {51,51,51,255}
  local segmentLitCol = props.col or {256,128,0,255}
  local w, h = props.w or 18, props.h or 18
  local r, cx, cy = w/2, h/2, math.min(w, h) / 2  -- width, height and radius of a circle that fills the element
  local startAngleOffs = (props.startAngleOffs or 0) * math.pi / 180  -- convert degrees to radians
  local endAngleOffs = (props.endAngleOffs or 0) * math.pi / 180  -- convert degrees to radians
  props.value = props.value or {value=0.5} -- value is in a table so its value can be changed without breaking the pointer
  local container = El:rect{parent=props.parent, x=props.x, y=props.y,  w=w, h=h, col=segmentLitCol, maskImg=props.maskImg, 
    value = props.value, valMin=props.valMin or 0, valMax=props.valMax or 1, interactive=false}
  
  --five static segments (bottom-left, left, top, right, bottom-right) with centres at (cx, cy)
  local segBL = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx-r,cy+r}, {cx,cy+r}}, interactive=false, col=segmentUnlitCol, globalDraw=false}
  local segL = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx-r,cy+r}, {cx-r,cy-r}}, interactive=false, col=segmentUnlitCol, globalDraw=false}
  local segT = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx-r,cy-r}, {cx+r,cy-r}}, interactive=false, col=segmentUnlitCol, globalDraw=false}
  local segR = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx+r,cy-r}, {cx+r,cy+r}}, interactive=false, col=segmentUnlitCol, globalDraw=false}
  local segBR = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx+r,cy+r}, {cx,cy+r}}, interactive=false, col=segmentUnlitCol, globalDraw=false}
  
  --the variable poly that does the bit where the angle is less than a whole segement
  local segVariEnd = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx,cy+r}, {cx,cy+r}}, interactive=false, col=segmentLitCol, globalDraw=false}
  --second variable poly for the starting partial segment (from startAngleOffs to first complete segment)
  local segVariStart = El:polygon{parent=container, x=0, y=0, w=w, h=h, coords={{cx,cy}, {cx,cy+r}, {cx,cy+r}}, interactive=false, col=segmentLitCol, globalDraw=false}
  
  container.onValueChange = function(self)
    --msg('sweepIndicator onValueChange')
    local displayVal = (self.value.value - self.valMin) / (self.valMax - self.valMin) -- remap value to be from 0 to 1
    self.children[6].col, self.children[7].col = self.col or segmentLitCol, self.col or segmentLitCol
    local angleRange = 2 * math.pi - startAngleOffs - endAngleOffs
    local v = startAngleOffs + (displayVal * angleRange)
    local segBoundaries = {0, math.pi/4, 3*math.pi/4, 5*math.pi/4, 7*math.pi/4, 2*math.pi} -- a table of the angle (in radians) boundaries of each fixed segemnt
    self.children[1].col, self.children[2].col, self.children[3].col, self.children[4].col, self.children[5].col = segmentUnlitCol, segmentUnlitCol, segmentUnlitCol, segmentUnlitCol, segmentUnlitCol-- Reset all segments to unlit
    
    local endAngle = 2 * math.pi - endAngleOffs
    for i = 1, 5 do -- iterate full segements and light them if they're wholey between v and startAngle, and haven't been cut off by endAngle
      if startAngleOffs <= segBoundaries[i] and v >= segBoundaries[i+1] and segBoundaries[i+1] <= endAngle then
        self.children[i].col = self.col or segmentLitCol
      end
    end
    
    local targetBoundary = v -- when no segements are lit, the top boundary is v itself
    for i = 1, 5 do -- iterate boundaries to find the first boundary of the first segment that will be lit when the indicator is full (i.e. when v is at engAngle)
      if startAngleOffs <= segBoundaries[i] and endAngle >= segBoundaries[i+1] then
        targetBoundary = segBoundaries[i]
        break
      end
    end
    
    local function angleToContainerEdge(angle) -- returns vertex {x,y} on the container edge based on which segment the angle is within
      local dx, dy = -math.sin(angle), math.cos(angle)
      if angle < segBoundaries[2] then return {cx + dx * (r / dy), cy + r} -- its on the bottom edge
      elseif angle < segBoundaries[3] then -- its on the left edge
        return {cx - r, cy + dy * (r / -dx)}
      elseif angle < segBoundaries[4] then -- its on the top edge
        return {cx + dx * (-r / dy), cy - r}
      elseif angle < segBoundaries[5] then -- its on the right edge
        return {cx + r, cy + dy * (r / dx)}
      else return {cx + dx * (r / dy), cy + r} -- its on the bottom edge
      end
    end
    
    --place segVariStart, the fist variable poly
    if v < targetBoundary then -- v is so low that there are no lit segements. segVariEnd will draw this bit, segVariStart can be hidden (sent far away)
      segVariStart.coords = { {10000,10000} , {10000,10000} , {10000,10000} }
    else -- set segVariStart between the start offset and the first lit segment
      segVariStart.coords[1] = segVariEnd.coords[1] -- anyone know the centre coord? Ah, thanks segVariEnd
      segVariStart.coords[2] = angleToContainerEdge(startAngleOffs)
      segVariStart.coords[3] = angleToContainerEdge(targetBoundary)
    end
    
    --place segVariEnd, the second variable poly
    local boundaryBeforeV = startAngleOffs  -- the lowest that the first segement could be is the startAngleOffs, so start there
    for i = #segBoundaries, 1, -1 do -- iterate the segment boundaries backwards to fins the first boundary that v follows, or startAngleOffs if it gets that far
      if v >= segBoundaries[i] then
        boundaryBeforeV = math.max(segBoundaries[i], startAngleOffs)
        break
      end
    end
    segVariEnd.coords[2] = angleToContainerEdge(boundaryBeforeV)
    segVariEnd.coords[3] = angleToContainerEdge(v)
    
    doDraw = true
  end
  
  container.onReaperChange = function(self)
    self:onValueChange()
  end

  container.draw = function(self)

    local buf, j = nil, imgBufferOffset
    while buf == nil do -- find the next empty buffer and assign
      local h,w = gfx.getimgdim(j)
      if h==0 and w==0 then buf=j; break end
      j = j+1
    end
    --msg(' using buffer '..buf..' at '..self.arrW..' x '..self.arrH)
    gfx.setimgdim(buf, self.arrW, self.arrH) -- create the buffer for this mask.
    gfx.dest = buf
    
    for i, child in ipairs(self.children) do -- iterate my children, who are globalDraw=false, and draw them to buf
      setCol(child.col)
      gfx.a2=0 --setCol will have set an alpha, buit we there needs to not be one
      local passList = {}
      for i,v in pairs(child.coords) do
        table.insert(passList, (v[1]*scaleMult))
        table.insert(passList, (v[2]*scaleMult))
      end
      --msg('gfx.triangle '..i..', to coords '..passList[1]..' '..passList[2]..' '..passList[3]..' '..passList[4]..' '..passList[5]..' '..passList[6])
      gfx.triangle(table.unpack(passList))
    end
    
    local scaledMaskImg = nil
    if self.maskImg then
      scaledMaskImg = self.maskImg
      if scaleMult == 1.5 then scaledMaskImg = self.maskImg..'_150' end
      if scaleMult == 2 then scaledMaskImg = self.maskImg..'_200' end 
    end
    
    local maskImg = getImage(scaledMaskImg)
    local maskW, maskH = gfx.getimgdim(maskImg)
    gfx.mode, gfx.dest = 3, buf -- set up to blit into buf with mode 3 (+1 for additive blend, +2 to disable source alpha)
    gfx.blit(maskImg, 1, 0, 0, 0, maskW, maskH, 0, 0, self.arrW, self.arrH)
    gfx.mode, gfx.dest = 0, -1 -- reset gfx.mode and dest
    local scrollY = 0
    if self.scrollParentY then scrollY = self.scrollParentY.scrollY end
    gfx.blit(buf, 1, 0, 0, 0, self.arrW, self.arrH, self.arrX, self.arrY + scrollY, self.arrW, self.arrH)
    --msg('blit buf '..buf..', at '..self.arrW..' '..self.arrH..' '..maskW..' '..maskH)
    gfx.setimgdim(buf,0,0) -- clear the buf buffer. 
    
  end
  
  return container
end


function VAL2DB(val) -- convert linear value to dB
  if val == nil or val <= 0 then return -145 end
  return 20 * math.log(val, 10)
end


function sendVol_to_value(vol)
  local centerslider = reaper.DB2SLIDER(0.0)
  local volslider = reaper.DB2SLIDER(VAL2DB(vol))
  local ang
  if centerslider < 1000.0 then
    if volslider < centerslider then ang = math.max((volslider-centerslider)/centerslider, -1.0)   
    else ang = (volslider-centerslider)/(1000-centerslider)
    end
  else ang = math.max(-1.0, math.min(volslider / 500.0 - 1,1.0))
  end
  return (ang + 1.0) / 2.0
end


function El:cableChunk(props)
  props = props or {}
  props.chanIdx = props.parent.chanIdx or 0
  
  props.onValueChange = function(dVal, self, isDrag)
    
    if not (self and dVal) then return end
    if not firstSelectedTrack then return end
    if floatPanel.offStage==true then floatPanel:setOffStage(false) end

    floatPanelMute.offStage = (self.parent.cableType == 'master') -- I am the bool ninja
    
    local function processDragValue(currentdB)
      if dVal==0 and isDrag==true then  self.initDragVal = currentdB end -- reset drag starting value to current value when dragging but dVal is zero
      if isDrag~=true then self.initDragVal = nil -- not a drag, discard any stored drag starting value
      else dVal = dVal*0.1 -- is a drag, rescale for finer input
      end
      local draggedVal = math.Clamp(((self.initDragVal or currentdB) + dVal), -145, 12)
      return (10^(draggedVal / 20)) -- convert back to linear
    end
    
    if self.parent.cableType=='master' then -- master / parent cable
      local _, vol = reaper.GetTrackUIVolPan(firstSelectedTrack)
      local voldB = 20 * math.log(vol, 10)
      local rangedVal = processDragValue(voldB)
      
      reaper.SetTrackUIVolume(firstSelectedTrack, rangedVal, false, false, 0)
      floatPanel:onReaperChange(self.parent, 'master', 0, rangedVal, props.maskedCol or {255,128,255,255}, 0)
      
    elseif self.parent.thisSendTrack then -- send cable
      local sendsCount = reaper.GetTrackNumSends(firstSelectedTrack, 0)
      for i = 0, sendsCount -1 do
        if reaper.GetTrackSendInfo_Value(firstSelectedTrack, 0, i, 'P_DESTTRACK') == self.parent.thisSendTrack then
          local _, sendLevel = reaper.GetTrackSendUIVolPan(firstSelectedTrack, i)
          local sendLeveldB = 20 * math.log(sendLevel, 10)
          local rangedVal = processDragValue(sendLeveldB)
          
          reaper.SetTrackSendUIVol(firstSelectedTrack, i, rangedVal, 0)
          floatPanel:onReaperChange(self.parent, 'send', i, rangedVal, props.maskedCol or {255,128,255,255}, props.chanIdx)
          break
        end
      end
      
    elseif self.parent.thisReceiveTrack then -- receive cable
      local receivesCount = reaper.GetTrackNumSends(firstSelectedTrack, -1)
      for i = 0, receivesCount -1 do
        if reaper.GetTrackSendInfo_Value(firstSelectedTrack, -1, i, 'P_SRCTRACK') == self.parent.thisReceiveTrack then
          local _, receiveLevel = reaper.GetTrackReceiveUIVolPan(firstSelectedTrack, i)
          local receiveLeveldB = 20 * math.log(receiveLevel, 10)
          local rangedVal = processDragValue(receiveLeveldB)
          
          reaper.SetTrackSendInfo_Value(firstSelectedTrack, -1, i, 'D_VOL', rangedVal)
          floatPanel:onReaperChange(self.parent, 'receive', i, rangedVal, props.maskedCol or {255,128,255,255}, props.chanIdx)
          break
        end
      end
    end
  end
  
  props.onDrag = function(dX, dY, self)
    local dragVal = dX - dY
    props.onValueChange(dragVal, self, true)
  end
  
  props.mouseWheel = function(self, wheel_amt)
    props.onValueChange(wheel_amt, self, false)
  end
  
  props.onDragOver = props.onDragOver or function(self) -- something else drags over me
    
    if self.parent.thisSendTrack then
      --msg('cableChunk drag over, send track')
      local existingSendsCount = reaper.GetTrackNumSends(dropSource.track, 0)
      dropTargetDeleteSend, dropTargetDeleteReceive = nil, nil
      for i = 0, existingSendsCount -1 do
        if reaper.GetTrackSendInfo_Value(dropSource.track, 0, i, 'P_DESTTRACK') == self.parent.thisSendTrack then
          dropTargetDeleteSend = i
          if self.parent.remove.img == nil then 
            self.parent.remove.img = 'remove'
            self.parent.remove.imgIdx = nil
          end
          break
        end
      end
    
    elseif self.parent.thisReceiveTrack then
      local existingReceivesCount = reaper.GetTrackNumSends(dropSource.track, -1)
      --msg('cableChunk drag over, receive track '..existingReceivesCount)
      dropTargetDeleteSend, dropTargetDeleteReceive = nil, nil
      for i = 0, existingReceivesCount -1 do
        if reaper.GetTrackSendInfo_Value(dropSource.track, -1, i, 'P_SRCTRACK') == self.parent.thisReceiveTrack then
          dropTargetDeleteReceive = i
          if self.parent.remove.img == nil then 
            self.parent.remove.img = 'remove'
            self.parent.remove.imgIdx = nil
          end
          break
        end
      end
      
    else --msg('cableChunk drag over, master send')
    end
    
  end

  props.onDragRelease = props.onDragRelease or function(self)
    --msg('cableChunk drag release') 
    if dropTargetDeleteSend~=nil or dropTargetDeleteReceive~=nil then
      reaper.Undo_BeginBlock()
      if dropTargetDeleteSend then reaper.RemoveTrackSend(dropSource.track, 0, dropTargetDeleteSend) end
      if dropTargetDeleteReceive then reaper.RemoveTrackSend(dropSource.track, -1, dropTargetDeleteReceive) end
      reaper.Undo_EndBlock('Remove track send',1)
    end
    doPopulate = true
  end
  return self:rect(props)
end

function Cable(props)
  
  local cableCol = props.cableCol or {129,137,137}
  local cellSize = 20*scaleMult -- because container is being defined by absolute screen Y positions, this needs to be as well
  local cableStyle = props.cableStyle or {prefix='mask_cable_'}
  local prefix = cableStyle.prefix
  local thisCableTile = cableStyle.tile or false
  
  local cy, ch, inverted = nil, nil, false
  if props.startY<props.endY then -- cable goes down
    cy = props.startY + 0
    ch = props.endY-props.startY + cellSize
  else -- cable goes up
    cy = props.endY
    ch = props.startY-props.endY + cellSize
    inverted = true
  end
  
  local containerRBorder = 8
  local container = El:rect{parent=props.parent, x=(props.x or 0)+(props.w*-1) - containerRBorder, screenY=cy, w=(props.x or 0) - containerRBorder, scaledH=ch,
    l={toEdge, canvas, 'right', 1}, r={toEdge, canvas, 'right', 1}, col = {0,0,0,0} or props.containerCol or {0, 255, 0, 50}, cableType=props.cableType or nil,
    thisSendTrack=props.thisSendTrack, thisReceiveTrack=props.thisReceiveTrack, chanIdx=props.chanIdx or 0, interactive=false, ignoreParentClippedHidden=true }
  
  if props.cableReverse~=true then -- normal sends
    if inverted ~= true then --line goes down
      El:cableChunk{parent = container, x=0, y=0, h=20, w=28, img=prefix..'corner_rd_grad', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=6, y=20, w=8, h=-20, b={toEdge, container, 'bottom', 1}, img=prefix..'v', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=0, y=-20, w=20, h=20, t={toEdge, container, 'bottom', 1}, img=prefix..'corner_ru', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, flow=true, x=0, y=6, h=8, w=-10, r={toEdge, container, 'right', 1}, img=prefix..'h', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, flow=true, x=0, y=-6, w=10, h=20, img=prefix..'h_arrow', maskedCol=cableCol, tile=thisCableTile }
    else --line goes up
      El:cableChunk{parent = container, x=0, y=0, h=20, w=20, img=prefix..'corner_rd', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=20, y=6, h=8, w=-10, r={toEdge, container, 'right', 1}, img=prefix..'h', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, flow=true, x=0, y=-6, w=10, h=20, img=prefix..'h_arrow', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=6, y=20, w=8, h=-20, b={toEdge, container, 'bottom', 1}, img=prefix..'v', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=0, y=0, w=28, h=20, t={toEdge, container, 'bottom', 1}, img=prefix..'corner_ru_grad', maskedCol=cableCol, tile=thisCableTile }
    end
  else -- receives
    if inverted ~= true then --line goes down
      El:cableChunk{parent = container, x=0, y=0, h=20, w=28, img=prefix..'corner_rd_grad', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=6, y=20, w=8, h=-20, b={toEdge, container, 'bottom', 1}, img=prefix..'v', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=0, y=-20, w=20, h=20, t={toEdge, container, 'bottom', 1}, img=prefix..'corner_ru', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, flow=true, x=0, y=6, h=8, w=-10, r={toEdge, container, 'right', 1}, img=prefix..'h', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, flow=true, x=0, y=-6, w=10, h=20, img=prefix..'h_bowl', maskedCol=cableCol, tile=thisCableTile }
    else --line goes up
      El:cableChunk{parent = container, x=0, y=0, h=20, w=20, img=prefix..'corner_rd', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=20, y=6, h=8, w=-10, r={toEdge, container, 'right', 1}, img=prefix..'h', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, flow=true, x=0, y=-6, w=10, h=20, img=prefix..'h_bowl', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=6, y=20, w=8, h=-20, b={toEdge, container, 'bottom', 1}, img=prefix..'v', maskedCol=cableCol, tile=thisCableTile }
      El:cableChunk{parent = container, x=0, y=0, w=30, h=20, t={toEdge, container, 'bottom', 1}, img=prefix..'corner_ru_grad', maskedCol=cableCol, tile=thisCableTile }
    end
  end
  
  container.remove = El:rect{parent=container, x=0, y=-10, t={toEdge, nil, 'parentBottom', 0.5}, w=20, h=20, img=nil, interactive=false}
  container.onDragOver = function(self)
    --msg('cable drag over')
  end
  
  return container
end

cableStyles = {
               {name='Normal', prefix='mask_cable_'}, 
               {name='Thin', prefix='thin_mask_cable_'}, 
               {name='Thick', prefix='thick_mask_cable_'}, 
               {name='Hollow', prefix='hollow_mask_cable_'},
               {name='Dotted', prefix='dotted_mask_cable_', tile=true},
               {name='Braided', prefix='braided_mask_cable_', tile=true}
               }
               

addToRecentSendTargets =function(track)
  --msg('adding a track to recentSendTargets')
  local popularSends = findPopularSends()
  for i, v in ipairs(popularSends) do
    if v.track == track then return nil end -- there's already a shortcut to this track in the popular list, its not helpful to also be in the recent list
  end
  
  if recentSendTargets == nil then recentSendTargets = {} end
  for i = #recentSendTargets, 1, -1 do
    if recentSendTargets[i]==track then table.remove(recentSendTargets, i) end -- remove an older entry of the same track if its already there
  end
  table.insert(recentSendTargets, track)
  while #recentSendTargets > maxRecentSendTargets.value do table.remove(recentSendTargets, 1) end --trim the oldest entry if the table size has exceeded maxRecentSendTargets
end

findPopularSends = function()
  local trackReceiveCounts = {}
  for i = 0, reaper.CountTracks(0) - 1 do -- iterate tracks counting the receives
    local track = reaper.GetTrack(0, i)
    local receiveCount = reaper.GetTrackNumSends(track, -1) -- -1 for receives
    if receiveCount > 0 then
      table.insert(trackReceiveCounts, {track = track, count = receiveCount})
    end
  end
  table.sort(trackReceiveCounts, function(a, b) return a.count > b.count end) -- sort by count field
  local trimmedTrackReceiveCounts = {}
  for i = 1, math.min(#trackReceiveCounts, maxPopularSends.value) do table.insert(trimmedTrackReceiveCounts, trackReceiveCounts[i]) end -- trim to maxPopularSends 
  return trimmedTrackReceiveCounts
end

findLongestTrackName = function(tableOfTracks)
  local longest = 0
  for i, track in ipairs(tableOfTracks) do
    local t=track; if type(track)=='table' then t=track.track end 
    local _, trackName = reaper.GetTrackName(t)
    local thisLength = gfx.measurestr(trackName or '')
    if thisLength > longest then longest = thisLength end
  end
  return longest
end


function El:socket(props)
  props = props or {}
  props.w, props.h = 20, 20
  props.iType = 3
  local imgSuffix = ''
  if props.mirrorImages==true then imgSuffix='_mirror' end
  props.img = (props.img or 'socket')..imgSuffix
  props.col = {0,0,0,0}

  if props.chan34==true then 
    props.img = 'socket_34'..imgSuffix
    props.w = 24
    if props.mirrorImages==true then props.x = props.x+4 end
  end
  
  props.onReaperChange = function(self)
    if self.track and reaper.IsTrackSelected(self.track)==true and props.img~='socket_selected'..imgSuffix then
      self.img = 'socket_selected'..imgSuffix
      self.imgIdx = getImage(scaleToDrawImg(self))
    end
  end
  
  props.onDrag = function(dX, dY, self)
 
    dropSource = self -- don't forget that dropSource is a temporary global
    dropTarget = nil 
    reaper.SetTrackSelected(props.track, true) -- ensure that the source track isn't unselected
    if linksPanel and showLinks~=0 then linksPanel:setOffStage(false) end -- show the links
    if floatPanel.offStage~=true then floatPanel:setOffStage(true) end -- socket ondrag should hide the float panel
    
    additionalSourceTracks = {} -- make a table of selected tracks that are NOT the source track, to receive simplified behaviour onDragRelease
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
      local track = reaper.GetSelectedTrack(0, i)
      if track ~= props.track then table.insert(additionalSourceTracks, track) end
    end
    
    for j,k in pairs(els) do
      local x, y, w, h = k.arrX or k.x or 0, k.arrY or k.y or 0, k.arrW or k.w or 0, k.arrH or k.h or 0
      if (k.onDragOver or k.onDragRelease) and k.interactive~=false
          and gfx.mouse_x > x and gfx.mouse_x < x+w 
          and gfx.mouse_y > y and gfx.mouse_y < y+h then
        k:onDragOver(k)
        dropTarget = k
        break
      else
        local targetImgSuffix=''
        if k.mirrorImages==true then targetImgSuffix='_mirror' end
        if k.img == 'socket_highlight'..targetImgSuffix or k.img == 'socket_remove'..targetImgSuffix then 
          k.img, k.imgIdx = 'socket'..targetImgSuffix, nil 
        end
        if k.img == 'socket_highlight_34'..targetImgSuffix then k.img, k.imgIdx = 'socket_34'..targetImgSuffix, nil end
        if k.img == 'remove' then k.img, k.imgIdx = nil, nil end-- a cable with a remove marker
        if k.onDragAway then k:onDragAway() end
      end
    end
    
  end
  
  props.onDragOver = function(self)
    local existingSendsCount = reaper.GetTrackNumSends(dropSource.track, 0)
    local uniqueSend = true
    dropTargetDelete = nil
    for i = 0, existingSendsCount -1 do
      if reaper.GetTrackSendInfo_Value(dropSource.track, 0, i, 'P_DESTTRACK') == self.track then
        dropTargetDelete = i
        self.img, self.imgIdx = 'socket_remove'..imgSuffix, nil
        uniqueSend = false
        break
      end
    end
    if uniqueSend == true and self.track ~= dropSource.track then
      self.img = 'socket_highlight'..imgSuffix
      if self.chan34==true then self.img = 'socket_highlight_34'..imgSuffix end
      self.imgIdx = nil
      if self.chan34~=true and props.annex==nil then addTimer(self,'annex',1) end -- start the countdown to make the annex
    end
  end
  
  local removeAnnex = function()
    if props.annex then props.annex:purge() end
    props.annex=nil
    doArrange = true
  end
  
  props.onDragAway = function(self)
    if Timers and Timers.annex then removeTimer(self,annex) end
    if props.annex then addTimer(self, 'removeAnnex', 1) end
  end
  
  props.onTimerComplete = {}
  props.onTimerComplete.annex = function()
    removeTimer(self, 'annex')
    props.annex = El:socket{parent=props, x=-4, y=16, ignoreParentClippedHidden=true, track=props.track, chan34=true, mirrorImages=props.mirrorImages} -- create the chan34 annex socket
    doArrange = true
  end
  
  props.onTimerComplete.removeAnnex = function()
    removeTimer(self, 'removeAnnex')
    removeAnnex()
  end
  
  props.onDragRelease = function(self)
    --msg('on drag release')
    
    popularSends=nil
    if linksPanel then linksPanel:setOffStage(true) end
    removeTimer(self,'annex')
    if props.annex then removeAnnex() end
    sendWasDeleted = nil -- don't go making additional sends if the primary interaction was to delete a track, that's yukky
    
    reaper.Undo_BeginBlock()
    if dropTargetDelete~=nil then
      reaper.RemoveTrackSend(dropSource.track, 0, dropTargetDelete)
      reaper.Undo_EndBlock('Remove track send',1)
      sendWasDeleted = true -- assuming that creating a new send means you want to see sends
    else
      local prevSndCnt = reaper.GetTrackNumSends(dropSource.track, 0)
      reaper.CreateTrackSend(dropSource.track, dropTarget.track)
      if self.chan34==true then reaper.SetTrackSendInfo_Value(dropSource.track, 0, prevSndCnt, 'I_DSTCHAN', 2) end-- make that send you just made be to channels 3/4
      reaper.Undo_EndBlock('Add track send',1)
      addToRecentSendTargets(dropTarget.track)
      msr.showSend = 1
    end
    

    if #additionalSourceTracks>0 and sendWasDeleted~=true then -- additional tracks have a simplified 'if there isn't a send, add one, but ask first' functionality

      local potentialNewSends = {}
      for i, additionalSourceTrack in ipairs(additionalSourceTracks) do
        local existingSendsCount = reaper.GetTrackNumSends(additionalSourceTrack, 0)-- Check if there's already a send from this additionalSourceTrack to dropTarget.track
        local alreadyHasSend = false
        for j = 0, existingSendsCount - 1 do
          if reaper.GetTrackSendInfo_Value(additionalSourceTrack, 0, j, 'P_DESTTRACK') == dropTarget.track then
            alreadyHasSend = true break end
        end
        if not alreadyHasSend and additionalSourceTrack ~= dropTarget.track then -- there is no existing send, add to potentialNewSends with a note of its track name
          local _, trackName = reaper.GetTrackName(additionalSourceTrack)
          table.insert(potentialNewSends, {track = additionalSourceTrack, name = trackName})
        end
      end
      
      if #potentialNewSends > 0 then -- These would be one or more additional new send sources to this target, ask the user
        local trackNames = {}
        for i, sendInfo in ipairs(potentialNewSends) do table.insert(trackNames, sendInfo.name) end
        local trackNamesString = table.concat(trackNames, '\n')
        local _, targetTrack = reaper.GetTrackName(dropTarget.track)
        local toChan34str = ''
        if self.chan34==true then toChan34str = ' channel 3/4' end
        
        local retval=reaper.ShowMessageBox('Also add sends to '..targetTrack..toChan34str..' from:\n\n'..trackNamesString, 'Multiple tracks are selected', 4)
        if retval == 6 then  -- 6 = Yes
          reaper.Undo_BeginBlock()
          for i, sendInfo in ipairs(potentialNewSends) do
            local prevSndCnt = reaper.GetTrackNumSends(sendInfo.track, 0)
            reaper.CreateTrackSend(sendInfo.track, dropTarget.track) 
            if self.chan34==true then reaper.SetTrackSendInfo_Value(sendInfo.track, 0, prevSndCnt, 'I_DSTCHAN', 2) end-- make that send you just made be to channels 3/4
          end
          reaper.SetOnlyTrackSelected(dropTarget.track)-- select the receiving track, to feedback that a number of receives have been added
          reaper.Undo_EndBlock('Add track send to additional selected tracks', 1)
        end
      end
      
    end
    additionalSourceTracks = nil -- finished with that
    doPopulate = true
  end
  
  props.onDragAbandon = function(self)
    popularSends=nil
    if linksPanel then 
      linksPanel:setOffStage(true)
    end
    
    removeTimer(self,'annex')
    if props.annex then removeAnnex() end
  end
  
  return self:button(props)
end


function El:linkSlot(props)
  
  local trackCol, textCol = {129,137,137}, {180,180,180}
  local trackCustomCol = getTrackCustomColor(props.track)
  if trackCustomCol then
    trackCol, textCol = trackCustomCol, trackCustomCol
  end
  local _, trackName = reaper.GetTrackName(props.track)
  props.text={style=3, align=6, str=trackName, col=textCol}
  local minLength = 40*scaleMult
  local titleLength = math.max((props.longestTrackName*scaleMult)+14, minLength)

  local container = El:rect{parent=props.parent, x=props.x, y=props.y, w=props.w, h=props.h, r={toEdge, props.parent, 'right', 1}, interactive=false}
  El:rect{parent=container, x=-34-titleLength, y=0, w=titleLength+26, h=props.h, l={toEdge, container, 'right', 1}, col={50,100,250,0}, img='link_bg', interactive=false} -- bg
  El:rect{parent=container, x=-32-titleLength, y=3, w=titleLength+16, h=26, l={toEdge, container, 'right', 1}, col={0,0,255,0}, maskedCol=trackCol, img='link_bg_mask', interactive=false} -- col mask
  container.title = El:rect{parent=container, x=(titleLength*-1) -28, y=0, w=titleLength, h=props.h, l={toEdge, container, 'right', 1}, text=props.text, interactive=false}
  container.socket = El:socket{parent=container, x=-20, y=6, l={toEdge, container, 'right', 1}, track=props.track, mirrorImages=true}
  
  return container
end


---------- POPULATE ----------

function populateTracks()
  
  --msg('populateTracks')
  trackContainer.children = nil
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local tcp_y = getTrackYPos(track)
    local tcp_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH") * pixelScale -- pixelScale converts OSX pseudo-measurements to actual pixels
    local thisYPadding = 2 * scaleMult
    if tcp_h > (29 * scaleMult) then thisYPadding = 3 * scaleMult end -- do the y-axis squeeze
    if tcp_h > (30 * scaleMult) then thisYPadding = 4 * scaleMult end
    
    local thisCol = {51,51,51}
    local trackCol = getTrackCustomColor(track) -- Get track custom color
    if trackCol then thisCol = compositeCols(thisCol, trackCol, (customColStrength.value*0.01)) end
    
    local strip = El:rect{
      parent=trackContainer, trackIdx=i, x=4, screenY=tcp_y + 1, w=-4, scaledH=tcp_h, col=thisCol,
      r={toEdge, canvas, 'right', 1}, scaledXInnerPadding=6, scaledYInnerPadding=thisYPadding
      }
    local div = El:rect{parent=strip, x=-6, y=-1, h=1, r={toEdge, trackContainer, 'right', 1}, t={toEdge, strip, 'bottom', 1}, interactive=false, col={0,0,0,75} }
    --populateStrip(strip, i)
  end
   
end


function populate(page)
  
  colEmptyAreaR, colEmptyAreaG, colEmptyAreaB = reaper.ColorFromNative(reaper.GetThemeColor('col_tracklistbg'))
  colEmptyArea = {colEmptyAreaR, colEmptyAreaG, colEmptyAreaB}
  if canvas then canvas:purge() end
  
  canvas = El:rect{parent = 'none',scaledW=gfx.w, scaledH=gfx.h, innerPadding = 0, col=colEmptyArea,
    onGfxResize = function()
      canvas.scaledW, canvas.scaledH = math.floor(gfx.w), math.floor(gfx.h)
      doArrange = true
      doDraw = true
    end
    }
    
  if page==nil then
  
    if trackContainer then trackContainer:purge() end
    trackContainer = El:rect{col=colEmptyArea, r={toEdge, canvas, 'right', 1}, b={toEdge, canvas, 'bottom', 1}, interactive = false,
      onReaperChange = function()
        --msg('trackContainer onReaperChange')
        for i = 0, reaper.CountTracks(0) - 1 do
          local track = reaper.GetTrack(0, i)
          if reaper.IsTrackSelected(track)==true then
            --msg('track '..(i+1)..' selected')
            firstSelectedTrack = track
            break
          end
        end
        
        if reaper.ValidatePtr(firstSelectedTrack, 'MediaTrack*')==true then -- count sends, receives and masterParent to know if one has been added or removed.
          displayedTrack = {}
          --if displayedTrack==nil then displayedTrack = {} end
          displayedTrack.sendsCount = reaper.GetTrackNumSends(firstSelectedTrack, 0)
          displayedTrack.receivesCount = reaper.GetTrackNumSends(firstSelectedTrack, -1)
          displayedTrack.masterParentSend = reaper.GetMediaTrackInfo_Value(firstSelectedTrack, "B_MAINSEND")
          if displayedTrack.sendsCount ~= displayedTrack.sendsCountOld or displayedTrack.receivesCount ~= displayedTrack.receivesCountOld or displayedTrack.masterParentSend ~= displayedTrack.masterParentSendOld then
            doPopulate = true
            displayedTrack.sendsCountOld = displayedTrack.sendsCount
            displayedTrack.receivesCountOld = displayedTrack.receivesCount
            displayedTrack.masterParentSendOld = displayedTrack.masterParentSend
          end
        end
        
        if firstSelectedTrack~=nil and (oldFirstSelectedTrack == nil or firstSelectedTrack ~= oldFirstSelectedTrack) then
          doPopulate = true
          oldFirstSelectedTrack = firstSelectedTrack
        end
      end,
      
      onDpiChange = function(self)
        doPopulateTracks = true
        doArrange = true
      end
      }
  
    populateTracks() 
    
    
    
    
    ---populate cables--- 
  
    if reaper.ValidatePtr(firstSelectedTrack, 'MediaTrack*')==true then
      
      routings = {} -- a table of all the routings (master/parent, sends, receives), so cables can be drawn in the correct order
      
      local firstSelectedTrack_y = getTrackYPos(firstSelectedTrack)
      local firstSelectedTrack_h = reaper.GetMediaTrackInfo_Value(firstSelectedTrack, "I_TCPH") * pixelScale -- pixelScale converts OSX pseudo-measurements to actual pixels
      local firstSelectedTrack_centerY = firstSelectedTrack_y + math.floor(0.5*firstSelectedTrack_h) - (10 * scaleMult)
      local _, firstSelectedTrack_name = reaper.GetTrackName(firstSelectedTrack)
      local sendsCount = displayedTrack.sendsCount
      local receivesCount = displayedTrack.receivesCount
      local xSpaceAbove, xSpaceBelow, xSpaceMasterParent, xSpaceReceivesAbove, xSpaceReceivesBelow, aboveBelowTogetherYOffs, xSpaceAllSends = 0, 0, 0, 0, 0, 0, 0
    
      local masterParentTrack_y = nil
      local masterParentTrack = reaper.GetParentTrack(firstSelectedTrack) or ((reaper.GetMasterTrackVisibility() & 1)~=0 and reaper.GetMasterTrack(0))
      if masterParentTrack and msr.showMaster==1 then
        if displayedTrack.masterParentSend>0 then
          _, masterParentsendName = reaper.GetTrackName(masterParentTrack)
          local masterParentTrack_y = getTrackYPos(masterParentTrack)
          local masterParentTrack_h = reaper.GetMediaTrackInfo_Value(masterParentTrack, "I_TCPH") * pixelScale
          local masterParentTrack_centerY = masterParentTrack_y + math.floor(0.5*masterParentTrack_h) - (10 * scaleMult)
          
          local thisCableCol = cableCols.master
          if cableUseCCol.master==1 then
            local masterParentTrackCol = getTrackCustomColor(masterParentTrack)
            if masterParentTrackCol then
              thisCableCol = masterParentTrackCol
            end
          end
          
          routings.masterParent = {sendName = masterParentsendName, centerY=masterParentTrack_centerY, thisCableCol=thisCableCol}
        end
      end
      
      if sendsCount>0 and msr.showSend==1 then
      
        routings.sends = {}
        for j = 0, sendsCount -1 do
          _, sendName = reaper.GetTrackSendName(firstSelectedTrack, j)
          local thisSendTrack = reaper.GetTrackSendInfo_Value(firstSelectedTrack, 0, j, 'P_DESTTRACK')
          if reaper.ValidatePtr(thisSendTrack, 'MediaTrack*')==true then
            local thisSendTrack_y = getTrackYPos(thisSendTrack)
            local thisSendTrack_h = reaper.GetMediaTrackInfo_Value(thisSendTrack, "I_TCPH") * pixelScale
            local thisSendTrack_centerY = thisSendTrack_y + math.floor(0.5*thisSendTrack_h) - (10 * scaleMult)
            local chanIdx = reaper.GetTrackSendInfo_Value(firstSelectedTrack, 0, j, 'I_DSTCHAN') & 0x3FF -- find if send destination is channel 3 or higher
  
            local thisCableCol = cableCols.send
            if chanIdx>=2 then thisCableCol = cableCols.send3plus end
            if (chanIdx<2 and cableUseCCol.send==1) or (chanIdx>=2 and cableUseCCol.send3plus==1) then
              local thisSendCol = getTrackCustomColor(thisSendTrack)
              if thisSendCol then
                thisCableCol = {thisSendCol[1], thisSendCol[2], thisSendCol[3], 255}
              end
            end
            
            local thisSendValues = {sendName=sendName, centerY=thisSendTrack_centerY, thisCableCol=thisCableCol, thisSendTrack=thisSendTrack, chanIdx=chanIdx}
            if thisSendTrack_y>firstSelectedTrack_y then
              if not routings.sends.below then routings.sends.below = {} end
              table.insert(routings.sends.below, thisSendValues)
            else
              if not routings.sends.above then routings.sends.above = {} end
              table.insert(routings.sends.above, thisSendValues)
            end
    
          end
        end
        
      end
      
      if receivesCount>0 and msr.showReceive==1 then
      
        routings.receives = {}
        for k = 0, receivesCount -1 do
          _, receiveName = reaper.GetTrackReceiveName(firstSelectedTrack, k)
          local thisReceiveTrack = reaper.GetTrackSendInfo_Value(firstSelectedTrack, -1, k, 'P_SRCTRACK') ---1 because category is <0 for receives, 0=sends, >0 for hardware outputs
          if reaper.ValidatePtr(thisReceiveTrack, 'MediaTrack*')==true then
            local thisReceiveTrack_y = getTrackYPos(thisReceiveTrack)
            local thisReceiveTrack_h = reaper.GetMediaTrackInfo_Value(thisReceiveTrack, "I_TCPH") * pixelScale
            local thisReceiveTrack_centerY = thisReceiveTrack_y + math.floor(0.5*thisReceiveTrack_h) - (10 * scaleMult)
            local chanIdx = reaper.GetTrackSendInfo_Value(firstSelectedTrack, -1, k, 'I_DSTCHAN') & 0x3FF -- find if send destination is channel 3 or higher
            
            local thisCableCol = cableCols.receive
            if chanIdx>=2 then thisCableCol = cableCols.receive3plus end
            if (chanIdx<2 and cableUseCCol.receive==1) or (chanIdx>=2 and cableUseCCol.receive3plus==1) then
              local thisReceiveCol = getTrackCustomColor(thisReceiveTrack)
              if thisReceiveCol then
                thisCableCol = {thisReceiveCol[1], thisReceiveCol[2], thisReceiveCol[3], 255}
              end
            end
            
            local thisReceiveValues = {receiveName=receiveName, centerY=thisReceiveTrack_centerY, thisCableCol=thisCableCol, thisReceiveTrack=thisReceiveTrack, chanIdx=chanIdx}
            if thisReceiveTrack_y>firstSelectedTrack_y then
              if not routings.receives.below then routings.receives.below = {} end
              table.insert(routings.receives.below, thisReceiveValues)
            else
              if not routings.receives.above then routings.receives.above = {} end
              table.insert(routings.receives.above, thisReceiveValues)
            end
          
          end
        end
      end
      
      --local xSpaceAbove, xSpaceBelow, xSpaceMasterParent, xSpaceReceivesAbove, aboveBelowTogetherYOffs, xSpaceAllSends = 0, 0, 0, 0, 0, 0
      
      if routings.sends and routings.sends.above then
        xSpaceAbove = #routings.sends.above * 10
        if routings.sends.below then aboveBelowTogetherYOffs=2 end
        for i = #routings.sends.above, 1, -1 do -- iterate 'above' sends backwards so nearest one gets drawn first
          local cableCol, cableStyle = routings.sends.above[i].thisCableCol, cableStyles[cableStyleAssign['send']] -- cableCol for 3+ already done, when routings.sends was built
          if routings.sends.above[i].chanIdx>=2 then cableStyle = cableStyles[cableStyleAssign['send3plus']] end -- cableStyle for 3+
          Cable{parent=trackContainer, w=30 + ((#routings.sends.above-i)*10),
            startY=firstSelectedTrack_centerY - aboveBelowTogetherYOffs, endY=routings.sends.above[i].centerY, 
            cableCol=cableCol, thisSendTrack=routings.sends.above[i].thisSendTrack, cableStyle=cableStyle, chanIdx=routings.sends.above[i].chanIdx }
        end
      end
      
      if routings.sends and routings.sends.below then
        xSpaceBelow = #routings.sends.below * 10
        if routings.sends.above then aboveBelowTogetherYOffs=2 else aboveBelowTogetherYOffs=0 end 
        for i,v in ipairs(routings.sends.below) do
          local cableCol, cableStyle = routings.sends.below[i].thisCableCol, cableStyles[cableStyleAssign['send']] -- cableCol for 3+ already done, when routings.sends was built
          if routings.sends.below[i].chanIdx>=2 then cableStyle = cableStyles[cableStyleAssign['send3plus']] end -- cableStyle for 3+
          Cable{parent=trackContainer, w=20 + (i*10), startY=firstSelectedTrack_centerY + aboveBelowTogetherYOffs, endY=v.centerY,
            cableCol=cableCol, thisSendTrack=routings.sends.below[i].thisSendTrack, cableStyle=cableStyle, chanIdx=routings.sends.below[i].chanIdx }
        end
      end
      
      xSpaceAllSends = math.max(xSpaceAbove, xSpaceBelow)
      if routings.masterParent then -- make the Master Parent cable
        Cable{parent=trackContainer, w=xSpaceAllSends + 30, startY=firstSelectedTrack_centerY, endY=routings.masterParent.centerY,  containerCol={255,255,0,50},
          cableCol=routings.masterParent.thisCableCol, cableType='master', cableStyle = cableStyles[cableStyleAssign['master']]} 
        xSpaceMasterParent = 10
      end 
      
      if routings.receives then 
        El:rect{parent = trackContainer, x=-1*(xSpaceAllSends + xSpaceMasterParent+40), l={toEdge, canvas, 'right', 1}, screenY=firstSelectedTrack_centerY, w=10, h=20, 
          img=cableStyles[cableStyleAssign['receive']].prefix..'h_arrow', maskedCol=cableCols.receive } -- one single arrow for the end of all the receives cables
        
        if routings.receives.above then 
          xSpaceReceivesAbove = #routings.receives.above * 10
          if routings.receives.below then aboveBelowTogetherYOffs=2 else aboveBelowTogetherYOffs=0 end
          for i = #routings.receives.above, 1, -1 do -- iterate 'above' sends backwards so nearest one gets drawn first
            local cableCol, cableStyle = routings.receives.above[i].thisCableCol, cableStyles[cableStyleAssign['receive']] -- cableCol for 3+ already done, when routings.sends was built
            if routings.receives.above[i].chanIdx>=2 then cableStyle = cableStyles[cableStyleAssign['receive3plus']] end -- cableStyle for 3+
            Cable{parent=trackContainer, x=(xSpaceAllSends + xSpaceMasterParent)*-1 -20, w= 20 + ((#routings.receives.above-i+1)*10),
              startY=firstSelectedTrack_centerY - aboveBelowTogetherYOffs, endY=routings.receives.above[i].centerY, 
              cableCol=cableCol, containerCol={100,255,255,50},
              cableReverse=true, cableStyle = cableStyle, thisReceiveTrack=routings.receives.above[i].thisReceiveTrack, chanIdx=routings.receives.above[i].chanIdx}
          end
        end
      
        if routings.receives.below then
          xSpaceReceivesBelow = #routings.receives.below * 10
          if routings.receives.above then aboveBelowTogetherYOffs=2 else aboveBelowTogetherYOffs=0 end
          for i,v in ipairs(routings.receives.below) do
            local cableCol, cableStyle = routings.receives.below[i].thisCableCol, cableStyles[cableStyleAssign['receive']] -- cableCol for 3+ already done, when routings.sends was built
            if routings.receives.below[i].chanIdx>=2 then cableStyle = cableStyles[cableStyleAssign['receive3plus']] end -- cableStyle for 3+
            Cable{parent=trackContainer, x=(xSpaceAllSends + xSpaceMasterParent)*-1 -20, w= 20 + (i*10), 
              startY=firstSelectedTrack_centerY + aboveBelowTogetherYOffs, endY=v.centerY,  cableCol=v.thisCableCol, 
              containerCol={255,0,0,50}, cableReverse=true, cableStyle = cableStyles[cableStyleAssign['receive']],
              thisReceiveTrack=routings.receives.below[i].thisReceiveTrack, chanIdx=routings.receives.below[i].chanIdx}
          end
        end
      
      end
      
      --linksPanel
      
      --msg('populating linksPanel')
      xSpaceAllReceives = math.max(xSpaceReceivesAbove or 0, xSpaceReceivesBelow or 0)
      if xSpaceAllReceives>0 then xSpaceAllReceives = xSpaceAllReceives+20 end -- if there are any receives, it will also be using space for the arrow
      local pitchH = 32
      local recentSendTargetsH, divH = 0, 0
      if recentSendTargets then recentSendTargetsH = #recentSendTargets * pitchH; divH = 8 end
      local popularSends = findPopularSends()
      local popularSendsH = #popularSends * pitchH 
      local linksPanelH = recentSendTargetsH + popularSendsH + divH
      
      linksPanel = El:rect{parent=canvas, x=0, screenY=firstSelectedTrack_y + math.floor(0.5*firstSelectedTrack_h) - (linksPanelH * 0.5 * scaleMult), 
        w=(xSpaceAllReceives + xSpaceAllSends + xSpaceMasterParent +30)*-1, r={toEdge, canvas, 'right', 1},
        h=linksPanelH, col=colEmptyArea, col={255,0,0,0}, interactive = false, offStage = true
        }
      
      gfx.setfont(3) -- gonna measure some strings, yeah?
      local longestPopularTrackName = findLongestTrackName(popularSends)/scaleMult
      local longestRecentTrackName = 0
      
      if recentSendTargets then
        longestRecentTrackName = findLongestTrackName(recentSendTargets)/scaleMult
        for i, track in ipairs(recentSendTargets) do
          El:linkSlot{parent=linksPanel, x=0, y=(i-1)*pitchH, w=0, h=pitchH, track=track, longestTrackName=longestRecentTrackName }
        end
      end
      
      if recentSendTargetsH>0 then
        local divW = math.max(longestPopularTrackName, longestRecentTrackName)
        El:rect{parent=linksPanel, x=-30-divW, y=recentSendTargetsH+3, w=divW+12, h=1, l={toEdge, linksPanel, 'right', 1}, col={255,255,255,50}, interactive=false} -- div
      end
      
      
      for i, v in ipairs(popularSends) do
        El:linkSlot{parent=linksPanel, x=0, y=recentSendTargetsH + divH + (i-1)*pitchH, w=0, h=pitchH, r={toEdge, linksPanel, 'right', 1}, track=v.track,
          longestTrackName=longestPopularTrackName}
      end

      
    end
    
    
    
    ---populate sockets---
  
    if reaper.GetMasterTrackVisibility() &1~=0 then
      local masterTrack = reaper.GetMasterTrack(0)
      local masterTrack_y = getTrackYPos(masterTrack)
      local masterTrack_h = reaper.GetMediaTrackInfo_Value(masterTrack, "I_TCPH") * pixelScale
      local masterTrack_centerY = masterTrack_y + math.floor(0.5*masterTrack_h)
      El:socket{parent=trackContainer, x=-20, screenY=masterTrack_centerY - (10*scaleMult), l={toEdge, canvas, 'right', 1}, track=masterTrack}
    end
    
    for i = 0, reaper.CountTracks(0) - 1 do
      local track = reaper.GetTrack(0, i)
      local track_y = getTrackYPos(track)
      local track_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH") * pixelScale
      local track_centerY = track_y + math.floor(0.5*track_h)
      El:socket{parent=trackContainer, x=-20, screenY=track_centerY - (10*scaleMult), l={toEdge, canvas, 'right', 1}, track=track}
    end
    
    
    
    
    
    ---floatPanel---
  
    floatPanel = El:circle{parent=canvas, x=-2, y=-12, w=24, h=24, col=colEmptyArea, interactive = false,
      onReaperChange = function(self, parentEl, cableType, SRidx, rangedVal, col, chanIdx)
        
        if type(rangedVal)=='number' then -- no need to fetch values, they're being provided
          self.lastSRidx, self.lastCableType = SRidx, cableType
          floatPanelSweepIndicator.col, floatPanelColMask.maskedCol = col, col
          floatPanel.parent, floatPanel.t = parentEl, {toEdge, parentEl, 'parentBottom', 0.5}
          floatPanelSweepIndicator.value.value = sendVol_to_value(rangedVal)
          floatPanelSweepIndicator:onReaperChange()
          floatPanelMute:onReaperChange()
          
          local chanSuffix = ''
          if chanIdx>=2 then chanSuffix = ' ('..(chanIdx+1)..'/'..(chanIdx+2)..')' end
          local thisSRName = ''
          local minLength = 60*scaleMult
          
          if cableType == 'master' then   
            local parentTrack = reaper.GetParentTrack(firstSelectedTrack) -- returns nil if the parent track is the master
            if parentTrack then _, thisSRName = reaper.GetTrackName(reaper.GetParentTrack(firstSelectedTrack)) -- parentTrack is a track, not the master
            else thisSRName = 'MASTER'
            end 
            floatPanelHeading.text.str = 'PARENT SEND to'
            minLength = 86*scaleMult
          elseif cableType == 'send' then 
            _, thisSRName = reaper.GetTrackSendName(firstSelectedTrack, self.lastSRidx)
            floatPanelHeading.text.str = 'SEND to'
          elseif cableType == 'receive' then
            _, thisSRName = reaper.GetTrackReceiveName(firstSelectedTrack, self.lastSRidx)
            floatPanelHeading.text.str = 'RECEIVE from'
            minLength = 86*scaleMult
          end

          gfx.setfont(2)
          floatPanelTrackName.text.str = (thisSRName or '')..chanSuffix
          
          local srNameLength = math.max((gfx.measurestr(floatPanelTrackName.text.str)*scaleMult)+14, minLength)
          floatPanelHeading.scaledX, floatPanelTrackValue.scaledX, floatPanelTrackName.scaledX = srNameLength*-1, srNameLength*-1, srNameLength*-1
          floatPanelMute.scaledX = srNameLength*-1
          floatPanelHeading.scaledW, floatPanelTrackValue.scaledW,  floatPanelTrackName.scaledW = srNameLength, srNameLength, srNameLength
          floatPanelBg.scaledX =  (srNameLength+6)*-1 
          floatPanelBg.scaledW = srNameLength+(33*scaleMult)
          floatPanelColMask.scaledX = (srNameLength+1)*-1 
          floatPanelColMask.scaledW = srNameLength+(24*scaleMult)

          floatPanelTrackValue.valueText.text.str = tonumber(string.format("%.2f",20 * math.log(rangedVal, 10)))
          floatPanel:scaleDimensions()
          floatPanelMute:getValue()
          doArrange = true
          
        else -- a track is selected, float panel is attached, possibly new onReaperChamge values from reaper need fetching
          if firstSelectedTrack and self.lastSRidx~=nil then
            local floatPaneldisplayVal
            if self.lastCableType == 'master' then _, floatPaneldisplayVal = reaper.GetTrackUIVolPan(firstSelectedTrack)
            elseif self.lastCableType=='send' then  _, floatPaneldisplayVal = reaper.GetTrackSendUIVolPan(firstSelectedTrack, self.lastSRidx)
            else  _, floatPaneldisplayVal = reaper.GetTrackReceiveUIVolPan(firstSelectedTrack, self.lastSRidx)
            end
            
            if lastFloatPaneldisplayVal==nil or lastFloatPaneldisplayVal~=floatPaneldisplayVal then
              --msg('floatPaneldisplayVal '..floatPaneldisplayVal..' is not '..(lastFloatPaneldisplayVal or 'none'))
              floatPanelSweepIndicator.value.value = sendVol_to_value(floatPaneldisplayVal)
              floatPanelSweepIndicator:onReaperChange()
              floatPanelTrackValue.valueText.text.str = tonumber(string.format("%.2f",20 * math.log(floatPaneldisplayVal, 10)))
              lastFloatPaneldisplayVal = floatPaneldisplayVal
            end
          end
        end
        
        
      end
    } 
    
    floatPanelBg = El:rect{parent=floatPanel, x=-28, y=-16, w=56, h=58, col=colEmptyArea, col={255,0,0,0}, interactive = false, img='float_bg', ignoreParentClippedHidden=true}
    floatPanelColMask = El:rect{parent=floatPanel, x=-23, y=-11, w=46, h=46, col=colEmptyArea, maskedCol={0,128,244}, col=nil, interactive = false, img='float_bg_mask', ignoreParentClippedHidden=true}
    floatPanelSweepIndicator = El:sweepIndicator{parent=floatPanel, x=3, y=3, w=18, h=18, startAngleOffs=20, endAngleOffs=20, maskImg='sweepIndicator_mask'}
    
    local darkBgCol, darkBgTextCol = {40,40,40,180}, {200,200,200,255}
    floatPanelMute = El:toggleValueButton{parent=floatPanel, x=-90, y=-10, w=14, h=14, img='mute', ignoreParentClippedHidden=true,
          getValue = function(self) 
            if not (floatPanel and floatPanel.lastSRidx and floatPanel.lastCableType) then return end
            local sendCategory = (floatPanel.lastCableType == 'receive') and -1 or 0
            return reaper.GetTrackSendInfo_Value(firstSelectedTrack, sendCategory, floatPanel.lastSRidx, 'B_MUTE')
          end,
          onToggle = function(self, currentValue)
            if not (floatPanel and floatPanel.lastSRidx and floatPanel.lastCableType) then return end
            local sendCategory = (floatPanel.lastCableType == 'receive') and -1 or 0
            reaper.SetTrackSendInfo_Value(firstSelectedTrack, sendCategory, floatPanel.lastSRidx, 'B_MUTE', 1-currentValue)
            self:onReaperChange()
          end
        }
    floatPanelHeading = El:rect({parent=floatPanel, x=-90, y=-10, w=93, h=14, interactive=false,
      text={style=1, align=6, str='SEND to', col=darkBgTextCol}, col=nil, ignoreParentClippedHidden=true })
    floatPanelTrackName = El:rect({parent=floatPanel, x=-90, y=4, w=93, h=16, interactive=false,
      text={style=2, align=6, str='', col={40,40,40,255}}, col={129,137,137,0}, ignoreParentClippedHidden=true })
    floatPanelTrackValue = El:readout({parent=floatPanel, x=-76, y=20, w=79, h=14, 
      text={style=1, align=6, str='', col=darkBgTextCol}, units={units='dB', style=1, col={200,200,200,188}}, col=nil, ignoreParentClippedHidden=true,
      doubleClick = function(self)
        if not (floatPanel and floatPanel.lastSRidx and floatPanel.lastCableType) then return end
        local currentVal
        if floatPanel.lastCableType == 'send' then  _, currentVal = reaper.GetTrackSendUIVolPan(firstSelectedTrack, floatPanel.lastSRidx)
        else  _, currentVal = reaper.GetTrackReceiveUIVolPan(firstSelectedTrack, floatPanel.lastSRidx)
        end
        local currentDB = 20 * math.log(currentVal, 10)
        
        local retval, user_input = reaper.GetUserInputs('Enter Value (dB)', 1, 'Value (-145dB to 12dB):', string.format("%.2f", currentDB))
        if retval then
          local newVal = tonumber(user_input)
          if newVal and newVal >= -145 and newVal <= 12 then
            local newLinear = 10^(newVal / 20)
            if floatPanel.lastCableType == 'send' then reaper.SetTrackSendUIVol(firstSelectedTrack, floatPanel.lastSRidx, newLinear, 0)
            else reaper.SetTrackSendInfo_Value(firstSelectedTrack, -1, floatPanel.lastSRidx, 'D_VOL', newLinear)
            end
            floatPanel:onReaperChange()
          else
            local retry = reaper.ShowMessageBox("Enter a value from -145dB to 12dB, retry?", 'Value out of range', 1)
            if retry == 1 then self:doubleClick() end
          end
        end
        
      end
      })

  
    -- end populate default page--

  else
  
  
  
  
    -- populate settings page
    
    settingsPage = El:rect{parent=canvas, x=0, y=50, w=0, h=0, r={toEdge, canvas, 'right', 1}, b={toEdge, canvas, 'bottom', 1}, innerPadding=10, col={colEmptyArea},  
      isScrollbarParentY=true, scrollY = 0}
    local textCol = {200,200,200}
    
    local function cableSettingsSection(props)
      local cellStyleNames = {}
      for i, style in ipairs(cableStyles) do table.insert(cellStyleNames, style.name) end -- table of names for the styles dropdown
      local container = El:rect{parent=props.parent, x=0, y=0, w=200, h=160, interactive=false, col={0,60,128,0}, flow=true, ignoreParentClippedHidden=true}
      
      El:rect{parent=container, x=0, y=0, w=200, h=30, text={style=3, align=5, str=props.title, col=textCol}, col={0,100,40,0}, interactive=false} -- title
      El:rect{parent=container, x=50, y=30, w=100, h=1, col={100,100,100}, interactive=false} -- div
      
      El:rect{parent=container, x=0, y=40, w=100, h=16, text={style=2, align=6, str='cable style : ', col=textCol}, col={0,255,0,0}, interactive=false}
      El:dropDown{parent=container, x=100, y=38, w=80, h=20, text={col=textCol}, 
        options=cellStyleNames, selectedIndex=cableStyleAssign[props.cableType],
        onChange=function(index, value, self)
          cableStyleAssign[props.cableType] = math.tointeger(index)
          self.selectedIndex = index
          doPopulate = true
        end
      }
      
      El:colChooser{parent=container, x=20, y=60, cableType=props.cableType, presets=props.colorPresets}
      
      El:rect{parent=container, x=0, y=120, w=160, h=20, text={style=2, align=6, str='use track custom color : ', col=textCol}, col={0,100,40,0}, interactive=false}
      El:button{parent=container, x=160, y=120, w=32, h=20, img='switch_off', 
        onReaperChange = function(self)
          if cableUseCCol[props.cableType] == 1 then self.img, self.imgIdx = 'switch_on', nil
          else self.img, self.imgIdx = 'switch_off', nil
          end
        end,
        onMouseDown = function(self)
          if cableUseCCol[props.cableType] ~= 1 and self.img == 'switch_off' then cableUseCCol[props.cableType] = 1
          elseif self.img == 'switch_on' then cableUseCCol[props.cableType] = 0
          end
          self:onReaperChange()
        end
      }
      return container
    end
    
    setsMaster = cableSettingsSection({parent=settingsPage, title='Master/Parent send ', cableType='master', colorPresets={{19,189,153}, {129,137,137}, {168,168,168}} })
    setsSends = cableSettingsSection({parent=settingsPage, title='Sends', cableType='send', colorPresets={{255,225,0}, {129,137,137}, {168,168,168}}, })
    setsReceives = cableSettingsSection({parent=settingsPage, title='Receives', cableType='receive', colorPresets={{0,162,255}, {129,137,137}, {168,168,168}}, })
    setsSends3plus = cableSettingsSection({parent=settingsPage, title='Sends (to channel 3+)', cableType='send3plus', colorPresets={{168,57,57}, {129,137,137}, {168,168,168}}, })
    setsReceives3plus = cableSettingsSection({parent=settingsPage, title='Receives (to channel 3+)', cableType='receive3plus', colorPresets={{168,57,57}, {129,137,137}, {168,168,168}}, })
    
    
    setColBG = El:rect{parent=settingsPage, x=0, y=0, w=200, h=166, interactive=false, col={0,60,128,0}, ignoreParentClippedHidden = true, flow=true}
  
    El:rect{parent=setColBG, x=0, y=6, w=160, h=20, text={style=2, align=6, str='Toolbar cable previews ', col=textCol}, col={0,100,40,0}, interactive=false}
    El:toggleValueButton{parent=setColBG, x=160, y=6, w=32, h=20, img='switch',
      getValue = function(self) return toolbarCablePreviews end,
      onToggle = function(self, currentValue)
        if currentValue==1 then toolbarCablePreviews=0 else toolbarCablePreviews=1 end
        doPopulate = true
      end
    }
    
    El:rect{parent=setColBG, x=0, y=6, flow=true, w=120, h=26, text={style=2, align=6, str='custom color track panel strength', col=textCol, wrap=true}, col={0,100,40,0}, interactive=false}
    colStrKnob, colStrReadout = El:sweepIndicatorKnob{parent=setColBG, x=4, y=0, circleSize=26, flow=true, value=customColStrength, valMin=0, valMax=100, decimals=0,
      colOutline={82,82,82}, colBG={38,38,38}, colSweep={181,181,181}, startAngleOffs=10, endAngleOffs=10, dragGearing=0.5, text={style=2, str=''},
      readout={x=4, y=2, w=46, h=22, units={units='%', style=2, col={120,120,120}}, flow=true, ignoreParentClippedHidden=true} }
      
    local ccPaletteCols = {{105,137,137},{129,137,137},{168,168,168},{19,189,153},{51,152,135},{184,143,63},{187,156,148},{134,94,82},{130,59,42}}
    local customColPalette = El:rect{parent=setColBG, x=4, y=4, flow=true, w=196, h=12, interactive=false,
      valueDependantOf = {colStrKnob, colStrReadout}, fetchProjectCols=true,
        onArrange = function(self)
          if self.fetchProjectCols==true then -- get up to nine project custom colours and use them instead of ccPaletteCols
            local thisProjectCols, seenColors = {}, {}
            
            for i = 0, reaper.CountTracks(0) - 1 do
              if #thisProjectCols >= 9 then break end -- only get the first nine unique colors
              local track = reaper.GetTrack(0, i)
              local rtnCol = reaper.GetTrackColor(track)
              if rtnCol~=0 and seenColors[rtnCol]==nil then 
                local trackCol = getTrackCustomColor(track) -- colour is unique, hit it with the luminance processing
                table.insert(thisProjectCols, {trackCol[1], trackCol[2], trackCol[3]})
                seenColors[rtnCol] = true -- this colour has now been seen
              end
            end
            
            if #thisProjectCols > 0 then
              for i = 1, #thisProjectCols do -- #thisProjectCols might be less than nine
                ccPaletteCols[i] = thisProjectCols[i] -- replace one of ccPaletteCols with this projectCol
              end
            end
            
            self.fetchProjectCols = nil
          end
        end,
      onValueChange = function(self)
        for i, child in ipairs(self.children) do child:onValueChange() end
      end
      }
    
    for i,v in ipairs(ccPaletteCols) do
      El:rect{parent=customColPalette, x=1, y=0, flow=true, w=20, h=12, col={255,0,0}, interactive=false, instance=i, needsOnValueChange=true,
        onArrange = function(self)
          if self.needsOnValueChange==true then  -- hack to get inital settings
            self:onValueChange() 
            self.needsOnValueChange = nil
          end
        end,
        onValueChange = function(self)
          self.col = compositeCols({51,51,51}, ccPaletteCols[i], (customColStrength.value*0.01)) 
        end
        }
    end
    
    El:rect{parent=setColBG, x=0, y=10, flow=true, w=120, h=26, text={style=2, align=6, str='lighten dark custom colors if below', col=textCol, wrap=true}, col={0,100,40,0}, interactive=false}
    colLumKnob, colLumReadout = El:sweepIndicatorKnob{parent=setColBG, x=4, y=0, circleSize=26, flow=true, value=minimumCustomColLum, valMin=0, valMax=100, decimals=0,
      colOutline={82,82,82}, colBG={38,38,38}, colSweep={181,181,181}, startAngleOffs=10, endAngleOffs=10, dragGearing=0.5, text={style=2, str=''},
      readout={x=4, y=2, w=46, h=22, units={units='%', style=2, col={120,120,120}}, flow=true, ignoreParentClippedHidden=true} }
    
    local lumPaletteCols = {{1,8,6},{5,51,41},{10,102,83},{15,153,124},{21,204,165},{25,255,206},{128,255,227},{204,255,244},{247,255,253}}
    local customColLumPalette = El:rect{parent=setColBG, x=4, y=4, flow=true, w=196, h=12, interactive=false,
      valueDependantOf = {colLumKnob, colLumReadout},
      onValueChange = function(self)
        for i, child in ipairs(self.children) do child:onValueChange() end
      end
      }
    
    for i,v in ipairs(lumPaletteCols) do
      El:rect{parent=customColLumPalette, x=1, y=0, flow=true, w=20, h=12, col={255,0,0}, interactive=false, instance=i, needsOnValueChange=true,
        onArrange = function(self)
          if self.needsOnValueChange==true then  -- hack to get inital settings
            self:onValueChange() 
            self.needsOnValueChange = nil
          end
        end,
        onValueChange = function(self)
          local r,g,b = lumPaletteCols[i][1], lumPaletteCols[i][2], lumPaletteCols[i][3]
          local currentLum = luminanceFromRGB(r,g,b) 
          local targetLum = minimumCustomColLum.value*2.55
          if currentLum < targetLum then r,g,b = luminanceToRGB(v[1],v[2],v[3], targetLum) end
          self.col = {r,g,b}
        end
        }
    end
    
    
    
    setsPatchSortcuts = El:rect{parent=settingsPage, x=0, y=0, w=200, h=124, interactive=false, col={0,60,128,0}, ignoreParentClippedHidden = true, flow=true}
    El:rect{parent=setsPatchSortcuts, x=0, y=0, w=200, h=30, text={style=3, align=5, str='Patch Shortcuts', col=textCol}, col={0,100,40,0}, interactive=false} -- title
    El:rect{parent=setsPatchSortcuts, x=50, y=30, w=100, h=1, col={100,100,100}, interactive=false} -- div
    
    El:rect{parent=setsPatchSortcuts, x=0, y=6, w=130, h=26, flow=true,
      text={style=2, align=6, str='number of recent destinations to show', col=textCol, wrap=true}, col={0,100,40,0}, interactive=false}
    El:sweepIndicatorKnob{parent=setsPatchSortcuts, x=4, y=0, circleSize=26, flow=true, value=maxRecentSendTargets, valMin=0, valMax=6, decimals=0,
      colOutline={82,82,82}, colBG={38,38,38}, colSweep={181,181,181}, startAngleOffs=10, endAngleOffs=10, dragGearing=0.1, text={style=2, str=''},
      readout={x=4, y=2, w=26, h=22, units={units='', style=2, col={120,120,120}}, flow=true, ignoreParentClippedHidden=true} }
    
    El:rect{parent=setsPatchSortcuts, x=0, y=6, w=130, h=26, flow=true,
      text={style=2, align=6, str='number of most used destinations to show', col=textCol, wrap=true}, col={0,100,40,0}, interactive=false}
    
    El:sweepIndicatorKnob{parent=setsPatchSortcuts, x=4, y=0, circleSize=26, flow=true, value=maxPopularSends, valMin=0, valMax=6, decimals=0,
      colOutline={82,82,82}, colBG={38,38,38}, colSweep={181,181,181}, startAngleOffs=10, endAngleOffs=10, dragGearing=0.1, text={style=2, str=''},
      readout={x=4, y=2, w=26, h=22, units={units='', style=2, col={120,120,120}}, flow=true, ignoreParentClippedHidden=true} }
    
    
    
    -- settings page scrollbar
    
    settingsPage.scrollbar = El:rect{parent=settingsPage, x=-24, y=-10, w=14, h=0, l={toEdge, settingsPage, 'right', 1}, b={toEdge, settingsPage, 'bottom', 1}, interactive = false,
      ignoreScrollY=true, iType=3, col={0,0,0,75}, offStage=true, 
      onArrange = function(self)
        local parentH, parentScrollableH = self.parent.arrH or self.parent.h, self.parent.scrollableH or 0
  
        if parentH<parentScrollableH then 
          if self.offStage==true then self:setOffStage(false); self:arrange() end
          self.scrollDiff = math.floor(parentH * (parentH / parentScrollableH))
          self.scrollRange = parentScrollableH - parentH
          self.scrollScale = self.scrollRange / ((self.arrH or self.h) - self.scrollDiff)
        else self:setOffStage(true)
        end
        
        self.parent.scrollableH = 0 -- reset that so that it recalculates next time
      end
      }
      
    settingsPage.scrollbar.bar = El:rect{parent=settingsPage.scrollbar, x=0, y=0, w=14, h=20, img='scrollbar_v', col={0,0,255,0}, iType=3,  offStage=true, 
      onArrange = function(self)
        self.arrH = nil
        self.h = self.parent.scrollDiff
      end,
      onDrag = function(dX, dY, self) self:onValueChange(dX - dY, true) end,
      mouseWheel = function(self, wheel_amt)
        if wheel_amt then self:onValueChange(wheel_amt, false) end
      end,
      
      onValueChange = function(self, dVal, isDrag)
        if dVal==0 and isDrag==true then  self.initDragVal = self.parent.parent.scrollY end -- reset the drag
        if isDrag~=true then 
          self.initDragVal = nil
          self.parent.parent.scrollY = math.Clamp(self.parent.parent.scrollY + (dVal*self.parent.scrollScale), -1*self.parent.scrollRange, 0)
        else self.parent.parent.scrollY = math.Clamp(self.initDragVal + (dVal*self.parent.scrollScale), -1*self.parent.scrollRange, 0)
        end
        self.arrY = (-1*self.parent.parent.scrollY / self.parent.scrollScale) + self.parent.arrY
      end
      }
    
  end
  
  
  
  
  
  
  -- populate toolbar
  
  toolbarBg = El:rect{parent=canvas, col=colEmptyArea, h=50, w=-28, r={toEdge, canvas, 'right', 1}, interactive = false} 
  
  settings = El:toggleValueButton{parent=toolbarBg, x=10, y=10, w=30, h=30, img='settings',
    getValue = function(self)
      if activePage=='settings' then return true end
    end,
    onToggle = function(self, currentValue)
      if currentValue and currentValue==true then activePage=nil else activePage='settings' end
      populate(activePage)
      doReaperGet = true
    end
  }


  dockButton = El:toggleValueButton{parent=toolbarBg, x=0, y=0, flow=true, w=30, h=30, img='toolbar_dock',
    getValue = function(self) return (gfx.dock(-1)&1) end,
    onToggle = function(self, currentValue)
      if currentValue==0 then gfx.dock(513) else gfx.dock(0) end
      doPopulate = true
    end
  }
  
  msrContainer = El:rect{parent=toolbarBg, x=4, y=0, flow=true, h=30, w=74, interactive=false }
  msrMaster = El:toggleValueButton{parent=msrContainer, x=0, y=0, w=74, h=30, img='msr_master',
    getValue = function(self) return msr.showMaster end,
    onToggle = function(self, currentValue)
      if currentValue==1 then msr.showMaster = 0 else msr.showMaster = 1 end
      doPopulate = true
    end
  }
  msrSend = El:toggleValueButton{parent=msrContainer, x=10, y=10, w=64, h=20, img='msr_send',
    getValue = function(self) return msr.showSend end,
    onToggle = function(self, currentValue)
      if currentValue==1 then msr.showSend = 0 else msr.showSend = 1 end
      doPopulate = true
    end
  }
  msrReceive = El:toggleValueButton{parent=msrContainer, x=20, y=20, w=54, h=10, img='msr_receive',
    getValue = function(self) return msr.showReceive end,
    onToggle = function(self, currentValue)
      if currentValue==1 then msr.showReceive = 0 else msr.showReceive = 1 end
      doPopulate = true
    end
  }
  
  if toolbarCablePreviews and toolbarCablePreviews==1 then
    msrSamplesContainer = El:rect{parent=toolbarBg, x=2, y=0, h=30, w=74, flow=true}
    El:cableChunk{parent = msrSamplesContainer, x=0, y=1, h=8, w=-2, interactive = false, r={toEdge, msrSamplesContainer, 'right', 1},
      img=cableStyles[cableStyleAssign['master']].prefix..'h', maskedCol=cableCols.master, tile=cableStyles[cableStyleAssign['master']].tile}
    El:cableChunk{parent = msrSamplesContainer, x=0, y=11, h=8, w=-2, interactive = false, r={toEdge, msrSamplesContainer, 'right', 1},
      img=cableStyles[cableStyleAssign['send']].prefix..'h', maskedCol=cableCols.send, tile=cableStyles[cableStyleAssign['send']].tile}
    El:cableChunk{parent = msrSamplesContainer, x=0, y=21, h=8, w=-2, interactive = false, r={toEdge, msrSamplesContainer, 'right', 1},
      img=cableStyles[cableStyleAssign['receive']].prefix..'h', maskedCol=cableCols.receive, tile=cableStyles[cableStyleAssign['receive']].tile}
  end
  
  closeBtnBg = El:rect{parent=canvas, col=colEmptyArea, x=-28, h=50, w=28, l={toEdge, canvas, 'right', 1}, interactive = false} 
  closeButton = El:button{parent=closeBtnBg, x=0, y=10, w=18, h=18, img='close',
    onMouseDown = function(self) Quit() end
  }
  
  linksButton = El:toggleValueButton{parent=toolbarBg, x=2, y=0, flow=true, w=30, h=30, img='links',
    getValue = function(self) return showLinks end,
    onToggle = function(self, currentValue)
      if currentValue==0 then showLinks=1 else showLinks=0 end
      doPopulate = true
    end
  }
  
  doArrange = true

end -- end populate page

  
--------- RUNLOOP ----------

function addTimer(self,index,time) 
  if Timers == nil then Timers = {} end
  if Timers[index] == nil then
    if self.Timers == nil then self.Timers = {} end
    self.Timers[index] = nowTime + time
    Timers[index] = self 
    return true
  end
end

function removeTimer(self,index)
  if self.Timers and self.Timers[index] and Timers[index] then
    self.Timers[index], Timers[index] = nil, nil
  end
end

function runloop()

  --[[if gfx.mouse_wheel~=0 then
    msg(gfx.mouse_wheel..'  ')
  end]]
  c=gfx.getchar()
  
  -- mouse stuff
  isCap = gfx.mouse_cap&1
  if gfx.mouse_cap&2>0 then isCap = 2 end
  
  if gfx.mouse_x ~= mouseXold or gfx.mouse_y ~= mouseYold or (firstClick ~= nil and last_click_time ~= nil and last_click_time+.25 < nowTime) then
    firstClick = nil
  end
  
  if gfx.mouse_x ~= mouseXold or gfx.mouse_y ~= mouseYold or isCap ~= mouseCapOld or gfx.mouse_wheel ~= 0 then
  
    isMouseMoving = true
    local wheel_amt = 0
    if gfx.mouse_wheel ~= 0 then
      mouseWheelAccum = mouseWheelAccum + gfx.mouse_wheel
      gfx.mouse_wheel = 0
      wheel_amt = math.floor(mouseWheelAccum / 120 + 0.5)
      if wheel_amt ~= 0 then mouseWheelAccum = 0 end
    end
    
    local hit = nil
    
    if els ~= nil then
      for j,k in pairs(els) do
        local scrollY = 0
        if k.scrollParentY then scrollY = k.scrollParentY.scrollY end
        local x, y, w, h = k.arrX or k.x or 0, (k.arrY or k.y or 0) + scrollY, k.arrW or k.w or 0, k.arrH or k.h or 0
        if k.interactive ~= false and k.offStage ~= true
            and gfx.mouse_x > x and gfx.mouse_x < x+w 
            and gfx.mouse_y > y and gfx.mouse_y < y+h then
          hit = k
        end
      end
    end
    
    if isCap == 0 or mouseCapOld == 0 then
      if activeMouseElement ~= nil and activeMouseElement ~= hit then
        activeMouseElement:mouseAway()
        singleClick = nil
        toolTipTimer = nil
      end
      activeMouseElement = hit
    end
    
    if isCap == 0 and mouseCapOld == 1 then -- mouse-up, reset stuff
      dragStart, singleClick = nil, nil
      if activeMouseElement then activeMouseElement:mouseUp() end
      if dropTarget then
        if dropTarget.onDragRelease then
          dropTarget.onDragRelease(dropTarget)
        end
        --msg('release drag')
        dropSource, dropTarget = nil, nil
      end
    if dropSource and dropSource.onDragAbandon then
      dropSource:onDragAbandon()
      --msg('abandon drag')
    end
    end
    
    if activeMouseElement ~= nil then 
      if isCap == 0 or mouseCapOld == 0 then
        activeMouseElement:mouseOver()
        activeMouseElement:showTooltip()
      end
      if wheel_amt ~= 0 then       
        activeMouseElement:mouseWheel(wheel_amt)
      end
       
      if isCap == 1 then -- mouse down
        activeMouseElement:mouseDown()
         
         local x,y = gfx.mouse_x,gfx.mouse_y
         if firstClick == nil or last_click_time == nil then 
           firstClick = {gfx.mouse_x,gfx.mouse_y}
           last_click_time = nowTime
         else if nowTime < last_click_time+.25 and math.abs((x-firstClick[1])*(x-firstClick[1]) + (y- firstClick[2])*(y- firstClick[2])) < 4 
          and activeMouseElement and activeMouseElement.doubleClick then 
           activeMouseElement:doubleClick() 
           firstClick = nil
           else
             firstClick = nil
           end 
         end
         
      end
      
      if isCap == 2 and activeMouseElement.onMouseDownRight then
        activeMouseElement:onMouseDownRight()
      end
      
    end
    
    mouseXold, mouseYold, mouseCapOld = gfx.mouse_x, gfx.mouse_y, isCap
  end
  
  -- changes from Reaper, also on init
  chgidx = reaper.GetProjectStateChangeCount(0)
  if chgidx ~= lastchgidx or doReaperGet == true then
    local masterVisible =  reaper.GetMasterTrackVisibility()&1
    local trackCount = reaper.CountTracks(0) 
    if trackCountOld==nil or trackCount ~= trackCountOld or masterVisibleOld==nil or masterVisible~=masterVisibleOld then
      --msg('start again')
      doPopulate = true -- if trackCount has reduced, els will be a mess, detect and start again
      trackCountOld, masterVisibleOld = trackCount, masterVisible
    else -- track count unchanged, safely tell the els to onReaperChange()
      --msg('track count unchanged')
      for j,k in pairs(els) do if k.onReaperChange then k:onReaperChange(k) end end
    end
    
    doArrange = true
    lastchgidx = chgidx
    doReaperGet = false
  end

  
  
  -- changes every FPS
  nowTime = reaper.time_precise()
  if (nextTime == nil or nowTime > nextTime) then -- do onFrame updates
    for i,k in pairs(needing_fps) do k:onFps() end
    nextTime = nowTime + (1/fps)
  end
  
  -- changes because a Timer is running
  if Timers then
    for j,k in pairs(Timers) do --iterate Timers
      if nowTime > k.Timers[j] then -- Timer has expired
        if k.onTimerComplete[j] then 
          --msg('timer '..j..' completes')
          k.onTimerComplete[j]() 
        end
        removeTimer(k,j)
      end
    end
  end
  
  -- change in window size
  if gfxWold ~= gfx.w or gfxHold ~= gfx.h then
    for j,k in pairs(els) do
      if k.onGfxResize then k.onGfxResize(k) end
    end
    doArrange = true
    --doPopulate = true
    gfxWold, gfxHold = gfx.w, gfx.h
  end
  
  
  if isMouseMoving and isMouseMoving == true and gfx.mouse_cap then -- only check these things if mouse is active
    
    -- changes in track height
    for i = 0, reaper.CountTracks(0) - 1 do
      local track = reaper.GetTrack(0, i)
      local tcp_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH") * pixelScale -- pixelScale converts OSX pseudo-measurements to actual pixels
      if trackContainer and trackContainer.children and trackContainer.children[i+1] then
        if tcp_h ~= trackContainer.children[i+1].scaledH then
          --msg('track '..i..', '..tcp_h..' is not '..trackContainer.children[i+1].scaledH)
          heightChanged = true
          break
        end
      end
    end
    
    -- changes in scroll (check TCPSCREENY of first visible track)
    for i = 0, reaper.CountTracks(0) -1 do
      local track = reaper.GetTrack(0, i)
      local firstVisibleTrack = nil
      if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")>0 then 
        local scrollwatchY = reaper.GetMediaTrackInfo_Value(track, "I_TCPSCREENY")
        if scrollwatchYOld==nil or scrollwatchYOld~=scrollwatchY then
          heightChanged = true
          scrollwatchYOld = scrollwatchY
        end
        break
      end
    end
    
    if heightChanged == true then
      --msg('h changed')
      doPopulate = true --may cause grief
      heightChanged = nil
    end
    
    -- change in window position
    screentoclientX, screentoclientY = gfx.screentoclient(0,0)
    if screentoclientXOld==nil or screentoclientXOld~=screentoclientX or screentoclientYOld==nil or screentoclientYOld~=screentoclientY then
      --window has moved
      doPopulate = true
      screentoclientXOld, screentoclientYOld = screentoclientX, screentoclientY
    end
    
    -- change in screen DPI
    if gfx.ext_retina ~= ext_retinaOld or ext_retinaOld == nil then
      local nScale = 1
      if gfx.ext_retina > 1.33 then nScale = 1.5 end
      if gfx.ext_retina > 1.66 then nScale = 2 end
      setScale(nScale)
      if ext_retinaOld ~= nil then -- DPI has changed 
        --doScaleDimensions = true
        doPopulate = true -- certainty is more fun
      end
      ext_retinaOld = gfx.ext_retina
      
    end
    
    isMouseMoving = false
  
  end
  
  
  if doScaleDimensions == true then
    for i, el in ipairs(els) do
      if el.img then el.imgIdx = nil end -- causes El:primative draw to do scaleToDrawImg() and getImage()
      el:scaleDimensions()
    end
    doScaleDimensions = nil
  end
  
  if doPopulate == true then
    populate(activePage or nil)
    --msg('populate')
    doPopulate = nil
    doReaperGet = true
  end
  
  if doPopulateTracks == true then
    populateTracks()
    doPopulateTracks = nil
  end
  
    
    
  if doArrange == true then
    for i, el in ipairs(els) do
      if el.arrange then
        if el.flow==true and el.parent and el.parent.children and el.flowEl==nil then
          for k, child in ipairs(el.parent.children) do -- increment parent's children looking for yourself
            if child == el and k>1 then el.flowEl = el.parent.children[k-1] end --assign previous child as flowEl
          end
        end
        el:arrange() 
      end 
    end
    doArrange = false
  end
  
  gfx.dest=-1
  if doDraw == true then
    --msg('doDraw')
    for i, el in ipairs(els) do
      if el.draw and (el.globalDraw==nil or el.globalDraw~=false) then el:draw() end --glbalDraw false elements have special draw behaviour elsewhere
    end
    doDraw = false 
  end

  if c>48 and c<59 then
    debugDraw = math.floor(c + 451)
    --msg(c)
  end
  if debugDraw ~= nil then 
    gfx.a, gfx.dest = 1, -1
    local iw, ih = gfx.getimgdim(debugDraw)
    gfx.muladdrect(0,0,iw, ih,0,0,0,0) 
    gfx.blit(debugDraw,1,0, 0, 0, iw, ih, 0, 40, iw*2, ih*2)
    text('BUFFER '..debugDraw..' w:'..iw..' h:'..ih,0,0,200,20,0,{255,255,255},3)
  end
  --msg('runloop')
  if c >= 0 then reaper.runloop(runloop) end
end

----------------------------

fps=10
needing_fps = { }
lastchgidx = 0
mouseWheelAccum = 0
doScaleDimensions = true
doArrange = true

runloop()


function Quit()
  d,x,y,w,h=gfx.dock(-1,0,0,0,0)
  reaper.SetExtState(sTitle,"wndw",w,true)
  reaper.SetExtState(sTitle,"wndh",h,true)
  reaper.SetExtState(sTitle,"dock",d,true)
  reaper.SetExtState(sTitle,"wndx",x,true)
  reaper.SetExtState(sTitle,"wndy",y,true)
  reaper.SetExtState(sTitle,'customColStrength', customColStrength.value, true)
  reaper.SetExtState(sTitle,'minimumCustomColLum', minimumCustomColLum.value, true)
  reaper.SetExtState(sTitle,'toolbarCablePreviews', toolbarCablePreviews, true)
  reaper.SetExtState(sTitle,'maxRecentSendTargets', maxRecentSendTargets.value, true)
  reaper.SetExtState(sTitle,'maxPopularSends', maxPopularSends.value, true)
  reaper.SetExtState(sTitle,'cableStyleAssignMaster', cableStyleAssign.master, true)
  reaper.SetExtState(sTitle,'cableStyleAssignSend', cableStyleAssign.send, true)
  reaper.SetExtState(sTitle,'cableStyleAssignSend3plus', cableStyleAssign.send3plus, true)
  reaper.SetExtState(sTitle,'cableStyleAssignReceive', cableStyleAssign.receive, true)
  reaper.SetExtState(sTitle,'cableStyleAssignReceive3plus', cableStyleAssign.receive3plus, true)
  reaper.SetExtState(sTitle,'cableColMaster', reaper.ColorToNative(cableCols.master[1], cableCols.master[2], cableCols.master[3]), true)
  reaper.SetExtState(sTitle,'cableColSend', reaper.ColorToNative(cableCols.send[1], cableCols.send[2], cableCols.send[3]), true)
  reaper.SetExtState(sTitle,'cableColSend3plus', reaper.ColorToNative(cableCols.send3plus[1], cableCols.send3plus[2], cableCols.send3plus[3]), true)
  reaper.SetExtState(sTitle,'cableColReceive', reaper.ColorToNative(cableCols.receive[1], cableCols.receive[2], cableCols.receive[3]), true)
  reaper.SetExtState(sTitle,'cableColReceive3plus', reaper.ColorToNative(cableCols.receive3plus[1], cableCols.receive3plus[2], cableCols.receive3plus[3]), true)
  reaper.SetExtState(sTitle,"cableUseCColMaster",cableUseCCol.master,true)
  reaper.SetExtState(sTitle,"cableUseCColSend",cableUseCCol.send,true)
  reaper.SetExtState(sTitle,"cableUseCColSend3plus",cableUseCCol.send3plus,true)
  reaper.SetExtState(sTitle,"cableUseCColReceive",cableUseCCol.receive,true)
  reaper.SetExtState(sTitle,"cableUseCColReceive3plus",cableUseCCol.receive3plus,true)
  reaper.SetExtState(sTitle,"msrShowMaster",msr.showMaster,true)
  reaper.SetExtState(sTitle,"msrShowSend",msr.showSend,true)
  reaper.SetExtState(sTitle,"msrShowReceive",msr.showReceive,true)
  reaper.SetExtState(sTitle,"showLinks",showLinks,true) 
  --msg('......quitting')
  gfx.quit()
end
reaper.atexit(Quit)
