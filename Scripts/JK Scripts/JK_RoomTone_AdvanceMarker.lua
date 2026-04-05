-- JK_RoomTone_AdvanceMarker.lua
-- Advances the edit cursor to the next matching project marker.
-- Configure behavior with JK_RoomTone_Settings.lua:
--   marker_mode    = "editing"  → only markers whose name starts with "@editing"
--                  = "all"      → any marker
--   marker_advance = 1..9       → how many matching markers to skip over
--
-- Designed as the final step in a JK RoomTone macro:
--   JK_RoomTone_DetectAndDelete → JK_RoomTone_Insert_Xs → JK_RoomTone_AdvanceMarker
--
-- Part of the JK Room Tone Replacement toolkit.

-- ============================================================
-- CONFIG (defaults — override via JK_RoomTone_Settings.lua)
-- ============================================================
local DEFAULT_MARKER_MODE    = "editing"   -- "editing" or "all"
local DEFAULT_MARKER_ADVANCE = 1           -- how many markers to jump
local MARKER_PREFIX          = "@editing"  -- prefix to match when mode = "editing"

-- ============================================================
-- MAIN
-- ============================================================
local EXT_NS = "JK_RoomTone"

local function main()
    local mode_raw    = reaper.GetExtState(EXT_NS, "marker_mode")
    local advance_raw = reaper.GetExtState(EXT_NS, "marker_advance")

    local mode    = (mode_raw    ~= "") and mode_raw    or DEFAULT_MARKER_MODE
    local advance = (advance_raw ~= "") and tonumber(advance_raw) or DEFAULT_MARKER_ADVANCE
    if not advance or advance < 1 then advance = 1 end

    local use_prefix = (mode == "editing")
    local from_pos   = reaper.GetCursorPosition()
    local found      = 0
    local target_pos = nil

    for i = 0, reaper.CountProjectMarkers(0) - 1 do
        local _, is_region, pos, _, name, _ = reaper.EnumProjectMarkers(i)
        if not is_region and pos > from_pos + 0.001 then
            if not use_prefix or name:sub(1, #MARKER_PREFIX) == MARKER_PREFIX then
                found = found + 1
                if found >= advance then
                    target_pos = pos
                    break
                end
            end
        end
    end

    if target_pos then
        reaper.SetEditCurPos(target_pos, true, false)  -- scroll view to cursor
    else
        local label = use_prefix and ('"' .. MARKER_PREFIX .. '"') or "any"
        reaper.ShowConsoleMsg("[JK RoomTone] No more " .. label .. " markers after current position.\n")
    end
end

main()
