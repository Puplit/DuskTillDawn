-- pup-stable | your horse in the world: whistle, follow, cores, death, flee, culling, blips, bonding

Horse = { cur = nil, peds = {}, blips = {}, follow = false, spawning = false }
Cores = { mem = {} }

local H = Config.Horse

------------------------------------------------------------------------------
-- cores (health / stamina rings and the inner stamina bar)
------------------------------------------------------------------------------
function Cores.apply(ped, c)
    if not DoesEntityExist(ped) or type(c) ~= 'table' then return end
    N.setCore(ped, 0, U.clamp(U.int(c.healthCore, 100), 0, 100))
    N.setCore(ped, 1, U.clamp(U.int(c.staminaCore, 100), 0, 100))
    local inner = U.int(c.pedStamina, 0)
    if inner > 0 then
        local now = N.pedStamina(ped) or 0
        N.changeStamina(ped, inner - now)
    end
end

function Cores.capture(ped)
    return N.core(ped, 0) or 100, N.core(ped, 1) or 100, math.floor(U.clamp(N.pedStamina(ped) or 0, 0, 1000))
end

-- save now; skipped during the spawn grace or when the horse is far away
function Cores.save(id, ped, force)
    if not id or not ped or not DoesEntityExist(ped) or IsEntityDead(ped) then return end
    local rec = Horse.peds[id]
    if not force and rec and GetGameTimer() < (rec.spawnedAt or 0) + H.invincibleMs + 5000 then return end
    if not force and #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > 40.0 then return end
    local hc, sc, inner = Cores.capture(ped)
    Cores.mem[id] = { t = GetGameTimer(), healthCore = hc, staminaCore = sc, pedStamina = inner }
    CreateThread(function() Call('saveCores', id, hc, sc, inner) end)
end

-- recall: memory copy within the keep window, else the server (which credits rest)
function Cores.restore(id, ped)
    local m = Cores.mem[id]
    if m and GetGameTimer() - m.t <= H.fleeKeepCoresMs then
        Cores.apply(ped, m)
        return
    end
    local ok, c = Call('getCores', id)
    if ok then Cores.apply(ped, c) end
end

------------------------------------------------------------------------------
-- blips
------------------------------------------------------------------------------
local BLIP_STYLE = joaat('BLIP_STYLE_PLAYER_HORSE')
local MOD_KEY, MOD_ANIMAL = joaat('BLIP_MODIFIER_MP_OBJECTIVE'), joaat('BLIP_MODIFIER_PLAYER_HORSE')

local function setBlip(id, ped, label, modifier)
    local old = Horse.blips[id]
    if old then N.blipRemove(old) end
    local b = N.blipEntity(BLIP_STYLE, ped)
    if b and b ~= 0 then
        N.blipName(b, label)
        if modifier then N.blipModifier(b, modifier) end
        Horse.blips[id] = b
    end
end

function Horse.refreshBlips()
    for id, rec in pairs(Horse.peds) do
        if DoesEntityExist(rec.ped) then
            local label, mod = L('blipHorse'), nil
            if Horse.cur and Horse.cur.id == id then
                if Horse.follow then label, mod = L('blipFollow'), MOD_ANIMAL else label, mod = L('blipLastHorse'), MOD_KEY end
            end
            if rec.blipLabel ~= label then
                rec.blipLabel = label
                setBlip(id, rec.ped, label, mod)
            end
        end
    end
end

------------------------------------------------------------------------------
-- bonding behaviour, read from the stats table the server publishes
------------------------------------------------------------------------------
local function bondFlags(ped, stats, owner)
    local b = type(stats) == 'table' and U.int(stats.bonding, 0) or 0
    local brave = b >= Config.Bonding.brave
    SetPedConfigFlag(ped, 113, brave)                 -- ignore shocking events
    if b >= Config.Bonding.calm then SetPedFleeAttributes(ped, 0, false) end
    local full = b >= Config.Stats.bondCeiling
    if Config.Bonding.kickFlag then
        -- full bond: never kick the owner; strangers within 3 m: deterministic 50 % per player+horse
        local kick = true
        if full then
            if owner then kick = false
            else
                local seed = (GetPlayerServerId(PlayerId()) * 7919 + U.int(Entity(ped).state.pup_stable_horseID, 0) * 104729) % 100
                kick = seed < Config.Bonding.strangerKickChance * 100
            end
        end
        SetPedConfigFlag(ped, Config.Bonding.kickFlag, not kick)
    end
end
Horse.bondFlags = bondFlags

local function ownerFlags(ped)
    for flag, on in pairs(H.ownerFlags) do SetPedConfigFlag(ped, flag, on) end
    for flag, on in pairs(H.extraFlags) do SetPedConfigFlag(ped, flag, on) end
    N.ownsAnimal(PlayerPedId(), ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    if H.ownerOnlyMount and H.mountSecurityFlag then SetPedConfigFlag(ped, H.mountSecurityFlag, true) end
end

------------------------------------------------------------------------------
-- adopting a spawned ped as one of mine
------------------------------------------------------------------------------
function Horse.adopt(row, ped, keepCurrent)
    Horse.peds[row.id] = { ped = ped, row = row, spawnedAt = GetGameTimer() }
    if not keepCurrent then
        Horse.cur = { id = row.id, ped = ped, row = row }
        Horse.follow = false
    end
    ownerFlags(ped)
    bondFlags(ped, Entity(ped).state.pup_stable_horse_stats or row, true)
    SetPedConfigFlag(ped, 297, true)
    Horse.refreshBlips()
end

local function forget(id, delete)
    local rec = Horse.peds[id]
    if rec and delete and DoesEntityExist(rec.ped) then
        SetEntityAsMissionEntity(rec.ped, true, true)
        DeleteEntity(rec.ped)
    end
    Horse.peds[id] = nil
    N.blipRemove(Horse.blips[id])
    Horse.blips[id] = nil
    if Horse.cur and Horse.cur.id == id then Horse.cur, Horse.follow = nil, false end
end
Horse.forget = forget

-- put a horse away from the world (flee, cull, interior): cores saved, server marks it in
function Horse.despawn(id, viaServer)
    local rec = Horse.peds[id]
    if rec and DoesEntityExist(rec.ped) then Cores.save(id, rec.ped, true) end
    forget(id, true)
    if viaServer ~= false then CreateThread(function() Call('horseGone', id) end) end
end

function Horse.curPed()
    local c = Horse.cur
    if c and DoesEntityExist(c.ped) then return c.ped, c end
    return nil
end

-- mounted, led, or the current spawned horse
exports('GetMyHorsePed', function()
    local me = PlayerPedId()
    local mount = GetMount(me)
    if mount and mount ~= 0 and Entity(mount).state.pup_stable_horseOwner == GetPlayerServerId(PlayerId()) then return mount end
    if N.leading(me) then
        local led = N.ledHorse(me)
        if led and led ~= 0 and Entity(led).state.pup_stable_horseOwner == GetPlayerServerId(PlayerId()) then return led end
    end
    return (Horse.curPed())
end)

------------------------------------------------------------------------------
-- whistling a horse in
------------------------------------------------------------------------------
local function spawnPoint()
    local me = PlayerPedId()
    local p = GetEntityCoords(me)
    local fwd = GetEntityForwardVector(me)
    local want = p + fwd * H.whistleAhead
    for _, z in ipairs(H.badGroundZones) do
        if #(vector2(p.x, p.y) - vector2(z.x, z.y)) <= (z.radius or 30.0) then return vector4(want.x, want.y, p.z, GetEntityHeading(me)) end
    end
    local radius = H.whistleSearch
    if InTown(p, Config.Wagon.noCallTowns) then radius = radius / 1.75 end
    local ok, node = GetClosestVehicleNode(want.x, want.y, want.z, 1, 3.0, 0.0)
    if ok and node and #(node - want) <= radius then return vector4(node.x, node.y, node.z, GetEntityHeading(me)) end
    for step = 5.0, 100.0, 5.0 do
        local tryP = p + fwd * step
        local okG, gz = GetGroundZFor_3dCoord(tryP.x, tryP.y, tryP.z + 10.0, false)
        if okG and gz ~= 0.0 then
            return vector4(tryP.x, tryP.y, gz, GetEntityHeading(me))
        end
    end
    local close = p + fwd * 2.0
    return vector4(close.x, close.y, p.z, GetEntityHeading(me))
end

function Horse.spawnNear(row)
    if Horse.spawning then return nil end
    Horse.spawning = true
    local ped = nil
    for attempt = 1, 2 do
        local at = spawnPoint()
        ped = Look.spawnHorse(row, at, true, true, true)
        if ped and DoesEntityExist(ped) then break end
        ped = nil
        if attempt == 1 then Wait(500) end
    end
    if ped then
        Horse.adopt(row, ped)
        SetEntityAlpha(ped, 0, false)
        SetEntityInvincible(ped, true)
        CreateThread(function()
            for a = 0, 255, 51 do SetEntityAlpha(ped, a, false) Wait(60) end
            ResetEntityAlpha(ped)
            Wait(2000)
            if DoesEntityExist(ped) and IsEntityInAir(ped) then
                local me = GetEntityCoords(PlayerPedId())
                SetEntityCoords(ped, me.x + 1.5, me.y, me.z, false, false, false, false)
            end
            Wait(math.max(0, H.invincibleMs - 2300))
            if DoesEntityExist(ped) then SetEntityInvincible(ped, false) end
        end)
        TaskGoToEntity(ped, PlayerPedId(), -1, 2.0, 2.0, 0, 0)
    end
    Horse.spawning = false
    return ped
end

local function noWhistleHere()
    return InTown(GetEntityCoords(PlayerPedId()), H.noWhistleTowns)
end

function Horse.whistle()
    local ped, cur = Horse.curPed()
    local me = PlayerPedId()
    if ped then
        if IsEntityDead(ped) then
            local ok, payload = CallTip('whistleRevive', cur.id)
            if ok then
                forget(cur.id, true)
                SetHorse(payload)
                Horse.spawnNear(payload)
            end
            return
        end
        local d = #(GetEntityCoords(ped) - GetEntityCoords(me))
        if d > H.whistleTeleport then
            if H.realistic then return Tip(L('tooFarTo', L('verbWhistle'))) end
            Horse.despawn(cur.id, false)
            Horse.spawnNear(cur.row)
            return
        end
        if cur.fled then
            cur.fled = nil
            ClearPedTasks(ped)
            Cores.restore(cur.id, ped)
        end
        ClearPedTasks(ped)
        TaskGoToEntity(ped, me, -1, 2.0, 2.0, 0, 0)
        return
    end
    if noWhistleHere() then return Tip(L('noWhistleHere')) end
    local fav = FavouriteHorse()
    if not fav then
        if not RefreshHorses() then return end
        fav = FavouriteHorse()
    end
    if not fav then return Tip(L('noFavourite')) end
    if fav.isDead then
        local ok, payload = CallTip('whistleRevive', fav.id)
        if ok then SetHorse(payload); Horse.spawnNear(payload) end
        return
    end
    local ok, payload = CallTip('whistle')
    if not ok then return end
    SetHorse(payload)
    local spawned = Horse.spawnNear(payload)
    if spawned then Cores.restore(payload.id, spawned) end
end

------------------------------------------------------------------------------
-- follow (long whistle)
------------------------------------------------------------------------------
local ignoreFollowUntil = 0
function Horse.ignoreFollow(ms) ignoreFollowUntil = GetGameTimer() + ms end

function Horse.toggleFollow()
    if GetGameTimer() < ignoreFollowUntil then return end
    local ped = Horse.curPed()
    if not ped then return end
    Horse.follow = not Horse.follow
    if not Horse.follow then ClearPedTasks(ped) end
    Horse.cur.blipLabel = nil
    if Horse.peds[Horse.cur.id] then Horse.peds[Horse.cur.id].blipLabel = nil end
    Horse.refreshBlips()
end

CreateThread(function()
    while true do
        local wait = 1000
        local ped = Horse.follow and Horse.curPed()
        if ped then
            wait = 750
            local me = PlayerPedId()
            if GetMount(me) == ped or N.leading(me) or IsEntityDead(ped) then
                Horse.follow = false
                Horse.refreshBlips()
            else
                local d = #(GetEntityCoords(ped) - GetEntityCoords(me))
                local speed = d < 10.0 and 1.0 or (d < 30.0 and 2.0 or 3.0)
                if d > 3.0 then TaskGoToEntity(ped, me, -1, 2.5, speed, 0, 0) end
            end
        end
        Wait(wait)
    end
end)

------------------------------------------------------------------------------
-- whistle keys, jump block, death watch, culling, cores while riding
------------------------------------------------------------------------------
-- no jumping from horse to horse; the whistle is held off while a horse is spawning
CreateThread(function()
    while true do
        local me = PlayerPedId()
        if (H.noHorseJump and IsPedOnMount(me)) or Horse.spawning then
            if H.noHorseJump and IsPedOnMount(me) then DisableControlAction(0, Config.Keys.jump, true) end
            if Horse.spawning then DisableControlAction(0, Config.Keys.whistle, true) end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- short whistle calls, a long one toggles follow
Keys.on(Config.Keys.whistle, function(held)
    if Horse.spawning or IsEntityDead(PlayerPedId()) then return end
    if held >= 600 then Horse.toggleFollow() else Horse.whistle() end
end)

CreateThread(function()
    local lastCores = 0
    while true do
        Wait(1000)
        local me = PlayerPedId()
        local myPos = GetEntityCoords(me)
        for id, rec in pairs(Horse.peds) do
            local ped = rec.ped
            if not DoesEntityExist(ped) then
                forget(id, false)
            elseif IsEntityDead(ped) then
                if not rec.deadSent then
                    rec.deadSent = true
                    local net = NetIdOf(ped)
                    CreateThread(function()
                        if net and Call('horseDied', net) then
                            if Me.horses[id] then Me.horses[id].isDead = true end
                        end
                    end)
                end
            elseif #(GetEntityCoords(ped) - myPos) > H.cullDistance and GetMount(me) ~= ped then
                Horse.despawn(id)
            end
        end
        local ped, cur = Horse.curPed()
        if ped and GetMount(me) == ped and GetGameTimer() - lastCores >= 15000 then
            lastCores = GetGameTimer()
            Cores.save(cur.id, ped)
        end
    end
end)

------------------------------------------------------------------------------
-- flee
------------------------------------------------------------------------------
function Horse.flee(ped)
    if not H.allowFlee then return Tip(L('fleeOff')) end
    local id = nil
    for hid, rec in pairs(Horse.peds) do if rec.ped == ped then id = hid end end
    if not id then return Tip(L('cantFlee')) end
    Cores.save(id, ped, true)
    local cur = Horse.cur
    if cur and cur.id == id then cur.fled = true end
    SetEntityInvincible(ped, true)
    TaskSmartFleePed(ped, PlayerPedId(), 500.0, -1, 0, 0, 0)
    SetTimeout(H.fleeDeleteMs, function()
        local c = Horse.cur
        if Horse.peds[id] and (not c or c.id ~= id or c.fled) then Horse.despawn(id) end
    end)
end

local function nearestOwn(radius)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, radius
    for _, rec in pairs(Horse.peds) do
        if DoesEntityExist(rec.ped) then
            local d = #(GetEntityCoords(rec.ped) - me)
            if d <= bestD then best, bestD = rec.ped, d end
        end
    end
    return best
end
Horse.nearestOwn = nearestOwn

if Config.Commands.fleeHorse then
    RegisterCommand(Config.Commands.fleeHorse, function()
        local ped = nearestOwn(3.0)
        if not ped then return Tip(L('cantFlee')) end
        Horse.flee(ped)
    end, false)
end

-- the game's own flee prompt on a horse
CreateThread(function()
    while true do
        local wait = 500
        local target = N.targetEntity()
        if target and IsEntityAPed(target) and GetPedType(target) == 28 then
            wait = 0
            if IsControlJustPressed(0, Config.Keys.flee) then
                local mine = false
                for _, rec in pairs(Horse.peds) do if rec.ped == target then mine = true end end
                if mine then Horse.flee(target) elseif Entity(target).state.pup_stable_horseID then Tip(L('cantFlee')) end
            end
        end
        Wait(wait)
    end
end)

------------------------------------------------------------------------------
-- bond commands
------------------------------------------------------------------------------
local function bondCommand(level, run)
    local ped, cur = Horse.curPed()
    if not ped then return Tip(L('noHorseOut')) end
    local me = PlayerPedId()
    if IsPedOnMount(me) then return Tip(L('dismountFirst')) end
    if #(GetEntityCoords(ped) - GetEntityCoords(me)) > Config.Bonding.commandDistance then return Tip(L('tooFarHorse')) end
    local st = Entity(ped).state.pup_stable_horse_stats or cur.row
    if U.bondLevel(U.int(st.bonding, 0)) < level then return Tip(L('needBond', level)) end
    NetworkRequestControlOfEntity(ped)
    local deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < deadline do Wait(50) end
    if not NetworkHasControlOfEntity(ped) then return Tip(L('noControl')) end
    run(ped, cur)
end

local function scenario(name, ms)
    return function(ped)
        ClearPedTasks(ped)
        TaskStartScenarioInPlace(ped, joaat(name), ms or -1, true, false, false, false)
    end
end

local CMD = {
    horseRest = { 2, scenario('WORLD_ANIMAL_HORSE_RESTING_DOZING', 300000) },
    horseSleep = { 2, scenario('WORLD_ANIMAL_HORSE_SLEEPING', -1) },
    horseWallow = { 4, scenario('WORLD_ANIMAL_HORSE_WALLOW', -1) },
    horseDrink = { 3, function(ped, cur)
        if not IsEntityInWater(ped) then return Tip(L('needWater')) end
        ClearPedTasks(ped)
        TaskStartScenarioInPlace(ped, joaat('WORLD_ANIMAL_HORSE_DRINK_GROUND'), 6000, true, false, false, false)
        SetTimeout(3500, function()
            if DoesEntityExist(ped) then
                N.setCore(ped, 1, math.min(100, (N.core(ped, 1) or 0) + Config.Bonding.drinkStamina))
                Cores.save(cur.id, ped, true)
            end
        end)
    end },
}

for key, def in pairs(CMD) do
    local name = Config.Commands[key]
    if name then RegisterCommand(name, function() bondCommand(def[1], def[2]) end, false) end
end

------------------------------------------------------------------------------
-- state published on horses: stats, height, death
------------------------------------------------------------------------------
local function entOfBag(bagName)
    local ent = GetEntityFromStateBagName(bagName)
    if ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

AddStateBagChangeHandler('pup_stable_horse_stats', nil, function(bagName, _, value)
    local ent = entOfBag(bagName)
    if not ent or type(value) ~= 'table' then return end
    Look.applyStats(ent, value)
    local mine = Entity(ent).state.pup_stable_horseOwner == GetPlayerServerId(PlayerId())
    bondFlags(ent, value, mine)
end)

AddStateBagChangeHandler('pup_stable_horseScale', nil, function(bagName, _, value)
    local ent = entOfBag(bagName)
    if ent and value then N.scale(ent, value) end
end)

-- XP feedback for trainer owners: one toast, and the game's bars nudged (never to full)
RegisterNetEvent('pup-stable:xpFeedback', function(_, total, gains)
    TriggerEvent('vorp:LeftRank', L('horseXP'), ('+%d XP'):format(U.int(total, 0)), 'toasts_mp_generic', 'toast_mp_horse_bonding', 4000, 'COLOR_WHITE')
    if not Config.Training.feedback.nudgeBars then return end
    local ped = Horse.curPed()
    if not ped or type(gains) ~= 'table' then return end
    for stat, n in pairs(gains) do
        local a = N.ATTR[stat]
        if a and (stat == 'speed' or stat == 'acceleration' or stat == 'handling') then
            local cur, max = N.points(ped, a) or 0, N.maxPoints(ped, a) or 0
            local room = max - cur - 1
            if room > 0 then N.addPoints(ped, a, math.min(room, U.int(n, 0))) end
        end
    end
end)

-- the server re-dresses a horse shortly after it came out (and after colour changes)
RegisterNetEvent('pup-stable:redress', function(netId, row)
    local ent = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
    if ent == 0 or not DoesEntityExist(ent) or type(row) ~= 'table' then return end
    SetHorse(row)
    Look.dress(ent, row.comps, true)
    if row.scale and math.abs(row.scale - 1.0) > 0.001 then N.scale(ent, row.scale) end
    local rec = Horse.peds[row.id]
    if rec then rec.row = row end
end)

------------------------------------------------------------------------------
-- finding my horses again (character selected, after instances, resource restart)
------------------------------------------------------------------------------
function Horse.refind()
    local myId = GetPlayerServerId(PlayerId())
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, math.huge
    for _, ped in ipairs(GetGamePool('CPed')) do
        local st = Entity(ped).state
        local id = U.int(st.pup_stable_horseID)
        if id and st.pup_stable_horseOwner == myId and Me.horses[id] then
            if not Horse.peds[id] or Horse.peds[id].ped ~= ped then
                Horse.peds[id] = { ped = ped, row = Me.horses[id], spawnedAt = 0 }
            end
            local d = #(GetEntityCoords(ped) - me)
            if d < bestD then best, bestD = id, d end
        end
    end
    if best and (not Horse.cur or Horse.cur.id ~= best) then
        Horse.cur = { id = best, ped = Horse.peds[best].ped, row = Me.horses[best] }
    end
    for id, rec in pairs(Horse.peds) do
        if DoesEntityExist(rec.ped) then
            ownerFlags(rec.ped)
            bondFlags(rec.ped, Entity(rec.ped).state.pup_stable_horse_stats or rec.row, true)
            rec.blipLabel = nil
        else
            forget(id, false)
        end
    end
    Horse.refreshBlips()
end

RegisterNetEvent('pup-stable:refind', function()
    CreateThread(function()
        Horse.peds, Horse.cur = {}, nil
        for _, b in pairs(Horse.blips) do N.blipRemove(b) end
        Horse.blips = {}
        RefreshHorses()
        RefreshWagons()
        Horse.refind()
        Wagon.refind()
    end)
end)

-- after leaving a routing bucket the handles change: look again every few seconds while it matters
CreateThread(function()
    local lastBucketCheck = 0
    while true do
        Wait(H.instanceResyncMs)
        if Stable and Stable.instanced then
            lastBucketCheck = GetGameTimer()
        elseif lastBucketCheck > 0 and GetGameTimer() - lastBucketCheck < 30000 then
            Horse.refind()
            Wagon.refind()
            local mount = GetMount(PlayerPedId())
            if mount ~= 0 then N.putOnMount(PlayerPedId(), mount, -1) end
            lastBucketCheck = 0
        end
    end
end)

-- pup_realestate / pup_hideouts fire this when the player walks into an interior
AddEventHandler('pup-stable:deletehorse', function()
    if not H.putAwayOnInteriorEvent then return end
    local ped, cur = Horse.curPed()
    if not ped or GetMount(PlayerPedId()) == ped then return end
    Cores.save(cur.id, ped, true)
    forget(cur.id, true)
    CreateThread(function() Call('putAwayCurrent', cur.id) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for _, b in pairs(Horse.blips) do N.blipRemove(b) end
end)
