--[[
  AAT2 Cleanup
  --------------------
  Purpose:
    Consolidates the manual session-cleanup pass done before exporting a
    REAPER project through AATranslator2 to a Pro Tools .ptx session, since
    PT is stricter than REAPER about several things (mono/stereo item vs
    track type, overlapping items, etc).

  Workflow (per step):
    1. Select the step on the left.
    2. Click "Scan This Step" - builds a list of matching issues.
    3. Use "Focus Next" / "Focus Prev" (or click a row's "Focus" button) to
       jump the arrange view to that issue: it selects ONLY that item,
       zooms the timeline around it with padding, and scrolls the track
       into view. Fix it however you like directly in REAPER (this script
       never auto-edits anything except the Step 7 fade-snap actions,
       which are explicit button presses).
    4. When you think you've cleared a step, click "Rescan This Step" to
       confirm. The step's status light in the sidebar turns green when a
       scan returns zero issues.
    5. Move to the next step whenever you like - steps don't lock you out,
       they're just organization.

  STEP DEFINITIONS:
    1. Muted items + grouped items (flagged for awareness, not auto-fixed -
       PT doesn't carry REAPER mute/group state the same way, and you
       generally want to consciously decide to delete/ungroup/unmute
       rather than have a script guess).
    2. Overlapping items on the same track (PT does not want two items
       overlapping on the same track the way REAPER allows).
    3. Mono items on stereo ("ST") tracks - and, folded into this same
       scan, channel-config INCONSISTENCY on tracks whose name contains
       neither "ST" nor "M" (every item on such a track should share one
       channel config - mono, stereo, quad, 5.1, etc - and a scan here
       flags a track where that isn't true).
    4. Stereo items on mono ("M") tracks.
    5. Items with Take FX (bake candidates - this script only flags them;
       pair with nk_Take n Bake to actually bake).
    6. Items with take automation (envelope points on the take) or
       modified item/take properties: channel mode override, playrate,
       pitch, or pan.
    7. Fade grid alignment [NOT CURRENTLY FUNCTIONAL]- built from the standalone "Fade Grid Snapper"
       tool. Two ways to use it:
         a) Scan/Focus/Fix flow like every other step: scan flags items
            whose EXISTING fade lengths aren't a whole number of frames,
            and "Apply Grid-Snap to Focused" / "Snap All Flagged" round
            them to the nearest frame (same math as the standalone tool's
            "Snap Fades on Selected Items").
         b) The "Set New Fades" panel below the issue table, which is the
            standalone tool's other mode verbatim: dial in a fade-in/out
            length in whole frames (with independent shapes) and apply it
            to whatever's currently selected in REAPER, anchored to the
            grid line nearest each item's edge.

  TRACK TYPE CLASSIFICATION (as specified):
    - Track name contains "ST" (case-insensitive substring) -> stereo track.
    - Track name contains "M" (case-insensitive substring) -> mono track.
    - Neither -> "untyped": every item on it should share one channel count.
    NOTE: this is a literal substring match per your spec. A track named
    e.g. "MUSIC" contains "M" and will be treated as a mono track. Worth
    keeping an eye on until/unless you want smarter matching (word-boundary,
    explicit tags, etc).

  A NOTE ON FADE SHAPE NUMBERS (carried over from Fade Grid Snapper script):
    REAPER stores fade shape as an integer 0-6 via C_FADEINSHAPE /
    C_FADEOUTSHAPE. The official API docs only confirm 0 = Linear; the rest
    (1-6) are documented here in the conventional community-known order:
      0 Linear | 1 Fast Start | 2 Fast End | 3 Fast Start/Fast End
      4 Slow Start/Slow End | 5 Slow Start | 6 Slow End
    If the shape you get doesn't match the label you picked, reorder the
    strings in FADE_SHAPES below to match what you see (the numeric index
    for each menu position won't change, only the label).

  Requires ReaImGui (install via ReaPack, ReaTeam Extensions repo).
--]]

if not reaper.ImGui_CreateContext then
  reaper.MB("This script requires the ReaImGui extension.\nInstall it via ReaPack (ReaTeam Extensions repo).", "AAT2 Cleanup", 0)
  return
end

local ctx = reaper.ImGui_CreateContext('AAT2 Cleanup')
local EXT_SECTION = "AAT2_Cleanup"

local UI_COLORS = {
  { reaper.ImGui_Col_WindowBg(),        0x202225FF },
  { reaper.ImGui_Col_TitleBg(),         0x16171AFF },
  { reaper.ImGui_Col_TitleBgActive(),   0x52422CFF },
  { reaper.ImGui_Col_Header(),          0x523826FF },
  { reaper.ImGui_Col_HeaderHovered(),   0x705644FF },
  { reaper.ImGui_Col_HeaderActive(),    0x391F0DFF },
  { reaper.ImGui_Col_Button(),          0x523826FF },
  { reaper.ImGui_Col_ButtonHovered(),   0x705644FF },
  { reaper.ImGui_Col_ButtonActive(),    0x391F0DFF },
  { reaper.ImGui_Col_FrameBg(),         0x2A2C30FF },
  { reaper.ImGui_Col_FrameBgHovered(),  0x33363BFF },
  { reaper.ImGui_Col_FrameBgActive(),   0x523826FF },
  { reaper.ImGui_Col_CheckMark(),       0x52422CFF },
  { reaper.ImGui_Col_SliderGrab(),      0x52422CFF },
  { reaper.ImGui_Col_Text(),            0xE8E6E1FF },
  { reaper.ImGui_Col_Separator(),       0x52422CFF },
  { reaper.ImGui_Col_Border(),          0x3A3D42FF },
  { reaper.ImGui_Col_ChildBg(),         0x202225FF },
}

local LOG_INFO  = 0xB8C0B0FF
local LOG_WARN  = 0xE8C24AFF
local LOG_ERR   = 0xE85A4AFF
local LOG_OK    = 0x8FE88FFF

local STATUS_OK    = 0x6FBF6FFF
local STATUS_WARN  = 0xE8C24AFF
local STATUS_BAD   = 0xE85A4AFF
local DUSTY_RED    = 0xA63A3AFF

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local log_lines = {}
local current_step = 1
local current_issue_idx = {}   -- per-step focus cursor
local timeline_open = true

local settings = {
  focus_padding_pct = 0.35,      -- how much extra time to show around a focused item
}

local FADE_SHAPES = {
  "Linear",
  "Fast Start",
  "Fast End",
  "Fast Start / Fast End",
  "Slow Start / Slow End",
  "Slow Start",
  "Slow End",
}
local FADE_SHAPES_COMBO_STR = table.concat(FADE_SHAPES, "\0") .. "\0"

local function fade_load_num(key, default)
  local val = tonumber(reaper.GetExtState(EXT_SECTION, key))
  if val == nil then return default end
  return val
end

local fade_state = {
  fadein_frames   = fade_load_num("fadein_frames", 2),
  fadeout_frames  = fade_load_num("fadeout_frames", 2),
  fadein_shape    = math.floor(fade_load_num("fadein_shape", 0)),
  fadeout_shape   = math.floor(fade_load_num("fadeout_shape", 0)),
  apply_in        = true,
  apply_out       = true,
}

local function fade_save_state()
  reaper.SetExtState(EXT_SECTION, "fadein_frames", tostring(fade_state.fadein_frames), true)
  reaper.SetExtState(EXT_SECTION, "fadeout_frames", tostring(fade_state.fadeout_frames), true)
  reaper.SetExtState(EXT_SECTION, "fadein_shape", tostring(fade_state.fadein_shape), true)
  reaper.SetExtState(EXT_SECTION, "fadeout_shape", tostring(fade_state.fadeout_shape), true)
end

----------------------------------------------------------------------
-- Log helpers
----------------------------------------------------------------------

local function log(level, text)
  table.insert(log_lines, { level = level, text = text })
  if #log_lines > 300 then table.remove(log_lines, 1) end
end

local function clear_log()
  log_lines = {}
end

----------------------------------------------------------------------
-- Generic helpers
----------------------------------------------------------------------

local function get_track_name(track)
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  return name
end

local function track_type(track)
  local name = get_track_name(track):upper()
  local has_st = name:find("ST", 1, true) ~= nil
  local has_m  = name:find("M", 1, true) ~= nil
  if has_st then return "stereo" end
  if has_m then return "mono" end
  return "untyped"
end

-- Effective channel count of an item's active take, accounting for
-- channel-mode overrides that force a mono result (reverse-stereo/L/R
-- excepted per REAPER's I_CHANMODE semantics).
local function item_channel_count(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil, "no take" end
  if reaper.TakeIsMIDI(take) then return nil, "midi" end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil, "no source" end
  local nch = reaper.GetMediaSourceNumChannels(src)
  local chanmode = reaper.GetMediaItemInfo_Value(item, "I_CHANMODE")
  -- 0 = normal, 1 = reverse stereo (still 2ch), >=2 = forced mono variants
  if chanmode >= 2 then
    return 1, "mono (forced via channel mode)"
  end
  return nch, nil
end

local function channel_count_label(n)
  if n == 1 then return "mono"
  elseif n == 2 then return "stereo"
  elseif n == 4 then return "quad"
  elseif n == 6 then return "5.1"
  elseif n == 8 then return "7.1"
  else return string.format("%d-ch", n) end
end

local function all_tracks()
  local t = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    t[#t + 1] = reaper.GetTrack(0, i)
  end
  return t
end

local function track_items(track)
  local items = {}
  for i = 0, reaper.CountTrackMediaItems(track) - 1 do
    items[#items + 1] = reaper.GetTrackMediaItem(track, i)
  end
  return items
end

local function get_frame_rate()
  local fr = reaper.TimeMap_curFrameRate(0)
  if not fr or fr <= 0 then return nil end
  return fr
end

----------------------------------------------------------------------
-- Focus / zoom-to-item
----------------------------------------------------------------------

local function focus_item(item)
  if not item or not reaper.ValidatePtr(item, "MediaItem*") then
    log("err", "Focus: item no longer valid (was it deleted/replaced since scan? try Rescan)")
    return
  end
  local track = reaper.GetMediaItem_Track(item)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemSelected(item, true)
  reaper.SetOnlyTrackSelected(track)

  local pad = math.max(len * settings.focus_padding_pct, 0.5)
  local view_start = math.max(0, pos - pad)
  local view_end = pos + len + pad
  reaper.GetSet_ArrangeView2(0, true, 0, 0, view_start, view_end)

  reaper.SetEditCurPos(pos, false, false)
  reaper.Main_OnCommand(40913, 0) -- Track: Vertical scroll selected tracks into view
  reaper.UpdateArrange()
end

----------------------------------------------------------------------
-- Step scan functions
-- Each returns a list of issue records:
--   { items = {item,...}, track_name, pos, len, kind, desc }
----------------------------------------------------------------------

local function scan_step1_muted_grouped()
  local issues = {}
  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    for _, item in ipairs(track_items(track)) do
      local muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
      local groupid = reaper.GetMediaItemInfo_Value(item, "IP_ITEMGROUPID")
      local grouped = groupid ~= nil and groupid ~= 0
      if muted or grouped then
        local parts = {}
        if muted then parts[#parts+1] = "muted" end
        if grouped then parts[#parts+1] = string.format("grouped (id %d)", groupid) end
        issues[#issues+1] = {
          items = { item },
          track_name = tname,
          pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
          len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
          kind = muted and "muted" or "grouped",
          desc = table.concat(parts, ", "),
        }
      end
    end
  end
  return issues
end

local function scan_step2_overlaps()
  local issues = {}
  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    local items = track_items(track)
    table.sort(items, function(a, b)
      return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
    end)
    for i = 1, #items - 1 do
      local a, b = items[i], items[i+1]
      local a_pos = reaper.GetMediaItemInfo_Value(a, "D_POSITION")
      local a_len = reaper.GetMediaItemInfo_Value(a, "D_LENGTH")
      local a_end = a_pos + a_len
      local b_pos = reaper.GetMediaItemInfo_Value(b, "D_POSITION")
      if b_pos < a_end - 0.0005 then
        issues[#issues+1] = {
          items = { a, b },
          track_name = tname,
          pos = b_pos,
          len = a_end - b_pos,
          kind = "overlap",
          desc = string.format("overlap of %.3fs", a_end - b_pos),
        }
      end
    end
  end
  return issues
end

local function scan_step3_mono_on_stereo_and_untyped()
  local issues = {}
  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    local ttype = track_type(track)
    local items = track_items(track)

    if ttype == "stereo" then
      for _, item in ipairs(items) do
        local nch, note = item_channel_count(item)
        if nch and nch == 1 then
          issues[#issues+1] = {
            items = { item },
            track_name = tname,
            pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
            len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
            kind = "mono_on_stereo",
            desc = note or "mono item on stereo track",
          }
        end
      end
    elseif ttype == "untyped" and #items > 0 then
      -- internal consistency check: every item on the track should share
      -- one channel count
      local seen = {}
      local order = {}
      for _, item in ipairs(items) do
        local nch = item_channel_count(item)
        if nch then
          if not seen[nch] then
            seen[nch] = true
            order[#order+1] = nch
          end
        end
      end
      if #order > 1 then
        local labels = {}
        for _, n in ipairs(order) do labels[#labels+1] = channel_count_label(n) end
        for _, item in ipairs(items) do
          local nch = item_channel_count(item)
          if nch then
            issues[#issues+1] = {
              items = { item },
              track_name = tname,
              pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
              len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
              kind = "untyped_inconsistent",
              desc = string.format("track has mixed channel configs (%s) - this item is %s",
                table.concat(labels, "/"), channel_count_label(nch)),
            }
          end
        end
      end
    end
  end
  return issues
end

local function scan_step4_stereo_on_mono()
  local issues = {}
  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    if track_type(track) == "mono" then
      for _, item in ipairs(track_items(track)) do
        local nch, note = item_channel_count(item)
        if nch and nch >= 2 then
          issues[#issues+1] = {
            items = { item },
            track_name = tname,
            pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
            len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
            kind = "stereo_on_mono",
            desc = string.format("%s item on mono track", channel_count_label(nch)),
          }
        end
      end
    end
  end
  return issues
end

local function scan_step5_take_fx()
  local issues = {}
  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    for _, item in ipairs(track_items(track)) do
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local fxcount = reaper.TakeFX_GetCount(take)
        if fxcount > 0 then
          issues[#issues+1] = {
            items = { item },
            track_name = tname,
            pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
            len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
            kind = "take_fx",
            desc = string.format("%d take FX (bake candidate)", fxcount),
          }
        end
      end
    end
  end
  return issues
end

local function take_has_envelope_points(take)
  for i = 0, reaper.CountTakeEnvelopes(take) - 1 do
    local env = reaper.GetTakeEnvelope(take, i)
    if env and reaper.CountEnvelopePoints(env) > 0 then
      return true
    end
  end
  return false
end

local function scan_step6_take_automation_props()
  local issues = {}
  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    for _, item in ipairs(track_items(track)) do
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local flags = {}
        local chanmode = reaper.GetMediaItemInfo_Value(item, "I_CHANMODE")
        if chanmode ~= 0 then flags[#flags+1] = "channel mode" end
        local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
        if math.abs(playrate - 1.0) > 0.0001 then flags[#flags+1] = string.format("playrate %.3f", playrate) end
        local pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
        if math.abs(pitch) > 0.0001 then flags[#flags+1] = string.format("pitch %.2f", pitch) end
        local pan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
        if math.abs(pan) > 0.0001 then flags[#flags+1] = string.format("pan %.2f", pan) end
        if take_has_envelope_points(take) then flags[#flags+1] = "take envelope" end

        if #flags > 0 then
          issues[#issues+1] = {
            items = { item },
            track_name = tname,
            pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
            len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
            kind = "take_props",
            desc = table.concat(flags, ", "),
          }
        end
      end
    end
  end
  return issues
end

----------------------------------------------------------------------
-- Step 7: fade grid logic (ported from the standalone Fade Grid Snapper) [NOT CURRENTLY FUNCTIONAL]
----------------------------------------------------------------------

-- Round a single fade length to the nearest whole frame, clamped to item
-- length. Same math as the standalone tool's SnapFadesToNearestFrame.
local function nearest_frame_fade_len(fade_len, fr, item_len)
  if not fade_len or fade_len <= 0 then return fade_len end
  local frames = fade_len * fr
  local rounded = math.floor(frames + 0.5)
  local new_len = rounded / fr
  if new_len > item_len then new_len = item_len end
  return new_len
end

local function scan_step7_fades()
  local issues = {}
  local fr = get_frame_rate()
  if not fr then
    log("err", "Step 7 scan: could not read project frame rate (check Project Settings > Project)")
    return issues
  end

  for _, track in ipairs(all_tracks()) do
    local tname = get_track_name(track)
    for _, item in ipairs(track_items(track)) do
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local fi = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
      local fo = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
      local fi_target = nearest_frame_fade_len(fi, fr, len)
      local fo_target = nearest_frame_fade_len(fo, fr, len)
      local fi_off = fi > 0 and math.abs(fi_target - fi) > 0.0005
      local fo_off = fo > 0 and math.abs(fo_target - fo) > 0.0005
      if fi_off or fo_off then
        local parts = {}
        if fi_off then parts[#parts+1] = string.format("fade-in %.4fs -> %.4fs", fi, fi_target) end
        if fo_off then parts[#parts+1] = string.format("fade-out %.4fs -> %.4fs", fo, fo_target) end
        issues[#issues+1] = {
          items = { item },
          track_name = tname,
          pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
          len = len,
          kind = "fade_offgrid",
          desc = table.concat(parts, ", "),
          _fi_target = fi_target,
          _fo_target = fo_target,
        }
      end
    end
  end
  return issues
end

local function apply_step7_fade_fix(issue)
  local item = issue.items[1]
  if not item or not reaper.ValidatePtr(item, "MediaItem*") then return false end
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", issue._fi_target)
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", issue._fo_target)
  reaper.UpdateItemInProject(item)
  return true
end

-- "Set New Fades" mode - grid-anchored fade-in/out in whole frames, applied
-- to whatever's currently selected in REAPER. Ported verbatim from the
-- standalone tool's ApplyFades().
local function apply_grid_fades(frames_in, shape_in, frames_out, shape_out, do_in, do_out)
  local fr = get_frame_rate()
  if not fr then
    log("err", "Set New Fades: could not read project frame rate (check Project Settings > Project)")
    return
  end

  local count = reaper.CountSelectedMediaItems(0)
  if count == 0 then
    log("err", "Set New Fades: no media items selected in REAPER")
    return
  end

  local frame_len = 1 / fr
  local grid_tolerance = frame_len
  local skipped = 0

  reaper.Undo_BeginBlock()

  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len   = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end   = item_start + item_len

    local fade_in_len, fade_out_len

    if do_in then
      local grid_start = reaper.SnapToGrid(0, item_start)
      local anchor = item_start
      if math.abs(grid_start - item_start) <= grid_tolerance then
        anchor = grid_start
      else
        skipped = skipped + 1
      end
      fade_in_len = (anchor + frames_in * frame_len) - item_start
    end

    if do_out then
      local grid_end = reaper.SnapToGrid(0, item_end)
      local anchor = item_end
      if math.abs(grid_end - item_end) <= grid_tolerance then
        anchor = grid_end
      else
        skipped = skipped + 1
      end
      fade_out_len = item_end - (anchor - frames_out * frame_len)
    end

    if fade_in_len and fade_in_len < 0 then fade_in_len = 0 end
    if fade_out_len and fade_out_len < 0 then fade_out_len = 0 end
    if fade_in_len and fade_out_len and (fade_in_len + fade_out_len) > item_len then
      local scale = item_len / (fade_in_len + fade_out_len)
      fade_in_len = fade_in_len * scale
      fade_out_len = fade_out_len * scale
    elseif fade_in_len and fade_in_len > item_len then
      fade_in_len = item_len
    elseif fade_out_len and fade_out_len > item_len then
      fade_out_len = item_len
    end

    if do_in then
      reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_in_len)
      reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", shape_in)
    end
    if do_out then
      reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_out_len)
      reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", shape_out)
    end
  end

  reaper.Undo_EndBlock("AAT2 Cleanup: set frame-accurate fades on selected items", -1)
  reaper.UpdateArrange()

  local msg = string.format("Set New Fades: applied to %d item(s).", count)
  if skipped > 0 then
    msg = msg .. string.format(" (%d edge(s) were more than 1 frame from grid, used raw edge instead.)", skipped)
  end
  log("ok", msg)
end

----------------------------------------------------------------------
-- Step registry
----------------------------------------------------------------------

local steps = {
  { name = "1. Muted / Grouped",        scan = scan_step1_muted_grouped },
  { name = "2. Overlapping Items",      scan = scan_step2_overlaps },
  { name = "3. Mono on Stereo (+untyped)", scan = scan_step3_mono_on_stereo_and_untyped },
  { name = "4. Stereo on Mono",         scan = scan_step4_stereo_on_mono },
  { name = "5. Take FX",                scan = scan_step5_take_fx },
  { name = "6. Take Automation/Props",  scan = scan_step6_take_automation_props },
  { name = "7. Fade Grid",              scan = scan_step7_fades, is_fade_step = true },
}

for i = 1, #steps do
  steps[i].issues = nil
  steps[i].last_scanned = false
  current_issue_idx[i] = 0
end

local function run_scan(step_idx)
  local step = steps[step_idx]
  reaper.Undo_BeginBlock()
  local ok, result = pcall(step.scan)
  reaper.Undo_EndBlock("AAT2 Cleanup: scan " .. step.name, -1)
  if not ok then
    log("err", string.format("Scan failed for %s: %s", step.name, tostring(result)))
    return
  end
  step.issues = result
  step.last_scanned = true
  current_issue_idx[step_idx] = 0
  if #result == 0 then
    log("ok", string.format("%s: clean, no issues found", step.name))
  else
    log("warn", string.format("%s: %d issue(s) found", step.name, #result))
  end
end

----------------------------------------------------------------------
-- GUI: sidebar
----------------------------------------------------------------------

local function status_dot_color(step)
  if not step.last_scanned then return 0x60636AFF end
  if #step.issues == 0 then return STATUS_OK end
  return STATUS_BAD
end

local function draw_sidebar()
  reaper.ImGui_BeginChild(ctx, "sidebar", 220, 0)
  for i, step in ipairs(steps) do
    local dot = status_dot_color(step)
    reaper.ImGui_TextColored(ctx, dot, "\226\151\143") -- filled circle
    reaper.ImGui_SameLine(ctx)
    local label = step.name
    if step.last_scanned then
      label = string.format("%s (%d)", step.name, #step.issues)
    end
    if reaper.ImGui_Selectable(ctx, label, current_step == i) then
      current_step = i
    end
  end
  reaper.ImGui_EndChild(ctx)
end

----------------------------------------------------------------------
-- GUI: mini timeline
----------------------------------------------------------------------

local function issue_color(kind)
  if kind == "muted" or kind == "grouped" then return STATUS_WARN
  elseif kind == "overlap" then return STATUS_BAD
  elseif kind == "mono_on_stereo" or kind == "stereo_on_mono" then return STATUS_BAD
  elseif kind == "untyped_inconsistent" then return DUSTY_RED
  elseif kind == "take_fx" then return STATUS_WARN
  elseif kind == "take_props" then return STATUS_WARN
  elseif kind == "fade_offgrid" then return STATUS_WARN
  end
  return STATUS_BAD
end

local function draw_timeline(step, focus_idx)
  if not timeline_open or not step.issues or #step.issues == 0 then return end

  local dl = reaper.ImGui_GetWindowDrawList(ctx)
  local wx, wy = reaper.ImGui_GetCursorScreenPos(ctx)
  local avail = reaper.ImGui_GetContentRegionAvail(ctx)
  local row_h = 22

  local lo, hi = math.huge, -math.huge
  for _, r in ipairs(step.issues) do
    lo = math.min(lo, r.pos)
    hi = math.max(hi, r.pos + math.max(r.len, 0.001))
  end
  local span = math.max(0.001, hi - lo)
  local pad = span * 0.04
  lo, hi = lo - pad, hi + pad
  span = hi - lo

  reaper.ImGui_DrawList_AddRectFilled(dl, wx, wy, wx + avail, wy + row_h, 0x16171AFF)
  reaper.ImGui_DrawList_AddRect(dl, wx, wy, wx + avail, wy + row_h, 0x3A3D42FF)

  local function xpos(t)
    return wx + ((t - lo) / span) * avail
  end

  for i, r in ipairs(step.issues) do
    local x1 = xpos(r.pos)
    local x2 = xpos(r.pos + math.max(r.len, span * 0.003))
    local col = issue_color(r.kind)
    if i == focus_idx then col = 0xFFFFFFFF end
    reaper.ImGui_DrawList_AddRectFilled(dl, x1, wy + 1, math.max(x1 + 2, x2), wy + row_h - 1, col)
  end

  local playpos = reaper.GetPlayPosition()
  if playpos >= lo and playpos <= hi then
    local px = xpos(playpos)
    reaper.ImGui_DrawList_AddLine(dl, px, wy, px, wy + row_h, 0xFFFFFFCC, 1.5)
  end

  reaper.ImGui_Dummy(ctx, avail, row_h)
  reaper.ImGui_TextColored(ctx, 0x9A9A9AFF, "each block = one issue - white = currently focused")
end

----------------------------------------------------------------------
-- GUI: step 7 extra panel (Set New Fades, grid-anchored)
----------------------------------------------------------------------

local function int_input(label, key, min_val)
  reaper.ImGui_PushItemWidth(ctx, 100)
  local changed, val = reaper.ImGui_InputInt(ctx, label, fade_state[key])
  reaper.ImGui_PopItemWidth(ctx)
  if changed then
    if val < (min_val or 0) then val = (min_val or 0) end
    fade_state[key] = val
  end
end

local function shape_combo(label, key)
  reaper.ImGui_PushItemWidth(ctx, 180)
  local changed, val = reaper.ImGui_Combo(ctx, label, fade_state[key], FADE_SHAPES_COMBO_STR)
  reaper.ImGui_PopItemWidth(ctx)
  if changed then fade_state[key] = val end
end

local function draw_set_new_fades_panel()
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Text(ctx, "Set New Fades (grid-anchored, on REAPER-selected items)")

  local fr = get_frame_rate()
  if fr then
    reaper.ImGui_TextDisabled(ctx, string.format("Project frame rate: %.3f fps", fr))
  else
    reaper.ImGui_TextColored(ctx, LOG_ERR, "Could not read project frame rate.")
  end

  local ch
  ch, fade_state.apply_in = reaper.ImGui_Checkbox(ctx, "Fade In", fade_state.apply_in)
  reaper.ImGui_Indent(ctx)
  int_input("Frames##in", "fadein_frames", 0)
  shape_combo("Shape##in", "fadein_shape")
  reaper.ImGui_Unindent(ctx)

  reaper.ImGui_Spacing(ctx)

  ch, fade_state.apply_out = reaper.ImGui_Checkbox(ctx, "Fade Out", fade_state.apply_out)
  reaper.ImGui_Indent(ctx)
  int_input("Frames##out", "fadeout_frames", 0)
  shape_combo("Shape##out", "fadeout_shape")
  reaper.ImGui_Unindent(ctx)

  reaper.ImGui_Spacing(ctx)

  if reaper.ImGui_Button(ctx, "Apply to Selected Items", -1, 0) then
    fade_save_state()
    apply_grid_fades(
      fade_state.fadein_frames, fade_state.fadein_shape,
      fade_state.fadeout_frames, fade_state.fadeout_shape,
      fade_state.apply_in, fade_state.apply_out
    )
  end
end

----------------------------------------------------------------------
-- GUI: issue table + walkthrough controls
----------------------------------------------------------------------

local function draw_issue_table(step_idx)
  local step = steps[step_idx]
  if not step.issues then
    reaper.ImGui_TextColored(ctx, 0x9A9A9AFF, "Not scanned yet - click \"Scan This Step\".")
    if step.is_fade_step then draw_set_new_fades_panel() end
    return
  end
  if #step.issues == 0 then
    reaper.ImGui_TextColored(ctx, LOG_OK, "Clean - no issues found on last scan.")
    if step.is_fade_step then draw_set_new_fades_panel() end
    return
  end

  local focus_idx = current_issue_idx[step_idx]

  reaper.ImGui_Text(ctx, string.format("%d issue(s)", #step.issues))
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "<< Focus Prev") then
    focus_idx = focus_idx <= 1 and #step.issues or focus_idx - 1
    current_issue_idx[step_idx] = focus_idx
    focus_item(step.issues[focus_idx].items[1])
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Focus Next >>") then
    focus_idx = focus_idx >= #step.issues and 1 or focus_idx + 1
    current_issue_idx[step_idx] = focus_idx
    focus_item(step.issues[focus_idx].items[1])
  end

  if step.is_fade_step then
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Apply Grid-Snap to Focused") and focus_idx > 0 then
      apply_step7_fade_fix(step.issues[focus_idx])
      log("ok", "Applied grid-snap fade fix to focused item")
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Snap All Flagged") then
      local n = 0
      for _, issue in ipairs(step.issues) do
        if apply_step7_fade_fix(issue) then n = n + 1 end
      end
      log("ok", string.format("Snapped %d flagged fade(s) to nearest frame", n))
      run_scan(step_idx)
    end
  end

  draw_timeline(step, focus_idx)

  local flags = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_ScrollY()
  if reaper.ImGui_BeginTable(ctx, "issues_table", 5, flags, 0, 200) then
    reaper.ImGui_TableSetupColumn(ctx, "", reaper.ImGui_TableColumnFlags_WidthFixed(), 60)
    reaper.ImGui_TableSetupColumn(ctx, "Track", reaper.ImGui_TableColumnFlags_WidthStretch())
    reaper.ImGui_TableSetupColumn(ctx, "Pos (s)", reaper.ImGui_TableColumnFlags_WidthFixed(), 70)
    reaper.ImGui_TableSetupColumn(ctx, "Issue", reaper.ImGui_TableColumnFlags_WidthFixed(), 130)
    reaper.ImGui_TableSetupColumn(ctx, "Detail", reaper.ImGui_TableColumnFlags_WidthStretch())
    reaper.ImGui_TableHeadersRow(ctx)

    for i, r in ipairs(step.issues) do
      reaper.ImGui_TableNextRow(ctx)

      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      if reaper.ImGui_SmallButton(ctx, "Focus##" .. i) then
        current_issue_idx[step_idx] = i
        focus_item(r.items[1])
      end

      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      reaper.ImGui_Text(ctx, r.track_name)

      reaper.ImGui_TableSetColumnIndex(ctx, 2)
      reaper.ImGui_Text(ctx, string.format("%.3f", r.pos))

      reaper.ImGui_TableSetColumnIndex(ctx, 3)
      reaper.ImGui_TextColored(ctx, issue_color(r.kind), r.kind)

      reaper.ImGui_TableSetColumnIndex(ctx, 4)
      reaper.ImGui_Text(ctx, r.desc)
    end

    reaper.ImGui_EndTable(ctx)
  end

  if step.is_fade_step then draw_set_new_fades_panel() end
end

----------------------------------------------------------------------
-- GUI: log panel
----------------------------------------------------------------------

local function draw_log()
  reaper.ImGui_Text(ctx, "Log")
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_SmallButton(ctx, "Clear##log") then clear_log() end
  reaper.ImGui_BeginChild(ctx, "log_child", 0, 110, reaper.ImGui_WindowFlags_None())
  for _, l in ipairs(log_lines) do
    local col = LOG_INFO
    if l.level == "warn" then col = LOG_WARN
    elseif l.level == "err" then col = LOG_ERR
    elseif l.level == "ok" then col = LOG_OK end
    reaper.ImGui_TextColored(ctx, col, l.text)
  end
  if #log_lines > 0 then
    reaper.ImGui_SetScrollHereY(ctx, 1.0)
  end
  reaper.ImGui_EndChild(ctx)
end

----------------------------------------------------------------------
-- Main loop
----------------------------------------------------------------------

local function loop()
  for _, c in ipairs(UI_COLORS) do
    reaper.ImGui_PushStyleColor(ctx, c[1], c[2])
  end

  reaper.ImGui_SetNextWindowSize(ctx, 900, 760, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'AAT2 Cleanup', true)
  if visible then

    draw_sidebar()
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_BeginChild(ctx, "main_panel", 0, 0)

    local step = steps[current_step]
    reaper.ImGui_Text(ctx, step.name)
    reaper.ImGui_Separator(ctx)

    if reaper.ImGui_Button(ctx, "Scan This Step", 160, 0) then
      run_scan(current_step)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Rescan This Step", 160, 0) then
      run_scan(current_step)
    end

    reaper.ImGui_Separator(ctx)
    draw_issue_table(current_step)

    reaper.ImGui_Separator(ctx)
    draw_log()

    reaper.ImGui_EndChild(ctx)
    reaper.ImGui_End(ctx)
  end

  reaper.ImGui_PopStyleColor(ctx, #UI_COLORS)

  if open then
    reaper.defer(loop)
  end
end

log("info", "AAT2 Cleanup loaded. Select a step and click Scan to begin.")
reaper.defer(loop)
