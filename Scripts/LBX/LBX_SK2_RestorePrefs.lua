  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end
  
  function RestorePrefs()
  
    local outfol = reaper.GetResourcePath()..'/Scripts/LBX/LBXSK_Resources/PrefsBak/'
    local outfn = 'prefs.txt'
    
    if reaper.file_exists(outfol..outfn) then
  
      for line in io.lines(outfol..outfn) do
      
        local prefname, prefsetting = string.match(line, '%[(.-)%](.*)')
        if prefname and tonumber(prefsetting) then
        
          reaper.SNM_SetIntConfigVar(prefname, tonumber(prefsetting))
        
        end
      
      end

      reaper.MB('Preferences successfully restored.','SK2: Restore preferences',0)
      
    else
    
      reaper.MB('No preferences restore file found.','SK2: Restore preferences',0)
    
    end
    
  end
  
  RestorePrefs() 
