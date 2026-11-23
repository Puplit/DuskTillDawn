-- pup-misc / pets - client half. Up to PetsConfig.General.maxPets animals out at once, each keyed by the whistle item that called it

local pets = {}   -- item -> ped
local order = {}  -- items in the order they came out; decides which follow slot each one walks in
local petNames = {} -- item -> the name on the whistle that called it, for the tips

local function dbg(msg)
    if PetsConfig and PetsConfig.General.debug then
        print('^3[pup-misc:pets]^7 ' .. tostring(msg))
    end
end

local function slotOf(item)
    for i, v in ipairs(order) do
        if v == item then return i end
    end
    return 1
end

local function forget(item)
    pets[item] = nil
    petNames[item] = nil
    for i, v in ipairs(order) do
        if v == item then table.remove(order, i) break end
    end
end

local function despawn(item, silent)
    local ped = pets[item]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    if ped and not silent then
        TriggerServerEvent('pup-misc:pets:cleared', item)
    end
    forget(item)
end

local function despawnAll(silent)
    for item in pairs(pets) do despawn(item, silent) end
end

--- Bounded: an unchecked wait here hangs the thread forever on a bad model name.
local function loadModel(name)
    local hash <const> = GetHashKey(name)
    if not IsModelInCdimage(hash) then
        print(('^1[pup-misc:pets]^7 model not in the game files: %s'):format(tostring(name)))
        return nil
    end
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    if not HasModelLoaded(hash) then
        print(('^1[pup-misc:pets]^7 model failed to load: %s'):format(tostring(name)))
        return nil
    end
    return hash
end

--- SetPedScale alone does not render - it needs the variation push after it.
local function setPetScale(ped, scale)
    if not ped or not DoesEntityExist(ped) then return end
    local lo <const> = (PetsConfig and PetsConfig.Scale.min) or 0.2
    local hi <const> = (PetsConfig and PetsConfig.Scale.max) or 3.0
    scale = math.min(math.max(tonumber(scale) or 1.0, lo), hi)
    Citizen.InvokeNative(0x25ACFC650B65C538, ped, scale + 0.0) -- SetPedScale
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    return scale
end

-- each pet gets its own spot behind you (slot 1 left of centre, slot 2 right, ...) so two never fight for the same patch
local function followOffset(slot)
    local base <const> = (PetsConfig and PetsConfig.Follow.offset) or { x = 0.0, y = -1.5, z = 0.0 }
    local spread <const> = (PetsConfig and PetsConfig.Follow.spread) or 1.2
    local side = 0.0
    if slot == 2 then side = spread
    elseif slot > 2 then side = (slot % 2 == 0) and spread * (slot / 2) or -spread * ((slot - 1) / 2)
    elseif slot == 1 and #order > 1 then side = -spread * 0.5 end
    return (base.x or 0.0) + side, base.y or -1.5, base.z or 0.0
end

-- pets must not spook horses: the pet moves into a group of ours that hates nothing
local PET_GROUP
local calmedGroups = {}

local function petGroup()
    if PET_GROUP then return PET_GROUP end
    local _, g = AddRelationshipGroup('PUP_PET')
    PET_GROUP = (g and g ~= 0) and g or GetHashKey('PUP_PET')
    SetRelationshipBetweenGroups(0, PET_GROUP, `PLAYER`)
    SetRelationshipBetweenGroups(0, `PLAYER`, PET_GROUP)
    SetRelationshipBetweenGroups(0, PET_GROUP, PET_GROUP)
    return PET_GROUP
end

-- tell one group and ours to leave each other alone; done once per group
local function calmTowards(group)
    if not group or group == 0 or calmedGroups[group] then return end
    calmedGroups[group] = true
    local mine <const> = petGroup()
    SetRelationshipBetweenGroups(0, mine, group)
    SetRelationshipBetweenGroups(0, group, mine)
end

-- a horse's fear is its own setting (pup-stable turns it off only above 800 bonding), so calm it here;
-- 312 (gunshot flee) is left alone so gunfire still spooks it
local function braveHorse(horse)
    if not horse or horse == 0 or not DoesEntityExist(horse) then return end
    calmTowards(GetPedRelationshipGroupHash(horse))
    SetPedConfigFlag(horse, 113, true)        -- PCF_DisableShockingEvents
    SetAnimalTuningBoolParam(horse, 25, true) -- bravery / frightened
    SetPedFleeAttributes(horse, 0, false)
end

-- mounted, led, or whistled and still walking over; the last of those is when it bolted
local function myHorse()
    local ok, horse = pcall(function() return exports['pup-stable']:GetMyHorsePed() end)
    return ok and horse or nil
end

local function tamePet(ped)
    if not ped or not DoesEntityExist(ped) then return end
    SetPedRelationshipGroupHash(ped, petGroup())

    -- a predator near a horse is a shocking event whatever the relationship; 217 stops this ped giving them off
    SetPedConfigFlag(ped, 217, true)  -- PCF_SupressShockingEvents
    SetPedConfigFlag(ped, 111, true)  -- PCF_DisableWeirdPedEvents
end

-- SetBlockingOfNonTemporaryEvents is what stops the animal wandering off after ambient distractions
local function taskFollow(ped, slot)
    local me <const> = PlayerPedId()
    local x, y, z = followOffset(slot or 1)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskGoToEntity(ped, me, -1, 1.0, 2.5, 0, 0)
    Citizen.InvokeNative(0x489FFCCCE7392B55, ped, me) -- follow
    TaskFollowToOffsetOfEntity(ped, me, x + 0.0, y + 0.0, z + 0.0,
        1.0, -1, 5 * 100000000, 1, 1, 0, 0, 1)
end

local sitting = false   -- set by /petsit; the recall loop leaves a sat pet alone
local hunting = false   -- set by /pethunt
local fetching = false  -- a retrieve is in flight
local retrieved = {}    -- carcasses already brought back

local function refollowAll()
    sitting = false
    for i, item in ipairs(order) do
        local ped = pets[item]
        if ped and DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            taskFollow(ped, i)
        end
    end
end

-- ORDERS
local function sitEntryFor(model)
    local m = tostring(model or ''):lower()
    for _, row in ipairs((PetsConfig.Anims or {}).sit or {}) do
        if m:find(row[1], 1, true) then return row end
    end
    return nil
end

-- first dict in the row that loads wins; nil when none of them do
local function loadOneOf(row)
    for i = 3, #row do
        local d = row[i]
        RequestAnimDict(d)
        local waited = 0
        while not HasAnimDictLoaded(d) and waited < 600 do
            Wait(20)
            waited = waited + 20
        end
        if HasAnimDictLoaded(d) then return d end
    end
    return nil
end

local function sitAll()
    local any = false
    for item, ped in pairs(pets) do
        local spec = (PetsConfig.Pets or {})[item]
        local row = spec and sitEntryFor(spec.model)
        if row and ped and DoesEntityExist(ped) then
            local dict = loadOneOf(row)
            if dict then
                ClearPedTasks(ped)
                TaskPlayAnim(ped, dict, row[2], 1.0, 1.0, -1, 1, 0, false, false, false)
                RemoveAnimDict(dict)
                any = true
            else
                print(('^3[pup-misc:pets]^7 no sit dict loaded for %s (%s)'):format(item, tostring(spec.model)))
            end
        end
    end
    return any
end

local function howlEntryFor(model)
    local m <const> = tostring(model or ''):lower()
    for _, row in ipairs((PetsConfig.Anims or {}).howl or {}) do
        if m:find(row[1], 1, true) then return row end
    end
    return nil
end

local function howlAll()
    local any = false
    for item, ped in pairs(pets) do
        local spec = (PetsConfig.Pets or {})[item]
        local row = spec and howlEntryFor(spec.model)
        if row and ped and DoesEntityExist(ped) then
            local dict = loadOneOf(row)
            if dict then
                ClearPedTasks(ped)
                -- one play, not a held pose: the pet goes back to heel after it
                TaskPlayAnim(ped, dict, row[2], 1.0, 1.0, 4000, 0, 0, false, false, false)
                RemoveAnimDict(dict)
                any = true
            else
                -- names the candidates so the working one can be kept and the rest dropped
                print(('^3[pup-misc:pets]^7 no howl dict loaded for %s (%s) - tried: %s')
                    :format(item, tostring(spec.model), table.concat(row, ', ', 3)))
            end
        end
    end
    return any
end

if PetsConfig then
    local CMD <const> = PetsConfig.General.commands or {}

    RegisterCommand(CMD.sit or 'petsit', function()
        if not next(pets) then return TriggerEvent('vorp:TipRight', PetsLocale.noPet, 3000) end
        if sitting then
            sitting = false
            refollowAll()
            return TriggerEvent('vorp:TipRight', PetsLocale.heel, 3000)
        end
        if sitAll() then
            sitting = true
            if PetsConfig.Sit.freezePet then
                for _, ped in pairs(pets) do
                    if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end
                end
            end
            TriggerEvent('vorp:TipRight', PetsLocale.sit, 3000)
        else
            TriggerEvent('vorp:TipRight', PetsLocale.wontSit, 3000)
        end
    end, false)

    local howlAt = 0
    RegisterCommand(CMD.howl or 'pethowl', function()
        if not next(pets) then return TriggerEvent('vorp:TipRight', PetsLocale.noPet, 3000) end

        local gap <const> = (tonumber(PetsConfig.Howl.cooldownSeconds) or 8) * 1000
        if GetGameTimer() - howlAt < gap then return end

        if howlAll() then
            howlAt = GetGameTimer()
            TriggerEvent('vorp:TipRight', PetsLocale.howl, 3000)
            -- back to heel once it is done, unless they were told to sit
            CreateThread(function()
                Wait(4200)
                if not sitting then refollowAll() end
            end)
        else
            TriggerEvent('vorp:TipRight', PetsLocale.nothingToSay, 3000)
        end
    end, false)

    -- ATTACK
    if (PetsConfig.Attack or {}).enabled then
        RegisterCommand(CMD.attack or 'petattack', function()
            local A <const> = PetsConfig.Attack
            if not next(pets) then return TriggerEvent('vorp:TipRight', PetsLocale.noPet, 3000) end

            local me <const> = PlayerId()
            local found, target = GetPlayerTargetEntity(me)
            if not (found and target and DoesEntityExist(target)) or IsEntityDead(target) then
                return TriggerEvent('vorp:TipRight', PetsLocale.aimFirst, 3000)
            end
            if IsPedAPlayer(target) and not A.allowPlayers then
                return TriggerEvent('vorp:TipRight', PetsLocale.notAtPlayer, 3000)
            end
            if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(target)) > (tonumber(A.range) or 30.0) then
                return TriggerEvent('vorp:TipRight', PetsLocale.tooFar, 3000)
            end

            refollowAll()
            for _, ped in pairs(pets) do
                if DoesEntityExist(ped) then
                    ClearPedTasks(ped)
                    SetPedCombatAttributes(ped, 5, true)    -- CA_ALWAYS_FIGHT
                    SetPedCombatAttributes(ped, 17, false)  -- not always flee
                    SetPedCombatAttributes(ped, 58, true)   -- no fleeing from combat
                    TaskCombatPed(ped, target, 0, 16)
                end
            end
            TriggerEvent('vorp:TipRight', PetsLocale.attack, 3000)
        end, false)
    end

    -- TRACK. Sniff, then blip live animals nearby for a while.
    local trackBlips = {}
    if (PetsConfig.Track or {}).enabled then
        RegisterCommand(CMD.track or 'pettrack', function()
            local T <const> = PetsConfig.Track
            local lead = pets[order[1] or '']
            if not lead or not DoesEntityExist(lead) then
                return TriggerEvent('vorp:TipRight', PetsLocale.noPet, 3000)
            end

            for _, b in ipairs(trackBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
            trackBlips = {}

            if T.dict then
                RequestAnimDict(T.dict)
                local w = 0
                while not HasAnimDictLoaded(T.dict) and w < 1000 do Wait(20) w = w + 20 end
                if HasAnimDictLoaded(T.dict) then
                    ClearPedTasks(lead)
                    TaskPlayAnim(lead, T.dict, T.clip or 'base', 1.0, 1.0, 3000, 1, 0, false, false, false)
                    RemoveAnimDict(T.dict)
                end
            end

            local me <const> = PlayerPedId()
            local c <const> = GetEntityCoords(me)
            local set = CreateItemset(true)
            local n = Citizen.InvokeNative(0x59B57C4B06531E1E, c, tonumber(T.radius) or 150.0, set, 1, Citizen.ResultAsInteger())
            local marked = 0
            for i = 0, (n or 0) - 1 do
                local p = GetIndexedItemInItemset(i, set)
                if p and p ~= me and p ~= lead and GetPedType(p) == 28 and not IsEntityDead(p) then
                    local pc = GetEntityCoords(p)
                    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, pc.x, pc.y, pc.z)
                    if b then
                        -- 1664425300 is only the blip style; without a sprite it draws the default icon
                        SetBlipSprite(b, tonumber(T.blipSprite) or -1085232344, 1)
                        pcall(function() SetBlipScale(b, tonumber(T.blipScale) or 0.8) end)
                        pcall(function()
                            Citizen.InvokeNative(0x9CB1A1623062F402, b, PetsLocale.scentBlip or 'Scent')
                        end)
                        trackBlips[#trackBlips + 1] = b
                        marked = marked + 1
                    end
                end
            end
            if IsItemsetValid(set) then DestroyItemset(set) end

            SetTimeout(math.max(5, tonumber(T.durationSeconds) or 30) * 1000, function()
                for _, b in ipairs(trackBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
                trackBlips = {}
            end)

            TriggerEvent('vorp:TipRight', marked > 0
                and (PetsLocale.scentFound):format(marked)
                or PetsLocale.scentNone, 4000)
            SetTimeout(3200, function() if not sitting then refollowAll() end end)
        end, false)
    end

    -- HUNT. Toggle: fetch what you kill and drop it at your feet.
    if (PetsConfig.Hunt or {}).enabled then
        RegisterCommand(CMD.hunt or 'pethunt', function()
            if not next(pets) then return TriggerEvent('vorp:TipRight', PetsLocale.noPet, 3000) end
            hunting = not hunting
            if not hunting then refollowAll() end
            TriggerEvent('vorp:TipRight', hunting and PetsLocale.huntOn or PetsLocale.huntOff, 3000)
        end, false)
    end
end

RegisterNetEvent('pup-misc:pets:spawn', function(spec, item)
    dbg(('spawn event received: %s'):format(type(spec) == 'table' and tostring(spec.model) or type(spec)))
    if type(spec) ~= 'table' or not spec.model or not item then return end
    despawn(item, true) -- the same whistle never leaves two behind

    local hash <const> = loadModel(spec.model)
    if not hash then return end

    local me <const> = PlayerPedId()
    local c <const> = GetEntityCoords(me)
    local ped = CreatePed(hash, c.x + 1.0, c.y + 1.0, c.z, GetEntityHeading(me), true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        print(('^1[pup-misc:pets]^7 CreatePed returned nothing for %s'):format(tostring(spec.model)))
        TriggerServerEvent('pup-misc:pets:cleared', item)
        return
    end
    dbg(('ped created: %s at %.1f %.1f %.1f'):format(tostring(ped), c.x, c.y, c.z))

    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255, false)
    pets[item] = ped
    order[#order + 1] = item

    -- the random pass first (or some models stay untextured), then always pin one variant (0 exists on every model)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, tonumber(spec.variant) or 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    setPetScale(ped, tonumber(spec.scale) or PetsConfig.Scale.default or 1.0)

    -- before anything else reacts to it: a predator model keeps its own group otherwise
    tamePet(ped)

    if PetsConfig.Behaviour.invincible then
        SetEntityCanBeDamaged(ped, false)
        SetEntityInvincible(ped, true)
        SetPedCanRagdoll(ped, false)
    end

    -- a pet is not a mount. The watchdog below pulls anyone off who gets on anyway,
    -- because this flag does not survive the ped streaming out and back.
    if PetsConfig.Behaviour.allowRiding ~= true then
        Citizen.InvokeNative(0x2D64376CF437363E, ped, false) -- CanPedBeMounted
    end

    -- the server deletes it by network id if we drop off without putting it away
    local netId = NetworkGetNetworkIdFromEntity(ped)
    if netId and netId ~= 0 then
        -- RedM has no SetNetworkIdCanMigrate wrapper, only the hash
        Citizen.InvokeNative(0x299EEB23175895FC, netId, true)
        TriggerServerEvent('pup-misc:pets:spawned', item, netId)
    end

    petNames[item] = spec.name
    refollowAll()
    dbg(('spawned %s (%s) in slot %d'):format(tostring(spec.label), tostring(spec.model), #order))
    TriggerEvent('vorp:TipRight', (PetsLocale.following):format(spec.name or spec.label or PetsLocale.yourPet), 4000)
end)

RegisterNetEvent('pup-misc:pets:despawn', function(item)
    if item then
        if not pets[item] then return end
        local label <const> = petNames[item]
            or (PetsConfig.Pets[item] and PetsConfig.Pets[item].label)
        despawn(item, true)
        refollowAll()
        TriggerEvent('vorp:TipRight', (PetsLocale.staysBehind):format(label or PetsLocale.yourPet), 4000)
    else
        despawnAll(true)
        TriggerEvent('vorp:TipRight', PetsLocale.allStayBehind, 4000)
    end
end)

-- VARIANT FINDER (PetsConfig.General.debug only)
-- Animal outfit variants are not documented anywhere. Put a pet out, then
--   /petvariant        step to the next one
--   /petvariant 7      jump straight to 7
--   /petvariant -1     back to a random coat
-- The number that looks right is what goes in `variant` in config/pets/pets.lua.
if PetsConfig and PetsConfig.General.debug then
    local probe = -1
    RegisterCommand('petvariant', function(_, args)
        local item <const> = order[#order]
        local ped <const> = item and pets[item]
        if not ped or not DoesEntityExist(ped) then
            return TriggerEvent('vorp:TipRight', 'Put a pet out first.', 4000)
        end

        if args and args[1] then probe = math.floor(tonumber(args[1]) or 0) else probe = probe + 1 end

        if probe < 0 then
            Citizen.InvokeNative(0x283978A15512B2FE, ped, true)  -- random outfit
        else
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, probe)
        end
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)  -- push the variation

        local spec <const> = PetsConfig.Pets[item]
        local msg <const> = (probe < 0) and 'random coat'
            or ('variant %d'):format(probe)
        TriggerEvent('vorp:TipRight', msg, 2500)
        print(('^3[pets]^7 %s (%s) -> %s'):format(
            tostring(item), tostring(spec and spec.model), msg))
    end, false)

    -- /petscan [max]   walk 0..max on the pet that is out, holding each long
    -- enough to see, and print a paste-ready config line per index. Run it again
    -- to stop. Keep the ones that looked different, bin the rest.
    local scanning = false
    RegisterCommand('petscan', function(_, args)
        if scanning then
            scanning = false
            return TriggerEvent('vorp:TipRight', 'Scan stopped.', 2500)
        end
        local item <const> = order[#order]
        local ped <const> = item and pets[item]
        if not ped or not DoesEntityExist(ped) then
            return TriggerEvent('vorp:TipRight', 'Put a pet out first.', 4000)
        end
        local spec <const> = PetsConfig.Pets[item] or {}
        local last <const> = math.floor(tonumber(args and args[1]) or 20)
        scanning = true
        CreateThread(function()
            for v = 0, last do
                if not scanning or not DoesEntityExist(ped) then break end
                Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, v)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
                TriggerEvent('vorp:TipRight', ('variant %d of %d'):format(v, last), 1800)
                print(("^3[pets]^7 ['%s_%d'] = { label = '%s (Variant %d)', model = '%s', variant = %d, scale = %s },")
                    :format(item, v, tostring(spec.label), v, tostring(spec.model), v, tostring(spec.scale or 1.0)))
                Wait(2000)
            end
            scanning = false
            TriggerEvent('vorp:TipRight', 'Scan done - one line per variant in the console.', 5000)
        end)
    end, false)
end

-- HUNT MODE: find a carcass, fetch it, drop it at the owner's feet
local skipHashes = nil
local function tooBigToCarry(ent)
    if not skipHashes then
        skipHashes = {}
        for _, n in ipairs((PetsConfig.Hunt or {}).skipModels or {}) do
            skipHashes[GetHashKey(n)] = true
        end
    end
    return skipHashes[GetEntityModel(ent)] == true
end

local function nearestCarcass(me, radius)
    local c <const> = GetEntityCoords(me)
    local set = CreateItemset(true)
    local n = Citizen.InvokeNative(0x59B57C4B06531E1E, c, radius, set, 1, Citizen.ResultAsInteger())
    local best, bestD = nil, radius
    for i = 0, (n or 0) - 1 do
        local p = GetIndexedItemInItemset(i, set)
        if p and p ~= me and GetPedType(p) == 28 and IsEntityDead(p)
            and not retrieved[p] and not tooBigToCarry(p) then
            local d = #(c - GetEntityCoords(p))
            if d < bestD then best, bestD = p, d end
        end
    end
    if IsItemsetValid(set) then DestroyItemset(set) end
    return best
end

-- walk the pet to `where` until it is within `close`, or give up
local function walkTo(ped, whereFn, close, timeoutMs)
    local started <const> = GetGameTimer()
    while DoesEntityExist(ped) do
        local target = whereFn()
        if not target then return false end
        TaskGoToCoordAnyMeans(ped, target, 2.0, 0, 0, 786603, 0xbf800000)
        Wait(1000)
        if #(GetEntityCoords(ped) - target) <= close then return true end
        if GetGameTimer() - started > timeoutMs then return false end
    end
    return false
end

CreateThread(function()
    local H <const> = PetsConfig and PetsConfig.Hunt
    if not (H and H.enabled) then return end
    while true do
        Wait(2000)
        if hunting and not fetching and not sitting and next(pets) then
            local me <const> = PlayerPedId()
            local lead = pets[order[1] or '']
            if lead and DoesEntityExist(lead) and not IsEntityDead(me) then
                local kill = nearestCarcass(me, tonumber(H.radius) or 60.0)
                if kill then
                    fetching = true
                    retrieved[kill] = true
                    CreateThread(function()
                        local got = walkTo(lead, function()
                            return DoesEntityExist(kill) and GetEntityCoords(kill) or nil
                        end, 2.5, 30000)

                        if got and DoesEntityExist(kill) then
                            AttachEntityToEntity(kill, lead, GetPedBoneIndex(lead, tonumber(H.bone) or 21030),
                                0.14, 0.14, 0.098, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                            walkTo(lead, function()
                                return DoesEntityExist(me) and GetEntityCoords(me) or nil
                            end, 2.0, 30000)
                            if DoesEntityExist(kill) then
                                DetachEntity(kill, true, true)
                                Wait(100)
                                PlaceObjectOnGroundProperly(kill, true)
                                TriggerEvent('vorp:TipRight', PetsLocale.broughtBack, 3000)
                            end
                        end

                        fetching = false
                        if hunting and not sitting then refollowAll() end
                    end)
                end
            end
        end
    end
end)

-- NOBODY RIDES A PET. The spawn flag is re-asserted here because it is lost when
-- the ped streams out, and anyone already sat on one is put straight back down.
CreateThread(function()
    while true do
        Wait(500)
        if next(pets) then
            local me <const> = PlayerPedId()
            local mount <const> = IsPedOnMount(me) and GetMount(me) or nil

            -- the horse you are on and the last one you rode; a freshly whistled horse is not your mount yet
            if mount and DoesEntityExist(mount) then
                braveHorse(mount)
            end
            local last <const> = Citizen.InvokeNative(0x4C8B59171957BCF7, me) -- GetLastMount
            if last and last ~= 0 and last ~= mount and DoesEntityExist(last) then
                braveHorse(last)
            end
            -- GetLastMount is 0 until you have ridden one, so a freshly whistled horse needs its own lookup
            local mine <const> = myHorse()
            if mine and mine ~= mount and mine ~= last then
                braveHorse(mine)
            end

            for _, ped in pairs(pets) do
                if DoesEntityExist(ped) then
                    -- the group goes with everything else when the ped streams back in
                    tamePet(ped)
                    if PetsConfig.Behaviour.allowRiding ~= true then
                        Citizen.InvokeNative(0x2D64376CF437363E, ped, false)
                        if mount and mount == ped then
                            TaskDismountAnimal(me, 262144, 0, 0, 0, 0)
                            TriggerEvent('vorp:TipRight', PetsLocale.notAMount, 3000)
                        end
                    end
                end
            end
        end
    end
end)

-- Keep them with you: re-issue the follow if the task lapsed, pull back any that got left behind
CreateThread(function()
    while true do
        Wait((PetsConfig and PetsConfig.Follow.recallCheckMs) or 3000)
        if next(pets) then
            local me <const> = PlayerPedId()
            if PetsConfig.Behaviour.despawnOnDeath and IsEntityDead(me) then
                despawnAll(false)
            else
                local c <const> = GetEntityCoords(me)
                for i, item in ipairs(order) do
                    local ped = pets[item]
                    if not ped or not DoesEntityExist(ped) then
                        forget(item)
                        TriggerServerEvent('pup-misc:pets:cleared', item)
                    else
                        local d <const> = #(c - GetEntityCoords(ped))
                        -- never teleport a pet that is away fetching a kill
                        if d > ((PetsConfig and PetsConfig.Follow.recallRange) or 60.0) and not fetching then
                            SetEntityCoords(ped, c.x + 1.0 + (i - 1), c.y + 1.0, c.z, false, false, false, false)
                            dbg(('recalled %s from %.0fm'):format(item, d))
                            sitting = false   -- a recalled pet is not sat any more
                        end
                        -- do not re-issue the follow over a sit or a fetch
                        if not sitting and not fetching then taskFollow(ped, i) end
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then despawnAll(true) end
end)
