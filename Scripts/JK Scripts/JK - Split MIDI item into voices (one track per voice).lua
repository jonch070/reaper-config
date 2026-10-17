-- Splits selected MIDI items into one new track per voice (chord position, top = V1).
-- Items on the same track share one set of voice tracks: 4-part harmony -> 4 tracks, 10-part -> 10,
-- however many items are selected. Only notes are copied (no CC / text events).
local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
local V = dofile(dir .. "JK_voices_lib.lua")

-- group selected MIDI items by their track
local groups, order = {}, {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local it = reaper.GetSelectedMediaItem(0, i)
  local tk = reaper.GetActiveTake(it)
  if tk and reaper.TakeIsMIDI(tk) then
    local tr = reaper.GetMediaItem_Track(it)
    if not groups[tr] then
      groups[tr] = { track = tr, items = {} }
      order[#order + 1] = groups[tr]
    end
    local g = groups[tr]
    g.items[#g.items + 1] = it
  end
end
if #order == 0 then
  reaper.ShowMessageBox("Select one or more MIDI items first.", "Split into voices", 0)
  return
end

local ignore_muted = V.prompt_ignore_muted("Split into voices")
if ignore_muted == nil then return end

-- bottom-most source track first, so inserting tracks doesn't shift the others
table.sort(order, function(a, b)
  return reaper.GetMediaTrackInfo_Value(a.track, "IP_TRACKNUMBER") > reaper.GetMediaTrackInfo_Value(b.track, "IP_TRACKNUMBER")
end)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

for _, g in ipairs(order) do
  local trnum = reaper.GetMediaTrackInfo_Value(g.track, "IP_TRACKNUMBER") -- 1-based
  local _, trname = reaper.GetSetMediaTrackInfo_String(g.track, "P_NAME", "", false)
  if trname == "" then trname = "MIDI" end

  -- analyse every item; N = most voices needed by any item on this track
  local N, info = 0, {}
  for _, it in ipairs(g.items) do
    local src = reaper.GetActiveTake(it)
    local notes = V.read_notes(src)
    local n = V.analyze(notes, ignore_muted)
    if n > N then N = n end
    info[#info + 1] = { item = it, src = src, notes = notes }
  end

  for v = 1, N do
    reaper.InsertTrackAtIndex(trnum + v - 1, true)
    local tr = reaper.GetTrack(0, trnum + v - 1)
    reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", ("%s V%d"):format(trname, v), true)
    for _, d in ipairs(info) do
      local has = false
      for _, n in ipairs(d.notes) do if n.voice == v then has = true break end end
      if has then
        local pos = reaper.GetMediaItemInfo_Value(d.item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(d.item, "D_LENGTH")
        local ni = reaper.CreateNewMIDIItemInProj(tr, pos, pos + len, false)
        local nt = reaper.GetActiveTake(ni)
        for _, n in ipairs(d.notes) do
          if n.voice == v then
            local ts = reaper.MIDI_GetProjTimeFromPPQPos(d.src, n.s)
            local te = reaper.MIDI_GetProjTimeFromPPQPos(d.src, n.e)
            reaper.MIDI_InsertNote(nt, false, n.muted, reaper.MIDI_GetPPQPosFromProjTime(nt, ts),
              reaper.MIDI_GetPPQPosFromProjTime(nt, te), n.chan, n.pitch, n.vel, true)
          end
        end
        reaper.MIDI_Sort(nt)
      end
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Split MIDI items into voices", -1)
