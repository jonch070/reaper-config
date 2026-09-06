-- @noindex

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
   reaper.Undo_BeginBlock()
end

function endUndoBlock()
   local actionDescription = "resetPlaybackOffset"
   reaper.Undo_OnStateChange(actionDescription)
   reaper.Undo_EndBlock(actionDescription, -1)
end

function disablePlaybackOffsetForSelectedTracks()

   local numberOfTracks = reaper.CountSelectedTracks(activeProjectIndex)

   for i = 0, numberOfTracks - 1 do

      local track = reaper.GetSelectedTrack(activeProjectIndex, i)
      local _, trackName = reaper.GetTrackName(track)

      reaper.SetMediaTrackInfo_Value(track, "I_PLAY_OFFSET_FLAG", 1.0)
   end
end

function setPlaybackOffsetToZeroForSelectedTracks()

   local numberOfTracks = reaper.CountSelectedTracks(activeProjectIndex)

   for i = 0, numberOfTracks - 1 do

      local track = reaper.GetSelectedTrack(activeProjectIndex, i)
      local _, trackName = reaper.GetTrackName(track)

      local playbackoffset = reaper.SetMediaTrackInfo_Value(track, "D_PLAY_OFFSET", 0.0)
   end
end


startUndoBlock()

   disablePlaybackOffsetForSelectedTracks()
   setPlaybackOffsetToZeroForSelectedTracks()

endUndoBlock()