-- pup-gangs | server/blood.lua: BLOOD MONEY - the item, the ledger, and what it buys

local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)
if not VorpCore or not VorpCore.getUser then
    VorpCore = exports.vorp_core:GetCore()
end
local VorpInv <const> = exports.vorp_inventory

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs blood]^7 " .. table.concat(parts, " "))
end

local function Char(src)
    local user = VorpCore.getUser(src)
    return user and user.getUsedCharacter or nil
end
local function notify(src, msg, dur) VorpCore.NotifyRightTip(src, msg, dur or 4000) end
local function now() return os.time() end

-- SCHEMA
CreateThread(function()
    Wait(4000)
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS bloodmoney INT(11) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS slots_bought INT(11) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS perks_bought TEXT NULL")
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS gang_blood_log (
        id     INT(11) NOT NULL AUTO_INCREMENT,
        gangid INT(11) NOT NULL,
        charid INT(11) NULL,
        name   VARCHAR(64) NOT NULL DEFAULT '',
        amount INT(11) NOT NULL DEFAULT 0,
        reason VARCHAR(96) NOT NULL DEFAULT '',
        ts     INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (id),
        KEY idx_blood_gang (gangid, ts)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    -- the item has to exist or every award silently vanishes
    local row = MySQL.query.await('SELECT item FROM items WHERE item = ?', { Config.Blood.item })
    if not row or not row[1] then
        print(('^1[pup-gangs]^7 blood money item "%s" is NOT in the items table - import blood_money.sql')
            :format(tostring(Config.Blood.item)))
    else
        dbg('ready')
    end
end)

-- LEDGER HELPERS
local function bloodLog(gangid, charid, name, amount, reason)
    MySQL.insert('INSERT INTO gang_blood_log (gangid, charid, name, amount, reason, ts) VALUES (?, ?, ?, ?, ?, ?)',
        { gangid, charid, name or '', amount, reason or '', now() })
end

-- Move `delta` into (or out of) a gang's ledger
function GangBloodMove(gang, delta, charid, name, reason)
    if not gang or delta ~= delta then return nil end
    local cur <const> = tonumber(gang.bloodmoney) or 0
    local newBal <const> = cur + delta
    if newBal < 0 then return nil end
    gang.bloodmoney = newBal
    MySQL.update('UPDATE gangs SET bloodmoney = ? WHERE id = ?', { newBal, gang.id })
    bloodLog(gang.id, charid, name, delta, reason)
    return newBal
end

--- Purchased perks as a set. Stored as a JSON array on the gang row.
local function boughtPerks(gang)
    if not gang then return {} end
    if gang._perkSet then return gang._perkSet end
    local set = {}
    local raw = gang.perks_bought
    if type(raw) == 'string' and raw ~= '' then
        local ok, list = pcall(json.decode, raw)
        if ok and type(list) == 'table' then
            for _, f in ipairs(list) do set[f] = true end
        end
    end
    gang._perkSet = set
    return set
end

-- Has this gang BOUGHT this perk?
function GangBoughtPerk(gang, flag)
    if not flag then return false end
    return boughtPerks(gang)[flag] == true
end

local function addBoughtPerk(gang, flag)
    local set = boughtPerks(gang)
    set[flag] = true
    local list = {}
    for f in pairs(set) do list[#list + 1] = f end
    table.sort(list)
    gang.perks_bought = json.encode(list)
    MySQL.update('UPDATE gangs SET perks_bought = ? WHERE id = ?', { gang.perks_bought, gang.id })
end

--- Extra member slots this gang has PAID for.
function GangBoughtSlots(gang)
    return math.max(0, tonumber(gang and gang.slots_bought) or 0)
end

-- EARNING IT - the one entry point, exported so other resources can award it
local function awardBlood(src, spec, chancePct, reason)
    if not Config.Blood.enabled then return 0 end
    local ch = Char(src)
    if not ch then return 0 end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return 0 end          -- the whole point: gang members only

    if chancePct and math.random(100) > chancePct then return 0 end

    local lo <const> = math.max(1, math.floor(tonumber(spec and spec.min) or 1))
    local hi <const> = math.max(lo, math.floor(tonumber(spec and spec.max) or lo))
    local n <const> = math.random(lo, hi)
    if n <= 0 then return 0 end

    local ok = pcall(function() VorpInv:addItem(src, Config.Blood.item, n) end)
    if not ok then return 0 end
    dbg('awarded', n, 'to', src, '-', reason or '?')
    return n
end

-- exports['pup-gangs']:AwardBloodMoney(source, kind) - kind: 'mission' | 'robbery' | 'drugSale', or a { min, max } table
exports('AwardBloodMoney', function(src, kind, reason)
    local spec, chance
    if type(kind) == 'table' then
        spec, chance = kind, nil
    elseif kind == 'robbery' then
        spec, chance = Config.Blood.robbery, Config.Blood.robberyChance
    elseif kind == 'drugSale' then
        spec, chance = Config.Blood.drugSale, Config.Blood.drugSaleChance
    else
        spec, chance = Config.Blood.mission, nil
    end
    return awardBlood(src, spec, chance, reason or kind)
end)

-- gang missions pay it flat (no chance roll): plant run, defence, fort raid, den
function GangBloodMission(src, reason)
    return awardBlood(src, Config.Blood.mission, nil, reason or 'mission')
end

-- BANKING IT
RegisterNetEvent('pup-gangs:bloodDeposit', function(amount)
    local _source = source
    if not Config.Blood.enabled then return end
    local ch = Char(_source)
    if not ch then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end

    local have <const> = tonumber(VorpInv:getItemCount(_source, nil, Config.Blood.item)) or 0
    if have < 1 then return notify(_source, Locale.bloodNone) end

    -- nil / 0 / "all" deposits the lot
    local n = math.floor(tonumber(amount) or 0)
    if n ~= n or n <= 0 or n > have then n = have end

    if VorpInv:subItem(_source, Config.Blood.item, n) == false then return end
    local bal = GangBloodMove(gang, n, ch.charIdentifier,
        ch.firstname .. ' ' .. ch.lastname, 'deposit')
    GangLog(m.gangid, 'blood', ('banked %d blood money'):format(n), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, (Locale.bloodBanked):format(n, bal or 0), 6000)
    dbg('deposit', n, 'gang', gang.id, '=>', bal)
end)

-- SPENDING IT
RegisterNetEvent('pup-gangs:bloodBuySlot', function()
    local _source = source
    if not Config.Blood.enabled then return end
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    -- spending the ledger needs the bank permission
    if not GangCan(charid, 'bank') then return notify(_source, Locale.notAllowed) end
    local gang = GangById(m.gangid)
    if not gang then return end

    local cap <const> = tonumber(Config.Blood.maxExtra) or 0
    if cap > 0 and GangBoughtSlots(gang) >= cap then
        return notify(_source, (Locale.bloodSlotCap):format(cap), 6000)
    end

    local cost <const> = tonumber(Config.Blood.perMember) or 0
    local bal = GangBloodMove(gang, -cost, charid, ch.firstname .. ' ' .. ch.lastname, 'member slot')
    if not bal then
        return notify(_source, (Locale.bloodShort):format(cost, tonumber(gang.bloodmoney) or 0), 6000)
    end

    gang.slots_bought = GangBoughtSlots(gang) + 1
    MySQL.update('UPDATE gangs SET slots_bought = ? WHERE id = ?', { gang.slots_bought, gang.id })
    GangLog(m.gangid, 'blood', ('bought a member slot for %d'):format(cost), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, (Locale.bloodSlotBought):format(cost, bal), 7000)
end)

RegisterNetEvent('pup-gangs:bloodBuyPerk', function(flag)
    local _source = source
    if not Config.Blood.enabled then return end
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    if not GangCan(charid, 'bank') then return notify(_source, Locale.notAllowed) end
    local gang = GangById(m.gangid)
    if not gang then return end

    flag = tostring(flag or '')
    if flag == '' or not (Config.Perks.labels or {})[flag] then return end

    -- must be OFFERED by the gang's level
    if not GangPerkAvailable or not GangPerkAvailable(gang, flag) then
        return notify(_source, Locale.bloodPerkLocked, 7000)
    end
    if GangHasPerk(gang, flag) then return notify(_source, Locale.bloodHavePerk) end

    local cost <const> = tonumber(Config.Blood.perPerk) or 0
    local bal = GangBloodMove(gang, -cost, charid, ch.firstname .. ' ' .. ch.lastname, 'perk ' .. flag)
    if not bal then
        return notify(_source, (Locale.bloodShort):format(cost, tonumber(gang.bloodmoney) or 0), 6000)
    end

    addBoughtPerk(gang, flag)
    GangLog(m.gangid, 'blood', ('unlocked %s for %d'):format(
        (Config.Perks.labels or {})[flag] or flag, cost), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, (Locale.bloodPerkBought):format((Config.Perks.labels or {})[flag] or flag, bal), 8000)
    GangRefreshCrew(m.gangid)
end)

-- THE LEDGER PAGE
VorpCore.Callback.Register('pup-gangs:getBlood', function(source, cb)
    local ch = Char(source)
    if not ch then return cb(false) end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return cb(false) end
    local gang = GangById(m.gangid)
    if not gang then return cb(false) end

    -- The transaction history is NOT sent

    -- which perks are still buyable: known flags this gang does not have yet
    local buyable = {}
    for flag, label in pairs(Config.Perks.labels or {}) do
        -- same fail-closed rule as the buy handler above: only perks this gang's LEVEL has actually put on the shelf
        if GangPerkAvailable and GangPerkAvailable(gang, flag) and not GangHasPerk(gang, flag) then
            buyable[#buyable + 1] = { flag = flag, label = label }
        end
    end
    table.sort(buyable, function(a, b) return a.label < b.label end)

    -- THE ROSTER, spelled out
    local bought <const> = GangBoughtSlots(gang)
    local perks <const> = GangPerks and GangPerks(gang.points) or nil
    local levelExtra <const> = (perks and tonumber(perks.members)) or 0
    local base <const> = tonumber(Config.Creation.maxMembers) or 0
    local roster <const> = (GangRosterCount and GangRosterCount(gang.id)) or 0

    cb({
        balance    = tonumber(gang.bloodmoney) or 0,
        carrying   = tonumber(VorpInv:getItemCount(source, nil, Config.Blood.item)) or 0,
        perMember  = tonumber(Config.Blood.perMember) or 0,
        perPerk    = tonumber(Config.Blood.perPerk) or 0,
        perColour  = tonumber(Config.Blood.perColour) or 0,
        perWar     = tonumber(Config.Blood.perWar) or 0,
        slotsBought = bought,
        maxExtra   = tonumber(Config.Blood.maxExtra) or 0,
        -- roster maths for the panel
        members    = roster,
        cap        = (base > 0) and (base + levelExtra + bought) or 0,
        levelExtra = levelExtra,
        baseCap    = base,
        canBuy     = GangCan(ch.charIdentifier, 'bank'),
        canPerk    = GangCan(ch.charIdentifier, 'bank'),
        buyable    = buyable,
    })
end)
