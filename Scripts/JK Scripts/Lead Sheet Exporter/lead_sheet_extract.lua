-- @noindex
-- Reads a REAPER project into the plain data model shared by the ABC and
-- MusicXML emitters. Everything is expressed in quarter-note (QN) position,
-- which is tempo-independent, so tempo changes never affect bar math.
--
-- NOTE: this leans on reaper.CountTempoTimeSigMarkers/GetTempoTimeSigMarker
-- and reaper.EnumProjectMarkers3, which are stable, well-documented APIs.
-- It has not been run inside REAPER yet -- if a call errors, check the
-- exact return signature against Actions > Show action list > right-click
-- a matching action > "Help: reference for FUNCNAME" before assuming the
-- extraction logic itself is wrong.

local script_path = ({reaper.get_action_context()})[2]:match('^(.*[\\/])')
local chord_detect = dofile(script_path .. 'chord_detect.lua')

local M = {}

local DYNAMIC_NAMES = {
  ppp = true, pp = true, p = true, mp = true, mf = true, f = true, ff = true, fff = true,
}
local HAIRPIN_NAMES = {
  ['<('] = 'cresc_start', ['<)'] = 'cresc_end',
  ['>('] = 'dim_start',   ['>)'] = 'dim_end',
}

function M.find_track(name_substr)
  local needle = name_substr:lower()
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    if name and name:lower():find(needle, 1, true) then
      return track
    end
  end
  return nil
end

-- Builds the bar-by-bar measure map in QN space: { {start_qn, end_qn, num, denom}, ... }
function M.build_measure_map(end_qn)
  local changes = {} -- { {qn=, num=, denom=}, ... } sorted by qn
  local n = reaper.CountTempoTimeSigMarkers(0)
  for i = 0, n - 1 do
    local ok, timepos, _, _, _, num, denom = reaper.GetTempoTimeSigMarker(0, i)
    if ok and num and num > 0 then
      local qn = reaper.TimeMap2_timeToQN(0, timepos)
      changes[#changes + 1] = {qn = qn, num = num, denom = denom}
    end
  end
  table.sort(changes, function(a, b) return a.qn < b.qn end)

  if #changes == 0 or changes[1].qn > 0.0001 then
    table.insert(changes, 1, {qn = 0, num = 4, denom = 4})
  end

  local measures = {}
  local cur_qn = 0
  local change_idx = 1
  local num, denom = changes[1].num, changes[1].denom

  while cur_qn < end_qn - 0.0001 do
    while change_idx < #changes and changes[change_idx + 1].qn <= cur_qn + 0.0001 do
      change_idx = change_idx + 1
      num, denom = changes[change_idx].num, changes[change_idx].denom
    end
    local bar_len_qn = num * (4 / denom)
    measures[#measures + 1] = {
      start_qn = cur_qn,
      end_qn = cur_qn + bar_len_qn,
      num = num,
      denom = denom,
    }
    cur_qn = cur_qn + bar_len_qn
  end

  return measures
end

local function item_notes(item)
  local take = reaper.GetActiveTake(item)
  if not take or not reaper.TakeIsMIDI(take) then return {}, nil end
  local _, notecnt = reaper.MIDI_CountEvts(take)
  local notes = {}
  for i = 0, notecnt - 1 do
    local ok, _, _, startppq, endppq, _, pitch = reaper.MIDI_GetNote(take, i)
    if ok then
      local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)
      local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, endppq)
      notes[#notes + 1] = {
        pitch = pitch,
        pos_qn = reaper.TimeMap2_timeToQN(0, start_time),
        len_qn = reaper.TimeMap2_timeToQN(0, end_time) - reaper.TimeMap2_timeToQN(0, start_time),
      }
    end
  end
  return notes, take
end

-- REAPER auto-names a fresh MIDI take "01-MIDI", "02-MIDI", etc. -- that is
-- not a manual override, it's just the default. Only a name that doesn't
-- match this pattern counts as the user having renamed the take.
local function is_default_take_name(name)
  return name:match('^%d+%-MIDI$') ~= nil
end

-- A chord track is typically one continuous performance -- notes overlap
-- and change over time -- rather than one discrete MIDI item per chord.
-- So chord boundaries come from where the *sounding pitch set* actually
-- changes (every note-on/note-off is a potential boundary), not from item
-- edges. Very short segments (a few ticks of finger-timing overlap between
-- a released chord and the next one going down) are absorbed into the
-- following segment rather than reported as their own spurious chord.
local MIN_SEGMENT_QN = 0.5 -- shorter than this (an eighth note) gets absorbed

local function pitch_set_key(pitches)
  local sorted = {}
  for _, p in ipairs(pitches) do sorted[#sorted + 1] = p end
  table.sort(sorted)
  return table.concat(sorted, ',')
end

-- One chord event per detected harmonic segment on the Chords track: { pos_qn, text }
function M.extract_chords(track)
  local chords = {}
  if not track then return chords end

  local notes = {}
  local overrides = {} -- manually renamed items: { start_qn, end_qn, text }
  for i = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local item_notes, take = item_notes(item)
    local take_name = take and reaper.GetTakeName(take) or ''
    if take_name ~= '' and not is_default_take_name(take_name) then
      overrides[#overrides + 1] = {
        start_qn = reaper.TimeMap2_timeToQN(0, item_pos),
        end_qn = reaper.TimeMap2_timeToQN(0, item_pos + item_len),
        text = take_name,
      }
    end
    for _, n in ipairs(item_notes) do
      notes[#notes + 1] = {start_qn = n.pos_qn, end_qn = n.pos_qn + n.len_qn, pitch = n.pitch}
    end
  end
  if #notes == 0 then return chords end

  local boundaries = {}
  for _, n in ipairs(notes) do
    boundaries[#boundaries + 1] = n.start_qn
    boundaries[#boundaries + 1] = n.end_qn
  end
  table.sort(boundaries)
  local dedup_b = {}
  for _, b in ipairs(boundaries) do
    if #dedup_b == 0 or b - dedup_b[#dedup_b] > 0.0001 then dedup_b[#dedup_b + 1] = b end
  end
  boundaries = dedup_b

  -- Slice into intervals of constant sounding-pitch-set, dropping silence.
  local segments = {}
  for k = 1, #boundaries - 1 do
    local seg_start, seg_end = boundaries[k], boundaries[k + 1]
    local pitches = {}
    for _, n in ipairs(notes) do
      if n.start_qn <= seg_start + 0.0001 and n.end_qn >= seg_end - 0.0001 then
        pitches[#pitches + 1] = n.pitch
      end
    end
    if #pitches > 0 then
      segments[#segments + 1] = {start_qn = seg_start, end_qn = seg_end, pitches = pitches, key = pitch_set_key(pitches)}
    end
  end

  -- Merge consecutive segments that share the same sounding pitch set.
  local merged = {}
  for _, seg in ipairs(segments) do
    local last = merged[#merged]
    if last and last.key == seg.key and math.abs(last.end_qn - seg.start_qn) < 0.0001 then
      last.end_qn = seg.end_qn
    else
      merged[#merged + 1] = {start_qn = seg.start_qn, end_qn = seg.end_qn, pitches = seg.pitches, key = seg.key}
    end
  end

  -- Absorb very short segments into the next one (or the previous, if last).
  local cleaned = {}
  for idx, seg in ipairs(merged) do
    if seg.end_qn - seg.start_qn < MIN_SEGMENT_QN and #merged > 1 then
      if idx < #merged then
        merged[idx + 1].start_qn = seg.start_qn
      elseif #cleaned > 0 then
        cleaned[#cleaned].end_qn = seg.end_qn
      end
    else
      cleaned[#cleaned + 1] = seg
    end
  end

  for _, seg in ipairs(cleaned) do
    local text = nil
    for _, ov in ipairs(overrides) do
      if ov.start_qn <= seg.start_qn + 0.0001 and ov.end_qn >= seg.end_qn - 0.0001 then
        text = ov.text
        break
      end
    end
    if not text then
      local bass = math.huge
      for _, p in ipairs(seg.pitches) do if p < bass then bass = p end end
      text = chord_detect.detect_chord(seg.pitches, bass)
    end
    chords[#chords + 1] = {pos_qn = seg.start_qn, text = text}
  end

  table.sort(chords, function(a, b) return a.pos_qn < b.pos_qn end)
  return chords
end

-- Transcribes real notes (pitch + rhythm) from a track within [start_qn, end_qn).
-- Used for both the optional Melody track (full song) and Figures regions
-- (a short scoped span) -- same function, different range.
function M.extract_notes_in_range(track, start_qn, end_qn)
  local out = {}
  if not track then return out end
  for i = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local notes = item_notes(item)
    for _, n in ipairs(notes) do
      if n.pos_qn >= start_qn - 0.0001 and n.pos_qn < end_qn - 0.0001 then
        out[#out + 1] = n
      end
    end
  end
  table.sort(out, function(a, b) return a.pos_qn < b.pos_qn end)
  return out
end

-- Reads all project markers/regions into typed event lists.
-- Returns: hits, dynamics, hairpins, annotations, sections, figures
function M.extract_markers_and_regions()
  local hits, dynamics, hairpins, annotations, sections, figures = {}, {}, {}, {}, {}, {}
  local i = 0
  while true do
    local retval, isrgn, pos, rgnend, name, _ = reaper.EnumProjectMarkers3(0, i)
    if retval == 0 then break end
    local pos_qn = reaper.TimeMap2_timeToQN(0, pos)

    if isrgn then
      local end_qn = reaper.TimeMap2_timeToQN(0, rgnend)
      local fig_label = name:match('^%s*[Ff][Ii][Gg]:%s*(.*)$')
      if fig_label then
        figures[#figures + 1] = {start_qn = pos_qn, end_qn = end_qn, label = fig_label}
      else
        sections[#sections + 1] = {start_qn = pos_qn, end_qn = end_qn, name = name}
      end
    else
      local key = name:match('^%s*(.-)%s*$')
      local key_lower = key:lower()
      if key_lower == 'hit' then
        hits[#hits + 1] = {pos_qn = pos_qn}
      elseif DYNAMIC_NAMES[key_lower] then
        dynamics[#dynamics + 1] = {pos_qn = pos_qn, level = key_lower}
      elseif HAIRPIN_NAMES[key] then
        hairpins[#hairpins + 1] = {pos_qn = pos_qn, kind = HAIRPIN_NAMES[key]}
      elseif key ~= '' then
        annotations[#annotations + 1] = {pos_qn = pos_qn, text = key}
      end
    end

    i = i + 1
  end

  local function by_pos(a, b) return a.pos_qn < b.pos_qn end
  local function by_start(a, b) return a.start_qn < b.start_qn end
  table.sort(hits, by_pos)
  table.sort(dynamics, by_pos)
  table.sort(hairpins, by_pos)
  table.sort(annotations, by_pos)
  table.sort(sections, by_start)
  table.sort(figures, by_start)

  return hits, dynamics, hairpins, annotations, sections, figures
end

-- Assembles the full chart data model for a project.
function M.build_chart()
  local chords_track = M.find_track('chord')
  local melody_track = M.find_track('melody')
  local figures_track = M.find_track('figure')

  local hits, dynamics, hairpins, annotations, sections, figure_regions = M.extract_markers_and_regions()
  local chords = M.extract_chords(chords_track)

  -- Project end: latest of project length, last chord item, last region/marker.
  local end_time = reaper.GetProjectLength(0)
  local end_qn = reaper.TimeMap2_timeToQN(0, end_time)
  for _, c in ipairs(chords) do
    if c.pos_qn > end_qn then end_qn = c.pos_qn end
  end
  for _, s in ipairs(sections) do
    if s.end_qn > end_qn then end_qn = s.end_qn end
  end
  end_qn = end_qn + 4 -- pad one bar (assuming 4/4-ish) so the last event isn't clipped

  local measures = M.build_measure_map(end_qn)

  local melody_notes = nil
  if melody_track then
    melody_notes = M.extract_notes_in_range(melody_track, 0, end_qn)
  end

  for _, fig in ipairs(figure_regions) do
    fig.notes = M.extract_notes_in_range(figures_track, fig.start_qn, fig.end_qn)
  end

  return {
    measures = measures,
    chords = chords,
    hits = hits,
    dynamics = dynamics,
    hairpins = hairpins,
    annotations = annotations,
    sections = sections,
    figures = figure_regions,
    melody_notes = melody_notes, -- nil if no Melody track found
    has_chords_track = chords_track ~= nil,
    has_melody_track = melody_track ~= nil,
    has_figures_track = figures_track ~= nil,
  }
end

return M
