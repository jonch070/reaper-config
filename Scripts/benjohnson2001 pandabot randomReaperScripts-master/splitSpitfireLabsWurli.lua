-- @noindex

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local activeProjectIndex = 0

function print(arg)
  reaper.ShowConsoleMsg(tostring(arg) .. "\n")
end

function startUndoBlock()
	reaper.Undo_BeginBlock()
end

function endUndoBlock()
	local actionDescription = "splitSpitfireLabsWurliItems"
	reaper.Undo_OnStateChange(actionDescription)
	reaper.Undo_EndBlock(actionDescription, -1)
end



function moveCursorRightToGridDivision()

	local commandId = 40647
  reaper.Main_OnCommand(commandId, 0)
end

function splitItems()

	local commandId = 40012
  reaper.Main_OnCommand(commandId, 0)
end

startUndoBlock()

-- 1:
	-- for i = 1, 1000 do
	-- 	for j = 1, 12 do
	-- 		moveCursorRightToGridDivision()
	-- 	end

	-- 	splitItems()
	-- end


-- 2:
	for i = 1, 1000 do

		for k = 1, 4 do

			for j = 1, 9 do
			moveCursorRightToGridDivision()
			end

			splitItems()

			for j = 1, 3 do
				moveCursorRightToGridDivision()
			end
		end

			for j = 1, 48 do
				moveCursorRightToGridDivision()
			end

		
	end

endUndoBlock()