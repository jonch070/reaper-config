local function main()
    reaper.Main_OnCommand(40776, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40192)
end

main()
