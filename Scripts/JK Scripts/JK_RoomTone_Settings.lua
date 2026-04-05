-- JK_RoomTone_Settings.lua
-- Configure shared settings for the JK Room Tone Replacement toolkit.
-- Settings persist across REAPER sessions.
--
-- threshold_db:
--   dB level below which audio is considered silence (-60 is typical;
--   raise to e.g. -50 if your room tone is louder than expected)
--
-- marker_mode:
--   "editing"  → AdvanceMarker only jumps to markers starting with "@editing"
--   "all"      → AdvanceMarker jumps to any project marker
--
-- marker_advance:
--   1-9 → how many matching markers to skip each time AdvanceMarker runs

local EXT_NS = "JK_RoomTone"

local function main()
    local cur_threshold = reaper.GetExtState(EXT_NS, "threshold_db")
    local cur_mode      = reaper.GetExtState(EXT_NS, "marker_mode")
    local cur_advance   = reaper.GetExtState(EXT_NS, "marker_advance")

    if cur_threshold == "" then cur_threshold = "-60" end
    if cur_mode      == "" then cur_mode      = "editing" end
    if cur_advance   == "" then cur_advance   = "1" end

    local ok, values = reaper.GetUserInputs(
        "JK Room Tone — Settings",
        3,
        "Silence threshold (dB, e.g. -60),Marker mode  (editing / all),Markers to advance  (1 – 9),",
        cur_threshold .. "," .. cur_mode .. "," .. cur_advance
    )
    if not ok then return end

    -- Parse comma-separated response (GetUserInputs uses , as separator)
    local parts = {}
    for part in (values .. ","):gmatch("([^,]*),") do
        parts[#parts + 1] = part:match("^%s*(.-)%s*$")
    end

    local new_threshold = parts[1] or cur_threshold
    local new_mode      = parts[2] or cur_mode
    local new_advance   = parts[3] or cur_advance

    -- Validate threshold
    local db = tonumber(new_threshold)
    if not db or db > 0 then
        reaper.ShowMessageBox(
            "Threshold must be a negative number (e.g. -60).\nGot: " .. new_threshold,
            "JK RoomTone Settings", 0)
        return
    end

    -- Validate marker mode
    if new_mode ~= "editing" and new_mode ~= "all" then
        reaper.ShowMessageBox(
            'Marker mode must be "editing" or "all".\nGot: "' .. new_mode .. '"',
            "JK RoomTone Settings", 0)
        return
    end

    -- Validate advance count
    local n = tonumber(new_advance)
    if not n or n < 1 or n > 9 or math.floor(n) ~= n then
        reaper.ShowMessageBox(
            "Markers to advance must be a whole number from 1 to 9.\nGot: " .. new_advance,
            "JK RoomTone Settings", 0)
        return
    end

    reaper.SetExtState(EXT_NS, "threshold_db",   tostring(db),   true)
    reaper.SetExtState(EXT_NS, "marker_mode",    new_mode,       true)
    reaper.SetExtState(EXT_NS, "marker_advance", tostring(n),    true)

    reaper.ShowConsoleMsg(
        "[JK RoomTone] Settings saved — threshold: " .. db .. " dB" ..
        "  |  mode: " .. new_mode ..
        "  |  advance: " .. n .. "\n")
end

main()
