-- @noindex
-- Renders the chart data model (see lead_sheet_extract.lua) to ABC notation
-- text, for a same-day quick PDF via abcm2ps.
--
-- Known limitation: ABC has no standard slash notehead (checked against the
-- 2.1 spec), so when there is no Melody track, rhythm hits are rendered as
-- ordinary noteheads on a fixed pitch (B) rather than true rhythm slashes.
-- The MusicXML emitter (lead_sheet_emit_musicxml.lua) uses real
-- <notehead>slash</notehead> for that case -- use it when the chart needs
-- to look right, treat this ABC output as a quick reference PDF only.

local UNIT = 4 -- units per quarter note (L:1/16)

local SHARP_NAMES = {[0]='C',[1]='^C',[2]='D',[3]='^D',[4]='E',[5]='F',[6]='^F',[7]='G',[8]='^G',[9]='A',[10]='^A',[11]='B'}

local function qn_to_units(qn)
  return math.floor(qn * UNIT + 0.5)
end

local function bar_len_units(measure)
  return math.floor(measure.num * 16 / measure.denom + 0.5)
end

local function pitch_to_abc(pitch)
  local pc = pitch % 12
  local octave_num = math.floor(pitch / 12) - 5
  local base = SHARP_NAMES[pc]
  if octave_num >= 1 then
    return base:lower() .. string.rep("'", octave_num - 1)
  elseif octave_num <= -1 then
    return base .. string.rep(',', -octave_num)
  else
    return base
  end
end

local function length_suffix(units)
  if units <= 1 then return '' end
  return tostring(units)
end

-- Finds the slot whose start_qn is the closest at-or-before match for qn.
local function find_slot(slots, qn)
  local best = 1
  for i, s in ipairs(slots) do
    if s.start_qn <= qn + 0.0001 then best = i else break end
  end
  return best
end

local function events_in_range(list, start_qn, end_qn)
  local out = {}
  for _, e in ipairs(list) do
    if e.pos_qn >= start_qn - 0.0001 and e.pos_qn < end_qn - 0.0001 then
      out[#out + 1] = e
    end
  end
  return out
end

-- A figure region's transcribed notes take priority over the Melody track
-- for any bar they overlap (e.g. a scoped unison hit inside a tune that
-- otherwise has no full melody).
local function figure_notes_for_measure(chart, measure)
  for _, fig in ipairs(chart.figures) do
    if fig.start_qn < measure.end_qn - 0.0001 and fig.end_qn > measure.start_qn + 0.0001 then
      return fig.notes
    end
  end
  return nil
end

-- Builds the note/rest slots for one bar, either from real melody/figure
-- pitches or (fallback) from chord-attack / hit rhythm.
local function build_slots(chart, measure)
  local bar_units = bar_len_units(measure)
  local slots = {}

  local notes_source = figure_notes_for_measure(chart, measure) or chart.melody_notes
  if notes_source then
    local notes = events_in_range(notes_source, measure.start_qn, measure.end_qn)
    local cursor_units = 0
    for _, n in ipairs(notes) do
      local note_start_units = qn_to_units(n.pos_qn - measure.start_qn)
      if note_start_units > cursor_units then
        slots[#slots + 1] = {
          start_qn = measure.start_qn + cursor_units / UNIT,
          token = 'z' .. length_suffix(note_start_units - cursor_units),
        }
      end
      local dur_units = qn_to_units(n.len_qn)
      if note_start_units + dur_units > bar_units then
        dur_units = bar_units - note_start_units -- clip at barline (no cross-bar ties in v1)
      end
      if dur_units > 0 then
        slots[#slots + 1] = {
          start_qn = measure.start_qn + note_start_units / UNIT,
          token = pitch_to_abc(n.pitch) .. length_suffix(dur_units),
        }
        cursor_units = note_start_units + dur_units
      end
    end
    if cursor_units < bar_units then
      slots[#slots + 1] = {
        start_qn = measure.start_qn + cursor_units / UNIT,
        token = 'z' .. length_suffix(bar_units - cursor_units),
      }
    end
  else
    -- Rhythm-slash fallback: one attack per chord change or HIT marker.
    local attacks = {}
    for _, c in ipairs(events_in_range(chart.chords, measure.start_qn, measure.end_qn)) do
      attacks[#attacks + 1] = c.pos_qn
    end
    for _, h in ipairs(events_in_range(chart.hits, measure.start_qn, measure.end_qn)) do
      attacks[#attacks + 1] = h.pos_qn
    end
    table.sort(attacks)
    -- de-dupe near-identical positions
    local dedup = {}
    for _, a in ipairs(attacks) do
      if #dedup == 0 or a - dedup[#dedup] > 0.0001 then dedup[#dedup + 1] = a end
    end
    attacks = dedup

    if #attacks == 0 then
      slots[#slots + 1] = {start_qn = measure.start_qn, token = 'z' .. length_suffix(bar_units)}
    else
      for i, a in ipairs(attacks) do
        local next_qn = (attacks[i + 1]) or measure.end_qn
        local start_units = qn_to_units(a - measure.start_qn)
        local end_units = qn_to_units(next_qn - measure.start_qn)
        slots[#slots + 1] = {
          start_qn = a,
          token = 'B' .. length_suffix(math.max(1, end_units - start_units)), -- fixed-pitch rhythm mark
        }
      end
    end
  end

  return slots
end

local function attach_decorations(slots, chart, measure)
  for _, s in ipairs(slots) do s.pre = {} end

  for _, c in ipairs(events_in_range(chart.chords, measure.start_qn, measure.end_qn)) do
    local slot = slots[find_slot(slots, c.pos_qn)]
    table.insert(slot.pre, '"' .. c.text .. '"')
  end
  for _, d in ipairs(events_in_range(chart.dynamics, measure.start_qn, measure.end_qn)) do
    local slot = slots[find_slot(slots, d.pos_qn)]
    table.insert(slot.pre, '!' .. d.level .. '!')
  end
  for _, h in ipairs(events_in_range(chart.hairpins, measure.start_qn, measure.end_qn)) do
    local sym = ({cresc_start = '!<(!', cresc_end = '!<)!', dim_start = '!>(!', dim_end = '!>)!'})[h.kind]
    local slot = slots[find_slot(slots, h.pos_qn)]
    table.insert(slot.pre, sym)
  end
  for _, a in ipairs(events_in_range(chart.annotations, measure.start_qn, measure.end_qn)) do
    local slot = slots[find_slot(slots, a.pos_qn)]
    table.insert(slot.pre, '"^' .. a.text .. '"')
  end

  -- Section/rehearsal marks: attach to the first slot of the bar if a
  -- section starts at or after this bar's start and before the next bar.
  for _, sec in ipairs(chart.sections) do
    if sec.start_qn >= measure.start_qn - 0.0001 and sec.start_qn < measure.end_qn - 0.0001 then
      table.insert(slots[1].pre, 1, '"^[' .. sec.name .. ']"')
    end
  end
end

local function render_bar(chart, measure, prev_measure)
  local slots = build_slots(chart, measure)
  attach_decorations(slots, chart, measure)

  local parts = {}
  if not prev_measure or prev_measure.num ~= measure.num or prev_measure.denom ~= measure.denom then
    parts[#parts + 1] = string.format('[M:%d/%d]', measure.num, measure.denom)
  end
  for _, s in ipairs(slots) do
    for _, dec in ipairs(s.pre) do parts[#parts + 1] = dec end
    parts[#parts + 1] = s.token
  end
  return table.concat(parts, ' ')
end

-- chart: from lead_sheet_extract.build_chart(). title: string.
local function build_abc(chart, title)
  local lines = {}
  lines[#lines + 1] = 'X:1'
  lines[#lines + 1] = 'T:' .. title
  local first = chart.measures[1]
  lines[#lines + 1] = string.format('M:%d/%d', first and first.num or 4, first and first.denom or 4)
  lines[#lines + 1] = 'L:1/16'
  lines[#lines + 1] = 'K:C'

  local body_bars = {}
  local prev_measure = nil
  for _, measure in ipairs(chart.measures) do
    body_bars[#body_bars + 1] = render_bar(chart, measure, prev_measure)
    prev_measure = measure
  end

  -- Wrap 4 bars per line for readability.
  local line_buf = {}
  for i, bar in ipairs(body_bars) do
    line_buf[#line_buf + 1] = bar
    if i % 4 == 0 then
      lines[#lines + 1] = table.concat(line_buf, ' | ') .. ' |'
      line_buf = {}
    end
  end
  if #line_buf > 0 then
    lines[#lines + 1] = table.concat(line_buf, ' | ') .. ' |]'
  else
    -- close off the last emitted line instead of leaving a dangling '|'
    lines[#lines] = lines[#lines]:gsub(' |$', ' |]')
  end

  return table.concat(lines, '\n') .. '\n'
end

return {build_abc = build_abc}
