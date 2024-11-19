local function main()
    reaper.Main_OnCommand(40780, 0)
    reaper.SetMIDIEditorGrid(0, 1/2)
end

main()
