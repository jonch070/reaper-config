-- Hide, within the time selection, tracks that are empty or muted and their folders.
-- End state: only tracks that have items AND are unmuted remain visible.
-- A muted folder track is hidden along with its entire subtree.
-- An empty folder track is hidden unless it still contains a visible descendant.
--
-- Toggle behavior: running this again restores the tracks this script hid last time
-- (only those tracks -- tracks the user hid manually for other reasons are left alone).
-- A third run hides again, and so on. Restoring never requires a time selection; the
-- "no time selection" bail-out only applies when a hide pass is about to run.
--
-- Only TCP visibility (B_SHOWINTCP) is toggled. MCP visibility (B_SHOWINMIXER) is left
-- untouched, matching the original script's behavior.

local EXT_SECTION = "JK_HideTracksWithoutItemsOrMuted_TimeSelection"
local EXT_KEY = "hidden_track_guids"

local function get_track_by_guid(guid)
  local count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if reaper.GetTrackGUID(tr) == guid then
      return tr
    end
  end
  return nil
end

-- If a previous run left tracks hidden, restore them and report true (script is done).
-- Otherwise report false so the caller proceeds with the hide pass.
local function try_restore()
  local state = reaper.GetExtState(EXT_SECTION, EXT_KEY)
  if state == "" then
    return false
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for guid in state:gmatch("[^,]+") do
    local tr = get_track_by_guid(guid)
    if tr then
      reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", 1)
    end
  end

  reaper.SetExtState(EXT_SECTION, EXT_KEY, "", false)

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Restore track visibility (time selection)", -1)
  return true
end

if try_restore() then return end

local function track_has_item_in_time_sel(track, sel_start, sel_end)
  local item_count = reaper.CountTrackMediaItems(track)
  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if item_start < sel_end and item_end > sel_start then
      return true
    end
  end
  return false
end

local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

if sel_start == sel_end then
  reaper.ShowMessageBox("No time selection found.", "Hide Tracks Without Items", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local track_count = reaper.CountTracks(0)

local info = {}
local folder_stack = {}
local hide_stack = { [0] = false } -- hide_stack[depth] = whether the folder at that depth is mute-hidden
local depth = 0

for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  local fd = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  local muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
  local ancestor_hidden = hide_stack[depth]
  local hidden_by_mute = ancestor_hidden or muted

  info[i + 1] = {
    track = track,
    fd = fd,
    has_item = track_has_item_in_time_sel(track, sel_start, sel_end),
    hidden_by_mute = hidden_by_mute,
    sub_end = nil,
    visible = false,
  }

  if fd == 1 then -- this track opens a new folder; children inherit its hidden state
    folder_stack[#folder_stack + 1] = i + 1
    depth = depth + 1
    hide_stack[depth] = hidden_by_mute
  end

  if fd < 0 then -- this track closes one or more enclosing folders (fd can be -1, -2, ...)
    for _ = 1, -fd do
      local top = folder_stack[#folder_stack]
      folder_stack[#folder_stack] = nil
      if top then
        info[top].sub_end = i + 1
      end
      hide_stack[depth] = nil
      if depth > 0 then depth = depth - 1 end
    end
  end
end

-- Folders left open at the end of the track list (no explicit closing track) span to the last track.
for _, top in ipairs(folder_stack) do
  info[top].sub_end = track_count
end

for i = track_count, 1, -1 do -- bottom-up so inner folders resolve before their parents
  local e = info[i]
  if e.fd ~= 1 then -- non-folder track: visible only if unmuted and has an item in range
    e.visible = not e.hidden_by_mute and e.has_item
  elseif not e.hidden_by_mute then -- folder: visible only if it has a visible descendant
    local any = false
    local last = e.sub_end or i
    for j = last, i + 1, -1 do
      if info[j].visible then any = true break end
    end
    e.visible = any
  end
end

local hidden_guids = {}
for i = 1, track_count do
  local e = info[i]
  if not e.visible then
    if reaper.GetMediaTrackInfo_Value(e.track, "B_SHOWINTCP") == 1 then
      hidden_guids[#hidden_guids + 1] = reaper.GetTrackGUID(e.track)
    end
    reaper.SetMediaTrackInfo_Value(e.track, "B_SHOWINTCP", 0)
  end
end

if #hidden_guids > 0 then
  reaper.SetExtState(EXT_SECTION, EXT_KEY, table.concat(hidden_guids, ","), false)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Hide other tracks (time selection)", -1)
