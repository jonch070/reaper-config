-- JK - Create markers from pasted timestamps.lua
-- Copy any text containing timestamps (e.g. a Snipd export, where every
-- "### Time 0:02:00" heading becomes a marker; otherwise every H:MM:SS / MM:SS
-- found in the text), run this, and a marker is dropped at each unique time.
-- Times are measured from the project start (0:00:00 = project start).
-- Requires the SWS Extension (clipboard access).

local function trim(s) return s:match("^%s*(.-)%s*$") end

local function toSeconds(str)
    local parts = {}
    for n in str:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    if #parts == 3 then return parts[1] * 3600 + parts[2] * 60 + parts[3] end
    if #parts == 2 then return parts[1] * 60 + parts[2] end
    return nil
end

local function main()
    if not reaper.CF_GetClipboard then
        reaper.ShowMessageBox("Requires the SWS Extension.", "Markers from timestamps", 0)
        return
    end
    local text = reaper.CF_GetClipboard()
    if not text or trim(text) == "" then
        reaper.ShowMessageBox("Clipboard is empty.", "Markers from timestamps", 0)
        return
    end

    local found = {}
    -- Snipd-style headings take priority so transcript text isn't scanned
    for ts in ("\n" .. text):gmatch("\n#+%s*Time%s+(%d+:%d%d:?%d*)") do found[#found + 1] = ts end
    if #found == 0 then
        for ts in text:gmatch("%f[%d](%d+:%d%d:%d%d)%f[%D]") do found[#found + 1] = ts end
        if #found == 0 then
            for ts in text:gmatch("%f[%d](%d+:%d%d)%f[%D]") do found[#found + 1] = ts end
        end
    end

    local seen, times = {}, {}
    for _, ts in ipairs(found) do
        local sec = toSeconds(ts)
        if sec and not seen[sec] then
            seen[sec] = true
            times[#times + 1] = { sec = sec, label = ts }
        end
    end
    if #times == 0 then
        reaper.ShowMessageBox("No timestamps found on the clipboard.", "Markers from timestamps", 0)
        return
    end
    table.sort(times, function(a, b) return a.sec < b.sec end)

    reaper.Undo_BeginBlock()
    for _, t in ipairs(times) do
        reaper.AddProjectMarker(0, false, t.sec, 0, "", -1)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Create markers from pasted timestamps", -1)
end

main()
