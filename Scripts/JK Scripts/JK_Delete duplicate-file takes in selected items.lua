-- @description Flag and delete takes that point to the same source file within an item
-- @about
--   For every selected item, finds takes that reference the same audio file
--   (first take wins). Lists the duplicates, asks for confirmation, then deletes them.
--   Set MATCH_OFFSET_AND_RATE = true to only treat takes as duplicates when
--   the source start offset and playrate also match (safer for comps/alt sections).

local MATCH_OFFSET_AND_RATE = false

local r = reaper
local DELETE_ACTIVE_TAKE = 40129 -- Take: Delete active take from items

local function root_source(take)
  local src = r.GetMediaItemTake_Source(take)
  while src do
    local parent = r.GetMediaSourceParent(src)
    if not parent then break end
    src = parent
  end
  return src
end

local function take_key(take)
  if r.TakeIsMIDI(take) then return nil end
  local src = root_source(take)
  if not src then return nil end
  local path = r.GetMediaSourceFileName(src, "")
  if not path or path == "" then return nil end
  path = path:gsub("\\", "/")
  if MATCH_OFFSET_AND_RATE then
    path = string.format("%s|%.6f|%.6f",
      path,
      r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
      r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"))
  end
  return path
end

local function main()
  local n_items = r.CountSelectedMediaItems(0)
  if n_items == 0 then
    r.ShowMessageBox("Select one or more items first.", "Delete duplicate-file takes", 0)
    return
  end

  -- find duplicates: { {item=, take_idx=, desc=}, ... }
  local dupes, lines = {}, {}
  for i = 0, n_items - 1 do
    local item = r.GetSelectedMediaItem(0, i)
    local seen = {}
    for t = 0, r.CountTakes(item) - 1 do
      local take = r.GetTake(item, t)
      local key = take and take_key(take)
      if key then
        if seen[key] then
          local track = r.GetMediaItemTrack(item)
          local _, tname = r.GetTrackName(track)
          local _, name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
          dupes[#dupes + 1] = { item = item, take = take }
          lines[#lines + 1] = string.format("  %s / item %d / take %d \"%s\"  (same as take %d)",
            tname, i + 1, t + 1, name, seen[key])
        else
          seen[key] = t + 1
        end
      end
    end
  end

  if #dupes == 0 then
    r.ShowMessageBox("No duplicate-file takes found.", "Delete duplicate-file takes", 0)
    return
  end

  local msg = string.format("Found %d duplicate take(s):\n\n%s\n\nDelete them?",
    #dupes, table.concat(lines, "\n"))
  if r.ShowMessageBox(msg, "Delete duplicate-file takes", 4) ~= 6 then return end

  -- remember selection, then delete each dupe via the active-take action
  local saved = {}
  for i = 0, n_items - 1 do saved[#saved + 1] = r.GetSelectedMediaItem(0, i) end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local deleted = 0
  for _, d in ipairs(dupes) do
    if r.ValidatePtr(d.item, "MediaItem*") then
      -- take pointers stay valid across deletions of other takes
      r.SelectAllMediaItems(0, false)
      r.SetMediaItemSelected(d.item, true)
      r.SetActiveTake(d.take)
      r.Main_OnCommand(DELETE_ACTIVE_TAKE, 0)
      deleted = deleted + 1
    end
  end
  r.SelectAllMediaItems(0, false)
  for _, it in ipairs(saved) do
    if r.ValidatePtr(it, "MediaItem*") then r.SetMediaItemSelected(it, true) end
  end
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Delete duplicate-file takes (" .. deleted .. ")", -1)
end

main()
