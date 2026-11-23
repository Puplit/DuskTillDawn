-- pup_camps | pelt origin tracking, public butchers, trapper donations, horse pelts,
-- and the per-character hunting-wagon stash

Hunting = {}

local B = Config.Butchers
local records = {}       -- [peltKey] = { model, outfit, price, big, t }
local recordCount = 0
local horseTally = {}    -- [horse entity] = money value of small pelts stowed on it
local npcs = {}          -- [butcher index] = ped
local butcherBlips = {}

------------------------------------------------------------------------------ helpers

local function pedOutfit(ped)
    local o = N(0x30569F348D126A5A, ped)
    if o and o ~= 0 then return o end
    return nil
end

local function carriedEntity()
    local ent = N(0xD806CD2A4F2C2996, PlayerPedId())
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

local function peltKey(ent)
    local st = Entity(ent).state
    if st and st.network ~= nil then return 'n:' .. tostring(st.network) end
    if NetworkGetEntityIsNetworked(ent) then return 'id:' .. tostring(NetworkGetNetworkIdFromEntity(ent)) end
    return 'e:' .. tostring(ent)
end

local function peltQuality(ent)
    local q = N(0x31FEF6A20F00B963, ent)
    if q and q ~= 0 then return q end
    return GetEntityModel(ent)
end

local function remember(ent, rec)
    local key = peltKey(ent)
    if not records[key] then recordCount = recordCount + 1 end
    rec.t = GetGameTimer()
    records[key] = rec
    if recordCount > Config.Pelts.maxRecords then
        local oldKey, oldT
        for k, r in pairs(records) do if not oldT or r.t < oldT then oldKey, oldT = k, r.t end end
        if oldKey then records[oldKey] = nil recordCount = recordCount - 1 end
    end
end

local function forget(ent)
    local key = peltKey(ent)
    if records[key] then records[key] = nil recordCount = recordCount - 1 end
end

-- what the player is carrying: kind = carcass | pelt | human | living | player | unknown
local function carried()
    local ent = carriedEntity()
    if not ent then return nil end
    if IsEntityAPed(ent) then
        if IsPedAPlayer(ent) then return { kind = 'player', ent = ent } end
        local model = GetEntityModel(ent)
        local outfit = pedOutfit(ent)
        local row = U.animalRow(model, outfit)
        if row then return { kind = 'carcass', ent = ent, model = model, outfit = outfit, row = row, price = row.price[2] } end
        if IsPedHuman(ent) then return { kind = IsEntityDead(ent) and 'human' or 'living', ent = ent } end
        return { kind = 'unknown', ent = ent }
    end
    local rec = records[peltKey(ent)]
    if rec then return { kind = 'pelt', ent = ent, model = rec.model, outfit = rec.outfit, price = rec.price, rec = rec } end
    return { kind = 'unknown', ent = ent }
end

local function dropCarried(ent)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if IsEntityAttached(ent) then DetachEntity(ent, true, true) end
    Wait(600)
end

local function lastMount(maxDist)
    local ped = PlayerPedId()
    local horse = N(0x4C8B59171957BCF7, ped)
    if not horse or horse == 0 or not DoesEntityExist(horse) then return nil end
    if #(GetEntityCoords(horse) - GetEntityCoords(ped)) > maxDist then return nil end
    return horse
end

local function clearHorsePelts(horse)
    local ok, handled = pcall(Integrations.clearHorsePelts, horse)
    if ok and handled then return end
    for i = 0, 5 do
        local pelt = N(0x0CEEB6F4780B1F2F, horse, i)
        if pelt and pelt ~= 0 then N(0x627F7F3A0C4C51FF, horse, pelt) end
    end
end

------------------------------------------------------------------------------ pelt origin tracking
-- The server decides what a pelt is worth: a new pelt is registered there against the
-- carcass it came from (peltBind) and only then recorded here. The price kept here is the
-- server's, used for display and the horse tally hint only.

local binding = {}   -- [peltKey] = true while a registration is in flight

local function bindPelt(ent, animal)
    local key = peltKey(ent)
    if binding[key] or animal.used or (animal.tries or 0) >= 3 then return end
    binding[key] = true
    animal.tries = (animal.tries or 0) + 1
    CreateThread(function()
        local peltNet = NetOf(ent, 2000)
        local carcassNet = (animal.ent and DoesEntityExist(animal.ent)) and NetOf(animal.ent, 1000) or 0
        if peltNet ~= 0 and carcassNet ~= 0 then
            local res = Request('peltBind', carcassNet, peltNet, animal.outfit, peltQuality(ent))
            if type(res) == 'table' and DoesEntityExist(ent) then
                animal.used = true
                remember(ent, { model = animal.model, outfit = animal.outfit, big = res.big == true, price = tonumber(res.price) or 0, net = peltNet })
            end
        end
        binding[key] = nil
    end)
end

-- a registered small pelt left the hands onto the horse: the server moves it to its tally
local function stowPelt(horse, rec)
    if not rec.net then return end
    CreateThread(function()
        if Request('peltStow', rec.net) then
            horseTally[horse] = (horseTally[horse] or 0) + (rec.price or 0)
        end
    end)
end

CreateThread(function()
    local lastAnimal = nil      -- { ent, model, outfit, row, t }
    local held = nil            -- { ent, rec } the recorded pelt carried last tick
    while true do
        Wait(500)
        if State.started then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local ent = carriedEntity()
            if not ent then
                -- a dead listed animal right beside the player is the likely skinning target
                local best, bestD
                for _, other in ipairs(GetGamePool('CPed')) do
                    if other ~= ped and not IsPedHuman(other) and IsEntityDead(other) then
                        local d = #(GetEntityCoords(other) - pos)
                        if d < 2.5 and (not bestD or d < bestD) then best, bestD = other, d end
                    end
                end
                if best then
                    local model, outfit = GetEntityModel(best), pedOutfit(best)
                    local row = U.animalRow(model, outfit)
                    if row then lastAnimal = { ent = best, model = model, outfit = outfit, row = row, t = GetGameTimer() } end
                end
                -- a recorded small pelt that left the hands next to a horse went onto that horse
                if held and DoesEntityExist(held.ent) then
                    local horse = lastMount(4.0)
                    if horse and not held.rec.big and IsEntityAttachedToEntity(held.ent, horse) then
                        stowPelt(horse, held.rec)
                        forget(held.ent)
                    end
                elseif held and not DoesEntityExist(held.ent) then
                    local horse = lastMount(4.0)
                    if horse and not held.rec.big then stowPelt(horse, held.rec) end
                end
                held = nil
            elseif not IsEntityAPed(ent) then
                local key = peltKey(ent)
                local rec = records[key]
                if not rec and lastAnimal and GetGameTimer() - lastAnimal.t < 20000 then
                    bindPelt(ent, lastAnimal)
                end
                held = rec and { ent = ent, rec = rec } or nil
            end
            -- forget old records
            local now = GetGameTimer()
            for k, r in pairs(records) do
                if now - r.t > Config.Pelts.forgetMin * 60000 then records[k] = nil recordCount = recordCount - 1 end
            end
        end
    end
end)

------------------------------------------------------------------------------ selling and donating

-- one carried body or pelt; endpoint = 'sell' (butcher index) or 'donate' (camp id)
local function handOver(endpoint, target, c)
    dropCarried(c.ent)
    local net = NetOf(c.ent, 2000)
    if net == 0 then return Notify(L('butcher_refused')) end
    -- the server identifies the body itself and prices it from config; the outfit only
    -- chooses between price rows of the same model
    local info = { outfit = c.outfit }
    local ok, why = Request(endpoint, target, net, info)
    if ok then
        if c.kind == 'pelt' then forget(c.ent) end
    else
        Notify(type(why) == 'string' and why or L('butcher_refused'))
    end
end

local function horseOver(endpoint, target, maxDist, nothingKey)
    local horse = lastMount(maxDist)
    local tally = horse and horseTally[horse] or 0
    if not horse or tally <= 0 then return Notify(L(nothingKey)) end
    -- the amount is the server's own tally of registered pelts
    if Ask(endpoint, target) then
        horseTally[horse] = nil
        clearHorsePelts(horse)
    end
end

local function sell(idx)
    local c = carried()
    if c then
        if c.kind == 'carcass' or c.kind == 'pelt' then return handOver('sell', idx, c) end
        return Notify(L('nobody_buys'))
    end
    horseOver('sellHorse', idx, B.mountDistance, 'nothing_to_sell')
end

function Hunting.donate(campId)
    local c = carried()
    if c then
        if c.kind == 'carcass' or c.kind == 'pelt' then return handOver('donate', campId, c) end
        return Notify(L('nobody_buys'))
    end
    horseOver('donateHorse', campId, B.donateMountDistance, 'nothing_to_donate')
end

------------------------------------------------------------------------------ butchers

local function makeBlips()
    for _, b in ipairs(butcherBlips) do DropBlip(b) end
    butcherBlips = {}
    if not B.enabled then return end
    for _, b in ipairs(CampButchers) do butcherBlips[#butcherBlips + 1] = BlipCoords(B.blipSprite, b.pos, b.name) end
end

CreateThread(function()
    while true do
        Wait(2000)
        if State.started and B.enabled then
            local pos = PedPos()
            for i, b in ipairs(CampButchers) do
                local at = b.npc or b.pos
                local near = U.dist3(pos, at) <= B.spawnDistance
                if near and not npcs[i] then
                    local model = LoadModel(B.npcModel)
                    if model then
                        local ped = CreatePed(model, at.x + 0.0, at.y + 0.0, at.z + 0.0, b.heading + 0.0, false, false, false, false)
                        SetModelAsNoLongerNeeded(model)
                        if ped and ped ~= 0 then
                            N(0x283978A15512B2FE, ped, true)
                            FreezeEntityPosition(ped, true)
                            SetEntityInvincible(ped, true)
                            SetBlockingOfNonTemporaryEvents(ped, true)
                            npcs[i] = ped
                        end
                    end
                elseif not near and npcs[i] then
                    if DoesEntityExist(npcs[i]) then DeletePed(npcs[i]) end
                    npcs[i] = nil
                end
            end
        end
    end
end)

Interact.add(function(pos, ped)
    if not B.enabled or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return nil end
    for i, b in ipairs(CampButchers) do
        local d = U.dist3(pos, b.pos)
        if d <= B.sellDistance then
            return { dist = d, title = b.name, keys = { { control = Config.Keys.interact, label = L('sell_animal'), fn = function() sell(i) end } } }
        end
    end
    return nil
end)

------------------------------------------------------------------------------ hunting-wagon stash

local HW = Config.HuntingWagon
local HW_MODEL <const> = U.signed(Config.HuntingWagon.model)

function Hunting.dressWagon(veh, count)
    if not veh or not DoesEntityExist(veh) then return end
    SetVehicleExtra(veh, 1, false)
    N(0x31F343383F19C987, veh, math.min(1.0, (tonumber(count) or 0) / HW.maxEntries) + 0.0, true)
end

local function nearWagon(pos, ped)
    if IsPedInAnyVehicle(ped, false) then return nil end
    local best, bestD
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetEntityModel(veh) == HW_MODEL then
            local d = U.dist3(pos, GetEntityCoords(veh))
            if d <= HW.nearDistance and (not bestD or d < bestD) then best, bestD = veh, d end
        end
    end
    return best, bestD
end

local function stashCarried(veh)
    local c = carried()
    if not c or (c.kind ~= 'carcass' and c.kind ~= 'pelt' and c.kind ~= 'human') then return end
    local ped = PlayerPedId()
    local back = GetOffsetFromEntityInWorldCoords(veh, 0.0, -3.5, 0.0)
    TaskGoToCoordAnyMeans(ped, back.x, back.y, back.z, 1.0, 0, false, 786603, 0xbf800000)
    local t = GetGameTimer() + 4000
    while #(GetEntityCoords(ped) - back) > 1.2 and GetGameTimer() < t do Wait(100) end
    local before = Request('hwList')
    local count = type(before) == 'table' and before.count or 0
    dropCarried(c.ent)
    local net = NetOf(c.ent, 2000)
    if net == 0 then return Notify(L('hw_stash_failed')) end
    local st = Entity(c.ent).state
    local rec = { kind = c.kind, model = c.model and U.signed(c.model) or nil, outfit = c.outfit, animalnetwork = st and st.network or net }
    if c.kind == 'pelt' then
        rec.data = { model = U.signed(c.model), model2 = GetEntityModel(c.ent), netid = net, peltquality = peltQuality(c.ent) }
    else
        rec.data = {
            model = GetEntityModel(c.ent), model2 = GetEntityModel(c.ent), netid = net, outfit = c.outfit or 0,
            quality = N(0x7BCC6087D130312A, c.ent) or 0, damage = N(0x88EFFED5FE8B0B4A, c.ent) or 0, metatag = {},
        }
    end
    local list, why = Request('hwPut', net, rec)
    if type(list) == 'table' and (list.count or 0) == count + 1 then
        if c.kind == 'pelt' then forget(c.ent) end
        Hunting.dressWagon(veh, list.count)
    else
        Notify(type(why) == 'string' and why or L('hw_stash_failed'))
    end
end

local function takeOut(key, veh)
    local e = Ask('hwTake', key)
    if type(e) ~= 'table' then return end
    local ped = PlayerPedId()
    local spot = GetOffsetFromEntityInWorldCoords(veh, 0.0, -3.0, 0.0)
    local ent, net = nil, 0
    local d = type(e.data) == 'table' and e.data or {}
    if e.isskin then
        local model = LoadModel(d.model2 ~= 0 and d.model2 or e.model)
        if model then
            ent = CreateObject(model, spot.x, spot.y, spot.z, true, true, false)
            SetModelAsNoLongerNeeded(model)
        end
        net = NetOf(ent, 2000)
        if net ~= 0 then N(0x502EC17B1BED4BFA, ped, ent) end
    else
        local model = LoadModel(e.model)
        if model then
            ent = CreatePed(model, spot.x, spot.y, spot.z, 0.0, true, true, false, false)
            SetModelAsNoLongerNeeded(model)
        end
        if ent and ent ~= 0 then
            if (tonumber(e.outfit) or 0) ~= 0 then N(0x1902C4CFCC5BE57C, ent, U.signed(e.outfit)) else N(0x283978A15512B2FE, ent, true) end
            if (tonumber(d.quality) or 0) ~= 0 then N(0xCE6B874286D640BB, ent, d.quality) end
            SetEntityHealth(ent, 0, 0)
        end
        net = NetOf(ent, 2000)
    end
    if net == 0 then
        if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
        Request('hwTaken', key, 0)
        return Notify(L('hw_take_failed'))
    end
    local res = Request('hwTaken', key, net)
    if e.isskin then
        if type(res) == 'table' then
            -- the server registered this pelt again with the price it stored
            remember(ent, { model = e.model, outfit = e.outfit, big = res.big == true, price = tonumber(res.price) or 0, net = net })
        elseif res == false then
            -- refused: the entry went back into the wagon, so this copy must not stay
            DeleteEnt(ent)
            Notify(L('hw_take_failed'))
        end
    end
end

local function wagonMenu(veh)
    local list = Request('hwList')
    if type(list) ~= 'table' then return end
    local rows = {}
    for _, e in ipairs(list.entries or {}) do
        rows[#rows + 1] = { label = e.name, description = L('hw_take'), onSelect = function()
            Menu.closeAll()
            takeOut(e.key, veh)
        end }
    end
    if #rows == 0 then rows[1] = { label = L('hw_empty'), disabled = true } end
    if Menu.begin({ noFreeze = true }) then
        Menu.push({ title = L('hw_stash_menu'), subtitle = L('hw_count', list.count or 0, list.max or HW.maxEntries), rows = rows })
    end
end

Interact.add(function(pos, ped)
    if not HW.enabled then return nil end
    local veh, d = nearWagon(pos, ped)
    if not veh then return nil end
    local keys = {}
    local c = carried()
    if c and (c.kind == 'carcass' or c.kind == 'pelt' or c.kind == 'human') then
        keys[#keys + 1] = { control = Config.Keys.stash, label = L('hw_stash'), fn = function() stashCarried(veh) end }
    end
    keys[#keys + 1] = { control = Config.Keys.confirm, label = L('hw_stash_menu'), fn = function() wagonMenu(veh) end }
    return { dist = d + 1.0, title = L('wagon_title'), keys = keys }
end)

------------------------------------------------------------------------------ start / stop

OnState('start', function(first)
    if first then makeBlips() end
end)

OnState('stop', function()
    for _, b in ipairs(butcherBlips) do DropBlip(b) end
    butcherBlips = {}
    for i, ped in pairs(npcs) do
        if DoesEntityExist(ped) then DeletePed(ped) end
        npcs[i] = nil
    end
end)
