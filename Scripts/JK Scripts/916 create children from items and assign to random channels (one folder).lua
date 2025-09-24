-- Random Channel Routing
-- Moves selected items into child tracks under parent
-- Routes child channel 1 to random mono parent channel (1–16, skip 4)
-- Selects parent + all child tracks at the end

local item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then return end

local first_item = reaper.GetSelectedMediaItem(0, 0)
local original_track = reaper.GetMediaItem_Track(first_item)
local channel_count = reaper.GetMediaTrackInfo_Value(original_track, "I_NCHAN")
if channel_count < 16 then channel_count = 16 end -- ensure parent has 16 channels
local orig_track_idx = reaper.GetMediaTrackInfo_Value(original_track, "IP_TRACKNUMBER") - 1

-- Available parent channels (skip 4)
local available_channels = {}
for i = 1, 16 do
  if i ~= 4 then
    table.insert(available_channels, i)
  end
end

-- Collect selected items
local items_to_move = {}
for i = 0, item_count - 1 do
  table.insert(items_to_move, reaper.GetSelectedMediaItem(0, i))
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Make parent a folder and prep for routing
reaper.SetMediaTrackInfo_Value(original_track, "I_FOLDERDEPTH", 1)
reaper.SetMediaTrackInfo_Value(original_track, "I_NCHAN", channel_count)
-- Do NOT disable parent master send

local child_tracks = {}
for i, item in ipairs(items_to_move) do
  local target_chan = available_channels[math.random(#available_channels)]

  -- Insert child track
  reaper.InsertTrackAtIndex(orig_track_idx + i, false)
  local child = reaper.GetTrack(0, orig_track_idx + i)
  table.insert(child_tracks, child)

  -- Move item to child
  reaper.MoveMediaItemToTrack(item, child)

  -- Configure child
  reaper.SetMediaTrackInfo_Value(child, "I_NCHAN", 2) -- stereo is enough
  reaper.SetMediaTrackInfo_Value(child, "B_MAINSEND", 0) -- disable child → master

  -- Create send child → parent
  local send_idx = reaper.CreateTrackSend(child, original_track)

  -- Source: mono channel 1
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_SRCCHAN", 1024)

  -- Destination: mono parent channel (1–16, skip 4)
  reaper.SetTrackSendInfo_Value(child, 0, send_idx, "I_DSTCHAN", 1024 + (target_chan - 1))
end

-- Close folder
if #child_tracks > 0 then
  reaper.SetMediaTrackInfo_Value(child_tracks[#child_tracks], "I_FOLDERDEPTH", -1)
end

-- Select parent + all children
reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
reaper.SetTrackSelected(original_track, true)
for _, t in ipairs(child_tracks) do
  reaper.SetTrackSelected(t, true)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

reaper.Undo_EndBlock("Random channel routing", -1)