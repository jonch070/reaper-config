-- GMEM.lua - Global Memory utilities for JSFX ↔ Lua communication
--
-- Provides clean API for GMEM operations and standardizes memory addressing
-- across transform system and retroactive recording.

require('types/types')

local GMEM = {}

-- ============================================================================
-- MEMORY LAYOUT CONSTANTS
-- ============================================================================
-- MUST match EnsemblerFilter.jsfx GMEM layout documentation

GMEM.ZONES = {
    TRANSFORMS_BASE = 1000,
    TRANSFORMS_END = 7199,
    RETRO_BASE = 100000,
    RETRO_END = 499999
}

GMEM.TRANSFORMS = {
    BASE = 1000,
    SLOTS_PER_INSTRUMENT = 31,  -- 1 count + (10 transforms × 3 slots/transform)
    MAX_INSTRUMENTS = 200
}

GMEM.RETROACTIVE = {
    BASE = 100000,
    SLOTS_PER_INSTRUMENT = 3002,  -- 2 metadata + (500 events × 6 slots/event)
    MAX_INSTRUMENTS = 100
}

-- ============================================================================
-- INSTRUMENT SLOT ASSIGNMENT
-- ============================================================================

---Assign sequential memory slot numbers to instruments (0-based)
---@param instruments Instrument[]
---@return table<string, integer> slotMap Mapping of instrument GUID to slot number
function GMEM.assignInstrumentSlots(instruments)
    ---@type table<string, integer>
    local slotMap = {}

    for i, instrument in ipairs(instruments) do
        slotMap[instrument.trackData.guid] = i - 1  -- 0-based for JSFX
    end

    return slotMap
end

-- ============================================================================
-- TRANSFORM SYSTEM API
-- ============================================================================

---Calculate GMEM base address for an instrument's transform data
---@param slotNumber integer 0-based instrument slot number
---@return integer base GMEM base address
function GMEM.getTransformBase(slotNumber)
    return GMEM.TRANSFORMS.BASE + (slotNumber * GMEM.TRANSFORMS.SLOTS_PER_INSTRUMENT)
end

---Write transform count to GMEM
---@param slotNumber integer 0-based instrument slot number
---@param count integer Number of transforms (0-10)
function GMEM.writeTransformCount(slotNumber, count)
    local base = GMEM.getTransformBase(slotNumber)
    reaper.gmem_write(base, count)
end

---Write a single transform to GMEM
---@param slotNumber integer 0-based instrument slot number
---@param transformIndex integer 0-based transform index (0-9)
---@param paramId number Parameter ID (0=velocity, 1-127=CC number)
---@param typeId number Type ID (0=none, 1=scale, 2=fixed, 3=ignore)
---@param value number Transform value (0.0-2.0 for scale, 0-127 for fixed)
function GMEM.writeTransform(slotNumber, transformIndex, paramId, typeId, value)
    local base = GMEM.getTransformBase(slotNumber)
    local offset = base + 1 + (transformIndex * 3)

    reaper.gmem_write(offset + 0, paramId)
    reaper.gmem_write(offset + 1, typeId)
    reaper.gmem_write(offset + 2, value)
end

-- ============================================================================
-- RETROACTIVE RECORDING API
-- ============================================================================

---Calculate GMEM base address for an instrument's retroactive buffer
---@param slotNumber integer 0-based instrument slot number
---@return integer base GMEM base address
function GMEM.getRetroactiveBase(slotNumber)
    return GMEM.RETROACTIVE.BASE + (slotNumber * GMEM.RETROACTIVE.SLOTS_PER_INSTRUMENT)
end

return GMEM
