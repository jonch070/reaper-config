-- Move next transient to edit cursor
-- Shifts all selected items so the next transient after the edit cursor aligns with the cursor
-- Requires SWS extension (falls back to native REAPER action 40375)
-- Author: JK

local function main()
    if reaper.CountSelectedMediaItems(0) == 0 then return end

    local cursor = reaper.GetCursorPosition()

    -- Find next transient using SWS, fall back to native REAPER action
    local cmdID = reaper.NamedCommandLookup("_SWS_NEXTTRANSIENT")
    if cmdID == 0 then cmdID = 40375 end
    reaper.Main_OnCommand(cmdID, 0)

    local nextTransient = reaper.GetCursorPosition()
    reaper.SetEditCurPos(cursor, false, false) -- restore cursor

    if math.abs(nextTransient - cursor) < 0.0001 then return end -- no transient found

    local offset = cursor - nextTransient
    local count = reaper.CountSelectedMediaItems(0)

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + offset)
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Move next transient to edit cursor", -1)
end

main()
