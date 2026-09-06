function emptyFunctionToPreventAutomaticCreationOfUndoPoint()
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock(actionDescription)
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function redrawEnvelope()

	reaper.PreventUIRefresh(1)

	local track = reaper.GetTrack(0,0)

	trackParameter = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
	
	if trackParameter == 0 then
		reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 1)
	else
		reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
	end

	reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", trackParameter)

	reaper.PreventUIRefresh(-1)
end


function getDeleteTimeLoopPoints(trackEnvelope, env_point_count, startTime, endTime)
	local set_first_start = 0
	local set_first_end = 0
	for i = 0, env_point_count do
		retval, time, valueOut, shape, tension, selectedOut = reaper.GetEnvelopePoint(trackEnvelope,i)

		if startTime == time and set_first_start == 0 then
			set_first_start = 1
			first_start_idx = i
			firstStartValue = valueOut
		end
		if endTime == time and set_first_end == 0 then
			set_first_end = 1
			first_end_idx = i
			firstEndValue = valueOut
		end
		if set_first_end == 1 and set_first_start == 1 then
			break
		end
	end

	local set_last_start = 0
	local set_last_end = 0
	for i = 0, env_point_count do
		retval, time, valueOut, shape, tension, selectedOut = reaper.GetEnvelopePoint(trackEnvelope,env_point_count-1-i)

		if startTime == time and set_last_start == 0 then
			set_last_start = 1
			last_start_idx = env_point_count-1-i
			lastStartValue = valueOut
		end
		if endTime == time and set_last_end == 0 then
			set_last_end = 1
			last_end_idx = env_point_count-1-i
			lastEndValue = valueOut
		end
		if set_last_start == 1 and set_last_end == 1 then
			break
		end
	end

	if firstStartValue == nil then
		retval_startTime, firstStartValue, dVdS_startTime, ddVdS_startTime, dddVdS_startTime = reaper.Envelope_Evaluate(trackEnvelope, startTime, 0, 0)
	end
	if lastEndValue == nil then
		retval_endTime, lastEndValue, dVdS_endTime, ddVdS_endTime, dddVdS_endTime = reaper.Envelope_Evaluate(trackEnvelope, endTime, 0, 0)
	end

	if lastStartValue == nil then
		lastStartValue = firstStartValue
	end
	if firstEndValue == nil then
		firstEndValue = lastEndValue
	end

	reaper.DeleteEnvelopePointRange(trackEnvelope, startTime-0.000000001, endTime+0.000000001)

	return firstStartValue, lastStartValue, firstEndValue, lastEndValue

end



function envelopePointDoesNotExistAtStart(trackEnvelopeObject)

	local envelopePointIndexAtStart = reaper.GetEnvelopePointByTime(trackEnvelope, 0)
	local returnValue, position, value, shape, selected, bezier = reaper.BR_EnvGetPoint(trackEnvelopeObject, envelopePointIndexAtStart)

	return value == 1.0
end

function addPoints(trackEnvelope)

	local trackEnvelopeObject = reaper.BR_EnvAlloc(trackEnvelope, false)

	local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(trackEnvelopeObject, true, true, true, true, 0, 0, 0, 0, 0, 0, true)

	if visible == false then
		local commandId = 40406
	  reaper.Main_OnCommand(commandId, 0)
	end

	if faderScaling == true then
		minValue = reaper.ScaleToEnvelopeMode(1, minValue)
		maxValue = reaper.ScaleToEnvelopeMode(1, maxValue)
		centerValue = reaper.ScaleToEnvelopeMode(1, centerValue)
	end

	env_points_count = reaper.CountEnvelopePoints(trackEnvelope)

	if env_points_count > 0 then
		for k = 0, env_points_count+1 do
			reaper.SetEnvelopePoint(trackEnvelope, k, timeInOptional, valueInOptional, shapeInOptional, tensionInOptional, false, true)
		end
	end

	firstStartValue, lastStartValue, firstEndValue, lastEndValue = getDeleteTimeLoopPoints(trackEnvelope, env_points_count, startTime, endTime)

	local minValue = 0.5

	if envelopePointDoesNotExistAtStart(trackEnvelopeObject) then
		reaper.InsertEnvelopePoint(trackEnvelope, 0, minValue, 0, 0, true, true)
	end

	reaper.InsertEnvelopePoint(trackEnvelope, startTime, minValue, 3, 0, true, true)

	reaper.InsertEnvelopePoint(trackEnvelope, startTime+0.06, centerValue, 0, 0, true, true)
	reaper.InsertEnvelopePoint(trackEnvelope, endTime-0.06, centerValue, 4, 0, true, true)

	reaper.InsertEnvelopePoint(trackEnvelope, endTime, minValue, 0, 0, true, true)


	reaper.BR_EnvFree(trackEnvelopeObject, 0)
	reaper.Envelope_SortPoints(trackEnvelope)
end


function getTimeSelectionEdges()
	return reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
end

function timeSelectionExists()
	local startTime, endTime = getTimeSelectionEdges()
	return startTime ~= endTime
end

function volumeEnvelopeIsNotVisible(trackEnvelope)

	local trackEnvelopeObject = reaper.BR_EnvAlloc(trackEnvelope, false)
	local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(trackEnvelopeObject, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
	reaper.BR_EnvFree(trackEnvelopeObject, 0)
	return visible == false
end

function toggleVolumeEnvelopeVisibility()

	local commandId = 40406
  reaper.Main_OnCommand(commandId, 0)
end

function main() -- local (i, j, item, take, track)

	startUndoBlock()

	startTime, endTime = getTimeSelectionEdges()

	if timeSelectionExists() then

		-- ROUND LOOP TIME SELECTION EDGES
		--startTime = math.floor(startTime * 100000000+0.5)/100000000
		--endTime = math.floor(endTime * 100000000+0.5)/100000000

		numberOfSelectedTracks = reaper.CountSelectedTracks(0)

		for i = 0, numberOfSelectedTracks-1  do

			selectedTrack = reaper.GetSelectedTrack(0, i)
			trackEnvelope = reaper.GetTrackEnvelopeByName(selectedTrack, "Volume")

			if volumeEnvelopeIsNotVisible(trackEnvelope) then
				toggleVolumeEnvelopeVisibility()
			else
				addPoints(trackEnvelope)
			end
		end

		endUndoBlock("isolateItemVolume")
	end

end



reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1) 
reaper.UpdateArrange()
redrawEnvelope()
reaper.defer(emptyFunctionToPreventAutomaticCreationOfUndoPoint)