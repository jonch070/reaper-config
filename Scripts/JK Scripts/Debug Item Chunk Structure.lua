-- Debug script to examine item chunk structure
-- This will help us understand how to properly add CHANMAP

-- Get first selected item
local item = reaper.GetSelectedMediaItem(0, 0)

if not item then
  reaper.ShowMessageBox("Please select at least one item!", "Error", 0)
  return
end

-- Get the item chunk
local retval, chunk = reaper.GetItemStateChunk(item, "", false)

if retval then
  -- Show the chunk in console
  reaper.ShowConsoleMsg("=== ITEM CHUNK DEBUG ===\n\n")
  reaper.ShowConsoleMsg(chunk)
  reaper.ShowConsoleMsg("\n\n=== END CHUNK ===\n")
  
  -- Analyze the chunk
  local analysis = "\n=== CHUNK ANALYSIS ===\n\n"
  
  -- Check for TAKE line
  if chunk:find("<TAKE") then
    analysis = analysis .. "✓ Found <TAKE section\n"
    
    -- Extract just the TAKE line
    local take_line = chunk:match("(<TAKE[^\n]*)")
    if take_line then
      analysis = analysis .. "TAKE line: " .. take_line .. "\n"
    end
  else
    analysis = analysis .. "✗ No <TAKE section found\n"
  end
  
  -- Check for CHANMODE
  if chunk:find("CHANMODE") then
    local chanmode = chunk:match("(CHANMODE[^\n]*)")
    analysis = analysis .. "CHANMODE: " .. chanmode .. "\n"
  end
  
  -- Check for existing CHANMAP
  if chunk:find("CHANMAP") then
    analysis = analysis .. "✓ Already has CHANMAP:\n"
    for chanmap in chunk:gmatch("(CHANMAP[^\n]*)") do
      analysis = analysis .. "  " .. chanmap .. "\n"
    end
  else
    analysis = analysis .. "✗ No CHANMAP found (this is normal if not set)\n"
  end
  
  -- Show SOURCE section
  if chunk:find("<SOURCE") then
    local source_line = chunk:match("(<SOURCE[^\n]*)")
    analysis = analysis .. "✓ SOURCE: " .. (source_line or "found") .. "\n"
  end
  
  reaper.ShowConsoleMsg(analysis)
  
  reaper.ShowMessageBox("Chunk dumped to console!\nView → Show ReaScript console", "Debug Complete", 0)
else
  reaper.ShowMessageBox("Failed to get item chunk!", "Error", 0)
end
