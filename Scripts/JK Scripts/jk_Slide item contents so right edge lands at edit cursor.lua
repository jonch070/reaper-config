-- @description Slide contents of selected items so the end of the source media lands at the edit cursor
-- @about Item position and length stay put; only the take start offset changes (slip edit).

local cursor = reaper.GetCursorPosition()

local count = reaper.CountSelectedMediaItems(0)
if count == 0 then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

for i = 0, count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  local src = take and reaper.GetMediaItemTake_Source(take)
  if src then
    local srclen, isQN = reaper.GetMediaSourceLength(src)
    if not isQN then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
      -- source end sits at pos + (srclen - offs) / rate; solve for offs so that equals cursor
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", srclen - (cursor - pos) * rate)
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Slide item contents: source end to edit cursor", -1)
