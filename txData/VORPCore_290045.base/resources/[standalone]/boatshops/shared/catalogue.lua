-- boatshops | resolves the config into shops and lookups (shared)

Boat = {}

local CFG <const> = BoatConfig
local isServer <const> = IsDuplicityVersion and IsDuplicityVersion() or false

local function warn(msg)
    print(('^3[boatshops] config:^7 %s'):format(msg))
end

local function copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- fields a shop leaves out come from the defaults; tables merge one level deep
local function withDefaults(shop)
    local out = copy(CFG.ShopDefaults)
    for k, v in pairs(shop) do
        if type(v) == 'table' and type(out[k]) == 'table' and k ~= 'boats' and k ~= 'jobs' and k ~= 'overrides' then
            for k2, v2 in pairs(v) do out[k][k2] = copy(v2) end
        else
            out[k] = copy(v)
        end
    end
    return out
end

local function boatKeys(id, boats)
    if type(boats) == 'string' then
        local set = CFG.Sets[boats]
        if not set then
            warn(('shop %s: unknown boat set "%s"'):format(id, boats))
            return {}
        end
        return set
    end
    if type(boats) == 'table' then return boats end
    return {}
end

Boat.shops = {}
do
    for id, raw in pairs(CFG.Shops) do
        local shop = withDefaults(raw)
        -- shop.boats is replaced by the resolved list, so read the raw value first
        local rawBoats = shop.boats
        shop.id = id
        shop.prompt = shop.prompt or shop.name
        shop.blip.name = shop.blip.name or shop.name
        shop.park = shop.park or shop.launch
        shop.exit = shop.exit or shop.counter
        shop.boats, shop.byKey = {}, {}
        for _, key in ipairs(boatKeys(id, rawBoats)) do
            local base = CFG.Boats[key]
            if not base then
                warn(('shop %s: unknown boat "%s"'):format(id, tostring(key)))
            else
                local entry = copy(base)
                entry.key = key
                for k, v in pairs((shop.overrides or {})[key] or {}) do entry[k] = copy(v) end
                entry.buy = math.floor(tonumber(entry.buy) or 0)
                entry.sell = math.floor(tonumber(entry.sell) or 0)
                shop.boats[#shop.boats + 1] = entry
                shop.byKey[key:lower()] = entry
            end
        end
        if not shop.counter or not shop.launch then
            warn(('shop %s: counter and launch are required, shop skipped'):format(id))
        else
            Boat.shops[id] = shop
        end
    end
end

-- the shop's entry for a boat key (case does not matter), or nil
function Boat.entry(shop, key)
    if not shop or type(key) ~= 'string' then return nil end
    return shop.byKey[key:lower()]
end

function Boat.catalogue(key)
    if type(key) ~= 'string' then return nil end
    return CFG.Boats[key]
end

-- the largest slot count any shop sells this model with
local slotCache = {}
function Boat.storageSlots(key)
    if slotCache[key] then return slotCache[key] end
    local best = nil
    for _, shop in pairs(Boat.shops) do
        local e = Boat.entry(shop, key)
        local n = e and tonumber(e.slots)
        if n and (not best or n > best) then best = n end
    end
    if not best then
        local base = Boat.catalogue(key)
        best = base and tonumber(base.slots) or tonumber(CFG.Storage.fallbackSlots) or 30
    end
    slotCache[key] = best
    return best
end

function Boat.options(category, key)
    local byModel = CFG.Upgrades[category]
    if not byModel or type(key) ~= 'string' then return nil end
    local list = byModel[key]
    if type(list) ~= 'table' or #list == 0 then return nil end
    return list
end

-- the listed option whose value matches (numbers and text compared as text)
function Boat.findOption(category, key, value)
    local list = Boat.options(category, key)
    if not list or value == nil then return nil end
    local want = tostring(value)
    for _, opt in ipairs(list) do
        if tostring(opt.value) == want then return opt end
    end
    return nil
end

function Boat.validCategory(category)
    for _, c in ipairs(CFG.Categories) do
        if c == category then return true end
    end
    return false
end

-- NULL, '{}', '[]' and broken text all mean nothing fitted
function Boat.decode(text)
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, t = pcall(json.decode, text)
    if not ok or type(t) ~= 'table' then return {} end
    local out = {}
    for _, c in ipairs(CFG.Categories) do
        if t[c] ~= nil then out[c] = t[c] end
    end
    return out
end

function Boat.inList(list, value)
    if type(list) ~= 'table' or value == nil then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- closed at or after the closing hour, or before the opening hour
function Boat.isClosed(shop, hour)
    local h = shop and shop.hours
    if not h or not h.enabled then return false end
    return hour >= h.close or hour < h.open
end

function Boat.money(n)
    n = tonumber(n) or 0
    if n == math.floor(n) then return ('%d'):format(n) end
    return ('%.2f'):format(n)
end

function Boat.debug(...)
    if CFG.General.debug then print('[boatshops]', ...) end
end

Boat.isServer = isServer
