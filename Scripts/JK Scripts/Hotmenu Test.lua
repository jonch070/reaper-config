reaper.ClearConsole()

local width = 400
local height = 800

gfx.init("Menu", width, height, false)

text = [[
1,_Analog
 1,_Channels
  1,24900,Slew
  2,24900,Slew2
  4,24900,Channel4
  5,24900,Channel5
  6,24900,Channel6
  7,24900,Channel7
 2,_Character
  1,24900,Apicolypse
  2,24900,Crystal
  3,24900,Luxor
  4,24900,Neverland
 3,_Consoles
  1,Atmosphere
   1,24900,AtmosphereBuss
   2,24900,AtmosphereChannel
  2,C5RawConsole
   1,24900,C5RawBuss
   2,24900,C5RawChannel
  3,Console4
   1,24900,Console4Buss
   2,24900,Console4Channel
  4,Console5
   1,24900,Console5Buss
   2,24900,Console5Channel
   3,24900,Console5DarkCh
  5,Console6
   1,24900,Console6Buss
   2,24900,Console6Channel
  6,PDConsole
   1,24900,PDBuss
   2,24900,PDChannel
  7,PurestConsole
   1,24900,PurestConsoleBuss
   2,24900,PurestConsoleChannel
  8,uLaw
   1,24900,uLawDecode
   2,24900,uLawEncode
 4,_Desks
  1,24900,Desk
  2,24900,Desk4
  3,24900,PowerSag
  4,24900,PowerSag2
  5,24900,TransDesk
  6,24900,TubeDesk
 5,_Noise
  1,24900,ElectroHat
  2,24900,Noise
  3,24900,Voice Of The Starship
 6,_Tape
  1,24900,DrumSlam
  2,24900,FromTape
  3,24900,Iron Oxide 5
  4,24900,Iron Oxide Classic
  5,24900,Tape
  6,24900,TapeDust
  7,24900,TapeFat
  8,24900,ToTape5
  9,24900,ToTape6
 7,_Vinyl
  1,24900,Acceleration
  2,24900,CrunchyGrooveWear
  2,24900,GrooveWear
  2,24900,ToVinyl4
 8,24900,BussColors4
 9,24900,CStrip
 0,24900,Interstage
 q,24900,Righteous4
2,_Bass
 1,24900,BassDrive
 2,24900,BassKit
 3,24900,Deckwrecka
 4,24900,DubCenter
 5,24900,DubSub
 6,24900,FathomFive
 7,24900,Floor
3,_Compressors
 1,24900,ButterComp
 2,24900,ButterComp2
 3,24900,Compresaturator
 4,24900,curve
 5,24900,Logical4
 6,24900,Podcast
 7,24900,PodcastDeluxe
 8,24900,Point
 9,24900,Pop
 0,24900,Pressure4
 q,24900,PurestSquish
 w,24900,Pyewacket
 e,24900,Recurve
 r,24900,Surge
 t,24900,SurgeTide
 y,24900,Thunder
 u,24900,VariMu
4,_DeEss
 1,24900,DeBess
 2,24900,DeEss
5,_Delay
 1,24900,ADT
 2,24900,Hombre
 3,24900,Melt
 4,24900,PurestEcho
 5,24900,TapeDelay
6,_Dither
 1,24900,BuildATPDF
 2,24900,Ditherbox
 3,24900,DitherFloat
 4,24900,DitherMeTimbers
 5,24900,DoublePaul
 6,24900,HighGlossDither
 7,24900,NaturalizeDither
 8,24900,NodeDither
 9,24900,NotJustAnotherDither/CD
 0,24900,PaulDither
 q,24900,RawTimbers
 w,24900,SpatializeDither
 e,24900,StudioTan
 r,24900,TapeDither
 t,24900,TPDFDither
 y,24900,VinylDither
7,_EQ
 1,24900,Air
 2,24900,Aura
 3,24900,Average
 4,24900,Baxandall
 5,24900,Biquad
 6,24900,Biquad2
 7,24900,BiquadOneHalf
 8,24900,Capacitor
 9,24900,Energy
 0,24900,EQ
 q,24900,Hermepass
 w,24900,Highpass
 e,24900,Highpass2
 r,24900,Holt
 t,24900,Lowpass
 y,24900,Lowpass2
 u,24900,Pafnuty
 i,24900,PurestAir
 o,24900,ResEQ
 p,24900,Smooth
 a,24900,ToneSlant
8,_FX
 1,24900,Chorus
 2,24900,ChorusEnsemble
 3,24900,DustBunny
 4,24900,Ensemble
 5,24900,Srsly
 5,24900,StereoFX
 5,24900,Swell
 5,24900,Tremolo
 5,24900,Vibrato
9,_Gate
 1,24900,BrassRider
 2,24900,DeHiss
 3,24900,DigitalBlack
 4,24900,Gatelope
 5,24900,SoftGate
0,_Guitar
 1,24900,Gringer
 2,24900,Guitar Conditioner
q,_Limiters
 1,24900,ADClip7
 2,24900,BlockParty
 3,24900,ClipOnly
 4,24900,Loud
 5,24900,NC-17
 6,24900,OneCornerClip
w,_Monitoring
 1,24900,Monitoring
 2,24900,PeaksOnly
 3,24900,SlewOnly
 4,24900,SubsOnly
e,_Reverb
 1,24900,Distance
 2,24900,Distance2
 3,24900,MV
 4,24900,NonlinearSpace
 5,24900,PocketVerbs
 6,24900,StarChild
r,_Saturation
 1,24900,Bite
 2,24900,BitGlitter
 3,24900,Coils
 4,24900,Cojones
 5,24900,Density
 6,24900,DeRez
 7,24900,DeRez2
 8,24900,Drive
 9,24900,Dyno
 0,24900,Facet
 q,24900,Focus
 w,24900,Fracture
 e,24900,Hard Vacuum
 r,24900,High Impact
 t,24900,Mojo
 y,24900,PurestDrive
 u,24900,PurestWarm
 i,24900,Remap
 o,24900,SingleEndedTriode
 p,24900,Spiral
 a,24900,Spiral2
 s,24900,Unbox
 d,24900,Wider
t,_Utility
 1,24900,AQuickVoiceClip
 2,24900,BitShiftGain
 3,24900,DCVoltage
 4,24900,EdIsDim
 5,24900,EveryTrim
 6,24900,Golem
 7,24900,HermeTrim
 8,24900,MoNoam
 9,24900,PhaseNudge
 0,24900,PurestGain
 q,24900,SideDull
 w,24900,Sidepass
 e,24900,LeftMono
 r,24900,RightMono
 t,24900,VoiceTrick
]]

local function split(text, delim)

  local lines = {}
  local pattern = "[^" .. delim .. "]+"
  for x in text.gmatch(text, pattern) do
    table.insert(lines, x)
  end
  return lines
end

local function parseLine(x)

  local level
  local row = {}
 
  local n = 0 
  for i in text.gmatch(x, "[^,]+") do
  
    if n == 0 then
      level = string.len(string.match(i, "^ *"))
      row["key"] = string.match(i, "[^ ]")
    elseif n == 1 then
      row["action"] = i
    elseif n == 2 then
      row["name"] = i
    end
    
    n = n + 1
  end

  if n < 3 then
    row["name"] = row["action"]
    row["action"] = nil
  end
  
  return level, row
end

function parseMenu(lines, level)

  local menu = {}
  local prev = nil
  
  while #lines > 0 do

    local l, row = parseLine(lines[1])
    
    if l < level then
      break
    elseif l > level and prev ~= nil then
      prev["menu"] = parseMenu(lines, l)
    else
      table.insert(menu, row)
      table.remove(lines, 1)
      prev = row
    end   
  end
  
  return menu
end

_menu = parseMenu(split(text, "\n"), 0)
_stack = {}

local function setTextColorToWhite()
  gfx.set(1, 1, 1, 1)
end

local function setTextColorToGrey()
  gfx.set(0.5, 0.5, 0.5, 1)
end

local function setTextColorToRed()
  gfx.set(1, 0, 0, 1)
end

local function drawFolderName(row, depth)

  local widthOfThreeSpaces, _ = gfx.measurestr("   ")

  gfx.x = 30 + (depth-1)*widthOfThreeSpaces
  setTextColorToGrey()
  gfx.drawstr(row["name"])
  
  local w, h = gfx.measurestr("a")
  gfx.y = gfx.y + h
end

local function drawEntries(row)

  local w, h = gfx.measurestr(row["key"])
  gfx.x = 13 - w * 0.5
  setTextColorToRed()
  gfx.drawstr(row["key"])

  if row["menu"] ~= nil then
    gfx.x = 17
    setTextColorToWhite()
    gfx.drawstr(">")
  end

  gfx.x = 30
  setTextColorToWhite()
  gfx.drawstr(row["name"])
  
  local w, h = gfx.measurestr("a")
  gfx.y = gfx.y + h
end

function render()

  gfx.setfont(1, "Arial", 14)
  gfx.x, gfx.y = 10, 10
  
  local menu = _menu
  for i, v in ipairs(_stack) do
    local row = menu[v]
    drawFolderName(row, i)
    menu = row["menu"]
  end
  
  for _, v in pairs(menu) do
    drawEntries(v)
  end
end

backspaceKey = 8
deleteKey = 6579564
escapeKey = 27

function mainLoop()

  render()
  gfx.update()
  
  local inputCharacter = gfx.getchar()

  if inputCharacter == escapeKey then
    return
  end

  if #_stack == 0 and inputCharacter == backspaceKey then
    return
  end

  if inputCharacter == -1 then
    return
  end
  
  local menu = _menu

  for _, v in ipairs(_stack) do
    menu = menu[v]["menu"]
  end
  
  if inputCharacter == backspaceKey or inputCharacter == deleteKey then

    if #_stack > 0 then
      table.remove(_stack, #_stack)
    end

  else  
    
    for i, v in ipairs(menu) do

      if string.byte(v["key"]) == inputCharacter then

        if v["menu"] ~= nil then
          table.insert(_stack, i)
        else

          action = v["action"]

          if action ~= nil then
            reaper.Main_OnCommand(action, 0)
          end

          return
        
        end
      end
    end

  end
  
  reaper.defer(mainLoop)
end



mainLoop()




  -- if c == 27 then
  --   reaper.ShowMessageBox(c, c, 1)
  -- end

--  reaper.ShowMessageBox(#_stack, #_stack, 1)

