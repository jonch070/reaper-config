-- @description Routing config helper functions
-- @author Nate Weiner
-- @link https://nateweiner.com
-- @version 1.0
-- @about
--   Helper functions for building routing configuration.
--   These return declarative data structures that RoutingAnalysis resolves at runtime.

local RoutingConfigHelpers = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Creates a folder reference for use in tracks()
--- @param name string The folder name
--- @param options table|nil Optional filtering options
--- @return table Folder data structure
---
--- Options:
---   matchPattern: string (Lua pattern) - only include tracks matching this
---   excludePattern: string (Lua pattern) - exclude tracks matching this
---
--- Examples:
---   folder("Stems")
---   folder("Stems", { excludePattern = "^%-$" })
---   folder("Stems", { matchPattern = "^%*%d+%." })
function RoutingConfigHelpers.folder(name, options)
    local result = {
        type = "folder",
        name = name,
    }
    if options then
        result.matchPattern = options.matchPattern
        result.excludePattern = options.excludePattern
    end
    return result
end

--- Creates a master track reference for use in tracks()
--- @return table Master track data structure
---
--- Example:
---   tracks(master())
function RoutingConfigHelpers.master()
    return {
        type = "master",
    }
end

--- Creates a tracks specification for the routing config
--- @param input string|table Track name, array of names, folder(), master(), or mixed array
--- @return table Tracks data structure
---
--- Examples:
---   tracks("FULL MIX")                              -- single track
---   tracks({"Bus 1", "Bus 2"})                      -- multiple tracks
---   tracks(folder("Stems"))                        -- folder children
---   tracks(folder("Stems", {excludePattern="^%-"})) -- filtered folder
---   tracks(master())                               -- master track
---   tracks({folder("A"), folder("B"), "Extra"})    -- mixed
function RoutingConfigHelpers.tracks(input)
    -- Handle nil/empty
    if input == nil then
        return {
            type = "tracks",
            items = {},
        }
    end

    -- Handle single string (track name)
    if type(input) == "string" then
        return {
            type = "tracks",
            items = {{ type = "name", name = input }},
        }
    end

    -- Handle table input
    if type(input) == "table" then
        -- Check if it's a folder() or master() result
        if input.type == "folder" or input.type == "master" then
            return {
                type = "tracks",
                items = {input},
            }
        end

        -- It's an array - could be strings, folders, or mixed
        local items = {}
        for _, item in ipairs(input) do
            if type(item) == "string" then
                table.insert(items, { type = "name", name = item })
            elseif type(item) == "table" and (item.type == "folder" or item.type == "master") then
                table.insert(items, item)
            end
        end

        return {
            type = "tracks",
            items = items,
        }
    end

    -- Fallback
    return {
        type = "tracks",
        items = {},
    }
end

return RoutingConfigHelpers
