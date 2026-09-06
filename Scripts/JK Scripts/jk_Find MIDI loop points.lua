local selected = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  table.insert(selected, reaper.GetSelectedMediaItem(0, i))
end

if #selected == 0 then return end

reaper.Undo_BeginBlock()

for _, item in ipairs(selected) do
  local take = reaper.GetActiveTake(item)
  if not take or not reaper.TakeIsMIDI(take) then goto skip end

  local _, note_count = reaper.MIDI_CountEvts(take)
  if note_count < 4 then goto skip end

  local notes = {}
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local track = reaper.GetMediaItemTrack(item)

  for i = 0, note_count - 1 do
    local retval, _, _, startppq, _, _, pitch = reaper.MIDI_GetNote(take, i)
    if retval then
      local t = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq) - item_start
      table.insert(notes, { time = t, pitch = pitch })
    end
  end

  local total = notes[#notes].time
  local grid = 1 / 32

  local pitch_map = {}
  for _, n in ipairs(notes) do
    local slot = math.floor(n.time / grid + 0.5)
    if not pitch_map[slot] then pitch_map[slot] = {} end
    pitch_map[slot][n.pitch] = true
  end

  local min_off = math.floor(0.125 / grid)
  local max_off = math.floor(total * 0.8 / grid)

  local best_off = 0
  local best_score = 0
  for off = min_off, max_off do
    local match = 0
    for _, n in ipairs(notes) do
      local src = math.floor(n.time / grid + 0.5)
      if pitch_map[src + off] and pitch_map[src + off][n.pitch] then
        match = match + 1
      end
    end
    local score = match / note_count
    if score > best_score then
      best_score = score
      best_off = off
    end
  end

  if best_off == 0 or best_score < 0.4 then goto skip end

  local loop_time = best_off * grid

  local split_pos = {}
  local t = loop_time
  while t < total - loop_time * 0.25 do
    local snapped = reaper.SnapToGrid(0, item_start + t)
    if snapped > item_start and snapped < item_start + item_len
        and (#split_pos == 0 or snapped > split_pos[#split_pos]) then
      table.insert(split_pos, snapped)
    end
    t = t + loop_time
  end

  for i = #split_pos, 1, -1 do
    reaper.SplitMediaItem(item, split_pos[i])
  end

  for i = 0, reaper.CountMediaItems(0) - 1 do
    local mi = reaper.GetMediaItem(0, i)
    if reaper.GetMediaItemTrack(mi) == track then
      local pos = reaper.GetMediaItemInfo_Value(mi, "D_POSITION")
      if pos >= item_start and pos < item_start + item_len then
        reaper.SetMediaItemInfo_Value(mi, "B_LOOPSRC", 1)
        reaper.SetMediaItemSelected(mi, true)
      end
    end
  end

  ::skip::
end

reaper.Undo_EndBlock("Cut MIDI items at loop point", -1)
reaper.UpdateArrange()
