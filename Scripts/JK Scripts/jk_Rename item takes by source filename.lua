--[[
@description jk_Rename item takes by source filename
@version 0.1
@author Jonathan Kawchuk
@about
  Renames every take of the selected items to match their source audio
  filename (extension stripped). If no items are selected, all items in
  the project are processed instead.
]]--


-- ── Config ──────────────────────────────────────────────────

local STRIP_EXTENSION = true   -- take name has no .wav / .mp3 suffix


-- ── Helpers ────────────────────────────────────────────────

local function basename(path)
  if not path then return "" end
  return path:match("([^/\\]+)$") or path
end

local function strip_ext(name)
  return (name:gsub("%.[^.]+$", ""))
end

local function get_items()
  local items = {}
  local n_selected = reaper.CountSelectedMediaItems(0)
  if n_selected > 0 then
    for i = 0, n_selected - 1 do
      items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
    end
  else
    local n_tracks = reaper.CountTracks(0)
    for t = 0, n_tracks - 1 do
      local track = reaper.GetTrack(0, t)
      local n_items = reaper.CountTrackMediaItems(track)
      for i = 0, n_items - 1 do
        items[#items + 1] = reaper.GetTrackMediaItem(track, i)
      end
    end
  end
  return items
end


-- ── Main ───────────────────────────────────────────────────

function main()
  reaper.Undo_BeginBlock()

  local items = get_items()
  local renamed, skipped = 0, 0

  for _, item in ipairs(items) do
    local n_takes = reaper.CountTakes(item)
    for tk = 0, n_takes - 1 do
      local take = reaper.GetTake(item, tk)
      if take then
        local source = reaper.GetMediaItemTake_Source(take)
        if source then
          local fname = basename(reaper.GetMediaSourceFileName(source))
          if STRIP_EXTENSION then fname = strip_ext(fname) end
          if fname ~= "" then
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", fname, true)
            renamed = renamed + 1
          else
            skipped = skipped + 1
          end
        else
          skipped = skipped + 1
        end
      end
    end
  end

  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Rename item takes by source filename", -1)

  if #items == 0 then
    reaper.ShowMessageBox("No items found (select items or add items to the project).",
      "Rename takes by source filename", 0)
  end
end


main()
