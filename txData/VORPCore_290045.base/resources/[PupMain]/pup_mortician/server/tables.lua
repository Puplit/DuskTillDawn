-- pup_mortician | prep tables and caskets (server memory only)

Tables = {} -- key -> { casket = nil | casket }
for key in pairs(Config.Tables) do Tables[key] = {} end

function ValidTableKey(key)
    if type(key) ~= 'string' or not Config.Tables[key] then return nil end
    return key
end

-- a random pick of goods without repeats, returned in list order
local function rollGoods()
    local n = #Config.Goods
    local lo = math.max(0, math.min(Config.WantedGoods.min, Config.WantedGoods.max))
    local hi = math.max(Config.WantedGoods.min, Config.WantedGoods.max)
    local count = math.min(n, math.random(lo, hi))
    local pool = {}
    for i = 1, n do pool[i] = i end
    for i = 1, count do
        local j = math.random(i, n)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local picked = {}
    for i = 1, count do picked[i] = pool[i] end
    table.sort(picked)
    return picked
end

function NewCasket(ctx, contract)
    return {
        owner = ctx.charId,
        ownerSrc = ctx.src,
        lastActive = os.time(),
        closed = false,
        wanted = rollGoods(),
        laid = {},
        contractId = contract and contract.id or nil,
        deceased = contract and contract.name or L('unknownSoul'),
        cause = contract and contract.cause or '',
    }
end

function PublicState(key)
    local c = Tables[key] and Tables[key].casket
    if not c then return { state = 'empty' } end
    local laid = {}
    for _, idx in ipairs(c.wanted) do
        if c.laid[idx] then laid[#laid + 1] = idx end
    end
    return {
        state = c.closed and 'closed' or 'open',
        owner = c.owner,
        wanted = c.wanted,
        laid = laid,
        deceased = c.deceased,
    }
end

function AllPublicStates()
    local out = {}
    for key in pairs(Config.Tables) do out[key] = PublicState(key) end
    return out
end

function BroadcastTable(key)
    TriggerClientEvent('pup_mortician:table', -1, key, PublicState(key))
end

function FreeTable(key, why)
    local t = Tables[key]
    if not t or not t.casket then return end
    Dbg('freeing table', key, why)
    t.casket = nil
    BroadcastTable(key)
end

-- expiry is applied on every look-up AND by a sweep (main.lua)
function ExpireCheck(key)
    local c = Tables[key] and Tables[key].casket
    if c and os.time() - c.lastActive >= Config.AbandonMinutes * 60 then
        FreeTable(key, 'abandoned')
        return true
    end
    return false
end

function ExpireAll()
    for key in pairs(Tables) do ExpireCheck(key) end
end

-- frees every casket the character owns; returns true if any
function FreeCasketsOf(charId)
    local any = false
    for key, t in pairs(Tables) do
        if t.casket and t.casket.owner == charId then
            FreeTable(key, 'owner gone')
            any = true
        end
    end
    return any
end

function CasketOwnedBy(charId)
    for key, t in pairs(Tables) do
        if t.casket and t.casket.owner == charId then return key, t.casket end
    end
    return nil
end

function GoodLabels(c)
    local labels = {}
    for _, idx in ipairs(c.wanted) do
        if c.laid[idx] then labels[#labels + 1] = Config.Goods[idx].label end
    end
    return labels
end
