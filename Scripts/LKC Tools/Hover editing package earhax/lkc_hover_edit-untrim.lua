--[[
  NoIndex: true
]]
reaper.Undo_BeginBlock()
hover_editing = tonumber(reaper.GetExtState("LKC_TOOLS","hover_editing_state"))
if hover_editing == nil then hover_editing = 1 end

if hover_editing == 1 then
	-- check if mouse pointer is hovering over an item
	local window, segment, details = reaper.BR_GetMouseCursorContext(); 
	local item = reaper.BR_GetMouseCursorContext_Item(); 
	local curpos = reaper.GetCursorPosition()
	local mppos = reaper.BR_GetMouseCursorContext_Position()
	if item then; 
	-- if mouse is hovering over an item, move the edit cursor to mouse pointer position
	-- otherwise, the untrim operation will be performed at the current edit cursor location on selected items (normal operation)
	-- EXCEPTION: if the mouse pointer is to the right of the edit cursor, on an "untrim right" operation, the selected  items will trim to the mouse pointer position.
	-- Similarly, when doing an "untrim left", if the pointer is to the left of the edit cursor, the selected items will untrim to the pointer position.


		--for flying cursor (no need for clicking)
		--reaper.Main_OnCommand(40514,0) --View: Move edit cursor to mouse cursor (no snapping)
		reaper.Main_OnCommand(40513,0) --View: Move edit cursor to mouse cursor (snapping)
	elseif (mppos >= curpos) and (OPERATION == "right_untrim") then
		-- reaper.Main_OnCommand(40528,0) --Item: Select item under mouse cursor
		reaper.Main_OnCommand(40513,0) --View: Move edit cursor to mouse cursor (snapping)
	elseif (mppos <= curpos) and (OPERATION == "left_untrim") then
		-- reaper.Main_OnCommand(40528,0) --Item: Select item under mouse cursor
		reaper.Main_OnCommand(40513,0) --View: Move edit cursor to mouse cursor (snapping)
	end;
end
if OPERATION == "right_untrim" then
	reaper.Main_OnCommand(41311,0) --Item edit: Trim right edge of item to edit cursor
	reaper.Undo_EndBlock("LKC - HOVER EDIT - Untrim right", -1)
elseif OPERATION == "left_untrim" then 
	reaper.Main_OnCommand(41305,0) --Item edit: Trim left edge of item to edit cursor
	reaper.Undo_EndBlock("LKC - HOVER EDIT - Untrim left", -1)
end