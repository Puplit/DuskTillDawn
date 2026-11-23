-- pup_clothing | server: every price, every check and every write is decided here.

local U, Cat, DB = PC.U, PC.Cat, PC.DB
local Core = exports.vorp_core:GetCore()

local sessions = {} -- [src] = { kind = 'store'|'wardrobe', loc = index|nil, charId, free = bool }
local passes   = {} -- [src] = charId holding an unused free starter fitting
local busy     = {} -- [src] = true while a purchase or outfit change runs
local lastCall = {} -- [src] = { [kind] = GetGameTimer() }
local deferred = {} -- [src] = { [kind] = true } when one late call is waiting
local charLocks = {} -- [charId] = true while that character's extras row is being rewritten

local function dbg(fmt, ...)
    if Config.Debug.server then print(('^5[pup_clothing]^7 ' .. fmt):format(...)) end
end

local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[pup_clothing]^7 %s'):format(msg))
end

local function tip(src, text)
    Core.NotifyRightTip(src, text, 4000)
end

---------------------------------------------------------------------------
-- players and characters
---------------------------------------------------------------------------
local function validSource(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if not GetPlayerName(src) then return nil end
    return src
end

local function getChar(src)
    local ok, user = pcall(Core.getUser, src)
    if not ok or not user then return nil end
    local c = user.getUsedCharacter
    if type(c) ~= 'table' or not tonumber(c.charIdentifier) then return nil end
    return c
end

local function looksLocked(c)
    -- a function from another resource (vorp_core) arrives as a callable table, not a 'function'
    local kind = type(c.appearanceLocked)
    if kind ~= 'function' and kind ~= 'table' then
        warnOnce('lock', 'vorp_core has no appearanceLocked(); purchases are not blocked during a disguise')
        return false
    end
    local ok, v = pcall(c.appearanceLocked)
    return ok and v == true
end

local function skinOf(c)
    if type(c.skin) == 'table' then return c.skin end
    return U.decodeObject(c.skin) or {}
end

local function sexOf(c)
    local s = skinOf(c).sex
    if s == 'mp_male' then return 'male' end
    if s == 'mp_female' then return 'female' end
    return nil
end

local function compsString(c)
    local v = c.comps
    if type(v) == 'table' then return U.encodeObject(v) end
    if type(v) ~= 'string' or v == '' then return '{}' end
    return v
end

-- per-player throttle. When a call comes too soon, `later` (if given) runs once after the gap instead.
local function allow(src, kind, later)
    local gap = Config.Server.rate[kind] or 500
    local now = GetGameTimer()
    local t = lastCall[src]
    if not t then
        t = {}
        lastCall[src] = t
    end
    if t[kind] and now - t[kind] < gap then
        if later then
            local d = deferred[src]
            if not d then
                d = {}
                deferred[src] = d
            end
            if not d[kind] then
                d[kind] = true
                SetTimeout(gap - (now - t[kind]), function()
                    if deferred[src] then deferred[src][kind] = nil end
                    if not GetPlayerName(src) then return end
                    lastCall[src] = lastCall[src] or {}
                    lastCall[src][kind] = GetGameTimer()
                    later()
                end)
            end
        end
        return false
    end
    t[kind] = now
    return true
end

-- one rewrite of a character's extras row at a time
local function withCharLock(charId, fn)
    local waited = 0
    while charLocks[charId] and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    charLocks[charId] = true
    local ok, err = pcall(fn)
    charLocks[charId] = nil
    if not ok then print(('^1[pup_clothing]^7 %s'):format(tostring(err))) end
end

---------------------------------------------------------------------------
-- locations
---------------------------------------------------------------------------
local function playerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local p = GetEntityCoords(ped)
    if not p or (p.x == 0.0 and p.y == 0.0 and p.z == 0.0) then return nil end
    return p
end

local function reachOf(pt)
    return (pt.tight and Config.Prompt.tightRadius or Config.Prompt.radius) + Config.Server.reach
end

local function distTo(pos, pt)
    local dx, dy, dz = pos.x - pt.x, pos.y - pt.y, pos.z - pt.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- index of the point the player stands at; 0 when the check is off or the position is unknown and allowed
local function pointAt(src, list)
    if not Config.Server.requireLocation then return 0 end
    local pos = playerPos(src)
    if not pos then return Config.Server.passUnknownPosition and 0 or nil end
    local best, bestD = nil, nil
    for i, pt in ipairs(list) do
        if pt.enabled ~= false then
            local d = distTo(pos, pt)
            if d <= reachOf(pt) and (not bestD or d < bestD) then
                best, bestD = i, d
            end
        end
    end
    return best
end

local function stillAt(src, list, idx)
    if not Config.Server.requireLocation or not idx or idx == 0 then return true end
    local pos = playerPos(src)
    if not pos then return Config.Server.passUnknownPosition end
    local pt = list[idx]
    return pt ~= nil and distTo(pos, pt) <= reachOf(pt)
end

local function sessionOk(src, kind, c)
    local s = sessions[src]
    if not s or s.kind ~= kind or s.charId ~= c.charIdentifier then return nil end
    if s.free then return s end
    local list = kind == 'store' and Config.Stores or Config.Wardrobes
    if not stillAt(src, list, s.loc) then
        tip(src, L('notHere'))
        return nil
    end
    return s
end

---------------------------------------------------------------------------
-- clothes and extras rules
---------------------------------------------------------------------------
local maleForce = {}
for _, slot in ipairs(Config.Store.maleForceNone) do maleForce[slot] = true end

-- validate the store's clothes map. Every value must be a catalogue garment of this sex in that
-- category, or -1. Returns the clean map or nil.
local function cleanClothes(t, sex)
    local out, n = {}, 0
    for k, v in pairs(t) do
        n = n + 1
        if n > 256 or not U.validCatKey(k, Config.Server.syncKeyMax) then return nil end
        local cat = Cat.categoryOf(k)
        local num = U.int(v)
        if num == nil then return nil end
        if num == -1 or num == 0 then
            out[k] = -1
        elseif Cat.fits(num, sex, cat) then
            out[k] = U.u32(num)
        else
            dbg('refused garment %s in %s (sex %s)', tostring(v), k, tostring(sex))
            return nil
        end
        if sex == 'male' and maleForce[k] then out[k] = -1 end
    end
    return out
end

local function tintPrice(cat)
    return tonumber(Config.Tints.prices[cat]) or tonumber(Config.Tints.defaultPrice) or 0
end

local function sameColour(a, b)
    if not a or not b or (a.p or 0) ~= (b.p or 0) then return false end
    local ac, bc = a.c or {}, b.c or {}
    return (ac[1] or 0) == (bc[1] or 0) and (ac[2] or 0) == (bc[2] or 0) and (ac[3] or 0) == (bc[3] or 0)
end

local function extrasOpts()
    return {
        keyMax = Config.Server.syncKeyMax, paletteCount = #Config.Palettes,
        chanMax = Config.Tints.channelMax, maxSlots = Config.Server.extrasMaxSlots,
    }
end

local function slotIsNone(clothes, cat)
    local v = clothes[Cat.slotName(cat)]
    if v == nil then v = clothes[cat] end
    return v == nil or v == -1
end

-- the store's extras map, made safe: singleplayer garments only when the store offers them and the
-- garment really is one; colours only while tints are on and only on a garment that is worn
local function cleanPurchaseExtras(raw, clothes, sex)
    local ex, n = U.cleanExtras(raw, extrasOpts())
    if not ex then return nil end
    local out = {}
    for cat, e in pairs(ex) do
        if e.h ~= false then
            local row = Config.Npc.inStore and Cat.npcRow(sex, e.h) or nil
            if not (row and row.cat == cat) then e.h = false end
        end
        if not Config.Tints.enabled then
            e.p, e.c = 0, { 0, 0, 0 }
        elseif e.h == false and slotIsNone(clothes, cat) then
            e.p, e.c = 0, { 0, 0, 0 }
        end
        if e.h ~= false or e.p > 0 then out[cat] = e end
    end
    return out, n
end

-- non-catalogue garment hashes in compPlayer (pup_tailor's singleplayer pieces) carried into a new look
local function keepForeignSlots(newMap, oldMap)
    for k, v in pairs(oldMap) do
        local num = U.int(v)
        if num and num ~= -1 and num ~= 0 and not Cat.known(num) then
            if newMap[k] == nil or newMap[k] == -1 then newMap[k] = num end
        end
    end
end

---------------------------------------------------------------------------
-- store
---------------------------------------------------------------------------
local function sendStore(src, c, free)
    local skin = skinOf(c)
    local extras = DB.getExtras(c.charIdentifier)
    local now = getChar(src)
    if not now or now.charIdentifier ~= c.charIdentifier then return end
    TriggerClientEvent('pup_clothing:storeData', src, {
        comps = compsString(now),
        body = U.int(skin.BodyType) or 0,
        legs = U.int(skin.LegsType) or 0,
        extras = extras,
        price = Config.Store.price,
        free = free == true,
    })
end

RegisterNetEvent('pup_clothing:openStore', function()
    local src = validSource(source)
    if not src or not allow(src, 'open') then return end
    local c = getChar(src)
    if not c then return end
    if busy[src] then return end
    local idx = pointAt(src, Config.Stores)
    if not idx then return tip(src, L('notHere')) end
    local free = passes[src] == c.charIdentifier
    sessions[src] = { kind = 'store', loc = idx, charId = c.charIdentifier, free = free }
    sendStore(src, c, free)
end)

RegisterNetEvent('pup_clothing:closed', function()
    local src = validSource(source)
    if not src then return end
    if busy[src] then return end
    sessions[src] = nil
end)

RegisterNetEvent('pup_clothing:buy', function(clothesJson, outfitName, extrasJson)
    local src = validSource(source)
    if not src or not allow(src, 'buy') or busy[src] then return end
    -- the page is already shut; tell the client so it can undo the preview
    local function fail(why, ...)
        if why then dbg('buy from %d refused: ' .. why, src, ...) end
        sessions[src] = nil
        TriggerClientEvent('pup_clothing:buyFailed', src)
    end
    local c = getChar(src)
    if not c then return fail('no character') end
    local s = sessionOk(src, 'store', c)
    if not s then return fail('no open store') end

    local maxB = Config.Server.payloadMax
    local raw = U.decodeObject(clothesJson, maxB)
    if not raw then return fail('bad clothes payload') end
    local rawExtras = {}
    if extrasJson ~= nil and extrasJson ~= '' then
        rawExtras = U.decodeObject(extrasJson, maxB)
        if not rawExtras then return fail('bad extras payload') end
    end

    local sex = sexOf(c)
    local clothes = cleanClothes(raw, sex)
    if not clothes then return fail('garment not in the catalogue') end
    local extras = cleanPurchaseExtras(rawExtras, clothes, sex)
    if not extras then return fail('too many extras slots') end

    local title = nil
    if type(outfitName) == 'string' then
        local t = U.trim(outfitName)
        if t ~= '' then title = U.utf8Cut(t, Config.Outfits.titleMax) end
    end

    busy[src] = true
    local charId = c.charIdentifier
    withCharLock(charId, function()
        local savedExtras = U.decodeObject(DB.getExtras(charId)) or {}
        local outfitCount = title and DB.countOutfits(charId) or 0

        -- everything below runs after awaits: look again
        local now = getChar(src)
        if not now or now.charIdentifier ~= charId or sessions[src] ~= s then return fail('character changed') end
        if looksLocked(now) then
            fail()
            return tip(src, L('disguised'))
        end
        -- a full wardrobe still buys the clothes, it just does not keep the outfit
        local max = Config.Outfits.maxPerCharacter
        if title and max > 0 and outfitCount >= max then
            tip(src, L('outfitLimit', max))
            title = nil
        end

        local price = Config.Store.price
        if Config.Tints.enabled then
            for cat, e in pairs(extras) do
                if e.p > 0 and (Config.Tints.chargeUnchanged or not sameColour(e, savedExtras[cat])) then
                    price = price + tintPrice(cat)
                end
            end
        end
        local starter = passes[src] == charId
        if starter then price = 0 end

        if price > 0 and (tonumber(now.money) or 0) < price then
            fail()
            return tip(src, L('cantAfford', price))
        end

        if Config.Npc.keepTailorPieces then
            keepForeignSlots(clothes, U.decodeObject(compsString(now)) or {})
            for cat, e in pairs(savedExtras) do
                if extras[cat] == nil and type(e) == 'table' and e.h and e.h ~= false and slotIsNone(clothes, cat) then
                    extras[cat] = U.cleanExtrasEntry(e, #Config.Palettes, Config.Tints.channelMax)
                end
            end
        end

        local compsJson = U.encodeObject(clothes)
        local extrasOut = U.encodeObject(extras)

        if price > 0 then now.removeCurrency(0, price) end
        local okWrite, written = pcall(now.updateComps, compsJson)
        if not okWrite or written == false then
            if price > 0 then now.addCurrency(0, price) end
            fail()
            return tip(src, L('saveFailed'))
        end
        TriggerClientEvent('vorp_character:client:syncComps', src, compsJson)
        DB.setExtras(charId, extrasOut)

        if starter then
            passes[src] = nil
            DB.markStarter(charId)
        end
        if title then
            DB.addOutfit(charId, now.identifier, title, compsJson, extrasOut)
            dbg('char %s saved outfit "%s"', charId, title)
        end
        sessions[src] = nil
        dbg('char %s bought clothes for $%s%s', charId, price, starter and ' (starter fitting)' or '')
        TriggerClientEvent('pup_clothing:bought', src, compsJson, extrasOut)
    end)
    busy[src] = nil
end)

---------------------------------------------------------------------------
-- free starter fitting
---------------------------------------------------------------------------
RegisterNetEvent('pup_clothing:starter', function()
    local src = validSource(source)
    if not src or not allow(src, 'starter') then return end
    if not Config.Starter.enabled then return end
    local c = getChar(src)
    if not c or busy[src] then return end
    local charId = c.charIdentifier
    if DB.starterUsed(charId) then return end
    local now = getChar(src)
    if not now or now.charIdentifier ~= charId then return end
    passes[src] = charId
    sessions[src] = { kind = 'store', charId = charId, free = true }
    sendStore(src, now, true)
end)

---------------------------------------------------------------------------
-- wardrobe
---------------------------------------------------------------------------
local function sendOutfits(src, charId)
    local rows = DB.listOutfits(charId)
    local list = {}
    for _, r in ipairs(rows) do list[#list + 1] = { id = r.id, title = r.title } end
    local now = getChar(src)
    if not now or now.charIdentifier ~= charId then return end
    TriggerClientEvent('pup_clothing:outfits', src, list)
end

RegisterNetEvent('pup_clothing:openWardrobe', function()
    local src = validSource(source)
    if not src or not allow(src, 'open') then return end
    local c = getChar(src)
    if not c or busy[src] then return end
    local idx = pointAt(src, Config.Wardrobes)
    if not idx then return tip(src, L('notHere')) end
    sessions[src] = { kind = 'wardrobe', loc = idx, charId = c.charIdentifier }
    sendOutfits(src, c.charIdentifier)
end)

RegisterNetEvent('pup_clothing:listOutfits', function()
    local src = validSource(source)
    if not src then return end
    local function run()
        local c = getChar(src)
        if not c or not sessionOk(src, 'wardrobe', c) then return end
        sendOutfits(src, c.charIdentifier)
    end
    if allow(src, 'list', run) then run() end
end)

RegisterNetEvent('pup_clothing:deleteOutfit', function(id)
    local src = validSource(source)
    if not src or not allow(src, 'delete') or busy[src] then return end
    id = U.int(id)
    if not id or id <= 0 then return end
    local c = getChar(src)
    if not c or not sessionOk(src, 'wardrobe', c) then return end
    local n = DB.deleteOutfit(id, c.charIdentifier)
    dbg('char %s deleted outfit %d (%d row)', c.charIdentifier, id, n)
    sendOutfits(src, c.charIdentifier)
end)

RegisterNetEvent('pup_clothing:wearOutfit', function(id)
    local src = validSource(source)
    if not src or not allow(src, 'wear') or busy[src] then return end
    id = U.int(id)
    if not id or id <= 0 then return end
    local c = getChar(src)
    if not c then return end
    local s = sessionOk(src, 'wardrobe', c)
    if not s then return end
    if looksLocked(c) then
        sessions[src] = nil
        return tip(src, L('disguised'))
    end

    busy[src] = true
    local charId = c.charIdentifier
    withCharLock(charId, function()
        local row = DB.getOutfit(id, charId)
        if not row then return tip(src, L('outfitGone')) end
        local comps = U.decodeObject(row.comps) or {}
        local sex = sexOf(c)

        -- garments the catalogue does not know are blanked, and the row keeps the blanked copy
        local changed = false
        if not Config.Npc.keepTailorPieces then
            for k, v in pairs(comps) do
                local num = U.int(v)
                if num and num ~= -1 and num ~= 0 and not Cat.fits(num, sex, Cat.categoryOf(k)) then
                    comps[k] = -1
                    changed = true
                end
            end
        end
        local compsJson = changed and U.encodeObject(comps) or (type(row.comps) == 'string' and row.comps ~= '' and row.comps or '{}')
        if changed then DB.setOutfitComps(id, charId, compsJson) end

        local extrasJson = ''
        local ex = U.decodeObject(row.extras)
        if ex and next(ex) then
            local clean = U.cleanExtras(ex, extrasOpts())
            if clean and next(clean) then extrasJson = U.encodeObject(clean) end
        end

        local now = getChar(src)
        if not now or now.charIdentifier ~= charId or sessions[src] ~= s then return end
        if looksLocked(now) then return tip(src, L('disguised')) end
        local okWrite, written = pcall(now.updateComps, compsJson)
        if not okWrite or written == false then return tip(src, L('saveFailed')) end
        TriggerClientEvent('vorp_character:client:syncComps', src, compsJson)
        if extrasJson ~= '' then DB.setExtras(charId, extrasJson) end
        sessions[src] = nil
        dbg('char %s wore outfit %d', charId, id)
        TriggerClientEvent('pup_clothing:worn', src, compsJson, extrasJson)
    end)
    -- the list closed on the client when Wear was pressed, whatever the outcome
    if sessions[src] == s then sessions[src] = nil end
    busy[src] = nil
end)

---------------------------------------------------------------------------
-- extras
---------------------------------------------------------------------------
local function sendExtras(src, wantSanitize)
    local c = getChar(src)
    if not c then return end
    local charId = c.charIdentifier
    local extras = DB.getExtras(charId)
    local now = getChar(src)
    if not now or now.charIdentifier ~= charId then return end
    local comps = nil
    if wantSanitize and not Config.Npc.keepTailorPieces and not looksLocked(now) then
        comps = compsString(now)
    end
    dbg('extras for char %s (%d bytes)%s', charId, #extras, comps and ' + sanitize' or '')
    TriggerClientEvent('pup_clothing:recExtras', src, extras, 'own', comps)
end

RegisterNetEvent('pup_clothing:getExtras', function(wantSanitize)
    local src = validSource(source)
    if not src then return end
    wantSanitize = wantSanitize == true
    if allow(src, 'extras', function() sendExtras(src, wantSanitize) end) then
        sendExtras(src, wantSanitize)
    end
end)

-- pup_tailor reports what it has dressed the ped in: category -> singleplayer drawable, or false
local pendingSync = {}
local function applySync(src)
    local json = pendingSync[src]
    pendingSync[src] = nil
    if not json then return end
    local c = getChar(src)
    if not c then return end
    local t = U.decodeObject(json, Config.Server.payloadMax)
    if not t then return end
    local charId = c.charIdentifier
    withCharLock(charId, function()
        local cur = U.decodeObject(DB.getExtras(charId)) or {}
        local valid = 0
        for k, v in pairs(t) do
            if U.validCatKey(k, Config.Server.syncKeyMax) then
                valid = valid + 1
                local old = type(cur[k]) == 'table'
                    and U.cleanExtrasEntry(cur[k], #Config.Palettes, Config.Tints.channelMax) or nil
                local num = type(v) == 'number' and U.int(v) or nil
                if num and num ~= 0 then
                    cur[k] = { h = num, p = old and old.p or 0, c = old and old.c or { 0, 0, 0 } }
                elseif old and old.p > 0 then
                    cur[k] = { h = false, p = old.p, c = old.c }
                else
                    cur[k] = nil
                end
            end
        end
        if valid == 0 then return end
        if U.count(cur) > Config.Server.extrasMaxSlots then
            return dbg('sync from %d refused: more than %d slots', src, Config.Server.extrasMaxSlots)
        end
        local now = getChar(src)
        if not now or now.charIdentifier ~= charId then return end
        DB.setExtras(charId, U.encodeObject(cur))
        dbg('char %s extras synced (%d key(s))', charId, valid)
    end)
end

RegisterNetEvent('pup_clothing:syncExtras', function(json)
    local src = validSource(source)
    if not src then return end
    if type(json) ~= 'string' or #json > Config.Server.payloadMax then return end
    -- the latest report wins; a report inside the gap is applied once the gap has passed
    pendingSync[src] = json
    if allow(src, 'sync', function() applySync(src) end) then applySync(src) end
end)

-- the server only needs the singleplayer list to check store purchases when the store offers those garments
if Config.Npc.inStore then Cat.loadNpcWhenReady() end

---------------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------------
local function forget(src)
    sessions[src], passes[src], busy[src] = nil, nil, nil
    lastCall[src], deferred[src], pendingSync[src] = nil, nil, nil
end

AddEventHandler('playerDropped', function()
    forget(source)
end)

-- a character switch ends any open store or wardrobe; a starter pass stays tied to its own character
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    sessions[src] = nil
end)
