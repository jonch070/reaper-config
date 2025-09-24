-- Randomize item output channel (skip channel 4)
-- Works on selected items in REAPER

function RandomizeItemChannel()
  local numItems = reaper.CountSelectedMediaItems(0)
  if numItems == 0 then return end

  -- use the track of the first selected item to get channel count
  local firstItem = reaper.GetSelectedMediaItem(0, 0)
  local track = reaper.GetMediaItem_Track(firstItem)
  local trackChannels = math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") or 2)

  if trackChannels < 2 then return end

  -- build a list of allowed channels (skip 4)
  local allowedChannels = {}
  for ch = 1, trackChannels do
    if ch ~= 4 then
      table.insert(allowedChannels, ch)
    end
  end

  for i = 0, numItems-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take ~= nil then
      -- pick random channel from allowed list
      local randIndex = math.random(#allowedChannels)
      local randChan = allowedChannels[randIndex]

      -- set take to mono (so one channel is routed)
      reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 0)

      -- set channel mapping bitmask: 2^(chan-1)
      reaper.SetMediaItemTakeInfo_Value(take, "C_CHANNEL_MAPPING", 2^(randChan-1))
    end
  end
  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
RandomizeItemChannel()
reaper.Undo_EndBlock("Randomize item output channels (skip ch4)", -1)
