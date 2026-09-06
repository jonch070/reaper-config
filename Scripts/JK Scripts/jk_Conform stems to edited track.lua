--[[
@description jk_Conform stems to edited track
@version 0.1
@author Jonathan Kawchuk
@about
  Conforms a folder of stems to an already-edited stereo reference track.

  Workflow this replaces:
    1. Select the "stereo edit" track (the one with the finished item edit,
       cut from a stereo mixdown).
    2. Duplicate that track once per stem, one by one.
    3. On each duplicate, select all items and replace their source with
       one of the stem files.
    4. Rename each item's take, and the track, to match the stem filename.

  This script does all of that in one pass:
    - Select the edited track, then run the script.
    - Pick the stem audio files (multi-select) in the dialog that opens.
    - One new track is created per stem, directly below the edited track,
      with the exact same item/edit structure. Each duplicate's item
      sources are swapped to the corresponding stem file (item position,
      length, and start-in-source offset are preserved — this only works
      if the stems are sample-aligned to the same timeline as the
      original stereo mix). Item takes and tracks are renamed to the
      stem's filename, and each new track's channel count is set to
      match its stem file (e.g. a 6-channel polywav gets a 6-channel
      track).

  Requires the js_ReaScriptAPI extension (for the multi-file browser). If
  it isn't installed, the script falls back to picking one stem file at a
  time (Cancel when you're done).
]]--


-- ── Config ──────────────────────────────────────────────────

local STRIP_EXTENSION = true   -- take/track names have no .wav / .mp3 suffix


-- ── Helpers ────────────────────────────────────────────────

local function basename(path)
  if not path then return "" end
  return path:match("([^/\\]+)$") or path
end

local function strip_ext(name)
  return (name:gsub("%.[^.]+$", ""))
end

-- Parses the NULL-delimited string returned by JS_Dialog_BrowseForOpenFiles
-- into a list of full file paths.
local function parse_js_filenames(str)
  local parts = {}
  for part in (str .. "\0"):gmatch("(.-)\0") do
    parts[#parts + 1] = part
  end
  while #parts > 0 and parts[#parts] == "" do table.remove(parts) end
  if #parts <= 1 then return parts end

  local folder = parts[1]
  local sep = folder:match("\\") and "\\" or "/"
  local files = {}
  for i = 2, #parts do
    files[#files + 1] = folder .. sep .. parts[i]
  end
  return files
end

-- Reads the channel count straight from the file (so it works even before
-- any take references it) and returns a value REAPER will accept for
-- I_NCHAN: even, clamped to [2, 64].
local function detect_channel_count(file_path)
  local probe = reaper.PCM_Source_CreateFromFile(file_path)
  if not probe then return 2 end
  local n = reaper.GetMediaSourceNumChannels(probe) or 2
  reaper.PCM_Source_Destroy(probe)

  if n < 2 then n = 2 end
  if n % 2 == 1 then n = n + 1 end
  if n > 64 then n = 64 end
  return n
end

local function pick_stem_files()
  if reaper.JS_Dialog_BrowseForOpenFiles then
    local filter = "Audio files\0*.wav;*.aif;*.aiff;*.mp3;*.flac;*.ogg;*.wv;*.bwf;*.w64\0All files\0*.*\0\0"
    local retval, files_str = reaper.JS_Dialog_BrowseForOpenFiles(
      "Select stem audio files (one per stem track)", "", "", filter, true)
    if not retval or files_str == "" then return {} end
    return parse_js_filenames(files_str)
  else
    local files = {}
    while true do
      local retval, fname = reaper.GetUserFileNameForRead("",
        string.format("Select stem file #%d (Cancel when done)", #files + 1), "")
      if not retval then break end
      files[#files + 1] = fname
    end
    return files
  end
end


-- ── Main ───────────────────────────────────────────────────

function main()
  local n_selected = reaper.CountSelectedTracks(0)
  if n_selected ~= 1 then
    reaper.ShowMessageBox(
      "Select exactly one track: the edited stereo track you want to conform stems to.",
      "Conform stems to edited track", 0)
    return
  end
  local edit_track = reaper.GetSelectedTrack(0, 0)

  local stems = pick_stem_files()
  if #stems == 0 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Phase 1: duplicate the edit track once per stem. Re-select the edit
  -- track before each duplicate so every copy comes from the untouched
  -- original, not from a previously-modified duplicate.
  local dup_tracks = {}
  for i = 1, #stems do
    reaper.SetOnlyTrackSelected(edit_track)
    reaper.Main_OnCommand(40062, 0) -- Track: Duplicate tracks
    dup_tracks[i] = reaper.GetSelectedTrack(0, 0)
  end

  -- Phase 2: sort duplicates top-to-bottom so stem order lines up with
  -- track order, regardless of the order REAPER stacked them while
  -- inserting each one directly below the edit track.
  table.sort(dup_tracks, function(a, b)
    return reaper.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER")
         < reaper.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
  end)

  -- Phase 3: swap sources and rename.
  local tracks_done, items_done, failed = 0, 0, {}
  for i, stem_path in ipairs(stems) do
    local track = dup_tracks[i]
    local stem_name = basename(stem_path)
    if STRIP_EXTENSION then stem_name = strip_ext(stem_name) end

    reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", detect_channel_count(stem_path))

    local n_items = reaper.CountTrackMediaItems(track)
    for it = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, it)
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local new_source = reaper.PCM_Source_CreateFromFile(stem_path)
        if new_source then
          reaper.SetMediaItemTake_Source(take, new_source)
          reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", stem_name, true)
          items_done = items_done + 1
        end
      end
    end

    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", stem_name, true)
    tracks_done = tracks_done + 1
  end

  reaper.SetOnlyTrackSelected(edit_track)
  for _, track in ipairs(dup_tracks) do
    reaper.SetTrackSelected(track, true)
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Conform stems to edited track", -1)

  reaper.ShowMessageBox(
    string.format("Stems conformed: %d\nTracks created: %d\nItems updated: %d",
      #stems, tracks_done, items_done),
    "Conform stems to edited track", 0)
end


main()
