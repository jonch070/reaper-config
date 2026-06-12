-- GridView.lua - The Main Grid View

local Grid = require('components/Views/Grid/Grid')
local FilterInput = require('components/Selectors/FilterInput')

GridView = {}

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

function GridView.render(ctx)
    
    -- Render the main table
    Grid.render()

    -- Add Chord Tone button below the table (left side)
   if reaper.ImGui_Button(ctx, 'Add Chord Tone##add_chord_tone_main', 120, 25) then
        State.ensemble.addNewChordTone()
    end
    
    -- Render any active filter popups
    FilterInput.renderActivePopups()
end

return GridView