-- boatshops | shop blips, shop keepers and the open / park prompts

local CFG <const> = BoatConfig
local L <const> = BoatLocale
local T <const> = CFG.Timings

BC.prompts = {}
local blips = {}    -- [shopId] = { handle, closed }
local keepers = {}  -- [shopId] = ped

local function dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
BC.dist3 = dist3

function BC.isClosed(shop)
    return Boat.isClosed(shop, BC.gameHour())
end

function BC.hoursText(shop)
    return L.hours:format(shop.hours.open, shop.hours.close)
end

-- ------------------------------------------------------------------ blips

local function makeBlip(shop, closed)
    local c = shop.counter
    local b = BN.coordBlip(CFG.Blips.shopStyle, c.x, c.y, c.z)
    BN.blipSprite(b, shop.blip.sprite)
    BN.blipScale(b, CFG.Blips.scale)
    if closed then
        BN.blipModifier(b, CFG.Blips.closedModifier)
        BN.blipName(b, shop.blip.name .. L.closedBlip)
    else
        BN.blipName(b, shop.blip.name)
    end
    return b
end

local function updateBlips()
    for id, shop in pairs(Boat.shops) do
        if shop.blip.show then
            local closed = BC.isClosed(shop)
            local cur = blips[id]
            if not cur or cur.closed ~= closed then
                if cur then BN.removeBlip(cur.handle) end
                blips[id] = { handle = makeBlip(shop, closed), closed = closed }
            end
        end
    end
end

local function removeBlips()
    for id, b in pairs(blips) do
        BN.removeBlip(b.handle)
        blips[id] = nil
    end
end

-- ------------------------------------------------------------------ shop keepers

function BC.keeperOf(shop)
    local ped = shop and keepers[shop.id]
    if ped and DoesEntityExist(ped) then return ped end
    return nil
end

function BC.say(shop, line)
    local ped = BC.keeperOf(shop)
    if ped then BN.speak(ped, line) end
end

local function makeKeeper(shop, at)
    local hash = GetHashKey(shop.keeper.model)
    if not BN.loadModel(hash) then return nil end
    local c = shop.counter
    local ped = CreatePed(hash, at.x + 0.0, at.y + 0.0, at.z + 0.0, (c.h or 0.0) + 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    BN.randomOutfit(ped)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

local function dropKeeper(id, wander)
    local ped = keepers[id]
    keepers[id] = nil
    if not ped or not DoesEntityExist(ped) then return end
    if wander then
        TaskWanderStandard(ped, 10.0, 10)
        SetPedAsNoLongerNeeded(ped)
    else
        DeletePed(ped)
    end
end

local function updateKeepers(pos)
    for id, shop in pairs(Boat.shops) do
        if shop.keeper.show then
            local d = dist3(pos, shop.counter)
            local useHours = shop.hours.enabled
            local closed = useHours and BC.isClosed(shop)
            local ped = BC.keeperOf(shop)
            if ped and (d > CFG.Keeper.despawnMeters) then
                dropKeeper(id, false)
            elseif ped and closed then
                dropKeeper(id, true)
            elseif not ped and not closed and d <= CFG.Keeper.spawnMeters then
                local c = shop.counter
                if useHours then
                    -- walks in from the street at opening time
                    local new = makeKeeper(shop, shop.keeper.walkIn or c)
                    if new then
                        keepers[id] = new
                        TaskGoStraightToCoord(new, c.x + 0.0, c.y + 0.0, c.z + 0.0, 1.0, -1, (c.h or 0.0) + 0.0, 0.5)
                    end
                else
                    local new = makeKeeper(shop, c)
                    if new then
                        keepers[id] = new
                        TaskStandStill(new, -1)
                    end
                end
            end
        end
    end
end

local function removeKeepers()
    for id in pairs(keepers) do dropKeeper(id, false) end
end

CreateThread(function()
    while true do
        updateBlips()
        updateKeepers(GetEntityCoords(PlayerPedId()))
        Wait(5000)
    end
end)

-- ------------------------------------------------------------------ prompts

CreateThread(function()
    BC.prompts.open = BN.prompt(CFG.Keys.use, L.press)
    BC.prompts.park = BN.prompt(CFG.Keys.use, L.parkBoat)
    BC.prompts.buy = BN.prompt(CFG.Keys.use, L.buyBoat)
    BC.prompts.mods = BN.prompt(CFG.Keys.use, L.buyMods)
end)

local function canPark(ped)
    if not IsPedInAnyBoat(ped) then return false end
    if IsPedSwimming(ped) or IsPedDeadOrDying(ped, true) or IsPedWalking(ped) or IsPedRunning(ped) then return false end
    return true
end

CreateThread(function()
    while not BC.prompts.park do Wait(100) end
    while true do
        local sleep = T.idleLoopMs
        local ped = PlayerPedId()
        if not BoatMenu.isOpen() and not BC.busy and not IsEntityDead(ped) then
            local pos = GetEntityCoords(ped)
            local inBoat = canPark(ped)
            local onFoot = not IsPedInAnyVehicle(ped, false)
            for _, shop in pairs(Boat.shops) do
                local dc = dist3(pos, shop.counter)
                if dc < 30.0 or (inBoat and dist3(pos, shop.park) < 30.0) then sleep = 0 end

                if onFoot and dc <= shop.openRadius then
                    local label = shop.prompt
                    if BC.isClosed(shop) then label = BC.hoursText(shop) end
                    BN.showPrompt(BC.prompts.open, label)
                    if BN.promptDone(BC.prompts.open) then
                        BC.busy = true
                        CreateThread(function() BC.openShop(shop) end)
                    end
                    break
                end

                if inBoat and dist3(pos, shop.park) <= shop.parkRadius then
                    BN.showPrompt(BC.prompts.park, shop.name)
                    if BN.promptDone(BC.prompts.park) then
                        BC.busy = true
                        CreateThread(function() BC.parkAt(shop) end)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

-- ------------------------------------------------------------------ stop

function BC.cleanupWorld()
    for _, pr in pairs(BC.prompts) do BN.deletePrompt(pr) end
    BC.prompts = {}
    removeBlips()
    removeKeepers()
end
