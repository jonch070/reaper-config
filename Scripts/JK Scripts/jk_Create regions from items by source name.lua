--[[
@description jk_Create regions from items by source name
@version 0.1
@author Jonathan Kawchuk
@about
  For every distinct source audio file used in the project, creates one
  region spanning all items that reference that source. Region name = source
  filename without extension.

  Use case: after splitting items (e.g. by markers, then editing), one
  chapter MP3 becomes many fragments. This script regroups them as a single
  region per chapter.

  Idempotent: if a region with the same name already exists, the existing
  one's bounds are EXTENDED to cover any new items. Set REPLACE_EXISTING
  below to true if you'd rather delete + recreate.
]]--


-- ── Config ──────────────────────────────────────────────────

local REPLACE_EXISTING = false   -- false = extend bounds; true = recreate
local STRIP_EXTENSION  = true    -- region name has no .mp3 / .wav suffix


-- ── Helpers ────────────────────────────────────────────────

local function basename(path)
  if not path then return "" end
  local b = path:match("([^/\\]+)$") or path
  return b
end

local function strip_ext(name)
  return (name:gsub("%.[^.]+$", ""))
end


-- ── Main ───────────────────────────────────────────────────

function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Step 1: Walk every item, group by source filename
  local groups = {}      -- source_name → { min_pos, max_end, count }
  local order = {}       -- preserve first-seen order for stable region IDs

  local n_tracks = reaper.CountTracks(0)
  for t = 0, n_tracks - 1 do
    local track = reaper.GetTrack(0, t)
    local n_items = reaper.CountTrackMediaItems(track)
    for i = 0, n_items - 1 do
      local item = reaper.GetTrackMediaItem(track, i)
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = pos + len

      local take = reaper.GetActiveTake(item)
      if take then
        local source = reaper.GetMediaItemTake_Source(take)
        if source then
          local fname_full = reaper.GetMediaSourceFileName(source)
          local fname = basename(fname_full)
          if STRIP_EXTENSION then fname = strip_ext(fname) end
          if fname ~= "" then
            local g = groups[fname]
            if not g then
              g = { min_pos = pos, max_end = item_end, count = 0 }
              groups[fname] = g
              table.insert(order, fname)
            end
            if pos < g.min_pos then g.min_pos = pos end
            if item_end > g.max_end then g.max_end = item_end end
            g.count = g.count + 1
          end
        end
      end
    end
  end

  if #order == 0 then
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox("No items with audio sources found.",
      "Regions from items", 0)
    return
  end

  -- Step 2: Index existing regions by name
  local existing = {}     -- name → { idx, pos, rgnend, color }
  local total_markers = reaper.CountProjectMarkers(0)
  for i = 0, total_markers - 1 do
    local _, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if isrgn and name and name ~= "" then
      existing[name] = { idx = idx, pos = pos, rgnend = rgnend, color = color }
    end
  end

  -- Step 3: Create or update regions
  local created, extended, replaced = 0, 0, 0
  for _, fname in ipairs(order) do
    local g = groups[fname]
    local cur = existing[fname]
    if cur then
      if REPLACE_EXISTING then
        reaper.DeleteProjectMarkerByIndex(0, cur.idx)
        reaper.AddProjectMarker2(0, true, g.min_pos, g.max_end, fname, -1, cur.color or 0)
        replaced = replaced + 1
      else
        local new_pos = math.min(cur.pos, g.min_pos)
        local new_end = math.max(cur.rgnend, g.max_end)
        if new_pos ~= cur.pos or new_end ~= cur.rgnend then
          reaper.SetProjectMarker3(0, cur.idx, true, new_pos, new_end, fname, cur.color or 0)
          extended = extended + 1
        end
      end
    else
      reaper.AddProjectMarker2(0, true, g.min_pos, g.max_end, fname, -1, 0)
      created = created + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Create regions from items by source name", -1)

  reaper.ShowMessageBox(
    string.format(
      "Source files found: %d\n\n" ..
      "Regions created:  %d\n" ..
      "Regions extended: %d\n" ..
      "Regions replaced: %d",
      #order, created, extended, replaced
    ),
    "Regions from items", 0)
end


main()
