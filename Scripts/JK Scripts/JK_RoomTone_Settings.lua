-- JK_RoomTone_Settings.lua
-- Configure JK_RoomTone_AdvanceMarker behaviour.
-- Settings persist across sessions (stored in REAPER ExtState).
--
-- marker_mode:
--   "editing"  → AdvanceMarker only jumps to markers whose name starts with "@editing"
--   "all"      → AdvanceMarker jumps to any project marker
--
-- marker_advance:
--   1-9 → how many matching markers to skip each time AdvanceMarker runs
--         (use 2 if your QC workflow visits two markers per fix, etc.)
--
-- Part of the JK Room Tone Replacement toolkit.

local EXT_NS = "JK_RoomTone"

local function main()
    local cur_mode    = reaper.GetExtState(EXT_NS, "marker_mode")
    local cur_advance = reaper.GetExtState(EXT_NS, "marker_advance")

    if cur_mode    == "" then cur_mode    = "editing" end
    if cur_advance == "" then cur_advance = "1" end

    local ok, values = reaper.GetUserInputs(
        "JK Room Tone — Marker Settings",
        2,
        "Marker mode  (editing / all),Markers to advance  (1 – 9),",
        cur_mode .. "," .. cur_advance
    )
    if not ok then return end

    local new_mode, new_advance = values:match("^([^,]+),(.+)$")
    if not new_mode then
        reaper.ShowMessageBox("Could not parse input.", "JK RoomTone Settings", 0)
        return
    end

    new_mode    = new_mode:match("^%s*(.-)%s*$")
    new_advance = new_advance:match("^%s*(.-)%s*$")

    if new_mode ~= "editing" and new_mode ~= "all" then
        reaper.ShowMessageBox(
            'Marker mode must be "editing" or "all".\nGot: "' .. new_mode .. '"',
            "JK RoomTone Settings", 0)
        return
    end

    local n = tonumber(new_advance)
    if not n or n < 1 or n > 9 or math.floor(n) ~= n then
        reaper.ShowMessageBox(
            "Markers to advance must be a whole number from 1 to 9.\nGot: " .. new_advance,
            "JK RoomTone Settings", 0)
        return
    end

    -- true = persist to disk (survives REAPER restart)
    reaper.SetExtState(EXT_NS, "marker_mode",    new_mode,      true)
    reaper.SetExtState(EXT_NS, "marker_advance", tostring(n),   true)

    reaper.ShowConsoleMsg(
        "[JK RoomTone] Settings saved — mode: " .. new_mode ..
        "  |  advance: " .. n .. "\n")
end

main()
