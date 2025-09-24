-- Step 1: Add Channel Mapper FX to all selected items
-- This adds a blank Channel Mapper that you'll need to configure manually

local item_count = reaper.CountSelectedMediaItems(0)

if item_count == 0 then
  reaper.ShowMessageBox("No items selected!", "Error", 0)
  return
end

reaper.Undo_BeginBlock()

local success_count = 0

for i = 0, item_count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  
  if item then
    local take = reaper.GetActiveTake(item)
    
    if take then
      -- Remove existing channel mappers
      local fx_count = reaper.TakeFX_GetCount(take)
      if fx_count then
        for j = fx_count - 1, 0, -1 do
          local _, fx_name = reaper.TakeFX_GetFXName(take, j, "")
          if fx_name and fx_name:find("hannel") and fx_name:find("apper") then
            reaper.TakeFX_Delete(take, j)
          end
        end
      end
      
      -- Add Channel Mapper via chunk insertion
      local retval, chunk = reaper.GetItemStateChunk(item, "", false)
      
      if retval then
        -- Remove any existing TAKEFX section
        chunk = chunk:gsub("<TAKEFX.->", "")
        
        -- Create minimal TAKEFX chunk with Channel Mapper
        local fx_chunk = string.format([[<TAKEFX
SHOW 0
LASTSEL 0
DOCKED 0
BYPASS 0 0 0
<JS utility/channel_mapper ""
>
FLOATPOS 0 0 0 0
FXID {%s}
WAK 0 0
>
]], reaper.genGuid())
        
        -- Insert before final >
        chunk = chunk:gsub("(>%s*)$", fx_chunk .. "%1")
        
        if reaper.SetItemStateChunk(item, chunk, false) then
          success_count = success_count + 1
        end
      end
    end
  end
end

reaper.Undo_EndBlock("Add Channel Mapper to items", -1)
reaper.UpdateArrange()

-- Silent completion for custom actions
-- Uncomment the line below if you want a message when running standalone:
-- reaper.ShowMessageBox("Added Channel Mapper to " .. success_count .. " items", "Complete", 0)

