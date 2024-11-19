
  local SCRIPT = 'LBX_SK_RRSETTINGS'
  
  local flags = {}
  --flags.merge = 1
  --flags.extend = 1
  --flags.overdubnotes = 1
  --flags.timeselection = 0
  
  local exception_cc = {}
  exception_cc[0] = true
  exception_cc[32] = true
  
  local glob_Play_Start_Pos
  local glob_Play_Start_Pos2
  
  local TrackOffset
  local Sel_Track_ID
  local TrackName
  local MSG_Count
  local Take_ID
  local RESET
  local Undo_Text
  local Ins_Note = 0
  local Ins_CC = 0 
  local single_item
  local Merge_Item
  local CCFlag
  local NoteFlag
  local CCs = {}
  local earlyCCs = {}

  local Comp_Latency
  local B_Latency
  local Latency
  local Proj_Offset

  local gmem_rd = reaper.gmem_read

  local d_msgdata = 0
  local d_other = 8388000
  local d_comp_latency = 8388100
  local d_b_latency = 8388101
  
  local d_active = 8388102
  local d_current = 8388103 
  local d_total = 8388104
  
  local d_clearbuf = 8388105
  local d_playpos = 8388106
  local d_playpos2 = 8388107

  local conv32_2 = 399998
  local conv32_1 = 399997
  
  local ccstamp_active = 399999
  local ccstamp_cc_active = 400000
  local ccstamp_cc_val = 400128
  local ccstamp_cc_enabled = 400384

  local rrrec_data = {}
  rrrec_data.tracknum = 3049990
  rrrec_data.itemnum = 3049991
  rrrec_data.takenum = 3049992
  rrrec_data.slotinfo_cnt = 3049993
  rrrec_data.mutedindexes_cnt = 3049994
  rrrec_data.mutednotesindexes_cnt = 3049995
  rrrec_data.dataset = 3049998
  rrrec_data.resetdata = 3049999
  rrrec_data.slotinfo = 3050000 --500
  rrrec_data.slotinfo_pp = 3050500 --500
  rrrec_data.mutedindexes = 3051000 
  rrrec_data.mutednotesindexes = 3100000
  
  notes_played = 8388108
  cc64_played = 8388109
  cc1_played = 8388110
  pb_played = 8388111
  
  local items
  local buf

  local GUI_TITLE = "SRD SMART CONTROL"
  
  local Max_Pos, Min_Pos, Play_Start_Pos, End_Pos
  
  local autoQ
  local autoQ_strength
  
  local function round(num, idp)
    --if tonumber(num) == nil then return num end    
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
  end
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end        
  
  function DBGTab(t)
    if t==nil then t="nil" end
    for i = 1, #t do
      reaper.ShowConsoleMsg(tostring(t[i])..' ')
    end
    reaper.ShowConsoleMsg('\n')
  end      

  function Progress(txt, bar)
  
    if reaper.JS_Window_Find then
      local w, h = 200, 50
                        
      local wid = reaper.JS_Window_Find(GUI_TITLE,true)
      local wdc = reaper.JS_GDI_GetClientDC(wid)
      
      local retval, left, top, right, bottom = reaper.JS_Window_GetRect(wid)
      local xywh = {x = math.floor(((right-left)/2)-w/2),
                    y = math.floor(((bottom-top)/2)-h/2),
                    w = w,
                    h = h}
      
      local col = reaper.JS_GDI_CreateFillBrush(8289919)
      local col2 = reaper.JS_GDI_CreateFillBrush(0)
      local pen0 = reaper.JS_GDI_CreatePen(1, 0)
      local pen = reaper.JS_GDI_CreatePen(2, 0xFF8000)
      local fnt = reaper.JS_GDI_CreateFont(20, 1, 0, false, false, false, 'Calibri')
      reaper.JS_GDI_SelectObject(wdc, fnt)
      reaper.JS_GDI_SetTextBkMode(wdc, 0)
      reaper.JS_GDI_SetTextColor(wdc, 0)
  
      reaper.JS_GDI_SelectObject(wdc, pen0)
      reaper.JS_GDI_SelectObject(wdc, col)
      reaper.JS_GDI_FillRoundRect(wdc, xywh.x, xywh.y, xywh.x+xywh.w, xywh.y+xywh.h, 20, 20)
      reaper.JS_GDI_SelectObject(wdc, col2)
      if bar > 0 then
        reaper.JS_GDI_SelectObject(wdc, pen)
        reaper.JS_GDI_FillRect(wdc, xywh.x+10, xywh.y+xywh.h-10, math.floor(xywh.x+((xywh.w-20)*bar)),xywh.y+xywh.h-8)
      end
      reaper.JS_GDI_DrawText(wdc, txt, string.len(txt), xywh.x, xywh.y+10, xywh.x+xywh.w, xywh.y+xywh.h, 'VCENTER HCENTER')
    
      reaper.JS_GDI_DeleteObject(col)
      reaper.JS_GDI_DeleteObject(col2)
      reaper.JS_GDI_DeleteObject(pen)
      reaper.JS_GDI_DeleteObject(fnt)
      reaper.JS_GDI_ReleaseDC(wid, wdc)
      
      gfx.update()
      
    end
     
  end 
  
  function StampCCs(Take_ID, ts_startppq)
    --ShowConsoleMsg("\nwriting default ccs:");
    --reaper.gmem_attach('')
    reaper.gmem_attach('LBX_SK2_SharedMem')
    
    local gmem = reaper.gmem_read
    if gmem(ccstamp_active) == 1 then
      cc = 0
      pos = 0
      if flags.timeselection == 1 and ts_startppq then
        pos = ts_startppq
      end
      msgType = 176
      msgChannel = 0
      for i = 1, 128 do
        if gmem(ccstamp_cc_active+cc) == 1 and gmem(ccstamp_cc_enabled+cc) == 1 and 
           gmem(ccstamp_cc_val+cc) >= 0 then
          reaper.MIDI_InsertCC(Take_ID,1,0, pos, msgType , msgChannel, cc, gmem(ccstamp_cc_val+cc))
        end
        cc=cc+1
      end
    end

    --reaper.gmem_attach('')
    reaper.gmem_attach('LBX_RRData')
  end
  
  function GlueExistingItems(Play_Start_Pos, End_Pos)
  --40362 - glue items
  --40289 - unselect all
  
    reaper.Main_OnCommand(40289,-1)
    local itemidx = 0
    local track = Sel_Track_ID
    local item = reaper.GetTrackMediaItem(track, itemidx)
    local itemSP 
    local itemEP
    local pos, len
    local glue = 0
    while item do
    
      pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
      len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
      itemSP = pos
      itemEP = pos+len
      if (Play_Start_Pos >= pos and Play_Start_Pos < pos+len) or
         (Play_Start_Pos <= pos and End_Pos >= pos) or
         (Play_Start_Pos < pos+len and End_Pos >= pos+len) then
        glue = glue + 1
        reaper.SetMediaItemSelected(item, true)
      end
      if pos > End_Pos then
        break
      end
      itemidx = itemidx + 1
      item = reaper.GetTrackMediaItem(track, itemidx)
    end
    if glue > 1 then
      reaper.Main_OnCommand(40362,-1)
    end
  end
  
  function RestoreMutedData()
    
    --Get Info
    local gmem = reaper.gmem_read
    if gmem(rrrec_data.dataset) ~= 1 then return end
    
    local gmem_wr = reaper.gmem_write
    gmem_wr(rrrec_data.dataset, 0)
    
    local trn = gmem(rrrec_data.tracknum)-1
    local itmn = gmem(rrrec_data.itemnum)
    local taken = gmem(rrrec_data.takenum)
    local slotcnt = gmem(rrrec_data.slotinfo_cnt)
    local mutedcnt = gmem(rrrec_data.mutedindexes_cnt)
    local mutednotescnt = gmem(rrrec_data.mutednotesindexes_cnt)
    
    --if slotcnt > 0 then
      local slotidx = {}
      local slotidx_14bit = {}
      for i = 0, slotcnt-1 do
        local code = gmem(rrrec_data.slotinfo + i)
        local chan = (code >> 7) & 15
        local cc = (code & 127)
        local cc14bit = (code >> 11) & 1
        local pp = gmem(rrrec_data.slotinfo_pp + i)
        slotidx[chan..'_'..cc] = pp
        if cc14bit == 1 then
          slotidx[chan..'_'..string.format('%i',cc+32)] = pp
        end
      end
      
      local mutedidx = {}
      if mutedcnt > 0 then
        for i = 0, mutedcnt-1 do
          local idx = gmem(rrrec_data.mutedindexes + i)
          mutedidx[idx] = true
        end
      end

      local mutednotesidx = {}
      if mutednotescnt > 0 then
        for i = 0, mutednotescnt-1 do
          local idx = gmem(rrrec_data.mutednotesindexes + i)
          mutednotesidx[idx] = true
        end
      end

      local exception_cc = exception_cc

      gmem_wr(rrrec_data.resetdata, 1)

      local track = reaper.GetTrack(0, trn)
      if track then
        local item = reaper.GetTrackMediaItem(track, itmn)
        if item then
          local take = reaper.GetMediaItemTake(item, taken)
          if take then
            reaper.Undo_BeginBlock2(0)
            
            local ts_start, ts_end, ts_sppq, ts_eppq = GetTS(take)
            local takes = {}
            takes[0] = take
            
            local itemnum = 0
            local itemcnt = 0
            if flags.timeselection == 1 and ts_start then
              --potential multiple items
              local item = reaper.GetMediaItemTake_Item(take)
              local item_n = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
              local track = reaper.GetMediaItemInfo_Value(item, 'P_TRACK')
              
              item_n = item_n + 1
              local item2 = reaper.GetTrackMediaItem(track, item_n)
              while item2 do 
                itemcnt = itemcnt + 1
                local spos = reaper.GetMediaItemInfo_Value(item2, 'D_POSITION')
                if spos >= ts_end then
                  break
                end
                takes[itemcnt] = reaper.GetActiveTake(item2) 
                item_n = item_n + 1
                item2 = reaper.GetTrackMediaItem(track, item_n)
              end
            end
      
            for t = 0, itemcnt do
            
              local take = takes[t]  
              local itemnum = t
               
              if take and reaper.TakeIsMIDI(take) then
            
                reaper.MIDI_DisableSort(take)
                local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
                for i = 0, ccevtcnt do
                  local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
                  local pos = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
                  local playpos = slotidx[chan..'_'..msg2]
                  if (playpos and pos >= playpos and (flags.timeselection ~= 1 or ts_start == nil)) 
                     or (ts_start and pos >= ts_start and pos <= ts_end) then
                  --if pp and pos >= pp then
                    if muted and not mutedidx[(itemnum<<24)+i] then
                      --unmute
                      reaper.MIDI_SetCC(take, i, nil, false, nil, nil, nil, nil, nil, nil)
                    end
                  end
                end
                if flags.overdubnotes ~= 1 and flags.notesplayed == 1 then
                  for i = 0, notecnt do
                    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
                    if muted and not mutednotesidx[(itemnum<<24)+i] then
                      --unmute
                      reaper.MIDI_SetNote(take, i, nil, false, nil, nil, nil, nil, nil, nil)
                    end
                  end
                  for i = 0, ccevtcnt do
                    local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
                    if (chanmsg == 208 or chanmsg == 224) then 
                      if muted and not mutedidx[(itemnum<<24)+i] then
                        --unmute
                        reaper.MIDI_SetCC(take, i, nil, false, nil, nil, nil, nil, nil, nil)
                      end
                    end
                  end
                end
                reaper.MIDI_Sort(take)
              end
            end
            
            reaper.Undo_EndBlock2(0, "Restore CC's", 0)
          end
        end
      end
    --end
  
  end
  
  function GetTS(take, noppq)
  
    if flags.timeselection == 1 then
      local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false) 
      if start_time ~= end_time then
        if not noppq then
          local sppq = reaper.MIDI_GetPPQPosFromProjTime(take, start_time)
          local eppq = reaper.MIDI_GetPPQPosFromProjTime(take, end_time)
          return start_time, end_time, sppq, eppq
        else
          return start_time, end_time
        end
      end
    end
  
  end
  
  function Read_Data_From_JS()
  
    local err = 0.001 --used to correct minor play position inaccuracies
    
    --DBG('Track Offset Read Data: '..TrackOffset)
    
    local gmem_rd = reaper.gmem_read
    local gmem_wr = reaper.gmem_write
  
    gmem_wr(d_active, 2)
  
    Comp_Latency = gmem_rd(d_comp_latency) --;//Get "Compensate latency" slider value
    B_Latency = gmem_rd(d_b_latency)
    
    --MSG_Count = gmem_rd(d_other+5)
    --Item_Count = gmem_rd(d_other+6)
    
    if Comp_Latency == 1 then 
      Latency=B_Latency+reaper.GetOutputLatency() 
    else 
      Latency=0 --;//Total Latency
    end
    Proj_Offset = reaper.GetProjectTimeOffset(0, false--[[rndframe]]) --;//Project Offset
    Play_Start_Pos = glob_Play_Start_Pos-Proj_Offset --gmem_rd(d_playpos)-Proj_Offset --reaper.GetCursorPosition();
    --DBG('----  '..gmem_rd(d_playpos)..'  '..d_playpos)
    gmem_wr(d_total, MSG_Count-1) 
    
    --//======Read MIDI-DATA and Pos Change Data========//  
    items = {}
    buf = {}
    
    --DBG(gmem_rd(d_other+5))
    
    if MSG_Count > 0 then
      local i=0
      local j=0 
      
      local cc_start_pos
      local cc_end_pos

      local note_start_pos
      local note_end_pos
      
      local minp, maxp = gmem_rd(i), gmem_rd(i)
      
      for mc = 0, MSG_Count-1 do
        
        i = mc*4
        buf[i] = gmem_rd(i) -TrackOffset --TrackFX_GetParam(Track_ID, FX_index,2, minval, maxval) --;//Get MSG_Position            
        --//Read msg1,2,3//
        buf[i+1] = gmem_rd(i+1)
        buf[i+2] = gmem_rd(i+2) 
        buf[i+3] = gmem_rd(i+3)            
        
        minp = math.min(minp, buf[i])
        maxp = math.max(maxp, buf[i])
        
        --//=====Analize and Save Items-Data to items[.,.,.,.]======//
        if buf[i+1]==-1 then
          items[j]=i/4 --;//First Msg Num in Item(0-based)
          items[j+1]=0 --;//Take_ID(Will be assigned later)
          items[j+2]=buf[i] --;);//Item Start Pos                    
        elseif buf[i+1]==-2 then
          items[j+3]=buf[i] --;//Item End Pos
          j = j+4 --;);//j+=4=Next cycle
        else
          msgType = (buf[i+1] & 240) 
          if msgType == 176 then
            CCFlag = true
            if not CCs[tonumber(buf[i+2])] then
              CCs[tonumber(buf[i+2])] = true
            end
            local pos = buf[i]-(Proj_Offset+Latency)
            if cc_start_pos == nil then
              cc_start_pos = pos
            end
            cc_end_pos = math.max(pos, cc_end_pos or pos)
          elseif msgType == 144 or msgType == 128 then
            NoteFlag = true
            local pos = buf[i]-(Proj_Offset+Latency)
            if msgType == 144 and note_start_pos == nil then
              note_start_pos = pos
            end
            if msgType == 144 or msgType == 128 then
              note_end_pos = math.max(pos, note_end_pos or pos)
            end
          end  
        end
        i = i+4;    
      end
  
      --//============First and Last Msg in First and Last Items=================//
      items[0]=0 --;//0-st Msg in 0-st Item Num(anyway)*
      items[0+1]=0 --;//Take_ID(Will be assigned later)
      
      items[0+2]=buf[0]-Latency --;//0-st Start=0-st MsgPos(anyway)*
      items[j+3]=buf[i-4]-Latency --;//Last Item End=Last MsgPos(anyway)*
      
      if j == 0 then
        single_item = true
      end
      
      --Play_Start_Pos = gmem_rd(d_playpos)-Proj_Offset --reaper.GetCursorPosition();
      reaper.SetEditCurPos(maxp-Proj_Offset, false, false);
      --store current endpos
      Min_End_Pos = reaper.GetCursorPosition();
      
      if flags.extend == 1 then
        _, grid, _, _ = reaper.GetSetProjectGrid(0, false) -- get grid
        reaper.GetSetProjectGrid(0, true, 1) -- set grid
        
        reaper.Main_OnCommand(40837, 1);
        --DBG(Min_End_Pos..'  '..reaper.BR_GetClosestGridDivision(Min_End_Pos))
        if Min_End_Pos < reaper.BR_GetClosestGridDivision(Min_End_Pos) then
          reaper.Main_OnCommand(40837, 1); --add additional measure for safety
        end
        reaper.GetSetProjectGrid(0, true, grid) -- set grid
      end
      
      End_Pos = reaper.GetCursorPosition();
      reaper.SetEditCurPos(Play_Start_Pos, false, false);
    
      if single_item then
      
        --GlueExistingItems(Play_Start_Pos, End_Pos, Sel_Track_ID)
      
        local itemidx = 0
        local track = Sel_Track_ID
        local item = reaper.GetTrackMediaItem(track, itemidx)
        local itemSP 
        local itemEP
        
        local ts_start_time, ts_end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        
        while item do
          pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
          len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
          itemSP = pos
          itemEP = pos+len
          --DBG(round(Play_Start_Pos,3)..'  '..round(pos,3)..'  '..round(Min_End_Pos,3))
          
          if flags.timeselection ~= 1 then
            if (Play_Start_Pos >= pos and Play_Start_Pos+err < itemEP) or
               (Play_Start_Pos <= itemSP and Min_End_Pos > itemSP) or
               (Play_Start_Pos+err < itemEP and Min_End_Pos >= itemEP) then
              Merge_Item = item
              break
            elseif Min_End_Pos <= itemSP then
              break
            end
          else
            if ((Play_Start_Pos >= pos and Play_Start_Pos+err < itemEP) or
               (Play_Start_Pos <= itemSP and Min_End_Pos > itemSP) or
               (Play_Start_Pos+err < itemEP and Min_End_Pos >= itemEP)) and
               (itemSP <= ts_start_time and itemEP > ts_start_time) or 
               (itemSP >= ts_start_time and itemSP < ts_end_time) then
              Merge_Item = item
              break
            elseif Min_End_Pos <= itemSP then
              break
            end
          end
          
          itemidx = itemidx + 1
          item = reaper.GetTrackMediaItem(track, itemidx)
        end
        
        if flags.merge ~= 1 then
          Merge_Item = nil
        end

        if Merge_Item then
          j = 0
          Item_ID = Merge_Item

          if flags.timeselection == 1 then
          
            local ssp = itemSP
            local sep = itemEP
            if itemSP > ts_start_time then
              ssp = ts_start_time
            end
            if itemEP < ts_end_time then
              sep = ts_end_time
            end
          
            local sQ = reaper.TimeMap2_timeToQN(0, ssp) --+Latency))
            local eQ = reaper.TimeMap2_timeToQN(0, sep)
            reaper.MIDI_SetItemExtents(Item_ID, sQ, eQ)
          end

          --get active take
          local take = reaper.GetActiveTake(Merge_Item)
          Take_ID = take
          items[j+1] = Take_ID --;//Save ID
          
          local NewName = TrackName --..string.format('%i',j/4+1)
          reaper.GetSetMediaItemTakeInfo_String(Take_ID, "P_NAME", NewName , 1) --;//Rename Item to parent Track name+Number
          reaper.SetMediaItemSelected(Item_ID, 1) --;//SELECT NEW ITEM!*  
          
          local sp = math.min(Play_Start_Pos, itemSP)
          local ep = math.max(End_Pos, itemEP)
          Min_End_Pos = math.max(Min_End_Pos, itemEP)
          Play_Start_Pos = sp
          End_Pos = ep
          
          Item_Start = sp --;//Item_Start
          Item_End   = ep --;//Item_End

          local ts_start, ts_end, ts_sppq, ts_eppq = GetTS(take)
          
          --remove CC's in bounds
          local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
          if CCFlag or NoteFlag then
            --[[local s_ppQ, e_ppQ, s_ppQN, e_ppQN
            if CCFlag then
              s_ppQ = reaper.MIDI_GetPPQPosFromProjTime(take, cc_start_pos)
              e_ppQ = reaper.MIDI_GetPPQPosFromProjTime(take, cc_end_pos)
            end
            if NoteFlag then
              s_ppQN = reaper.MIDI_GetPPQPosFromProjTime(take, note_start_pos)
              e_ppQN = reaper.MIDI_GetPPQPosFromProjTime(take, note_end_pos)
            end]]

            local dcnt = 0
            --reaper.MIDI_SelectAll(take, true)
            reaper.MIDI_DisableSort(take)
            
            for cc = ccevtcnt-1, 0, -1 do
              retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, cc)
              local pos = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
              if (CCFlag and chanmsg == 176) then
                if pos < (ts_start or cc_start_pos) and pos < (ts_start or (note_start_pos or math.huge)) and flags.timeselection ~= 1 then
                  break
                elseif pos >= (ts_start or cc_start_pos) and pos <= (ts_end or cc_end_pos) and CCs[tonumber(msg2)] then
                  reaper.MIDI_DeleteCC(take, cc)
                  dcnt = dcnt + 1
                end
              elseif (NoteFlag and flags.overdubnotes ~= 1 and 
                      (chanmsg == 208 or 
                       chanmsg == 224)) then
                if pos < (ts_start or note_start_pos) and pos < (ts_start or (cc_start_pos or math.huge)) and flags.timeselection ~= 1 then
                  break
                elseif pos >= (ts_start or note_start_pos) and pos <= (ts_end or note_end_pos) then
                  reaper.MIDI_DeleteCC(take, cc)
                  dcnt = dcnt + 1
                end
              end
            end
          end
          if NoteFlag then
            if flags.overdubnotes ~= 1 then
              --local s_ppQ = reaper.MIDI_GetPPQPosFromProjTime(take, note_start_pos)
              --local e_ppQ = reaper.MIDI_GetPPQPosFromProjTime(take, note_end_pos)
              
              local dcnt = 0
              --reaper.MIDI_SelectAll(take, true)
              reaper.MIDI_DisableSort(take)
              for note = notecnt-1, 0, -1 do
                retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note)
                local spos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
                local epos = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
                if (epos < (ts_start or note_start_pos)) and flags.timeselection ~= 1 then
                  break
                elseif (spos >= (ts_start or note_start_pos) and spos < (ts_end or note_end_pos))  then
                  reaper.MIDI_DeleteNote(take, note)
                  dcnt = dcnt + 1
                end
              end
            end
          end
          
          if (NoteFlag and flags.overdubnotes ~= 1) or CCFlag then
            reaper.MIDI_Sort(take)
          end
          
        end
      end
      if not Merge_Item then
        --//====================Create Items and save ID to items[j+1]=================================// 
        j=0
        reaper.SelectAllMediaItems(0,0) --;//UNSEL ALL ITEMS in Project
        for ic = 1, Item_Count do
          Item_Start = Play_Start_Pos --;//Item_Start
          Item_End = End_Pos --;//Item_End
          local ts_start, ts_end = GetTS(take, true)

          if flags.timeselection == 1 and ts_start then
            Item_Start = ts_start
            Item_End = ts_end
          end
          Item_ID = reaper.CreateNewMIDIItemInProj(Sel_Track_ID, Item_Start, Item_End, qnInOpt)
          reaper.SetMediaItemInfo_Value(Item_ID, "B_LOOPSRC", 0)       
          Take_ID = reaper.GetActiveTake(Item_ID) --;//Get Active Take from Item 
          items[j+1] = Take_ID --;//Save ID          
          local NewName = TrackName --..string.format('%i',j/4+1)
          reaper.GetSetMediaItemTakeInfo_String(Take_ID, "P_NAME", NewName , 1) --;//Rename Item to parent Track name+Number
          reaper.SetMediaItemSelected(Item_ID, 1) --;//SELECT NEW ITEM!*  
          j = j+4;
        end
      end
    end
    return Play_Start_Pos+err, End_Pos
  end
  
  function Insert_MIDI()
  
    local sel = false
    local muted = false
    local startpos
    
    reaper.SetOnlyTrackSelected(Sel_Track_ID) --;//Select-ONLY TRACK 
    
    i=0
    j=0
    --Take_ID=0
    local ts_start, ts_end, ts_sppq, ts_eppq = GetTS(Take_ID)
    
    local ts_sppq_grace = 10 --ts grace period
    
    local Take_ID = nil
    local ccevtcnt
    for mc = 1, MSG_Count do  
      if i/4==items[j] then
        if Take_ID then
          reaper.MIDI_Sort(Take_ID) --;//MIDI_Sort Prev_Take if Exist
        end --//Set New Take for Insert MIDI
        Take_ID=items[j+1]
        --_, _, ccevtcnt = reaper.MIDI_CountEvts(Take_ID)
        ts_start, ts_end, ts_sppq, ts_eppq = GetTS(Take_ID)
        j = j+4
        reaper.MIDI_DisableSort(Take_ID)
        
        StampCCs(Take_ID, ts_sppq)
      end
         
      --//=========Create MIDI-EVENTS in Current Item============// 
      Msg_Time_Pos = buf[i]-(Proj_Offset+Latency)
      PPQ_Pos = reaper.MIDI_GetPPQPosFromProjTime(Take_ID, Msg_Time_Pos)
      startpos = startpos or Msg_Time_Pos
      msgType = (buf[i+1] & 240) --  // message type nibble
      msgChannel = (buf[i+1] & 15) --; // channel nibble(0-15)    
      msg2 = buf[i+2]
      msg3 = buf[i+3]
      --//==For each Note ON(144)-------Find Note OFF(128)-------and Insert Note==//
      if msgType==144 and msg3>0 then
        Store_Take_ID=Take_ID
        Off_Send=0
        i_2=i+4
        j_2=j
        
        while (Off_Send==0 and MSG_Count>i_2/4) do --//Main Condition
          msgType_2 = (buf[i_2+1] & 240)
          msgChannel_2 = (buf[i_2+1] & 15)
          msg2_2 = buf[i_2+2]
          msg3_2 = buf[i_2+3]
            
          --//=====If Note OFF not found in current item=====//
          if i_2/4==items[j_2] then
            PPQ_Item_End = reaper.MIDI_GetPPQPosFromProjTime(Take_ID,items[j_2-4+3]-Proj_Offset) --;//PPQ=End

            if PPQ_Pos >= (ts_sppq or PPQ_Pos) and PPQ_Pos <= (ts_eppq or PPQ_Pos) then
            
              if autoQ == 1 then
                local closest_grid = reaper.BR_GetClosestGridDivision(Msg_Time_Pos) -- get closest grid for current note (return value in seconds)
                local closest_grid_ppq = reaper.MIDI_GetPPQPosFromProjTime(Take_ID, closest_grid) -- convert closest grid to PPQ
                if closest_grid_ppq ~= PPQ_Pos then -- if notes are not on the grid
                  local diff = (closest_grid_ppq-PPQ_Pos)*(autoQ_strength/100)
                  PPQ_Pos = PPQ_Pos + diff
                  PPQ_Item_End = PPQ_Item_End + diff
                end
              end
              reaper.MIDI_InsertNote(Take_ID,sel,muted, PPQ_Pos, PPQ_Item_End , msgChannel, msg2, msg3, 1)
            end
            Take_ID = items[j_2+1]
            j_2=j_2+4 --;//New take ID
            PPQ_Pos = reaper.MIDI_GetPPQPosFromProjTime(Take_ID,items[j_2-4+2]-Proj_Offset) --;//PPQ=Start
          end
          if (msgType_2==128 or (msgType_2==144 and msg3_2==0)) and msgChannel_2==msgChannel and msg2_2==msg2 then
            Msg_Time_Pos_2 = buf[i_2]-(Proj_Offset+Latency)
            PPQ_Pos_2 = reaper.MIDI_GetPPQPosFromProjTime(Take_ID, Msg_Time_Pos_2)
            
            if PPQ_Pos >= (ts_sppq or PPQ_Pos) and PPQ_Pos <= (ts_eppq or PPQ_Pos) then
            
              if autoQ == 1 then
                local closest_grid = reaper.BR_GetClosestGridDivision(Msg_Time_Pos) -- get closest grid for current note (return value in seconds)
                local closest_grid_ppq = reaper.MIDI_GetPPQPosFromProjTime(Take_ID, closest_grid) -- convert closest grid to PPQ
                if closest_grid_ppq ~= PPQ_Pos then -- if notes are not on the grid
                  local diff = (closest_grid_ppq-PPQ_Pos)*(autoQ_strength/100)
                  PPQ_Pos = PPQ_Pos + diff
                  PPQ_Pos_2 = PPQ_Pos_2 + diff
                end
              end
              
              reaper.MIDI_InsertNote(Take_ID,sel,muted, PPQ_Pos, PPQ_Pos_2 , msgChannel, msg2, msg3, 1)
              Ins_Note=Ins_Note+1
            end
            Off_Send=1
          end
          i_2 = i_2+4
        end
        Take_ID=Store_Take_ID
        
      end
      
      --//==For PKeyPressue,ControlChange,ProgrammChange,ChanPressue,PWheel Change---Insert==//
      if msgType==160 or msgType==176 or msgType==192 or msgType==208 or msgType==224 then 
        if PPQ_Pos >= (ts_sppq or PPQ_Pos) and PPQ_Pos <= (ts_eppq or PPQ_Pos) then
        
          if flags.timeselection == 1 and msgType==176
             and PPQ_Pos > ts_sppq + ts_sppq_grace 
             and earlyCCs[(msgChannel<<7) + msg2] then
            --Insert early CC at TS start
            reaper.MIDI_InsertCC(Take_ID,1,0, ts_sppq, msgType , msgChannel,  msg2, earlyCCs[(msgChannel<<7) + msg2])
            Ins_CC=Ins_CC+1
            _, _, ccevtcnt = reaper.MIDI_CountEvts(Take_ID)
            reaper.MIDI_SetCCShape(Take_ID, ccevtcnt-1, 1, 1, true)
            earlyCCs[(msgChannel<<7) + msg2] = nil --clear cc once inserted
          end
        
          reaper.MIDI_InsertCC(Take_ID,1,0, PPQ_Pos, msgType , msgChannel,  msg2, msg3 )
          Ins_CC=Ins_CC+1
          _, _, ccevtcnt = reaper.MIDI_CountEvts(Take_ID)
          if msgType == 176 and msg2 ~= 64 and msg2 ~= 66 and msg2 ~= 67 then
            reaper.MIDI_SetCCShape(Take_ID, ccevtcnt-1, 1, 1, true)
          else
            reaper.MIDI_SetCCShape(Take_ID, ccevtcnt-1, 0, 1, true)
          end
        elseif flags.timeselection == 1 and msgType==176 and PPQ_Pos < ts_sppq then
          --store latest 'early' CC
          earlyCCs[(msgChannel<<7) + msg2] = msg3
        end
      end
      i= i+4
    end 
    
    --run through any uninserted early CC's
    if flags.timeselection == 1 then
      local msgType = 176
      for a, msg3 in pairs(earlyCCs) do
        local msgChannel = a >> 7
        local msg2 = a & 127
        reaper.MIDI_InsertCC(Take_ID,1,0, ts_sppq, msgType , msgChannel, msg2, msg3)
        Ins_CC=Ins_CC+1
        --make it square as no CC's captured within TS.
        _, _, ccevtcnt = reaper.MIDI_CountEvts(Take_ID)
        reaper.MIDI_SetCCShape(Take_ID, ccevtcnt-1, 0, 1, true)
        lastcc = lastcc + 1
      end
    end
    
    reaper.MIDI_Sort(Take_ID) --;//MIDI_Sort Last_Take
    return startpos, Take_ID
  end
  
  function StoreSelectedItems()
    
    local cnt = reaper.CountSelectedMediaItems(0)
    if cnt > 0 then
      for i = 0, cnt-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local itemguid = reaper.BR_GetMediaItemGUID(item)
        
        local key = 'ITEM_'..string.format('%i',i)..'_'
        reaper.SetExtState(SCRIPT, key..'seli_guid', itemguid, false)
        
      end
    end
    reaper.SetExtState(SCRIPT, 'seli_count', cnt, false)
    
  end
  
  function RestoreSelectedItems()

    local cnt2 = tonumber(reaper.GetExtState(SCRIPT,'seli_count')) or 0
    if cnt2 > 0 then
    
      --Store current
      local cnt = reaper.CountSelectedMediaItems(0)
      local iguids = {}
      
      if cnt > 0 then
        for i = 0, cnt-1 do
          local item = reaper.GetSelectedMediaItem(0, i)
          local itemguid = reaper.BR_GetMediaItemGUID(item)
          iguids[i] = itemguid
        end
      end
    
      reaper.SelectAllMediaItems(0,0)
      for i = 0, cnt2-1 do
        local key = 'ITEM_'..string.format('%i',i)..'_'
        local guid = reaper.GetExtState(SCRIPT, key..'seli_guid')
        local item = reaper.BR_GetMediaItemByGUID(0, guid)
        if item then
          reaper.SetMediaItemInfo_Value(item, 'B_UISEL', 1)
        end
      end
      if cnt > 0 then
        for i = 0, cnt-1 do
          local key = 'ITEM_'..string.format('%i',i)..'_'
          reaper.SetExtState(SCRIPT, key..'seli_guid', iguids[i], false)
        end
      end
      reaper.SetExtState(SCRIPT, 'seli_count', cnt, false)

      --reaper.UpdateArrange()
    end
  end
  
  ----------------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------

  reaper.PreventUIRefresh(1)
  
  --reaper.gmem_attach('')
  reaper.gmem_attach('LBX_RRData')
  --DBG(reaper.gmem_read(d_playpos))
  glob_Play_Start_Pos = reaper.gmem_read(d_playpos)
  glob_Play_Start_Pos2 = reaper.gmem_read(d_playpos2)
  --[[if glob_Play_Start_Pos ~= glob_Play_Start_Pos2 then
    reaper.ShowConsoleMsg(glob_Play_Start_Pos..'  '..glob_Play_Start_Pos2..'\n')
  end]]
  
  reaper.gmem_write(d_active,1)

  --Load Settings
  autoQ = tonumber(reaper.GetExtState(SCRIPT,'autoquantize')) or 0 
  autoQ_strength = tonumber(reaper.GetExtState(SCRIPT,'quantize_strength')) or 100
  
  --flags.splitmerge = 0
  flags.merge = tonumber(reaper.GetExtState(SCRIPT,'merge')) or 1
  flags.extend = tonumber(reaper.GetExtState(SCRIPT,'extend')) or 1
  flags.overdubnotes = tonumber(reaper.GetExtState(SCRIPT,'overdubnotes')) or 1
  flags.timeselection = tonumber(reaper.GetExtState(SCRIPT,'timeselection')) or 0
  flags.trackoffset = tonumber(reaper.GetExtState(SCRIPT,'trackoffset')) or 0
  flags.notesplayed = gmem_rd(notes_played) 

  --reaper.gmem_attach('')
  reaper.gmem_attach('LBX_SK2_SharedMem')
  RestoreMutedData()
  --reaper.gmem_attach('')
  reaper.gmem_attach('LBX_RRData')
  
  StoreSelectedItems()
  reaper.SelectAllMediaItems(0,0)
  
  local cp = reaper.GetCursorPosition();

  --GetMIDIDataHere - MSG_Count, Item_Count, glob_Play_Start_Pos, glob_Play_Start_Pos2 (stop position)

  MSG_Count = gmem_rd(d_other+5)
  Item_Count = gmem_rd(d_other+6)
    
  Sel_Track_ID = reaper.GetSelectedTrack(0,0) --Get 1-st selected Track ID(For ADD MIDI-DATA)
  if Sel_Track_ID and MSG_Count > 0 then
    TrackOffset = 0
    if flags.trackoffset == 1 then
      local playoffsetflag = reaper.GetMediaTrackInfo_Value(Sel_Track_ID, "I_PLAY_OFFSET_FLAG")
      if playoffsetflag&1~=1 then
        if playoffsetflag&2==2 then
          --convert samples to seconds
          local sampleoffset = reaper.GetMediaTrackInfo_Value(Sel_Track_ID, "D_PLAY_OFFSET")
          local ProjectSampleRate = 1 / reaper.parse_timestr_len( 1, 0, 4 )
          TrackOffset = sampleoffset / ProjectSampleRate
        else        
          TrackOffset = reaper.GetMediaTrackInfo_Value(Sel_Track_ID, "D_PLAY_OFFSET")
        end
      end
    end
    _, TrackName = reaper.GetSetMediaTrackInfo_String(Sel_Track_ID, "P_NAME", '', false) --;//Get Sel_Track_Name(for rename New Item-Takes)  
    RESET=1
     
    reaper.Undo_BeginBlock() --;//Start Undo  
    --//==Read DATA from JS==// 

    local tsst, tset = GetTS(nil, true) --check ts available
    if not (tsst and tset) then
      flags.timeselection = 0
    end

    if flags.timeselection == 1 and flags.merge == 1 then
      --merge items within TS
      -- 40718 - select items in time selection
      -- XX 40061 - split items at time selection
      -- XX 40718 - select items in time selection
      -- 41588 - glue items

      reaper.Main_OnCommand(40718, 0) -- select items in time selection
      -- WTF - MSgCount global memory slot reset to 0 on gluing (next command)????
      -- Is there something in SK2 which would reset when items glued?
      --reaper.Main_OnCommand(40061, 0) -- split at time selection
      reaper.Main_OnCommand(41588, 0) -- glue items
      --reaper.Main_OnCommand(41588, 0) -- glue to remove notes starting outside bounds
      reaper.SelectAllMediaItems(0,0)
      
      --Remove '-glued' from name
      local ic = reaper.CountTrackMediaItems(Sel_Track_ID)
      for i = 0, ic-1 do
        local mi = reaper.GetTrackMediaItem(Sel_Track_ID, i)
        local tk = reaper.GetActiveTake(mi)
        if tk then
          local _, itemnm = reaper.GetSetMediaItemTakeInfo_String(tk, 'P_NAME', '', false)
          local nnm = string.match(itemnm,'(.+)-glued')
          if nnm then
            reaper.GetSetMediaItemTakeInfo_String(tk, 'P_NAME', nnm, true)
          end
        end
      end
    end

    local startpos, endpos
    if Sel_Track_ID then startpos, endpos = Read_Data_From_JS() end --//Call func Read DATA from JS
    
    --//==Insert MIDI-data on the Track(if exist);Implode takes,Activate Last Take==//
    if MSG_Count > 0 then
      
      local startpos2 = Insert_MIDI()
      
      
      
      --Fix item size+position
      if flags.timeselection ~= 1 then
        if (startpos2+0.02) < startpos then
          startpos = glob_Play_Start_Pos2 - Proj_Offset --gmem_rd(d_playpos2)-(Proj_Offset)
          local sQ = reaper.TimeMap2_timeToQN(0, startpos) --+Latency))
          local eQ = reaper.TimeMap2_timeToQN(0, endpos)
          reaper.MIDI_SetItemExtents(Item_ID, sQ, eQ)
        end
  
        if flags.extend == 1 then
          --Fix item size+position
          if Min_End_Pos and Sel_Track_ID then
            --Find next item - prevent overlap
            local itemcnt = reaper.CountTrackMediaItems(Sel_Track_ID)
            local fitem
            for i = itemcnt-1, 0, -1 do
              local citem = reaper.GetTrackMediaItem(Sel_Track_ID, i)
              if citem then
                local csp = reaper.GetMediaItemInfo_Value(citem, 'D_POSITION')
                local cln = reaper.GetMediaItemInfo_Value(citem, 'D_LENGTH')
                local cep = csp+cln
                --DBG(csp..'  '..cep..'  '..startpos..'  '..endpos)
                if csp < endpos then
                  fitem = {item = citem, sp = csp, ep = cep}
                  break
                elseif cep <= startpos then
                  break
                end
              end
            end
            if fitem then
              local nendpos = math.max(fitem.sp, Min_End_Pos)
              if not (nendpos > fitem.sp) then
                endpos = nendpos
              end
            end
            local sQ = reaper.TimeMap2_timeToQN(0, startpos) --+Latency))
            local eQ = reaper.TimeMap2_timeToQN(0, endpos)
            reaper.MIDI_SetItemExtents(Item_ID, sQ, eQ)
          end
          
          --Ensure item start is on measure
          local _, meas = reaper.TimeMap2_timeToBeats(0, startpos)
          local nST = reaper.TimeMap2_beatsToTime(0, 0, meas)
          local itemcnt = reaper.CountTrackMediaItems(Sel_Track_ID)
          local fitem
          for i = 0, itemcnt-1 do
            local citem = reaper.GetTrackMediaItem(Sel_Track_ID, i)
            if citem then
              local csp = reaper.GetMediaItemInfo_Value(citem, 'D_POSITION')
              local cln = reaper.GetMediaItemInfo_Value(citem, 'D_LENGTH')
              local cep = csp+cln
              --DBG(csp..'  '..cep..'  '..startpos..'  '..endpos)
              if nST > csp and nST < cep then
                fitem = {item = citem, sp = csp, ep = cep}
                break
              elseif csp > nST then
                break
              end
            end
          end
          if not fitem then
            --do not extend - item there
            local sQ = reaper.TimeMap2_timeToQN(0, nST)
            local eQ = reaper.TimeMap2_timeToQN(0, endpos)
            reaper.MIDI_SetItemExtents(Item_ID, sQ, eQ)
          end
        end
      end
      
      reaper.Main_OnCommand(40543, 0)
      reaper.SetActiveTake(Take_ID)
          
      if RESET then
        reaper.gmem_write(d_clearbuf,1)
      end
    end --//RESET JS After Script Executed 
    
    reaper.SetEditCurPos(cp, false, false)
    
    if Take_ID then
      local startoffs = reaper.GetMediaItemTakeInfo_Value(Take_ID,'D_STARTOFFS')
      if startoffs < 0.001 then
        reaper.SetMediaItemTakeInfo_Value(Take_ID,'D_STARTOFFS',0)
      end
      reaper.MIDI_SelectAll(Take_ID, false)
    end
    --reaper.MIDIEditor_LastFocused_OnCommand(40214, false)
    --if autoQ == 1 then
    
    --end
    
    local restore = reaper.GetExtState(SCRIPT, 'autorestore')
    if tonumber(restore) == 1 then
      RestoreSelectedItems()
    end
    
    --//==Create #Undo_Text For RRMidi==//       
    Undo_Text = "~RetroRec: "..Ins_Note..'-Notes,'..Ins_CC..'-CC Inserted~' --;//Undo_Text
    reaper.Undo_EndBlock(Undo_Text, -1) --;//End Undo

    reaper.UpdateArrange();
    
  end
  
  reaper.gmem_write(notes_played,0)
  reaper.gmem_write(cc64_played,-1)
  reaper.gmem_write(cc1_played,-1)
  reaper.gmem_write(pb_played,-1)
  reaper.gmem_write(d_active,0)

  reaper.PreventUIRefresh(-1)
  
