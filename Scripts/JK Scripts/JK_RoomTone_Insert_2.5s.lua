-- JK_RoomTone_Insert_2.5s.lua
-- Inserts "Clean silence_2.5 Seconds.mp3" at the current edit cursor
-- on the currently selected track, then applies short fades at both edges.
--
-- Designed to run AFTER JK_RoomTone_DetectAndDelete in a REAPER custom action.
-- With Ripple Edit ON, subsequent items are pushed right by the room-tone length.
--
-- Suggested use: Section Break (SB) fix
-- Macro:  JK_RoomTone_DetectAndDelete → JK_RoomTone_Insert_2.5s → JK_RoomTone_AdvanceMarker
--
-- Part of the JK Room Tone Replacement toolkit.

-- ============================================================
-- CONFIG
-- ============================================================
local ROOM_TONE_DIR  = "/Users/jonathankawchuk/Documents/Projects/Audiobook Editing/Spotify/Current Audiobook Project/room_tone/"
local ROOM_TONE_FILE = "Clean silence_2.5 Seconds"   -- extension resolved automatically
local CROSSFADE_MS   = 15                             -- fade applied to inserted item edges (ms)

-- ============================================================
-- HELPERS
-- ============================================================
local function findFile(dir, base)
    for _, ext in ipairs({".mp3", ".wav", ".aif", ".aiff", ".flac", ".MP3", ".WAV"}) do
        local path = dir .. base .. ext
        local f = io.open(path, "r")
        if f then f:close(); return path end
    end
    return nil
end

local function applyFades(track, insert_pos, xfade_sec)
    local new_item = nil
    for i = 0, reaper.CountTrackMediaItems(track) - 1 do
        local it     = reaper.GetTrackMediaItem(track, i)
        local it_pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
        if math.abs(it_pos - insert_pos) < 0.05 then
            local tk = reaper.GetActiveTake(it)
            if tk then
                local src  = reaper.GetMediaItemTake_Source(tk)
                local name = reaper.GetMediaSourceFileName(src, "")
                if name:find(ROOM_TONE_FILE, 1, true) then
                    new_item = it
                    break
                end
            end
        end
    end
    if not new_item then
        local best_dist = math.huge
        for i = 0, reaper.CountTrackMediaItems(track) - 1 do
            local it   = reaper.GetTrackMediaItem(track, i)
            local dist = math.abs(reaper.GetMediaItemInfo_Value(it, "D_POSITION") - insert_pos)
            if dist < best_dist then best_dist = dist; new_item = it end
        end
    end
    if not new_item then return end

    reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN",  xfade_sec)
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", xfade_sec)

    local ni_end = reaper.GetMediaItemInfo_Value(new_item, "D_POSITION")
               + reaper.GetMediaItemInfo_Value(new_item, "D_LENGTH")
    for i = 0, reaper.CountTrackMediaItems(track) - 1 do
        local it = reaper.GetTrackMediaItem(track, i)
        if it ~= new_item then
            if math.abs(reaper.GetMediaItemInfo_Value(it, "D_POSITION") - ni_end) < 0.005 then
                reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN", xfade_sec)
                break
            end
        end
    end
end

-- ============================================================
-- MAIN
-- ============================================================
local function main()
    local dir = ROOM_TONE_DIR
    if dir:sub(-1) ~= "/" and dir:sub(-1) ~= "\\" then dir = dir .. "/" end

    local filepath = findFile(dir, ROOM_TONE_FILE)
    if not filepath then
        reaper.ShowMessageBox(
            "Room-tone file not found:\n" .. dir .. ROOM_TONE_FILE ..
            "\n\nTried: .mp3  .wav  .aif  .aiff  .flac\n\nCheck ROOM_TONE_DIR at the top of the script.",
            "JK RoomTone Insert", 0)
        return
    end

    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowConsoleMsg("[JK RoomTone Insert] No track selected — run DetectAndDelete first.\n")
        return
    end

    local insert_pos = reaper.GetCursorPosition()

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    reaper.InsertMedia(filepath, 0)

    if CROSSFADE_MS > 0 then
        applyFades(track, insert_pos, CROSSFADE_MS / 1000)
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("JK RoomTone: insert " .. ROOM_TONE_FILE, -1)
end

main()
