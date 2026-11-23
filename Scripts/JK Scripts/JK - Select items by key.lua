-- JK - Select items by key
--
-- Select items whose pitch is IN (or NOT IN) a key/scale, using the same
-- key picker layout as REAPER's MIDI editor key snap: root + scale + 12
-- pitch-class checkboxes.
--
-- Where an item's pitch comes from (first hit wins, take name before file name):
--   * note name   "F#3", "Bb2", "C-1"      (e.g. Gtr-harm_fingering-F#3-p.wav)
--   * MIDI number "midi60", "note 61"  (or any bare 0-127 number, optional)
--   * frequency   "388.5Hz" -> nearest note
--   * MIDI takes: every note in the take (item matches if ALL / ANY notes fit)
-- Audio pitches can be offset by the take's pitch shift (and playrate when
-- "preserve pitch" is off).
--
-- Settings persist between runs (ExtState "JK_SelectByKey").

local r = reaper
if not r.ImGui_CreateContext then
  r.ShowMessageBox("ReaImGui is required for this script.", "Select items by key", 0)
  return
end

local EXT = "JK_SelectByKey"

---------------------------------------------------------------------------
-- Music data
---------------------------------------------------------------------------
-- Display order matches REAPER's dialog: A first, two columns of six.
local NAMES = { [0]="C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B" }
local LEFT  = { 9, 10, 11, 0, 1, 2 }
local RIGHT = { 3, 4, 5, 6, 7, 8 }
local ROOT_ORDER = { 9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8 } -- combo order (A..G#)

local SCALES = {
  { "Chromatic",        { 0,1,2,3,4,5,6,7,8,9,10,11 } },
  { "Major",            { 0,2,4,5,7,9,11 } },
  { "Natural minor",    { 0,2,3,5,7,8,10 } },
  { "Harmonic minor",   { 0,2,3,5,7,8,11 } },
  { "Melodic minor",    { 0,2,3,5,7,9,11 } },
  { "Dorian",           { 0,2,3,5,7,9,10 } },
  { "Phrygian",         { 0,1,3,5,7,8,10 } },
  { "Lydian",           { 0,2,4,6,7,9,11 } },
  { "Mixolydian",       { 0,2,4,5,7,9,10 } },
  { "Locrian",          { 0,1,3,5,6,8,10 } },
  { "Major pentatonic", { 0,2,4,7,9 } },
  { "Minor pentatonic", { 0,3,5,7,10 } },
  { "Blues",            { 0,3,5,6,7,10 } },
  { "Whole tone",       { 0,2,4,6,8,10 } },
  { "Diminished (W-H)", { 0,2,3,5,6,8,9,11 } },
  { "Custom",           nil },
}
local CUSTOM = #SCALES

local LETTER = { c=0, d=2, e=4, f=5, g=7, a=9, b=11 }

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local st = {
  root = 9, scale = 1,                  -- root pitch class, SCALES index
  mask = {},                            -- mask[pc] = true if pc is in the key
  want = 1,                             -- 1 = select IN key, 2 = select NOT in key
  rule = 1,                             -- MIDI items: 1 = ALL notes, 2 = ANY note
  scope = 1,                            -- 1 = all items, 2 = only selected items
  op = 1,                               -- 1 = replace, 2 = add, 3 = deselect matches
  src_name = true, src_file = true,
  p_note = true, p_hz = true,
  p_midi = 1,                           -- 1 off, 2 labelled "midi60"/"note60", 3 any bare 0-127
  p_midinotes = true,
  use_pitch = true,                     -- apply take pitch shift
  unpitched_out = false,                -- no detectable pitch counts as "not in key"
}
for pc = 0, 11 do st.mask[pc] = true end

local function apply_scale()
  local s = SCALES[st.scale]
  if not s or not s[2] then return end
  for pc = 0, 11 do st.mask[pc] = false end
  for _, iv in ipairs(s[2]) do st.mask[(st.root + iv) % 12] = true end
end

local function save()
  local bits = {}
  for pc = 0, 11 do bits[#bits+1] = st.mask[pc] and "1" or "0" end
  local function b(v) return v and "1" or "0" end
  local parts = {
    st.root, st.scale, table.concat(bits), st.want, st.rule, st.scope, st.op,
    b(st.src_name), b(st.src_file), b(st.p_note), b(st.p_hz), st.p_midi,
    b(st.p_midinotes), b(st.use_pitch), b(st.unpitched_out),
  }
  r.SetExtState(EXT, "settings", table.concat(parts, ","), true)
end

local function load()
  local s = r.GetExtState(EXT, "settings")
  if s == "" then apply_scale() return end
  local f = {}
  for v in s:gmatch("[^,]+") do f[#f+1] = v end
  if #f < 15 or #f[3] ~= 12 then apply_scale() return end
  st.root, st.scale = tonumber(f[1]) % 12, math.min(tonumber(f[2]), CUSTOM)
  for pc = 0, 11 do st.mask[pc] = f[3]:sub(pc+1, pc+1) == "1" end
  st.want, st.rule, st.scope, st.op = tonumber(f[4]), tonumber(f[5]), tonumber(f[6]), tonumber(f[7])
  local function b(v) return v == "1" end
  st.src_name, st.src_file, st.p_note, st.p_hz = b(f[8]), b(f[9]), b(f[10]), b(f[11])
  st.p_midi = tonumber(f[12])
  st.p_midinotes, st.use_pitch, st.unpitched_out = b(f[13]), b(f[14]), b(f[15])
end

---------------------------------------------------------------------------
-- Pitch detection
---------------------------------------------------------------------------
local function round(x) return math.floor(x + 0.5) end

-- Each parser returns a pitch (MIDI number, float allowed) or pitch class (nil
-- octave) from a string, or nil. Returns value, has_octave.
local function parse_note(s)
  local l, acc = s:match("%f[%w]([A-Ga-g])([#b]?)%-?%d+%f[%W]")
  if not l then return nil end
  local pc = LETTER[l:lower()] + (acc == "#" and 1 or acc == "b" and -1 or 0)
  return pc % 12
end

local function parse_hz(s)
  local n = s:match("%f[%d](%d+%.?%d*)%s*[Hh][Zz]%f[%W]")
  n = n and tonumber(n)
  if not n or n <= 0 then return nil end
  return 69 + 12 * math.log(n / 440, 2)       -- float MIDI number
end

local function parse_midi(s, mode)
  local low = s:lower()
  local n = low:match("midi[%s_%-:=#]*(%d+)") or low:match("note[%s_%-:=#]*(%d+)")
  if not n and mode == 3 then
    for tok in s:gmatch("%f[%w](%d+)%f[%W]") do
      if tonumber(tok) <= 127 then n = tok break end
    end
  end
  n = n and tonumber(n)
  if n and n >= 0 and n <= 127 then return n end
  return nil
end

local function strings_for(take)
  local list = {}
  if st.src_name then
    local _, nm = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if nm ~= "" then list[#list+1] = nm end
  end
  if st.src_file then
    local src = r.GetMediaItemTake_Source(take)
    if src then
      local parent = r.GetMediaSourceParent(src)
      local fn = r.GetMediaSourceFileName(parent or src, "")
      local base = fn and fn:match("([^/\\]+)$")
      if base and base ~= "" then list[#list+1] = base end
    end
  end
  return list
end

local function take_shift(take)
  if not st.use_pitch then return 0 end
  local sh = r.GetMediaItemTakeInfo_Value(take, "D_PITCH") or 0
  if (r.GetMediaItemTakeInfo_Value(take, "B_PPITCH") or 1) == 0 then
    local rate = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") or 1
    if rate > 0 then sh = sh + 12 * math.log(rate, 2) end
  end
  return sh
end

-- Returns a set of pitch classes {[pc]=true} for the item, or nil if no pitch.
local function item_pitch_classes(item)
  local take = r.GetActiveTake(item)
  if not take then return nil end

  if r.TakeIsMIDI(take) then
    if not st.p_midinotes then return nil end
    local set, any = {}, false
    local _, notes = r.MIDI_CountEvts(take)
    for i = 0, notes - 1 do
      local _, _, _, _, _, _, pitch = r.MIDI_GetNote(take, i)
      if pitch then set[pitch % 12] = true; any = true end
    end
    return any and set or nil
  end

  local shift = round(take_shift(take))
  for _, s in ipairs(strings_for(take)) do
    if st.p_note then
      local pc = parse_note(s)
      if pc then return { [(pc + shift) % 12] = true } end
    end
    if st.p_midi > 1 then
      local n = parse_midi(s, st.p_midi)
      if n then return { [(n + shift) % 12] = true } end
    end
    if st.p_hz then
      local m = parse_hz(s)
      if m then return { [(round(m) + shift) % 12] = true } end
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- Selection
---------------------------------------------------------------------------
local function in_key(set)
  local all, any = true, false
  for pc in pairs(set) do
    if st.mask[pc] then any = true else all = false end
  end
  if st.rule == 1 then return all end
  return any
end

local function run()
  local total = r.CountMediaItems(0)
  local items = {}
  for i = 0, total - 1 do
    local it = r.GetMediaItem(0, i)
    if st.scope == 1 or r.IsMediaItemSelected(it) then items[#items+1] = it end
  end

  local matched, unpitched = {}, 0
  for _, it in ipairs(items) do
    local set = item_pitch_classes(it)
    local hit
    if not set then
      unpitched = unpitched + 1
      hit = (st.want == 2) and st.unpitched_out
    else
      local k = in_key(set)
      hit = (st.want == 1) and k or (st.want == 2 and not k)
    end
    if hit then matched[#matched+1] = it end
  end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  if st.op == 1 then
    for i = 0, total - 1 do r.SetMediaItemSelected(r.GetMediaItem(0, i), false) end
  end
  for _, it in ipairs(matched) do r.SetMediaItemSelected(it, st.op ~= 3) end
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Select items by key", -1)

  return string.format("%s %d of %d items checked  (%d with no detectable pitch)",
    st.op == 3 and "Deselected" or "Selected", #matched, #items, unpitched)
end

---------------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------------
load()
local ctx = r.ImGui_CreateContext("JK Select items by key")
local status = ""

local function radio(label, field, value, same_line)
  if same_line then r.ImGui_SameLine(ctx) end
  if r.ImGui_RadioButton(ctx, label, st[field] == value) then st[field] = value end
end

local function combo(label, width, cur, items)
  r.ImGui_SetNextItemWidth(ctx, width)
  local changed, new = false, cur
  if r.ImGui_BeginCombo(ctx, label, items[cur]) then
    for i, name in ipairs(items) do
      if r.ImGui_Selectable(ctx, name, i == cur) then changed, new = true, i end
    end
    r.ImGui_EndCombo(ctx)
  end
  return changed, new
end

local root_items, scale_items = {}, {}
for i, pc in ipairs(ROOT_ORDER) do root_items[i] = NAMES[pc]:match("^[^/]+") end
for i, s in ipairs(SCALES) do scale_items[i] = s[1] end
local function root_index() for i, pc in ipairs(ROOT_ORDER) do if pc == st.root then return i end end end

local function key_checkbox(pc)
  local ch, v = r.ImGui_Checkbox(ctx, NAMES[pc] .. "##pc" .. pc, st.mask[pc])
  if ch then st.mask[pc] = v; st.scale = CUSTOM end
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 470, 0, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "Select items by key", true,
    r.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    r.ImGui_Text(ctx, "Key:")
    local ch1, ri = combo("##root", 90, root_index(), root_items)
    if ch1 then st.root = ROOT_ORDER[ri]; if st.scale == CUSTOM then st.scale = 1 end; apply_scale() end
    r.ImGui_SameLine(ctx)
    local ch2, si = combo("##scale", 190, st.scale, scale_items)
    if ch2 then st.scale = si; apply_scale() end

    r.ImGui_Spacing(ctx)
    if r.ImGui_BeginTable(ctx, "keys", 2) then
      for row = 1, 6 do
        r.ImGui_TableNextRow(ctx)
        r.ImGui_TableSetColumnIndex(ctx, 0); key_checkbox(LEFT[row])
        r.ImGui_TableSetColumnIndex(ctx, 1); key_checkbox(RIGHT[row])
      end
      r.ImGui_EndTable(ctx)
    end
    if r.ImGui_SmallButton(ctx, "All") then for pc = 0, 11 do st.mask[pc] = true end; st.scale = CUSTOM end
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, "None") then for pc = 0, 11 do st.mask[pc] = false end; st.scale = CUSTOM end
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, "Invert") then for pc = 0, 11 do st.mask[pc] = not st.mask[pc] end; st.scale = CUSTOM end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Select:")
    radio("items IN the key", "want", 1, true)
    radio("items NOT in the key", "want", 2, true)

    r.ImGui_Text(ctx, "From:  ")
    radio("all items", "scope", 1, true)
    radio("selected items only", "scope", 2, true)

    r.ImGui_Text(ctx, "Mode:  ")
    radio("replace selection", "op", 1, true)
    radio("add to selection", "op", 2, true)
    radio("remove from selection", "op", 3, true)

    r.ImGui_Text(ctx, "MIDI items match when:")
    radio("ALL notes fit", "rule", 1, true)
    radio("ANY note fits", "rule", 2, true)

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Read pitch from:")
    local _
    _, st.src_name = r.ImGui_Checkbox(ctx, "take / item name", st.src_name)
    r.ImGui_SameLine(ctx)
    _, st.src_file = r.ImGui_Checkbox(ctx, "source file name", st.src_file)
    _, st.p_note = r.ImGui_Checkbox(ctx, "note names (F#3, Bb2)", st.p_note)
    r.ImGui_SameLine(ctx)
    _, st.p_hz = r.ImGui_Checkbox(ctx, "Hz (388.5Hz)", st.p_hz)
    _, st.p_midinotes = r.ImGui_Checkbox(ctx, "notes inside MIDI items", st.p_midinotes)
    local c3, mi = combo("MIDI number in name", 230, st.p_midi,
      { "off", "labelled (midi60, note 61)", "any bare number 0-127" })
    if c3 then st.p_midi = mi end
    _, st.use_pitch = r.ImGui_Checkbox(ctx, "apply take pitch shift to audio items", st.use_pitch)
    _, st.unpitched_out = r.ImGui_Checkbox(ctx,
      "items with no detectable pitch count as 'not in key'", st.unpitched_out)

    r.ImGui_Separator(ctx)
    if r.ImGui_Button(ctx, "Select", 120, 28) then
      status = run()
      save()
    end
    r.ImGui_SameLine(ctx)
    if status ~= "" then r.ImGui_TextWrapped(ctx, status) end
    r.ImGui_End(ctx)
  end
  if open then
    r.defer(loop)
  else
    save()
  end
end

r.defer(loop)
