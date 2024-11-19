  local SCRIPT = 'LBX_SK2_CM_CREATOR'
  local SCRIPT_NAME = 'SK2 Controller Map Creator'
  
  local gui_size = {w = 300, h = 100}
  local mouse = {}
  
  local resize_display = true
  local update_gfx = true
  
  local lastitem = -1
  local lasttaketype
  local lastwinfocus
  
  local montext = ''
  
  local nextcheck = -1
  local lvar = {ft = 0}
  local paths = {}
  
  lvar.rcz = false
  
  lvar.showlabels = true
  
  local contexts = {create_shape = 1,
                    crop = 2,
                    add_fader = 3,
                    add_encoder = 4,
                    add_button = 5,
                    move_delay = 6,
                    move_delay2 = 7,
                    }
                    
  lvar.version = '1.0'
  lvar.shapes = {'Rectangle','Circle'}
  lvar.adjust = {1,2,4,8,16}
  lvar.adjustamt = 1
  
  lvar.mwdiv = 120
  
  lvar.btype = 0 --0 = rect, 1 = circ
  
  lvar.blblcol = '205 205 205'
  lvar.sortoffs = 0
  
  lvar.buttdata = {}
  lvar.buttsel = {}
  lvar.buttsel_idx = {}
  lvar.zoomfactor = 1
  lvar.imagescale = 1
  lvar.imagescale2 = 1
  lvar.zoombox = 40
  
  lvar.lrncol = {}
  lvar.lrncol['PITCH'] = {fg = '0 0 0', bg = '0 190 0'}
  lvar.lrncol['CC'] = {fg = '0 0 0', bg = '200 200 0'}
  lvar.lrncol['NOTE'] = {fg = '0 0 0', bg = '190 128 255'}
  
  lvar.def_fader = {w = 120, h = 400}
  lvar.def_encoder = {r = 80}
  lvar.def_button = {r = 30}
  
  lvar.ctlzoom_f = 1
  lvar.ctlzoom_e = 1
  lvar.ctlzoom_b = 1
  
  local WM_MBUTTONDOWN = 0x207
  local MK_CONTROL = 0x8
  local MK_LBUTTON = 0x1
  local MK_MBUTTON = 0x10
  local MK_RBUTTON = 0x2
  local MK_SHIFT = 0x4
  local MK_XBUTTON1 = 0x20
  local MK_XBUTTON2 = 0x40
  
  local pages = {}
  local ctlpage = {}
  
  local datatab = {}
  datatab[1] = {'PITCH','NOTE','CC','N/A'}
  datatab[2] = {'-','NOTE','CC'}
  datatab[3] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}
  datatab[4] = {0,6,7,2,3,4}
  
  datatab[5] = {'-','A','B','C','D','E','F','G','H'}
  datatab[6] = {'-','PITCH','NOTE','CC','SPEC1','XCTLLED','DUMMY','SPEC2'}
  datatab[7] = {'-',0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40}
  datatab[8] = {'None', 'XTouch XCTL', 'XTouch Extender CTRLREL', 'Mackie Universal', 'Mackie Extender'}
  datatab[9] = {'-',1,2}
  datatab[10] = {'-',1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
  datatab[11] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
  datatab[12] = {'None', 'XTouch XCTL'}
  datatab[13] = {1,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1}
  datatab[14] = {0,-1,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
  
  local datatab_desc = {}
  datatab_desc[4] = {'Absolute','Relative 1 (Other)','Relative 1 (Reaper)','Relative 2 (Reaper)','Relative 3 (Reaper)','Toggle Button'}
  datatab_desc[5] = {'-','1','2','3','4','5','6','7','8'}
  datatab_desc[6] = {'-','PITCH','NOTE','CC','XT ENC RING','XCTL LED','DUMMY','XT ENC RING 2'}
  datatab_desc[9] = {'None','1 - XTouch Extender CTRLREL','2 - XTouch XCTL'}
  datatab_desc[13] = {'0%','10%','20%','30%','40%','50%','60%','70%','80%','90%'}
  datatab_desc[14] = {'Off','All','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16'}
  --datatab_desc[7] = {''}
  
  local dispchar = {"'0'","'1'","'2'","'3'","'4'","'5'","'6'","'7'","'8'","'9'","' '","'-'","'d'","'f'","'G'","'L'","'P'"}
  local dispchar2 = {"0","1","2","3","4","5","6","7","8","9","X","-","d","f","G","L","P"}
  
  local conv_mode = {}
  conv_mode[0] = 1
  conv_mode[6] = 2
  conv_mode[2] = 3
  conv_mode[3] = 4
  conv_mode[4] = 5
    
  local gmem_reset = 0
  local gmem_cnt = 1
  local gmem_data = 2
  
  local gmem_handshake_len = 2009999
  local gmem_handshake = 2010000
  
  lvar.midilearn_track = nil
  lvar.midilearn_trname = 'LBX_CM_LRN'
  
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end
  
  function string:split(sep)
     local sep, fields = sep or ":", {}
     local pattern = string.format("([^%s]+)", sep)
     self:gsub(pattern, function(c) fields[#fields+1] = c end)
     return fields
  end
  
  function ValTCString(val)
    if tonumber(val) then
      return tonumber(math.floor(val))
    end
  end
  
  function Val0To127(val)
    
    if tonumber(val) and tonumber(val) >= 0 and tonumber(val) <= 127 then
      return tonumber(math.floor(val))
    end
  
  end

  function ValTType(val, idx)

    if val > 1 then --Note or CC
      if not lvar.buttdata[idx]['t_off'] then
        lvar.buttdata[idx]['t_off'] = 0
      end
      if not lvar.buttdata[idx]['t_on'] then
        lvar.buttdata[idx]['t_on'] = 127
      end
      return val
    else
      lvar.buttdata[idx]['t_num'] = nil
      lvar.buttdata[idx]['t_chan'] = nil
      lvar.buttdata[idx]['t_on'] = nil
      lvar.buttdata[idx]['t_off'] = nil
      return 0
    end
    
  end

  function ValFBType(val, idx)
  
    if val > 1 and val ~= 7 then --Note or CC or SPEC1 or xctlled
      if val == 2 or val == 3 or val == 4 or val == 8 then
        lvar.buttdata[idx]['fb_cca'] = nil
        lvar.buttdata[idx]['fb_ccb'] = nil
      elseif val == 5 or val == 6 then
        lvar.buttdata[idx]['fb_num'] = 0
      end
      return val
    elseif val == 7 then
      lvar.buttdata[idx]['fb_num'] = 0
      lvar.buttdata[idx]['fb_chan'] = 0
      lvar.buttdata[idx]['fb_cca'] = nil
      lvar.buttdata[idx]['fb_ccb'] = nil
      return val
    else
      lvar.buttdata[idx]['fb_num'] = nil
      lvar.buttdata[idx]['fb_chan'] = nil
      lvar.buttdata[idx]['fb_cca'] = nil
      lvar.buttdata[idx]['fb_ccb'] = nil
      return 0
    end
    
  end
  
  function ValSSSysX(str)
    t = str:split(' ')
    for i = 1, #t do
      local num = tonumber(t[i])
      if (num and num >= 0 and num <= 255) or string.match(t[i], '%<C%d+%>') or t[i] == '<COLOR>' then
        --ok
      else
        str = nil
        break
      end
    end
    return str
  end

  function ValButOnVal(str)
    if not str then str = '' end
    local val = math.floor(tonumber(str))
    if val then
      val = F_limit(val,1,127)
    else
      val = 127
    end
    return val
  end
  
  function ValSysX(str)
    t = str:split(' ')
    for i = 1, #t do
      local num = tonumber(t[i])
      if (num and num >= 0 and num <= 255) then
        --ok
      else
        str = nil
        break
      end
    end
    return str
  end

  function ValButtGroup(val)
    if val ~= 1 then
      return val
    end
  end
  
  function FormatTitCropL()
    if lvar.buttdata[lvar.buttsel[1]].shape == 0 then
      return 'Crop Left'
    else
      return 'Crop Centre X'
    end
  end

  function FormatTitCropT()
    if lvar.buttdata[lvar.buttsel[1]].shape == 0 then
      return 'Top'
    else
      return 'Centre Y'
    end
  end

  function FormatTitCropR()
    if lvar.buttdata[lvar.buttsel[1]].shape == 0 then
      return 'Crop Right'
    else
      return 'Crop Radius'
    end
  end

  function CropRectActive()
    if lvar.buttdata[lvar.buttsel[1]].shape == 0 then
      return true
    end  
  end
  
  function TouchActive(idx)
  
    if lvar.buttdata[idx]['t_type'] then
      return true
    end
    
  end

  function MidiActive2(idx)
  
    local mt = lvar.buttdata[idx]['miditype']
    if mt and mt ~= 'PITCH' and mt ~= 'N/A' then
      return true
    end
    
  end

  function MidiActive3(idx)
  
    local mt = lvar.buttdata[idx]['miditype']
    if mt and mt ~= 'N/A' then
      return true
    end
    
  end

  function TCDigitActive(idx)
    if idx <= (lvar.buttdata['tc_digits'] or -1) then
      return true
    end
  end

  function TCDigitActive2(idx)
    if tonumber(lvar.buttdata['tc_digits']) then
      return true
    end
  end
  
  function TouchActive2(idx)
  
    local tt = lvar.buttdata[idx]['t_type']
    if tt then
      return true
    end
    
  end

  function FBActive(idx)
    if lvar.buttdata[idx]['fb_type'] and lvar.buttdata[idx]['fb_type'] ~= 'DUMMY' then
      return true
    end
    
  end

  function FBActive2(idx)
  
    local fbt = lvar.buttdata[idx]['fb_type']
    if fbt == 'SPEC1' or fbt == 'XCTLLED' then
      return true
    end
    
  end

  function FBActive3(idx)
  
    local fbt = lvar.buttdata[idx]['fb_type']
    if fbt and fbt ~= 'SPEC1' and fbt ~= 'XCTLLED' and fbt ~= 'PITCH' and fbt ~= 'DUMMY' then
      return true
    end
    
  end
  
  function CropActive(idx)
    if (lvar.imagefn or '') ~= '' then
      return true
    end
  end
  
  function ValInt(v)
    if tonumber(v) then
      return string.format('%i',v)
    end
    return v
  end
  
  function MTypeCol(idx)
    return lvar.lrncol[lvar.buttdata[idx].miditype or 0]
  end

  function TTypeCol(idx)
    return lvar.lrncol[lvar.buttdata[idx].t_type or 0]
  end
  
  function FTypeCol(idx)
    return lvar.lrncol[lvar.buttdata[idx].fb_type or 0]
  end
  
  
  function SetUpPages()
    pages.x = 10
    pages.y = 40
    pages.w = 150
    pages.h = 22
    
    pages[1] = {x=pages.x,y=pages.y+(pages.h+2)*0,w=pages.w,h=pages.h,text='Controls'}
    pages[2] = {x=pages.x,y=pages.y+(pages.h+2)*1,w=pages.w,h=pages.h,text='Sort Groups'}
    pages[3] = {x=pages.x,y=pages.y+(pages.h+2)*2,w=pages.w,h=pages.h,text=''}
    pages[4] = {x=pages.x,y=pages.y+(pages.h+2)*3,w=pages.w,h=pages.h,text='Channel Strips',bsel_func = ButtSel_CStrip}
    pages[5] = {x=pages.x,y=pages.y+(pages.h+2)*4,w=pages.w,h=pages.h,text='Flip Controls',bsel_func = ButtSel_Flip}
  
    pages[6] = {x=pages.x,y=pages.y+(pages.h+2)*5,w=pages.w,h=pages.h,text='Scribble Strips'}
    pages[7] = {x=pages.x,y=pages.y+(pages.h+2)*6,w=pages.w,h=pages.h,text='Timecode'}
    pages[8] = {x=pages.x,y=pages.y+(pages.h+2)*7,w=pages.w,h=pages.h,text='Additional Data'}
    pages[10] = {x=pages.x,y=pages.y+(pages.h+2)*8,w=pages.w,h=pages.h,text='Setup Data'}

    pages[9] = {x=pages.x,y=pages.y+(pages.h+2)*10,w=pages.w,h=pages.h*2,text='Sort & Create Map'}
    
    ctlpage.activepage = 1
    ctlpage.bx1 = 250
    ctlpage.bx2 = 560
    ctlpage.bx3 = 870
    ctlpage.by1 = 40
    ctlpage.bh1 = 22
    ctlpage.bw1 = 200
    ctlpage.bw2 = 100
    ctlpage.bw3 = 300
    ctlpage.bw4 = 50
    ctlpage.topinfoh = 16
  
    ctlpage.gridx = 250
    ctlpage.gridy = 64
    ctlpage.gridw = 90
    ctlpage.gridh = 22
    
    ctlpage[1] = {}
    ctlpage[1][1] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*0,w=ctlpage.bw1,h=ctlpage.bh1,title='Name',dataindex='name', uitxt = 'Enter control name:', uiextraw = 100, compul = true}
    ctlpage[1][30] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*1,w=ctlpage.bw1,h=ctlpage.bh1,title='Short Name',dataindex='shortname', uitxt = 'Enter control short name:', uiextraw = 100}
    ctlpage[1][2] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*2,w=ctlpage.bw1,h=ctlpage.bh1,title='Sort Group',dataindex='sort',datatab = 3, formatval = SGrp_FormatVal, multiedit = true, compul = true}
    ctlpage[1][3] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*3.5,w=ctlpage.bw2,h=ctlpage.bh1,title='Button Group',dataindex='group',datatab = 10, multiedit = true--[[formatval = BGrp_FormatVal]]}
    ctlpage[1][4] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=ctlpage.bw2,h=ctlpage.bh1,title='Midi Type',dataindex='miditype',datatab = 1, colorfunc = MTypeCol, compul = true, compul = true}
    ctlpage[1][5] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*7,w=ctlpage.bw2,h=ctlpage.bh1,title='Midi Num',dataindex='midinum', valactive = MidiActive2, uitxt = 'Enter MIDI number:', valfunc = Val0To127, colorfunc = MTypeCol, compul = true}
    ctlpage[1][6] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*6,w=ctlpage.bw2,h=ctlpage.bh1,title='Midi Chan',dataindex='midichan',datatab = 3, valactive = MidiActive3, formatval = ValInt, colorfunc = MTypeCol, compul = true}
    ctlpage[1][7] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*8,w=ctlpage.bw1,h=ctlpage.bh1,title='Mode',dataindex='mode',datatab = 4, valactive = MidiActive3, compul = true}
    
    ctlpage[1][8] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*10,w=ctlpage.bw4,h=ctlpage.bh1,title='Scribble Strip',dataindex='ssnum',datatab = 5}
    ctlpage[1][26] = {x=ctlpage.bx1+102,y=ctlpage.by1+(ctlpage.bh1+2)*10,w=ctlpage.bw4,h=ctlpage.bh1,title='',dataindex='ssnum_main',
                      LClick = Click_SSNumMain, RClick = RClick_SSNumMain, title_top = 'DEFAULT',title_toph = ctlpage.topinfoh, formatval = SSNum_Main_FormatVal, fontsz = -2}
    
    ctlpage[1][9] = {x=ctlpage.bx2,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=ctlpage.bw2,h=ctlpage.bh1,title='Touch Type',dataindex='t_type',datatab = 2, valfunc = ValTType, colorfunc = TTypeCol}
    ctlpage[1][10] = {x=ctlpage.bx2,y=ctlpage.by1+(ctlpage.bh1+2)*7,w=ctlpage.bw2,h=ctlpage.bh1,title='Touch Num',dataindex='t_num', valactive = TouchActive2, uitxt = 'Enter MIDI number:', valfunc = Val0To127, colorfunc = TTypeCol}
    ctlpage[1][11] = {x=ctlpage.bx2,y=ctlpage.by1+(ctlpage.bh1+2)*6,w=ctlpage.bw2,h=ctlpage.bh1,title='Touch Chan',dataindex='t_chan',datatab = 3, valactive = TouchActive, colorfunc = TTypeCol}
    ctlpage[1][12] = {x=ctlpage.bx2,y=ctlpage.by1+(ctlpage.bh1+2)*8,w=ctlpage.bw2,h=ctlpage.bh1,title='Touch On Val',dataindex='t_on', valactive = TouchActive, uitxt = 'Enter MIDI value:', valfunc = Val0To127, colorfunc = TTypeCol}
    ctlpage[1][13] = {x=ctlpage.bx2,y=ctlpage.by1+(ctlpage.bh1+2)*9,w=ctlpage.bw2,h=ctlpage.bh1,title='Touch Off Val',dataindex='t_off', valactive = TouchActive, uitxt = 'Enter MIDI value:', valfunc = Val0To127, colorfunc = TTypeCol}
  
    ctlpage[1][14] = {x=ctlpage.bx3,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=ctlpage.bw2,h=ctlpage.bh1,title='Feedback Type',dataindex='fb_type',datatab = 6, valfunc = ValFBType, colorfunc = FTypeCol}
    ctlpage[1][15] = {x=ctlpage.bx3,y=ctlpage.by1+(ctlpage.bh1+2)*7,w=ctlpage.bw2,h=ctlpage.bh1,title='Feedback Num',dataindex='fb_num', valactive = FBActive3, uitxt = 'Enter MIDI number:', valfunc = Val0To127, colorfunc = FTypeCol}
    ctlpage[1][16] = {x=ctlpage.bx3,y=ctlpage.by1+(ctlpage.bh1+2)*6,w=ctlpage.bw2,h=ctlpage.bh1,title='Feedback Chan',dataindex='fb_chan',datatab = 3, valactive = FBActive, colorfunc = FTypeCol}
    ctlpage[1][17] = {x=ctlpage.bx3,y=ctlpage.by1+(ctlpage.bh1+2)*8,w=ctlpage.bw2,h=ctlpage.bh1,title='CC_A',dataindex='fb_cca', valactive = FBActive2, uitxt = 'Enter CC number:', valfunc = Val0To127}
    ctlpage[1][18] = {x=ctlpage.bx3,y=ctlpage.by1+(ctlpage.bh1+2)*9,w=ctlpage.bw2,h=ctlpage.bh1,title='CC_B',dataindex='fb_ccb', valactive = FBActive2, uitxt = 'Enter CC number:', valfunc = Val0To127}
    --ctlpage[1][19] = {x=ctlpage.bx2,y=ctlpage.by1+(ctlpage.bh1+2)*0,w=ctlpage.bw2,h=ctlpage.bh1,title='ID',dataindex='id'}

    ctlpage[1][19] = {x=ctlpage.bx1+50+ctlpage.bw2+2,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=40,h=ctlpage.bh1,title='',dataindex='mlrn',formatval = MLrn_FormatVal, LClick = MLrn_Click, fontsz = -2,bgcol = '64 128 255', fgcol = '0 0 0'}
    ctlpage[1][20] = {x=ctlpage.bx2+ctlpage.bw2+2,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=40,h=ctlpage.bh1,title='',dataindex='mlrn',formatval = MLrn_FormatVal, LClick = TLrn_Click, fontsz = -2,bgcol = '64 128 255', fgcol = '0 0 0'}

    ctlpage[1][21] = {x=ctlpage.bx2+ctlpage.bw2+2,y=ctlpage.by1+(ctlpage.bh1+2)*1,w=60,h=ctlpage.bh1,title='Crop Left',dataindex='crop_l', LClick = CropL_Click, fontsz = -2, formattitle = FormatTitCropL, valactive = CropActive}
    ctlpage[1][22] = {x=ctlpage.bx2+ctlpage.bw2+2,y=ctlpage.by1+(ctlpage.bh1+2)*2,w=60,h=ctlpage.bh1,title='Crop Right',dataindex='crop_r', LClick = CropR_Click, fontsz = -2, formattitle = FormatTitCropR, valactive = CropActive}
    ctlpage[1][23] = {x=ctlpage.bx2+ctlpage.bw2+140,y=ctlpage.by1+(ctlpage.bh1+2)*1,w=60,h=ctlpage.bh1,title='Top',dataindex='crop_t', LClick = CropT_Click, fontsz = -2, formattitle = FormatTitCropT, valactive = CropActive}
    ctlpage[1][24] = {x=ctlpage.bx2+ctlpage.bw2+140,y=ctlpage.by1+(ctlpage.bh1+2)*2,w=60,h=ctlpage.bh1,title='Bottom',dataindex='crop_b', LClick = CropB_Click, fontsz = -2, valactive = CropRectActive, valactive = CropActive}

    ctlpage[1][25] = {x=ctlpage.bx2+ctlpage.bw2+2,y=ctlpage.by1+(ctlpage.bh1+2)*0,w=200,h=ctlpage.bh1,title='',dataindex='xx', LClick = LClick_Dummy, fontsz = -2, formatval = function() return 'Transparent Area Crop' end,bgcol = '128 128 128', fgcol = '0 0 0', valactive = CropActive}
    
    ctlpage[1][27] = {x=ctlpage.bx1-20,y=0--[[ctlpage.by1+(ctlpage.bh1+2)*0]],w=ctlpage.bw2-40,h=ctlpage.bh1,title='Add', 
                     dataindex = 'xx', formatval = function() return 'FADER' end, LClick = AddFader_Click, alwaysshow = true, fgcol = '255 128 128'}
    ctlpage[1][28] = {x=ctlpage[1][27].x+ctlpage[1][27].w+4,y=0--[[ctlpage.by1+(ctlpage.bh1+2)*0]],w=ctlpage.bw2-20,h=ctlpage.bh1,title='', 
                     dataindex = 'xx', formatval = function() return 'ENCODER' end, LClick = AddEncoder_Click, alwaysshow = true, fgcol = '255 128 128'}
    ctlpage[1][29] = {x=ctlpage[1][28].x+ctlpage[1][28].w+4,y=0--[[ctlpage.by1+(ctlpage.bh1+2)*0]],w=ctlpage.bw2-20,h=ctlpage.bh1,title='', 
                     dataindex = 'xx', formatval = function() return 'BUTTON' end, LClick = AddButton_Click, alwaysshow = true, fgcol = '255 128 128'}
    
    lvar.cstrip_rows = {'Fader','Encoder','Mute','Solo','Select','Record','Enc Push','Meter LED','Other 1','Other 2'}

    ctlpage[2] = {}
    for c = 1, 16 do
      local x
      if c <= 8 then
        x = ctlpage.bx1+100
      else
        x = ctlpage.bx2+150
      end
      ctlpage[2][c] = {x=x,y=ctlpage.by1+(ctlpage.bh1+2)*(((c-1) % 8)+1),w=ctlpage.bw1,h=ctlpage.bh1,title='Sort Group '..string.format('%i',c-1),
                       dataindex2='sortgroup'..string.format('%i',c-1), uitxt = 'Enter sort group name:', uiextraw = 100, RClick = SGrp_RClick, idx = c-1}
    end

    --[[ctlpage[3] = {}
    for c = 1, 16 do
      local x
      if c <= 8 then
        x = ctlpage.bx1+100
      else
        x = ctlpage.bx2 + 50
      end
      ctlpage[3][c] = {x=x,y=ctlpage.by1+(ctlpage.bh1+2)*(((c-1) % 8)+1),w=ctlpage.bw2,h=ctlpage.bh1,title='Btn Group '..string.format('%i',c),
                       dataindex2='btngroup'..string.format('%i',c), datatab = 7, valfunc = ValButtGroup, RClick = BGrp_RClick, idx = c}

    end]]
    
    ctlpage[4] = {}
    for c = 1, 8 do
      for r = 1, 10 do
        local idx = ((r-1)*8)+c
        ctlpage[4][idx] = {x=ctlpage.gridx+(ctlpage.gridw+2)*(c-1),y=ctlpage.gridy+(ctlpage.gridh+2)*(r-1),
                           w=ctlpage.gridw,h=ctlpage.gridh,title='', dataindex2 = 'chanstrip_'..string.format('%i',r)..'_'..string.format('%i',c), fontsz = -2,
                           row = r, col = c, idx = idx, LClick = CStrip_Click, formatval = CStrip_FormatVal, RClick = CStrip_RClick}
        if idx <= 8 then
          ctlpage[4][idx].title_top = 'Strip '..string.format('%i',idx)
          ctlpage[4][idx].title_toph = ctlpage.topinfoh
        end
        if c == 1 then
          ctlpage[4][idx].title_left = lvar.cstrip_rows[r]
          ctlpage[4][idx].title_leftw = 70
        end
      end
    end

    ctlpage[5] = {}
    for c = 1, 8 do
      for r = 1, 2 do
        local idx = ((r-1)*8)+c
        ctlpage[5][idx] = {x=ctlpage.gridx+(ctlpage.gridw+2)*(c-1),y=ctlpage.gridy+(ctlpage.gridh+2)*(2+r-1),
                           w=ctlpage.gridw,h=ctlpage.gridh,title='', dataindex2 = 'flip_'..string.format('%i',r)..'_'..string.format('%i',c), fontsz = -2,
                           row = r, col = c, idx = idx, LClick = Flip_Click, formatval = CStrip_FormatVal}
        if idx <= 8 then
          ctlpage[5][idx].title_top = 'Strip '..string.format('%i',idx)
          ctlpage[5][idx].title_toph = ctlpage.topinfoh
        end
        if c == 1 then
          ctlpage[5][idx].title_left = lvar.cstrip_rows[r]
          ctlpage[5][idx].title_leftw = 70
        end
      end
    end
    
    local ssw = 750
    ctlpage[6] = {}
    ctlpage[6][1] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*3,w=ssw,h=ctlpage.bh1,title='Scribble 1',dataindex2='ss1_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][1].title_top = 'SysX String'
    ctlpage[6][1].title_toph = ctlpage.topinfoh
    
    ctlpage[6][2] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*4,w=ssw,h=ctlpage.bh1,title='Scribble 2',dataindex2='ss2_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][3] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=ssw,h=ctlpage.bh1,title='Scribble 3',dataindex2='ss3_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][4] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*6,w=ssw,h=ctlpage.bh1,title='Scribble 4',dataindex2='ss4_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][5] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*7,w=ssw,h=ctlpage.bh1,title='Scribble 5',dataindex2='ss5_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][6] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*8,w=ssw,h=ctlpage.bh1,title='Scribble 6',dataindex2='ss6_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][7] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*9,w=ssw,h=ctlpage.bh1,title='Scribble 7',dataindex2='ss7_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}
    ctlpage[6][8] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*10,w=ssw,h=ctlpage.bh1,title='Scribble 8',dataindex2='ss8_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSSSysX, AltLClick = AltClick_SS}

    ctlpage[6][9] = {x=ctlpage.bx1-20,y=0--[[ctlpage.by1+(ctlpage.bh1+2)*0]],w=ctlpage.bw3-40,h=ctlpage.bh1,title='Preset',dataindex2='sspreset', datatab = 8, 
                     idx = 9, LClick = SSPreset_Click}
    ctlpage[6][10] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*1,w=ctlpage.bw3,h=ctlpage.bh1,title='Color Mode',dataindex2='sscolormode', datatab = 9, 
                     idx = 10}

    ctlpage[7] = {}
    ctlpage[7][1] = {x=ctlpage.bx1+20,y=ctlpage.by1+(ctlpage.bh1+2)*0,w=ctlpage.bw4+20,h=ctlpage.bh1,title='Display Digits',dataindex2='tc_digits',datatab = 11}

    for d = 1, 16 do
      local x
      if d <= 10 then
        x = ctlpage.bx1-20
      else--if d <= 12 then
        x = ctlpage.bx1+120
      --else
        --x = ctlpage.bx1+320
      end
      ctlpage[7][1+d] = {x=x,y=ctlpage.by1+(ctlpage.bh1+2)*(2+((d-1) % 10)),w=ctlpage.bw4+20,h=ctlpage.bh1,title='Digit '..string.format('%i',d),
                         idx = d, dataindex2='tc_digit'..string.format('%i',d), valactive = TCDigitActive, uitxt = 'Enter CC number:', valfunc = Val0To127}
      if d == 1 or d == 11 then
        ctlpage[7][1+d].title_top = 'CC Num'
        ctlpage[7][1+d].title_toph = ctlpage.topinfoh
      end
    end
    
    local nchars = #dispchar
    local ncharsd2 = math.floor(nchars/2 + 1)
    for d = 0, nchars -1 do
      local x
      if d < ncharsd2 then
        x = ctlpage.bx2+270
      else
        x = ctlpage.bx2+370
      end
      ctlpage[7][18+d] = {x=x,y=ctlpage.by1+(ctlpage.bh1+2)*(2+((d) % ncharsd2)),w=ctlpage.bw4+20,h=ctlpage.bh1,title=dispchar[d+1], valactive = TCDigitActive2,
                         idx = d, dataindex2='tc_char'..string.format('%i',d), uitxt = 'Enter CC value for character '..dispchar[d+1]..':', valfunc = Val0To127}
      if d == 0 or d == ncharsd2 then
        if d == 0 then
          ctlpage[7][18+d].title= 'Char '..ctlpage[7][18+d].title
        end
        ctlpage[7][18+d].title_top = 'Code Val'
        ctlpage[7][18+d].title_toph = ctlpage.topinfoh
      end
    end
    
    local nidx = 18+nchars-1

    local x = ctlpage.bx1+300
    local w = ctlpage.bw4
    --ctlpage[7][30] = {x=x,y=ctlpage.by1+(ctlpage.bh1+2)*1,w=ctlpage.bw1,h=ctlpage.bh1,title="Beats Format", font = 'Courier New', fontsz = -2,
    --                  idx = 30, dataindex2='tc_beatsformat', uitxt = 'Enter beats format string:', uiextraw = 100, valfunc = ValTCString}
    --ctlpage[7][31] = {x=x,y=ctlpage.by1+(ctlpage.bh1+2)*2,w=ctlpage.bw1,h=ctlpage.bh1,title="Time Format", font = 'Courier New', fontsz = -2,
    --                  idx = 31, dataindex2='tc_timeformat', uitxt = 'Enter time format string:', uiextraw = 100, valfunc = ValTCString}
    
    --bars beats sub frames
    local y = ctlpage.by1+(ctlpage.bh1+2)*2
    ctlpage[7][nidx+7] = {x=x,y=y,w=w,h=ctlpage.bh1,title="Beats Format",title_top = 'Bars',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+7, dataindex2='tc_beatsformat_bars', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    ctlpage[7][nidx+8] = {x=x+(w+2)*1,y=y,w=w,h=ctlpage.bh1,title="",title_top = 'Beats',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+8, dataindex2='tc_beatsformat_beats', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    ctlpage[7][nidx+9] = {x=x+(w+2)*2,y=y,w=w,h=ctlpage.bh1,title="",title_top = 'Sub',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+9, dataindex2='tc_beatsformat_sub', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    ctlpage[7][nidx+10] = {x=x+(w+2)*3,y=y,w=w,h=ctlpage.bh1,title="",title_top = 'Frames',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+10, dataindex2='tc_beatsformat_frames', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    
    --hours mins secs frames
    local y = ctlpage.by1+(ctlpage.bh1+2)*4
    ctlpage[7][nidx+11] = {x=x,y=y,w=w,h=ctlpage.bh1,title="Time Format",title_top = 'Hours',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+11, dataindex2='tc_timeformat_hours', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    ctlpage[7][nidx+12] = {x=x+(w+2)*1,y=y,w=w,h=ctlpage.bh1,title="",title_top = 'Mins',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+12, dataindex2='tc_timeformat_mins', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    ctlpage[7][nidx+13] = {x=x+(w+2)*2,y=y,w=w,h=ctlpage.bh1,title="",title_top = 'Secs',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+13, dataindex2='tc_timeformat_secs', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}
    ctlpage[7][nidx+14] = {x=x+(w+2)*3,y=y,w=w,h=ctlpage.bh1,title="",title_top = 'Frames',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+14, dataindex2='tc_timeformat_frames', uitxt = 'Enter number of digits to display:', valfunc = ValTCString}


    --local x = ctlpage.bx1+320
    local y1 = ctlpage.by1+(ctlpage.bh1+2)*6
    local y2 = ctlpage.by1+(ctlpage.bh1+2)*7
    ctlpage[7][nidx+1] = {x=x,y=y1,w=ctlpage.bw4,h=ctlpage.bh1,title="Beats LED",title_top = 'Note',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+1, dataindex2='tc_beatsled_note', uitxt = 'Enter beats LED note number:', valfunc = Val0To127}
    ctlpage[7][nidx+2] = {x=x,y=y2,w=ctlpage.bw4,h=ctlpage.bh1,title="Time LED", valactive = TCDigitActive2,
                      idx = nidx+2, dataindex2='tc_timeled_note', uitxt = 'Enter time LED note number:', valfunc = Val0To127}
    local x = ctlpage.bx1+300+ctlpage.bw4+2
    ctlpage[7][nidx+3] = {x=x,y=y1,w=ctlpage.bw4,h=ctlpage.bh1,title="",title_top = 'On',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+3, dataindex2='tc_beatsled_on', uitxt = 'Enter beats LED on value:', valfunc = Val0To127}
    ctlpage[7][nidx+4] = {x=x,y=y2,w=ctlpage.bw4,h=ctlpage.bh1,title="", valactive = TCDigitActive2,
                      idx = nidx+4, dataindex2='tc_timeled_on', uitxt = 'Enter time LED on value:', valfunc = Val0To127}
    local x = ctlpage.bx1+300+(ctlpage.bw4+2)*2
    ctlpage[7][nidx+5] = {x=x,y=y1,w=ctlpage.bw4,h=ctlpage.bh1,title="",title_top = 'Off',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+5, dataindex2='tc_beatsled_off', uitxt = 'Enter beats LED off value:', valfunc = Val0To127}
    ctlpage[7][nidx+6] = {x=x,y=y2,w=ctlpage.bw4,h=ctlpage.bh1,title="", valactive = TCDigitActive2,
                      idx = nidx+6, dataindex2='tc_timeled_off', uitxt = 'Enter time LED off value:', valfunc = Val0To127}
    
    ctlpage[7][nidx+15] = {x=ctlpage.bx1-20,y=0,w=ctlpage.bw3-40,h=ctlpage.bh1,title='Preset',dataindex2='tcpreset', datatab = 12, 
                     idx = nidx+15, LClick = TCPreset_Click}
    
    --Assignment digits
    local x = ctlpage.bx1+300
    local y = ctlpage.by1+(ctlpage.bh1+2)*10
    ctlpage[7][nidx+16] = {x=x,y=y,w=ctlpage.bw4,h=ctlpage.bh1,title="Assignment Display",title_top = 'Dig1 CC',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+16, dataindex2='tc_asscc1', uitxt = 'Enter Assignment Digit 1 CC number:', valfunc = Val0To127}
    local x = ctlpage.bx1+300+ctlpage.bw4+2
    ctlpage[7][nidx+17] = {x=x,y=y,w=ctlpage.bw4,h=ctlpage.bh1,title="",title_top = 'Dig1. CC',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+17, dataindex2='tc_asscc1d', uitxt = 'Enter Assignment Digit 1 (with period) CC number:', valfunc = Val0To127}
    local x = ctlpage.bx1+300+(ctlpage.bw4+2)*2
    ctlpage[7][nidx+18] = {x=x,y=y,w=ctlpage.bw4,h=ctlpage.bh1,title="",title_top = 'Dig2 CC',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+18, dataindex2='tc_asscc2', uitxt = 'Enter Assignment Digit 2 CC number:', valfunc = Val0To127}
    local x = ctlpage.bx1+300+(ctlpage.bw4+2)*3
    ctlpage[7][nidx+19] = {x=x,y=y,w=ctlpage.bw4,h=ctlpage.bh1,title="",title_top = 'Dig2. CC',title_toph = ctlpage.topinfoh, valactive = TCDigitActive2,
                      idx = nidx+19, dataindex2='tc_asscc2d', uitxt = 'Enter Assignment Digit 2 (with period) CC number:', valfunc = Val0To127}
    
    
    ctlpage[8] = {}
    ctlpage[8][1] = {x=ctlpage.bx1+50,y=ctlpage.by1+(ctlpage.bh1+2)*3,w=ctlpage.bw3*2,h=ctlpage.bh1,title="Handshake", font = 'Courier New', fontsz = -2,
                      idx = 1, dataindex2='handshake', uitxt = 'Enter handshake SysX string:', uiextraw = 200, valfunc = ValSysX}
    ctlpage[8][1].title_top = 'SysX String'
    ctlpage[8][1].title_toph = ctlpage.topinfoh
    ctlpage[8][2] = {x=ctlpage.bx1+250,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=ctlpage.bw2,h=ctlpage.bh1,title="Bitmap Control Transparency",
                      idx = 2, dataindex2='bmpalpha', datatab = 13}
    ctlpage[8][3] = {x=ctlpage.bx1+250,y=ctlpage.by1+(ctlpage.bh1+2)*7,w=ctlpage.bw2,h=ctlpage.bh1,title="Pass thru note and pitch",
                      idx = 3, dataindex2='notesthru', datatab = 14}
    ctlpage[8][3].title_top = 'on Channel'
    ctlpage[8][3].title_toph = ctlpage.topinfoh
    ctlpage[8][4] = {x=ctlpage.bx1+250,y=ctlpage.by1+(ctlpage.bh1+2)*9,w=ctlpage.bw2,h=ctlpage.bh1,title="Toggle button 'On' value",
                      idx = 3, dataindex2='but_onval', uitxt = 'Enter MIDI value (1-127):', uiextraw = 0, valfunc = ValButOnVal}

    ctlpage[9] = {}
    for idx = 1, 40 do
      local x = ctlpage.gridx-25+((ctlpage.gridw+2)*2)*math.floor((idx-1) / 10)
      local y = ctlpage.gridy-ctlpage.gridh/2+(ctlpage.gridh+2)*((idx-1) % 10)
      
      ctlpage[9][idx] = {x=x,y=y,
                         w=ctlpage.gridw*2+2,h=ctlpage.gridh,title='', fontsz = -2,
                         idx = idx, LClick = FSort_Click, wheelfunc = FSort_Wheel}
    end

    ctlpage[9][41] = {x=ctlpage.gridx+70,y=ctlpage.gridy-ctlpage.bh1*1.5-2,
                      w=ctlpage.gridw*2+2,h=ctlpage.gridh,title='Sort Group', fontsz = -2,
                      LClick = FSortG_Click, formatval = FSortG_FormatVal, bgcol = '48 48 48'--[[, fgcol = '0 0 0']]}
    
    ctlpage[9][42] = {x=ctlpage.gridx-25+(ctlpage.gridw+2)*3,y=299,
                      w=ctlpage.gridw*2+2,h=ctlpage.gridh*1.5,title='', fontsz = -2,
                      LClick = CreateMap_Click, formatval = CM_FormatVal}

    ctlpage[9][43] = {x=ctlpage.gridx-70,y=126,
                      w=40,h=ctlpage.gridh*2,title='', fontsz = -2,
                      LClick = CMUP_Click, formatval = CMUP_FormatVal, title_top = 'MOVE',title_toph = ctlpage.topinfoh}
    ctlpage[9][44] = {x=ctlpage.gridx-70,y=174,
                      w=40,h=ctlpage.gridh*2,title='', fontsz = -4,
                      LClick = CMDN_Click, formatval = CMDN_FormatVal}
    
    local ssw = 750
    ctlpage[10] = {}
    ctlpage[10][1] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*0,w=ssw,h=ctlpage.bh1,title='SysEx 1',dataindex2='setup1_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][1].title_top = 'SysX String'
    ctlpage[10][1].title_toph = ctlpage.topinfoh-2
    
    ctlpage[10][2] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*1,w=ssw,h=ctlpage.bh1,title='SysEx 2',dataindex2='setup2_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][3] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*2,w=ssw,h=ctlpage.bh1,title='SysEx 3',dataindex2='setup3_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][4] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*3,w=ssw,h=ctlpage.bh1,title='SysEx 4',dataindex2='setup4_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][5] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*4,w=ssw,h=ctlpage.bh1,title='SysEx 5',dataindex2='setup5_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][6] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*5,w=ssw,h=ctlpage.bh1,title='SysEx 6',dataindex2='setup6_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][7] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*6,w=ssw,h=ctlpage.bh1,title='SysEx 7',dataindex2='setup7_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][8] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*7,w=ssw,h=ctlpage.bh1,title='SysEx 8',dataindex2='setup8_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][9] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*8,w=ssw,h=ctlpage.bh1,title='SysEx 9',dataindex2='setup9_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][10] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*9,w=ssw,h=ctlpage.bh1,title='SysEx 10',dataindex2='setup10_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][11] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*10,w=ssw,h=ctlpage.bh1,title='SysEx 11',dataindex2='setup11_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    ctlpage[10][12] = {x=ctlpage.bx1,y=ctlpage.by1+(ctlpage.bh1+2)*11,w=ssw,h=ctlpage.bh1,title='SysEx 12',dataindex2='setup12_sysx', font = 'Courier New', fontsz = -2, uitxt = 'Enter SysX String:', uiextraw = 800, valfunc = ValSysX, AltLClick = AltClick_SS}
    
  end

  function SetDefaults()
    --Set Defaults
    --if not lvar.buttdata['tc_digits'] then
    --  lvar.buttdata['tc_digits'] = 10
    --end
    if not lvar.buttdata['bmpalpha'] then
      lvar.buttdata['bmpalpha'] = 0.5
      lvar.buttdata['bmpalpha_desc'] = '50%'
    end
    if not lvar.buttdata['but_onval'] then
      lvar.buttdata['but_onval'] = 127
    end
    
  end

  function CreateMap()
    
    --Sort
    
    --Validate Data
    local valss = {}
    local valssmain = {}
    local valbg = {}
    local valsort = {}
    local errctl = {}
    local err = 0
    local success = true
    local mdcheck = {}
    
    --name sort group miditype midichan midinum mode ssnum t_type t_chan t_num t_on t_off fb_type fb_chan fb_num fb_cca fb_ccb
    for i = 1, #lvar.buttdata do
      local b = lvar.buttdata[i]
      local name = b.name
      if name == nil then
        DBG('ERROR: Button '..i..' has no name')
        name = 'Unnamed button '..i
        errctl[i] = true
        err = err + 1
      end
      if b.sort == nil then
        DBG('ERROR: '..name..' has no sort group assigned')
        errctl[i] = true
        err = err + 1
      end
      if b.miditype == nil then
        DBG('ERROR: '..name..' has invalid midi type')
        errctl[i] = true
        err = err + 1
      else
        if b.miditype == 'N/A' then
        elseif b.midichan == nil or (b.miditype ~= 'PITCH' and b.midinum == nil) then
          DBG('ERROR: '..name..' has invalid midi data')
          errctl[i] = true
          err = err + 1
        else
          if b.miditype and b.miditype ~= 'NIL' then
            local idx = b.miditype..'_'..b.midichan..'_'..(b.midinum or '')
            if mdcheck[idx] then
              DBG('ERROR: Duplicate midi data for '..name..' and '..mdcheck[idx])
              errctl[i] = true
              err = err + 1
            else
              mdcheck[idx] = name or 'Unnamed button '..i
            end
          end
        end
      end
      if b.mode == nil and b.miditype ~= 'N/A' then
        DBG('ERROR: '..name..' has invalid mode')
        errctl[i] = true
        err = err + 1
      end

      if b.t_type ~= nil and b.t_type ~= '-' then
        if b.t_chan == nil or b.t_num == nil then
          DBG('ERROR: '..name..' has invalid touch data')
          errctl[i] = true
          err = err + 1
        else
          local idx = b.t_type..'_'..b.t_chan..'_'..b.t_num
          if mdcheck[idx] then
            DBG('ERROR: Duplicate touch data for '..name..' and '..mdcheck[idx])
            errctl[i] = true
            err = err + 1
          else
            mdcheck[idx] = name or 'Unnamed button '..i
          end
        end
      end

      if b.fb_type ~= nil and b.fb_type ~= '-' then
        if b.fb_type == 'PITCH' then
          if b.fb_chan == nil then
            DBG('ERROR: '..name..' has invalid feedback data')
            errctl[i] = true
            err = err + 1
          end
        elseif b.fb_type == 'NOTE' or b.fb_type == 'CC' then
          if b.fb_chan == nil or b.fb_num == nil then
            DBG('ERROR: '..name..' has invalid feedback data')
            errctl[i] = true
            err = err + 1
          end
        elseif b.fb_type == 'SPEC1' or b.fb_type == 'XCTLLED' then
          if b.fb_cca == nil or b.fb_ccb == nil then
            DBG('ERROR: '..name..' has invalid feedback data')
            errctl[i] = true
            err = err + 1
          end
        end
      end
      if b.ssnum and b.ssnum ~= '-' then
        if tonumber(b.ssnum) then
          valss[tonumber(b.ssnum)] = true
        else
          valss[string.byte(b.ssnum)-64] = true
        end
        --DBG(b.ssnum ..'  '..tostring(b.ssnum_main)..'  '..lvar.buttdata[i].name)
        if b.ssnum_main then
          if tonumber(b.ssnum) then
            valssmain[tonumber(b.ssnum)] = (valssmain[tonumber(b.ssnum)] or 0) + 1
          else
            valssmain[string.byte(b.ssnum)-64] = (valssmain[string.byte(b.ssnum)-64] or 0) + 1
          end
        end
      end
      if b.group and b.group ~= '-' then
        valbg[b.group] = (valbg[b.group] or 0) + 1
      end
      if b.sort then
        valsort[b.sort] = true
      end
    end

    for a, b in pairs(valsort) do
      local idx = 'sortgroup'..string.format('%i',a)
      if not lvar.buttdata[idx] then
        DBG('SORT GROUP ERROR: Sort Group '..string.format('%i',a)..' is referenced but has no name')
        err = err + 1
      end
    end
    
    for a, b in pairs(valbg) do
      --[[local idx = 'btngroup'..string.format('%i',a)
      if not lvar.buttdata[idx] then
        DBG('BUTTON GROUP ERROR: Btn Group '..string.format('%i',a)..' is referenced but has no value')
        err = err + 1
      end]]
      if b > 8 then
        DBG('BUTTON GROUP WARNING: Btn Group '..string.format('%i',a)..' has more than 8 entries')
        --err = err + 1
      end
    end

    for a, b in pairs(valss) do
      local idx = 'ss'..string.format('%i',a)..'_sysx'
      if not (lvar.buttdata[idx] and ValSSSysX(lvar.buttdata[idx])) then
        DBG('SCRIBBLE STRIP ERROR: Scribble Strip '..string.format('%i',a)..' is referenced but the SysX string is invalid')
        err = err + 1
      end
    end

    for i = 1, 8 do
      if valss[i] then
        if not valssmain[i] then
          DBG('SCRIBBLE STRIP ERROR: Scribble Strip '..string.format('%i',i)..' does not have a default control assignment')
          err = err + 1
        elseif valssmain[i] ~= 1 then
          DBG('SCRIBBLE STRIP ERROR: Scribble Strip '..string.format('%i',i)..' has more than 1 default control assignment')
          err = err + 1
        end
      end
    end

    for c = 1, 8 do
      local idx1 = 'flip_1_'..string.format('%i',c)
      local idx2 = 'flip_2_'..string.format('%i',c)
      if (lvar.buttdata[idx1] and not lvar.buttdata[idx2]) or (lvar.buttdata[idx2] and not lvar.buttdata[idx1]) then
        DBG('FLIP ERROR: Flip (Strip '..string.format('%i',c)..') is incomplete')
        err = err + 1
      end
    end
    
    if lvar.buttdata['tc_digits'] then
      if not lvar.buttdata['tc_beatsformat_bars'] or not lvar.buttdata['tc_beatsformat_beats'] or not lvar.buttdata['tc_beatsformat_sub'] or not lvar.buttdata['tc_beatsformat_frames'] then
        DBG('TIMECODE ERROR: Beats Format is incomplete')
        err = err + 1
      elseif lvar.buttdata['tc_beatsformat_bars'] + lvar.buttdata['tc_beatsformat_beats'] + lvar.buttdata['tc_beatsformat_sub'] + lvar.buttdata['tc_beatsformat_frames'] ~= lvar.buttdata['tc_digits'] then
        DBG('TIMECODE ERROR: Beats Format total digits does not match Display Digits value')
        err = err + 1
      end

      if not lvar.buttdata['tc_timeformat_hours'] or not lvar.buttdata['tc_timeformat_mins'] or not lvar.buttdata['tc_timeformat_secs'] or not lvar.buttdata['tc_timeformat_frames'] then
        DBG('TIMECODE ERROR: Time Format is incomplete')
        err = err + 1
      elseif lvar.buttdata['tc_timeformat_hours'] + lvar.buttdata['tc_timeformat_mins'] + lvar.buttdata['tc_timeformat_secs'] + lvar.buttdata['tc_timeformat_frames'] ~= lvar.buttdata['tc_digits'] then
        DBG('TIMECODE ERROR: Time Format total digits does not match Display Digits value')
        err = err + 1
      end

      for d = 1, lvar.buttdata['tc_digits'] do
        local idx = 'tc_digit'..string.format('%i',d)
        if not lvar.buttdata[idx] then
          DBG('TIMECODE ERROR: CC number for Digit '..string.format('%i',d) ..' missing')
          err = err + 1
        end
      end

      for d = 0, #dispchar2-1 do
        local idx = 'tc_char'..string.format('%i',d)
        if not lvar.buttdata[idx] then
          DBG('TIMECODE ERROR: Character code for '..dispchar[d+1] ..' missing')
          err = err + 1
        end
      end
    end
    
    lvar.buttsel_err = {}
    lvar.buttsel_err_idx = {}
    if err > 0 then
      DBG('Total errors: '..string.format('%i',err))
      for a, b in pairs(errctl) do
      
        if a then
          local idx = #lvar.buttsel_err+1
          lvar.buttsel_err[idx] = a
          lvar.buttsel_err_idx[a] = idx
        end
        
      end
      update_gfx = true
      update_cbox = true
      
    else
      --data passed validation
      --produce map string
      --SortButtData()
      local ret, fn = reaper.GetUserInputs('Create Map',1,'Filename:;extrawidth=100','')
      
      if ret and fn ~= '' then
        local sfn = fn..'.skctlmap'
        if reaper.file_exists(paths.controllermaps..sfn) then
          if reaper.MB('File exists.  Overwrite?', 'Create Map', 4) ~= 6 then
            return
          end
        end
        local cm_string = GetCMString()
        local cm_locstring = GetCMLocString()

        reaper.RecursiveCreateDirectory(paths.controllermaps..fn, 1)
        writebinaryfile(paths.controllermaps..sfn, cm_string)
        writebinaryfile(paths.controllermaps..fn..'/device_data.txt', cm_locstring)
        
        ProcessBMP(paths.controllermaps..fn..'/')
        
      end        
      update_gfx = true
      update_cbox = true
      
    end
    
  end
  
  function CheckSortMsg(cnt)
    if cnt == 1 then
      return cnt..' control without a sort group will be deleted.  Continue?'
    else
      return cnt..' controls without a sort group will be deleted.  Continue?'
    end
  end
  
  function SortButtData(checksortgrp)
  
    local tab = {}
    local sorttab = {}
    local cancel
    
    local cnt_tot = 0
    for a, b in pairs(lvar.buttdata) do
      --retain non-button information
      if not tonumber(a) then
        tab[a] = b
      else
        cnt_tot = cnt_tot + 1
      end
    end
    local moved = {}
    local cnt_sort = 0
    
    for sg = 0, 15 do
      sorttab[sg] = {}
      for b = 1, #lvar.buttdata do
        
        if lvar.buttdata[b].sort == sg then
          cnt_sort = cnt_sort + 1
          local nidx = #tab + 1
          tab[nidx] = lvar.buttdata[b]
          moved[b] = nidx
          local sidx = #sorttab[sg]+1
          sorttab[sg][sidx] = nidx
        end
      end
    end

    if checksortgrp and cnt_tot > cnt_sort and reaper.MB(CheckSortMsg(cnt_tot-cnt_sort),'Control Sort',4) ~= 6 then
      cancel = true
    else
    
      lvar.buttdata = tab
      lvar.buttsel = {}
      lvar.buttsel_idx = {}
      lvar.buttsel_err = {}
      lvar.buttsel_err_idx = {}
      
      ButtMoved(moved)
    end
    
    return sorttab, cancel
    
  end

  function LICE_text_fit(gui, xywh, text, flags, col, tsz, font, vertical, bitmap)
  
    if col == nil then col = '205 205 205' end
    if tsz == nil then tsz = 0 end
    
    f_Get_SSV(col)  
    local fit = false
    
    local testw = xywh.w
    local tflags = ''
    if vertical then
      testw = xywh.h
      tflags = 'VERTICAL'
    end
    
    local gdi_font, lice_font
    while not fit and gui.fontsz+tsz > 8 do
      if gdi_font then
        reaper.JS_GDI_DeleteObject(gdi_font)
        reaper.JS_LICE_DestroyFont(lice_font)
      end
      gdi_font = reaper.JS_GDI_CreateFont(gui.fontsz+tsz, 400, 0, false, false, false, font or gui.fontname)
      lice_font = reaper.JS_LICE_CreateFont()
      reaper.JS_LICE_SetFontFromGDI(lice_font, gdi_font, '')
      
      local tw = reaper.JS_LICE_MeasureText(text)
      if tw > testw then
        tsz = tsz - 1
      else
        fit = true
      end
    end
    reaper.JS_GDI_DeleteObject(gdi_font)
    reaper.JS_LICE_DestroyFont(lice_font)
    gdi_font = reaper.JS_GDI_CreateFont(gui.fontsz+tsz, 400, 0, false, false, false, font or gui.fontname)
    lice_font = reaper.JS_LICE_CreateFont()
    reaper.JS_LICE_SetFontFromGDI(lice_font, gdi_font, tflags)
    local tw = reaper.JS_LICE_MeasureText(text)
    th = gui.fontsz+tsz
    if vertical then
      tw, th = th, tw
    end
    local xx, yy, rr, bb
    xx = xywh.x+xywh.w/2 - tw/2
    yy = xywh.y+xywh.h/2 - th/2
    rr = xywh.x+xywh.w/2 + tw/2
    bb = xywh.y+xywh.h/2 + th/2
    
    local lice_col = (0xFF<<24)+gfx.r*255 + ((gfx.g*255) << 8) + ((gfx.b*255) << 16)
    reaper.JS_LICE_SetFontColor(lice_font, lice_col)
    reaper.JS_LICE_DrawText(bitmap, lice_font, text, string.len(text), math.floor(xx), math.floor(yy), math.floor(rr), math.floor(bb))

    reaper.JS_GDI_DeleteObject(gdi_font)
    reaper.JS_LICE_DestroyFont(lice_font)
    
    --gfx.drawstr(text, flags, r, b)
  
  end

  function ProcessBMP(savefol)
    
    local fn = lvar.imagefn
    if fn then
      if fn == '' then
      
        --local gdi_font = reaper.JS_GDI_CreateFont(integer height, integer weight, integer angle, boolean italic, boolean underline, boolean strike, string fontName)
        local bmp = reaper.JS_LICE_CreateBitmap(true, lvar.imagew, lvar.imageh)
        reaper.JS_LICE_FillRect(bmp, 0, 0, lvar.imagew, lvar.imageh, 0xFF<<24, 1, 'COPY')
        local alpha = 1 --lvar.buttdata.bmpalpha
        
        --[[for i = 1, #lvar.buttdata do
          local bd = lvar.buttdata[i]
          if bd.shape == 0 then
            local r,g,b = 128, 128, 128
            local col = (0xFF<<24) + r + (g<<8) + (b<<16)
            local x,y,w,h = bd.x, bd.y, bd.w, bd.h
            reaper.JS_LICE_FillTriangle(bmp, math.floor(x), math.floor(y), math.floor(x+w), math.floor(y), math.floor(x+w), math.floor(y+h), 0, alpha, 'COPYALPHA')
            reaper.JS_LICE_FillTriangle(bmp, math.floor(x), math.floor(y+1), math.floor(x), math.floor(y+h), math.floor(x+w-1), math.floor(y+h), 0, alpha, 'COPYALPHA')
            --reaper.JS_LICE_RoundRect(bmp, bd.x, bd.y, bd.w, bd.h, 0, col, 1, 'COPY', false)
            if bd.w >= bd.h then
              LICE_text_fit(gui, bd, bd.name, 5, '128 128 128', 2, nil, nil, bmp)
            else
              LICE_text_fit(gui, bd, bd.name, 5, '128 128 128', 2, nil, true, bmp)
            end
          else
            local xywh = {x = bd.x-bd.r, y = bd.y - bd.r, w = bd.r*2, h = bd.r*2} 
            reaper.JS_LICE_FillCircle(bmp,math.floor(bd.x),math.floor(bd.y),math.floor(bd.r),0,alpha,'COPYALPHA',true)
            LICE_text_fit(gui, xywh, bd.name, 5, '128 128 128', 2, nil, nil, bmp)
          end
        end]]
        
        --DBG(lvar.imagew..'  '..lvar.imageh)
        reaper.JS_LICE_WritePNG(savefol..'device_img.png',bmp,true)
        reaper.JS_LICE_DestroyBitmap(bmp)
        
      else
      
        local bmp
        if string.match(fn,'.+(%.png)$') then
          bmp = reaper.JS_LICE_LoadPNG(fn)
        elseif string.match(fn,'.+(%.jpg)$') then
          bmp = reaper.JS_LICE_LoadJPG(fn)
        end  
        if bmp then
          local alpha = lvar.buttdata.bmpalpha
        
          for i = 1, #lvar.buttdata do
            local bd = lvar.buttdata[i]
            if bd.shape == 0 then
              local x = bd.x + (bd.crop_l or 0)
              local y = bd.y + (bd.crop_t or 0)
              local w = bd.w - (bd.crop_l or 0) + (bd.crop_r or 0)
              local h = bd.h - (bd.crop_t or 0) + (bd.crop_b or 0)
              --reaper.JS_LICE_FillRect(bmp,math.floor(bd.x),math.floor(bd.y),math.floor(bd.w),math.floor(bd.h),0x00000000,0.5,'COPYALPHA')
              reaper.JS_LICE_FillTriangle(bmp, math.floor(x), math.floor(y), math.floor(x+w), math.floor(y), math.floor(x+w), math.floor(y+h), 0, alpha, 'COPYALPHA')
              reaper.JS_LICE_FillTriangle(bmp, math.floor(x), math.floor(y+1), math.floor(x), math.floor(y+h), math.floor(x+w-1), math.floor(y+h), 0, alpha, 'COPYALPHA')
              --reaper.JS_LICE_ProcessRect(bmp, math.floor(bd.x),math.floor(bd.y),math.floor(bd.w),math.floor(bd.h), 'SET_A', 0)
              --[[reaper.JS_LICE_GradRect(bmp, math.floor(bd.x + (bd.crop_l or 0)),
                                           math.floor(bd.y + (bd.crop_t or 0)),
                                           math.floor(bd.w - (bd.crop_l or 0) + (bd.crop_r or 0)),
                                           math.floor(bd.h - (bd.crop_t or 0) + (bd.crop_b or 0)), 0, 0, 0, alpha, 0, 0, 0, 0, 0, 0, 0, 0, 'COPYALPHA')]]
              
            elseif bd.shape == 1 then
  
              reaper.JS_LICE_FillCircle(bmp,math.floor(bd.x + (bd.crop_l or 0)),math.floor(bd.y + (bd.crop_t or 0)),math.floor(bd.r + (bd.crop_r or 0)),0,alpha,'COPYALPHA',true)
              --reaper.JS_LICE_FillCircle(bmp,bd.x,bd.y,bd.r,alpha,1,'MULALPHA',true)
            
            end
          end
          reaper.JS_LICE_WritePNG(savefol..'device_img.png',bmp,true)
          reaper.JS_LICE_DestroyBitmap(bmp)
        end
      end
      
    end
  
  end

  function GetCMLocString()

    local cm_locstring = '//Created by LBX_CM_Creator '..lvar.version..'\n'
    cm_locstring = cm_locstring .. '\n'
    if (lvar.imagefn or '') == '' then
      cm_locstring = cm_locstring .. '[TYPE]1\n'
    end
    for i = 1, #lvar.buttdata do
      local bd = lvar.buttdata[i]
      if bd.shape == 0 then
        local l, r, t, b
        l = string.format('%i',math.floor(bd.x))
        t = string.format('%i',math.floor(bd.y))
        r = string.format('%i',math.floor(bd.x + bd.w))
        b = string.format('%i',math.floor(bd.y + bd.h))
        cm_locstring = cm_locstring .. '<'..bd.name..'> '..l..' '..r..' '..t..' '..b..' [0 0 0] '..string.format('%i',bd.shape)

        local cl, cr, ct, cb
        cl = string.format('%i',math.floor(bd.crop_l or 0))
        cr = string.format('%i',math.floor(bd.crop_r or 0))
        ct = string.format('%i',math.floor(bd.crop_t or 0))
        cb = string.format('%i',math.floor(bd.crop_b or 0))
        cm_locstring = cm_locstring .. ' '..cl..' '..cr..' '..ct..' '..cb..' "'..(bd.shortname or '')..'"\n'
      elseif bd.shape == 1 then
        local l, r, t, b
        l = string.format('%i',math.floor(bd.x))
        t = string.format('%i',math.floor(bd.y))
        r = string.format('%i',math.floor(bd.r))
        b = 0
        cm_locstring = cm_locstring .. '<'..bd.name..'> '..l..' '..r..' '..t..' '..b..' [0 0 0] '..string.format('%i',bd.shape)

        local cl, cr, ct, cb
        cl = string.format('%i',math.floor(bd.crop_l or 0))
        cr = string.format('%i',math.floor(bd.crop_r or 0))
        ct = string.format('%i',math.floor(bd.crop_t or 0))
        cb = string.format('%i',math.floor(bd.crop_b or 0))
        cm_locstring = cm_locstring .. ' '..cl..' '..cr..' '..ct..' '..cb..' "'..(bd.shortname or '')..'"\n'
      end
      
    end
    
    return cm_locstring
    
  end
  
  function CheckBG(bg)
    for i = 1, #lvar.buttdata do
      local bd = lvar.buttdata[i]
      if tonumber(bd.group) == bg then
        return true
      end
    end
  end
  
  function GetCMString()
  
    local cm_string = '//Created by LBX_CM_Creator '..lvar.version..'\n'
    cm_string = cm_string..'[FADERS]'..#lvar.buttdata..'\n'
  
    cm_string = cm_string .. '\n//Fader - SORT / GROUP / NAME / TYPE / NUM / CHAN / MODE / SS NUM / TOUCH_TYPE / NUM / CHAN / ON / OFF\n'
    cm_string = cm_string .. '//MODE - 0=Abs / 6=Relative1 / 2=Relative2 / 3=Relative3 / 4=Button\n\n'
    for i = 1, #lvar.buttdata do
      local bd = lvar.buttdata[i]
      cm_string = cm_string .. GenFString(i, bd)
    end

    cm_string = cm_string .. '\n//Feedback - TYPE / NUM / CHAN\n'
    cm_string = cm_string .. '//XCtl encoder single LED: SPEC1 / 0 / CHAN / CC_A / CC_B\n'
    cm_string = cm_string .. '//XCtl LED Strip: XCTLLED / 0 / CHAN / VAL OFFS / RANGE\n'
    for i = 1, #lvar.buttdata do
      local bd = lvar.buttdata[i]
      cm_string = cm_string .. GenFBString(i, bd)
    end

    cm_string = cm_string..'\n'
  
    for i = 1, 8 do
      if lvar.buttdata['ss'..string.format('%i',i)..'_sysx'] then
        local id = string.char(64+i)
        cm_string = cm_string .. '[SS'..id..']'..string.format('%i',i)..'\n'
      end
    end

    cm_string = cm_string..'\n'

    for i = 1, 16 do
    
      --local v = lvar.buttdata['btngroup'..string.format('%i',i)]
      if CheckBG(i) then
        local id = string.format('%i',i)
        cm_string = cm_string .. '[GRPSEL'..id..']'..string.format('%i',i)..'\n'
      end
    end

    cm_string = cm_string..'\n'

    for i = 0, 15 do
      local v = lvar.buttdata['sortgroup'..string.format('%i',i)]
      if v then
        local id = string.format('%i',i)
        cm_string = cm_string .. '[SORTGRP'..id..']'..v..'\n'
      end
    end
    
    cm_string = cm_string .. '\n//Color mode: 1 = XTouch CTRL/CTRLREL 2 = XTouch XCTL\n'
    
    local v = lvar.buttdata['sscolormode']
    if v then
      cm_string = cm_string .. '[SSCOLORMODE]'..string.format('%i',v)..'\n'
    end

    cm_string = cm_string .. '\n//Scribble Strips\n'

    for i = 1, 32 do
      local v = lvar.buttdata['ss'..string.format('%i',i)..'_sysx']
      if v then
        local id = string.format('%i',i)
        cm_string = cm_string .. '[SS'..id..']'..v..'\n'
      end
    end

    cm_string = cm_string .. '\n//Flip\n'

    for i = 1, 8 do
      local v = lvar.buttdata['flip_1_'..string.format('%i',i)]
      local v2 = lvar.buttdata['flip_2_'..string.format('%i',i)]
      if v and v2 then
        local id = string.format('%i',i)
        cm_string = cm_string .. '[FLIP'..id..']'..string.format('%i',v)..' '..string.format('%i',v2)..'\n'
      end
    end

    cm_string = cm_string .. '\n//Channel strips --fader/encoder/mute/solo/select/record/encoder push/led meter\n'
    
    for i = 1, 8 do
      local v1 = lvar.buttdata['chanstrip_1_'..string.format('%i',i)] or -1
      local v2 = lvar.buttdata['chanstrip_2_'..string.format('%i',i)] or -1
      local v3 = lvar.buttdata['chanstrip_3_'..string.format('%i',i)] or -1
      local v4 = lvar.buttdata['chanstrip_4_'..string.format('%i',i)] or -1
      local v5 = lvar.buttdata['chanstrip_5_'..string.format('%i',i)] or -1
      local v6 = lvar.buttdata['chanstrip_6_'..string.format('%i',i)] or -1
      local v7 = lvar.buttdata['chanstrip_7_'..string.format('%i',i)] or -1
      local v8 = lvar.buttdata['chanstrip_8_'..string.format('%i',i)] or -1
      local v9 = lvar.buttdata['chanstrip_9_'..string.format('%i',i)] or -1
      local v10 = lvar.buttdata['chanstrip_10_'..string.format('%i',i)] or -1
      local id = string.format('%i',i)
      cm_string = cm_string .. '[CHANSTRIP'..id..']'..string.format('%i',v1)..' '..string.format('%i',v2)..' '..string.format('%i',v3)..
                  ' '..string.format('%i',v4)..' '..string.format('%i',v5)..' '..string.format('%i',v6)..' '..string.format('%i',v7)..
                  ' '..string.format('%i',v8)..' '..string.format('%i',v9)..' '..string.format('%i',v10)..'\n'
    end
    
    if lvar.buttdata['tc_digits'] then

      cm_string = cm_string .. "\n//Assignment LEDs - D1 = digit 1, D2 = digit 2 - CC Numbers\n"
      cm_string = cm_string .. "//D1 no DP / D1 DP / D2 no DP / D2 DP\n"
      local a = string.format('%i',lvar.buttdata['tc_asscc1'])
      local b = string.format('%i',lvar.buttdata['tc_asscc1d'])
      local c = string.format('%i',lvar.buttdata['tc_asscc2'])
      local d = string.format('%i',lvar.buttdata['tc_asscc2d'])
      if a and b and c and d then
        cm_string = cm_string..'[ASSIGNMENTDISPLAY]'..a..' '..b..' '..c..' '..d..'\n'
      end
      
      --[ASSIGNMENTDISPLAY]96 112 97 113

      cm_string = cm_string .. "\n//Time code display CC's\n"
      cm_string = cm_string .. "//<TIME FORMAT STRING> / <BEATS FORMAT STRING> / #CCs / CC's ...\n"

      local a = string.format('%i',lvar.buttdata['tc_timeformat_hours'])
      local b = string.format('%i',lvar.buttdata['tc_timeformat_mins'])
      local c = string.format('%i',lvar.buttdata['tc_timeformat_secs'])
      local d = string.format('%i',lvar.buttdata['tc_timeformat_frames'])
      local tc_time = '<%'..a..'d%0'..b..'d%0'..c..'d%'..d..'d>'
      local a = string.format('%i',lvar.buttdata['tc_beatsformat_bars'])
      local b = string.format('%i',lvar.buttdata['tc_beatsformat_beats'])
      local c = string.format('%i',lvar.buttdata['tc_beatsformat_sub'])
      local d = string.format('%i',lvar.buttdata['tc_beatsformat_frames'])
      local tc_beats = '<%'..a..'d%'..b..'d%'..c..'d%'..d..'d>'
      local str = lvar.buttdata['tc_digits']
      for i = 1, lvar.buttdata['tc_digits'] do
        local id = 'tc_digit'..string.format('%i',i)
        str = str..' '..string.format('%i',lvar.buttdata[id])
      end
      cm_string = cm_string..'[TIMECODEDISPLAY]'..tc_time..' '..tc_beats..' '..str..'\n'
      
      local a = lvar.buttdata['tc_beatsled_note']
      local b = lvar.buttdata['tc_beatsled_on']
      local c = lvar.buttdata['tc_beatsled_off']
      if a and b and c then
        cm_string = cm_string..'[TIMECODE_BEATS_LED]'..string.format('%i',a)..' '..string.format('%i',b)..' '..string.format('%i',c)..'\n'
      end

      local a = lvar.buttdata['tc_timeled_note']
      local b = lvar.buttdata['tc_timeled_on']
      local c = lvar.buttdata['tc_timeled_off']
      if a and b and c then
        cm_string = cm_string..'[TIMECODE_SMPTE_LED]'..string.format('%i',a)..' '..string.format('%i',b)..' '..string.format('%i',c)..'\n'
      end
      
      cm_string = cm_string .. "\n//DISPLAYCHAR CHAR / VAL\n"
      for d = 0, #dispchar2-1 do
        local idx = 'tc_char'..string.format('%i',d)
        cm_string = cm_string..'[DISPLAYCHAR'..string.format('%i',d)..']'..dispchar2[d+1]..' '..string.format('%i',lvar.buttdata[idx])..'\n'
      end
      
    end
    
    cm_string = cm_string .. '\n//Controller Initialize SYSX Strings\n'
    
    local c = 1
    for i = 1, 32 do
      local v = lvar.buttdata['setup'..string.format('%i',i)..'_sysx']
      if v then
        local id = string.format('%i',c)
        cm_string = cm_string .. '[SETUP_SYSX_'..id..']'..v..'\n'
        c = c + 1
      end
    end
    
    cm_string = cm_string..'\n'
    
    if lvar.buttdata['handshake'] then
      cm_string = cm_string..'[HANDSHAKE]'..lvar.buttdata['handshake']..'\n'
    end

    cm_string = cm_string..'\n'
    
    if lvar.buttdata['notesthru'] then
      cm_string = cm_string..'[NOTESTHRU]'..lvar.buttdata['notesthru']..'\n'
    end
    
    cm_string = cm_string..'\n'
        
    if lvar.buttdata['but_onval'] then
      cm_string = cm_string..'[BUTTON_ON_VAL]'..lvar.buttdata['but_onval']..'\n'
    end
    
    return cm_string
  end

  function GenFString(i, bd)
  
    local midinum = bd.midinum
    if bd.miditype == 'PITCH' then
      midinum = '0'
    end
    local ssnum = bd.ssnum
    if ssnum and bd.ssnum_main then
      if tonumber(bd.ssnum) then
        ssnum = tonumber(bd.ssnum)
      else
        ssnum = string.byte(bd.ssnum)-64
      end
    else
      if tonumber(ssnum) then
        ssnum = string.char(64+bd.ssnum)
      end
    end
    if tonumber(ssnum) then
      ssnum = string.format('%i',ssnum)
    elseif ssnum == nil then
      ssnum = '-'
    end
    --DBG(i..' '..tostring(ssnum)..'  '..tostring(bd.ssnum))
    local group = bd.group
    if tonumber(group) then
      group = tonumber(group) --lvar.buttdata['btngroup'..string.format('%i',group)]
    else
      group = '-'
    end
    local str
    if bd.miditype == 'N/A' then
      str = '[F'..string.format('%i',i)..']'.. string.format('%i',bd.sort)..' '..group..' <'..bd.name..'> NIL 0 0 0 -'
    else
      str = '[F'..string.format('%i',i)..']'.. string.format('%i',bd.sort)..' '..group..' <'..bd.name..'> '..
                bd.miditype..' '..midinum..' '..string.format('%i',bd.midichan)..' '..string.format('%i',bd.mode)..' '..ssnum
    
      if bd.t_type and bd.t_type ~= '-' then
        
        str = str..' '..bd.t_type..' '..string.format('%i',bd.t_num)..' '..string.format('%i',bd.t_chan)..' '..string.format('%i',bd.t_on)..' '..string.format('%i',bd.t_off)
      end
    end
    
    str = str ..'\n'
    return str
  end

  function GenFBString(i, bd)
    
    local str = ''
    
    if bd.fb_type and bd.fb_type ~= '-' then
      local fbnum, chan = bd.fb_num, bd.fb_chan
      if bd.fb_type == 'PITCH' then
        str = '[FB'..string.format('%i',i)..']'..bd.fb_type..' 0 '..string.format('%i',chan)
      elseif bd.fb_type == 'CC' or bd.fb_type == 'NOTE' or bd.fb_type == 'SPEC2' then
        str = '[FB'..string.format('%i',i)..']'..bd.fb_type..' '..fbnum..' '..string.format('%i',chan)
      elseif bd.fb_type == 'DUMMY' then
        str = '[FB'..string.format('%i',i)..']'..bd.fb_type..' 0 0'
      else
        fbnum = '0'
        chan = '0'      
        str = '[FB'..string.format('%i',i)..']'..bd.fb_type..' 0 0 '..string.format('%i',bd.fb_cca)..' '..string.format('%i',bd.fb_ccb)
      end
  
  
      str = str ..'\n'
      return str
    else
      return ''
    end
  end

  function CM_FormatVal()
    return 'CREATE MAP'
  end

  function CMUP_FormatVal()
    return 'UP'
  end
  
  function CMDN_FormatVal()
    return 'DOWN'
  end
  
  function CreateMap_Click()
    CreateMap()
  end
  
  function CMUP_Click()
    if lvar.sorttab_idx and lvar.sorttab_idx > 1 then

      moved = {}
      for i = 1, #lvar.buttdata do
        moved[i] = i
      end
      
      moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]
      moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]
    
      local tmp = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]]
      lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]]
      lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]] = tmp
      
      ButtMoved(moved)
      lvar.sorttab = SortButtData()
      lvar.sorttab_idx = lvar.sorttab_idx - 1
      update_gfx = true
      update_cbox = true
    
    end
  end

  function CMDN_Click()
    if lvar.sorttab_idx and lvar.sorttab_idx < #lvar.sorttab[lvar.sortsel] then

      moved = {}
      for i = 1, #lvar.buttdata do
        moved[i] = i
      end
      
      moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]
      moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]
    
      local tmp = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]]
      lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]]
      lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]] = tmp
      
      ButtMoved(moved)
      lvar.sorttab = SortButtData()
      lvar.sorttab_idx = lvar.sorttab_idx + 1
      update_gfx = true
      update_cbox = true
    
    end
  end
  
  function FSortG_Click()
    
    local mstr = ''
    for i = 0, 15 do
      local idx = 'sortgroup'..string.format('%i',i)
      if i > 0 then
        mstr = mstr .. '|'
      end
      mstr = mstr .. (lvar.buttdata[idx] or '-')
    end
    gfx.x = obj.sections[5].x + ctlpage[9][41].x
    gfx.y = obj.sections[5].y + ctlpage[9][41].y + ctlpage[9][41].h
    local res = gfx.showmenu(mstr)
    if res > 0 then
      lvar.sortsel = res-1
      lvar.sorttab_idx = nil
      update_cbox = true
    end
  end
  
  function FSortG_FormatVal()
    if lvar.sortsel then
      local idx = 'sortgroup'..string.format('%i',lvar.sortsel)
      return lvar.buttdata[idx]
    end
  end

  function FSort_Wheel(v)
    lvar.sortoffs = math.max(math.min(lvar.sortoffs - v*10,math.ceil((#lvar.sorttab[lvar.sortsel]-40)/10)*10),0)
    update_cbox = true
  end

  function FSort_Click(idx)
    if idx+lvar.sortoffs <= #lvar.sorttab[lvar.sortsel] then
      lvar.sorttab_idx = idx+lvar.sortoffs
      update_cbox = true
    end
  end

  function LClick_Dummy()
    --do nothing
  end
  
  function AddFader_Click()
    mouse.context = contexts.add_fader
    local fsize_w, fsize_h = lvar.def_fader.w*lvar.ctlzoom_f, lvar.def_fader.h*lvar.ctlzoom_f
    lvar.add_fader = {x = math.floor(mouse.mx-fsize_w/2), y = math.floor(mouse.my-fsize_h/2), w = fsize_w, h = fsize_h}
  end

  function AddEncoder_Click()
    mouse.context = contexts.add_encoder
    local fsize_r = lvar.def_encoder.r*lvar.ctlzoom_e
    lvar.add_encoder = {x = mouse.mx, y = mouse.my, r = fsize_r}
  end

  function AddButton_Click()
    mouse.context = contexts.add_button
    if lvar.btype == 0 then
      fsize_r = lvar.def_button.r*2*lvar.ctlzoom_b
      lvar.add_button = {x = math.floor(mouse.mx-fsize_r/2), y = math.floor(mouse.my-fsize_r/2), r = fsize_r}
    else
      fsize_r = lvar.def_button.r*lvar.ctlzoom_b
      lvar.add_button = {x = mouse.mx, y = mouse.my, r = fsize_r}
    end
  end
  
  function CropL_Click()
  
    mouse.context = contexts.crop
    local v = lvar.buttdata[lvar.buttsel[1]].crop_l or 0
    local v2 = lvar.buttdata[lvar.buttsel[1]].crop_r or 0
    lvar.crop = {y = mouse.my+obj.sections[5].y, val = v, cidx = 'crop_l', cidx2 = 'crop_r', val2 = v2}
  
  end

  function CropR_Click()
  
    mouse.context = contexts.crop
    local v = lvar.buttdata[lvar.buttsel[1]].crop_r or 0
    local v2 = lvar.buttdata[lvar.buttsel[1]].crop_l or 0
    lvar.crop = {y = mouse.my+obj.sections[5].y, val = v, cidx = 'crop_r', cidx2 = 'crop_l', val2 = v2}
  
  end
  
  function CropT_Click()
  
    mouse.context = contexts.crop
    local v = lvar.buttdata[lvar.buttsel[1]].crop_t or 0
    local v2 = lvar.buttdata[lvar.buttsel[1]].crop_b or 0
    lvar.crop = {y = mouse.my+obj.sections[5].y, val = v, cidx = 'crop_t', cidx2 = 'crop_b', val2 = v2}
  
  end
  
  function CropB_Click()
  
    mouse.context = contexts.crop
    local v = lvar.buttdata[lvar.buttsel[1]].crop_b or 0
    local v2 = lvar.buttdata[lvar.buttsel[1]].crop_t or 0
    lvar.crop = {y = mouse.my+obj.sections[5].y, val = v, cidx = 'crop_b', cidx2 = 'crop_t', val2 = v2}
  
  end
  
  function MLrn_FormatVal()
    return 'LEARN'
  end
  
  function MLrn_Click()
  
    if #lvar.buttsel > 0 then
      MLrn_SetUp()
    
      lvar.midilearn = {ltype = 0, bd = lvar.buttdata[lvar.buttsel[1]]}
      reaper.gmem_write(gmem_reset,1)
      lvar.ml_cnt = 0
      lvar.ml_rec = {}
      update_lrn = true
    end
    
  end

  function TLrn_Click()
  
    if #lvar.buttsel > 0 then
      MLrn_SetUp()
    
      lvar.midilearn = {ltype = 1, bd = lvar.buttdata[lvar.buttsel[1]]}
      reaper.gmem_write(gmem_reset,1)
      lvar.ml_cnt = 0
      lvar.ml_rec = {}
      update_lrn = true
    end
    
  end

  function MLrn_SetUp(delete)
    local fnd
    if lvar.midilearn_track then
      local ret, nm = reaper.GetTrackName(lvar.midilearn_track)
      if nm ~= lvar.midilearn_trname then
        lvar.midilearn_track = nil
        fnd = false
      else
        fnd = true
      end
    end
    if not fnd then
      --search
      for t = 0, reaper.GetNumTracks()-1 do
        local tr = reaper.GetTrack(0, t)
        local ret, nm = reaper.GetTrackName(tr)
        if nm == lvar.midilearn_trname then
          lvar.midilearn_track = tr
          --DBG('found learn track')
        end
      end
      if delete then
        if lvar.midilearn_track then
          reaper.DeleteTrack(lvar.midilearn_track)
        end
      else
        if not lvar.midilearn_track then
          --DBG('creating learn track')
          --create
          if not lvar.mididevices then
            lvar.mididevices = GetMIDIDevices()
          end
          
          local mididevices = lvar.mididevices
          reaper.PreventUIRefresh(1)
          local tr
          local trnum = reaper.GetNumTracks()
          reaper.InsertTrackAtIndex(trnum, false)
          tr = reaper.GetTrack(0, trnum)
          reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", lvar.midilearn_trname, true)
          reaper.SetMediaTrackInfo_Value(tr,'B_MAINSEND',0) 
          reaper.SetMediaTrackInfo_Value(tr,'D_VOL',0)
          reaper.SetMediaTrackInfo_Value(tr,'I_AUTOMODE',0)
          --reaper.SetMediaTrackInfo_Value(tr,'I_RECINPUT',dev)
          
          reaper.TrackFX_AddByName(tr, 'JS:LBX_CM_LRN', false, -1)
          reaper.TrackFX_AddByName(tr, 'JS:LBX_SYSXOut', false, -1)
          
          if lvar.buttdata.listenport then
          
            local pidx = mididevices.inidx2[lvar.buttdata.listenport]
            if pidx and mididevices.input[pidx] then
              local b = mididevices.input[pidx].dev
              local dev = 4096+(b << 5)
              reaper.SetMediaTrackInfo_Value(tr,'I_RECINPUT',dev)
              reaper.SetMediaTrackInfo_Value(tr,'I_RECMODE',2)
              reaper.SetMediaTrackInfo_Value(tr,'I_RECARM',1)
              reaper.SetMediaTrackInfo_Value(tr,'I_RECMON',1)
            end
          end
          lvar.midilearn_track = tr
          if lvar.buttdata.handshakeport then
            local pidx = mididevices.outidx2[lvar.buttdata.handshakeport]
            if pidx and mididevices.output[pidx] then
              local b = mididevices.output[pidx].dev
              local dev = (b << 5)
              reaper.SetMediaTrackInfo_Value(tr, 'I_MIDIHWOUT', dev)
              SetUpHandshake(0, lvar.buttdata.handshake)
            end            
          end
          reaper.PreventUIRefresh(-1)
        end
      end
    else
      if delete then
        if lvar.midilearn_track then
          reaper.DeleteTrack(lvar.midilearn_track)
        end
      end
    end
  end

  function RClick_SSNumMain(idx)

    

  end

  function ClearAllDefSSNum()

    for i = 1, #lvar.buttdata do
      local b = lvar.buttdata[i]
      b.ssnum_main = nil
    end
    update_cbox = true
  
  end
  
  function Click_SSNumMain(idx)
    if mouse.ctrl and mouse.shift then
      ClearAllDefSSNum()
    else
      local bd = lvar.buttdata[idx]
      if bd.ssnum_main then
        bd.ssnum_main = nil
      else
        bd.ssnum_main = 1
      end
    end
    update_cbox = true
  end

  function SSNum_Main_FormatVal(v)
    if v == 1 then
      return '*'
    else
      return ''
    end
  end
  
  function BGrp_FormatVal(v)
    if v then
      return string.format('%i',v)..' ['..(lvar.buttdata['btngroup'..string.format('%i',v or -1)] or 'not set')..']'
    end
  end

  function BGrp_RClick(idx)
    --highlight BGrp
    lvar.buttsel = {}
    lvar.buttsel_idx = {}
    for i = 1, #lvar.buttdata do
      local b = lvar.buttdata[i]
      if b.group == idx then
        local idx2 = #lvar.buttsel+1
        lvar.buttsel[idx2] = i
        lvar.buttsel_idx[i] = idx2
      end
    end
    update_gfx = true
    update_cbox = true
    
  end

  function SGrp_FormatVal(v)
    if v then
      local txt = (lvar.buttdata['sortgroup'..string.format('%i',v or -1)])
      if txt then
        txt = ' - '..txt
      end
      return string.format('%i',v)..(txt or '')
    end
  end

  function SGrp_RClick(idx)
    --highlight SGrp
    lvar.buttsel = {}
    lvar.buttsel_idx = {}
    for i = 1, #lvar.buttdata do
      local b = lvar.buttdata[i]
      if b.sort == idx then
        local idx2 = #lvar.buttsel+1
        lvar.buttsel[idx2] = i
        lvar.buttsel_idx[i] = idx2
      end
    end
    update_gfx = true
    update_cbox = true
    
  end
  
  function CStrip_FormatVal(v)
    if v then
      return lvar.buttdata[v].name
    end
  end
  
  function CStrip_Click(idx, row, col, dataindex)
    --DBG(idx..'  '..row..'  '..col..'  '..dataindex)
    if mouse.alt then
      lvar.buttdata[dataindex] = nil
    else
      if lvar.cstrip and lvar.cstrip.sel == idx then
        lvar.cstrip = nil
        SetButtSel()
      else
        lvar.cstrip = {}
        lvar.cstrip.sel = idx
        SetButtSel(lvar.buttdata[dataindex])
      end
    end    
    update_cbox = true
  end

  function CStrip_RClick(idx)
    lvar.buttsel = {}
    lvar.buttsel_idx = {}

    idx = ((idx-1) % 8)+1
    for i = 0, 9 do
      local idx2 = i*8+idx
      local r = math.floor((idx2-1) / 8) + 1
      local c = (idx2-1) % 8 + 1
      v = lvar.buttdata['chanstrip_'..string.format('%i',r)..'_'..string.format('%i',c)]
      --DBG(r.. '  '..c..'  '..tostring(v))
      if v then
        local idx3 = #lvar.buttsel+1
        lvar.buttsel[idx3] = v
        lvar.buttsel_idx[v] = idx3
      end
    end
    update_gfx = true
    update_cbox = true
  end
  
  function Flip_Click(idx, row, col, dataindex)
    --DBG(idx..'  '..row..'  '..col..'  '..dataindex)
    if mouse.alt then
      lvar.buttdata[dataindex] = nil
    else
      if lvar.flip and lvar.flip.sel == idx then
        lvar.flip = nil
        SetButtSel()
      else
        lvar.flip = {}
        lvar.flip.sel = idx
        SetButtSel(lvar.buttdata[dataindex])
      end
    end
    
    update_cbox = true
  end
  
  function GetDescFromVal(dtab, val, nilval)
  
    if val == nil then return nilval end
    
    for i = 1, #datatab[dtab] do
    
      if val == datatab[dtab][i] then
        return datatab_desc[dtab][i]
      end
    
    end
  
  end
  
  function AltClick_SS(idx, row, col, dataindex, dtab)
  
    lvar.buttdata[dataindex] = nil
    update_cbox = true
  
  end
  
  function SSPreset_Click(idx, row, col, dataindex, dtab)
  
    local page = ctlpage.activepage
    local x = obj.sections[5].x + ctlpage[page][idx].x
    local y = obj.sections[5].y + ctlpage[page][idx].y + ctlpage[page][idx].h
  
    local res = DataTab_Menu(dtab, x, y)
    if res > 0 then
      local didx = datatab[dtab][res]
      if lvar.SSPreset[didx] then
      
        lvar.buttdata['sspreset'] = didx

        lvar.buttdata['sscolormode'] = lvar.SSPreset[didx].cmode
        lvar.buttdata['sscolormode_desc'] = GetDescFromVal(9, lvar.SSPreset[didx].cmode, 'None')
        lvar.buttdata['ss1_sysx'] = lvar.SSPreset[didx][1]
        lvar.buttdata['ss2_sysx'] = lvar.SSPreset[didx][2]
        lvar.buttdata['ss3_sysx'] = lvar.SSPreset[didx][3]
        lvar.buttdata['ss4_sysx'] = lvar.SSPreset[didx][4]
        lvar.buttdata['ss5_sysx'] = lvar.SSPreset[didx][5]
        lvar.buttdata['ss6_sysx'] = lvar.SSPreset[didx][6]
        lvar.buttdata['ss7_sysx'] = lvar.SSPreset[didx][7]
        lvar.buttdata['ss8_sysx'] = lvar.SSPreset[didx][8]
        
        update_cbox = true
      end
    end
  
  end

  function TCPreset_Click(idx, row, col, dataindex, dtab)
  
    local page = ctlpage.activepage
    local x = obj.sections[5].x + ctlpage[page][idx].x
    local y = obj.sections[5].y + ctlpage[page][idx].y + ctlpage[page][idx].h
  
    local res = DataTab_Menu(dtab, x, y)
    if res > 0 then
      local didx = datatab[dtab][res]
      if lvar.TCPreset[didx] then
      
        lvar.buttdata['tcpreset'] = didx
        
        lvar.buttdata['tc_digits'] = lvar.TCPreset[didx].digits
  
        lvar.buttdata['tc_digit1'] = lvar.TCPreset[didx].d1
        lvar.buttdata['tc_digit2'] = lvar.TCPreset[didx].d2
        lvar.buttdata['tc_digit3'] = lvar.TCPreset[didx].d3
        lvar.buttdata['tc_digit4'] = lvar.TCPreset[didx].d4
        lvar.buttdata['tc_digit5'] = lvar.TCPreset[didx].d5
        lvar.buttdata['tc_digit6'] = lvar.TCPreset[didx].d6
        lvar.buttdata['tc_digit7'] = lvar.TCPreset[didx].d7
        lvar.buttdata['tc_digit8'] = lvar.TCPreset[didx].d8
        lvar.buttdata['tc_digit9'] = lvar.TCPreset[didx].d9
        lvar.buttdata['tc_digit10'] = lvar.TCPreset[didx].d10
        lvar.buttdata['tc_digit11'] = lvar.TCPreset[didx].d11
        lvar.buttdata['tc_digit12'] = lvar.TCPreset[didx].d12
        lvar.buttdata['tc_digit13'] = lvar.TCPreset[didx].d13
        lvar.buttdata['tc_digit14'] = lvar.TCPreset[didx].d14
        lvar.buttdata['tc_digit15'] = lvar.TCPreset[didx].d15
        lvar.buttdata['tc_digit16'] = lvar.TCPreset[didx].d16

        lvar.buttdata['tc_timeformat_hours'] = lvar.TCPreset[didx].tf_hours
        lvar.buttdata['tc_timeformat_mins'] = lvar.TCPreset[didx].tf_mins
        lvar.buttdata['tc_timeformat_secs'] = lvar.TCPreset[didx].tf_secs
        lvar.buttdata['tc_timeformat_frames'] = lvar.TCPreset[didx].tf_frames
        lvar.buttdata['tc_beatsformat_bars'] = lvar.TCPreset[didx].bf_bars
        lvar.buttdata['tc_beatsformat_beats'] = lvar.TCPreset[didx].bf_beats
        lvar.buttdata['tc_beatsformat_sub'] = lvar.TCPreset[didx].bf_sub
        lvar.buttdata['tc_beatsformat_frames'] = lvar.TCPreset[didx].bf_frames

        lvar.buttdata['tc_beatsled_note'] = lvar.TCPreset[didx].bled_note
        lvar.buttdata['tc_beatsled_on'] = lvar.TCPreset[didx].bled_on
        lvar.buttdata['tc_beatsled_off'] = lvar.TCPreset[didx].bled_off
        lvar.buttdata['tc_timeled_note'] = lvar.TCPreset[didx].tled_note
        lvar.buttdata['tc_timeled_on'] = lvar.TCPreset[didx].tled_on
        lvar.buttdata['tc_timeled_off'] = lvar.TCPreset[didx].tled_off
        
        lvar.buttdata['tc_char0'] = lvar.TCPreset[didx].char0
        lvar.buttdata['tc_char1'] = lvar.TCPreset[didx].char1
        lvar.buttdata['tc_char2'] = lvar.TCPreset[didx].char2
        lvar.buttdata['tc_char3'] = lvar.TCPreset[didx].char3
        lvar.buttdata['tc_char4'] = lvar.TCPreset[didx].char4
        lvar.buttdata['tc_char5'] = lvar.TCPreset[didx].char5
        lvar.buttdata['tc_char6'] = lvar.TCPreset[didx].char6
        lvar.buttdata['tc_char7'] = lvar.TCPreset[didx].char7
        lvar.buttdata['tc_char8'] = lvar.TCPreset[didx].char8
        lvar.buttdata['tc_char9'] = lvar.TCPreset[didx].char9
        lvar.buttdata['tc_char10'] = lvar.TCPreset[didx].char10
        lvar.buttdata['tc_char11'] = lvar.TCPreset[didx].char11
        lvar.buttdata['tc_char12'] = lvar.TCPreset[didx].char12
        lvar.buttdata['tc_char13'] = lvar.TCPreset[didx].char13
        lvar.buttdata['tc_char14'] = lvar.TCPreset[didx].char14
        lvar.buttdata['tc_char15'] = lvar.TCPreset[didx].char15
        lvar.buttdata['tc_char16'] = lvar.TCPreset[didx].char16
        
        lvar.buttdata['tc_asscc1'] = lvar.TCPreset[didx].tc_asscc1
        lvar.buttdata['tc_asscc1d'] = lvar.TCPreset[didx].tc_asscc1d
        lvar.buttdata['tc_asscc2'] = lvar.TCPreset[didx].tc_asscc2
        lvar.buttdata['tc_asscc2d'] = lvar.TCPreset[didx].tc_asscc2d
        
        update_cbox = true
      end
    end
  
  end
  
  function SetButtSel(id)

    lvar.buttsel = {}
    lvar.buttsel_idx = {}
  
    if id then
      lvar.buttsel[1] = id
      lvar.buttsel_idx[id] = 1
    end
    update_gfx = true
    
  end
  
  function TCPreset_Setup()

    lvar.TCPreset = {}
    lvar.TCPreset['None'] = {}
    lvar.TCPreset['None'].digits = nil
    lvar.TCPreset['None'].d1 = nil
    lvar.TCPreset['None'].d2 = nil
    lvar.TCPreset['None'].d3 = nil
    lvar.TCPreset['None'].d4 = nil
    lvar.TCPreset['None'].d5 = nil
    lvar.TCPreset['None'].d6 = nil
    lvar.TCPreset['None'].d7 = nil
    lvar.TCPreset['None'].d8 = nil
    lvar.TCPreset['None'].d9 = nil
    lvar.TCPreset['None'].d10 = nil
    lvar.TCPreset['None'].d11 = nil
    lvar.TCPreset['None'].d12 = nil
    lvar.TCPreset['None'].d13 = nil
    lvar.TCPreset['None'].d14 = nil
    lvar.TCPreset['None'].d15 = nil
    lvar.TCPreset['None'].d16 = nil
    lvar.TCPreset['None'].bf_bars = nil
    lvar.TCPreset['None'].bf_beats = nil
    lvar.TCPreset['None'].bf_sub = nil
    lvar.TCPreset['None'].bf_frames = nil
    lvar.TCPreset['None'].tf_hours = nil
    lvar.TCPreset['None'].tf_mins = nil
    lvar.TCPreset['None'].tf_secs = nil
    lvar.TCPreset['None'].tf_frames = nil
    lvar.TCPreset['None'].bled_note = nil
    lvar.TCPreset['None'].bled_on = nil
    lvar.TCPreset['None'].bled_off = nil
    lvar.TCPreset['None'].tled_note = nil
    lvar.TCPreset['None'].tled_on = nil
    lvar.TCPreset['None'].tled_off = nil
    lvar.TCPreset['None'].char0 = nil
    lvar.TCPreset['None'].char1 = nil
    lvar.TCPreset['None'].char2 = nil
    lvar.TCPreset['None'].char3 = nil
    lvar.TCPreset['None'].char4 = nil
    lvar.TCPreset['None'].char5 = nil
    lvar.TCPreset['None'].char6 = nil
    lvar.TCPreset['None'].char7 = nil
    lvar.TCPreset['None'].char8 = nil
    lvar.TCPreset['None'].char9 = nil
    lvar.TCPreset['None'].char10 = nil
    lvar.TCPreset['None'].char11 = nil
    lvar.TCPreset['None'].tc_asscc1 = nil
    lvar.TCPreset['None'].tc_asscc1d = nil
    lvar.TCPreset['None'].tc_asscc2 = nil
    lvar.TCPreset['None'].tc_asscc2d = nil
    
    lvar.TCPreset['XTouch XCTL'] = {}
    lvar.TCPreset['XTouch XCTL'].digits = 10
    lvar.TCPreset['XTouch XCTL'].d1 = 98
    lvar.TCPreset['XTouch XCTL'].d2 = 99
    lvar.TCPreset['XTouch XCTL'].d3 = 116
    lvar.TCPreset['XTouch XCTL'].d4 = 101
    lvar.TCPreset['XTouch XCTL'].d5 = 118
    lvar.TCPreset['XTouch XCTL'].d6 = 103
    lvar.TCPreset['XTouch XCTL'].d7 = 104
    lvar.TCPreset['XTouch XCTL'].d8 = 105
    lvar.TCPreset['XTouch XCTL'].d9 = 106
    lvar.TCPreset['XTouch XCTL'].d10 = 107
    lvar.TCPreset['XTouch XCTL'].d11 = nil
    lvar.TCPreset['XTouch XCTL'].d12 = nil
    lvar.TCPreset['XTouch XCTL'].d13 = nil
    lvar.TCPreset['XTouch XCTL'].d14 = nil
    lvar.TCPreset['XTouch XCTL'].d15 = nil
    lvar.TCPreset['XTouch XCTL'].d16 = nil
    lvar.TCPreset['XTouch XCTL'].bf_bars = 3
    lvar.TCPreset['XTouch XCTL'].bf_beats = 2
    lvar.TCPreset['XTouch XCTL'].bf_sub = 2
    lvar.TCPreset['XTouch XCTL'].bf_frames = 3
    lvar.TCPreset['XTouch XCTL'].tf_hours = 3
    lvar.TCPreset['XTouch XCTL'].tf_mins = 2
    lvar.TCPreset['XTouch XCTL'].tf_secs = 2
    lvar.TCPreset['XTouch XCTL'].tf_frames = 3
    lvar.TCPreset['XTouch XCTL'].bled_note = 114
    lvar.TCPreset['XTouch XCTL'].bled_on = 127
    lvar.TCPreset['XTouch XCTL'].bled_off = 0
    lvar.TCPreset['XTouch XCTL'].tled_note = 113
    lvar.TCPreset['XTouch XCTL'].tled_on = 127
    lvar.TCPreset['XTouch XCTL'].tled_off = 0
    lvar.TCPreset['XTouch XCTL'].char0 = 63
    lvar.TCPreset['XTouch XCTL'].char1 = 6
    lvar.TCPreset['XTouch XCTL'].char2 = 91
    lvar.TCPreset['XTouch XCTL'].char3 = 79
    lvar.TCPreset['XTouch XCTL'].char4 = 102
    lvar.TCPreset['XTouch XCTL'].char5 = 109
    lvar.TCPreset['XTouch XCTL'].char6 = 124
    lvar.TCPreset['XTouch XCTL'].char7 = 7
    lvar.TCPreset['XTouch XCTL'].char8 = 127
    lvar.TCPreset['XTouch XCTL'].char9 = 111
    lvar.TCPreset['XTouch XCTL'].char10 = 0
    lvar.TCPreset['XTouch XCTL'].char11 = 64
    lvar.TCPreset['XTouch XCTL'].char12 = 94
    lvar.TCPreset['XTouch XCTL'].char13 = 113
    lvar.TCPreset['XTouch XCTL'].char14 = 61
    lvar.TCPreset['XTouch XCTL'].char15 = 56
    lvar.TCPreset['XTouch XCTL'].char16 = 115
    lvar.TCPreset['XTouch XCTL'].tc_asscc1 = 96
    lvar.TCPreset['XTouch XCTL'].tc_asscc1d = 112
    lvar.TCPreset['XTouch XCTL'].tc_asscc2 = 97
    lvar.TCPreset['XTouch XCTL'].tc_asscc2d = 113

  end
  
  function SSPreset_Setup()
  
    lvar.SSPreset = {}
    lvar.SSPreset['None'] = {}
    lvar.SSPreset['None'].cmode = nil
    lvar.SSPreset['None'][1] = nil
    lvar.SSPreset['None'][2] = nil
    lvar.SSPreset['None'][3] = nil
    lvar.SSPreset['None'][4] = nil
    lvar.SSPreset['None'][5] = nil
    lvar.SSPreset['None'][6] = nil
    lvar.SSPreset['None'][7] = nil
    lvar.SSPreset['None'][8] = nil

    lvar.SSPreset['XTouch XCTL'] = {}
    lvar.SSPreset['XTouch XCTL'].cmode = 2
    lvar.SSPreset['XTouch XCTL'][1] = '0xF0 0x00 0x00 0x66 0x58 0x20 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][2] = '0xF0 0x00 0x00 0x66 0x58 0x21 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][3] = '0xF0 0x00 0x00 0x66 0x58 0x22 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][4] = '0xF0 0x00 0x00 0x66 0x58 0x23 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][5] = '0xF0 0x00 0x00 0x66 0x58 0x24 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][6] = '0xF0 0x00 0x00 0x66 0x58 0x25 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][7] = '0xF0 0x00 0x00 0x66 0x58 0x26 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch XCTL'][8] = '0xF0 0x00 0x00 0x66 0x58 0x27 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'

    lvar.SSPreset['XTouch Extender CTRLREL'] = {}
    lvar.SSPreset['XTouch Extender CTRLREL'].cmode = 1
    lvar.SSPreset['XTouch Extender CTRLREL'][1] = '0xF0 0x00 0x20 0x32 0x15 0x4C 0 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][2] = '0xF0 0x00 0x20 0x32 0x15 0x4C 1 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][3] = '0xF0 0x00 0x20 0x32 0x15 0x4C 2 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][4] = '0xF0 0x00 0x20 0x32 0x15 0x4C 3 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][5] = '0xF0 0x00 0x20 0x32 0x15 0x4C 4 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][6] = '0xF0 0x00 0x20 0x32 0x15 0x4C 5 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][7] = '0xF0 0x00 0x20 0x32 0x15 0x4C 6 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['XTouch Extender CTRLREL'][8] = '0xF0 0x00 0x20 0x32 0x15 0x4C 7 <COLOR> <C01> <C02> <C03> <C04> <C05> <C06> <C07> <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'

    lvar.SSPreset['Mackie Universal'] = {}
    lvar.SSPreset['Mackie Universal'].cmode = nil
    lvar.SSPreset['Mackie Universal'][1] = '0xF0 0x00 0x00 0x66 0x14 0x12 0 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 56 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][2] = '0xF0 0x00 0x00 0x66 0x14 0x12 7 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 63 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][3] = '0xF0 0x00 0x00 0x66 0x14 0x12 14 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 70 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][4] = '0xF0 0x00 0x00 0x66 0x14 0x12 21 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 77 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][5] = '0xF0 0x00 0x00 0x66 0x14 0x12 28 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 84 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][6] = '0xF0 0x00 0x00 0x66 0x14 0x12 35 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 91 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][7] = '0xF0 0x00 0x00 0x66 0x14 0x12 42 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 98 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Universal'][8] = '0xF0 0x00 0x00 0x66 0x14 0x12 49 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x14 0x12 105 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'

    lvar.SSPreset['Mackie Extender'] = {}
    lvar.SSPreset['Mackie Extender'].cmode = nil
    lvar.SSPreset['Mackie Extender'][1] = '0xF0 0x00 0x00 0x66 0x15 0x12 0 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 56 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][2] = '0xF0 0x00 0x00 0x66 0x15 0x12 7 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 63 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][3] = '0xF0 0x00 0x00 0x66 0x15 0x12 14 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 70 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][4] = '0xF0 0x00 0x00 0x66 0x15 0x12 21 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 77 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][5] = '0xF0 0x00 0x00 0x66 0x15 0x12 28 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 84 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][6] = '0xF0 0x00 0x00 0x66 0x15 0x12 35 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 91 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][7] = '0xF0 0x00 0x00 0x66 0x15 0x12 42 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 98 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
    lvar.SSPreset['Mackie Extender'][8] = '0xF0 0x00 0x00 0x66 0x15 0x12 49 <C01> <C02> <C03> <C04> <C05> <C06> <C07> 0xF7 0xF0 0x00 0x00 0x66 0x15 0x12 105 <C08> <C09> <C10> <C11> <C12> <C13> <C14> 0xF7'
  
  end
  
  ----------------------------------------------------------
  
  function round(v)
    return math.floor(v+0.5)
  end

  function round2(v,d)
    local dp = 10^(d or 0)
    return math.floor(v*dp+0.5)/dp
  end
  
  function GetWindowHwnd(title, exact)
    return reaper.JS_Window_Find(title, exact)
  end
  
  ------------------------------------------- --
  -- Pickle.lua
  -- A table serialization utility for lua
  -- Steve Dekorte, http://www.dekorte.com, Apr 2000
  -- (updated for Lua 5.3 by me)
  -- Freeware
  ----------------------------------------------
  
  function pickle(t)
  return Pickle:clone():pickle_(t)
  end
  
  Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end
  }
  
  function Pickle:pickle_(root)
  if type(root) ~= "table" then
  error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""
  
  while #self._refToTable > savecount do
  savecount = savecount + 1
  local t = self._refToTable[savecount]
  s = s.."{\n"
  
  for i, v in pairs(t) do
  s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
  end
  s = s.."},\n"
  
  end
  return string.format("{%s}", s)
  end
  
  function Pickle:value_(v)
  local vtype = type(v)
  if vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else error("pickle a "..type(v).." is not supported")
  end
  end
  
  function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then
  if t == self then error("can't pickle the pickle class") end
  table.insert(self._refToTable, t)
  ref = #self._refToTable
  self._tableToRef[t] = ref
  end
  return ref
  end
  
  ----------------------------------------------
  -- unpickle
  ----------------------------------------------
  
  function unpickle(s)
  if s == nil or s == '' then return end
  if type(s) ~= "string" then
  error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = load("return "..s)
  if gentables then
    local tables = gentables()
  
    if tables then
      for tnum = 1, #tables do
      local t = tables[tnum]
      local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
      for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
      end
      end
      return tables[1]
    end
  else
    --error
  end
  end
  
  ------------------------------------------------------------
  
  ----------------------------------------------------------
  
  function GetGUI_vars()
    gfx.mode = 0
    
    local gui = {}
      gui.w = 1020
      gui.h = 1000
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

  function table.copy(t)
    if t == nil then return nil end
    local u = { }
    for k, v in pairs(t) do u[k] = v end
    return setmetatable(u, getmetatable(t))
  end
  
  function table.deepcopy(o, seen)
    seen = seen or {}
    if o == nil then return nil end
    if seen[o] then return seen[o] end
  
  
    local no = {}
    seen[o] = no
    setmetatable(no, table.deepcopy(getmetatable(o), seen))
  
    for k, v in next, o, nil do
      k = (type(k) == 'table') and table.deepcopy(k, seen) or k
      v = (type(v) == 'table') and table.deepcopy(v, seen) or v
      no[k] = v
    end
    return no
  end
  
  function GetObjects()
  
    local obj = {}
    obj.sections = {}
    obj.sections[1] = {x = 0, y = 0, w = gui.w, h = gfx1.main_h-340}
    if lvar.imageidx then
      if (lvar.imagefn or '') ~= '' then
        obj.sections[2] = {x = 0, y = 0}
        LoadControllerImage(obj, true)
      else
        obj.sections[2] = {x = 0, y = 0}
        SetUpCanvas(obj, lvar.imagew, lvar.imageh)
      end
    else
      obj.sections[2] = {x = 0, y = 0, w = gui.w, h = gfx1.main_h-340} --updated to image position
    end
    obj.sections[3] = {x = 10, y = 620, w = lvar.zoombox*4, h = lvar.zoombox*4}
    obj = SetObj4(obj)
    obj.sections[5] = {x = 0, y = obj.sections[1].y + obj.sections[1].h, w = gui.w, h = gui.h-obj.sections[1].y + obj.sections[1].h}
    
    local bw = 60
    local bh = 22

    obj.sections[10] = {x = obj.sections[1].x+obj.sections[1].w - bw, y = 0, w = bw, h = bh}
    obj.sections[11] = {x = obj.sections[10].x -140 - bw*2, y = 0, w = bw*2, h = bh}
    obj.sections[12] = {x = 10, y = 0, w = 150, h = bh}
    
    --obj.sections[13] = {x = 10, y = 250, w = 150, h = bh*2}

    obj.sections[14] = {x = obj.sections[1].x+obj.sections[1].w - 420, y = 0, w = 30, h = bh}
    
    --learn
    local lw = 340
    local llw = 204
    local lh = 145
    obj.sections[100] = {x = gfx.w/2 - lw/2, y = gfx.h/2 - lh/2, w = lw, h = lh}
    obj.sections[101] = {x = 68, y = 65, w = 204, h = lh-65}
    obj.sections[102] = {x = 140, y = 10, w = 190, h = 22}
    obj.sections[103] = {x = 140, y = 33, w = 190, h = 22}
    
    obj.sections[1000] = {x = 0, y = 0, w = gui.w, h = gfx1.main_h}

    return obj
    
  end

  function SetObj4(obj)
    obj.sections[4] = table.copy(obj.sections[2])
    return obj
  end
  
  ----------------------------------------------------------

  function init()
  
    local x, y = GES('win_x',true), GES('win_y',true)
    local ww, wh = GES('win_w',true), GES('win_h',true)
    --DBG(ww..'  '..wh)
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
  
    SaveData(paths.CMC..'last.cmc')
    SaveSettings()      
    
    MLrn_SetUp(true)
    
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
      reaper.SetExtState(SCRIPT,'win_h',gfx1.main_h or 200,true)
    end
  
  end

  function F_limit(val,min,max)
      if val == nil or min == nil or max == nil then return end
      local val_out = val
      if val < min then val_out = min end
      if val > max then val_out = max end
      return val_out
    end   
  ------------------------------------------------------------
    
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

  function MOUSE_over(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      then
     return true 
    end 
  end
  
  ----------------------------------------------------------

  function f_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    lvar.selcol = s
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  
  ------------------------------------------------------------
    
  function GUI_text(gui, xywh, text, flags, col, tsz, justifyiftoobig, font, tflags)
  
    if col == nil then col = '205 205 205' end
    if tsz == nil then tsz = 0 end
    
    f_Get_SSV(col)  
    gfx.a = 1
    local tf
    if tflags then
      tf = 0
      for i = 1, string.len(tflags) do
        tf = tf + ((string.byte(string.sub(tflags,i,i)) or 0)*(256^(i-1)))
      end
    end
    gfx.setfont(1, font or gui.fontname, gui.fontsz+tsz, tf)
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
  
  function GUI_text_fit(gui, xywh, text, flags, col, tsz, font, vertical)
  
    if col == nil then col = '205 205 205' end
    if tsz == nil then tsz = 0 end
    
    f_Get_SSV(col)  
    gfx.a = 1 
    local fit = false
    
    local testw = xywh.w
    local tflags = ''
    if vertical then
      testw = xywh.h
      tflags = string.byte('z')
    end
    
    while not fit and gui.fontsz+tsz > 8 do
      gfx.setfont(1, font or gui.fontname, gui.fontsz+tsz)
      local tw = gfx.measurestr(text)
      if tw > testw then
        tsz = tsz - 8
      else
        fit = true
      end
    end

    if fit then
      gfx.setfont(1, font or gui.fontname, gui.fontsz+tsz, tflags)
      
      gfx.x, gfx.y = xywh.x,xywh.y
      local r, b
      r, b = xywh.x+xywh.w, xywh.y+xywh.h 
      
      gfx.drawstr(text, flags, r, b)
    end
    
  end
  
  function GUI_DrawButton(gui, xywh, txt, bcol, tcol, val, tsz, flags, txt2, padx, justifyiftoobig, font, tflags)
  
    f_Get_SSV(bcol)
    gfx.rect(xywh.x,
             xywh.y,
             xywh.w,
             xywh.h, 1)
    local xywh2 = {x = xywh.x+(padx or 0), y = xywh.y, w = xywh.w-(padx or 0)*2, h = xywh.h}
    GUI_text(gui, xywh2, txt, flags or 5, tcol, tsz, justifyiftoobig, font)
    if txt2 then
      xywh2.x = xywh2.x - 200
      xywh2.w = 190
      --f_Get_SSV(lvar.blblcol)
      GUI_text(gui, xywh2, txt2, 6, lvar.blblcol, 1, nil, nil, tflags)
    end
        
  end
  
  ------------------------------------------------------------

  function GUI_draw()
  
    if resize_display then
          
      gfx.setimgdim(1, -1, -1)  
      gfx.setimgdim(1, gui.w,obj.sections[1].h+10)
      
      gfx.setimgdim(2, -1, -1)  
      gfx.setimgdim(2, gui.w,obj.sections[5].h)

      gfx.setimgdim(3, -1, -1)  
      gfx.setimgdim(3, obj.sections[100].w, obj.sections[100].h)
      
    end

    gfx.dest = 1
    gfx.mode = 2

    local xoff = lvar.xoff or 0
    local yoff = lvar.yoff or 0
    
    if update_gfx then
      gfx.a = 1

      --[[f_Get_SSV('32 32 32')
      gfx.rect(0,
               0,
               10,
               obj.sections[1].h+10, 1)
      gfx.rect(10,
               0,
               obj.sections[1].w,
               10, 1)
      gfx.rect(obj.sections[1].w+10,
               0,
               10,
               obj.sections[1].h+10, 1)]]
    
      f_Get_SSV('0 0 0')
      gfx.rect(0,
               0,
               obj.sections[1].w,
               obj.sections[1].h, 1) 
      
    
      if lvar.imageidx then
        local iw, ih = gfx.getimgdim(lvar.imageidx)
        --local iww, ihh = iw, ih
        local scale = lvar.imagescale
        if lvar.zoomcentre --[[and lvar.imagescale2 < lvar.zoomfactor --[ [1]] then
          --local x0 =
          iw = math.min(iw, obj.sections[1].w)
          ih = math.min(ih, obj.sections[1].h)
          local xx, yy
          
          if lvar.shift2 then
            xx = (lvar.shift2.x + lvar.shift2.dx) 
            yy = (lvar.shift2.y + lvar.shift2.dy)
          else
            xx = (mouse.mx - obj.sections[4].x)/lvar.imagescale2 --* 2
            yy = (mouse.my - obj.sections[4].y)/lvar.imagescale2 --* 2
          end
          
          --xx = F_limit(xx, 0, iww)
          
          xx = (xx - obj.sections[1].w/(2*lvar.imagescale)) 
          yy = (yy - obj.sections[1].h/(2*lvar.imagescale))
          xoff = xx*lvar.imagescale
          yoff = yy*lvar.imagescale
          --[[if iw < obj.sections[1].w then
            xoff = xoff + (obj.sections[1].w-iw)*lvar.imagescale
          end]]
          lvar.xoff = xoff
          lvar.yoff = yoff
          gfx.a = 1
          gfx.blit(lvar.imageidx, scale, 0, 
                   xx, yy, --[[math.min(iw, ]]obj.sections[1].w/lvar.imagescale--[[)]], --[[math.min(ih, ]]obj.sections[1].h/lvar.imagescale--[[)]],
                   obj.sections[1].x, obj.sections[1].y) --, obj.sections[2].w, obj.sections[2].h)
          f_Get_SSV('255 0 0')
          local xxx = obj.sections[4].x+obj.sections[4].w/2
          local yyy = obj.sections[4].y+obj.sections[4].h/2
          gfx.line(xxx-10,yyy,xxx+10,yyy)
          gfx.line(xxx,yyy-10,xxx,yyy+10)
          
        else
          gfx.a = 1
          gfx.blit(lvar.imageidx, scale, 0, 
                   0, 0, iw, ih,
                   obj.sections[2].x, obj.sections[2].y) --, obj.sections[2].w, obj.sections[2].h)
          
          f_Get_SSV('128 128 128')
          gfx.rect(obj.sections[2].x,
                   obj.sections[2].y,
                   obj.sections[2].w,
                   obj.sections[2].h, 0) 
        end
        --DBG(lvar.imageidx..'  '..iw..'  '..ih..'  '..x..'  '..y)
      end
      
      --[[f_Get_SSV('64 64 64')
      gfx.rect(obj.sections[1].x,
               obj.sections[1].y,
               obj.sections[1].w,
               obj.sections[1].h, 0) ]]

      --[[f_Get_SSV('128 128 128')
      gfx.rect(obj.sections[2].x,
               obj.sections[2].y,
               obj.sections[2].w,
               obj.sections[2].h, 0) ]]
      
      for i = 1, #lvar.buttdata do
        local bd = lvar.buttdata[i]
        if bd.shape == 0 then
        
          if lvar.move_delay and lvar.move_delay.bd and lvar.move_delay.bd[i] then
            f_Get_SSV('128 255 128')
          elseif lvar.buttsel_idx[i] then
            if lvar.buttsel_idx[i] == 1 then
              f_Get_SSV('255 255 255')
            else
              f_Get_SSV('160 160 255')
            end
          elseif lvar.buttsel_err_idx and lvar.buttsel_err_idx[i] then
            f_Get_SSV('255 0 0')
          else
            f_Get_SSV('255 128 128')
          end
          local xx, yy
          if lvar.zoomcentre then
            xx = round(bd.x*lvar.imagescale+obj.sections[1].x)
            yy = round(bd.y*lvar.imagescale+obj.sections[1].y)
          else
            xx = round(bd.x*lvar.imagescale+obj.sections[2].x)
            yy = round(bd.y*lvar.imagescale+obj.sections[2].y)
          end
          gfx.rect(xx-xoff,
                   yy-yoff,
                   math.ceil(bd.w*lvar.imagescale),
                   math.ceil(bd.h*lvar.imagescale),0)
          
          local pad = 5
          local xywh = {x = xx-xoff + pad, y = yy-yoff + pad, w = math.ceil(bd.w*lvar.imagescale) - pad*2, h = math.ceil(bd.h*lvar.imagescale) - pad*2}
          local colt = lvar.selcol
          
          if (bd.crop_l or 0) ~= 0 or (bd.crop_r or 0) ~= 0 or (bd.crop_t or 0) ~= 0 or (bd.crop_b or 0) ~= 0 then
            local xx, yy, ww, hh
            if lvar.zoomcentre then
              xx = round((bd.x+(bd.crop_l or 0))*lvar.imagescale+obj.sections[1].x)
              yy = round((bd.y+(bd.crop_t or 0))*lvar.imagescale+obj.sections[1].y)
              ww = round((bd.w - (bd.crop_l or 0) + (bd.crop_r or 0))*lvar.imagescale)
              hh = round((bd.h - (bd.crop_t or 0) + (bd.crop_b or 0))*lvar.imagescale)
            else
              xx = round((bd.x+(bd.crop_l or 0))*lvar.imagescale+obj.sections[2].x)
              yy = round((bd.y+(bd.crop_t or 0))*lvar.imagescale+obj.sections[2].y)
              ww = round((bd.w - (bd.crop_l or 0) + (bd.crop_r or 0))*lvar.imagescale)
              hh = round((bd.h - (bd.crop_t or 0) + (bd.crop_b or 0))*lvar.imagescale)
            end
            f_Get_SSV('0 196 255')
            gfx.rect(xx-xoff,
                     yy-yoff,
                     ww,
                     hh,0)
          end
          if xywh.w >= xywh.h then
            --horiz
            GUI_text_fit(gui,xywh,bd.shortname or bd.name or '',5,colt,2,nil,nil)
          else
            --vert
            GUI_text_fit(gui,xywh,bd.shortname or bd.name or '',5,colt,2,nil,true)
          end
        
        elseif bd.shape == 1 then
        
          if lvar.move_delay and lvar.move_delay.bd and lvar.move_delay.bd[i] then
            f_Get_SSV('128 255 128')
          elseif lvar.buttsel_idx[i] then
            if lvar.buttsel_idx[i] == 1 then
              f_Get_SSV('255 255 255')
            else
              f_Get_SSV('160 160 255')
            end
          elseif lvar.buttsel_err_idx and lvar.buttsel_err_idx[i] then
            f_Get_SSV('255 0 0')
          else
            f_Get_SSV('255 128 128')
          end
          local xx, yy
          if lvar.zoomcentre then
            xx = round(bd.x*lvar.imagescale+obj.sections[1].x)
            yy = round(bd.y*lvar.imagescale+obj.sections[1].y)
          else
            xx = round(bd.x*lvar.imagescale+obj.sections[2].x)
            yy = round(bd.y*lvar.imagescale+obj.sections[2].y)
          end
          gfx.circle(xx-xoff, yy-yoff, bd.r*lvar.imagescale, 0, 1)
          local pad = 5
          local xywh = {x = xx-xoff - math.ceil(bd.r*lvar.imagescale) + pad, y = yy-yoff -10, w = math.ceil(bd.r*lvar.imagescale)*2 - pad*2, h = 20}
          local colt = lvar.selcol
          
          if (bd.crop_l or 0) ~= 0 or (bd.crop_t or 0) ~= 0 or (bd.crop_r or 0) ~= 0 then
            f_Get_SSV('0 196 255')
            xx = xx + (bd.crop_l or 0)*lvar.imagescale
            yy = yy + (bd.crop_t or 0)*lvar.imagescale
            gfx.circle(xx-xoff, yy-yoff, (bd.r+(bd.crop_r or 0))*lvar.imagescale, 0, 1)
          end
          
          GUI_text_fit(gui,xywh,bd.shortname or bd.name or '',5,colt,2,nil,nil)
        end

      end

    end

    if update_cbox then
      gfx.dest = 2
      f_Get_SSV('32 32 32')
      gfx.rect(0,
               0,
               obj.sections[5].w,
               obj.sections[5].h, 1)
    
      --zoom
      if lvar.rcz then
        GUI_DrawButton(gui, obj.sections[10], 'x'..string.format('%i',lvar.zoomfactor), '0 0 0', '205 205 205', true, 1, nil, 'Right-click zoom:')
      else
        GUI_DrawButton(gui, obj.sections[10], 'Off', '0 0 0', '205 205 205', true, 1, nil, 'Right-click zoom:')
      end
      GUI_DrawButton(gui, obj.sections[11], lvar.shapes[lvar.btype+1], '0 0 0', '205 205 205', true, 1, nil, 'Shape:')
      GUI_DrawButton(gui, obj.sections[14], lvar.adjustamt, '0 0 0', '205 205 205', true, 1, nil, 'Grid:')
      GUI_DrawButton(gui, obj.sections[12], 'File Menu', '0 0 0', '205 205 205', true, 1, nil)
      --GUI_DrawButton(gui, obj.sections[13], 'Create Map', '0 0 0', '205 205 205', true, 1, nil)
    
      GUI_DrawPage(gui, obj)
    
    end
    
    --if update_gfx then
      gfx.dest = -1
      gfx.mode = 0
      gfx.a = 1
      gfx.blit(1, 1, 0, 
        0,0, gui.w,obj.sections[1].h+10,
        0,0)
    --end

    if lvar.create_shape then
      local cs = lvar.create_shape
      if cs.shape == 0 then
        --rect
        if cs.x2 then
        
          gfx.a = 1
          f_Get_SSV('128 255 128')
          local x,x2,y,y2
          if cs.x2 > cs.x then
            x = cs.x*lvar.imagescale
            x2 = cs.x2*lvar.imagescale
          else
            x = cs.x2*lvar.imagescale
            x2 = cs.x*lvar.imagescale
          end
          if cs.y2 > cs.y then
            y = cs.y*lvar.imagescale
            y2 = cs.y2*lvar.imagescale
          else
            y = cs.y2*lvar.imagescale
            y2 = cs.y*lvar.imagescale
          end
          
          local xx, yy, ww, hh, box
          if lvar.zoomcentre --[[and lvar.imagescale2 < 1]] then
            xx = x + obj.sections[1].x
            yy = y + obj.sections[1].y
            box = obj.sections[1]
          else 
            xx = round(x+obj.sections[2].x)
            yy = round(y+obj.sections[2].y)
            box = obj.sections[2]
          end
          xx = xx-xoff
          yy = yy-yoff
          
          --local xx1, yy2, w, h = CheckBoundaries(box, xx,yy,math.ceil(x2-x),math.ceil(y2-y))
          
          gfx.rect(xx,
                   yy,
                   math.ceil(x2-x),--w,
                   math.ceil(y2-y),0)--,0)
        
        
        end
      
      elseif cs.shape == 1 then
        --circ
        if cs.x2 then
          local dx = (cs.x2*lvar.imagescale - cs.x*lvar.imagescale)^2
          local dy = (cs.y2*lvar.imagescale - cs.y*lvar.imagescale)^2
          local r = math.sqrt(dx + dy)
          
          local xx, yy, box
          if lvar.zoomcentre --[[and lvar.imagescale2 < 1]] then
            xx = cs.x*lvar.imagescale + obj.sections[1].x
            yy = cs.y*lvar.imagescale + obj.sections[1].y
            box = obj.sections[1]
          else 
            xx = round(cs.x*lvar.imagescale+obj.sections[2].x)
            yy = round(cs.y*lvar.imagescale+obj.sections[2].y)
            box = obj.sections[2]
          end
          xx = xx-xoff
          yy = yy-yoff
      
          gfx.a = 1
          f_Get_SSV('128 255 128')
          gfx.circle(xx, yy, r, 0, 1)
        end
        
      end
      
    end
    
    if lvar.midilearn then
      
      if update_lrn then
        gfx.dest = 3
        f_Get_SSV('16 16 16')
        gfx.rect(0,
                 0,
                 obj.sections[100].w,
                 obj.sections[100].h, 1)
        f_Get_SSV('205 205 205')
        gfx.rect(1,
                 1,
                 obj.sections[100].w-2,
                 obj.sections[100].h-2, 0)

        GUI_DrawButton(gui, obj.sections[102], lvar.buttdata.listenport or '', '0 0 0', '205 205 205', true, -4, nil, 'Listen Port:')
        GUI_DrawButton(gui, obj.sections[103], lvar.buttdata.handshakeport or '', '0 0 0', '205 205 205', true, -4, nil, 'Handshake Port:')

        local xywh1 = {x = obj.sections[101].x, y = obj.sections[101].y, w = 100, h = ctlpage.bh1}
        local xywh2 = {x = xywh1.x+xywh1.w+2, y = obj.sections[101].y, w = 50, h = ctlpage.bh1}
        local xywh3 = {x = xywh2.x+xywh2.w+2, y = obj.sections[101].y, w = 50, h = ctlpage.bh1}
        local cnt = math.floor(obj.sections[101].h / (ctlpage.bh1+2))
        
        for i = 1, cnt do
          local rec = lvar.ml_rec[#lvar.ml_rec-cnt+i]
          if rec then
            --local bc = '0 0 0'
            --local tc = '205 205 205'
            
            local bc = lvar.lrncol[rec.ltype].bg
            local tc = lvar.lrncol[rec.ltype].fg
            
            GUI_DrawButton(gui, xywh1, rec.ltype, bc, tc, true)
            GUI_DrawButton(gui, xywh2, string.format('%i',rec.chan), bc, tc, true)
            GUI_DrawButton(gui, xywh3, string.format('%i',rec.num), bc, tc, true)
            xywh1.y = xywh1.y + ctlpage.bh1 + 2
            xywh2.y = xywh1.y
            xywh3.y = xywh1.y
          end        
        end
      end
      
    end
    
    gfx.dest = -1
    gfx.mode = 0
    gfx.a = 1
    gfx.blit(2, 1, 0, 
      0,0, obj.sections[5].w,obj.sections[5].h,
      obj.sections[5].x,obj.sections[5].y)

    if lvar.midilearn then
    
      gfx.blit(3, 1, 0, 
        0,0, obj.sections[100].w,obj.sections[100].h,
        obj.sections[100].x,obj.sections[100].y)
    
    end
    
    if lvar.add_fader then
      f_Get_SSV('128 255 128')
      gfx.rect(lvar.add_fader.x, lvar.add_fader.y, lvar.add_fader.w*lvar.imagescale, lvar.add_fader.h*lvar.imagescale, 0)
    end

    if lvar.add_encoder then
      f_Get_SSV('128 255 128')
      gfx.circle(lvar.add_encoder.x, lvar.add_encoder.y, lvar.add_encoder.r*lvar.imagescale, 0, 1)
    end

    if lvar.add_button then
      f_Get_SSV('128 255 128')
      if lvar.btype == 0 then
        gfx.rect(lvar.add_button.x, lvar.add_button.y, lvar.add_button.r*lvar.imagescale, lvar.add_button.r*lvar.imagescale, 0)
      else
        gfx.circle(lvar.add_button.x, lvar.add_button.y, lvar.add_button.r*lvar.imagescale, 0, 1)
      end
    end
    
    --[[if MOUSE_over(obj.sections[2]) then
  
      local sz = lvar.zoombox
      local x, y
      if lvar.shift2 then
        x = (lvar.shift2.x + lvar.shift2.dx) - sz
        y = (lvar.shift2.y + lvar.shift2.dy) - sz
      else
        x = ((mouse.mx - obj.sections[2].x)/lvar.imagescale2) - sz
        y = ((mouse.my - obj.sections[2].y)/lvar.imagescale2) - sz
      end
      
      gfx.blit(lvar.imageidx, 1, 0, 
               x, y, sz*2+1, sz*2+1,
               obj.sections[3].x, obj.sections[3].y, obj.sections[3].w, obj.sections[3].h)
      
      if lvar.create_shape then
        f_Get_SSV('128 255 128')
      else
        f_Get_SSV('255 0 0')
      end
      local xxx = obj.sections[3].x + sz*2
      local yyy = obj.sections[3].y + sz*2
      gfx.line(xxx-10,yyy,xxx+10,yyy)
      gfx.line(xxx,yyy-10,xxx,yyy+10)
      
    end]]


    gfx.update()
    
    resize_display = false
    update_gfx = false
    update_cbox = false
    update_lrn = false
    
  end

  function GUI_DrawPage(gui, obj)

    for p = 1, #pages do
      if p ~= 3 then
        local cobj = pages[p]
        if p == ctlpage.activepage then
          GUI_DrawButton(gui, cobj, cobj.text, '205 205 205', '0 0 0', true, 1, nil)
        else
          GUI_DrawButton(gui, cobj, cobj.text, '0 0 0', '205 205 205', true, 1, nil)
        end
      end
    end

    local page = ctlpage.activepage
    if page == 9 then
    
      if ctlpage[page] then
        for c = 1, #ctlpage[page] do
          local cobj = ctlpage[page][c]
          local validx, val, val2
          if c <= 40 then
            validx = lvar.sorttab[lvar.sortsel][cobj.idx + lvar.sortoffs]
            if validx then
              val = lvar.buttdata[validx].name or 'Unnamed Control'
            end
          end
          if cobj.formatval then
            val2 = cobj.formatval(tonumber(val))
          end
          local txt = cobj.title
          if not cobj.valactive or cobj.valactive(ctlpage[page][c].idx) then
            local bg, fg = cobj.bgcol or '0 0 0', cobj.fgcol or '205 205 205'
            if lvar.sorttab_idx == (cobj.idx or math.huge)+lvar.sortoffs then
              bg, fg = '205 205 205', '0 0 0'
            end
            local tflags
            if cobj.compul then
              tflags = 'b'
            end
            GUI_DrawButton(gui, cobj, val2 or val or '', bg, fg, true, ctlpage[page][c].fontsz or 1, nil, cobj.title, 4, 4, cobj.font, tflags)
            if cobj.title_top then
              local xywh = {x=cobj.x,y=cobj.y-cobj.title_toph-2,w=cobj.w,h=cobj.title_toph}
              GUI_DrawButton(gui, xywh, cobj.title_top, '120 120 120', '0 0 0', true, (ctlpage[page][c].fontsz or 1)-2, nil)
            end
            if cobj.title_left then
              local xywh = {x=cobj.x-cobj.title_leftw-2,y=cobj.y,w=cobj.title_leftw,h=cobj.h}
              GUI_DrawButton(gui, xywh, cobj.title_left, '120 120 120', '0 0 0', true, (ctlpage[page][c].fontsz or 1)-2, nil)
            end
          end
        end
      end
    
    elseif page == 1 then

      local bsel = {}
      if lvar.buttsel[1] then
        bsel = lvar.buttdata[lvar.buttsel[1]]
      end
      if ctlpage[page] then
        for c = 1, #ctlpage[page] do
          local cobj = ctlpage[page][c]
          if lvar.buttsel[1] or cobj.alwaysshow then
            local val = bsel[cobj.dataindex..'_desc'] or bsel[cobj.dataindex] or ''
            local val2
            if cobj.formatval then
              val2 = cobj.formatval(tonumber(val))
            end
  
            local txt = cobj.title
            if cobj.formattitle then
              txt = cobj.formattitle()
            end
            if not cobj.valactive or cobj.valactive(lvar.buttsel[1]) then
              local bc, tc
              if cobj.colorfunc then
                local coltab = cobj.colorfunc(lvar.buttsel[1])
                if coltab then
                  bc, tc = coltab.bg, coltab.fg
                end
              end
              local tflags
              if cobj.compul then
                tflags = 'bu'
              end
              GUI_DrawButton(gui, cobj, val2 or val, bc or cobj.bgcol or '0 0 0', tc or cobj.fgcol or '205 205 205', true, (ctlpage[page][c].fontsz or 1), nil, txt, nil, nil, nil, tflags)
              if cobj.title_top then
                local xywh = {x=cobj.x,y=cobj.y-cobj.title_toph-2,w=cobj.w,h=cobj.title_toph}
                GUI_DrawButton(gui, xywh, cobj.title_top, '120 120 120', '0 0 0', true, (ctlpage[page][c].fontsz or 1)-2, nil)
              end
              if cobj.title_left then
                local xywh = {x=cobj.x-cobj.title_leftw-2,y=cobj.y,w=cobj.title_leftw,h=cobj.h}
                GUI_DrawButton(gui, xywh, cobj.title_left, '120 120 120', '0 0 0', true, (ctlpage[page][c].fontsz or 1)-2, nil)
              end
            end
          end
        end
      end
    
    elseif page > 1 then

      local bsel = lvar.buttdata
      if ctlpage[page] then
        for c = 1, #ctlpage[page] do
          local cobj = ctlpage[page][c]
          local val = bsel[cobj.dataindex2..'_desc'] or bsel[cobj.dataindex2] or ''
          local val2
          if cobj.formatval then
            val2 = cobj.formatval(tonumber(val))
          end
          local txt = cobj.title
          if not cobj.valactive or cobj.valactive(ctlpage[page][c].idx) then
            GUI_DrawButton(gui, cobj, val2 or val, cobj.bgcol or '0 0 0', cobj.fgcol or '205 205 205', true, ctlpage[page][c].fontsz or 1, nil, cobj.title, 4, 4, cobj.font)
            if cobj.title_top then
              local xywh = {x=cobj.x,y=cobj.y-cobj.title_toph-2,w=cobj.w,h=cobj.title_toph}
              GUI_DrawButton(gui, xywh, cobj.title_top, '120 120 120', '0 0 0', true, (ctlpage[page][c].fontsz or 1)-2, nil)
            end
            if cobj.title_left then
              local xywh = {x=cobj.x-cobj.title_leftw-2,y=cobj.y,w=cobj.title_leftw,h=cobj.h}
              GUI_DrawButton(gui, xywh, cobj.title_left, '120 120 120', '0 0 0', true, (ctlpage[page][c].fontsz or 1)-2, nil)
            end
          end
          
          --page specific
          if page == 4 then
          
            if lvar.cstrip and lvar.cstrip.sel and lvar.cstrip.sel == cobj.idx then
              f_Get_SSV('205 205 205')
              gfx.rect(cobj.x,cobj.y,cobj.w,cobj.h,0)
            end
          
          elseif page == 5 then
          
            if lvar.flip and lvar.flip.sel and lvar.flip.sel == cobj.idx then
              f_Get_SSV('205 205 205')
              gfx.rect(cobj.x,cobj.y,cobj.w,cobj.h,0)
            end
          end
        end
      end
    
    end
    
  end

  function CheckBoundaries(b, x, y, w, h)
  
    local x1, y1, w1, h1 = x,y,w,h
    if x < b.x then
      x1 = b.x
      w1 = w-(x1-x)
    end
    if y < b.y then
      y1 = b.y
      h1 = h-(y1-y)
    end
    if x+w > b.x+b.w then
      w1 = b.w-(x1-b.x)
    end
    if y+h > b.y+b.h then
      h1 = b.h-(y1-b.y)
    end
    --DBG('IY: '..y..'  OY: '..y1..'  IH: '..h..'  OH: '..h1)
    return x1, y1, w1, h1
  end
  
  function keypress(char)
    --DBG(char)
    if ctlpage.activepage == 9 then

      if lvar.sorttab_idx then
        if char == 30064 then --up
          if lvar.sorttab_idx > 1 then
  
            moved = {}
            for i = 1, #lvar.buttdata do
              moved[i] = i
            end
            
            moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]
            moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]
          
            local tmp = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]]
            lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]]
            lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx-1]] = tmp
            
            ButtMoved(moved)
            lvar.sorttab = SortButtData()
            lvar.sorttab_idx = lvar.sorttab_idx - 1
            update_gfx = true
            update_cbox = true
          
          end
        elseif char == 1685026670 then --down
          if lvar.sorttab_idx < #lvar.sorttab[lvar.sortsel] then
  
            moved = {}
            for i = 1, #lvar.buttdata do
              moved[i] = i
            end
            
            moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]
            moved[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]] = lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]
          
            local tmp = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]]
            lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx]] = lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]]
            lvar.buttdata[lvar.sorttab[lvar.sortsel][lvar.sorttab_idx+1]] = tmp
            
            ButtMoved(moved)
            lvar.sorttab = SortButtData()
            lvar.sorttab_idx = lvar.sorttab_idx + 1
            update_gfx = true
            update_cbox = true
          
          end
        end
      end
      
    else
      if ctlpage.activepage == 1 then
        if char == 1818584692 then --left
        
          if #lvar.buttsel > 0 then
            for b = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[b]]
              if bd then
                if not mouse.ctrl or not CropActive() then
                  if not mouse.shift then
                    bd.x = bd.x - lvar.adjustamt
                  else
                    if bd.shape == 0 then
                      bd.w = bd.w - lvar.adjustamt
                    elseif bd.shape == 1 then
                      bd.r = bd.r - lvar.adjustamt
                    end
                  end
                elseif CropActive() then
                  --crop area adjust
                  if bd.shape == 0 then
                    if not mouse.shift then
                      bd.crop_l = (bd.crop_l or 0) - lvar.adjustamt
                      bd.crop_r = (bd.crop_r or 0) - lvar.adjustamt
                    else
                      --bd.crop_l = bd.crop_l - lvar.adjustamt
                      bd.crop_r = (bd.crop_r or 0) - lvar.adjustamt
                    end
                  else
                    if not mouse.shift then
                      bd.crop_l = (bd.crop_l or 0) - lvar.adjustamt
                    else
                      bd.crop_r = (bd.crop_r or 0) - lvar.adjustamt
                    end
                  end
                  update_cbox = true
                end
              end
            end
          
            update_gfx = true
          end
        
        elseif char == 1919379572 then --right
        
          if #lvar.buttsel > 0 then
            for b = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[b]]
              if bd then
                if not mouse.ctrl or not CropActive() then
                  if not mouse.shift then
                    bd.x = bd.x + lvar.adjustamt
                  else
                    if bd.shape == 0 then
                      bd.w = bd.w + lvar.adjustamt
                    elseif bd.shape == 1 then
                      bd.r = bd.r + lvar.adjustamt
                    end
                  end
                elseif CropActive() then
                  --crop area adjust
                  if bd.shape == 0 then
                    if not mouse.shift then
                      bd.crop_l = (bd.crop_l or 0) + lvar.adjustamt
                      bd.crop_r = (bd.crop_r or 0) + lvar.adjustamt
                    else
                      --bd.crop_l = bd.crop_l + lvar.adjustamt
                      bd.crop_r = (bd.crop_r or 0) + lvar.adjustamt
                    end
                  else
                    if not mouse.shift then
                      bd.crop_l = (bd.crop_l or 0) + lvar.adjustamt
                    else
                      bd.crop_r = (bd.crop_r or 0) + lvar.adjustamt
                    end
                  end
                  update_cbox = true
                end
              end
            end
          
            update_gfx = true
          end
        
        elseif char == 30064 then --up
        
          if #lvar.buttsel > 0 then
            for b = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[b]]
              if bd then
                if not mouse.ctrl or not CropActive() then
                  if not mouse.shift then
                    bd.y = bd.y - lvar.adjustamt
                  else
                    if bd.shape == 0 then
                      bd.h = bd.h - lvar.adjustamt
                    elseif bd.shape == 1 then
                      bd.r = bd.r - lvar.adjustamt
                    end
                  end
                elseif CropActive() then
                  --crop area adjust
                  if bd.shape == 0 then
                    if not mouse.shift then
                      bd.crop_t = (bd.crop_t or 0) - lvar.adjustamt
                      bd.crop_b = (bd.crop_b or 0) - lvar.adjustamt
                    else
                      --bd.crop_l = bd.crop_l - lvar.adjustamt
                      bd.crop_b = (bd.crop_b or 0) - lvar.adjustamt
                    end
                  else
                    if not mouse.shift then
                      bd.crop_t = (bd.crop_t or 0) - lvar.adjustamt
                    else
                      bd.crop_r = (bd.crop_r or 0) - lvar.adjustamt
                    end
                  end
                  update_cbox = true
                end
              end
            end
          
            update_gfx = true
          end
        
        elseif char == 1685026670 then --down
        
          if #lvar.buttsel > 0 then
            for b = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[b]]
              if bd then
                if not mouse.ctrl or not CropActive() then
                  if not mouse.shift then
                    bd.y = bd.y + lvar.adjustamt
                  else
                    if bd.shape == 0 then
                      bd.h = bd.h + lvar.adjustamt
                    elseif bd.shape == 1 then
                      bd.r = bd.r + lvar.adjustamt
                    end
                  end
                elseif CropActive() then
                  --crop area adjust
                  if bd.shape == 0 then
                    if not mouse.shift then
                      bd.crop_t = (bd.crop_t or 0) + lvar.adjustamt
                      bd.crop_b = (bd.crop_b or 0) + lvar.adjustamt
                    else
                      --bd.crop_l = bd.crop_l - lvar.adjustamt
                      bd.crop_b = (bd.crop_b or 0) + lvar.adjustamt
                    end
                  else
                    if not mouse.shift then
                      bd.crop_t = (bd.crop_t or 0) + lvar.adjustamt
                    else
                      bd.crop_r = (bd.crop_r or 0) + lvar.adjustamt
                    end
                  end
                  update_cbox = true
                end
              end
            end
          
            update_gfx = true
          end
        
        elseif char == 4 or char == 260 then --ctrl+D duplicate sel
        
          if #lvar.buttsel > 0 then
        
            local x,y
            if lvar.shift2 then
              x = round(lvar.shift2.x + round(lvar.shift2.dx))
              y = round(lvar.shift2.y + round(lvar.shift2.dy))
            else
              x = (mouse.mx - obj.sections[2].x)/lvar.imagescale2
              y = (mouse.my - obj.sections[2].y)/lvar.imagescale2
            end
        
            local minx = math.huge
            local xoff, yoff = 0, 0
            for b = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[b]]
              if bd then
        
                if bd.x < minx then
                  xoff = x - bd.x
                  yoff = y - bd.y
                  minx = bd.x
                end
        
              end
            end
        
            for b = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[b]]
              if bd then
                local tab = table.copy(bd)
                tab.x = bd.x + xoff
                tab.y = bd.y + yoff
                
                local idx = #lvar.buttdata+1
                lvar.buttdata[idx] = tab
                
              end
            end
          
            update_gfx = true
          end
        
        elseif char == 115 then --s
        
          lvar.btype = 1-lvar.btype
          if lvar.create_shape then
            lvar.create_shape.shape = lvar.btype
          end
          update_cbox = true
    
        elseif char == 6579564 then --delete
        
          if #lvar.buttsel > 0 then
    
            local tab = {}
            for a, b in pairs(lvar.buttdata) do
              --retain non-button information
              if not tonumber(a) then
                tab[a] = b
              end
            end
            local moved = {}
            for b = 1, #lvar.buttdata do
              if not lvar.buttsel_idx[b] then
                local nidx = #tab + 1
                tab[nidx] = lvar.buttdata[b]
                moved[b] = nidx
              end
            end
            lvar.buttdata = tab
            lvar.buttsel = {}
            lvar.buttsel_idx = {}
            lvar.buttsel_err = {}
            lvar.buttsel_err_idx = {}
            
            ButtMoved(moved)
          end
          update_gfx = true
          update_cbox = true
          
        end
      end
    end
    
    if char >= 49 and char <= 57 then
      local p = char - 48
      ctlpage.activepage = p
      update_cbox = true
              
      --[[if p ~= 1 then
        lvar.buttsel = {}
        lvar.buttsel_idx = {}
      end]]
      update_gfx = true
      
      if p == 9 then
        lvar.sorttab = SortButtData()
        lvar.sortsel = 0
      end
    end
  end
  
  function ButtMoved(moved)
  
    local tab = table.deepcopy(lvar.buttdata)
    
    --flip
    for c = 1, 8 do
      for r = 1, 2 do
        local idx = 'flip_'..string.format('%i',r)..'_'..string.format('%i',c)
        local idx2 = lvar.buttdata[idx]
        tab[idx] = moved[tonumber(idx2)]
      end
    end
    
    --cstrips
    for c = 1, 8 do
      for r = 1, 10 do
        local idx = 'chanstrip_'..string.format('%i',r)..'_'..string.format('%i',c)
        local idx2 = lvar.buttdata[idx]
        tab[idx] = moved[tonumber(idx2)]
      end
    end
    
    lvar.buttdata = tab
  
  end
  
  ----------------------------------------------------------
  
  function ARun_CBox()
    
    local mx, my = mouse.mx, mouse.my
    mouse.mx = mx - obj.sections[5].x
    mouse.my = my - obj.sections[5].y
    
    if MOUSE_click(obj.sections[10]) then
      --Zoom
      local mstr = '1x|2x|3x|4x'
      gfx.x = obj.sections[5].x + obj.sections[10].x
      gfx.y = obj.sections[5].y + obj.sections[10].y + obj.sections[10].h
      local res = gfx.showmenu(mstr)
      if res > 0 then
        lvar.zoomfactor = res
        lvar.rcz = true
        update_gfx = true
        update_cbox = true
      end
    elseif MOUSE_click_RB(obj.sections[10]) then
      lvar.rcz = not lvar.rcz
      update_cbox = true
    elseif MOUSE_click(obj.sections[11]) then
      --Shape
      local mstr = ''
      for i = 1, #lvar.shapes do
        if i > 1 then
          mstr = mstr .. '|'
        end
        mstr = mstr .. lvar.shapes[i]
      end
      gfx.x = obj.sections[5].x + obj.sections[11].x
      gfx.y = obj.sections[5].y + obj.sections[11].y + obj.sections[11].h
      local res = gfx.showmenu(mstr)
      if res > 0 then
        lvar.btype = res-1
        update_cbox = true
      end

    elseif MOUSE_click(obj.sections[14]) then
      --Adjust
      local mstr = ''
      for i = 1, #lvar.adjust do
        if i > 1 then
          mstr = mstr .. '|'
        end
        mstr = mstr .. lvar.adjust[i]
      end
      gfx.x = obj.sections[5].x + obj.sections[14].x
      gfx.y = obj.sections[5].y + obj.sections[14].y + obj.sections[14].h
      local res = gfx.showmenu(mstr)
      if res > 0 then
        lvar.adjustamt = lvar.adjust[res]
        update_cbox = true
      end
      
    elseif MOUSE_click(obj.sections[12]) then
      
      FileMenu()

    --elseif MOUSE_click(obj.sections[13]) then
    
    --  CreateMap()
    
    else
      --Page Data
      ARun_Page(ctlpage.activepage)
    end
  
    mouse.mx, mouse.my = mx, my
  
  end
  
  function FileMenu()
  
    local mstr = 'Load Data||Save Data||New||Load Controller Image|Use Blank Canvas||Fit Controls To Canvas||Import Existing Map'
    gfx.x = obj.sections[5].x + obj.sections[12].x
    gfx.y = obj.sections[5].y + obj.sections[12].y + obj.sections[12].h
    local res = gfx.showmenu(mstr)
    if res > 0 then
  
      if res == 1 then
        --Load Data
        local retval, fn = reaper.JS_Dialog_BrowseForOpenFiles('Load Data', paths.CMC, '', 'CMC Files (.cmc)\0*.cmc', false)
        if retval then
          if reaper.file_exists(fn) then
            LoadData(fn)
            update_gfx = true
            update_cbox = true
          end
        end

      elseif res == 2 then
        local retval, fn = reaper.JS_Dialog_BrowseForSaveFile('Save Data', paths.CMC, '', 'CMC Files (.cmc)\0*.cmc')
        if retval == 1 then
          if not string.match(fn,'%.cmc$') then
            fn = fn..'.cmc'
          end
          SaveData(fn)
          update_gfx = true
          update_cbox = true
        end

      elseif res == 3 then

        ctlpage.activepage = 1
        lvar.sorttab = nil
        lvar.sorttab_idx = nil
        lvar.sortsel = nil
        lvar.imagefn = nil
        lvar.imageidx = nil
        lvar.buttdata = {}
        lvar.buttsel = {}
        lvar.buttsel_idx = {}
        lvar.buttsel_err = {}
        lvar.buttsel_err_idx = {}
        update_gfx = true
        update_cbox = true
        SetDefaults()
        SetUpCanvas(obj,obj.sections[1].w,obj.sections[1].h)
        
      elseif res == 4 then
        --Load image
        local retval, fn = reaper.JS_Dialog_BrowseForOpenFiles('Load Controller Image', paths.controllermaps, '', 'PNG Files (.png)\0*.png\0JPG Files (.jpg)\0*.jpg', false)
        if retval then
          if reaper.file_exists(fn) then
            lvar.imagefn = fn
            LoadControllerImage(obj)
          end
        end
      elseif res == 5 then
        --Blank canvas
        SetUpCanvas(obj)
      elseif res == 6 then
        FitControls()
      elseif res == 7 then
        --Import Existing Map
        local retval, fn = reaper.JS_Dialog_BrowseForOpenFiles('Import Existing Map', paths.controllermaps, '', 'SKCTLMAP Files (.skctlmap)\0*.skctlmap', false)
        if retval then
          if reaper.file_exists(fn) then
            Import(fn)
            update_gfx = true
            update_cbox = true
          end
        end
      end
    end
  end
  
  function FitControls()
  
    local l, t, r, b = math.huge, math.huge, 0, 0
    local bdata = lvar.buttdata
    for i = 1, #bdata do
      local bd = bdata[i]
      if bd.shape == 0 then
        l = math.min(bd.x, l)
        t = math.min(bd.y, t)
        r = math.max(bd.x+bd.w, r)
        b = math.max(bd.y+bd.h, b)
      else
        l = math.min(bd.x-bd.r, l)
        t = math.min(bd.y-bd.r, t)
        r = math.max(bd.x+bd.r, r)
        b = math.max(bd.y+bd.r, b)
      end
    end
    local cw, ch = gfx.getimgdim(99)
  
    local dw, dh = r-l, b-t
    local scale = math.min(cw/dw,ch/dh)

    for i = 1, #bdata do
      local bd = bdata[i]
      if bd.shape == 0 then
        bd.x = math.floor(bd.x * scale)
        bd.y = math.floor(bd.y * scale)
        bd.w = math.floor(bd.w * scale)
        bd.h = math.floor(bd.h * scale)
      else
        bd.x = math.floor(bd.x * scale)
        bd.y = math.floor(bd.y * scale)
        bd.r = math.floor(bd.r * scale)
      end
    end
    
    update_gfx = true
  end
  
  function SetUpCanvas(obj, w, h)
  
    if not w and not h then
      w, h = obj.sections[2].w,obj.sections[2].h
      local ret, vals = reaper.GetUserInputs('Set Up Canvas',2,'Width (pixels),Height (pixels)',w .. ',' .. h)
      w, h = string.match(vals,'(%d+),(%d+)')
      w = tonumber(w)
      h = tonumber(h)
    end
    
    if w and h then
      lvar.imageidx = 99
      lvar.imagefn = ''
      lvar.imagew = w
      lvar.imageh = h
      lvar.buttdata.imagew = w
      lvar.buttdata.imageh = h
      
      gfx.setimgdim(lvar.imageidx,w,h)
      gfx.dest = lvar.imageidx
      f_Get_SSV('0 0 0')
      gfx.rect(0,0,w,h,1)
      f_Get_SSV('64 64 64')
      gfx.rect(0,0,w,h,0)
      
      local scale_w, scale_h = 1, 1
      local pad = 0
      if w > obj.sections[1].w-pad then
        scale_w = (obj.sections[1].w-pad) / w
      end
      if h > (obj.sections[1].h-pad) then
        scale_h = (obj.sections[1].h-pad) / h
      end
      lvar.imagescale = round2(math.min(scale_w, scale_h, 1),2)
      lvar.imagescale2 = lvar.imagescale
      local x = math.floor(((obj.sections[1].w-pad) - w*lvar.imagescale)/2) + obj.sections[1].x + pad*0.5
      local y = math.floor(((obj.sections[1].h-pad) - h*lvar.imagescale)/2) + obj.sections[1].y + pad*0.5
      --DBG('X'..x..'  '..y..' '..w..' '..h)
      obj.sections[2] = {x = x, y = y, w = math.ceil(w*lvar.imagescale), h = math.ceil(h*lvar.imagescale)}
      obj = SetObj4(obj)
      update_gfx = true
      
      lvar.buttdata.image = ''
        
    end
  
  end
  
  function ARun_Page(page)

    for p = 1, #pages do
      if p ~= 3 and MOUSE_click(pages[p]) and p~=ctlpage.activepage then
        page = p
        ctlpage.activepage = p
        update_cbox = true
        
        --[[if p ~= 1 then
          lvar.buttsel = {}
          lvar.buttsel_idx = {}
        end]]
        update_gfx = true
        
        if p == 9 then
          lvar.sorttab, cancel = SortButtData(true)
          if not cancel then
            lvar.sortsel = 0
          else
            ctlpage.activepage = 1
          end
        end
        break
      end
    end
  
    if page == 9 then

      if ctlpage[page] then
        for c = 1, #ctlpage[page] do
          if MOUSE_over(ctlpage[page][c]) and ctlpage[page][c].wheelfunc then
            if gfx.mouse_wheel ~= 0 then
              local v = gfx.mouse_wheel / lvar.mwdiv
              local func = ctlpage[page][c].wheelfunc
              func(v)
              gfx.mouse_wheel = 0
            end
          end
          if MOUSE_click(ctlpage[page][c]) then
            local LClick = ctlpage[page][c].LClick
            if LClick then
              
              LClick(ctlpage[page][c].idx)
            
            end
          end
        end
      end
      
    elseif page ~= 1 or lvar.buttsel[1] then
      if ctlpage[page] then
        for c = 1, #ctlpage[page] do
        
          if MOUSE_click(ctlpage[page][c]) then
            if ctlpage[page][c].dataindex then
              --control data
              if not ctlpage[page][c].valactive or ctlpage[page][c].valactive(lvar.buttsel[1]) then
                
                local LClick = ctlpage[page][c].LClick
                if mouse.alt then
                  
                  if ctlpage[page][c].multiedit then
                    for i = 1, #lvar.buttsel do
                      lvar.buttdata[lvar.buttsel[i]][ctlpage[page][c].dataindex] = nil
                    end
                  else
                    lvar.buttdata[lvar.buttsel[1]][ctlpage[page][c].dataindex] = nil
                  end
                  update_gfx = true
                  update_cbox = true
                  
                elseif LClick then
                                  
                  LClick(lvar.buttsel[1])
                  
                elseif ctlpage[page][c].datatab then
                
                  local x = obj.sections[5].x + ctlpage[page][c].x
                  local y = obj.sections[5].y + ctlpage[page][c].y + ctlpage[page][c].h
                
                  local res = DataTab_Menu(ctlpage[page][c].datatab, x, y, ctlpage[page][c].formatval)
                  if res > 0 then
                    
                    --validate
                    local validated
                    local func = ctlpage[page][c].valfunc
                    if func then
                      validated = func(res, lvar.buttsel[1])
                    else
                      validated = res
                    end
                    
                    if ctlpage[page][c].multiedit then
                      for i = 1, #lvar.buttsel do
                        lvar.buttdata[lvar.buttsel[i]][ctlpage[page][c].dataindex] = datatab[ctlpage[page][c].datatab][validated]
                        if datatab_desc[ctlpage[page][c].datatab] then
                          lvar.buttdata[lvar.buttsel[i]][ctlpage[page][c].dataindex..'_desc'] = datatab_desc[ctlpage[page][c].datatab][validated]
                        else
                          lvar.buttdata[lvar.buttsel[i]][ctlpage[page][c].dataindex..'_desc'] = nil
                        end
                      end
                    else                  
                      lvar.buttdata[lvar.buttsel[1]][ctlpage[page][c].dataindex] = datatab[ctlpage[page][c].datatab][validated]
                      if datatab_desc[ctlpage[page][c].datatab] then
                        lvar.buttdata[lvar.buttsel[1]][ctlpage[page][c].dataindex..'_desc'] = datatab_desc[ctlpage[page][c].datatab][validated]
                      else
                        lvar.buttdata[lvar.buttsel[1]][ctlpage[page][c].dataindex..'_desc'] = nil
                      end
                    end
                    update_cbox = true
                  end
                elseif ctlpage[page][c].uitxt then
                  --user input entry
                  local ew = ''
                  if ctlpage[page][c].uiextraw then
                    ew = ',extrawidth='..string.format('%i',ctlpage[page][c].uiextraw)
                  end
                  local retval, val = reaper.GetUserInputs(ctlpage[page][c].title, 1, ctlpage[page][c].uitxt..ew, 
                                                           lvar.buttdata[lvar.buttsel[1]][ctlpage[page][c].dataindex] or '')
                  if retval and val ~= '' then
                    --validate
                    local validated
                    local func = ctlpage[page][c].valfunc
                    if func then
                      validated = func(val, lvar.buttsel[1])
                    else
                      validated = val
                    end
    
                    if ctlpage[page][c].multiedit then
                      for i = 1, #lvar.buttsel do
                        lvar.buttdata[lvar.buttsel[i]][ctlpage[page][c].dataindex] = validated
                      end
                    else
                      lvar.buttdata[lvar.buttsel[1]][ctlpage[page][c].dataindex] = validated
                    end
                    update_cbox = true
                    update_gfx = true
                  end
                end
              end
            
              break
  
            elseif ctlpage[page][c].dataindex2 then
              --global data
              if not ctlpage[page][c].valactive or ctlpage[page][c].valactive(ctlpage[page][c].idx) then
                local LClick = ctlpage[page][c].LClick
                --local AltClick = ctlpage[page][c].AltLClick
                if mouse.alt then
                  
                  lvar.buttdata[ctlpage[page][c].dataindex2] = nil
                  update_cbox = true
                  --AltClick(ctlpage[page][c].idx, ctlpage[page][c].row, ctlpage[page][c].col, ctlpage[page][c].dataindex2, ctlpage[page][c].datatab)
                
                elseif LClick then
                  
                  LClick(ctlpage[page][c].idx, ctlpage[page][c].row, ctlpage[page][c].col, ctlpage[page][c].dataindex2, ctlpage[page][c].datatab)
                
                elseif ctlpage[page][c].datatab then
                                
                  local x = obj.sections[5].x + ctlpage[page][c].x
                  local y = obj.sections[5].y + ctlpage[page][c].y + ctlpage[page][c].h
                
                  local res = DataTab_Menu(ctlpage[page][c].datatab, x, y)
                  if res > 0 then
                    
                    --validate
                    local validated
                    local func = ctlpage[page][c].valfunc
                    if func then
                      validated = func(res)
                    else
                      validated = res
                    end
                    
                    lvar.buttdata[ctlpage[page][c].dataindex2] = datatab[ctlpage[page][c].datatab][validated]
                    if datatab_desc[ctlpage[page][c].datatab] then
                      lvar.buttdata[ctlpage[page][c].dataindex2..'_desc'] = datatab_desc[ctlpage[page][c].datatab][validated]
                    else
                      lvar.buttdata[ctlpage[page][c].dataindex2..'_desc'] = nil
                    end
                    update_cbox = true
                  end
                
                elseif ctlpage[page][c].uitxt then
                  --user input entry
                  local ew = ''
                  if ctlpage[page][c].uiextraw then
                    ew = ',extrawidth='..string.format('%i',ctlpage[page][c].uiextraw)
                  end
                  local retval, val = reaper.GetUserInputs(ctlpage[page][c].title, 1, ctlpage[page][c].uitxt..ew, 
                                                           lvar.buttdata[ctlpage[page][c].dataindex2] or '')
                  if retval and val ~= '' then
                    --validate
                    local validated
                    local func = ctlpage[page][c].valfunc
                    if func then
                      validated = func(val)
                    else
                      validated = val
                    end
    
                    lvar.buttdata[ctlpage[page][c].dataindex2] = validated
                    update_cbox = true
                  elseif retval then
                    lvar.buttdata[ctlpage[page][c].dataindex2] = nil
                    update_cbox = true
                  end
                end
              end
              
              break
            end
            
          elseif MOUSE_click_RB(ctlpage[page][c]) then
            --if ctlpage[page][c].dataindex2 then
              
              local RClick = ctlpage[page][c].RClick
              if RClick then
                RClick(ctlpage[page][c].idx, ctlpage[page][c].dataindex2)
              end
              
            --end
          end
        
        end
      end
    elseif page == 1 then
      --Special case for always shown buttons
      for c = 1, #ctlpage[page] do
              
        if ctlpage[page][c].alwaysshow and MOUSE_click(ctlpage[page][c]) then
          local LClick = ctlpage[page][c].LClick
          if LClick then
            LClick(lvar.buttsel[1])
          end
        end
      end
    end
    
  end
  
  function GetMIDIDevices()
    
    local tmp = {input = {}, output = {}, inidx = {}, outidx = {}, inidx2 = {}, outidx2 = {}}
  
    local incnt = reaper.GetNumMIDIInputs()
    
    for i = 0, incnt do
      local present, name = reaper.GetMIDIInputName(i, '')
      if present then
        local idx = #tmp.input+1
        tmp.input[idx] = {name = name, present = present, dev = i, bus = 0}
        tmp.inidx[name] = i
        tmp.inidx2[name] = idx
      end
    end
    
    local outcnt = reaper.GetNumMIDIOutputs()
        
    for i = 0, outcnt do
      local present, name = reaper.GetMIDIOutputName(i, '')
      if present == true then
        local idx = #tmp.output+1
        tmp.output[idx] = {name = name, present = present, dev = i, bus = 0}
        --DBG(idx..'  '..i..'  '..name)
        tmp.outidx[name] = i
        tmp.outidx2[name] = idx
      end
    end
    
    return tmp
  end
  
  function ListenPortMenu(x,y,d)

    if not lvar.mididevices then
      lvar.mididevices = GetMIDIDevices()
    end
    
    local mididevices = lvar.mididevices
    local mstr = ''
    
    for i = 1, #mididevices.input do
      tk = ''
      if d == mididevices.input[i].name then
        tk = '!'
      end
      mstr = mstr .. '|'..tk .. mididevices.input[i].name 
    end
  
    gfx.x = x
    gfx.y = y
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if lvar.midilearn_track then
        lvar.buttdata.listenport = mididevices.input[res].name
        local b = mididevices.input[res].dev
        local dev = 4096+(b << 5)
        local tr = lvar.midilearn_track
        reaper.SetMediaTrackInfo_Value(tr,'I_RECINPUT',dev)
        reaper.SetMediaTrackInfo_Value(tr,'I_RECMODE',2)
        reaper.SetMediaTrackInfo_Value(tr,'I_RECARM',1)
        reaper.SetMediaTrackInfo_Value(tr,'I_RECMON',1)
        update_lrn = true
      end
    end
    
  end

  function HandShakePortMenu(x,y,d)
  
    if not lvar.mididevices then
      lvar.mididevices = GetMIDIDevices()
    end
    
    local mididevices = lvar.mididevices
    local mstr = ''
    
    for i = 1, #mididevices.output do
      tk = ''
      if d == mididevices.output[i].name then
        tk = '!'
      end
      mstr = mstr .. '|'..tk .. mididevices.output[i].name 
    end
  
    gfx.x = x
    gfx.y = y
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if lvar.midilearn_track then
        lvar.buttdata.handshakeport = mididevices.output[res].name
        local b = mididevices.output[res].dev
        local tr = lvar.midilearn_track
        
        local pidx = mididevices.outidx2[lvar.buttdata.handshakeport]
        if pidx and mididevices.output[pidx] then
          local b = mididevices.output[pidx].dev
          local dev = (b << 5)
          reaper.SetMediaTrackInfo_Value(tr, 'I_MIDIHWOUT', dev)
          SetUpHandshake(0, lvar.buttdata.handshake)
        end
        --[[reaper.SetMediaTrackInfo_Value(tr,'I_RECINPUT',dev)
        reaper.SetMediaTrackInfo_Value(tr,'I_RECMODE',2)
        reaper.SetMediaTrackInfo_Value(tr,'I_RECARM',1)
        reaper.SetMediaTrackInfo_Value(tr,'I_RECMON',1)]]
        update_lrn = true
      end
    end
    
  end
  
  function SetUpHandshake(dev, sysxstr)
  
    if sysxstr and sysxstr ~= '' then
      hstab = sysxstr:split(' ')
      if lvar.midilearn_track then
        reaper.gmem_attach('LBX_SK2_SharedMem')
        local gmem = reaper.gmem_write
        for i = 1, #hstab do
          gmem(gmem_handshake + (i-1), tonumber(hstab[i]))
        end 
        gmem(gmem_handshake_len, #hstab)
        local track = lvar.midilearn_track
        if track then
          reaper.TrackFX_SetParam(track,1,5,1)
        end
        reaper.gmem_attach('LBX_CM_SharedMem')
      end
    else
      reaper.MB("Please set up handshake in 'Additional Data' section",'MIDI Learn Handshake',0)
    end
    
  end  
  
  function ARun_MidiLrn()
  
    local gmem = reaper.gmem_read
    local lcnt = gmem(gmem_cnt)
    if lvar.ml_cnt < lcnt then
      for i = lvar.ml_cnt, lcnt-1 do
        local ltype = gmem(gmem_data + (i*2) + 0)
        local lencodedmsg = gmem(gmem_data + (i*2) + 1)
        if ltype == 224 then
          --pitch
          local idx = #lvar.ml_rec+1
          lvar.ml_rec[idx] = {ltype = 'PITCH', chan = lencodedmsg, num = 0}
          update_lrn = true
          
        elseif ltype == 176 then
          local idx = #lvar.ml_rec+1
          lvar.ml_rec[idx] = {ltype = 'CC', chan = lencodedmsg >> 8, num = lencodedmsg & 0xFF}
          update_lrn = true

        elseif ltype == 144 then
          local idx = #lvar.ml_rec+1
          lvar.ml_rec[idx] = {ltype = 'NOTE', chan = lencodedmsg >> 8, num = lencodedmsg & 0xFF}
          update_lrn = true

        end
      end
      lvar.ml_cnt = lcnt
    
    end
    
    if MOUSE_click(obj.sections[100]) then
      local mx, my = mouse.mx, mouse.my
      mouse.mx = mx - obj.sections[100].x
      mouse.my = my - obj.sections[100].y
      
      if MOUSE_click(obj.sections[102]) then
      
        local x = obj.sections[100].x+obj.sections[102].x
        local y = obj.sections[100].y+obj.sections[102].y+obj.sections[102].h
        
        ListenPortMenu(x,y,lvar.buttdata.listenport)

      elseif MOUSE_click(obj.sections[103]) then
      
        local x = obj.sections[100].x+obj.sections[103].x
        local y = obj.sections[100].y+obj.sections[103].y+obj.sections[103].h
        
        HandShakePortMenu(x,y,lvar.buttdata.handshakeport)
      
      elseif MOUSE_click(obj.sections[101]) then
      
        local mmy = mouse.my - obj.sections[101].y
        local rcnt = math.floor(obj.sections[101].h / (ctlpage.bh1+2))
        local r = math.floor(mmy / (ctlpage.bh1+2))
        local rr = math.max(#lvar.ml_rec, rcnt) - rcnt + r + 1
        if lvar.ml_rec[rr] then
        
          local bd = lvar.midilearn.bd
          if lvar.midilearn.ltype == 0 then
            bd.miditype = lvar.ml_rec[rr].ltype
            bd.midichan = lvar.ml_rec[rr].chan
            bd.midinum = lvar.ml_rec[rr].num
            
            lvar.midilearn = nil
          elseif lvar.midilearn.ltype == 1 then
            bd.t_type = lvar.ml_rec[rr].ltype
            bd.t_chan = lvar.ml_rec[rr].chan
            bd.t_num = lvar.ml_rec[rr].num
            bd.t_on = 127
            bd.t_off = 0
            lvar.midilearn = nil
            
          end
          update_cbox = true
        end
    
      end
      mouse.mx = mx
      mouse.my = my
      
    elseif MOUSE_click(obj.sections[1000]) then
      lvar.midilearn = nil
    end
    
  end
  
  function DataTab_Menu(datanum, x, y, formatval)
  
    local data = datatab_desc[datanum] or datatab[datanum] 
    local mstr = ''
    for d = 1, #data do
      if d > 1 then
        mstr = mstr .. '|'
      end
      local v = data[d]
      if formatval then
        v = formatval(v)
      end
      mstr = mstr .. v
    end
    gfx.x = x or (obj.sections[5].x + mouse.mx)
    gfx.y = y or (obj.sections[5].y + mouse.my)
    local res = gfx.showmenu(mstr)  
    return res
    
  end
  
  function run()
  
    --[[if lvar.cursor_invis == true then
      reaper.JS_Mouse_SetCursor(lvar.cursor_invisible)
    end]]
    
    mouse.smx, mouse.smy = reaper.GetMousePosition()
    mouse.mx, mouse.my = gfx.mouse_x, gfx.mouse_y
    mouse.LB = gfx.mouse_cap&1==1
    mouse.RB = gfx.mouse_cap&2==2
    mouse.ctrl = gfx.mouse_cap&4==4
    mouse.shift = gfx.mouse_cap&8==8
    mouse.alt = gfx.mouse_cap&16==16
    
    local char = gfx.getchar()
    
    local rt = reaper.time_precise()
    if mouse.context == nil and MOUSE_click_RB(obj.sections[1]) and (mouse.shift or not lvar.rcz) then
      Menu_ImageRB()
    else
      if (mouse.alt or mouse.RB) and lvar.imageidx and (not lvar.zoomcentre or lvar.imagescale ~= lvar.zoomfactor) and MOUSE_over(obj.sections[4]) then
        lvar.imagescale = lvar.zoomfactor
        update_gfx = true
        local w, h = gfx.getimgdim(lvar.imageidx)
        obj.sections[2].w = obj.sections[1].w--math.ceil(w*lvar.imagescale)
        obj.sections[2].h = obj.sections[1].h--math.ceil(h*lvar.imagescale)
        lvar.zoomcentre = true
        
      elseif not (mouse.alt or mouse.RB) and lvar.zoomcentre and lvar.imageidx and lvar.imagescale == lvar.zoomfactor --[[and lvar.imagescale2 ~= 1]] then
        lvar.imagescale = lvar.imagescale2
        update_gfx = true
        local w, h = gfx.getimgdim(lvar.imageidx)
        obj.sections[2].w = math.ceil(w*lvar.imagescale)
        obj.sections[2].h = math.ceil(h*lvar.imagescale)
        lvar.zoomcentre = false
        reaper.JS_WindowMessage_Post(lvar.hwnd, 'WM_MBUTTONUP', MK_MBUTTON, 0, 0, 0)
        lvar.xoff = nil
        lvar.yoff = nil
        
      end
    end
    
    if lvar.zoomcentre then
      reaper.JS_WindowMessage_Post(lvar.hwnd, 'WM_MBUTTONDOWN', MK_MBUTTON, 0, 0, 0)
      reaper.JS_Mouse_SetCursor(lvar.cursor_invisible)
      if mouse.last_x ~= mouse.mx or mouse.last_y ~= mouse.my then
        update_gfx = true
      end
    end

    if not mouse.LB --[[and not mouse.RB]] and not lvar.preservecontext then mouse.context = nil end

    nextcheck = rt+0.1
    
    if gfx.w ~= gfx1.main_w or gfx.h ~= gfx1.main_h then
    
      local r = false
      if not r or gfx.dock(-1) > 0 then 
      
        gfx1.main_w = gfx.w
        gfx1.main_h = gfx.h
        win_w = gfx.w
        win_h = gfx.h
  
        obj = GetObjects()
        resize_display = true
        update_gfx = true
        update_cbox = true
        update_lrn = true
        
      end
    end
    
    GUI_draw()
    
    -----------------------------------------------

    if char > 0 then
      --DBG(char)
      keypress(char)
    end

    --end
    if lvar.midilearn then
      ARun_MidiLrn()
    else
      local mo2
      mo2 = MOUSE_over(obj.sections[2])
      if mo2 then
        if gfx.mouse_wheel ~= 0 and lvar.zoomcentre then
          local v = gfx.mouse_wheel / lvar.mwdiv
          if v < 0 then
            v = -1
          else
            v = 1
          end
          lvar.zoomfactor = F_limit(lvar.zoomfactor+v,1,4)
          update_gfx = true
          update_cbox = true
          gfx.mouse_wheel = 0
        end
        if (mouse.RB or mouse.alt) and not lvar.shift2 then
          lvar.shift2 = {}
  --        if lvar.zoomcentre then
          
  --        else
            lvar.shift2.x = (mouse.mx - obj.sections[2].x)/lvar.imagescale2
            lvar.shift2.y = (mouse.my - obj.sections[2].y)/lvar.imagescale2
  --        end
          lvar.shift2.dx = 0
          lvar.shift2.dy = 0
          lvar.cursor_invis = true
          mouse.ox, mouse.oy = mouse.smx, mouse.smy
          
        elseif (mouse.RB or mouse.alt) then
      
          local shift = 0.4
          lvar.shift2.dx = lvar.shift2.dx -((mouse.ox-mouse.smx)) * shift
          lvar.shift2.dy = lvar.shift2.dy -((mouse.oy-mouse.smy)) * shift
          
          if lvar.imageidx then
            local w, h = gfx.getimgdim(lvar.imageidx)
            if lvar.shift2.x+lvar.shift2.dx < 0 then
              lvar.shift2.dx = 0-lvar.shift2.x
            elseif lvar.shift2.x+lvar.shift2.dx > w then
              lvar.shift2.dx = w-lvar.shift2.x
            end
            if lvar.shift2.y+lvar.shift2.dy < 0 then
              lvar.shift2.dy = 0-lvar.shift2.y
            elseif lvar.shift2.y+lvar.shift2.dy > h then
              lvar.shift2.dy = h-lvar.shift2.y
            end
          end
          
          lvar.cursor_invis = true
          
        else
          if lvar.shift2 then
            reaper.JS_Mouse_SetPosition(math.floor(mouse.ox+lvar.shift2.dx*lvar.imagescale2), math.floor(mouse.oy+lvar.shift2.dy*lvar.imagescale2))
          end
          lvar.shift2 = nil
          lvar.cursor_invis = false
        end
      elseif (mouse.RB or mouse.alt) and lvar.shift2 then
  
        local shift = 0.4
        lvar.shift2.dx = lvar.shift2.dx -((mouse.ox-mouse.smx)) * shift
        lvar.shift2.dy = lvar.shift2.dy -((mouse.oy-mouse.smy)) * shift

        if lvar.imageidx then
          local w, h = gfx.getimgdim(lvar.imageidx)
          if lvar.shift2.x+lvar.shift2.dx < 0 then
            lvar.shift2.dx = 0-lvar.shift2.x
          elseif lvar.shift2.x+lvar.shift2.dx > w then
            lvar.shift2.dx = w-lvar.shift2.x
          end
          if lvar.shift2.y+lvar.shift2.dy < 0 then
            lvar.shift2.dy = 0-lvar.shift2.y
          elseif lvar.shift2.y+lvar.shift2.dy > h then
            lvar.shift2.dy = h-lvar.shift2.y
          end
        end

        lvar.cursor_invis = true

      elseif not (mouse.RB or mouse.alt) and lvar.shift2 then
          if lvar.shift2 then
            reaper.JS_Mouse_SetPosition(math.floor(mouse.ox+lvar.shift2.dx*lvar.imagescale2), math.floor(mouse.oy+lvar.shift2.dy*lvar.imagescale2))
          end
          lvar.shift2 = nil
          lvar.cursor_invis = false
      end
      
      if mouse.context == nil then
      
        if lvar.create_shape then
          local cs = lvar.create_shape      
          if cs.x2 then
            
            if cs.shape == 0 then      
              local x,x2,y,y2
              if cs.x2 > cs.x then
                x = cs.x
                x2 = cs.x2
              else
                x = cs.x2
                x2 = cs.x
              end
              if cs.y2 > cs.y then
                y = cs.y
                y2 = cs.y2
              else
                y = cs.y2
                y2 = cs.y
              end
              
              if x2-x > 4 and y2-y > 4 then
                local tab = {}
                tab.x = x
                tab.y = y
                tab.w = x2-x
                tab.h = y2-y
                tab.shape = cs.shape
                
                lvar.buttdata[#lvar.buttdata+1] = tab
              
              else
                --single click
                SelectButt()
              end
              update_gfx = true
              
            elseif cs.shape == 1 then
            
              local dx = (cs.x2 - cs.x)^2
              local dy = (cs.y2 - cs.y)^2
              local r = math.sqrt(dx + dy)
              
              if r > 4 then
                local tab = {}
                tab.x = cs.x
                tab.y = cs.y
                tab.r = r
                tab.shape = cs.shape
                
                lvar.buttdata[#lvar.buttdata+1] = tab
              
              else
                --single click
                SelectButt()
              end
              update_gfx = true
            end
          end
          
          lvar.create_shape = nil
        
        elseif lvar.move_delay then
        
          update_gfx = true
          lvar.move_delay = nil
        
        elseif lvar.add_fader then
          --Add fader
          if MOUSE_over(obj.sections[4]) then
            local tab = {}
            tab.ctype = 'fader'
            tab.x = (lvar.add_fader.x-obj.sections[4].x)/lvar.imagescale
            tab.y = (lvar.add_fader.y-obj.sections[4].y)/lvar.imagescale
            tab.w = lvar.add_fader.w
            tab.h = lvar.add_fader.h
            tab.shape = 0
            
            tab.x = math.floor(tab.x/lvar.adjustamt)*lvar.adjustamt
            tab.y = math.floor(tab.y/lvar.adjustamt)*lvar.adjustamt
            
            local cnt = 1
            for i = 1, #lvar.buttdata do
              local bd = lvar.buttdata[i]
              --[[if bd.mode == 0 and bd.miditype ~= 'NIL' then
                cnt = cnt + 1
              else]]if string.match(bd.name or '','Fader %d+') then
                cnt = cnt + 1
              end
              
            end
            tab.name = 'Fader '..cnt
            local idx = #lvar.buttdata+1
            lvar.buttdata[idx] = tab

            lvar.buttsel, lvar.buttsel_idx = {}, {}
            lvar.buttsel[1] = idx
            lvar.buttsel_idx[idx] = 1
          end
          lvar.add_fader = nil
          update_gfx = true
          update_cbox = true
          
        elseif lvar.add_encoder then

          if MOUSE_over(obj.sections[4]) then
            local tab = {}
            tab.ctype = 'encoder'
            tab.x = (lvar.add_encoder.x-obj.sections[4].x)/lvar.imagescale
            tab.y = (lvar.add_encoder.y-obj.sections[4].y)/lvar.imagescale
            tab.r = lvar.add_encoder.r
            tab.shape = 1

            tab.x = math.floor(tab.x/lvar.adjustamt)*lvar.adjustamt
            tab.y = math.floor(tab.y/lvar.adjustamt)*lvar.adjustamt
            
            local cnt = 1
            for i = 1, #lvar.buttdata do
              local bd = lvar.buttdata[i]
              --[[if (bd.mode == 2 or bd.mode == 3) and bd.miditype ~= 'NIL' then
                cnt = cnt + 1
              else]]if string.match(bd.name or '','Encoder %d+') then
                cnt = cnt + 1
              end
            end
            tab.name = 'Encoder '..cnt
            
            local idx = #lvar.buttdata+1
            lvar.buttdata[idx] = tab

            lvar.buttsel, lvar.buttsel_idx = {}, {}
            lvar.buttsel[1] = idx
            lvar.buttsel_idx[idx] = 1
          end
          lvar.add_encoder = nil
          update_gfx = true
          update_cbox = true
        
        elseif lvar.add_button then
        
          if MOUSE_over(obj.sections[4]) then
            local tab = {}
            tab.ctype = 'button'
            if lvar.btype == 0 then
              tab.x = (lvar.add_button.x-obj.sections[4].x)/lvar.imagescale
              tab.y = (lvar.add_button.y-obj.sections[4].y)/lvar.imagescale
              tab.w = lvar.add_button.r
              tab.h = lvar.add_button.r
              tab.shape = 0

            else
              tab.x = (lvar.add_button.x-obj.sections[4].x)/lvar.imagescale
              tab.y = (lvar.add_button.y-obj.sections[4].y)/lvar.imagescale
              tab.r = lvar.add_button.r
              tab.shape = 1
            end

            tab.x = math.floor(tab.x/lvar.adjustamt)*lvar.adjustamt
            tab.y = math.floor(tab.y/lvar.adjustamt)*lvar.adjustamt
            
            local cnt = 1
            for i = 1, #lvar.buttdata do
              local bd = lvar.buttdata[i]
              --[[if (bd.mode == 4) and bd.miditype ~= 'NIL' then
                cnt = cnt + 1
              else]]if string.match(bd.name or '','Button %d+') then
                cnt = cnt + 1
              end
            end
            tab.name = 'Button '..cnt
            
            local idx = #lvar.buttdata+1
            lvar.buttdata[idx] = tab

            lvar.buttsel, lvar.buttsel_idx = {}, {}
            lvar.buttsel[1] = idx
            lvar.buttsel_idx[idx] = 1
          end
          lvar.add_button = nil
          update_gfx = true
          update_cbox = true
          
        end
        
        if MOUSE_click(obj.sections[5]) or MOUSE_click_RB(obj.sections[5]) or (gfx.mouse_wheel ~= 0 and MOUSE_over(obj.sections[5])) then
          --CBox
          ARun_CBox()
        
        elseif MOUSE_click(obj.sections[2]) then
          if not SelectButt() then
            mouse.context = contexts.create_shape
            local x,y
            if lvar.shift2 then
              x = round(lvar.shift2.x + round(lvar.shift2.dx))
              y = round(lvar.shift2.y + round(lvar.shift2.dy))
            else
              x = (mouse.mx - obj.sections[2].x)/lvar.imagescale2
              y = (mouse.my - obj.sections[2].y)/lvar.imagescale2
            end
            lvar.create_shape = {x = x, y = y, shape = lvar.btype}
          else
            mouse.context = contexts.move_delay
            lvar.move_delay = {t = reaper.time_precise()}
          end
          
        --elseif MOUSE_click_RB(obj.sections[1]) and mouse.shift then
        --  Menu_ImageRB()
        end
      
      else
        --mouse context
        if mouse.context == contexts.create_shape then
          if lvar.shift2 then
            lvar.create_shape.x2 = round(lvar.shift2.x + round(lvar.shift2.dx))
            lvar.create_shape.y2 = round(lvar.shift2.y + round(lvar.shift2.dy))
          else
            lvar.create_shape.x2 = (mouse.mx - obj.sections[2].x)/lvar.imagescale2
            lvar.create_shape.y2 = (mouse.my - obj.sections[2].y)/lvar.imagescale2
          end
          
        elseif mouse.context == contexts.move_delay then
          if reaper.time_precise() > lvar.move_delay.t + 0.2 then
            
            local bd = lvar.buttdata[lvar.buttsel[1]]
            if bd then
              mouse.context = contexts.move_delay2
              lvar.move_delay.offx = mouse.mx-(bd.x/lvar.imagescale+obj.sections[4].x)
              lvar.move_delay.offy = mouse.my-(bd.y/lvar.imagescale+obj.sections[4].y)
              lvar.move_delay.mx = mouse.mx
              lvar.move_delay.my = mouse.my
              lvar.move_delay.bd = {}
              for i = 1, #lvar.buttsel do
                local bd = lvar.buttdata[lvar.buttsel[i]]
                if bd then
                  lvar.move_delay.bd[lvar.buttsel[i]] = {x = bd.x, y = bd.y}
                end
              end
            end
          end
        
        elseif mouse.context == contexts.move_delay2 then

          if mouse.mx ~= lvar.move_delay.lastmouse_x or mouse.my ~= lvar.move_delay.lastmouse_y then
            lvar.move_delay.lastmouse_x = mouse.mx
            lvar.move_delay.lastmouse_y = mouse.my
            
            --[[lvar.move_delay.x = mouse.mx
            lvar.move_delay.y = mouse.my]]
            
            local dx = (mouse.mx - lvar.move_delay.mx)/lvar.imagescale
            local dy = (mouse.my - lvar.move_delay.my)/lvar.imagescale
            local mbd = lvar.move_delay.bd
            
            for i = 1, #lvar.buttsel do
              local bd = lvar.buttdata[lvar.buttsel[i]]
              if bd then
                bd.x = mbd[lvar.buttsel[i]].x + dx
                bd.y = mbd[lvar.buttsel[i]].y + dy

                bd.x = math.floor(bd.x/lvar.adjustamt)*lvar.adjustamt
                bd.y = math.floor(bd.y/lvar.adjustamt)*lvar.adjustamt

              end
            end
            update_gfx = true
          end
          
        elseif mouse.context == contexts.crop then
          local v = lvar.crop.val + (lvar.crop.y - mouse.my)
          for i = 1, #lvar.buttsel do
            lvar.buttdata[lvar.buttsel[i]][lvar.crop.cidx] = v
            if mouse.shift then
              local v2 = lvar.crop.val2 + (lvar.crop.y - mouse.my)
              lvar.buttdata[lvar.buttsel[i]][lvar.crop.cidx2] = v2
            end
          end
          update_gfx = true
          update_cbox = true
        
        elseif mouse.context == contexts.add_fader then
          if gfx.mouse_wheel ~= 0 then
            local v = gfx.mouse_wheel / lvar.mwdiv
            lvar.ctlzoom_f = F_limit(lvar.ctlzoom_f + v*0.2,0.2,8)
            lvar.add_fader.w = lvar.def_fader.w*lvar.ctlzoom_f
            lvar.add_fader.h = lvar.def_fader.h*lvar.ctlzoom_f
          end
          lvar.add_fader.x = mouse.mx-(((lvar.add_fader.w)*lvar.imagescale)/2)
          lvar.add_fader.y = mouse.my-(((lvar.add_fader.h)*lvar.imagescale)/2)
          
        elseif mouse.context == contexts.add_encoder then
          if gfx.mouse_wheel ~= 0 then
            local v = gfx.mouse_wheel / lvar.mwdiv
            lvar.ctlzoom_e = F_limit(lvar.ctlzoom_e + v*0.2,0.2,8)
            lvar.add_encoder.r = lvar.def_encoder.r*lvar.ctlzoom_e
          end
          lvar.add_encoder.x = mouse.mx
          lvar.add_encoder.y = mouse.my

        elseif mouse.context == contexts.add_button then
          if gfx.mouse_wheel ~= 0 then
            local v = gfx.mouse_wheel / lvar.mwdiv
            lvar.ctlzoom_b = F_limit(lvar.ctlzoom_b + v*0.2,0.2,8)
            local m = 1
            if lvar.btype == 0 then
              m = 2
            end
            lvar.add_button.r = (lvar.def_button.r*m)*lvar.ctlzoom_b
            --lvar.add_button.w = lvar.def_button.w*lvar.ctlzoom
            --lvar.add_button.h = lvar.def_button.h*lvar.ctlzoom
          end
          if lvar.btype == 0 then
            lvar.add_button.x = mouse.mx-(((lvar.add_button.r)*lvar.imagescale)/2)
            lvar.add_button.y = mouse.my-(((lvar.add_button.r)*lvar.imagescale)/2)
          else
            lvar.add_button.x = mouse.mx
            lvar.add_button.y = mouse.my
          end
        end
      end
    end
    
    -----------------------------------------------
    if lvar.cursor_invis == true then
      reaper.JS_Mouse_SetCursor(lvar.cursor_invisible)
      reaper.JS_Mouse_SetPosition(mouse.ox, mouse.oy)
    end
    
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
    gfx.mouse_wheel = 0
    
    
  end --run
  
  ---------------------------------------------------------
  
  function SelectButt()
  
    local mx, my
    if lvar.shift2 then
      mx = round(lvar.shift2.x + round(lvar.shift2.dx))
      my = round(lvar.shift2.y + round(lvar.shift2.dy))
    else
      mx, my = mouse.mx - obj.sections[2].x, mouse.my - obj.sections[2].y
      mx = mx/lvar.imagescale2
      my = my/lvar.imagescale2
    end
    local sel, sel2
    local vol = math.huge
    for i = 1, #lvar.buttdata do
      local bd = lvar.buttdata[i]
      if bd.shape == 0 then
        if mx >= bd.x and mx <= bd.x+bd.w and my >= bd.y and my <= bd.y+bd.h then
          --if not lvar.buttsel_idx[i] then
            local vol2 = bd.w*bd.h
            if vol2 < vol then
              sel = i
              vol = vol2
            end
            --rad = 
          --  break
          --else
          --  sel2 = i
          --end
        end
      elseif bd.shape == 1 then
        local r = math.sqrt((mx-bd.x)^2 + (my-bd.y)^2)
        if r <= bd.r then
          --if not lvar.buttsel_idx[i] then
            local vol2 = 3.14*(bd.r*bd.r)
            if vol2 < vol then
              sel = i
              vol = vol2
            end
          --  break
          --else
          --  sel2 = i
          --end
        end
      end
    end

    --if not sel then
    --  sel = sel2
    --end
    
    if sel then
    
      if mouse.ctrl then
        if not lvar.buttsel_idx[sel] then
          local idx = #lvar.buttsel+1
          lvar.buttsel[idx] = sel
          lvar.buttsel_idx[sel] = idx
        else
          local tab, tab_idx = {}, {}
          for i = 1, #lvar.buttsel do
            if sel ~= lvar.buttsel[i] then
              local idx = #tab+1
              tab[idx] = lvar.buttsel[i]
              tab_idx[lvar.buttsel[i]] = idx
            end
          end
          lvar.buttsel = tab
          lvar.buttsel_idx = tab_idx
        end
      else
        if not lvar.buttsel_idx[sel] then
          lvar.buttsel = {}
          lvar.buttsel_idx = {}
          local idx = #lvar.buttsel+1
          lvar.buttsel[idx] = sel
          lvar.buttsel_idx[sel] = idx
        else
          local tab, tab_idx = {}, {}
          tab[1] = sel
          tab_idx[sel] = 1
          for i = 1, #lvar.buttsel do
            if sel ~= lvar.buttsel[i] then
              local idx = #tab+1
              tab[idx] = lvar.buttsel[i]
              tab_idx[lvar.buttsel[i]] = idx
            end
          end
          lvar.buttsel = tab
          lvar.buttsel_idx = tab_idx
          
        end
      end
      update_gfx = true
      update_cbox = true
      
      if pages[ctlpage.activepage].bsel_func then
        pages[ctlpage.activepage].bsel_func(lvar.buttsel[1])
      end
      
      local bd = lvar.buttdata[lvar.buttsel[1]]
      if bd and bd.ctype then
        if bd.ctype == 'fader' then
          lvar.def_fader.w = bd.w or lvar.def_fader.w
          lvar.def_fader.h = bd.h or lvar.def_fader.h
          lvar.ctlzoom_f = 1
        elseif bd.ctype == 'encoder' then
          if bd.r then
            lvar.def_encoder.r = bd.r
            lvar.ctlzoom_e = 1
          end
        elseif bd.ctype == 'button' then
          if bd.w then
            lvar.def_button.r = math.ceil(bd.h/2)
            lvar.ctlzoom_b = 1
          end
        end
      end
      
      return true
      
    elseif not mouse.ctrl then
      lvar.buttsel = {}
      lvar.buttsel_idx = {}
      update_cbox = true
    end
  
  end
  
  function ButtSel_CStrip(butt)
  
    if lvar.cstrip and lvar.cstrip.sel then
      local page = ctlpage.activepage
      local cobj = ctlpage[page][lvar.cstrip.sel]
      lvar.buttdata[cobj.dataindex2] = butt
      lvar.cstrip.sel = lvar.cstrip.sel + 1
      if lvar.cstrip.sel % 8 == 1 then
        lvar.cstrip = nil
      end
      update_cbox = true
    end
    
  end

  function ButtSel_Flip(butt)
  
    if lvar.flip and lvar.flip.sel then
      local page = ctlpage.activepage
      local cobj = ctlpage[page][lvar.flip.sel]
      lvar.buttdata[cobj.dataindex2] = butt
      lvar.flip.sel = lvar.flip.sel + 8
      
      if lvar.flip.sel > 16 then
        lvar.flip = nil
      end
      update_cbox = true
    end
    
  end
  
  function Menu_ImageRB()

    local mstr = 'Align Left|Align Right|Align Top|Align Bottom||Align Centre Horiz|Align Centre Vert||Match Width|Match Height||Toggle Shape||Clear Control Error Indicators'
    gfx.x, gfx.y = mouse.mx, mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        if #lvar.buttsel > 1 then
          local idx, x
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            x = lvar.buttdata[idx].x
          else
            x = lvar.buttdata[idx].x-lvar.buttdata[idx].r
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].x = x
            else
              lvar.buttdata[idx].x = x + lvar.buttdata[idx].r
            end
          end
        end
        update_gfx = true

      elseif res == 2 then
        if #lvar.buttsel > 1 then
          local idx, r
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            r = lvar.buttdata[idx].x + lvar.buttdata[idx].w
          else
            r = lvar.buttdata[idx].x + lvar.buttdata[idx].r
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].x = r - lvar.buttdata[idx].w
            else
              lvar.buttdata[idx].x = r - lvar.buttdata[idx].r
            end
          end
        end
        update_gfx = true

      elseif res == 3 then
        if #lvar.buttsel > 1 then
          local idx, y
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            y = lvar.buttdata[idx].y
          else
            y = lvar.buttdata[idx].y - lvar.buttdata[idx].r
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].y = y
            else
              lvar.buttdata[idx].y = y + lvar.buttdata[idx].r
            end
          end
        end
        update_gfx = true

      elseif res == 4 then
        if #lvar.buttsel > 1 then
          local idx, b
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            b = lvar.buttdata[idx].y + lvar.buttdata[idx].h
          else
            b = lvar.buttdata[idx].y + lvar.buttdata[idx].r
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].y = b - lvar.buttdata[idx].h
            else
              lvar.buttdata[idx].y = b - lvar.buttdata[idx].r
            end
          end
        end
        update_gfx = true

      elseif res == 5 then
        if #lvar.buttsel > 1 then
          local idx, c
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            c = lvar.buttdata[idx].x + lvar.buttdata[idx].w/2
          else
            c = lvar.buttdata[idx].x
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].x = c - lvar.buttdata[idx].w/2
            else
              lvar.buttdata[idx].x = c
            end
          end
        end
        update_gfx = true

      elseif res == 6 then
        if #lvar.buttsel > 1 then
          local idx, c
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            c = lvar.buttdata[idx].y + lvar.buttdata[idx].h/2
          else
            c = lvar.buttdata[idx].y
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].y = c - lvar.buttdata[idx].h/2
            else
              lvar.buttdata[idx].y = c
            end
          end
        end
        update_gfx = true

      elseif res == 7 then
        if #lvar.buttsel > 1 then
          local idx, w
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            w = lvar.buttdata[idx].w
          else
            w = lvar.buttdata[idx].r*2
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].w = w
            else
              lvar.buttdata[idx].r = w/2
            end
          end
        end
        update_gfx = true
      
      elseif res == 8 then
        if #lvar.buttsel > 1 then
          local idx, h
          idx = lvar.buttsel[1]
          if lvar.buttdata[idx].shape == 0 then
            h = lvar.buttdata[idx].h
          else
            h = lvar.buttdata[idx].r*2
          end
          for i = 2, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            if lvar.buttdata[idx].shape == 0 then
              lvar.buttdata[idx].h = h
            else
              lvar.buttdata[idx].r = h/2
            end
          end
        end
        update_gfx = true

      elseif res == 9 then
        if #lvar.buttsel > 0 then
          for i = 1, #lvar.buttsel do
            local idx = lvar.buttsel[i]
            local bd = lvar.buttdata[idx]
            if bd.shape == 0 then
              local x,y,w,h = bd.x,bd.y,bd.w,bd.h
              bd.x = x+w/2
              bd.y = y+h/2
              bd.r = w/2
              bd.w = nil
              bd.h = nil
              bd.shape = 1
            else
              local x,y,r = bd.x,bd.y,bd.r
              bd.x = x-r
              bd.y = y-r
              bd.w = r*2
              bd.h = r*2
              bd.r = nil
              bd.shape = 0
            end
            bd.crop_l = nil
            bd.crop_t = nil
            bd.crop_r = nil
            bd.crop_b = nil
          end
        end
        update_cbox = true
        update_gfx = true
        
      elseif res == 10 then
        lvar.buttsel_err = {}
        lvar.buttsel_err_idx = {}
        update_gfx = true
      end
    end
    mouse.RB = nil
    
  end
  
  function LoadControllerImage(obj, donotload)
  
    local fn = lvar.imagefn
    
    if fn and reaper.file_exists(fn) then
      
      if not donotload then
        lvar.imageidx = gfx.loadimg(99,fn)
      end
      if lvar.imageidx then
        local scale_w, scale_h = 1, 1
        local pad = 0
        local w, h = gfx.getimgdim(lvar.imageidx)
        if w > obj.sections[1].w-pad then
          scale_w = (obj.sections[1].w-pad) / w
        end
        if h > (obj.sections[1].h-pad) then
          scale_h = (obj.sections[1].h-pad) / h
        end
        lvar.imagescale = round2(math.min(scale_w, scale_h, 1),2)
        lvar.imagescale2 = lvar.imagescale
        local x = math.floor(((obj.sections[1].w-pad) - w*lvar.imagescale)/2) + obj.sections[1].x + pad*0.5
        local y = math.floor(((obj.sections[1].h-pad) - h*lvar.imagescale)/2) + obj.sections[1].y + pad*0.5
        
        obj.sections[2] = {x = x, y = y, w = math.ceil(w*lvar.imagescale), h = math.ceil(h*lvar.imagescale)}
        obj = SetObj4(obj)
        update_gfx = true
        
        lvar.buttdata.image = fn
        
      end
      
    end
  
  end
  
  function readbinaryfile(src)
    local file = io.open(src, 'rb')
    local content = file:read('*a')
    file:close()
    return content
  end
  
  function writebinaryfile(dest, content)
    local file = io.open(dest, 'wb')
    file:write(content)
    file:close()
  end
  
  function SaveData(fn)
  
    if fn then
    
      local pdata = pickle(lvar.buttdata)
      if pdata then
      
        writebinaryfile(fn, pdata)
      
      end
    
    end
  
  end

  function LoadData(fn)
  
    if reaper.file_exists(fn) then
  
      local pdata = readbinaryfile(fn)
      if pdata then
      
        local tab = unpickle(pdata)
        if tab then
          lvar.buttdata = tab
          lvar.imagefn = tab.image
          lvar.image_w = tab.imagew or 400
          lvar.image_h = tab.imageh or 400
          if (lvar.imagefn or '') ~= '' then
            LoadControllerImage(obj)
          else
            SetUpCanvas(obj, lvar.image_w, lvar.image_h)
          end
        end
      end
    
    end
    
  end

  function Import(fn)

    if reaper.file_exists(fn) then
      
      ctlpage.activepage = 1
      lvar.sorttab = nil
      lvar.sorttab_idx = nil
      lvar.sortsel = nil
      lvar.imagefn = nil
      lvar.imageidx = nil
      lvar.buttdata = {}
      lvar.buttsel = {}
      lvar.buttsel_idx = {}
      lvar.buttsel_err = {}
      lvar.buttsel_err_idx = {}
      update_gfx = true
      update_cbox = true
      SetDefaults()
      
      local file
      
      local data = {}
      for line in io.lines(fn) do
        local idx, val = string.match(line,'^%[(.-)%](.*)') --decipher(line)
        if idx then
          data[idx] = val
        end
      end
    
      --local tmp = {fader = {}, fb = {}, flip = {}}
      local fader_offs = 0
      local group_offs = 0
      local fb_offs = 0
      
      local errormap, error2
      
      --local key = 'FADER_RESET_SYSX'
      --tmp.devsysx[d-1] = {}
      
      --if data[key] then
      --  tmp.devsysx[d-1].fader_reset_sysx = SYSX_StrToTable(data[key])
      --end

      --local key = 'LED_RESET_SYSX'
      --if data[key] then
      --  tmp.devsysx[d-1].led_reset_sysx = SYSX_StrToTable(data[key])      
      --end
      
      local bd = lvar.buttdata
      
      local sscolor = tonumber(data['SSCOLORMODE'])
      if sscolor then
        for i = 1, #datatab[9] do
          if sscolor == tonumber(string.match(datatab[9][i],'^(%d+).*')) then
            bd.sscolormode = datatab[9][i]
            bd.sscolormode_desc = datatab_desc[9][i]
            break
          end
        end
      end
      
      local nt = data['NOTESTHRU']
      if nt then
        bd['notesthru'] = tonumber(nt)
      end

      local bo = data['BUTTON_ON_VAL']
      if bo then
        bd['but_onval'] = tonumber(bo)
      end
      
      local hs = data['HANDSHAKE']
      if hs then
        bd.handshake = hs
      end
      
      local ad = data['ASSIGNMENTDISPLAY']
      if ad then
        local a,b,c,d = string.match(ad,'(%d+)%s*(%d+)%s*(%d+)%s*(%d+)')
        bd.tc_asscc1 = tonumber(a)
        bd.tc_asscc1d = tonumber(b)
        bd.tc_asscc2 = tonumber(c)
        bd.tc_asscc2d = tonumber(d)
      end
      
      local tcd = data['TIMECODEDISPLAY']
      if tcd then
        local cc = {}
        local tf, bf, cnt
        tf, bf, cnt, cc[1], cc[2], cc[3], cc[4], cc[5], cc[6], cc[7], cc[8], cc[9], cc[10] = 
              string.match(tcd,'%<(.-)%>%s*%<(.-)%>%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)')
        bd.tc_timeformat_hours, bd.tc_timeformat_mins, bd.tc_timeformat_secs, bd.tc_timeformat_frames = string.match(tf,'.-(%d+).-(%d+).-(%d+).-(%d+)')
        bd.tc_beatsformat_bars, bd.tc_beatsformat_beats, bd.tc_beatsformat_sub, bd.tc_beatsformat_frames = string.match(tf,'.-(%d+).-(%d+).-(%d+).-(%d+)')
        bd.tc_timeformat_hours = tonumber(bd.tc_timeformat_hours)
        bd.tc_timeformat_mins = tonumber(bd.tc_timeformat_mins)
        bd.tc_timeformat_secs = tonumber(bd.tc_timeformat_secs)
        bd.tc_timeformat_frames = tonumber(bd.tc_timeformat_frames)
        bd.tc_beatsformat_bars = tonumber(bd.tc_beatsformat_bars)
        bd.tc_beatsformat_beats = tonumber(bd.tc_beatsformat_beats)
        bd.tc_beatsformat_sub = tonumber(bd.tc_beatsformat_sub)
        bd.tc_beatsformat_frames = tonumber(bd.tc_beatsformat_frames)

        bd.tc_digits = tonumber(cnt)
        for i = 1, cnt do
          bd['tc_digit'..string.format('%i',i)] = tonumber(cc[i])
        end

        local dispchar2_idx = {}
        for i = 1, #dispchar2 do
          dispchar2_idx[dispchar2[i]] = i-1
        end

        for chars = 0, 20 do
          local key = 'DISPLAYCHAR'..string.format('%i',chars)
          if data[key] then
            local ch, cv = string.match(data[key],'(%-*%d*%a*)%s*(%d+)')
            
            --[[if ch == 'X' then ch = 10 
            elseif ch == '-' then ch = 11
            elseif tonumber(ch) then
              ch = tonumber(ch)
            else
            end]]
            ch = dispchar2_idx[ch]
            if tonumber(ch) then
              bd['tc_char'..string.format('%i',ch)] = tonumber(cv)
            end
          end
        end
        
        local key = 'TIMECODE_SMPTE_LED'
        if data[key] then
          local note, on, off = string.match(data[key],'(%d+)%s*(%d+)%s*(%d+)')
          if note then
            bd['tc_timeled_note'] = tonumber(note)
            bd['tc_timeled_on'] = tonumber(on)
            bd['tc_timeled_off'] = tonumber(off)
          end
        end
        local key = 'TIMECODE_BEATS_LED'
        if data[key] then
          local note, on, off = string.match(data[key],'(%d+)%s*(%d+)%s*(%d+)')
          if note then
            bd['tc_beatsled_note'] = tonumber(note)
            bd['tc_beatsled_on'] = tonumber(on)
            bd['tc_beatsled_off'] = tonumber(off)
          end
        end        
      end
      
      --[[local ssa = {}
      for xx = 0, 31 do
        local id = string.char(65+xx)
        local key = 'SS'..id
        if data[key] then
          ssa[id] = tonumber(data[key])
        end
      end]]
      
      local bgidx = {}
      for gg = 1, 16 do
        local key = 'GRPSEL'..gg
        if data[key] then
          bd['btngroup'..string.format('%i',gg)] = tonumber(data[key])
          bgidx[tonumber(data[key])] = gg
        end
      end

      for sg = 0, 15 do
        local key = 'SORTGRP'..string.format('%i',sg)
        if data[key] then
          bd['sortgroup'..string.format('%i',sg)] = data[key]
        end      
      end

      for cs = 1, 8 do
        local key = 'CHANSTRIP'..cs
        if data[key] then
          local str = data[key]
          t = str:split(' ')
          for i = 1, #t do
            local num = tonumber(t[i])
            if tonumber(t[i]) == -1 then
            else
              bd['chanstrip_'..string.format('%i',i)..'_'..string.format('%i',cs)] = tonumber(t[i])
            end
            --DBG(i..'  '..cs..'  '..tostring(t[i]))
          end
        end      
      end
      
      local dt_idx = {}
      for i = 1, #datatab[6] do
        dt_idx[datatab[6][i]] = i
      end
      
      for i = 1, 256 do
      
        local key = 'F'..string.format('%i',i)
        if data[key] then
          local sort, group, devctl, dtype, dcode, dchan, lmode, ssnum, ttype, tcode, tchan, ton, toff 
          sort, group, devctl, dtype, dcode, dchan, lmode, ssnum = string.match(data[key]..' ','(%d+)%s*(%d+)%s*%<(.-)%>%s*(%a+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d*%-*[A-H]*)%s*')
          if sort == nil then
            sort, group, devctl, dtype, dcode, dchan, lmode, ssnum = string.match(data[key]..' ','(%d+)%s*(-)%s*%<(.-)%>%s*(%a+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d*%-*[A-H]*)%s*')
          end
          ttype, tcode, tchan, ton, toff = string.match(data[key]..' ','%d+%s*%d+%s*%<.-%>%s*%a+%s*%d+%s*%d+%s*%d+%s*%d*%-*[A-H]*%s*(%a+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)')
          if ttype == nil then
            ttype, tcode, tchan, ton, toff = string.match(data[key]..' ','%d+%s*-%s*%<.-%>%s*%a+%s*%d+%s*%d+%s*%d+%s*%d*%-*[A-H]*%s*(%a+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)')
          end
          if not sort then
            errormap = i
            break
          end
          
          group = tonumber(group) --tonumber(bgidx[tonumber(group)])
          
          sort = tonumber(sort)
          
          bd[i] = {}
          bd[i].name = devctl
          bd[i].sort = sort
          bd[i].group = group
          bd[i].miditype = dtype
          bd[i].midichan = tonumber(dchan)
          bd[i].midinum = tonumber(dcode)
          --bd[i].mode = conv_mode[tonumber(lmode)]
          bd[i].mode = tonumber(lmode)
          bd[i].mode_desc = datatab_desc[4][conv_mode[tonumber(lmode)]]
          if tonumber(ssnum) then
            bd[i].ssnum = tonumber(ssnum)
            bd[i].ssnum_main = 1
          elseif ssnum ~= '-' then
            bd[i].ssnum = string.byte(ssnum)-64
            bd[i].ssnum_main = nil
          end
          bd[i].t_type = ttype
          bd[i].t_chan = tonumber(tchan)
          bd[i].t_num = tonumber(tcode)
          bd[i].t_on = tonumber(ton)
          bd[i].t_off = tonumber(toff)
        end

        local key = 'FB'..string.format('%i',i)
        if data[key] then
        
          local dtype, dcode, dchan, dA, dB = string.match(data[key],'(%a+%d*)%s-(%d+)%s*(%d+)%s*(%d*)%s*(%d*)')
          bd[i].fb_type = dtype
          bd[i].fb_type_desc = datatab_desc[6][dt_idx[dtype]]
          --DBG(dtype..'  '..tostring(bd[i].fb_type_desc)..'  '..dt_idx[dtype])
          bd[i].fb_chan = tonumber(dchan)
          bd[i].fb_num = tonumber(dcode)
          bd[i].fb_cca = tonumber(dA)
          bd[i].fb_ccb = tonumber(dB)
          
        end

        local key = 'FLIP'..string.format('%i',i)
        if data[key] then
        
          local f1, f2 = string.match(data[key],'(%d+)%s*(%d+)')
          bd['flip_1_'..string.format('%i',i)] = tonumber(f1)
          bd['flip_2_'..string.format('%i',i)] = tonumber(f2)

        end
        
        local skey = 'SS'..string.format('%i',i)
        if data[skey] then
          bd['ss'..string.format('%i',i)..'_sysx'] = data[skey]
        end

        local skey = 'SETUP_SYSX_'..string.format('%i',i)
        if data[skey] then
          bd['setup'..string.format('%i',i)..'_sysx'] = data[skey]
        end

      end
      if not errormap then
        local xfn = string.match(fn, '.+[\\/](.*).skctlmap')
        local xpath = string.match(fn, '(.+[\\/]).*.skctlmap')
        local path = --[[paths.controllermaps]] xpath .. xfn ..'/' 
        local lfn = path..'device_data.txt'
        local imagefn = path..'device_img.png'
        
        if not reaper.file_exists(lfn) then
          DBG('Error loading file: '..lfn)
          error2 = true
        end
        if not reaper.file_exists(imagefn) then
          DBG('Error loading file: '..imagefn)
          error2 = true
        end
      else
        DBG('Error in skctlmap file: F'..string.format('%i',errormap))
      end
      
      
      if not errormap and not error2 then
        --Import device image
        --Import control location data

        local bd = lvar.buttdata
        local data_idx = {}
        for i = 1, #bd do
          data_idx[bd[i].name] = i
        end
        
        data = {}
        local xfn = string.match(fn, '.+[\\/](.*).skctlmap')
        local xpath = string.match(fn, '(.+[\\/]).*.skctlmap')
        local path = --[[paths.controllermaps]] xpath .. xfn ..'/' 
        local lfn = path..'device_data.txt'
      
        for line in io.lines(lfn) do
          local idx, val = string.match(line,'%<(.-)%>(.*)') --decipher(line)
          if idx then
            data[idx] = val
          end
        end

        local data_idx2 = {}
        
        for a, bb in pairs(data) do
          local l,r,t,b,bcol = string.match(bb, '.-(%d+).-(%d+).-(%d+).-(%d+).-%[(.-)%].*')
          local cl, cr, ct, cb, shape
          shape, cl, cr, ct, cb = string.match(bb, '.-%[.-%].-(%d+).-(%-?%d+).-(%-?%d+).-(%-?%d+).-(%-?%d+)')
          if not shape then
            shape = string.match(bb, '.-%[.-%].-(%d+)')
          end
          if not shape then shape = 0 end
          if bcol == '-' then
            bcol = nil
          end
          
          local idx = data_idx[a]
          if idx then
            bd[idx].x = tonumber(l)
            bd[idx].y = tonumber(t)
            if tonumber(shape) == 0 then
              bd[idx].w = tonumber(r)-tonumber(l)
              bd[idx].h = tonumber(b)-tonumber(t)
            else
              bd[idx].r = tonumber(r)
            end
            bd[idx].shape = tonumber(shape)
            bd[idx].crop_l = tonumber(cl)
            bd[idx].crop_r = tonumber(cr)
            bd[idx].crop_t = tonumber(ct)
            bd[idx].crop_b = tonumber(cb)
            data_idx2[idx] = true
          end

        end

      
        lvar.imagefn = path..'device_img.png'
        LoadControllerImage(obj)
        
        local xx, yy, dsize = 0,0,20
        local imgw, imgh = gfx.getimgdim(lvar.imageidx)
        for idx = 1, #bd do
          if not data_idx2[idx] then
            --create button
            bd[idx].shape = 0
            bd[idx].x = xx
            bd[idx].y = yy
            bd[idx].w = dsize
            bd[idx].h = dsize
            
            xx = xx + dsize+2
            if xx+dsize > imgw then
              xx = 0
              yy = yy + dsize+2
            end
          end
        end
        
      end
      
    end
    --SetCtlMap(d)

  end

  ---------------------------------------------------------
  ---------------------------------------------------------
  
  reaper.gmem_attach('LBX_CM_SharedMem')
  
  gui = GetGUI_vars()  
  init()
  obj = GetObjects()
  
  paths.resource = reaper.GetResourcePath() ..'/Scripts/LBX/'
  paths.controllermaps = paths.resource..'SmartKnobs2_DATA/controller_maps/'
  paths.CMC = paths.resource..'SmartKnobs2_DATA/CMC/'

  reaper.RecursiveCreateDirectory(paths.CMC,1)
  
  --DBG(paths.resource)
  
  lvar.hwnd = GetWindowHwnd('SK2 Controller Map Creator',true)
  
  if reaper.JS_Mouse_LoadCursorFromFile then
    lvar.cursor_invisible = reaper.JS_Mouse_LoadCursorFromFile(paths.resource..'SmartKnobs2_DATA/invisible.cur')
    lvar.hidecursordrag = true
    if not lvar.cursor_invisible or not reaper.JS_Mouse_SetPosition then
      lvar.hidecursordrag = false
    end
  end
  
  --[[local startahk = 'D:/E_BAK/AutoHotkey/SWI_Focus.ahk'
  if reaper.file_exists(startahk) then
    reaper.CF_ShellExecute(startahk)
  end]]
  
  SSPreset_Setup()
  TCPreset_Setup()
  
  SetUpPages()
  
  update_cbox = true
  update_gfx = true
  resize_display = true
  
  LoadData(paths.CMC..'last.cmc')
  SetDefaults()
  
  run()
  reaper.atexit(quit)
  
