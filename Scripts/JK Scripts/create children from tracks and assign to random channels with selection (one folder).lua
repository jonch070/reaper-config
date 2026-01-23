-- Random Channel Routing from Tracks (Single Parent) - General/Unlimited Channels
-- Takes all selected tracks and:
--   * prompts for channels to include and exclude (numbers only)
--   * supports ranges like 1-3 and lists like 1, 5, 6
--   * no channel limit - use for non-standard or high channel count systems
--   * optional "fill first" mode: uses each channel once before repeating
--   * uses the first selected track as parent folder
--   * makes remaining selected tracks children of the parent
--   * routes each child: SRC mono ch1 -> random mono parent channel from allowed list

-- Parse a channel specification string into a list of channel numbers
-- Supports: "1-3" (range), "1, 5, 6" (list), "1-3, 7, 9-11" (mixed)
local function parse_channel_spec(spec)
  if not spec or spec == "" then return {} end

  local channels = {}
  local seen = {}

  -- Split by comma
  for part in string.gmatch(spec, "[^,]+") do
    part = part:match("^%s*(.-)%s*$") -- trim whitespace

    -- Check if it's a range (contains dash)
    local range_start, range_end = part:match("^(%d+)%s*%-%s*(%d+)$")
    if range_start and range_end then
      local start_num = tonumber(range_start)
      local end_num = tonumber(range_end)
      if start_num and end_num and start_num >= 1 and end_num >= 1 then
        local step = start_num <= end_num and 1 or -1
        for i = start_num, end_num, step do
          if not seen[i] then
            table.insert(channels, i)
            seen[i] = true
          end
        end
      end
    else
      -- Single number
      local num = tonumber(part)
      if num and num >= 1 and not seen[num] then
        table.insert(channels, num)
        seen[num] = true
      end
    end
  end

  table.sort(channels)
  return channels
end

-- Build available channels from include list minus exclude list
local function build_available_channels(include_spec, exclude_spec)
  local include_channels = parse_channel_spec(include_spec)
  local exclude_channels = parse_channel_spec(exclude_spec)

  if #include_channels == 0 then
    return {}
  end

  local exclude_set = {}
  for _, ch in ipairs(exclude_channels) do
    exclude_set[ch] = true
  end

  local available = {}
  for _, ch in ipairs(include_channels) do
    if not exclude_set[ch] then
      table.insert(available, ch)
    end
  end

  return available
end

-- Shuffle array in place (Fisher-Yates)
local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

-- Generate channel assignments for N children
-- If fill_first is true, uses each channel once before repeating
local function generate_channel_assignments(available_channels, num_children, fill_first)
  local assignments = {}

  if fill_first and #available_channels > 0 then
    -- Fill all channels first, then repeat randomly
    local pool = {}
    while #assignments < num_children do
      if #pool == 0 then
        -- Refill and shuffle the pool
        for _, ch in ipairs(available_channels) do
          table.insert(pool, ch)
        end
        shuffle(pool)
      end
      table.insert(assignments, table.remove(pool))
    end
  else
    -- Pure random selection
    for i = 1, num_children do
      table.insert(assignments, available_channels[math.random(#available_channels)])
    end
  end

  return assignments
end

-- Collect all selected tracks
local function collect_selected_tracks()
  local tracks = {}
  local sel_trk_count = reaper.CountSelectedTracks(0)

  if sel_trk_count > 0 then
    for i = 0, sel_trk_count - 1 do
      table.insert(tracks, reaper.GetSelectedTrack(0, i))
    end
  end

  return tracks
end

-- Check track count first
local tracks = collect_selected_tracks()
if #tracks < 2 then
  reaper.ShowMessageBox("Select at least 2 tracks (first = parent, rest = children)", "Error", 0)
  return
end

-- Prompt for channel specifications
local retval, user_input = reaper.GetUserInputs(
  "Channel Selection (General)",
  3,
  "Include channels (e.g. 1-32 or 1, 5, 17-24):,Exclude channels (e.g. 4 or 1-3, 16):,Fill all channels before repeating? (y/n):,extrawidth=120",
  ",,y"
)

if not retval then return end

-- Parse input
local parts = {}
for part in user_input:gmatch("([^,]*),?") do
  table.insert(parts, part)
end

local include_spec = parts[1] or ""
local exclude_spec = parts[2] or ""
local fill_first_input = (parts[3] or "y"):lower():gsub("%s+", "")
local fill_first = (fill_first_input == "y" or fill_first_input == "yes" or fill_first_input == "1")

local available_channels = build_available_channels(include_spec, exclude_spec)

if #available_channels == 0 then
  reaper.ShowMessageBox("No valid channels specified.\n\nUse formats like:\n- Ranges: 1-32\n- Lists: 1, 5, 17\n- Mixed: 1-8, 17-24", "Error", 0)
  return
end

-- Determine minimum parent channels needed
local max_channel = 0
for _, ch in ipairs(available_channels) do
  if ch > max_channel then max_channel = ch end
end
local MIN_PARENT_CHANS = max_channel

-- Seed RNG
math.randomseed(math.floor(reaper.time_precise() * 1e6) % 2^31)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local parent = tracks[1]

local parent_chans = reaper.GetMediaTrackInfo_Value(parent, "I_NCHAN")
if parent_chans < MIN_PARENT_CHANS then
  reaper.SetMediaTrackInfo_Value(parent, "I_NCHAN", MIN_PARENT_CHANS)
end

local parent_idx = reaper.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER") - 1

local children = {}
for i = 2, #tracks do
  table.insert(children, tracks[i])
end

for i, child in ipairs(children) do
  local target_idx = parent_idx + i
  reaper.SetOnlyTrackSelected(child)
  reaper.ReorderSelectedTracks(target_idx, 0)
end

reaper.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)

local last_child = children[#children]
local lastSelIdx = reaper.GetMediaTrackInfo_Value(last_child, "IP_TRACKNUMBER") - 1
local curDepth = 0
for trackIdx = lastSelIdx, reaper.CountTracks(0) - 1 do
  local track = reaper.GetTrack(0, trackIdx)
  local trackDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  curDepth = curDepth + trackDepth
  if curDepth <= 0 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", trackDepth - 1)
    break
  end
end

-- Generate channel assignments
local channel_assignments = generate_channel_assignments(available_channels, #children, fill_first)

for i, child in ipairs(children) do
  reaper.SetMediaTrackInfo_Value(child, "B_MAINSEND", 0)
  local send_idx = reaper.CreateTrackSend(child, parent)
  local target_chan = channel_assignments[i]
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_SRCCHAN", 1024)
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_DSTCHAN", 1024 + (target_chan - 1))
end

reaper.Main_OnCommand(40297, 0)
reaper.SetTrackSelected(parent, true)
for _, child in ipairs(children) do
  reaper.SetTrackSelected(child, true)
end

reaper.TrackList_AdjustWindows(false)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Random channel routing (single parent, custom)", -1)
