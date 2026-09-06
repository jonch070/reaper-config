-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
   reaper.Undo_BeginBlock()
end

function endUndoBlock()
   local actionDescription = "decreasePlaybackOffset"
   reaper.Undo_OnStateChange(actionDescription)
   reaper.Undo_EndBlock(actionDescription, -1)
end

function enablePlaybackOffsetForSelectedTracks()

   local numberOfTracks = reaper.CountSelectedTracks(activeProjectIndex)

   for i = 0, numberOfTracks - 1 do

      local track = reaper.GetSelectedTrack(activeProjectIndex, i)
      local _, trackName = reaper.GetTrackName(track)

      reaper.SetMediaTrackInfo_Value(track, "I_PLAY_OFFSET_FLAG", 0.0)
   end
end

startUndoBlock()

   enablePlaybackOffsetForSelectedTracks()

   local numberOfTracks = reaper.CountSelectedTracks(activeProjectIndex)

   local topNoteTrack = reaper.GetSelectedTrack(activeProjectIndex, 0)
   local playbackOffsetOfTopNote = reaper.GetMediaTrackInfo_Value(topNoteTrack, "D_PLAY_OFFSET")
   local newPlaybackOffsetOfTopNote = playbackOffsetOfTopNote - 0.001

   for i = 0, numberOfTracks - 1 do

      local track = reaper.GetSelectedTrack(activeProjectIndex, i)
      local _, trackName = reaper.GetTrackName(track)

      local offsetBetweenNotes = newPlaybackOffsetOfTopNote / (numberOfTracks-1)

      if i == numberOfTracks - 1 then
         reaper.SetMediaTrackInfo_Value(track, "D_PLAY_OFFSET", 0.0)
      else
         reaper.SetMediaTrackInfo_Value(track, "D_PLAY_OFFSET", newPlaybackOffsetOfTopNote - offsetBetweenNotes*i)
      end
   end

endUndoBlock()