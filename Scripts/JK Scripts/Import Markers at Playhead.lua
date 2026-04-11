-- @description Import Markers at Playhead Position
-- @author Jonathan Kawchuk (generated with Claude)
-- @version 1.1
-- @about
--   Imports markers from a _reaper.txt file, offset by the current
--   playhead (edit cursor) position. Place your cursor at the start
--   of a chapter, run this script, pick the marker file, and markers
--   land at the correct absolute positions in the session.
--
--   Expected file format (one per line):
--     MARKER <index> <position_in_seconds> "<name>" <color>
--   Lines starting with // are treated as comments and skipped.

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
  -- Get current edit cursor position (this is the offset)
  local cursor_pos = reaper.GetCursorPosition()

  -- Prompt user to select a marker file
  local retval, filepath = reaper.GetUserFileNameForRead("", "Select marker file", "*.txt")
  if not retval then return end

  -- Read the file
  local file = io.open(filepath, "r")
  if not file then
    reaper.ShowMessageBox("Could not open file:\n" .. filepath, "Error", 0)
    return
  end

  local count = 0

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for line in file:lines() do
    -- Skip empty lines and comments
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 2) ~= "//" then
      -- Parse: MARKER <index> <position> "<name>" <color>
      local pos_str, name = trimmed:match('MARKER%s+%d+%s+([%d%.]+)%s+"(.-)"%s*')
      if pos_str and name then
        local pos = tonumber(pos_str)
        if pos then
          local absolute_pos = cursor_pos + pos
          reaper.AddProjectMarker(0, false, absolute_pos, 0, name, -1)
          count = count + 1
        end
      end
    end
  end

  file:close()

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Import markers at playhead", -1)
end

main()
