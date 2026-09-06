-- Children Inherit MIDI Input & Routing (first selected = source)
-- Select source (parent) track FIRST, then any number of target tracks. Run.
-- Targets inherit the source's MIDI input + channel (I_RECINPUT).
-- Optionally inherits sends / receives / hardware outputs (CONFIG below).

local COPY_INPUT     = true
local COPY_SENDS     = true
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

local function copy_send_params(src_send_cat, src_idx, dst, dst_cat, dst_idx, other)
  local params = {
    "D_VOL", "D_PAN", "B_MUTE", "B_PHASE",
    "I_SENDMODE", "I_AUTOMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDIFLAGS",
  }
  for _, p in ipairs(params) do
    local ok, v = pcall(reaper.GetTrackSendInfo_Value, other or dst, src_send_cat, src_idx, p)
    if ok then
      pcall(reaper.SetTrackSendInfo_Value, dst, dst_cat, dst_idx, p, v)
    end
  end
end

local function inherit_sends(src, dst)
  local n = reaper.GetTrackNumSends(src, 0)
  for i = 0, n - 1 do
    local dest = reaper.GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK")
    if dest and dest ~= dst then
      local newidx = reaper.CreateTrackSend(dst, dest)
      copy_send_params(0, i, dst, 0, newidx, src)
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
      copy_send_params(-1, i, source, 0, newidx, src)
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

local tracks = collect_selected_tracks()
if #tracks < 2 then
  reaper.ShowMessageBox("Select the SOURCE track first, then the tracks that should inherit from it.\n\n(needs at least 2 selected tracks)", "Inherit From First Selected", 0)
  return
end

local src = table.remove(tracks, 1)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

for _, dst in ipairs(tracks) do
  if COPY_INPUT then copy_input(src, dst) end
  if COPY_MAIN_SEND then inherit_main_send(src, dst) end
  if COPY_SENDS then inherit_sends(src, dst) end
  if COPY_RECEIVES then inherit_receives(src, dst) end
  if COPY_HW_OUTS then inherit_hw_outs(src, dst) end
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Inherit MIDI input and routing from first selected", -1)
