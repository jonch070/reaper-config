-- @noindex
BlankGroup = {} -- To create a group with all things it needs
BlankGroup.__index = BlankGroup

function BlankGroup.NewDefaultSettings()
    return {
        Erase = true,
        Is_trim_ItemEnd = true,
        Is_trim_StartNextNote = true,
        Is_trim_EndNote = true,
        UseSnapOffset = false,
        Tips = true,
        Velocity = false,
        Vel_OriginalVal = 64,
        Vel_Min = -6,
        Vel_Max = 6,
        Pitch = false,
        Pitch_Original = 60,
        MatchByName = false,
        MatchByName_OctaveSearch = 2,
        MatchByName_Fallback = true,
        NoteRange = {
            Min = 0,
            Max = 127
        },
        VelocityRange = {
            Min = 0,
            Max = 127
        }
    }
end

function BlankGroup:Create(name)
    local temp = {
        name = name or "New Group",
        Settings = BlankGroup.NewDefaultSettings(),
        Selected = true
    }
    setmetatable(temp,BlankGroup)
    return temp
end

-- Back-fills any keys missing from a Settings table (e.g. one restored from a
-- project saved before a setting existed) with their defaults, so old saved
-- state doesn't pass nil into ImGui calls that expect a bool/number.
function FillMissingSettings(settings)
    if not settings then return BlankGroup.NewDefaultSettings() end
    for k, v in pairs(BlankGroup.NewDefaultSettings()) do
        if settings[k] == nil then
            settings[k] = v
        end
    end
    return settings
end

--[[ Groups = {}
Groups[1] = BlankGroup:Create('G1') ]]