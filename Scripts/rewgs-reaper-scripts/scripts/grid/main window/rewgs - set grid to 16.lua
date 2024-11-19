local function main()
    reaper.Main_OnCommand(40776, 0)
    reaper.SetMIDIEditorGrid(0, 1/16)
end

main()
