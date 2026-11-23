-- pup-misc / bountyhunting | pure data lookups used by both sides
-- One global table so nothing else leaks into the shared pup-misc Lua state.

BountyShared = {}

local DATA_KEY <const> = { kill = 'Kill', arrest = 'Arrest', escort = 'Escort' }

BountyShared.KINDS = { 'kill', 'arrest', 'escort' }

function BountyShared.isKind(kind)
    return DATA_KEY[kind] ~= nil
end

-- list of contracts of one kind posted in one town, or nil
function BountyShared.contracts(kind, town)
    local key = DATA_KEY[kind]
    local byTown = key and BountyConfig[key]
    local list = type(byTown) == 'table' and byTown[town] or nil
    return type(list) == 'table' and list or nil
end

function BountyShared.contract(kind, town, idx)
    local list = BountyShared.contracts(kind, town)
    local ct = list and list[idx]
    return type(ct) == 'table' and ct or nil
end

function BountyShared.pool(name)
    local pools = BountyConfig.PedPools
    local list = type(pools) == 'table' and pools[name] or nil
    if type(list) ~= 'table' or #list == 0 then return nil end
    return list
end

-- the pools a block's peds are drawn from, by role
function BountyShared.poolName(kind, block, role)
    if kind == 'escort' then
        return role == 'client' and block.clientPool or block.enemyPool
    end
    return block.pedPool
end

-- how many paid units a block has: bodies (kill), wanted men (capture) or the one client (escort)
function BountyShared.units(kind, block)
    if kind == 'kill' then return type(block.enemies) == 'table' and #block.enemies or 0 end
    if kind == 'arrest' then return type(block.targets) == 'table' and #block.targets or 0 end
    return 1
end

-- the difficulty block for a party size, only when it can actually be played
function BountyShared.block(kind, town, idx, count)
    local ct = BountyShared.contract(kind, town, idx)
    if not ct or not ct.coords or not ct.dropCoords or type(ct.levels) ~= 'table' then return nil end
    local block = ct.levels[count]
    if type(block) ~= 'table' then return nil end
    if BountyShared.units(kind, block) < 1 then return nil end
    if kind == 'escort' then
        if not BountyShared.pool(block.clientPool) then return nil end
        if type(block.enemies) == 'table' and #block.enemies > 0 and not BountyShared.pool(block.enemyPool) then return nil end
    elseif not BountyShared.pool(block.pedPool) then
        return nil
    end
    return block, ct
end

-- per-unit share of the block's total (fractions are kept; the server floors the paid amount)
function BountyShared.share(kind, block)
    local units = BountyShared.units(kind, block)
    local cash = math.max(0, tonumber(block.rewardCash) or 0)
    local gold = math.max(0, tonumber(block.rewardGold) or 0)
    if units < 1 then return 0, 0, 0 end
    return cash / units, gold / units, units
end

function BountyShared.jobAllowed(job)
    if not BountyConfig.Jobs.Lock then return true end
    if type(job) ~= 'string' then return false end
    for _, j in ipairs(BountyConfig.Jobs.Law or {}) do
        if j == job then return true end
    end
    for _, j in ipairs(BountyConfig.Jobs.Hunter or {}) do
        if j == job then return true end
    end
    return false
end

function BountyShared.weaponName(name)
    if type(name) ~= 'string' then return nil end
    return (BountyConfig.WeaponFixes or {})[name] or name
end
