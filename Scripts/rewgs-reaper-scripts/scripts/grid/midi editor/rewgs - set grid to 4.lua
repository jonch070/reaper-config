local function main()
    reaper.Main_OnCommand(40779, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40201)
end

main()
