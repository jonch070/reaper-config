-- Shared helpers for the JK voice scripts (split to voices / select voice in MIDI editor).
-- A "voice" is a chord position: among all notes sounding together at an onset,
-- the highest is voice 1 from top (and the lowest is voice 1 from bottom).
local M = {}

local TOL = 5 -- ppq tolerance for notes counted as starting together

function M.read_notes(take)
  local _, n = reaper.MIDI_CountEvts(take)
  local notes = {}
  for i = 0, n - 1 do
    local _, sel, muted, s, e, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    notes[#notes + 1] = { idx = i, sel = sel, muted = muted, s = s, e = e, chan = chan, pitch = pitch, vel = vel }
  end
  return notes
end

-- Walks notes onset by onset. Fills nt.top / nt.bot (rank among everything sounding
-- at that onset) and nt.voice (stable slot 1..N, top = 1, held notes keep their slot).
-- Returns N, the maximum number of simultaneously sounding notes.
-- With ignore_muted, muted notes are skipped (they get no top/bot/voice).
function M.analyze(notes, ignore_muted)
  local order = {}
  for _, nt in ipairs(notes) do
    if not (ignore_muted and nt.muted) then order[#order + 1] = nt end
  end
  table.sort(order, function(a, b)
    if a.s ~= b.s then return a.s < b.s end
    return a.pitch > b.pitch
  end)

  -- group by onset
  local groups, cur = {}, nil
  for _, nt in ipairs(order) do
    if cur and nt.s - cur.s <= TOL then
      cur[#cur + 1] = nt
    else
      cur = { s = nt.s, nt }
      groups[#groups + 1] = cur
    end
  end

  local function sounding_at(active, g)
    local keep = {}
    for _, a in ipairs(active) do if a.e > g.s + TOL then keep[#keep + 1] = a end end
    return keep
  end

  -- pass 1: ranks and N
  local N, active = 0, {}
  for _, g in ipairs(groups) do
    active = sounding_at(active, g)
    for _, nt in ipairs(g) do active[#active + 1] = nt end
    table.sort(active, function(a, b) return a.pitch > b.pitch end)
    local n = #active
    if n > N then N = n end
    for pos, a in ipairs(active) do
      if a.s >= g.s - TOL and a.s <= g.s + TOL then a.top, a.bot = pos, n - pos + 1 end
    end
  end

  -- pass 2: stable voice slots
  active = {}
  for _, g in ipairs(groups) do
    active = sounding_at(active, g)
    local taken = {}
    for _, a in ipairs(active) do taken[a.voice] = true end
    local all = {}
    for _, a in ipairs(active) do all[#all + 1] = a end
    for _, nt in ipairs(g) do all[#all + 1] = nt end
    table.sort(all, function(a, b) return a.pitch > b.pitch end)
    for rank, nt in ipairs(all) do
      if not nt.voice then
        local best, bestd = nil, math.huge
        for v = 1, N do
          if not taken[v] then
            local d = math.abs(v - rank)
            if d < bestd then best, bestd = v, d end
          end
        end
        nt.voice = best
        taken[best] = true
      end
    end
    for _, nt in ipairs(g) do active[#active + 1] = nt end
  end

  return N
end

-- Selects notes of the given chord position in the active MIDI editor take.
function M.select_voice(from_top, n, ignore_muted)
  local me = reaper.MIDIEditor_GetActive()
  if not me then return end
  local take = reaper.MIDIEditor_GetTake(me)
  if not take then return end
  reaper.Undo_BeginBlock()
  local notes = M.read_notes(take)
  M.analyze(notes, ignore_muted)
  local key = from_top and "top" or "bot"
  for _, nt in ipairs(notes) do
    reaper.MIDI_SetNote(take, nt.idx, nt[key] == n, nil, nil, nil, nil, nil, nil, true)
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock(("Select voice %d from %s"):format(n, from_top and "top" or "bottom"), -1)
end

local function yn(s) return not (s or ""):lower():match("^%s*n") end

-- Asks for N and "ignore muted" (default y), remembering the last answers.
-- Returns n, ignore_muted (nil if cancelled).
function M.prompt_n(title)
  local last = reaper.GetExtState("JK_voices", "last_n")
  if last == "" then last = "2" end
  local lastm = reaper.GetExtState("JK_voices", "ignore_muted")
  if lastm == "" then lastm = "y" end
  local ok, val = reaper.GetUserInputs(title, 2, "N:,Ignore muted (y/n):", last .. "," .. lastm)
  if not ok then return nil end
  local ns, ms = val:match("^([^,]*),([^,]*)$")
  local n = tonumber(ns)
  if not n or n < 1 then return nil end
  n = math.floor(n)
  reaper.SetExtState("JK_voices", "last_n", tostring(n), true)
  reaper.SetExtState("JK_voices", "ignore_muted", yn(ms) and "y" or "n", true)
  return n, yn(ms)
end

-- Asks only for "ignore muted" (default y). Returns boolean, or nil if cancelled.
function M.prompt_ignore_muted(title)
  local lastm = reaper.GetExtState("JK_voices", "ignore_muted")
  if lastm == "" then lastm = "y" end
  local ok, val = reaper.GetUserInputs(title, 1, "Ignore muted notes (y/n):", lastm)
  if not ok then return nil end
  reaper.SetExtState("JK_voices", "ignore_muted", yn(val) and "y" or "n", true)
  return yn(val)
end

return M
