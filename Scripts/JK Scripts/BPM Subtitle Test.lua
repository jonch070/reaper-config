-- Lua Script to Write BPM to a Subtitle File
function main()
    local file = io.open("path_to_your_subtitle_file.srt", "w")  -- Specify the path to your subtitle file
    local current_bpm = reaper.Master_GetTempo()  -- Fetch the current BPM
    if file then
        file:write("1\n00:00:00,000 --> 23:59:59,999\nBPM: " .. tostring(current_bpm) .. "\n")
        file:close()
    end
    reaper.defer(main)  -- Re-run the script after a short delay to update the BPM
end

reaper.defer(main)  -- Start the script

