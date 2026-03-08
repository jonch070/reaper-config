-- This script is not meant to be used individually
-- it is referenced by "ReaSoundly - Loop items to time selection (Duplicate Items).lua" and "ReaSoundly - Loop items to time selection (Loop Source).lua"

local info = debug.getinfo(1, 'S');
local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/ReaSoundly - Common Functions.lua')

local start_sel, end_sel = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
local prompt_user = true
local crossfade_dur
local new_items = {}

local function AddSelectedItemToTable()
  local item = reaper.GetSelectedMediaItem(0, 0)
  reaper.SetMediaItemSelected(item, false)
  table.insert(new_items, item)
end

local function GetItemBounds(item)
  local start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local end_pos = start_pos + length

  return start_pos, end_pos
end

local function ExecuteCmd(item_start, item_end, duplicate)
  local inside_ts = item_start <= start_sel and item_end >= end_sel
  if inside_ts then
    local cmd = reaper.NamedCommandLookup("_SWS_AWTRIMCROP") -- SWS/AW: Trim selected items to selection or cursor (crop)
    reaper.Main_OnCommand(cmd, 0)
  else
    if not duplicate then
      reaper.Main_OnCommand(41320, 0) -- Item: Move items to time selection, trim/loop to fit
      AddSelectedItemToTable()
    else
      -- get time selection length
      local ts_length = end_sel - start_sel
      local item_length = item_end - item_start

      if ts_length > item_length then
        if prompt_user then
          local rv, val = reaper.GetUserInputs(ReaSoundly.GetScriptName(), 1, "Crossfade (sec)",
            tostring(settings.crossfade_dur))
          if tonumber(val) then
            crossfade_dur = tonumber(val)
          end
          prompt_user = false
        end

        local item = reaper.GetSelectedMediaItem(0, 0)
        reaper.SetMediaItemPosition(item, start_sel, true)

        local duplicate_count = (ts_length - crossfade_dur) / (item_length - crossfade_dur)

        table.insert(new_items, item)

        for i = 1, duplicate_count do
          reaper.Main_OnCommand(41295, 0) -- Item: Duplicate items
          local item = reaper.GetSelectedMediaItem(0, 0)
          local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") - crossfade_dur

          reaper.SetMediaItemPosition(item, item_pos, true)
          table.insert(new_items, item)
        end

        local item = reaper.GetSelectedMediaItem(0, 0)
        reaper.SetMediaItemSelected(item, false)
      else
        reaper.Main_OnCommand(41320, 0) -- Item: Move items to time selection, trim/loop to fit
        AddSelectedItemToTable()
      end
    end
  end
end

function ExecuteScript(duplicate)
  -- stop script if there is no time selection
  if start_sel == end_sel then
    return
  end

  local files = ReaSoundly.GetFiles()
  local items = ReaSoundly.CacheSelectedItems()

  -- stop script if no media items are selected or cached
  if #items == 0 then
    return
  end

  ReaSoundly.SetItemsSelected(items, false)

  reaper.Undo_BeginBlock2(0)

  ReaSoundly.LoadSettings()
  crossfade_dur = settings.crossfade_dur

  if ReaSoundly.LoadImportMode() == "1" then
    local min_range = reaper.GetProjectLength(0)
    local max_range = 0

    for _, item in pairs(items) do
      local file = ReaSoundly.FindTakeInFiles(files, item)

      if file then
        reaper.SetMediaItemSelected(item, true)

        local start_pos, end_pos = GetItemBounds(item)
        if start_pos < min_range then min_range = start_pos end
        if end_pos > max_range then max_range = end_pos end
      end
    end

    ExecuteCmd(min_range, max_range)
  else
    for _, item in pairs(items) do
      local file = ReaSoundly.FindTakeInFiles(files, item)

      if file then
        reaper.SetMediaItemSelected(item, true)
        local start_pos, end_pos = GetItemBounds(item)
        ExecuteCmd(start_pos, end_pos, duplicate)
      end
    end

    -- Reselect all items
    ReaSoundly.SetItemsSelected(new_items, true)

    if duplicate then
      reaper.Main_OnCommand(41059, 0)                          -- Item: Crossfade any overlapping items
      local cmd = reaper.NamedCommandLookup("_SWS_AWTRIMCROP") -- SWS/AW: Trim selected items to selection or cursor (crop)
      reaper.Main_OnCommand(cmd, 0)
    end
  end

  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(0, ReaSoundly.GetScriptName(), 0)
end
