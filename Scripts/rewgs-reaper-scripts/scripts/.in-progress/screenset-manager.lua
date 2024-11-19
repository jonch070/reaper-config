-- NOTE: requires that the js_ReaScriptAPI package be installed via ReaPack

key_codes = {
    enter = 13, -- note that the word `return` can't be used because it's a keyword; this does however refer to the key `Return` on a Mac keyboard
    command = 17,
    option = 18,
    left_bracket = 91,
    right_bracket = 93,
    m = 77,
    backtick = 96
}

-- command ids
window_sets = {
    {
        name = 'main',
        command_id = 40454,
        key_code = {
            key_codes.command,
            key_codes.enter
        },
    },
    {
        name = 'main (no inspector)',
        command_id = 40455,
        key_code = {
            -- key_codes.left_bracket
        },
    },
    {
        name = 'main (no master output)',
        command_id = 40456,
        key_code = {
            -- key_codes.right_bracket
        },
    },
    {
        name = 'mixer (docker)',
        command_id = 40457,
        key_code = {
            -- key_codes.command,
            -- key_codes.m
        }
    },
    {
        name = 'piano roll (docked)',
        command_id = 40458,
        key_code = {
            -- key_codes.backtick
        }
    }
    -- s_01 = 40454,  -- main (left inspector, right master)  Cmd+Return
    -- s_02 = 40455,  -- main (no inspector)                  ]
    -- s_03 = 40456,  -- main (no master)                     [
    -- s_04 = 40457,  -- mixer (docked)                       Cmd+M
    -- s_05 = 40458,  -- piano roll (docked)                  `
    -- s_06 = 40459,
    -- s_07 = 40460,
    -- s_08 = 40461,
    -- s_09 = 40462,
    -- s_10 = 40463,
}


window_set_actions = {
    40454,
    40455,
    40456,
    40457,
    40458,
}


function chat_gpt()
    for i, id in pairs(window_set_actions) do
        toggle_state = reaper.GetToggleCommandState(id)
        reaper.ShowConsoleMsg(toggle_state)

        -- if toggle_state == 1 then
        --     reaper.ShowConsoleMsg('The current window set has the index of: ' .. id .. '\n')
        --     break
        -- end

    end

    -- reaper.ShowConsoleMsg('None of the listed window sets are active!')
end


function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end


function get_keystrokes_and_set_window_set()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg('Running get_keystrokes_and_set_window_set()')

    local state = reaper.JS_VKeys_GetState(0)

    keystrokes = {}
    for i = 1, 255 do
        if string.byte(state:sub(i, i)) == 1 then
            for iterator, window_set in ipairs(window_sets) do
                local matches = {}
                for j = 0, #window_set.key_code do
                    reaper.ShowConsoleMsg(tostring(#window_set.key_code))
                    table.insert(keystrokes, iterator)
                    if iterator == window_set.key_code[j] then
                        -- FIXME: this is where it's breaking -- this block is never running
                        reaper.ShowConsoleMsg('We have a match!')
                        table.insert(match, iterator)
                    end
                end

                if #keystrokes == #matches then
                    comparisons = {}
                    for n = 1, #keystrokes do
                        if keystrokes[n] ~= matches[n] then
                            comparisons[n] = true
                        else
                            comparisons[n] = false
                        end
                    end

                    for index, value in ipairs(comparisons) do
                        if value == false then
                            reaper.ShowConsoleMsg('Returning false!')
                            return
                        end
                    end

                    reaper.ShowConsoleMsg('Returning true!')



                    -- set window_set
                    -- reaper.ShowConsoleMsg(window_set.name)
                    -- reaper.Main_OnCommand(window_set.command_id, 0, 0)
                end

            end
        end
    end
end


function print_keystrokes()
    state = reaper.JS_VKeys_GetState(0)
    reaper.ClearConsole()
    for i = 1, 255 do
        if string.byte(state:sub(i, i)) == 1 then
            reaper.ShowConsoleMsg(i .." is pressed\n")
        end
    end
end


function main()
    -- print_keystrokes()
    -- get_keystrokes_and_set_window_set()
    chat_gpt()
    -- reaper.defer(main)
    -- reaper.Main_OnCommand(window_sets.s_02, 0, 0)
end


main()
