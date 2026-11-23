-- Start-up, the single request entry point for clients, and player lifecycle.

-- RATE LIMITS
local RATE_WINDOW_MS <const> = 5000
local RATE_MAX <const> = 30
local HEAVY <const> = {
    start = true, finish = true, cancel = true, collect = true, collectAll = true,
    openBox = true, place = true, pickup = true, favs = true,
}
local HEAVY_GAP_MS <const> = 400

local rate = {}   -- src -> { winStart, n, last = { kind -> ms } }
local busy = {}   -- src -> true while a heavy request is running

local function allowed(src, kind)
    local now = GetGameTimer()
    local s = rate[src]
    if not s then
        s = { winStart = now, n = 0, last = {} }
        rate[src] = s
    end
    if now - s.winStart > RATE_WINDOW_MS then
        s.winStart, s.n = now, 0
    end
    s.n = s.n + 1
    if s.n > RATE_MAX then return false end
    if HEAVY[kind] then
        if s.last[kind] and now - s.last[kind] < HEAVY_GAP_MS then return false end
        s.last[kind] = now
    end
    return true
end

-- REQUEST HANDLERS: each gets (src, who, payload) and returns the answer
local Handlers = {}

function Handlers.hello(_, who)
    return { charid = who.charid, stations = Stations.clientList() }
end

function Handlers.open(src, who)
    local xp = Progress.getXp(who.charid)
    local favs = Progress.getFavourites(who.charid)
    local pending = Craft.pending(who.charid)
    local now = Who(src)
    if not now or now.charid ~= who.charid then return nil end
    return {
        recipes = Recipes.viewFor(who, xp),
        xp = xp,
        thresholds = Recipes.thresholds(),
        favourites = favs,
        pending = pending,
        now = os.time(),
        timed = Config.Timed.enabled,
        box = Config.Box.enabled,
    }
end

function Handlers.counts(src, _, payload)
    if type(payload) ~= 'table' then return { ok = true, counts = {} } end
    local out, n = {}, 0
    for _, name in ipairs(payload) do
        -- only names some recipe uses: arbitrary names would flood vorp_inventory's warnings
        if type(name) == 'string' and out[name] == nil and Recipes.isCountable(name) then
            n = n + 1
            if n > 400 then break end
            out[name] = tonumber(Inv:getItemCount(src, nil, name)) or 0
        end
    end
    return { ok = true, counts = out }
end

function Handlers.favs(_, who, payload)
    return { ok = true, list = Progress.saveFavourites(who.charid, payload) }
end

function Handlers.pending(_, who)
    return { list = Craft.pending(who.charid), now = os.time() }
end

function Handlers.collect(src, who, payload)
    return Craft.collect(src, who, payload)
end

function Handlers.collectAll(src, who)
    return Craft.collectAll(src, who)
end

function Handlers.openBox(src, who)
    if not Config.Box.enabled then return { ok = false, msg = L('cannot_craft') } end
    local ok, msg = Box.open(src, who)
    return { ok = ok, msg = msg }
end

function Handlers.start(src, who, payload)
    return Craft.start(src, who, payload)
end

function Handlers.finish(src, who, payload)
    return Craft.finish(src, who, payload)
end

function Handlers.cancel(src, _, payload)
    return Craft.cancel(src, payload)
end

function Handlers.place(src, who, payload)
    return Placeables.place(src, who, payload)
end

function Handlers.pickup(src, who)
    return Placeables.pickup(src, who)
end

Core.Callback.Register('pup_workbench:req', function(source, cb, kind, payload)
    local src = tonumber(source)
    if not Server.ready or not src then return cb(nil) end
    local handler = type(kind) == 'string' and Handlers[kind] or nil
    if not handler then return cb(nil) end
    local who = Who(src)
    if not who then return cb(nil) end
    if not allowed(src, kind) then return cb({ ok = false, msg = L('slow_down') }) end
    if HEAVY[kind] then
        if busy[src] then return cb({ ok = false, msg = L('busy') }) end
        busy[src] = true
    end
    local ok, res = pcall(handler, src, who, payload)
    if HEAVY[kind] then busy[src] = nil end
    if not ok then
        print(('^1[pup_workbench]^7 request %s from %d failed: %s'):format(kind, src, tostring(res)))
        return cb({ ok = false, msg = L('cannot_craft') })
    end
    cb(res)
end)

-- START-UP
local function registerUsables()
    while GetResourceState('vorp_inventory') ~= 'started' do Wait(1000) end
    Placeables.registerItems()
end

local function startup()
    local began = GetGameTimer()
    math.randomseed(os.time() + GetGameTimer())
    DB.ensureSchema()
    local ok, err = pcall(Recipes.seedIfEmpty)
    if not ok then Warn('recipe seed failed: %s', tostring(err)) end
    ok, err = pcall(Stations.seedIfEmpty)
    if not ok then Warn('station seed failed: %s', tostring(err)) end
    Recipes.load()
    Stations.load()
    ok, err = pcall(Progress.migrateFavourites)
    if not ok then Warn('favourites migration failed: %s', tostring(err)) end
    Recipes.addMissingItems()

    if Config.Box.enabled and Config.Box.wipeOnStart then
        local left = Config.Box.wipeDelayMs - (GetGameTimer() - began)
        if left > 0 then Wait(left) end
        while GetResourceState('vorp_inventory') ~= 'started' do Wait(1000) end
        Box.wipeAll()
    end

    Server.ready = true
    Stations.pushTo(-1)
    print(('[pup_workbench] ready: %d recipes%s, %d stations')
        :format(#Recipes.list, Recipes.fromConfig and ' (config list)' or '', #Stations.active))
    registerUsables()
end

MySQL.ready(function()
    CreateThread(startup)
end)

AddEventHandler('onServerResourceStart', function(res)
    if res == 'vorp_inventory' and Server.ready then
        SetTimeout(2000, Placeables.registerItems)
    end
end)

-- CHARACTER SELECT
AddEventHandler('vorp:SelectedCharacter', function(source)
    local src = tonumber(source)
    if not src then return end
    Craft.dropPlayer(src) -- tokens belong to the previous character
    SetTimeout(4000, function()
        if not Server.ready then return end
        local who = Who(src)
        if not who then return end
        local ok, err = pcall(MoveDeadLocks, who)
        if not ok then Warn('lock move failed for %d: %s', who.charid, tostring(err)) end
        ok, err = pcall(RegisterLockOwner, who)
        if not ok then Warn('lock owner register failed for %d: %s', who.charid, tostring(err)) end
        Stations.pushTo(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Craft.dropPlayer(src)
    Placeables.dropPlayer(src)
    rate[src] = nil
    busy[src] = nil
end)
