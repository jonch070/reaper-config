local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "combineTrackFx"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

----


function cutFxChain()
	local commandId = reaper.NamedCommandLookup("_S&M_COPYFXCHAIN6")
	reaper.Main_OnCommand(commandId, 0)
end

function pasteFxChain()
	local commandId = reaper.NamedCommandLookup("_S&M_COPYFXCHAIN10")
	reaper.Main_OnCommand(commandId, 0)
end

-----------------------------------------


startUndoBlock()


local numberOfSelectedTracks = reaper.CountSelectedTracks(activeProjectIndex)

local selectedTracks = {}

-- collect selected tracks
for i = 0, numberOfSelectedTracks - 1 do
	local selectedTrack = reaper.GetSelectedTrack(activeProjectIndex, i)
	table.insert(selectedTracks, selectedTrack)
end

-- cut fx chain and paste it to the track above it
for i = #selectedTracks, 2, -1 do

	reaper.SetOnlyTrackSelected(selectedTracks[i]);
	cutFxChain();
	reaper.SetOnlyTrackSelected(selectedTracks[i-1]);
	pasteFxChain();
end

-- delete remaining tracks
for i = 2, #selectedTracks do
	reaper.DeleteTrack(selectedTracks[i]);
end

endUndoBlock()
reaper.UpdateArrange()
