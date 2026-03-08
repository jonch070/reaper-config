-- Move next take marker to edit cursor
-- Shifts all selected items so the next take marker after the edit cursor aligns with the cursor
-- Author: JK

local function main()
    local count = reaper.CountSelectedMediaItems(0)
    if count == 0 then return end

    local cursor = reaper.GetCursorPosition()
    local nearestMarkerTime = nil
    local nearestDist = math.huge

    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local playRate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
            if playRate == 0 then playRate = 1 end

            local markerCount = reaper.GetNumTakeMarkers(take)
            for j = 0, markerCount - 1 do
                local markerTime = reaper.GetTakeMarker(take, j)
                local markerProjTime = itemPos + markerTime / playRate
                if markerProjTime > cursor + 0.0001 then
                    local dist = markerProjTime - cursor
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestMarkerTime = markerProjTime
                    end
                end
            end
        end
    end

    if not nearestMarkerTime then return end

    local offset = cursor - nearestMarkerTime

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + offset)
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Move next take marker to edit cursor", -1)
end

main()
