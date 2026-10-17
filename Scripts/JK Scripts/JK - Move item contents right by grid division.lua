-- Slips the contents of selected items right by one grid division (item position/length unchanged).
-- Same effect as "Item edit: Move contents of items right", but the step is the current grid.
local dir = 1

-- Distance in seconds between the grid lines around `pos`, measured with REAPER's own snap
-- so it follows whatever grid is active (fixed division, relative to zoom, triplets...).
local function grid_step(pos)
  local g = reaper.SnapToGrid(0, pos)
  local delta = 1e-4
  for _ = 1, 40 do
    local s = reaper.SnapToGrid(0, g + delta) -- probe forward in time
    if s - g > 1e-9 then return s - g end
    delta = delta * 2
  end
  -- snap unavailable: fall back to the project grid division (whole notes)
  local r, d = reaper.GetSetProjectGrid(0, false)
  local div = d or r
  return reaper.TimeMap2_QNToTime(0, reaper.TimeMap2_timeToQN(0, pos) + div * 4) - pos
end

local n = reaper.CountSelectedMediaItems(0)
if n == 0 then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
for i = 0, n - 1 do
  local it = reaper.GetSelectedMediaItem(0, i)
  local dt = grid_step(reaper.GetMediaItemInfo_Value(it, "D_POSITION"))
  for t = 0, reaper.CountTakes(it) - 1 do
    local tk = reaper.GetTake(it, t)
    local rate = reaper.GetMediaItemTakeInfo_Value(tk, "D_PLAYRATE")
    local off = reaper.GetMediaItemTakeInfo_Value(tk, "D_STARTOFFS")
    -- contents move left = take start offset moves later in the source
    reaper.SetMediaItemTakeInfo_Value(tk, "D_STARTOFFS", off - dir * dt * rate)
  end
end
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Move item contents right by grid division", -1)
