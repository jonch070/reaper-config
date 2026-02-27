-- Solo Random Tracks
-- Solos a random number of tracks in the project.
-- Options: specify how many tracks to solo (or "random"), skip muted tracks.

-- Prompt user for settings
local ret, csv = reaper.GetUserInputs(
  "Solo Random Tracks", 2,
  "Number of tracks to solo (or 'random'),Skip muted tracks? (y/n),extrawidth=80",
  "random,y"
)
if not ret then return end

local num_input, skip_muted_input = csv:match("([^,]+),([^,]+)")
num_input = num_input and num_input:match("^%s*(.-)%s*$") or "random"
skip_muted_input = skip_muted_input and skip_muted_input:match("^%s*(.-)%s*$") or "y"

local skip_muted = (skip_muted_input:lower() == "y" or skip_muted_input:lower() == "yes")
local randomize_count = (num_input:lower() == "random" or num_input:lower() == "r")
local solo_count = tonumber(num_input)

if not randomize_count and not solo_count then
  reaper.ShowMessageBox("Invalid input. Enter a number or 'random'.", "Error", 0)
  return
end

if solo_count and solo_count < 1 then
  reaper.ShowMessageBox("Number of tracks to solo must be at least 1.", "Error", 0)
  return
end

-- Build list of eligible tracks
local total_tracks = reaper.CountTracks(0)
if total_tracks == 0 then
  reaper.ShowMessageBox("No tracks in project!", "Error", 0)
  return
end

local eligible = {}
for i = 0, total_tracks - 1 do
  local track = reaper.GetTrack(0, i)
  local dominated_by_folder_solo = false

  if skip_muted then
    local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
    if mute == 1 then goto continue end

    -- Also check if a parent folder is muted
    local parent = reaper.GetParentTrack(track)
    while parent do
      if reaper.GetMediaTrackInfo_Value(parent, "B_MUTE") == 1 then
        dominated_by_folder_solo = true
        break
      end
      parent = reaper.GetParentTrack(parent)
    end
    if dominated_by_folder_solo then goto continue end
  end

  table.insert(eligible, track)
  ::continue::
end

if #eligible == 0 then
  reaper.ShowMessageBox("No eligible tracks found (all muted?).", "Error", 0)
  return
end

-- Determine how many tracks to solo
if randomize_count then
  solo_count = math.random(1, #eligible)
end

if solo_count > #eligible then
  solo_count = #eligible
end

-- Shuffle eligible tracks using Fisher-Yates
math.randomseed(os.time())
for i = #eligible, 2, -1 do
  local j = math.random(1, i)
  eligible[i], eligible[j] = eligible[j], eligible[i]
end

reaper.Undo_BeginBlock()

-- Unsolo all tracks first
for i = 0, total_tracks - 1 do
  local track = reaper.GetTrack(0, i)
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
end

-- Solo the randomly chosen tracks
local soloed_names = {}
for i = 1, solo_count do
  reaper.SetMediaTrackInfo_Value(eligible[i], "I_SOLO", 2) -- solo in place
  local _, name = reaper.GetTrackName(eligible[i])
  table.insert(soloed_names, name)
end

reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Solo " .. solo_count .. " random tracks", -1)

-- Show result
local skip_str = skip_muted and " (skipped muted)" or ""
reaper.ShowMessageBox(
  "Soloed " .. solo_count .. " of " .. #eligible .. " eligible tracks" .. skip_str .. ":\n\n" ..
  table.concat(soloed_names, "\n"),
  "Solo Random Tracks", 0
)
