-- Inherit MIDI Input & Routing From Parent Folder
-- Select any tracks and run: each inherits MIDI input + channel (and optionally
-- sends/receives/hardware outs) from its own immediate folder parent.
-- Top-level tracks (no parent) are skipped.

local COPY_INPUT     = true
local COPY_SENDS     = false
local COPY_RECEIVES  = false
local COPY_HW_OUTS   = false
local COPY_MAIN_SEND = false

local function collect_selected_tracks()
  local t = {}
  local n = reaper.CountSelectedTracks(0)
  for i = 0, n - 1 do
    t[#t + 1] = reaper.GetSelectedTrack(0, i)
  end
  return t
end

local function copy_input(src, dst)
  local v = reaper.GetMediaTrackInfo_Value(src, "I_RECINPUT")
  reaper.SetMediaTrackInfo_Value(dst, "I_RECINPUT", v)
end

local function copy_send_params(read_tr, read_cat, read_idx, write_tr, write_cat, write_idx)
  local params = {
    "D_VOL", "D_PAN", "B_MUTE", "B_PHASE",
    "I_SENDMODE", "I_AUTOMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDIFLAGS",
  }
  for _, p in ipairs(params) do
    local ok, v = pcall(reaper.GetTrackSendInfo_Value, read_tr, read_cat, read_idx, p)
    if ok then
      pcall(reaper.SetTrackSendInfo_Value, write_tr, write_cat, write_idx, p, v)
    end
  end
end

local function inherit_sends(src, dst)
  local n = reaper.GetTrackNumSends(src, 0)
  for i = 0, n - 1 do
    local dest = reaper.GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK")
    if dest and dest ~= dst then
      local newidx = reaper.CreateTrackSend(dst, dest)
      copy_send_params(src, 0, i, dst, 0, newidx)
    end
  end
end

local function inherit_receives(src, dst)
  local n = reaper.GetTrackNumSends(src, -1)
  for i = 0, n - 1 do
    local source = reaper.GetTrackSendInfo_Value(src, -1, i, "P_SRCTRACK")
    if source and source ~= dst then
      reaper.CreateTrackSend(source, dst)
      local newidx = reaper.GetTrackNumSends(source, 0) - 1
      copy_send_params(src, -1, i, source, 0, newidx)
    end
  end
end

local function inherit_hw_outs(src, dst)
  local n = reaper.GetTrackNumSends(src, 1)
  for i = 0, n - 1 do
    local newidx = reaper.CreateTrackSend(dst, nil)
    local params = { "D_VOL", "I_DSTCHAN", "B_MUTE" }
    for _, p in ipairs(params) do
      local v = reaper.GetTrackSendInfo_Value(src, 1, i, p)
      reaper.SetTrackSendInfo_Value(dst, 1, newidx, p, v)
    end
  end
end

local function inherit_main_send(src, dst)
  local v = reaper.GetMediaTrackInfo_Value(src, "B_MAINSEND")
  reaper.SetMediaTrackInfo_Value(dst, "B_MAINSEND", v)
end

local function inherit_from(parent, dst)
  if COPY_INPUT then copy_input(parent, dst) end
  if COPY_MAIN_SEND then inherit_main_send(parent, dst) end
  if COPY_SENDS then inherit_sends(parent, dst) end
  if COPY_RECEIVES then inherit_receives(parent, dst) end
  if COPY_HW_OUTS then inherit_hw_outs(parent, dst) end
end

local tracks = collect_selected_tracks()
if #tracks == 0 then
  reaper.ShowMessageBox("Select at least one child track.", "Inherit From Parent", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local changed = {}
for _, tr in ipairs(tracks) do
  local parent = reaper.GetParentTrack(tr)
  if parent then
    inherit_from(parent, tr)
    changed[#changed + 1] = tr
  end
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Inherit MIDI input and routing from parent", -1)

if #changed == 0 then
  reaper.ShowMessageBox("None of the selected tracks have a parent folder.", "Inherit From Parent", 0)
end
