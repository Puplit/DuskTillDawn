-- pup-magic | the staff spell kit, server side. The server decides who may cast, what is in range,
-- every cooldown, and what each effect does. Clients only send "I pressed this key, aiming here".

local Spells <const> = Config.Spells

local Auras     = {} -- [target src] = { [spell id] = true }
local Cooldowns = {} -- [src] = { [spell id] = ms of the last cast that went off }
local Shocks    = {} -- [target src] = token of the shock now running
local Frogs     = {} -- [target src] = token of the transform now running
local castAt, refusedAt, spellsAskAt = {}, {}, {}
local token = 0

local AURA_BAG <const> = 'pup_magic_auras'

---------------------------------------------------------------------------
-- permission
---------------------------------------------------------------------------
local function canCast(src, spell)
    local ch = CharOf(src)
    if not ch then return false end
    if Config.General.debug then return true end
    for _, group in ipairs(spell.casters or {}) do
        local list = MagicCasters[group]
        if type(list) == 'table' then
            for _, id in ipairs(list) do
                -- server/casters.lua says non-integer ids are ignored, so they are
                if math.type(id) == 'integer' and id == ch.id then return true end
            end
        end
    end
    return false
end

local function allowedList(src)
    local out = {}
    for id, spell in pairs(Spells) do
        if canCast(src, spell) then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

RegisterNetEvent('pup-magic:askSpells', function()
    local src = PlayerIdOf(source)
    if not src or not Throttle(spellsAskAt, src, 1000) then return end
    TriggerClientEvent('pup-magic:spells', src, allowedList(src))
end)

local function refuse(src, spellId)
    if not Throttle(refusedAt, src, 10000) then return end
    LogRefusedCast(src, type(spellId) == 'string' and spellId or tostring(spellId))
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function spend(src, id)
    Cooldowns[src] = Cooldowns[src] or {}
    Cooldowns[src][id] = GetGameTimer()
end

local function rangeOf(spell)
    return tonumber(spell.range) or tonumber(MagicLimits.targetRange) or 250.0
end

local function within(src, point, max)
    local me = PosOf(src)
    return me ~= nil and point ~= nil and #(me - point) <= max
end

local function nextToken()
    token = token + 1
    return token
end

-- every aura that is on, by player, as one replicated GlobalState table only the server can write
local function publishAuras()
    local map = {}
    for target, set in pairs(Auras) do
        local ids = {}
        for id in pairs(set) do ids[#ids + 1] = id end
        if #ids > 0 then
            table.sort(ids)
            map[tostring(target)] = ids
        end
    end
    GlobalState:set(AURA_BAG, map, true)
end

local function clearAuras(src)
    if Auras[src] then
        Auras[src] = nil
        publishAuras()
    end
end

local function blast(x, y, z, tag, size)
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, tag = math.tointeger(tonumber(tag)) or 25, size = (tonumber(size) or 1.0) + 0.0 }
end

local function showBlasts(list, caster)
    TriggerClientEvent('pup-magic:blasts', -1, list, caster)
end

-- the blast push: everyone but `exclude` within radius gets hit, less the further away
local function push(origin, s, exclude)
    local radius = tonumber(s.radius) or 4.0
    local damage = tonumber(s.damage) or 0
    local force = tonumber(s.force) or 0
    if (damage <= 0 and force <= 0) or radius <= 0 then return end
    for _, id in ipairs(ConnectedPlayers()) do
        if id ~= exclude then
            local p = PosOf(id)
            if p then
                local d = #(p - origin)
                if d <= radius then
                    local hit = math.max(0, math.floor(damage * (1 - 0.6 * d / radius)))
                    TriggerClientEvent('pup-magic:hit', id, origin.x, origin.y, origin.z, hit, force + 0.0)
                end
            end
        end
    end
end

local function endShock(target, t)
    if Shocks[target] ~= t then return end
    Shocks[target] = nil
    if Online(target) then TriggerClientEvent('pup-magic:shockEnd', target) end
    TriggerClientEvent('pup-magic:sparks', -1, target, nil, false)
    TriggerClientEvent('pup-magic:mute', -1, target, false)
end

local function endFrog(target, t, spell)
    if Frogs[target] ~= t then return end
    Frogs[target] = nil
    if not Online(target) then return end
    TriggerClientEvent('pup-magic:untransform', target)
    if type(spell.notif) == 'table' then TipRight(target, spell.notif.off, 3000) end
end

---------------------------------------------------------------------------
-- effects: return false when the spell stopped early (no cooldown, no end message)
---------------------------------------------------------------------------
local Effect = {}

function Effect.aura(src, id, spell, target)
    local who = spell.self and src or (target or src)
    if who ~= src then
        local tp = PosOf(who)
        if not within(src, tp, rangeOf(spell)) then TipRight(src, Locale.tooFar, 3000) return false end
    end

    local set = Auras[who]
    if set and set[id] then
        set[id] = nil
        if not next(set) then Auras[who] = nil end
        publishAuras()
        if type(spell.notif) == 'table' then TipRight(who, spell.notif.off, 3000) end
        return false
    end

    spend(src, id)
    Auras[who] = Auras[who] or {}
    Auras[who][id] = true
    publishAuras()

    if type(spell.pop) == 'table' then
        local p = PosOf(who)
        if p then
            local at = vector3(p.x, p.y, p.z + 0.7)
            showBlasts({ blast(at.x, at.y, at.z, spell.pop.tag or 24, spell.pop.size or 0.8) }, src)
            push(at, spell.pop, who)
        end
    end
    return true
end

function Effect.rocketleap(src, id, spell)
    local p = PosOf(src)
    if not p then return false end
    spend(src, id)
    showBlasts({ blast(p.x, p.y, p.z - 0.9, spell.tag or 24, spell.size or 0.6) }, src)
    local launch = type(spell.launch) == 'table' and spell.launch or {}
    TriggerClientEvent('pup-magic:leap', src, (tonumber(launch.forward) or 20.0) + 0.0, (tonumber(launch.up) or 10.0) + 0.0)
    return true
end

function Effect.detonate(src, id, spell)
    local p = PosOf(src)
    if not p then return false end
    spend(src, id)
    local size = tonumber(spell.size) or 1.5
    local list = { blast(p.x, p.y, p.z, spell.tag or 27, size) }
    local ring = math.max(0, math.floor(tonumber(spell.ring) or 0))
    local r = tonumber(spell.ringRadius) or 3.0
    for i = 1, ring do
        local a = (i - 1) / ring * 2 * math.pi
        list[#list + 1] = blast(p.x + math.cos(a) * r, p.y + math.sin(a) * r, p.z - 0.5, 25, size * 0.6)
    end
    showBlasts(list, src)
    push(p, spell, src)
    -- the caster always goes down with it
    TriggerClientEvent('pup-magic:hit', src, p.x, p.y + 0.3, p.z, math.max(0, math.floor(tonumber(spell.selfDamage) or 0)), 6.0)
    return true
end

function Effect.bombpunch(src, id, spell, target)
    if not target then return false end
    local tp = PosOf(target)
    if not within(src, tp, tonumber(spell.range) or 25.0) then TipRight(src, Locale.tooFar, 3000) return false end
    spend(src, id)
    local at = vector3(tp.x, tp.y, tp.z + 0.4)
    showBlasts({ blast(at.x, at.y, at.z, spell.tag or 25, spell.size or 0.8) }, src)
    push(at, spell, src)
    return true
end

function Effect.bombtoss(src, id, spell, _, point)
    if not point then return false end
    if not within(src, point, tonumber(spell.range) or 60.0) then TipRight(src, Locale.tooFarThrow, 3000) return false end
    spend(src, id)
    SetTimeout(math.max(0, tonumber(spell.delay) or 900), function()
        showBlasts({ blast(point.x, point.y, point.z, spell.tag or 27, spell.size or 1.2) }, src)
        push(point, spell, src)
    end)
    return true
end

function Effect.smoke(src, id, spell, _, point)
    if not point then return false end
    if not within(src, point, rangeOf(spell)) then TipRight(src, Locale.tooFar, 3000) return false end
    spend(src, id)
    TriggerClientEvent('pup-magic:smoke', -1, id, point.x, point.y, point.z)
    return true
end

function Effect.lightning(src, id, spell, target, point)
    if not point then return false end
    local reach = rangeOf(spell)
    if not within(src, point, reach) then TipRight(src, Locale.tooFar, 3000) return false end
    if target and not within(src, PosOf(target), reach) then target = nil end
    spend(src, id)
    TriggerClientEvent('pup-magic:lightning', -1, point.x, point.y, point.z)
    local dmg = math.floor(tonumber(spell.damage) or 0)
    if target and dmg > 0 then TriggerClientEvent('pup-magic:selfDamage', target, dmg) end
    return true
end

function Effect.shock(src, id, spell, target)
    if not target then TipRight(src, spell.noTarget or Locale.noReach, 3000) return false end
    if not within(src, PosOf(target), rangeOf(spell)) then TipRight(src, Locale.tooFar, 3000) return false end
    spend(src, id)
    local secs = math.max(1, math.floor(tonumber(spell.duration) or 5))
    local sparks = type(spell.sparks) == 'string' and spell.sparks or 'ent_sht_electrical_box'
    -- a second shock on the same player restarts the clock; only the newest timer ends it
    local t = nextToken()
    Shocks[target] = t
    TriggerClientEvent('pup-magic:shock', target, secs, sparks)
    TriggerClientEvent('pup-magic:sparks', -1, target, sparks, true)
    TriggerClientEvent('pup-magic:mute', -1, target, true)
    SetTimeout(secs * 1000, function() endShock(target, t) end)
    return true
end

function Effect.transform(src, id, spell, target)
    if not target then TipRight(src, spell.noTarget or Locale.noReach, 3000) return false end
    if not within(src, PosOf(target), rangeOf(spell)) then TipRight(src, Locale.tooFar, 3000) return false end
    spend(src, id)
    local secs = math.max(1, math.floor(tonumber(spell.duration) or 10))
    local t = nextToken()
    local already = Frogs[target] ~= nil
    Frogs[target] = t
    if not already then TriggerClientEvent('pup-magic:transform', target, spell.model) end
    if type(spell.notif) == 'table' then TipRight(target, spell.notif.on, 3000) end
    SetTimeout(secs * 1000, function() endFrog(target, t, spell) end)
    return true
end

---------------------------------------------------------------------------
-- the cast
---------------------------------------------------------------------------
RegisterNetEvent('pup-magic:cast', function(msg)
    local src = PlayerIdOf(source)
    if not src or not Throttle(castAt, src, 150) then return end

    if type(msg) ~= 'table' or type(msg.id) ~= 'string' then return refuse(src, type(msg) == 'table' and msg.id or nil) end
    local id = msg.id
    local spell = Spells[id]
    if type(spell) ~= 'table' or not canCast(src, spell) then return refuse(src, id) end

    local handler = Effect[spell.effect]
    if not handler then return end -- aimdot and anim never reach the server

    local target = PlayerIdOf(msg.target)
    local point = PointOf(msg.point)

    if spell.requires then
        local mine = Auras[src]
        if not (mine and mine[spell.requires]) then
            TipRight(src, Locale.pinFirst, 3000)
            return
        end
    end

    local cd = tonumber(spell.cooldown)
    if cd and cd > 0 then
        local last = Cooldowns[src] and Cooldowns[src][id]
        local left = last and (cd * 1000 - (GetGameTimer() - last)) or 0
        if left > 0 then
            TipRight(src, Locale.notYet:format(math.ceil(left / 1000)), 3000)
            return
        end
    end

    if handler(src, id, spell, target, point) == false then return end

    local notif = spell.notif
    if type(notif) == 'table' then notif = notif.on end
    TipRight(src, notif, 3000)
end)

---------------------------------------------------------------------------
-- forgetting
---------------------------------------------------------------------------
local function forget(src, dropped)
    clearAuras(src)
    Cooldowns[src] = nil
    if Shocks[src] then
        local t = Shocks[src]
        endShock(src, t)
    end
    if Frogs[src] then
        Frogs[src] = nil -- the character reload (or the drop) puts the real model back
    end
    if dropped then
        castAt[src], refusedAt[src], spellsAskAt[src] = nil, nil, nil
    end
end

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = PlayerIdOf(src)
    if src then forget(src, false) end
end)

AddEventHandler('playerDropped', function()
    local src = math.tointeger(tonumber(source))
    if src then forget(src, true) end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    publishAuras() -- nothing on after a restart
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    GlobalState:set(AURA_BAG, {}, true)
end)
