local selected = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  table.insert(selected, reaper.GetSelectedMediaItem(0, i))
end

if #selected == 0 then
  reaper.ShowMessageBox("Select at least one MIDI item", "Error", 0)
  return
end

reaper.Undo_BeginBlock()

local changed = 0
local skipped = 0

for _, item in ipairs(selected) do
  local take = reaper.GetActiveTake(item)
  if not take or not reaper.TakeIsMIDI(take) then
    skipped = skipped + 1
  else
    local note_count = reaper.MIDI_CountEvts(take, 0, 0)
    if note_count < 4 then
      skipped = skipped + 1
    else
      local notes = {}
      local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

      for i = 0, note_count - 1 do
        local retval, _, _, startppq, _, _, pitch = reaper.MIDI_GetNote(take, i)
        if retval then
          local t = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq) - item_start
          table.insert(notes, { time = t, pitch = pitch, idx = i })
        end
      end

      if #notes == 0 then
        skipped = skipped + 1
      else
        local total = notes[#notes].time - notes[1].time

        local grid = 1 / 32
        local pitch_map = {}
        for _, n in ipairs(notes) do
          local slot = math.floor(n.time / grid)
          if not pitch_map[slot] then pitch_map[slot] = {} end
          pitch_map[slot][n.pitch] = true
        end

        local min_off = math.floor(0.25 / grid)
        local max_off = math.floor(total * 0.75 / grid)

        local best_off = 0
        local best_score = 0
        for off = min_off, max_off do
          local match = 0
          for _, n in ipairs(notes) do
            if pitch_map[math.floor(n.time / grid) + off] and pitch_map[math.floor(n.time / grid) + off][n.pitch] then
              match = match + 1
            end
          end
          local score = match / #notes
          if score > best_score then
            best_score = score
            best_off = off
          end
        end

        if best_off == 0 or best_score < 0.5 then
          skipped = skipped + 1
        else
          local loop_time = best_off * grid

          for i = note_count - 1, 0, -1 do
            local retval, _, _, startppq = reaper.MIDI_GetNote(take, i)
            if retval then
              local t = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq) - item_start
              if t > loop_time then
                reaper.MIDI_DeleteNote(take, i)
              end
            end
          end

          reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
          changed = changed + 1
        end
      end
    end
  end
end

reaper.Undo_EndBlock("Loop MIDI items at pattern", -1)
reaper.UpdateArrange()

local msg = string.format("%d items looped", changed)
if skipped > 0 then
  msg = msg .. string.format("\n%d skipped (non-MIDI, <4 notes, or no pattern)", skipped)
end
reaper.ShowMessageBox(msg, "Done", 0)
