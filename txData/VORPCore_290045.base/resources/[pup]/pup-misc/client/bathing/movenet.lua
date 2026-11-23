-- bathing | client: starts a task move network "with init params".
-- The game reads a 512-byte block: the clipset hash at byte 0, the clipset
-- variable hash at byte 8 and a pointer to the starting state's name at byte
-- 240, each a 64-bit little-endian value. A Lua string is handed to a native
-- as a pointer to its bytes, so the block is built with string.pack.
-- Publishes BathhouseMoveNet (used only by client/bathing/main.lua).

local TASK_PLAIN <const> = 0x139805C2A67C4795    -- TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS
local TASK_ADVANCED <const> = 0x7B6A04F98BBAFB2C -- TASK_MOVE_NETWORK_ADVANCED_BY_NAME_WITH_INIT_PARAMS
local VAR_STRING <const> = 0xFA925AC00EB830B9
local BLOCK_SIZE <const> = 512
local STATE_OFFSET <const> = 240

-- the last block per entity stays referenced so it is not collected while in use
local kept = {}

local function hash32(name)
    return GetHashKey(name) & 0xFFFFFFFF
end

local function buildBlock(clipset, variable, state)
    local statePtr = Citizen.InvokeNative(VAR_STRING, 10, 'LITERAL_STRING', state, Citizen.ResultAsLong()) or 0
    local head = string.pack('<I8I8', hash32(clipset), hash32(variable))
    local body = head .. string.rep('\0', STATE_OFFSET - #head) .. string.pack('<i8', statePtr)
    return body .. string.rep('\0', BLOCK_SIZE - #body)
end

BathhouseMoveNet = {}

-- on a ped: plain variant, blend-in 1.0
function BathhouseMoveNet.start(entity, network, clipset, variable, state)
    local data = buildBlock(clipset, variable, state)
    kept[entity] = data
    Citizen.InvokeNative(TASK_PLAIN, entity, network, data, 1.0, 0, 0, 0)
end

-- on an object (the rag): advanced variant, anchored at pos with the heading
function BathhouseMoveNet.startAt(entity, network, clipset, variable, state, pos, heading)
    local data = buildBlock(clipset, variable, state)
    kept[entity] = data
    Citizen.InvokeNative(TASK_ADVANCED, entity, network, data,
        pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, 0.0, 0.0, heading + 0.0, 2, 3.0, 0, 0, 0, 0)
end

-- drop the kept blocks of entities that are gone
function BathhouseMoveNet.forget(entity)
    if entity then
        kept[entity] = nil
        return
    end
    kept = {}
end
