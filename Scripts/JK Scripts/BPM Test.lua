-- Lua Script to Fetch and Display BPM in Real-time
function main()
    local current_bpm = reaper.Master_GetTempo()  -- Fetch the current BPM
    reaper.SetExtState("Global", "BPM", tostring(current_bpm), false)  -- Store BPM in ExtState without project saving
    reaper.defer(main)  -- Re-run the script continuously
end

reaper.defer(main)  -- Start the script

