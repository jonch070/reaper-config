-- Random Channel Routing from Tracks (Multiple Folders) - 7.1.4 With Channel Selection
-- Takes all selected tracks and:
--   * prompts for channels to include and exclude
--   * supports channel names (L, R, C, LFE, Lss, Rss, Lrs, Rrs, Ltf, Rtf, Ltr/Ltb, Rtr/Rtb)
--   * letter order doesn't matter: ltf, lft, tfl all work
--   * supports ranges like 1-3 and lists like 1, 5, 6
--   * optional "fill first" mode: uses each channel once before repeating
--   * uses the first selected track as parent folder
--   * makes remaining selected tracks children of the parent
--   * routes each child: SRC mono ch1 -> random mono parent channel from allowed list

local MAX_CHANNELS = 12

-- 7.1.4 SMPTE/Dolby channel mapping
-- Keys are sorted lowercase letters for permutation-tolerant matching
local CHANNEL_NAMES_SORTED = {
  ["l"] = 1,       -- L (Left)
  ["r"] = 2,       -- R (Right)
  ["c"] = 3,       -- C (Center)
  ["efl"] = 4,     -- LFE (sorted: efl)
  ["lss"] = 5,     -- Lss (Left Side Surround)
  ["rss"] = 6,     -- Rss (Right Side Surround)
  ["lrs"] = 7,     -- Lrs (Left Rear Surround)
  ["rrs"] = 8,     -- Rrs (Right Rear Surround)
  ["flt"] = 9,     -- Ltf (Left Top Front, sorted: flt)
  ["frt"] = 10,    -- Rtf (Right Top Front, sorted: frt)
  ["lrt"] = 11,    -- Ltr (Left Top Rear, sorted: lrt)
  ["rrt"] = 12,    -- Rtr (Right Top Rear, sorted: rrt)
  ["blt"] = 11,    -- Ltb/Lbt (Left Top Back = Left Top Rear, sorted: blt)
  ["brt"] = 12,    -- Rtb/Rbt (Right Top Back = Right Top Rear, sorted: brt)
}

-- Exact match names (case insensitive)
local CHANNEL_NAMES_EXACT = {
  ["left"] = 1,
  ["right"] = 2,
  ["center"] = 3,
  ["centre"] = 3,
  ["sub"] = 4,
  ["subwoofer"] = 4,
  ["lfe"] = 4,
}

-- Sort characters in a string
local function sort_chars(s)
  local chars = {}
  for i = 1, #s do
    table.insert(chars, s:sub(i, i))
  end
  table.sort(chars)
  return table.concat(chars)
end

-- Parse a single token (number or channel name) to channel number
local function parse_token(token)
  token = token:lower():gsub("%s+", "") -- lowercase, remove spaces

  -- Try as number first
  local num = tonumber(token)
  if num then return num end

  -- Try exact match
  if CHANNEL_NAMES_EXACT[token] then
    return CHANNEL_NAMES_EXACT[token]
  end

  -- Try sorted-letter match (permutation tolerant)
  local sorted = sort_chars(token)
  if CHANNEL_NAMES_SORTED[sorted] then
    return CHANNEL_NAMES_SORTED[sorted]
  end

  return nil
end

-- Parse a channel specification string into a list of channel numbers
-- Supports: "1-3" (range), "1, 5, 6" (list), "l-c" (name range), "l, lfe, ltf" (name list)
local function parse_channel_spec(spec)
  if not spec or spec == "" then return {} end

  local channels = {}
  local seen = {}

  -- Split by comma
  for part in string.gmatch(spec, "[^,]+") do
    part = part:match("^%s*(.-)%s*$") -- trim whitespace

    -- Check if it's a range (contains dash not at start)
    local range_start, range_end = part:match("^(.+)%s*%-%s*(.+)$")
    if range_start and range_end then
      local start_num = parse_token(range_start)
      local end_num = parse_token(range_end)
      if start_num and end_num then
        local step = start_num <= end_num and 1 or -1
        for i = start_num, end_num, step do
          if i >= 1 and i <= MAX_CHANNELS and not seen[i] then
            table.insert(channels, i)
            seen[i] = true
          end
        end
      end
    else
      -- Single token
      local num = parse_token(part)
      if num and num >= 1 and num <= MAX_CHANNELS and not seen[num] then
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
  "7.1.4 Channel Selection",
  3,
  "Include (e.g. 1-12 or L, Lss-Rrs, Ltf):,Exclude (e.g. LFE or 4, Lrs-Rrs):,Fill all channels before repeating? (y/n):,extrawidth=120",
  "1-12,4,y"
)

if not retval then return end

-- Parse input - fields are comma-separated, but include/exclude can contain commas
-- So we find the last two commas (field separators) and parse from there
local comma_positions = {}
local pos = 1
while true do
  local found = user_input:find(",", pos)
  if not found then break end
  table.insert(comma_positions, found)
  pos = found + 1
end

local include_spec, exclude_spec, fill_first_input
if #comma_positions >= 2 then
  local second_last = comma_positions[#comma_positions - 1]
  local last = comma_positions[#comma_positions]
  include_spec = user_input:sub(1, second_last - 1)
  exclude_spec = user_input:sub(second_last + 1, last - 1)
  fill_first_input = user_input:sub(last + 1)
elseif #comma_positions == 1 then
  include_spec = user_input:sub(1, comma_positions[1] - 1)
  exclude_spec = ""
  fill_first_input = user_input:sub(comma_positions[1] + 1)
else
  include_spec = user_input
  exclude_spec = ""
  fill_first_input = "y"
end

fill_first_input = (fill_first_input or "y"):lower():gsub("%s+", "")
local fill_first = (fill_first_input == "y" or fill_first_input == "yes" or fill_first_input == "1")

local available_channels = build_available_channels(include_spec, exclude_spec)

if #available_channels == 0 then
  reaper.ShowMessageBox("No valid channels specified.\n\nUse formats like:\n- Numbers: 1-12, 1, 5, 6\n- Names: L, R, C, LFE, Lss, Rss, Lrs, Rrs, Ltf, Rtf, Ltr, Rtr\n- Also: Ltb/Rtb (Top Back = Top Rear)\n- Letter order flexible: ltf, lft, tfl all work\n- Mixed: L-C, lfe, 9-12", "Error", 0)
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
reaper.Undo_EndBlock("Random channel routing 7.1.4 (multiple folders)", -1)
