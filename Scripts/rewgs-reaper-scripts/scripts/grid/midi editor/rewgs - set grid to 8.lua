local function main()
    reaper.Main_OnCommand(40778, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40197)
end

main()
