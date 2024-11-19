-- Export still image at region start to Downloads folder
-- Modify the path to your Mac's Downloads folder

local _, _, section_id, _, _, _, _ = reaper.get_action_context()
if not section_id then
  section_id = 0 -- specify a default section ID
end

local project_name = reaper.GetProjectName(0, "")

-- Modify the path to your Mac's Downloads folder
local path = "/Users/your_username/Downloads/"

-- Get number of regions in project
local num_regions = reaper.CountProjectMarkers(0, 0)

-- Loop through all regions
for i = 0, num_regions - 1 do
  local is_region, _, _, region_start, region_end, _, _, region_name = reaper.EnumProjectMarkers3(0, i)
  
  -- Check if marker is a region and not a normal marker
  if is_region then
    -- Set filename to region name with .png extension
    local filename = project_name .. " - " .. (region_name or "Region_"..tostring(i+1)) .. ".png"
    local full_path = path .. filename
    
    -- Set region start as play cursor position
    reaper.SetEditCurPos(region_start, false, false)
    
    -- Check if video window is open
    local video_window = reaper.JS_Window_FindChildByID(reaper.JS_Window_Find(reaper.JS_Localize("Video window", "common"), true), 1000)
    if video_window then
      -- Send video window command to export current frame to file
      reaper.JS_WindowMessage_Send(video_window, "WM_COMMAND", 40733, 0, 0, 0)
      reaper.JS_WindowMessage_Send(reaper.JS_Window_Find(reaper.JS_Localize("Render", "common"), true), "WM_COMMAND", 1, 0, 0, 0)
      reaper.JS_WindowMessage_Send(reaper.JS_Window_Find(reaper.JS_Localize("Render to File", "common"), true), "WM_COMMAND", 0x3E9, 0, 0, 0)
      reaper.GetSetProjectInfo_String(0, "RENDER_FILE", full_path, true)
      reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "png", true)
      reaper.GetSetProjectInfo_String(0, "RENDER_BOUNDSFLAG", "1026", true)
      reaper.JS_WindowMessage_Send(reaper.JS_Window_Find(reaper.JS_Localize("Render to File", "common"), true), "WM_COMMAND", 0x3E8, 0, 0, 0)
    end
  end
end

