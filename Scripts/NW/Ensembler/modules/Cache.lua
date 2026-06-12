-- Cache.lua - Generic synchronous caching module for reusable lazy loading pattern
-- 
-- This provides a simple lazy loading cache that loads data when first accessed
-- and caches it for subsequent calls. This is NOT an async cache system - all
-- loading happens synchronously in the main thread.
--
-- Usage:
--   local myCache = Cache.create(function() return loadMyData() end)
--   myCache:ensureCache()  -- Load data if not already loaded
--   local data = myCache:getData()  -- Get cached data (loads if needed)
--   myCache:clear()  -- Invalidate cache, next access will reload
--   myCache:reload()  -- Force reload cache immediately

Cache = {}

local debug_log = State.debug_log

---@class CacheInstance
---@field cache any[]|nil Cached data array
---@field loadCallback fun(): any[] Function that loads and returns data to cache

---Create a new cache instance
---@param loadCallback fun(): any[] Function that loads and returns the data to cache
---@return CacheInstance
function Cache.create(loadCallback)
    if not loadCallback or type(loadCallback) ~= "function" then
        error("Cache.create requires a loadCallback function")
    end
    
    ---@type CacheInstance
    local instance = {
        cache = nil,
        loadCallback = loadCallback
    }
    
    ---Ensure cache is loaded (loads if not already cached)
    function instance:ensureCache()
        if not self.cache then
            debug_log("Loading cache data...")
            self.cache = self.loadCallback()
            debug_log("Cache loaded with " .. #self.cache .. " items")
        end
    end
    
    ---Get cached data (loads if not already cached)
    ---@return any[] cachedData
    function instance:getData()
        self:ensureCache()
        return self.cache
    end
    
    ---Clear cache (next access will reload)
    function instance:clear()
        self.cache = nil
        debug_log("Cache cleared")
    end
    
    ---Force reload cache immediately
    function instance:reload()
        self:clear()
        self:ensureCache()
    end
    
    return instance
end

return Cache