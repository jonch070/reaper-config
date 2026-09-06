--[[
  Move selected items so their RIGHT EDGE aligns
  to the nearest previous marker containing "narration"

  For REAPER
--]]

local function find_previous_narration_marker(item_pos)
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions

    local best_pos = nil

    for i = 0, total - 1 do
        local retval, isrgn, pos, rgnend, name, idx =
            reaper.EnumProjectMarkers(i)

        -- Only check markers (not regions)
        if not isrgn and name then
            local lower_name = string.lower(name)

            if string.find(lower_name, "narration", 1, true) then
                if pos <= item_pos then
                    if best_pos == nil or pos > best_pos then
                        best_pos = pos
                    end
                end
            end
        end
    end

    return best_pos
end

reaper.Undo_BeginBlock()

local item_count = reaper.CountSelectedMediaItems(0)

for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)

    if item then
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        local item_end = item_pos + item_len

        local marker_pos = find_previous_narration_marker(item_end)

        if marker_pos then
            -- Move item so RIGHT edge lands on marker
            local new_pos = marker_pos - item_len
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
        end
    end
end

reaper.UpdateArrange()

reaper.Undo_EndBlock(
    "Align selected item right edge to previous narration marker",
    -1
)
