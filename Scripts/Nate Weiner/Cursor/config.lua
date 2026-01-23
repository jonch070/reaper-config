-- VideoCutConfig.lua - Centralized configuration for video cut navigation system
-- All tunable parameters in one place for easy adjustment
-- Author: Nate Weiner (https://nateweiner.com)

local VideoCutConfig = {}

-- =============================================================================
-- Scene Detection Settings
-- =============================================================================

-- Scene detection sensitivity (0.0 to 1.0)
-- Lower values = more sensitive (detects subtle changes)
-- Higher values = less sensitive (only detects major changes)
-- Recommended: 0.2 for most content
VideoCutConfig.SCENE_THRESHOLD = 0.2

-- Downscale video width for faster processing
-- Lower values = faster but less accurate
-- Set to 0 to disable downscaling (slower but more accurate)
-- Recommended: 320 for 2-4x speedup with minimal accuracy loss
VideoCutConfig.DOWNSCALE_WIDTH = 320

-- =============================================================================
-- Navigation Search Settings
-- =============================================================================

-- Search chunk size when looking for a cut near cursor (in seconds)
-- Smaller = faster initial response, more chunks if cut is far
-- Larger = slower initial response, fewer chunks needed
-- Recommended: 10 seconds
VideoCutConfig.NAVIGATION_SEARCH_CHUNK_SIZE = 10

-- Maximum search distance when looking for a cut (in seconds)
-- System will search this far before giving up
-- Recommended: 120 seconds (2 minutes)
VideoCutConfig.MAX_SEARCH_DISTANCE = 120

-- =============================================================================
-- Background Fill Settings
-- =============================================================================

-- Background fill chunk size (in seconds)
-- How much video to process at once when building cache in background
-- Larger = fewer jobs but longer per job
-- Smaller = more jobs but faster per job
-- Recommended: 60 seconds
VideoCutConfig.BACKGROUND_FILL_CHUNK_SIZE = 60

-- Enable processing window to limit background fill to area around cursor
-- true = only cache video near cursor (recommended for long films)
-- false = cache entire video (recommended for short projects)
VideoCutConfig.ENABLE_PROCESSING_WINDOW = true

-- Processing window size (in seconds, centered on cursor)
-- Only used if ENABLE_PROCESSING_WINDOW is true
VideoCutConfig.PROCESSING_WINDOW_SIZE = 360

-- =============================================================================
-- Cache Settings
-- =============================================================================

-- ExtState section name for cache storage
-- Change this to invalidate all existing caches
VideoCutConfig.EXTSTATE_SECTION = "VideoSceneCuts"

-- Cache key prefix for versioning
-- Increment the number to invalidate all existing caches
VideoCutConfig.KEY_PREFIX = "VSC_1"

-- =============================================================================
-- Background Processor Settings
-- =============================================================================

-- Heartbeat update interval (in loop iterations)
-- How often to update the heartbeat timestamp
-- Lower = more accurate liveness detection but more ExtState writes
-- Higher = less overhead but less responsive liveness detection
-- Recommended: 10
VideoCutConfig.HEARTBEAT_UPDATE_INTERVAL = 10

-- Heartbeat timeout (in seconds)
-- Consider processor dead if heartbeat is older than this
-- Should be greater than expected loop iteration time
-- Recommended: 5.0 seconds
VideoCutConfig.HEARTBEAT_TIMEOUT = 5.0

-- Background processor command ID is discovered at runtime via ReaperUtils.Main_OnCommandByName()
-- This avoids hardcoded IDs that break when scripts move or are renamed

-- =============================================================================
-- Debug Settings
-- =============================================================================

-- Enable debug logging to console during development
-- In production (ReaPack), this is transformed to false by the build system
-- and ExtState controls logging via the "Toggle Debug Logging" action
local LOCAL_DEBUG = false
VideoCutConfig.LOCAL_DEBUG = LOCAL_DEBUG

return VideoCutConfig
