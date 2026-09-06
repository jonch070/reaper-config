--[[
@description jk_Select items shorter than (ms)
@version 0.1
@author Jonathan Kawchuk
@about
  From the current item selection, deselects items whose length
  is >= the given threshold (milliseconds). Only items shorter
  than the threshold remain selected.
]]--

reaper.Undo_BeginBlock()

local retval, threshold_str = reaper.GetUserInputs("Select items shorter than", 1, "Max length (ms):", "100")
if not retval then return end

local threshold_ms = tonumber(threshold_str)
if not threshold_ms or threshold_ms <= 0 then return end

local threshold_sec = threshold_ms / 1000.0

for i = reaper.CountSelectedMediaItems(0) - 1, 0, -1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if len >= threshold_sec then
    reaper.SetMediaItemSelected(item, false)
  end
end

reaper.Undo_EndBlock("Select items shorter than " .. threshold_str .. " ms", -1)
reaper.UpdateArrange()
