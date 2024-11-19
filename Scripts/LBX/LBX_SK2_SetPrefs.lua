
  local prefs = {}
  prefs['midisendflags'] = {[0] = {32,128}, [1] = {1,2,8,16,64,256}}
  local bittab = {}
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end
  
  function PopulateBitTab()
  
    local v = 1
    for i = 1, 32 do
      bittab[v] = i
      v = v + v
    end
  
  end
  
  function StoreSettings()

    local outfol = reaper.GetResourcePath()..'/Scripts/LBX/LBXSK_Resources/PrefsBak/'
    local outfn = 'prefs.txt'
    reaper.RecursiveCreateDirectory(outfol,1)
    
    --Restore settings first - so new saved settings include the users original settings
    RestorePrefs()
    
    --if not reaper.file_exists(outfol..outfn) then
      local txt = ''
      for prefname,b in pairs(prefs) do
        local prefsetting = reaper.SNM_GetIntConfigVar(prefname, 0)
        txt = txt .. '['..prefname..']'..prefsetting..'\n'          
      end
      
      file=io.open(outfol..outfn,"w")
      if file then
        file:write(txt)
      end
      file:close()
      
    --end
    
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
  
    end
    
  end
  
  function SetPrefs()
  
    StoreSettings()
    for prefname,b in pairs(prefs) do

      local prefsetting = reaper.SNM_GetIntConfigVar(prefname, 0)
    
      local flags = 0
      for v = 1, #b[1] do
      
        flags = flags | b[1][v]
      
      end
      prefsetting = prefsetting | flags

      local flags = 4294967295
      for v = 1, #b[0] do
      
        flags = flags - b[0][v]
      
      end
      prefsetting = prefsetting & flags
      
      reaper.SNM_SetIntConfigVar(prefname, prefsetting)
      --DBG(prefsetting)
    end
    
    reaper.MB('SK2 Preferences set.','SK2 Set Preferences',0)
  
  end
  
  --PopulateBitTab()
  
  SetPrefs()

