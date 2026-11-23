-- pup_gunsmith | customization bench: sessions, the gun on the bench, live preview, fitting

Bench = {
    sessions = {}, -- [src] = session
}

local benchById = {}
for _, b in ipairs(Config.Benches) do benchById[b.id] = b end
Bench.byId = benchById

local MAX_PARTS <const> = Config.Bench.maxParts

local function partsJson(set)
    if next(set) == nil then return '{}' end
    return json.encode(set)
end

---------------------------------------------------------------------------
-- carried guns: the character's loadout rows that are held, in the main inventory, not dropped
---------------------------------------------------------------------------
local CARRIED_SQL <const> = [[SELECT id, name, label, custom_label, serial_number, comps FROM loadout
    WHERE charidentifier = ? AND identifier IS NOT NULL AND identifier <> ''
    AND curr_inv = 'default' AND (dropped IS NULL OR dropped = 0)]]

local function gunFromRow(r)
    local label = r.custom_label
    if type(label) ~= 'string' or label == '' then label = r.label end
    if type(label) ~= 'string' or label == '' then label = Config.WeaponNames[tostring(r.name):upper()] or tostring(r.name) end
    return {
        id = tonumber(r.id),
        name = tostring(r.name),
        label = label,
        serial = (type(r.serial_number) == 'string' and r.serial_number ~= '') and r.serial_number or nil,
        parts = GS.cleanParts(Srv.decode(r.comps, {}), MAX_PARTS),
    }
end

function Bench.carriedGuns(charId)
    local ok, rows = pcall(MySQL.query.await, CARRIED_SQL, { charId })
    local out = {}
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do out[#out + 1] = gunFromRow(r) end
    end
    return out
end

function Bench.carriedGun(charId, weaponId)
    local ok, rows = pcall(MySQL.query.await, CARRIED_SQL .. ' AND id = ?', { charId, weaponId })
    if ok and type(rows) == 'table' and rows[1] then return gunFromRow(rows[1]) end
    return nil
end

---------------------------------------------------------------------------
-- watchers (players near the bench who see the gun)
---------------------------------------------------------------------------
local function nearbyPlayers(src, pos)
    local set = {}
    local range = Config.Bench.watchRange
    for _, p in ipairs(GetPlayers()) do
        local pid = tonumber(p)
        if pid and pid ~= src then
            local c = Srv.coords(pid)
            if c and #(c - pos) <= range then set[pid] = true end
        end
    end
    return set
end

local function hideAll(s)
    for pid in pairs(s.watchers) do
        TriggerClientEvent('pup_gunsmith:pvHide', pid, s.src)
    end
    s.watchers = {}
end

local function showTo(s, pid)
    local g = s.gun
    TriggerClientEvent('pup_gunsmith:pvShow', pid, s.src, s.bench.id, g.hash, g.name, g.family, s.preview, s.rot)
end

--- adds players who walked up, drops those who walked away
function Bench.refreshWatchers(s)
    if not s.gun then return end
    local now = nearbyPlayers(s.src, s.bench.stand)
    for pid in pairs(now) do
        if not s.watchers[pid] then showTo(s, pid) end
    end
    for pid in pairs(s.watchers) do
        if not now[pid] then TriggerClientEvent('pup_gunsmith:pvHide', pid, s.src) end
    end
    s.watchers = now
end

---------------------------------------------------------------------------
-- sessions
---------------------------------------------------------------------------
function Bench.endSession(src, tellClient)
    local s = Bench.sessions[src]
    if not s then return end
    hideAll(s)
    Bench.sessions[src] = nil
    if tellClient then TriggerClientEvent('pup_gunsmith:benchClose', src) end
end

Srv.onReset(function(src) Bench.endSession(src, false) end)

--- the session, when the player is still at its bench with the same character
function Bench.active(src, char, needGun)
    local s = Bench.sessions[src]
    if not s or s.charId ~= char.charIdentifier then return nil end
    if needGun and not s.gun then return nil end
    if not Srv.near(src, s.bench.stand, Config.Bench.reach, 'bench') then return nil end
    -- losing the job ends the session at once, not only on the next sweep
    if not Srv.hasAccess(char, s.bench.jobs, Config.Bench.minGrade) then
        Bench.endSession(src, true)
        return nil
    end
    return s
end

-- one loop while any session exists: refresh watchers, end sessions whose player lost the job or walked off
local loopRunning = false
local function ensureLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while next(Bench.sessions) do
            Wait(Config.Bench.watchRefresh)
            for src, s in pairs(Bench.sessions) do
                local char = Srv.char(src)
                if not char or char.charIdentifier ~= s.charId
                    or not Srv.hasAccess(char, s.bench.jobs, Config.Bench.minGrade)
                    or not Srv.near(src, s.bench.stand, Config.Bench.reach + 1.0, 'bench') then
                    Bench.endSession(src, true)
                else
                    Bench.refreshWatchers(s)
                end
            end
        end
        loopRunning = false
    end)
end

Srv.rpc('benchOpen', function(src, char, benchId)
    local bench = benchById[benchId]
    if not bench then return { ok = false } end
    if not Srv.near(src, bench.stand, Config.Bench.reach, 'bench') then return { ok = false, msg = L('stand_bench') } end
    if not Srv.hasAccess(char, bench.jobs, Config.Bench.minGrade) then return { ok = false, msg = L('no_job_bench') } end

    Bench.endSession(src, false)
    local s = {
        src = src, charId = char.charIdentifier, bench = bench,
        gun = nil, watchers = {}, preview = {}, rot = { 0.0, 0.0, 0.0 },
        lastTurn = 0, partWindow = 0, partCount = 0,
    }
    Bench.sessions[src] = s

    local guns = Bench.carriedGuns(char.charIdentifier)
    if Bench.sessions[src] ~= s or not Srv.same(src, char) then return { ok = false } end
    local okW, wear = pcall(function() return Inv:IsWeaponDegradationEnabled() end)
    ensureLoop()
    return {
        ok = true,
        guns = guns,
        wallet = Srv.wallet(src),
        wear = okW and wear == true,
        bench = bench.label or bench.id,
    }
end, { throttle = 750 })

Srv.rpc('benchSelect', function(src, char, weaponId, family)
    local s = Bench.active(src, char, false)
    if not s then return { ok = false, msg = L('stand_bench') } end
    weaponId = GS.int(weaponId)
    if not weaponId then return { ok = false, msg = L('not_carrying') } end
    if family ~= nil and not Catalogue.isFamily(family) then family = nil end

    local gun = Bench.carriedGun(char.charIdentifier, weaponId)
    if Bench.sessions[src] ~= s or not Srv.same(src, char) then return { ok = false, msg = L('stand_bench') } end
    if not gun then return { ok = false, msg = L('not_carrying') } end

    -- a previous gun's preview goes away for its watchers
    hideAll(s)
    gun.hash = joaat(gun.name:upper())
    gun.family = family
    gun.catalogue = Catalogue.build(gun.name, family)
    gun.fitted = gun.parts
    gun.parts = nil
    s.gun = gun
    s.preview = GS.copy(gun.fitted)
    s.rot = { 0.0, 0.0, 0.0 }
    Bench.refreshWatchers(s)

    local presets = BenchPresets.list(char.charIdentifier, gun.name)
    local card = Workshop.card(src, gun)
    if Bench.sessions[src] ~= s then return { ok = false, msg = L('stand_bench') } end
    return {
        ok = true,
        fitted = gun.fitted,
        catalogue = gun.catalogue,
        card = card,
        wallet = Srv.wallet(src),
        presets = presets,
    }
end, { exclusive = true, throttle = 300 })

Srv.rpc('benchPutAway', function(src, char)
    local s = Bench.sessions[src]
    if not s or s.charId ~= char.charIdentifier then return { ok = false } end
    hideAll(s)
    s.gun = nil
    s.preview = {}
    return { ok = true }
end)

RegisterNetEvent('pup_gunsmith:benchLeave', function()
    local src = source
    if not Srv.validSource(src) then return end
    Bench.endSession(src, false)
end)

---------------------------------------------------------------------------
-- validating a parts set against the gun on the bench
---------------------------------------------------------------------------
--- returns the cleaned set, or nil plus the offending category/part
function Bench.validateSet(gun, set)
    if type(set) ~= 'table' then return nil, '?', '?' end
    local out, n = {}, 0
    for cat, comp in pairs(set) do
        if type(cat) ~= 'string' or type(comp) ~= 'string' then return nil, tostring(cat), tostring(comp) end
        n = n + 1
        if n > MAX_PARTS then return nil, 'count', tostring(n) end
        local ucat, ucomp = cat:upper(), comp:upper()
        if not Catalogue.find(ucat, ucomp, gun.catalogue) and gun.fitted[ucat] ~= ucomp then
            return nil, ucat, ucomp
        end
        out[ucat] = ucomp
    end
    -- a gun always keeps a grip
    if gun.fitted.GRIP and not out.GRIP then out.GRIP = gun.fitted.GRIP end
    return out
end

--- what fitting `set` costs, given what is fitted now. Removals are free.
function Bench.priceOf(gun, set)
    local cash, gold = 0, 0
    for cat, comp in pairs(set) do
        if gun.fitted[cat] ~= comp then
            local v = Catalogue.find(cat, comp, gun.catalogue)
            if v then
                cash = cash + math.max(0, math.floor(v.cash or 0))
                gold = gold + math.max(0, math.floor(v.gold or 0))
            end
        end
    end
    return cash, gold
end

---------------------------------------------------------------------------
-- saving parts to a gun (only reachable from confirm)
---------------------------------------------------------------------------
local function verifyLater(weaponId, expected)
    SetTimeout(2000, function()
        local function count()
            local ok, v = pcall(MySQL.scalar.await, 'SELECT comps FROM loadout WHERE id = ?', { weaponId })
            if not ok then return nil end
            return GS.count(GS.cleanParts(Srv.decode(v, {}), MAX_PARTS))
        end
        if count() == expected then return end
        SetTimeout(3000, function()
            local n = count()
            if n ~= expected then
                print(('^1[pup_gunsmith]^7 weapon %s: saved %d part categories but the row holds %s - something overwrote the parts (write race with vorp_inventory?)')
                    :format(tostring(weaponId), expected, tostring(n)))
            end
        end)
    end)
end

function Bench.saveParts(src, char, weaponId, set, hash)
    set = GS.cleanParts(set, MAX_PARTS)
    local row = MySQL.single.await('SELECT charidentifier, curr_inv, identifier FROM loadout WHERE id = ?', { weaponId })
    if not row or tostring(row.charidentifier) ~= tostring(char.charIdentifier) then
        Srv.security(src, 'tried to save parts on weapon %s that is not theirs', tostring(weaponId))
        return false
    end
    if row.curr_inv ~= 'default' then
        Srv.security(src, 'tried to save parts on weapon %s stored in %s', tostring(weaponId), tostring(row.curr_inv))
        return false
    end
    if type(row.identifier) ~= 'string' or row.identifier == '' then
        Srv.security(src, 'tried to save parts on weapon %s that nobody carries', tostring(weaponId))
        return false
    end

    -- vorp_inventory's memory (when it has the weapon loaded; otherwise the parts show after a relog)
    local okC, current = pcall(function() return Inv:getWeaponComponents(src, weaponId) end)
    if okC and type(current) == 'table' then
        local removed = {}
        for cat, comp in pairs(current) do
            if set[cat] == nil then removed[cat] = comp end
        end
        if next(removed) then pcall(function() Inv:subWeaponComponents(src, weaponId, removed) end) end
        if next(set) then pcall(function() Inv:addWeaponComponents(src, weaponId, set) end) end
    end

    if next(set) then TriggerClientEvent('pup_gunsmith:refit', src, set, weaponId, hash) end

    MySQL.update('UPDATE loadout SET comps = ? WHERE id = ?', { partsJson(set), weaponId })
    verifyLater(weaponId, GS.count(set))
    return true
end

Srv.rpc('benchConfirm', function(src, char, set)
    local s = Bench.active(src, char, true)
    if not s then return { ok = false, msg = L('stand_bench') } end
    local gun = s.gun

    local clean, badCat, badPart = Bench.validateSet(gun, set)
    if not clean then
        Srv.security(src, 'tried to fit %s = %s on %s', tostring(badCat), tostring(badPart), gun.name)
        return { ok = false, msg = L('part_doesnt_fit') }
    end

    local cash, gold = Bench.priceOf(gun, clean)
    if Srv.cash(src) + 1e-9 < cash or Srv.gold(src) + 1e-9 < gold then
        return { ok = false, msg = L('no_money') }
    end
    -- paid first, refunded if the save is refused
    if not Srv.takeMoney(src, 0, cash) then return { ok = false, msg = L('no_money') } end
    if not Srv.takeMoney(src, 1, gold) then
        Srv.giveMoney(src, 0, cash)
        return { ok = false, msg = L('no_money') }
    end

    if not Bench.saveParts(src, char, gun.id, clean, gun.hash) then
        Srv.giveMoney(src, 0, cash)
        Srv.giveMoney(src, 1, gold)
        return { ok = false, msg = L('not_carrying') }
    end
    if Bench.sessions[src] == s and s.gun == gun then
        gun.fitted = clean
        s.preview = GS.copy(clean)
    end
    return { ok = true, paid = { cash = cash, gold = gold }, set = clean, wallet = Srv.wallet(src) }
end, { exclusive = true, throttle = 500 })

---------------------------------------------------------------------------
-- live preview relays
---------------------------------------------------------------------------
RegisterNetEvent('pup_gunsmith:benchPart', function(cat, comp)
    local src = source
    local s = Bench.sessions[src]
    if not s or not s.gun then return end
    if type(cat) ~= 'string' then return end
    if comp ~= nil and comp ~= false and type(comp) ~= 'string' then return end

    local now = GetGameTimer()
    if now - s.partWindow >= 1000 then
        s.partWindow, s.partCount = now, 0
    end
    s.partCount = s.partCount + 1
    if s.partCount > 40 then return end

    local gun = s.gun
    cat = cat:upper()
    local list = gun.catalogue[cat]
    if not list then return end
    if not comp then
        if cat == 'GRIP' then return end
        comp = nil
    else
        comp = comp:upper()
        if not Catalogue.find(cat, comp, gun.catalogue) and gun.fitted[cat] ~= comp then return end
    end
    s.preview[cat] = comp
    if not next(s.watchers) then return end

    local clear = {}
    for _, v in ipairs(list) do clear[#clear + 1] = v.item end
    if gun.fitted[cat] and not GS.inList(clear, gun.fitted[cat]) then clear[#clear + 1] = gun.fitted[cat] end
    for pid in pairs(s.watchers) do
        TriggerClientEvent('pup_gunsmith:pvPart', pid, src, cat, comp or false, clear)
    end
end)

RegisterNetEvent('pup_gunsmith:benchTurn', function(rx, ry, rz)
    local src = source
    local s = Bench.sessions[src]
    if not s or not s.gun then return end
    local now = GetGameTimer()
    if now - s.lastTurn < 60 then return end
    rx, ry, rz = tonumber(rx), tonumber(ry), tonumber(rz)
    if not rx or not ry or not rz or rx ~= rx or ry ~= ry or rz ~= rz then return end
    if math.abs(rx) > 1e6 or math.abs(ry) > 1e6 or math.abs(rz) > 1e6 then return end
    s.lastTurn = now
    s.rot = { rx % 360, ry % 360, rz % 360 }
    for pid in pairs(s.watchers) do
        TriggerClientEvent('pup_gunsmith:pvTurn', pid, src, s.rot[1], s.rot[2], s.rot[3])
    end
end)

---------------------------------------------------------------------------
-- stop: every preview goes away
---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(name)
    if name ~= GS.RES then return end
    for src in pairs(Bench.sessions) do Bench.endSession(src, false) end
end)
