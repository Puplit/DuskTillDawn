-- pup_railroad | client: station blips, the station menu, the train shop, bringing trains out

local L <const> = Rail.L
local RESOURCE <const> = GetCurrentResourceName()

local stationBlips = {}
local shopItems = nil   -- [shop item name] = Config.Trains entry, while this resource owns the open shop

--------------------------------------------------------------------------------
-- blips
--------------------------------------------------------------------------------
CreateThread(function()
    for i = 1, #Config.Stations do
        local st = Config.Stations[i]
        stationBlips[i] = Cl.coordBlip(Config.StationBlipSprite, st.coords, Config.Blips.stationScale, st.name)
    end
end)

Cl.onCleanup(function()
    for i = 1, #stationBlips do Cl.removeBlip(stationBlips[i]) end
    stationBlips = {}
end)

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function fmtNum(n)
    n = tonumber(n) or 0
    if math.floor(n) == n then return tostring(math.tointeger(n)) end
    return ('%.1f'):format(n)
end

local function trainRowDescription(src)
    local parts = {
        L('row_speed', fmtNum(src.speed)),
        L('row_coal', fmtNum(src.coal), fmtNum(src.coalcap)),
    }
    if Config.Maintenance.enabled then
        parts[#parts + 1] = L('row_maint', Rail.round(src.maint))    end
    return table.concat(parts, '  |  ')
end

local function pictureUrl(key)
    key = tostring(key or 'Train17')
    if not key:match('^Train%d+$') then key = 'Train17' end
    return ('nui://%s/html/img/%s.svg'):format(RESOURCE, key)
end

--------------------------------------------------------------------------------
-- buying a key
--------------------------------------------------------------------------------
local function buyKey()
    Cl.closeMenu()
    local r = Cl.call('buyKey', 5000)
    if not r then return Cl.officeSilent() end
    if r.ok then Cl.notify(L('bought_key', r.price)) end
end

--------------------------------------------------------------------------------
-- the shop (pup-ui sends every shop's clicks to everyone; only react while ours is open)
--------------------------------------------------------------------------------
local function openShop(st)
    Cl.closeMenu()
    local items = {}
    shopItems = {}
    for i = 1, #Config.Trains do
        local t = Config.Trains[i]
        if not t.disabled then
            local name = 'pup_railroad_train_' .. i
            shopItems[name] = t
            items[#items + 1] = {
                name = name,
                label = t.name,
                price = t.price,
                rankreq = 0,
                img = pictureUrl(t.picture),
                stats = {
                    L('shop_speed', t.speed),
                    L('shop_cap', t.cap),
                    t.burn > 0 and L('shop_burn', t.burn) or L('shop_noburn'),
                },
            }
        end
    end
    Cl.shopOpen = true
    exports['pup-ui']:OpenShop({ label = st.name, cash = Cl.cash, items = items })
end

local function closeShop()
    if not Cl.shopOpen then return end
    Cl.shopOpen = false
    shopItems = nil
    exports['pup-ui']:HideShop()
end

AddEventHandler('pup-ui:client:shopClosed', function()
    Cl.shopOpen = false
    shopItems = nil
end)

AddEventHandler('pup-ui:client:shopBuy', function(itemName)
    if not Cl.shopOpen or not shopItems then return end
    local entry = shopItems[itemName]
    if not entry then return end
    closeShop()
    CreateThread(function()
        local values = Cl.ask(L('name_title'), {
            { label = L('name'), type = 'text', required = true, maxlength = 50 },
        })
        local name = values and values[1]
        if type(name) ~= 'string' or name:match('^%s*$') then return Cl.notify(L('invalid')) end
        local r = Cl.call('buyTrain', 8000, entry.hash, name)
        if not r then return Cl.officeSilent() end
        if r.ok then Cl.notify(L('bought_train', r.price)) end
    end)
end)

Cl.onCleanup(closeShop)

--------------------------------------------------------------------------------
-- bringing a train out
--------------------------------------------------------------------------------
local function loadTrainModels(hash)
    local count = tonumber(Cl.train.cars(hash)) or 0
    if count <= 0 then return false, {} end
    local models = {}
    for i = 0, count - 1 do
        local model = Cl.train.carModel(hash, i)
        if model and model ~= 0 then
            RequestModel(model)
            local deadline = GetGameTimer() + 10000
            while not HasModelLoaded(model) do
                if GetGameTimer() > deadline then return false, models end
                Wait(50)
            end
            models[#models + 1] = model
        end
    end
    return #models > 0, models
end

local function releaseModels(models)
    for i = 1, #models do SetModelAsNoLongerNeeded(models[i]) end
end

local function fadeOut()
    DoScreenFadeOut(2000)
    local deadline = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(50) end
end

local function deleteTrain(train)
    if train and train ~= 0 and DoesEntityExist(train) then
        SetEntityAsMissionEntity(train, true, true)
        Cl.train.delete(train)
        if DoesEntityExist(train) then DeleteEntity(train) end
    end
end

--- returns true when the train is out and accepted by the server
local function spawnTrain(st, t, direction)
    local r = Cl.call('requestSpawn', 6000, t.id)
    if not r then Cl.officeSilent() return false end
    if not r.ok then return false end

    local hash = Rail.s32(r.hash)
    local loaded, models = false, {}
    if hash then loaded, models = loadTrainModels(hash) end
    if not loaded then
        releaseModels(models)
        Cl.tell('spawnFailed', t.id)
        Cl.notify(L('spawn_failed'))
        return false
    end

    local ped = PlayerPedId()
    local train = nil
    local accepted = false
    local told = false -- the server already showed its refusal
    local ok, err = pcall(function()
        fadeOut()
        local darkSince = GetGameTimer()
        local pos = GetEntityCoords(ped)
        train = Cl.train.create(hash, pos.x, pos.y, pos.z, direction == 1)
        if not train or train == 0 then return end
        local speed = (tonumber(r.speed) or 0) + 0.0
        Cl.train.setSpeed(train, 0.0)
        if Config.SpawnSetsCruiseSpeed then Cl.train.setCruise(train, speed) end
        Cl.train.setMax(train, speed)
        SetPedIntoVehicle(ped, train, -1)

        local netDeadline = GetGameTimer() + 3000
        while not NetworkGetEntityIsNetworked(train) and GetGameTimer() < netDeadline do
            NetworkRegisterEntityAsNetworked(train)
            Wait(50)
        end
        local netId = NetworkGetNetworkIdFromEntity(train)
        SetNetworkIdExistsOnAllMachines(netId, true)

        local wait = 4000 - (GetGameTimer() - darkSince)
        if wait > 0 then Wait(wait) end

        local res = Cl.call('spawned', 8000, t.id, netId)
        if res and res.ok then
            accepted = true
            Cl.removeBlip(Cl.trainBlips[t.id])
            Cl.trainBlips[t.id] = Cl.entityBlip(Config.Blips.trainSprite, train, Config.Blips.trainScale, t.name)
            TaskLeaveVehicle(ped, train, 0)
        elseif res then
            told = true
        end
    end)
    if not ok then print('[pup_railroad] spawn error: ' .. tostring(err)) end
    releaseModels(models)

    if not accepted then
        if train and train ~= 0 and DoesEntityExist(train) then
            if GetVehiclePedIsIn(ped, false) == train then ClearPedTasksImmediately(ped) end
            deleteTrain(train)
        end
        Cl.tell('spawnFailed', t.id)
        if not told then Cl.notify(L('spawn_failed')) end
    end
    DoScreenFadeIn(2000)
    return accepted
end

--------------------------------------------------------------------------------
-- company train list
--------------------------------------------------------------------------------
local openTrainList -- forward

local function bringOut(st, t, direction, mode)
    Cl.closeMenu()
    Cl.busy = true
    local ok = spawnTrain(st, t, direction)
    Cl.busy = false
    if ok and mode == 'delivery' then
        Wait(2000)
        if Cl.openRoutePicker then Cl.openRoutePicker(st, t.id) end
    end
end

local function directionMenu(st, t, mode)
    Cl.openMenu({
        title = t.name,
        subtitle = st.name,
        rows = {
            { label = L('spawn_dir0'), action = function() bringOut(st, t, 0, mode) end },
            { label = L('spawn_dir1'), action = function() bringOut(st, t, 1, mode) end },
        },
    })
end

openTrainList = function(st, trains, mode)
    local rows = {}
    for i = 1, #trains do
        local t = trains[i]
        local live = Cl.byId[t.id]
        rows[#rows + 1] = {
            label = t.name .. (live and L('tag_out') or ''),
            description = trainRowDescription(live or t),
            action = function()
                if Cl.byId[t.id] then
                    if mode == 'delivery' then
                        Cl.closeMenu()
                        if Cl.openRoutePicker then Cl.openRoutePicker(st, t.id) end
                    else
                        Cl.notify(L('already_out'))
                    end
                    return
                end
                directionMenu(st, t, mode)
            end,
        }
    end
    if #rows == 0 then rows[1] = { label = L('no_trains') } end
    Cl.openMenu({ title = st.name, subtitle = L('group_company'), rows = rows })
end

--------------------------------------------------------------------------------
-- station menu
--------------------------------------------------------------------------------
local function openStation(st)
    Cl.busy = true
    local me = Cl.call('whoami', 5000)
    local list = me and me.ok and Cl.call('companyTrains', 5000) or nil
    Cl.busy = false
    if not me or not list then return Cl.officeSilent() end
    if not me.ok or not list.ok then return end
    Cl.job, Cl.cash = me.job, me.cash
    if me.job ~= st.job then return Cl.notify(L('staff_only')) end

    local trains = list.trains or {}
    Cl.openMenu({
        title = st.name,
        subtitle = L('group_company'),
        rows = {
            { label = L('menu_shop'), action = function() openShop(st) end },
            { label = L('menu_owned'), action = function() openTrainList(st, trains, 'owned') end },
            { label = L('menu_key', Config.KeyPrice), action = buyKey },
            { label = L('menu_delivery'), action = function()
                if Cl.route then return Cl.notify(L('finish_first')) end
                openTrainList(st, trains, 'delivery')
            end },
        },
    })
end

--------------------------------------------------------------------------------
-- station prompt
--------------------------------------------------------------------------------
CreateThread(function()
    local group = Cl.newGroup()
    local prompt = Cl.newPrompt(Config.Keys.interact, L('prompt_menu'), group)
    local lastYield = 0
    Cl.onCleanup(function() Cl.deletePrompt(prompt) end)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local near, nearDist = nil, nil
        for i = 1, #Config.Stations do
            local d = #(pos - Config.Stations[i].coords)
            if not nearDist or d < nearDist then near, nearDist = Config.Stations[i], d end
        end

        if nearDist and nearDist < 30.0 then sleep = 250 end
        if near and nearDist <= Config.Timings.stationPrompt and Cl.idle() and not Cl.incapacitated(ped) then
            sleep = 0
            Cl.showGroup(group, L('group_company'))
            local now = GetGameTimer()
            if now - lastYield >= 200 then
                lastYield = now
                TriggerEvent('pup:promptYield', 250)
            end
            if Cl.promptPressed(prompt) then
                local st = near
                CreateThread(function() openStation(st) end)
                Wait(500)
            end
        end
        Wait(sleep)
    end
end)
