local function main()
    reaper.Main_OnCommand(40780, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40203)
end

main()
