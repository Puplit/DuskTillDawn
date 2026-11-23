-- pup_camps | server core: state, request routing, player context, camp helpers

VCore = exports.vorp_core:GetCore()

Camps   = {}   -- [campId] = camp (memory is authoritative)
Players = {}   -- [src] = { charid, name, identifier }
Ready   = false

local RES <const> = GetCurrentResourceName()

------------------------------------------------------------------------------ requests
-- Client -> server goes through one net event. Every handler gets a validated context
-- (source + used character); nothing the client sends is trusted beyond its shape.

local handlers = {}
local buckets  = {}   -- [src] = { t, n }
local BUCKET_WINDOW <const> = 3000
local BUCKET_MAX    <const> = 25

function Handle(name, fn, opts)
    handlers[name] = { fn = fn, opts = opts or {} }
end

local function allowed(src)
    local now = GetGameTimer()
    local b = buckets[src]
    if not b or now - b.t > BUCKET_WINDOW then
        buckets[src] = { t = now, n = 1 }
        return true
    end
    b.n = b.n + 1
    if b.n == BUCKET_MAX + 1 then
        print(('^3[pup_camps]^7 request flood from %s [%d] - dropping for a moment'):format(GetPlayerName(src) or '?', src))
    end
    return b.n <= BUCKET_MAX
end

local perCall = {}    -- [src] = { [name] = last }

-- forget a player's rate-limit memory (disconnect)
function RequestsForget(src)
    perCall[src] = nil
    buckets[src] = nil
end

local function reply(src, token, ...)
    if token then TriggerClientEvent('pup_camps:cl:reply', src, token, ...) end
end

RegisterNetEvent('pup_camps:sv:req', function(token, name, ...)
    local src = source
    if type(name) ~= 'string' then return end
    if token ~= nil and type(token) ~= 'number' then return end
    local h = handlers[name]
    if not h or not Ready then return reply(src, token, nil) end
    if not allowed(src) then return reply(src, token, nil) end

    if h.opts.gapMs then
        perCall[src] = perCall[src] or {}
        local last = perCall[src][name]
        local now = GetGameTimer()
        if last and now - last < h.opts.gapMs then return reply(src, token, nil) end
        perCall[src][name] = now
    end

    local ctx = Ctx(src)
    if not ctx then return reply(src, token, nil) end

    local ok, a, b = pcall(h.fn, ctx, ...)
    if not ok then
        print(('^1[pup_camps]^7 request %s failed: %s'):format(name, tostring(a)))
        return reply(src, token, nil)
    end
    reply(src, token, a, b)
end)

------------------------------------------------------------------------------ players

local function charOf(src)
    local user = VCore.getUser(src)
    return user and user.getUsedCharacter or nil
end
CharOf = charOf

function FullName(ch)
    return U.trim(('%s %s'):format(tostring(ch.firstname or ''), tostring(ch.lastname or '')))
end

-- validated context for a source, or nil. Detects a character switch and cleans up.
function Ctx(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return nil end
    local ch = charOf(src)
    if not ch or not ch.charIdentifier then return nil end
    local charid = tonumber(ch.charIdentifier)
    local p = Players[src]
    if p and p.charid ~= charid then
        PlayerLeft(src, 'switch')
        p = nil
    end
    if not p then
        p = { charid = charid }
        Players[src] = p
    end
    p.name = FullName(ch)
    p.identifier = ch.identifier
    local camp = CampOfChar(charid, ch.identifier)
    return { src = src, char = ch, charid = charid, name = p.name, identifier = ch.identifier, camp = camp }
end

function SrcOfChar(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for src, p in pairs(Players) do
        if p.charid == charid and GetPlayerName(src) then return src end
    end
    return nil
end

-- server-side player position; nil when the server cannot see it (no OneSync)
function PlayerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) then return nil end
    return { x = c.x, y = c.y, z = c.z }
end

function Notify(src, msg, ms)
    if src then VCore.NotifyRightTip(src, msg, ms or 5000) end
end

function NotifyBottom(src, msg, ms)
    if src then VCore.NotifyObjective(src, msg, ms or 8000) end
end

function Money(ctx)
    return tonumber(ctx.char.money) or 0
end

function TakeCash(ctx, amount)
    if amount <= 0 then return true end
    -- re-read the live character: the context may be from before an await
    local ch = charOf(ctx.src)
    if not ch or tonumber(ch.charIdentifier) ~= ctx.charid then return false end
    if (tonumber(ch.money) or 0) < amount then return false end
    ch.removeCurrency(0, amount)
    return true
end

function GiveCash(ctx, amount)
    if amount <= 0 then return true end
    local ch = charOf(ctx.src)
    if not ch or tonumber(ch.charIdentifier) ~= ctx.charid then return false end
    ch.addCurrency(0, amount)
    return true
end

function IsStaff(src)
    if src == 0 then return true end
    local ch = charOf(src)
    return ch ~= nil and ch.group == 'admin'
end

------------------------------------------------------------------------------ camps

function CampOfChar(charid, identifier)
    for id, camp in pairs(Camps) do
        if FindMember(camp, charid, identifier) then return id end
    end
    return nil
end

-- index and entry of a member; legacy rows may hold an identifier string instead of a char id
function FindMember(camp, charid, identifier)
    charid = tonumber(charid)
    for i, m in ipairs(camp.members) do
        if charid and tonumber(m.charid) == charid then return i, m end
    end
    if identifier then
        for i, m in ipairs(camp.members) do
            if type(m.charid) == 'string' and tonumber(m.charid) == nil and m.charid == identifier then
                -- upgrade the legacy entry to this character on first sight
                m.charid = charid
                Save(camp)
                return i, m
            end
        end
    end
    return nil
end

function IsLeader(camp, charid)
    return tonumber(camp.leader) ~= nil and tonumber(camp.leader) == tonumber(charid)
end

-- rank id and leader flag of a character in a camp (nil when not a member and not leader)
function RankOf(camp, charid, identifier)
    local leader = IsLeader(camp, charid)
    local _, m = FindMember(camp, charid, identifier)
    if not m and not leader then return nil, false end
    local r = m and m.rank
    if not U.validRank(r) then r = Config.Ranks[1].id end
    return r, leader
end

function MemberCount(camp)
    return #camp.members
end

function CampFull(camp)
    local max = Config.Camp.maxMembers
    return max and max > 0 and #camp.members >= max
end

function CampRadius()
    return Config.Camp.furnitureRadius + Config.Camp.atCampSlack
end

function AtCamp(src, camp)
    local pos = PlayerPos(src)
    if not pos then return true end
    return U.dist3(pos, camp.coords) <= CampRadius()
end

function NearPoint(src, point, dist, flat)
    local pos = PlayerPos(src)
    if not pos then return true end
    if flat then return U.dist2(pos, point) <= dist end
    return U.dist3(pos, point) <= dist
end

-- Can this context do `action` at its own camp? Returns camp or nil, message.
-- opts.allowRepo  : action allowed on a shut-down camp (tax deposit)
-- opts.noDistance : skip the at-camp check
function Can(ctx, campId, action, opts)
    opts = opts or {}
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return nil, L('not_member') end
    local rank, leader = RankOf(camp, ctx.charid, ctx.identifier)
    if not rank and not leader then return nil, L('not_member') end
    if camp.repo and not opts.allowRepo then return nil, L('camp_shut') end
    if action then
        local need = Config.Permissions[action] or 'leader'
        if not U.meets(rank, leader, need) then
            return nil, L('rank_too_low', U.rankLabel(need))
        end
    end
    if not opts.noDistance and not AtCamp(ctx.src, camp) then return nil, L('too_far') end
    return camp
end

-- pay a camp purchase: the safe when it covers the whole price, else the player
function PayFromSafeOrPlayer(ctx, camp, price)
    if price <= 0 then return 'free' end
    if camp.cash >= price then
        camp.cash = U.round(camp.cash - price, 2)
        return 'safe'
    end
    if TakeCash(ctx, price) then return 'player' end
    return nil
end

function CampTitle(camp)
    if camp.name and camp.name ~= '' then return ('%s (Camp #%d)'):format(camp.name, camp.id) end
    return ('Camp #%d'):format(camp.id)
end

function OnlineMembers(camp)
    local out = {}
    for _, m in ipairs(camp.members) do
        local s = SrcOfChar(m.charid)
        if s then out[#out + 1] = s end
    end
    local ls = SrcOfChar(camp.leader)
    if ls then
        local dup = false
        for _, s in ipairs(out) do if s == ls then dup = true break end end
        if not dup then out[#out + 1] = ls end
    end
    return out
end

-- storage capacity: admin override, else the largest storage piece (placed or not)
function RecomputeStorage(camp)
    if camp.invoverride then
        camp.invlimit = camp.invoverride
        return
    end
    local best = 0
    for _, p in pairs(camp.furni) do
        if p.functional == 'inv' then
            local def = CampFurniture[p.item]
            local slots = def and tonumber(def.slots) or 0
            if slots > best then best = slots end
        end
    end
    camp.invlimit = best
end

function NextPieceId(camp)
    local top = 0
    for id in pairs(camp.furni) do if id > top then top = id end end
    return top + 1
end

------------------------------------------------------------------------------ client views

function LootAllowed(camp, src, charid)
    local open = RaidOpen and RaidOpen[camp.id]
    if not open or os.time() >= open.untilTime then return false end
    if charid and open.chars[charid] then return true end
    if open.posseId and Integrations.running('pup-ui') then
        local ok, p = pcall(function() return exports['pup-ui']:GetPosse(src) end)
        if ok and type(p) == 'table' and p.inPosse and p.id == open.posseId then return true end
    end
    return false
end

function PieceView(p)
    return {
        id = p.id, item = p.item, prop = p.prop, label = p.label, cata = p.cata,
        functional = p.functional, active = p.active == true, grounded = p.grounded == true,
        coords = p.coords, heading = p.heading,
    }
end

-- what one player may know about one camp
function View(camp, src)
    local p = Players[src]
    local charid = p and p.charid
    local rank, leader = nil, false
    if charid then rank, leader = RankOf(camp, charid, p.identifier) end
    local member = rank ~= nil or leader
    local loot = (not member) and charid and LootAllowed(camp, src, charid) or false

    local furni = {}
    for _, piece in pairs(camp.furni) do furni[#furni + 1] = PieceView(piece) end

    local v = {
        id = camp.id, name = camp.name, bcolor = camp.bcolor, coords = camp.coords,
        leader = camp.leader, repo = camp.repo, raid = camp.raid, lifecycle = camp.lifecycle,
        invlimit = camp.invlimit, maxstock = camp.maxstock, hwagon = camp.hwagon,
        furni = furni, haswebhook = (camp.webhook ~= nil and camp.webhook ~= ''),
        memberCount = #camp.members,
        member = member, rank = rank, isLeader = leader, loot = loot,
        tax = 0, cash = nil,
    }
    if member then
        v.members = {}
        for _, m in ipairs(camp.members) do
            v.members[#v.members + 1] = { name = m.name, charid = m.charid, rank = U.validRank(m.rank) and m.rank or Config.Ranks[1].id }
        end
        v.tax = camp.taxmoney
        v.cash = camp.cash
        v.stewlevel = camp.stewlevel
        v.material = camp.material
        v.stock = camp.stock
        v.supply = camp.supply
    elseif loot then
        v.cash = camp.cash
    end
    return v
end

function PushCamp(camp, rebuild)
    for src, p in pairs(Players) do
        if p.started then
            TriggerClientEvent('pup_camps:cl:camp', src, View(camp, src), rebuild == true)
        end
    end
end

function PushCampTo(src, camp, rebuild)
    local p = Players[src]
    if p and p.started then
        TriggerClientEvent('pup_camps:cl:camp', src, View(camp, src), rebuild == true)
    end
end

function PushGone(campId)
    for src, p in pairs(Players) do
        if p.started then TriggerClientEvent('pup_camps:cl:campGone', src, campId) end
    end
end

-- tell a player their own camp id changed
function PushMyCamp(src)
    local p = Players[src]
    if not p or not p.started then return end
    local camp = CampOfChar(p.charid, p.identifier)
    TriggerClientEvent('pup_camps:cl:myCamp', src, camp or 0)
end

------------------------------------------------------------------------------ menu locks

MenuLocks = {}   -- [campId] = src

function LockFree(campId, src)
    local holder = MenuLocks[campId]
    if not holder or holder == src then return true end
    if not GetPlayerName(holder) then MenuLocks[campId] = nil return true end
    return false
end

function ReleaseLocksOf(src)
    for id, holder in pairs(MenuLocks) do
        if holder == src then MenuLocks[id] = nil end
    end
end

------------------------------------------------------------------------------ misc

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    SaveAllNow()
end)
