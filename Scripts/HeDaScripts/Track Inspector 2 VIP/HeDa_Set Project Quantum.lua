-- set project data for specific quantum override

local retval, project_quantum = reaper.GetProjExtState(0, "HeDaTrackInspector", "QUANTUM")
project_quantum = tonumber(project_quantum) or "0"
local retval, quantum = reaper.GetUserInputs("Project Quantum", 1, "Change Setting (0 to unset):"..",extrawidth=200", project_quantum)
if retval then 
    quantum = tonumber(quantum) or "0"
    if quantum=="0" then 
        reaper.SetProjExtState(0, "HeDaTrackInspector", "QUANTUM", "")
    else
        reaper.SetProjExtState(0, "HeDaTrackInspector", "QUANTUM", tostring(quantum))
        reaper.ExecProcess("pw-metadata -n settings 0 clock.force-quantum " .. tostring(quantum), 0)
    end
end