-- @noindex
-- Renders the chart data model to MusicXML for hand-finishing in MuseScore.
--
-- Dynamics, hairpins, rehearsal marks, and annotations use real structured
-- MusicXML elements (<dynamics>, <wedge>, <rehearsal>, <words>) so they land
-- as native, draggable objects in MuseScore. Chord symbols are emitted as
-- plain <words> text rather than <harmony> -- parsing arbitrary manually
-- typed chord names (take-name overrides) into root/kind/bass reliably is
-- more failure-prone than it's worth given you're finishing this by hand in
-- MuseScore anyway; select the text and use MuseScore's "Add/Edit Chord
-- Symbol" to convert any of them to a native chord object.

local DIVISIONS = 4 -- divisions per quarter note (1 division = a 16th note)

local FLAT_STEP = {[0]='C',[1]='D',[2]='D',[3]='E',[4]='E',[5]='F',[6]='G',[7]='G',[8]='A',[9]='A',[10]='B',[11]='B'}
local FLAT_ALTER = {[0]=0,[1]=-1,[2]=0,[3]=-1,[4]=0,[5]=0,[6]=-1,[7]=0,[8]=-1,[9]=0,[10]=-1,[11]=0}

-- Largest-first table of {divisions, type, dots} used for greedy duration decomposition.
local DUR_TABLE = {
  {16, 'whole', 0}, {12, 'half', 1}, {8, 'half', 0}, {6, 'quarter', 1},
  {4, 'quarter', 0}, {3, 'eighth', 1}, {2, 'eighth', 0}, {1, '16th', 0},
}

local function xml_escape(s)
  return (tostring(s):gsub('[&<>"]', {['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;'}))
end

local function pitch_info(pitch)
  local pc = pitch % 12
  local octave = math.floor(pitch / 12) - 1
  return FLAT_STEP[pc], FLAT_ALTER[pc], octave
end

local function decompose_duration(units)
  local parts = {}
  local remaining = units
  while remaining > 0 do
    for _, entry in ipairs(DUR_TABLE) do
      if entry[1] <= remaining then
        parts[#parts + 1] = {divisions = entry[1], type = entry[2], dots = entry[3]}
        remaining = remaining - entry[1]
        break
      end
    end
  end
  return parts
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

-- Emits one or more tied <note> elements for a rest or pitched note of the
-- given total duration (in divisions).
local function note_xml(out, pitch, units, is_rhythm_mark)
  local parts = decompose_duration(units)
  for i, p in ipairs(parts) do
    out[#out + 1] = '      <note>'
    if pitch == nil then
      out[#out + 1] = '        <rest/>'
    else
      local step, alter, octave = pitch_info(pitch)
      out[#out + 1] = '        <pitch>'
      out[#out + 1] = '          <step>' .. step .. '</step>'
      if alter ~= 0 then out[#out + 1] = '          <alter>' .. alter .. '</alter>' end
      out[#out + 1] = '          <octave>' .. octave .. '</octave>'
      out[#out + 1] = '        </pitch>'
    end
    out[#out + 1] = '        <duration>' .. p.divisions .. '</duration>'
    if pitch ~= nil and #parts > 1 then
      if i == 1 then
        out[#out + 1] = '        <tie type="start"/>'
      elseif i == #parts then
        out[#out + 1] = '        <tie type="stop"/>'
      else
        out[#out + 1] = '        <tie type="stop"/>'
        out[#out + 1] = '        <tie type="start"/>'
      end
    end
    out[#out + 1] = '        <type>' .. p.type .. '</type>'
    for _ = 1, p.dots do out[#out + 1] = '        <dot/>' end
    if pitch ~= nil and is_rhythm_mark then
      out[#out + 1] = '        <notehead>slash</notehead>'
    end
    local notations = {}
    if pitch ~= nil and #parts > 1 then
      if i == 1 then
        notations[#notations + 1] = '<tied type="start"/>'
      elseif i == #parts then
        notations[#notations + 1] = '<tied type="stop"/>'
      else
        notations[#notations + 1] = '<tied type="stop"/><tied type="start"/>'
      end
    end
    if #notations > 0 then
      out[#out + 1] = '        <notations>' .. table.concat(notations) .. '</notations>'
    end
    out[#out + 1] = '      </note>'
  end
end

local DYNAMIC_TAG = {
  ppp = 'ppp', pp = 'pp', p = 'p', mp = 'mp', mf = 'mf', f = 'f', ff = 'ff', fff = 'fff',
}

local function direction_words(out, text, placement)
  out[#out + 1] = '      <direction placement="' .. placement .. '">'
  out[#out + 1] = '        <direction-type><words>' .. xml_escape(text) .. '</words></direction-type>'
  out[#out + 1] = '      </direction>'
end

local function direction_dynamics(out, level)
  out[#out + 1] = '      <direction placement="below">'
  out[#out + 1] = '        <direction-type><dynamics><' .. DYNAMIC_TAG[level] .. '/></dynamics></direction-type>'
  out[#out + 1] = '        <sound dynamics="90"/>'
  out[#out + 1] = '      </direction>'
end

local function direction_wedge(out, kind, wedge_number)
  local wedge_type = (kind == 'cresc_start' and 'crescendo')
    or (kind == 'dim_start' and 'diminuendo')
    or 'stop'
  out[#out + 1] = '      <direction placement="below">'
  out[#out + 1] = '        <direction-type><wedge type="' .. wedge_type .. '" number="' .. wedge_number .. '"/></direction-type>'
  out[#out + 1] = '      </direction>'
end

local function direction_rehearsal(out, name)
  out[#out + 1] = '      <direction placement="above">'
  out[#out + 1] = '        <direction-type><rehearsal>' .. xml_escape(name) .. '</rehearsal></direction-type>'
  out[#out + 1] = '      </direction>'
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

-- Builds the {pos_qn, duration_units, pitch|nil, is_rhythm_mark} slot list
-- for one measure, mirroring lead_sheet_emit_abc's build_slots.
local function build_slots(chart, measure)
  local bar_units = math.floor(measure.num * 16 / measure.denom + 0.5)
  local slots = {}
  local qn_to_units = function(qn) return math.floor(qn * DIVISIONS + 0.5) end

  local notes_source = figure_notes_for_measure(chart, measure) or chart.melody_notes
  if notes_source then
    local notes = events_in_range(notes_source, measure.start_qn, measure.end_qn)
    local cursor_units = 0
    for _, n in ipairs(notes) do
      local note_start_units = qn_to_units(n.pos_qn - measure.start_qn)
      if note_start_units > cursor_units then
        slots[#slots + 1] = {start_qn = measure.start_qn + cursor_units / DIVISIONS, units = note_start_units - cursor_units, pitch = nil}
      end
      local dur_units = qn_to_units(n.len_qn)
      if note_start_units + dur_units > bar_units then dur_units = bar_units - note_start_units end
      if dur_units > 0 then
        slots[#slots + 1] = {start_qn = measure.start_qn + note_start_units / DIVISIONS, units = dur_units, pitch = n.pitch}
        cursor_units = note_start_units + dur_units
      end
    end
    if cursor_units < bar_units then
      slots[#slots + 1] = {start_qn = measure.start_qn + cursor_units / DIVISIONS, units = bar_units - cursor_units, pitch = nil}
    end
  else
    local attacks = {}
    for _, c in ipairs(events_in_range(chart.chords, measure.start_qn, measure.end_qn)) do attacks[#attacks + 1] = c.pos_qn end
    for _, h in ipairs(events_in_range(chart.hits, measure.start_qn, measure.end_qn)) do attacks[#attacks + 1] = h.pos_qn end
    table.sort(attacks)
    local dedup = {}
    for _, a in ipairs(attacks) do
      if #dedup == 0 or a - dedup[#dedup] > 0.0001 then dedup[#dedup + 1] = a end
    end
    attacks = dedup

    if #attacks == 0 then
      slots[#slots + 1] = {start_qn = measure.start_qn, units = bar_units, pitch = nil}
    else
      for i, a in ipairs(attacks) do
        local next_qn = attacks[i + 1] or measure.end_qn
        local start_units = qn_to_units(a - measure.start_qn)
        local end_units = qn_to_units(next_qn - measure.start_qn)
        slots[#slots + 1] = {start_qn = a, units = math.max(1, end_units - start_units), pitch = 71, is_rhythm_mark = true} -- B4, slash notehead
      end
    end
  end

  return slots
end

local function find_slot_index(slots, qn)
  local best = 1
  for i, s in ipairs(slots) do
    if s.start_qn <= qn + 0.0001 then best = i else break end
  end
  return best
end

-- chart: from lead_sheet_extract.build_chart(). title: string.
local function build_musicxml(chart, title)
  local out = {}
  out[#out + 1] = '<?xml version="1.0" encoding="UTF-8"?>'
  out[#out + 1] = '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">'
  out[#out + 1] = '<score-partwise version="4.0">'
  out[#out + 1] = '  <work><work-title>' .. xml_escape(title) .. '</work-title></work>'
  out[#out + 1] = '  <part-list>'
  out[#out + 1] = '    <score-part id="P1"><part-name>Lead Sheet</part-name></score-part>'
  out[#out + 1] = '  </part-list>'
  out[#out + 1] = '  <part id="P1">'

  local prev_measure = nil
  local wedge_number = 0

  for m_idx, measure in ipairs(chart.measures) do
    out[#out + 1] = '    <measure number="' .. m_idx .. '">'

    if m_idx == 1 or prev_measure.num ~= measure.num or prev_measure.denom ~= measure.denom then
      out[#out + 1] = '      <attributes>'
      out[#out + 1] = '        <divisions>' .. DIVISIONS .. '</divisions>'
      if m_idx == 1 then
        out[#out + 1] = '        <key><fifths>0</fifths></key>'
      end
      out[#out + 1] = '        <time><beats>' .. measure.num .. '</beats><beat-type>' .. measure.denom .. '</beat-type></time>'
      if m_idx == 1 then
        out[#out + 1] = '        <clef><sign>G</sign><line>2</line></clef>'
      end
      out[#out + 1] = '      </attributes>'
    end

    for _, sec in ipairs(chart.sections) do
      if sec.start_qn >= measure.start_qn - 0.0001 and sec.start_qn < measure.end_qn - 0.0001 then
        direction_rehearsal(out, sec.name)
      end
    end

    local slots = build_slots(chart, measure)

    -- Non-note events (chords/dynamics/hairpins/annotations) each emit a
    -- <direction> immediately before the note at their matching slot, so
    -- walk slots in order and interleave.
    local chord_events = events_in_range(chart.chords, measure.start_qn, measure.end_qn)
    local dyn_events = events_in_range(chart.dynamics, measure.start_qn, measure.end_qn)
    local hairpin_events = events_in_range(chart.hairpins, measure.start_qn, measure.end_qn)
    local annot_events = events_in_range(chart.annotations, measure.start_qn, measure.end_qn)

    for slot_i, slot in ipairs(slots) do
      for _, c in ipairs(chord_events) do
        if find_slot_index(slots, c.pos_qn) == slot_i then direction_words(out, c.text, 'above') end
      end
      for _, d in ipairs(dyn_events) do
        if find_slot_index(slots, d.pos_qn) == slot_i then direction_dynamics(out, d.level) end
      end
      for _, h in ipairs(hairpin_events) do
        if find_slot_index(slots, h.pos_qn) == slot_i then
          if h.kind == 'cresc_start' or h.kind == 'dim_start' then
            wedge_number = wedge_number + 1
            slot._wedge_number = wedge_number
            direction_wedge(out, h.kind, wedge_number)
          else
            direction_wedge(out, h.kind, wedge_number)
          end
        end
      end
      for _, a in ipairs(annot_events) do
        if find_slot_index(slots, a.pos_qn) == slot_i then direction_words(out, a.text, 'above') end
      end

      note_xml(out, slot.pitch, slot.units, slot.is_rhythm_mark)
    end

    out[#out + 1] = '    </measure>'
    prev_measure = measure
  end

  out[#out + 1] = '  </part>'
  out[#out + 1] = '</score-partwise>'
  return table.concat(out, '\n') .. '\n'
end

return {build_musicxml = build_musicxml}
