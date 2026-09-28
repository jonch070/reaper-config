-- @description Export Lead Sheet (chords/hits/dynamics/structure to ABC + MusicXML)
-- @author Jonathan Kawchuk (generated with Claude)
-- @version 0.1
-- @about
--   Reads chord, structure, hit, and dynamic data out of the current
--   project and writes two chart files next to the project:
--     <project>.abc       -- quick reference PDF via abcm2ps (if installed)
--     <project>.musicxml  -- open in MuseScore for real hand-finishing
--
--   CONVENTIONS (read this before running):
--     Track named containing "chord"  -- a continuous performance (notes
--       overlap/change over time, like normal chord playing) is segmented
--       automatically wherever the sounding pitch set changes; each segment
--       is auto-detected into a chord symbol. To override a guess, put that
--       chord in its own MIDI item and rename the item's take (e.g. to
--       "Cmaj7#11") -- the override applies to any segment fully inside
--       that item's span. Segments shorter than an eighth note are treated
--       as finger-timing overlap and absorbed into the next chord.
--     Track named containing "melody" (optional) -- if present, transcribed
--       in full as real notated pitches/rhythm (fake-book style). If
--       absent, the chart falls back to rhythm-slash marks driven by chord
--       attacks and HIT markers.
--     Track named containing "figure" (optional) -- notes inside any
--       region named "FIG: <label>" are transcribed for just that span
--       (for a shared unison lick/hit even without a full melody track).
--     Project markers:
--       "HIT"                        -- rhythmic stab
--       "pp" "p" "mp" "mf" "f" "ff" "fff" "ppp"  -- dynamic level
--       "<(" "<)" ">(" ">)"          -- crescendo / diminuendo hairpin start/end
--       anything else                -- freeform text annotation
--     Project regions (not named "FIG: ...") -- rehearsal/section label.
--     Time signature -- read from REAPER's native time-sig changes.
--
--   This has not been run inside REAPER yet. If a REAPER API call errors,
--   check its exact return signature (Action list > right-click a matching
--   action > "Help: reference for FUNCNAME") -- the data model and emitters
--   are the parts to trust; the REAPER glue is the part to verify first.

local _, script_full_path = reaper.get_action_context()
local script_path = script_full_path:match('^(.*[\\/])')

local extract = dofile(script_path .. 'lead_sheet_extract.lua')
local emit_abc = dofile(script_path .. 'lead_sheet_emit_abc.lua')
local emit_xml = dofile(script_path .. 'lead_sheet_emit_musicxml.lua')

local function write_file(path, text)
  local f, err = io.open(path, 'w')
  if not f then return false, err end
  f:write(text)
  f:close()
  return true
end

-- REAPER is launched by macOS LaunchServices, not a login shell, so it does
-- not inherit PATH entries set up in .zshrc/.zprofile (e.g. Homebrew's
-- /opt/homebrew/bin). Search common install locations directly instead of
-- trusting the inherited PATH. Returns the absolute path, or nil.
local EXTRA_BIN_DIRS = {'/opt/homebrew/bin/', '/usr/local/bin/', '/opt/local/bin/'}

local function find_bin(cmd)
  for _, dir in ipairs(EXTRA_BIN_DIRS) do
    local f = io.open(dir .. cmd, 'r')
    if f then f:close(); return dir .. cmd end
  end
  local p = io.popen('command -v ' .. cmd .. ' 2>/dev/null')
  if not p then return nil end
  local result = p:read('*a')
  p:close()
  result = result and result:match('^%s*(.-)%s*$')
  return (result ~= '' and result) or nil
end

local function project_title_and_base()
  local proj = 0
  local _, proj_fn = reaper.EnumProjects(-1)
  if proj_fn and proj_fn ~= '' then
    local dir, name = proj_fn:match('^(.*[\\/])([^\\/]+)%.[Rr][Pp][Pp]$')
    if dir and name then return name, dir .. name end
  end
  -- Unsaved project: fall back to REAPER's resource Data folder.
  local fallback_dir = reaper.GetResourcePath() .. '/Data/'
  return 'Untitled Lead Sheet', fallback_dir .. 'Untitled Lead Sheet'
end

local function main()
  local title, base_path = project_title_and_base()
  local chart = extract.build_chart()

  if not chart.has_chords_track then
    reaper.ShowMessageBox(
      'No track found with "chord" in its name. The chart will have no chord symbols.\n\nAdd a MIDI track named e.g. "Chords" with one item per chord change and re-run.',
      'Lead Sheet Exporter', 0)
  end

  local abc_text = emit_abc.build_abc(chart, title)
  local xml_text = emit_xml.build_musicxml(chart, title)

  local abc_path = base_path .. '.abc'
  local xml_path = base_path .. '.musicxml'

  local ok_abc, err_abc = write_file(abc_path, abc_text)
  local ok_xml, err_xml = write_file(xml_path, xml_text)

  local report = {}
  if ok_abc then report[#report + 1] = 'Wrote: ' .. abc_path
  else report[#report + 1] = 'FAILED to write .abc: ' .. tostring(err_abc) end
  if ok_xml then report[#report + 1] = 'Wrote: ' .. xml_path
  else report[#report + 1] = 'FAILED to write .musicxml: ' .. tostring(err_xml) end

  if ok_abc then
    local abcm2ps_bin = find_bin('abcm2ps')
    local gs_bin = find_bin('gs')
    if abcm2ps_bin and gs_bin then
      local ps_path = base_path .. '.ps'
      local pdf_path = base_path .. '.pdf'
      os.execute(string.format('%q %q -O %q 2>/dev/null', abcm2ps_bin, abc_path, ps_path))
      os.execute(string.format('%q -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=%q %q 2>/dev/null', gs_bin, pdf_path, ps_path))
      local pf = io.open(pdf_path, 'r')
      if pf then
        pf:close()
        report[#report + 1] = 'Rendered PDF: ' .. pdf_path
        os.execute(string.format('open %q', pdf_path))
      else
        report[#report + 1] = 'PDF render step ran but no .pdf was produced -- check abcm2ps/gs output manually.'
      end
    else
      report[#report + 1] = '\nabcm2ps and/or ghostscript (gs) not found on PATH -- skipped PDF render.'
      report[#report + 1] = 'Install with: brew install abcm2ps ghostscript'
    end
  end

  if not chart.has_melody_track then
    report[#report + 1] = '\nNo "melody" track found -- chord/hit rhythm rendered as slash marks (fake-book melody notation skipped).'
  end

  reaper.ShowMessageBox(table.concat(report, '\n'), 'Lead Sheet Exporter', 0)
end

main()
