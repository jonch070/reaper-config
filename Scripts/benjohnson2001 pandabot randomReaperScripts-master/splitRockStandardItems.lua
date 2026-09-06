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
	local actionDescription = "splitRockStandardItems"
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

	-- string 1
	for i = 1, 23 do
		for j = 1, 12 do
			moveCursorRightToGridDivision()
		end

		splitItems()

		for k = 1, 5 do
			moveCursorRightToGridDivision()
		end

		if i ~= 23 then
			splitItems()
		end
	end


moveCursorRightToGridDivision()
moveCursorRightToGridDivision()	
splitItems()

	-- string 2
	for i = 1, 23 do
		for j = 1, 10 do
			moveCursorRightToGridDivision()
		end

		splitItems()

		for k = 1, 7 do
			moveCursorRightToGridDivision()
		end

		if i ~= 23 then
			splitItems()
		end
	end

moveCursorRightToGridDivision()
moveCursorRightToGridDivision()
splitItems()

	-- string 3
	for i = 1, 23 do
		for j = 1, 10 do
			moveCursorRightToGridDivision()
		end

		splitItems()

		for k = 1, 7 do
			moveCursorRightToGridDivision()
		end

		if i ~= 23 then
			splitItems()
		end
	end

moveCursorRightToGridDivision()
moveCursorRightToGridDivision()
splitItems()

	-- string 4
	for i = 1, 23 do
		for j = 1, 8 do
			moveCursorRightToGridDivision()
		end

		splitItems()

		for k = 1, 9 do
			moveCursorRightToGridDivision()
		end

		if i ~= 23 then
			splitItems()
		end
	end

moveCursorRightToGridDivision()
moveCursorRightToGridDivision()
splitItems()

	-- string 5
	for i = 1, 23 do
		for j = 1, 8 do
			moveCursorRightToGridDivision()
		end

		splitItems()

		for k = 1, 9 do
			moveCursorRightToGridDivision()
		end

		if i ~= 23 then
			splitItems()
		end
	end

moveCursorRightToGridDivision()
moveCursorRightToGridDivision()
splitItems()

	-- string 6
	for i = 1, 23 do
		for j = 1, 8 do
			moveCursorRightToGridDivision()
		end

		splitItems()

		for k = 1, 9 do
			moveCursorRightToGridDivision()
		end

		splitItems()
	end

endUndoBlock()