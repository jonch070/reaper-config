-- ============================================================================
-- ROUTING CONFIG TEMPLATE
-- ============================================================================
--
-- To configure routing analysis for your template:
-- 1. Copy this file to "RoutingConfig.lua" (same folder)
-- 2. Modify the config below to match your template
-- 3. Your RoutingConfig.lua will not be overwritten by updates
--
-- ============================================================================

-- Load the helper functions
local configHelpers = require("utils.RoutingConfigHelpers")
local tracks = configHelpers.tracks
local folder = configHelpers.folder
local master = configHelpers.master

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local RoutingConfig = {

    -- ========================================================================
    -- TARGET CHAIN
    -- ========================================================================
    -- The expected signal flow path. All source tracks should route to step 1,
    -- then audio flows through each subsequent step in order.
    --
    -- Example flows:
    --   Instruments → Stems → Master
    --   Instruments → Stems → Mix Bus → Master
    --   Instruments → Stems → FULL MIX → Music Out → Master
    --
    -- Use tracks() to identify tracks at each step:
    --   tracks("Track Name")           -- single track by name
    --   tracks({"A", "B", "C"})        -- multiple tracks by name
    --   tracks(folder("Folder"))       -- all children of a folder
    --   tracks(folder("Folder", {      -- filtered folder children
    --       matchPattern = "^Stem",    -- only include tracks matching pattern
    --       excludePattern = "^%-",    -- exclude tracks matching pattern
    --   }))
    --   tracks(master())               -- the master track
    --
    targetChain = {
        -- Example: All tracks in "Stems" folder
        -- tracks(folder("Stems")),

        -- Example: Stems folder, excluding spacer tracks named "-"
        -- tracks(folder("Stems", { excludePattern = "^%-$" })),

        -- Example: Multiple stem folders
        -- tracks({
        --     folder("Orchestra Stems"),
        --     folder("Synth Stems"),
        -- }),

        -- Example: Specific tracks as stems
        -- tracks({"Drum Bus", "Bass Bus", "Keys Bus", "Guitar Bus"}),

        -- Final destination (usually master)
        tracks(master()),
    },

    -- ========================================================================
    -- PARALLEL PATHS
    -- ========================================================================
    -- Routes that audio can flow through (like reverbs, FX buses) without
    -- being flagged as a duplicate. Audio going through these should eventually
    -- rejoin the main chain.
    --
    parallelPaths = {
        -- Example: Reverb folder
        -- tracks(folder("Reverbs")),

        -- Example: Tracks with a prefix
        -- tracks(folder("FX", { matchPattern = "^FX:" })),
    },

    -- ========================================================================
    -- IGNORE
    -- ========================================================================
    -- Tracks that aren't sources and shouldn't be analyzed for routing.
    -- These are typically utility tracks, outputs, markers, video, etc.
    --
    ignore = {
        -- Example: Output/mixdown folder
        -- tracks(folder("Mixdown")),

        -- Example: Utility tracks
        -- tracks({"Video Out", "Markers", "Click"}),
    },

    -- ========================================================================
    -- OPTIONS
    -- ========================================================================

    -- Automatically ignore empty top-level tracks (no content, no routing)
    -- These are often marker tracks, video tracks, or organizational elements
    ignoreEmptyTopLevelTracks = true,

    -- Automatically ignore pinned/locked tracks (future feature)
    -- ignorePinnedTracks = false,
}

return RoutingConfig
