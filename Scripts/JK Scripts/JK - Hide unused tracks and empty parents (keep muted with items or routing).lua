-- @description Hide unused tracks and parents with nothing used inside; muted tracks stay visible if they have items or incoming routing
-- @author Jonathan Kawchuk (generated with Claude)
--
-- A track is "used" if it has any media item OR any receive (audio/MIDI routing into it).
-- Mute state is ignored: a muted track with items or receives stays visible.
-- Folder (parent) tracks are visible if they are used themselves or contain a visible descendant;
-- otherwise they are hidden.
--
-- Toggle: running again restores only the tracks this script hid last time (tracks you hid
-- manually are left alone). Only TCP visibility (B_SHOWINTCP) is changed.

local EXT_SECTION = "JK_HideUnusedKeepMuted"
local EXT_KEY = "hidden_track_guids"

local function get_track_by_guid(guid)
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    if reaper.GetTrackGUID(tr) == guid then return tr end
  end
end

local function try_restore()
  local state = reaper.GetExtState(EXT_SECTION, EXT_KEY)
  if state == "" then return false end
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for guid in state:gmatch("[^,]+") do
    local tr = get_track_by_guid(guid)
    if tr then reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", 1) end
  end
  reaper.SetExtState(EXT_SECTION, EXT_KEY, "", false)
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Restore track visibility (unused tracks)", -1)
  return true
end

if try_restore() then return end

local track_count = reaper.CountTracks(0)
local info, folder_stack = {}, {}

for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  local fd = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  info[i + 1] = {
    track = track,
    fd = fd,
    used = reaper.CountTrackMediaItems(track) > 0 or reaper.GetTrackNumSends(track, -1) > 0,
    sub_end = nil,
    visible = false,
  }
  if fd == 1 then folder_stack[#folder_stack + 1] = i + 1 end
  if fd < 0 then
    for _ = 1, -fd do
      local top = folder_stack[#folder_stack]
      folder_stack[#folder_stack] = nil
      if top then info[top].sub_end = i + 1 end
    end
  end
end
for _, top in ipairs(folder_stack) do info[top].sub_end = track_count end

-- bottom-up so inner folders resolve before their parents
for i = track_count, 1, -1 do
  local e = info[i]
  e.visible = e.used
  if not e.visible and e.fd == 1 then
    for j = e.sub_end or i, i + 1, -1 do
      if info[j].visible then e.visible = true break end
    end
  end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local hidden_guids = {}
for i = 1, track_count do
  local e = info[i]
  if not e.visible and reaper.GetMediaTrackInfo_Value(e.track, "B_SHOWINTCP") == 1 then
    hidden_guids[#hidden_guids + 1] = reaper.GetTrackGUID(e.track)
    reaper.SetMediaTrackInfo_Value(e.track, "B_SHOWINTCP", 0)
  end
end

if #hidden_guids > 0 then
  reaper.SetExtState(EXT_SECTION, EXT_KEY, table.concat(hidden_guids, ","), false)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Hide unused tracks and empty parents", -1)
