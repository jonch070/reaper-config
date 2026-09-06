-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "alignNotesToNonzeroSample"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end

function getNumberOfSelectedItems()
	return reaper.CountSelectedMediaItems(activeProjectIndex)
end

startUndoBlock()



	local numberOfSelectedItems = getNumberOfSelectedItems()

	for i = 0, numberOfSelectedItems - 1 do

		local item = reaper.GetSelectedMediaItem(activeProjectIndex, i)

		local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    local take = reaper.GetActiveTake(item)

    local source = reaper.GetMediaItemTake_Source(take)    
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local samplerate = reaper.GetMediaSourceSampleRate(source)
    local channels = reaper.GetMediaSourceNumChannels(source)
    local startingPosition = 0
    local samples = samplerate
    local bufferSize = samples -- first second
    local buffer = reaper.new_array(samples*channels)
    
    reaper.GetAudioAccessorSamples(accessor, samplerate, channels, startingPosition, samples, buffer)

    local nonzeroPointHasNotBeenFound = true
    local nonzeroSample = 0

    local previousSample = nil
    for i = 1, bufferSize do
			
			local sample = math.abs(buffer[i])
			
			if i > 1 and math.abs(sample) > math.abs(previousSample) and math.abs(sample) > 0.001 and nonzeroPointHasNotBeenFound then
				nonzeroPointHasNotBeenFound = false
				nonzeroSample = i/channels - 1
			end
			
			previousSample = sample
    end
    
    local snapOffsetPosition = nonzeroSample / samplerate
    reaper.DestroyAudioAccessor(accessor)
    reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", snapOffsetPosition)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", itemPosition-snapOffsetPosition)
    reaper.UpdateArrange() 
	end




endUndoBlock()
