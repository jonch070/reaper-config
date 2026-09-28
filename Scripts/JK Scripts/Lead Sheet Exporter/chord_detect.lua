-- @noindex
-- Chord-name detection from a set of MIDI pitches.
-- Heuristic: tests every note in the chord as a candidate root against a
-- dictionary of common chord qualities, matched by interval pattern.
-- Ambiguous/dense voicings can be misread -- rename the chord item's take
-- to override (see lead_sheet_extract.lua).

local NOTE_NAMES_FLAT = {'C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'}

-- Ordered so that, among exact matches, more specific/common names are
-- preferred when a tie must be broken by list order.
local CHORD_TEMPLATES = {
  {intervals = {0,4,7,11}, label = 'maj7'},
  {intervals = {0,4,7,10}, label = '7'},
  {intervals = {0,3,7,10}, label = 'm7'},
  {intervals = {0,3,6,10}, label = 'm7b5'},
  {intervals = {0,3,6,9},  label = 'dim7'},
  {intervals = {0,4,7,9},  label = '6'},
  {intervals = {0,3,7,9},  label = 'm6'},
  {intervals = {0,2,4,7,11}, label = 'maj9'},
  {intervals = {0,2,4,7,10}, label = '9'},
  {intervals = {0,2,3,7,10}, label = 'm9'},
  {intervals = {0,2,4,7,9},  label = '6/9'},
  {intervals = {0,2,4,7},  label = 'add9'},
  {intervals = {0,2,3,7},  label = 'madd9'},
  {intervals = {0,4,7},   label = ''},      -- major (bare root)
  {intervals = {0,3,7},   label = 'm'},
  {intervals = {0,3,6},   label = 'dim'},
  {intervals = {0,4,8},   label = 'aug'},
  {intervals = {0,5,7},   label = 'sus4'},
  {intervals = {0,2,7},   label = 'sus2'},
}

local function note_name(pc)
  return NOTE_NAMES_FLAT[(pc % 12) + 1]
end

local function set_eq(a, b)
  if #a ~= #b then return false end
  local seen = {}
  for _, v in ipairs(a) do seen[v] = true end
  for _, v in ipairs(b) do if not seen[v] then return false end end
  return true
end

local function is_subset(small, big)
  local seen = {}
  for _, v in ipairs(big) do seen[v] = true end
  for _, v in ipairs(small) do if not seen[v] then return false end end
  return true
end

local function unique_sorted(list)
  local seen, out = {}, {}
  for _, v in ipairs(list) do
    local pc = v % 12
    if not seen[pc] then
      seen[pc] = true
      out[#out + 1] = pc
    end
  end
  table.sort(out)
  return out
end

-- pitches: array of MIDI note numbers (any octave) sounding together.
-- bass_pitch: the lowest-sounding MIDI note number (for slash-chord spelling).
-- Returns a chord symbol string, e.g. "Cmaj7", "Ebm7/Bb", "F?" (unrecognized).
local function detect_chord(pitches, bass_pitch)
  local pcs = unique_sorted(pitches)
  if #pcs == 0 then return '?' end

  local bass_pc = bass_pitch % 12

  if #pcs == 1 then
    return note_name(pcs[1])
  end

  local best = nil -- {score, root, label}

  for _, root in ipairs(pcs) do
    local intervals = {}
    for _, pc in ipairs(pcs) do
      intervals[#intervals + 1] = (pc - root) % 12
    end
    table.sort(intervals)

    for _, tmpl in ipairs(CHORD_TEMPLATES) do
      local exact = set_eq(intervals, tmpl.intervals)
      local subset = (not exact) and is_subset(tmpl.intervals, intervals)
      if exact or subset then
        local score = #tmpl.intervals * 10
        if exact then score = score + 100 end
        if root == bass_pc then score = score + 5 end
        if (not best) or score > best.score then
          best = {score = score, root = root, label = tmpl.label}
        end
      end
    end
  end

  if not best then
    -- Nothing matched cleanly (e.g. a bare fifth, or a cluster). Fall back
    -- to the bass note and flag it for a manual rename.
    if #pcs == 2 then
      local diff = (pcs[2] - pcs[1]) % 12
      if diff == 7 or diff == 5 then
        return note_name(bass_pc) .. '5'
      end
    end
    return note_name(bass_pc) .. '?'
  end

  local name = note_name(best.root) .. best.label
  if best.root ~= bass_pc then
    name = name .. '/' .. note_name(bass_pc)
  end
  return name
end

return {
  detect_chord = detect_chord,
  note_name = note_name,
}
