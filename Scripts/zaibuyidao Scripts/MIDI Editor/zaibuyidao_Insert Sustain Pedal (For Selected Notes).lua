--[[
 * ReaScript Name: Insert Sustain Pedal (For Selected Notes)
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-24)
  + Initial release
--]]

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local item = reaper.GetMediaItemTake_Item(take)
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end

  local msg2 = reaper.GetExtState("InsertSustainPedalForSelNote", "Msg2")
  local msg3 = reaper.GetExtState("InsertSustainPedalForSelNote", "Msg3")
  local msg4 = reaper.GetExtState("InsertSustainPedalForSelNote", "Msg4")
  local first_offset = reaper.GetExtState("InsertSustainPedalForSelNote", "FirstOffset")
  local second_offset = reaper.GetExtState("InsertSustainPedalForSelNote", "SecondOffset")
  
  if (msg2 == "") then msg2 = "64" end
  if (msg3 == "") then msg3 = "127" end
  if (msg4 == "") then msg4 = "0" end
  if (first_offset == "") then first_offset = "110" end
  if (second_offset == "") then second_offset = "-10" end

  local user_ok, input_csv = reaper.GetUserInputs("Insert Sustain Pedal", 5, "CC Number,1,2,Offset 1,Offset 2", msg2..','..msg3..','.. msg4..','..first_offset..','.. second_offset)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  msg2, msg3, msg4, first_offset, second_offset = input_csv:match("(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) or not tonumber(first_offset) or not tonumber(second_offset) then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("InsertSustainPedalForSelNote", "Msg2", msg2, false)
  reaper.SetExtState("InsertSustainPedalForSelNote", "Msg3", msg3, false)
  reaper.SetExtState("InsertSustainPedalForSelNote", "Msg4", msg4, false)
  reaper.SetExtState("InsertSustainPedalForSelNote", "FirstOffset", first_offset, false)
  reaper.SetExtState("InsertSustainPedalForSelNote", "SecondOffset", second_offset, false)
  
  for i = 1,  #index do
    local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
    if selected == true then
      reaper.MIDI_InsertCC(take, selected, muted, startppqpos + first_offset, 0xB0, chan, msg2, msg3)
      if i > 1 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + second_offset, 0xB0, chan, msg2, msg4)
      end
      if i == #index then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos + second_offset, 0xB0, chan, msg2, msg4)
      end
      reaper.UpdateItemInProject(item)
    end
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Insert Sustain Pedal (For Selected Notes)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()