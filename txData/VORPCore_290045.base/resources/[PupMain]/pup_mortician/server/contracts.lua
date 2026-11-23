-- pup_mortician | the contract board (server memory only)
-- A corpse only counts as a contract body when the server registered it for
-- that posting (TagBody); the client's state bag is never trusted on its own.

local CC = Config.Contracts

Boards = {}   -- key -> array of postings
Holders = {}  -- charId -> posting
local nextId = 0

for key in pairs(Config.Tables) do Boards[key] = {} end

local function pick(list)
    return list[math.random(1, #list)]
end

local function pointAround(anchor, minR, maxR)
    local a = math.random() * 2.0 * math.pi
    local r = minR + math.random() * (maxR - minR)
    return vector3(anchor.x + math.cos(a) * r, anchor.y + math.sin(a) * r, anchor.z)
end

-- returns pickup (vector3) and town name (or nil)
function ChoosePickup(key)
    local tbl = Config.Tables[key]
    if tbl.pickups and #tbl.pickups > 0 then
        return pick(tbl.pickups), nil
    end
    if CC.travel then
        local near = {}
        for _, town in ipairs(Config.Towns) do
            local d = Rules.Flat(town.pos, tbl.pos)
            if d >= CC.travelMin and d <= CC.travelMax then
                near[#near + 1] = { town = town, d = d }
            end
        end
        if #near > 0 then
            table.sort(near, function(a, b) return a.d < b.d end)
            local choice = near[math.random(1, math.min(CC.travelNearest, #near))].town
            return pointAround(choice.pos, CC.townSpreadMin, CC.townSpreadMax), choice.name
        end
    end
    return pointAround(tbl.pos, CC.localMin, CC.localMax), nil
end

local function newPosting(key)
    nextId = nextId + 1
    local female = math.random(1, 2) == 1
    local pickup, town = ChoosePickup(key)
    return {
        id = nextId,
        board = key,
        postedAt = os.time(),
        female = female,
        name = ('%s %s'):format(pick(female and CC.femaleNames or CC.maleNames), pick(CC.lastNames)),
        cause = pick(CC.causes),
        model = pick(female and CC.femaleModels or CC.maleModels),
        pickup = pickup,
        town = town,
        bodies = math.random(CC.bodiesMin, CC.bodiesMax),
        holder = nil,
        holderSrc = nil,
        deadline = nil,
        arrived = false,
        respots = 0,
        bodyEnts = {}, -- entity handle -> true, registered by the server only
    }
end

local function removeAt(key, i)
    local p = table.remove(Boards[key], i)
    if p and p.holder and Holders[p.holder] == p then
        Holders[p.holder] = nil
    end
    return p
end

-- removes a posting wherever it is; tells its holder
function RemovePosting(posting)
    local list = Boards[posting.board]
    if not list then return end
    for i, p in ipairs(list) do
        if p == posting then
            local src = p.holderSrc
            removeAt(posting.board, i)
            if src then PushStatus(src) end
            return
        end
    end
end

function PruneBoard(key)
    local list = Boards[key]
    local now = os.time()
    for i = #list, 1, -1 do
        local p = list[i]
        if p.holder then
            if p.deadline and now >= p.deadline then
                local src = p.holderSrc
                removeAt(key, i)
                if src then PushStatus(src) end
            end
        elseif now - p.postedAt >= CC.untakenMinutes * 60 then
            removeAt(key, i)
        end
    end
end

function FillBoard(key, upTo)
    local list = Boards[key]
    local added = 0
    while #list < CC.perBoard and added < upTo do
        list[#list + 1] = newPosting(key)
        added = added + 1
    end
end

function ReleasePostingOf(charId)
    local p = Holders[charId]
    if p then
        p.holderSrc = nil -- the holder is leaving; no status push to a stale source
        RemovePosting(p)
        return true
    end
    return false
end

-- what the holder (and only the holder) may know
function HolderView(posting)
    if not posting then return nil end
    local alive = 0
    for ent in pairs(posting.bodyEnts) do
        if DoesEntityExist(ent) then alive = alive + 1 else posting.bodyEnts[ent] = nil end
    end
    return {
        id = posting.id,
        board = posting.board,
        name = posting.name,
        cause = posting.cause,
        model = posting.model,
        pickup = { x = posting.pickup.x, y = posting.pickup.y, z = posting.pickup.z },
        town = posting.town,
        bodies = posting.bodies,
        registered = alive,
        arrived = posting.arrived,
        left = posting.deadline and math.max(0, posting.deadline - os.time()) or 0,
    }
end

-- the board as one viewer may see it
function BoardView(key, charId)
    PruneBoard(key)
    local out = {}
    for _, p in ipairs(Boards[key]) do
        local mine = p.holder == charId
        out[#out + 1] = {
            id = p.id,
            name = p.name,
            cause = p.cause,
            bodies = p.bodies,
            town = CC.travel and p.town or nil,
            mine = mine,
            taken = p.holder ~= nil,
            left = mine and p.deadline and math.max(0, p.deadline - os.time()) or nil,
        }
    end
    return out
end

-- the posting a corpse delivers to, if it is a real contract body for this character
function ContractBodyOf(charId, ent)
    local p = Holders[charId]
    if not p or not p.arrived or not p.bodyEnts[ent] then return nil end
    local tag = Entity(ent).state.undertakerContract
    if tag ~= nil and tonumber(tag) ~= p.id then return nil end
    return p
end

function DeliverContractBody(posting, ent)
    posting.bodyEnts[ent] = nil
    posting.bodies = posting.bodies - 1
    if posting.bodies <= 0 then
        RemovePosting(posting)
    elseif posting.holderSrc then
        PushStatus(posting.holderSrc)
    end
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
Actions = Actions or {}

Actions.take = function(ctx, p)
    if not CC.enabled then return { ok = false, msg = L('contractsOff') } end
    local key = ValidTableKey(p.key)
    if not key or not Rules.CanWorkTable(ctx.job, key) then return { ok = false, msg = L('notYourTable') } end
    if DistTo(ctx.src, Config.Tables[key].pos) > Config.Distance.tableServer then return { ok = false, msg = L('tooFar') } end
    if Holders[ctx.charId] then return { ok = false, msg = L('alreadyContract') } end
    PruneBoard(key)
    local id = tonumber(p.id)
    local posting
    for _, q in ipairs(Boards[key]) do
        if q.id == id then posting = q break end
    end
    if not posting or posting.holder then return { ok = false, msg = L('postingGone') } end
    posting.holder = ctx.charId
    posting.holderSrc = ctx.src
    posting.deadline = os.time() + CC.deadlineMinutes * 60
    Holders[ctx.charId] = posting
    return { ok = true, msg = L('tookContract', posting.name), posting = HolderView(posting) }
end

Actions.giveup = function(ctx, _)
    local posting = Holders[ctx.charId]
    if not posting then return { ok = false, msg = L('postingGone') } end
    posting.holderSrc = nil
    RemovePosting(posting)
    return { ok = true, msg = L('gaveUp') }
end

Actions.arrive = function(ctx, _)
    local posting = Holders[ctx.charId]
    if not posting or not posting.pickup then return { ok = false, quiet = true } end
    if posting.arrived then return { ok = true, quiet = true, posting = HolderView(posting) } end
    if DistTo(ctx.src, posting.pickup) > CC.arriveServer then return { ok = false, quiet = true } end
    posting.arrived = true
    return { ok = true, msg = L('foundThem'), posting = HolderView(posting) }
end

local lastRespot = {}

Actions.respot = function(ctx, _)
    local now = os.time()
    if lastRespot[ctx.charId] and now - lastRespot[ctx.charId] < CC.respotThrottle then
        return { ok = false, quiet = true }
    end
    lastRespot[ctx.charId] = now
    local posting = Holders[ctx.charId]
    if not posting or posting.arrived then return { ok = false, quiet = true } end
    if posting.respots >= CC.maxRespots then
        return { ok = false, msg = L('noPlace') }
    end
    posting.respots = posting.respots + 1
    posting.pickup, posting.town = ChoosePickup(posting.board)
    -- bodies spawned at the old spot no longer count
    posting.bodyEnts = {}
    return { ok = true, quiet = true, posting = HolderView(posting) }
end

-- the client spawned a body for its posting; the server checks it and tags it
Actions.tagBody = function(ctx, p)
    local posting = Holders[ctx.charId]
    if not posting then return { ok = false, quiet = true } end
    local ent = NetworkGetEntityFromNetworkId(tonumber(p.net) or -1)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return { ok = false, quiet = true, retry = true } end
    if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return { ok = false, quiet = true } end
    -- compare as unsigned: the server and joaat may disagree on the sign
    local model = math.tointeger(GetEntityModel(ent)) or 0
    if (model & 0xFFFFFFFF) ~= (joaat(posting.model) & 0xFFFFFFFF) then return { ok = false, quiet = true } end
    if #(GetEntityCoords(ent) - posting.pickup) > CC.spawnRange then return { ok = false, quiet = true } end
    if DistTo(ctx.src, posting.pickup) > CC.spawnRange + 30.0 then return { ok = false, quiet = true } end
    if posting.bodyEnts[ent] then return { ok = true, quiet = true } end
    local alive = 0
    for e in pairs(posting.bodyEnts) do
        if DoesEntityExist(e) then alive = alive + 1 else posting.bodyEnts[e] = nil end
    end
    if alive >= posting.bodies then return { ok = false, quiet = true } end
    posting.bodyEnts[ent] = true
    Entity(ent).state:set('undertakerContract', posting.id, true)
    return { ok = true, quiet = true }
end

-- start: fill every board; then every refill period prune and add ONE posting
CreateThread(function()
    if not CC.enabled then return end
    for key in pairs(Boards) do FillBoard(key, CC.perBoard) end
    while true do
        Wait(CC.refillMinutes * 60 * 1000)
        for key in pairs(Boards) do
            PruneBoard(key)
            FillBoard(key, 1)
        end
    end
end)

function ForgetRespot(charId)
    lastRespot[charId] = nil
end
