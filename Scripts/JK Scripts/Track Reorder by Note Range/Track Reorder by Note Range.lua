-- Track Reorder by Note Range
-- Reorders tracks by the note name found in their track name (e.g. Kick_C1, Snare_D1, G2_C3)
-- Pairs with "Track Select from Note Range" - run that first to select the tracks you want, then run this.

-- Parse a note name to MIDI number
-- Supports: C4, c4, C#4, c#4, Db4, db4
local function note_to_midi(note_str)
  if not note_str then return nil end

  local note_names = {
    C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11
  }

  local letter, accidental, octave = note_str:match("^([A-Ga-g])([#b]?)(%d+)$")
  if not letter then return nil end

  local base = note_names[letter:upper()]
  if not base then return nil end

  if accidental == "#" then
    base = base + 1
  elseif accidental == "b" then
    base = base - 1
  end

  -- C4 = 60, so octave 4 starts at 60
  local midi = base + (tonumber(octave) + 1) * 12

  if midi >= 0 and midi <= 127 then
    return midi
  end
end

-- Find all note tokens in a track name, return list of MIDI numbers.
-- Tokens are separated by underscore, hyphen, plus, or whitespace
-- (e.g. "Kick_C1", "CIBb-aeolian+ord-G#4-pp").
local function parse_track_notes(track_name)
  local midis = {}
  local seen = {}

  local function is_note(str)
    return str:match("^[A-G][#B]?%d+$")
  end

  for token in track_name:gmatch("[^_%-%+%s]+") do
    token = token:upper()
    if is_note(token) then
      local midi = note_to_midi(token)
      if midi and not seen[midi] then
        seen[midi] = true
        table.insert(midis, midi)
      end
    end
  end

  return midis
end

-- Reduce a list of MIDI numbers to a single sort key
local function get_sort_key(midis, reference)
  if #midis == 0 then return nil end

  if reference == "highest" then
    local m = midis[1]
    for _, v in ipairs(midis) do if v > m then m = v end end
    return m
  elseif reference == "average" then
    local sum = 0
    for _, v in ipairs(midis) do sum = sum + v end
    return sum / #midis
  else -- "lowest"
    local m = midis[1]
    for _, v in ipairs(midis) do if v < m then m = v end end
    return m
  end
end

local function get_track_name(track)
  local _, name = reaper.GetTrackName(track, "")
  return name or ""
end

-- Main script
local retval, user_input = reaper.GetUserInputs(
  "Track Reorder by Note Range",
  3,
  "Order (ascending/descending):,Note reference (lowest/highest/average):,Scope (selection/all):,extrawidth=150",
  "descending,lowest,selection"
)

if not retval then return end

local fields = {}
for field in user_input:gmatch("([^,]*),?") do
  table.insert(fields, field)
end

local order = (fields[1] or "descending"):lower():gsub("%s+", "")
local reference = (fields[2] or "lowest"):lower():gsub("%s+", "")
local scope = (fields[3] or "selection"):lower():gsub("%s+", "")

if order ~= "ascending" and order ~= "descending" then order = "descending" end
if reference ~= "lowest" and reference ~= "highest" and reference ~= "average" then reference = "lowest" end
if scope ~= "selection" and scope ~= "all" then scope = "selection" end

-- Gather candidate tracks (must have at least one detected note in their name)
local candidates = {}

if scope == "selection" then
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local midis = parse_track_notes(get_track_name(track))
    local key = get_sort_key(midis, reference)
    if key then
      table.insert(candidates, {track = track, key = key})
    end
  end
else
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local midis = parse_track_notes(get_track_name(track))
    local key = get_sort_key(midis, reference)
    if key then
      table.insert(candidates, {track = track, key = key})
    end
  end
end

if #candidates < 2 then
  reaper.ShowMessageBox("Fewer than 2 tracks with a recognizable note name were found (scope: " .. scope .. ").", "Track Reorder by Note Range", 0)
  return
end

-- Anchor: the position immediately above the topmost candidate track (captured before any moves)
local top_track_number = math.huge
for _, c in ipairs(candidates) do
  local num = reaper.GetMediaTrackInfo_Value(c.track, "IP_TRACKNUMBER")
  if num < top_track_number then top_track_number = num end
end
local anchor_idx = top_track_number - 1

-- Stable sort by key, tie-broken by current track position
for _, c in ipairs(candidates) do
  c.orig_pos = reaper.GetMediaTrackInfo_Value(c.track, "IP_TRACKNUMBER")
end

-- Inserting at a fixed anchor index repeatedly is LIFO, so process in the
-- reverse of the desired final (top-to-bottom) order.
local want_ascending_top_to_bottom = (order == "ascending")
table.sort(candidates, function(a, b)
  if a.key == b.key then
    -- Processing order is reversed into the final result, so sort ties
    -- descending here to keep their original relative order on-screen.
    return a.orig_pos > b.orig_pos
  end
  if want_ascending_top_to_bottom then
    return a.key > b.key -- reverse: descending, so final result is ascending
  else
    return a.key < b.key -- reverse: ascending, so final result is descending
  end
end)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Remember current full selection so it can be restored
local prev_selected = {}
for i = 0, reaper.CountSelectedTracks(0) - 1 do
  table.insert(prev_selected, reaper.GetSelectedTrack(0, i))
end

for _, c in ipairs(candidates) do
  reaper.SetOnlyTrackSelected(c.track)
  reaper.ReorderSelectedTracks(anchor_idx, 0)
  reaper.SetTrackSelected(c.track, false)
end

-- Restore original selection
for i = 0, reaper.CountTracks(0) - 1 do
  reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
end
for _, t in ipairs(prev_selected) do
  reaper.SetTrackSelected(t, true)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Reorder tracks by note range (" .. order .. ", " .. reference .. ")", -1)

reaper.ShowMessageBox("Reordered " .. #candidates .. " track(s) by note name (" .. order .. ", " .. reference .. " note).", "Track Reorder by Note Range", 0)
