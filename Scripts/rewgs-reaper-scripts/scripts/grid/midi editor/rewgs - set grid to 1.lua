local function main()
    reaper.Main_OnCommand(40781, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40204)
end

main()
