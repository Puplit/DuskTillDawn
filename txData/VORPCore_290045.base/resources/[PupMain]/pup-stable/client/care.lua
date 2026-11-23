-- pup-stable | caring for a horse: saddlebags, lockers, feeding, items, lanterns, pelts, shoes, the U menu

local K = Config.Keys
local Care = { bagBusy = false, lastB = 0 }

local function myServerId() return GetPlayerServerId(PlayerId()) end

local function stableHorsesNear(radius)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, radius
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Entity(ped).state.pup_stable_horseID then
            local d = #(GetEntityCoords(ped) - me)
            if d <= bestD then best, bestD = ped, d end
        end
    end
    return best
end

local function isMine(ped) return ped and Entity(ped).state.pup_stable_horseOwner == myServerId() end

------------------------------------------------------------------------------
-- saddlebag: walk to the side, loot animation until the inventory closes
------------------------------------------------------------------------------
local invOpen = false
AddEventHandler('vorp_stables:setClosedInv', function(state) invOpen = state == true end)
AddEventHandler('pup:closeinv', function() invOpen = false end)

function Care.openBag(horse)
    if Care.bagBusy then return end
    local st = Entity(horse).state
    if not st.pup_stable_saddlebagID then return Tip(L('noSaddlebag')) end
    local net = NetIdOf(horse)
    if not net then return end
    Care.bagBusy = true
    local me = PlayerPedId()
    local side = GetOffsetFromEntityInWorldCoords(horse, -0.9, -0.3, 0.0)
    TaskGoStraightToCoord(me, side.x, side.y, side.z, 1.0, 3000, GetEntityHeading(horse) - 90.0, 0.3)
    local t0 = GetGameTimer()
    while GetGameTimer() - t0 < 3000 and #(GetEntityCoords(me) - side) > 0.6 do Wait(100) end
    SetPedConfigFlag(horse, 113, true)
    local ok = CallTip('openBag', net)
    if ok and LoadDict('mech_inventory@saddlebag@loot') then
        invOpen = true
        TaskPlayAnim(me, 'mech_inventory@saddlebag@loot', 'loot_loop', 4.0, -4.0, -1, 1, 0.0, false, false, false)
        local start = GetGameTimer()
        local origin = GetEntityCoords(me)
        Wait(500)
        while invOpen and not IsPedOnMount(me) and #(GetEntityCoords(me) - origin) <= 5.0 and GetGameTimer() - start < 300000 do Wait(250) end
        StopAnimTask(me, 'mech_inventory@saddlebag@loot', 'loot_loop', 1.0)
    end
    if DoesEntityExist(horse) then
        Horse.bondFlags(horse, Entity(horse).state.pup_stable_horse_stats, isMine(horse))
    end
    Care.bagBusy = false
end

Keys.on(K.saddlebag, function()
    if GetGameTimer() - Care.lastB < 800 then return end
    Care.lastB = GetGameTimer()
    local me = PlayerPedId()
    if IsPedOnMount(me) or IsPedInAnyVehicle(me, false) then return end
    local horse = stableHorsesNear(2.5)
    if horse and Entity(horse).state.pup_stable_saddlebagID then return Care.openBag(horse) end
    local veh = Wagon.stableWagonNear(2.0)
    if veh then return Wagon.openLocker(veh) end
end)

------------------------------------------------------------------------------
-- feeding, brushing, stims
------------------------------------------------------------------------------
local function playFeed(horse, it)
    local me = PlayerPedId()
    if IsPedOnMount(me) then
        if not Config.Bonding.feedWhenMounted then return end
        if LoadDict('mech_inventory@eating@horse') then
            TaskPlayAnim(me, 'mech_inventory@eating@horse', 'feed_horse_mounted', 4.0, -4.0, 3000, 0, 0.0, false, false, false)
        end
    else
        TaskTurnPedToFaceEntity(me, horse, 800)
        Wait(800)
        local prop = nil
        if it.prop and LoadModel(it.prop) then
            prop = CreateObject(joaat(it.prop), 0.0, 0.0, 0.0, true, true, false, false, false)
            AttachEntityToEntity(prop, me, GetEntityBoneIndexByName(me, 'SKEL_R_Finger12'), 0.02, -0.02, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true, false, false)
        end
        if LoadDict('mech_inventory@eating@horse') then
            TaskPlayAnim(me, 'mech_inventory@eating@horse', 'feed_horse', 4.0, -4.0, 3500, 0, 0.0, false, false, false)
        end
        Wait(3500)
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    end
end

local function applyCare(horse, it)
    N.setCore(horse, 0, math.min(100, (N.core(horse, 0) or 0) + (it.health or 0)))
    N.setCore(horse, 1, math.min(100, (N.core(horse, 1) or 0) + (it.stamina or 0)))
    pcall(function() PlaySoundFrontend('Core_Fill_Up', 'Consumption_Sounds', true, 0) end)
    local id = U.int(Entity(horse).state.pup_stable_horseID)
    if id and Horse.peds[id] then Cores.save(id, horse, true) end
end

RegisterNetEvent('pup-stable:useItem', function(name)
    local it = Config.Items[name]
    if not it then return end
    local horse = stableHorsesNear(Config.CareReach.client)
    if not horse then return Tip(L('noHorseNear')) end
    if IsEntityDead(horse) then return Tip(L('beyondMedicine')) end
    local net = NetIdOf(horse)
    if not net then return end
    local ok, def = CallTip('careUse', name, net)
    if not ok then return end
    def = type(def) == 'table' and def or it
    local me = PlayerPedId()
    if it.kind == 'feed' then
        playFeed(horse, it)
        applyCare(horse, it)
    elseif it.kind == 'brush' then
        if IsPedOnMount(me) then return end
        TaskTurnPedToFaceEntity(me, horse, 800)
        Wait(800)
        if LoadDict('mech_inventory@item@horse_brush@unarmed') then
            TaskPlayAnim(me, 'mech_inventory@item@horse_brush@unarmed', 'brush_horse_side', 4.0, -4.0, 4000, 0, 0.0, false, false, false)
        end
        Wait(4000)
        N.cleanDirt(horse)
    elseif it.kind == 'stim' then
        if LoadDict('mech_inventory@item@stimulants@inject@quick') then
            TaskPlayAnim(me, 'mech_inventory@item@stimulants@inject@quick', 'quick_stimulant_inject_lhand', 4.0, -4.0, 2500, 0, 0.0, false, false, false)
        end
        Wait(2500)
        applyCare(horse, it)
        if it.overpower then
            N.overpower(horse, 0, it.overpower[1])
            N.overpower(horse, 1, it.overpower[2])
        end
        Tip(L('stimWorks'))
    end
end)

------------------------------------------------------------------------------
-- prompts on a targeted horse: saddlebag, lantern, shoes, feeding; and pelts beside it
------------------------------------------------------------------------------
local tgtGroup = nil
local pTakeBag, pPutBag, pTakeLantern, pPutLantern, pShoes, pStow, pDrop, pUnstow
local promptHorse = nil

local function buildTargetPrompts(horse)
    if promptHorse == horse then return end
    promptHorse = horse
    local g = N.entityGroup(horse)
    if tgtGroup == g and pTakeBag then return end
    tgtGroup = g
    for _, p in ipairs({ pTakeBag, pPutBag, pTakeLantern, pPutLantern, pShoes }) do N.promptDelete(p) end
    pTakeBag = N.prompt(K.takeBag, L('takeSaddlebag'), 1000, g)
    pPutBag = N.prompt(K.takeBag, L('putSaddlebag'), 1000, g)
    pTakeLantern = N.prompt(K.lantern, L('takeLantern'), nil, g)
    pPutLantern = N.prompt(K.lantern, L('putLantern'), nil, g)
    pShoes = N.prompt(K.shoes, L('checkShoes'), nil, g)
end

local carry = function() return LocalPlayer.state.pup_stable_carry or {} end

local function carryNow(key, comp)
    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline do
        if (carry()[key] ~= nil) == (comp ~= nil) then return true end
        Wait(50)
    end
    return false
end

local function shoeState(horse)
    local st = Entity(horse).state
    local dist = U.int(st.pup_stable_stat_distance, 0) - U.int(st.pup_stable_stat_lastNewShoes, 0)
    return 1 - dist / (Config.Shoes.lifeKm * 1000)
end

local function onTarget(horse)
    local st = Entity(horse).state
    local me = PlayerPedId()
    local dist = #(GetEntityCoords(horse) - GetEntityCoords(me))
    local mine = isMine(horse)
    local c = carry()
    buildTargetPrompts(horse)
    local onFoot = not IsPedOnMount(me)
    N.promptShow(pTakeBag, onFoot and mine and st.pup_stable_saddlebagID and true or false)
    N.promptShow(pPutBag, onFoot and mine and not st.pup_stable_saddlebagID and c.saddlebag ~= nil)
    N.promptShow(pTakeLantern, onFoot and dist <= Config.Lantern.promptReach and st.pup_stable_lanternID and true or false, c.lantern == nil)
    N.promptShow(pPutLantern, onFoot and dist <= Config.Lantern.promptReach and not st.pup_stable_lanternID and c.lantern ~= nil)
    N.promptShow(pShoes, Config.Shoes.enabled and onFoot)
    local net = NetIdOf(horse)
    if not net then return end
    if N.promptDone(pTakeBag) then
        if c.saddlebag then return Tip(L('hasSatchel')) end
        CreateThread(function()
            local ok, comp = CallTip('takeBag', net)
            if ok and comp then
                carryNow('saddlebag', comp)
                Look.removeComp(horse, comp.hash)
                N.update(horse)
            end
        end)
    elseif N.promptDone(pPutBag) then
        CreateThread(function()
            local ok, comp = CallTip('putBag', net)
            if ok and comp then N.applyComp(horse, comp.hash) N.update(horse) end
        end)
    elseif N.promptDone(pTakeLantern) then
        CreateThread(function()
            local ok, comp = CallTip('takeLantern', net)
            if ok and comp and carryNow('lantern', comp) then
                Citizen.InvokeNative(0x5E3BDDBCB83F3D84, me, joaat(Config.Lantern.weapon), 0, true, false, 0, false, 0.5, 1.0, 0, false, 0.0, false)
                Look.removeComp(horse, comp.hash)
                N.update(horse)
            end
        end)
    elseif N.promptDone(pPutLantern) then
        CreateThread(function()
            local ok, comp = CallTip('putLantern', net)
            if ok and comp then
                RemoveWeaponFromPed(me, joaat(Config.Lantern.weapon), true, 0)
                N.applyComp(horse, comp.hash)
                N.update(horse)
                if comp.color then Wait(50) Look.paintIndexOf(horse, comp.hash, comp.color.palette, comp.color.tint0, comp.color.tint1, comp.color.tint2) end
            end
        end)
    elseif N.promptDone(pShoes) then
        CreateThread(function()
            TaskTurnPedToFaceEntity(me, horse, 1000)
            Wait(1000)
            Tip(L('shoesState', math.max(0, math.floor(shoeState(horse) * 100))))
        end)
    end
    -- the game's feed interaction on a targeted horse
    if (IsControlJustPressed(0, K.feed) or IsDisabledControlJustPressed(0, K.feed)) and not Care.feeding then
        Care.feeding = true
        CreateThread(function()
            local ok, item, it = CallTip('feed', net)
            if ok and type(it) == 'table' then
                playFeed(horse, it)
                applyCare(horse, it)
            end
            Debug('fed', item)
            Care.feeding = false
        end)
    end
    -- the info key: the game's info card (client/info.lua), plus the trainers' tip on their own horse
    if IsControlJustPressed(0, K.horseInfo) or IsDisabledControlJustPressed(0, K.horseInfo) then
        Info.toggle(horse)
    end
end

CreateThread(function()
    while true do
        local wait = 400
        local target = N.targetEntity()
        if target and IsEntityAPed(target) and Entity(target).state.pup_stable_horseID and not IsEntityDead(target) then
            wait = 0
            onTarget(target)
        elseif promptHorse then
            promptHorse = nil
            for _, p in ipairs({ pTakeBag, pPutBag, pTakeLantern, pPutLantern, pShoes }) do if p then N.promptShow(p, false) end end
        end
        Wait(wait)
    end
end)

------------------------------------------------------------------------------
-- pelts
------------------------------------------------------------------------------
local peltGroup = N.newGroup()
pStow = N.prompt(K.peltStow, L('stowPelt'), 1000, peltGroup)
pDrop = N.prompt(K.peltDrop, L('drop'), 1000, peltGroup)
pUnstow = N.prompt(K.peltStow, L('removePelt'), 1000, peltGroup)

local function claimMount(horse, on)
    if on then N.ownsAnimal(PlayerPedId(), horse, true) end
end

CreateThread(function()
    while true do
        local wait = 600
        local me = PlayerPedId()
        if Config.Pelts.enabled and not IsPedOnMount(me) and not IsPedInAnyVehicle(me, false) then
            local horse = stableHorsesNear(2.0)
            if horse and not IsEntityDead(horse) then
                local carried = N.carrying(me)
                local list = Entity(horse).state.pup_stable_stow or {}
                local mine = isMine(horse)
                local canStow = carried and carried ~= 0 and mine and #list < Config.Pelts.max
                N.promptShow(pStow, canStow)
                N.promptShow(pDrop, carried and carried ~= 0)
                N.promptShow(pUnstow, (not carried or carried == 0) and #list > 0)
                if canStow or (carried and carried ~= 0) or #list > 0 then
                    wait = 0
                    N.groupActive(peltGroup, L('stowPelt'))
                    claimMount(horse, mine)
                end
                local net = NetIdOf(horse)
                if net and N.promptDone(pStow) then
                    local model = GetEntityModel(carried)
                    CreateThread(function()
                        if CallTip('stowPelt', net, 0, model) then
                            N.placeOnMount(me, carried, horse)
                            if #list + 1 > Config.Pelts.visible then
                                Wait(2500)
                                if DoesEntityExist(carried) then SetEntityVisible(carried, false) end
                            end
                        end
                    end)
                elseif N.promptDone(pDrop) then
                    ClearPedTasks(me)
                    Citizen.InvokeNative(0x7DE9692C6F64CFE8, me, false, 0, false) -- drop what is carried
                elseif net and N.promptDone(pUnstow) then
                    CreateThread(function()
                        local ok, top = CallTip('unstowPelt', net)
                        if not ok or type(top) ~= 'table' then return end
                        TaskTurnPedToFaceEntity(me, horse, 800)
                        Wait(800)
                        local p = GetEntityCoords(me)
                        if LoadModel(top.model) then
                            local obj = CreateObject(top.model, p.x, p.y, p.z, true, true, false, false, false)
                            N.pickUp(me, obj)
                        end
                    end)
                end
            else
                N.promptShow(pStow, false) N.promptShow(pDrop, false) N.promptShow(pUnstow, false)
            end
        end
        Wait(wait)
    end
end)

-- another resource (a butcher sale) clears every stowed pelt off a horse
exports('ClearStowedPelts', function(horse)
    if not horse or horse == 0 or not DoesEntityExist(horse) then return 0 end
    local n = 0
    for _, obj in ipairs(GetGamePool('CObject')) do
        if IsEntityAttachedToEntity(obj, horse) then
            n = n + 1
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
    local net = NetIdOf(horse)
    if net then
        local ok, count = Call('clearPelts', net)
        if ok then n = math.max(n, U.int(count, 0)) end
    end
    return n
end)

------------------------------------------------------------------------------
-- horseshoes wear (only when the shoe system is on)
------------------------------------------------------------------------------
if Config.Shoes.enabled then
    CreateThread(function()
        local warned = 0
        while true do
            Wait(1000)
            local me = PlayerPedId()
            local mount = GetMount(me)
            if mount ~= 0 and Entity(mount).state.pup_stable_horseID then
                local s = shoeState(mount)
                if s < Config.Shoes.noRunBelow then
                    SetPedMaxMoveBlendRatio(mount, 1.0)
                    if GetGameTimer() - warned > 60000 then warned = GetGameTimer() Tip(L('shoesShattered')) end
                elseif s < Config.Shoes.warnBelow then
                    SetPedMaxMoveBlendRatio(mount, 2.0)
                    if GetGameTimer() - warned > 120000 then warned = GetGameTimer() Tip(L('shoesDamaged')) end
                end
            end
        end
    end)
end

------------------------------------------------------------------------------
-- the U menu on your own horse
------------------------------------------------------------------------------
local FOCUS = { 'speed', 'acceleration', 'handling', 'health', 'stamina', 'bonding' }

local function ownHorseHere()
    local me = PlayerPedId()
    local mount = GetMount(me)
    if mount ~= 0 and isMine(mount) then return mount end
    if N.leading(me) then
        local led = N.ledHorse(me)
        if led ~= 0 and isMine(led) then return led end
    end
    return nil
end

local function horseMenu(horse, p, trainer)
    local lv = U.level(p.xp or 0)
    local levels = Config.Training.levels
    local nextXp = levels[lv + 1]
    local c = Config.Training.ceilings
    local cap = Config.Training.capPerLevel[lv] or 10
    local header = {
        { kind = 'text', label = L('horseLevel', lv), raw = true, value = nextXp and ('%d / %d XP'):format(p.xp, nextXp) or ('%d XP - MAX'):format(p.xp) },
        { kind = 'fraction', label = 'speed', cur = p.speed, max = c.speed },
        { kind = 'fraction', label = 'acceleration', cur = p.acceleration, max = c.acceleration },
        { kind = 'fraction', label = 'handling', cur = p.handling, max = c.handling },
        { kind = 'fraction', label = 'health', cur = U.rankFromPoints(p.health), max = 10 },
        { kind = 'fraction', label = 'stamina', cur = U.rankFromPoints(p.stamina), max = 10 },
        { kind = 'fraction', label = 'bondingLevel', cur = U.bondLevel(p.bonding), max = 4 },
    }
    local items = { { id = 'bag', title = 'openSaddlebag', icon = 'bag', stats = header, actions = { { act = 'bag', label = 'select', key = 'Enter' } } } }
    if trainer then
        for _, stat in ipairs(FOCUS) do
            local status
            if stat == 'speed' or stat == 'acceleration' or stat == 'handling' then
                local limit = stat == 'handling' and c.handling or math.min(c[stat], cap)
                if p[stat] >= c[stat] then status = L('breedLimit')
                elseif p[stat] >= limit then status = L('raiseLevel')
                else status = ('%d / %d XP'):format(p.wallets[stat] or 0, Config.Training.rankCost[stat]) end
            else
                status = ('%s: %d'):format(L('points'), U.int(p[stat], 0))
            end
            local desc = Locale.focusDesc[stat] .. '<br>' .. status
            if p.focus == stat then desc = desc .. '<br><b>' .. L('currentFocus') .. '</b>' end
            items[#items + 1] = { id = stat, title = stat, prefix = p.focus == stat and 'star' or nil, desc = desc, stats = header,
                actions = { { act = 'focus', label = 'setFocus', key = 'Enter' } } }
        end
    end
    Ui.menus = {}
    Ui.menu({ id = 'hmenu', title = trainer and L('horseTraining') or p.name, raw = true, items = items })
    Ui.header(p.name, true)
    Ui.root('hmenu')
    if Ui.open then return end
    Ui.show({
        onAction = function(_, it, a)
            if a == 'bag' then
                Ui.hide(true)
                Care.openBag(horse)
            elseif a == 'focus' then
                local net = NetIdOf(horse)
                local ok, focus = CallTip('setFocus', net, it.id)
                if ok then
                    p.focus = focus
                    horseMenu(horse, p, trainer)
                end
            end
        end,
    })
end

Keys.on(K.menu, function()
    local horse = ownHorseHere()
    if not horse then return end
    local net = NetIdOf(horse)
    if not net then return end
    local p = promise.new()
    CreateThread(function() p:resolve(table.pack(Call('horsePanel', net))) end)
    SetTimeout(2000, function() p:resolve({ false, n = 1 }) end)
    local res = Citizen.Await(p)
    if not res[1] or type(res[2]) ~= 'table' then return end
    horseMenu(horse, res[2], res[3] == true)
end)

------------------------------------------------------------------------------
-- the coat tonic: recolour your favourite horse where it stands
------------------------------------------------------------------------------
RegisterNetEvent('pup-stable:coatChanger', function()
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    local nearStable = false
    for _, s in pairs(Config.Stables) do
        if #(pos - vector3(s.location.x, s.location.y, s.location.z)) <= Config.Colors.coatChangerStableReach then nearStable = true end
    end
    if not nearStable then return Tip(L('nearStable')) end
    local fav = FavouriteHorse()
    local rec = fav and Horse.peds[fav.id]
    if not rec or not DoesEntityExist(rec.ped) or #(GetEntityCoords(rec.ped) - pos) > Config.Colors.coatChangerHorseReach then return Tip(L('mustBeOut')) end
    Coat.edit(fav, rec.ped)
end)

Coat = {}

function Coat.edit(row, ped)
    local m = Menus.builders.palette('coatSave')
    Menus.palCtx = { mode = 'coatSave', horse = row.id }
    Ui.menus = {}
    Ui.menu(m)
    Ui.header('changeCoat')
    Ui.root(m.id)
    Stable.camTarget = nil
    Stable.aimCamera(ped)
    local saved = false
    Ui.show({
        onRotate = Stable.rotate,
        onPreview = function(_, _, sl)
            local pals = Config.Colors.palettes
            local pp = pals[(U.int(sl[1], 0) % #pals) + 1]
            Look.paintCoat(ped, 'metaped_' .. pp.id, U.int(sl[2], 0), U.int(sl[3], 0), U.int(sl[4], 0), U.int(sl[5], 0), U.int(sl[6], 0))
        end,
        onAction = function(_, _, a, sl)
            if a ~= 'save' then return end
            local pals = Config.Colors.palettes
            local pp = pals[(U.int(sl[1], 0) % #pals) + 1]
            local color = { palette = 'metaped_' .. pp.id, tint0 = U.int(sl[2], 0), tint1 = U.int(sl[3], 0), tint2 = U.int(sl[4], 0), bodyTint1 = U.int(sl[5], 0), bodyTint2 = U.int(sl[6], 0) }
            color.head, color.body = Look.coatGuids(ped)
            local ok, payload = CallTip('saveCoat', row.id, color)
            if ok then saved = true SetHorse(payload) Ui.hide(true) end
        end,
        onClose = function()
            Stable.dropCamera()
            -- Back reverts the colours
            if not saved and DoesEntityExist(ped) then Look.dress(ped, (Me.horses[row.id] or row).comps, true) end
        end,
    })
end
