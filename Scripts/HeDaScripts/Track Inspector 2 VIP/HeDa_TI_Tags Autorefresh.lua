--[==[
   * ReaScript Name: Track Inspector
   * Author: Hector Corcin (HeDa)
   * Author URI: https://reaper.hector-corcin.com
   * Licence: Copyright © 2016-2025, Hector Corcin
--]==]
 




--------------------------------------------------------------------------------
local sectionname="HeDaTrackInspector"
reaper.SetProjExtState(0, sectionname, "Tags Toggle AutoRefresh", "1")
local s_new_value,filename,sectionID,cmdID,mode,resolution,val = reaper.get_action_context()
reaper.SetProjExtState(0, sectionname, "Tags sectionID", sectionID)
reaper.SetProjExtState(0, sectionname, "Tags cmdID", cmdID)
