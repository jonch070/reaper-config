-- Step 2: Apply random presets to Channel Mapper FX on selected items
-- Run after Step 1

-- CONFIGURATION: Your preset names (skip channel 4)
local preset_names = {
  "ToChannel1", "ToChannel2", "ToChannel3", 
  "ToChannel5", "ToChannel6", "ToChannel7", "ToChannel8",
  "ToChannel9", "ToChannel10", "ToChannel11", "ToChannel12",
  "ToChannel13", "ToChannel14", "ToChannel15", "ToChannel16"
}

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
      -- Find Channel Mapper FX
      local fx_count = reaper.TakeFX_GetCount(take)
      
      for fx = 0, fx_count - 1 do
        local _, fx_name = reaper.TakeFX_GetFXName(take, fx, "")
        
        if fx_name and fx_name:find("hannel") and fx_name:find("apper") then
          -- Found it! Apply random preset
          local random_preset = preset_names[math.random(1, #preset_names)]
          reaper.TakeFX_SetPreset(take, fx, random_preset)
          success_count = success_count + 1
          break
        end
      end
    end
  end
end

reaper.Undo_EndBlock("Apply random channel presets", -1)
reaper.UpdateArrange()

-- Silent completion for custom actions
-- Uncomment the line below if you want a message when running standalone:
-- reaper.ShowMessageBox("Applied random presets to " .. success_count .. " items", "Complete", 0)
