-- huntingbirds | selling a bird to another player at a sell point

Sell = { points = {} } -- [birdId] = { id, name, model, price, coords, owner }

local PRICE_INPUT <const> = 'huntingbirds:price'
local myServerId = GetPlayerServerId(PlayerId())

-------------------------------------------------------------------------------- seller
RegisterNetEvent('pup_huntingbirds:start_sell', function()
    if Bird.state ~= 'shoulder' or not Bird.data or Cl.uiOwner then return end
    Cl.uiOwner = PRICE_INPUT
    exports['pup-ui']:OpenInput({
        owner = PRICE_INPUT,
        title = Locale.price,
        subtitle = Bird.data.name,
        submit = Locale.confirm,
        fields = { { label = Locale.price, type = 'number', min = 1, max = Config.Trade.maxPrice } },
    })
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= PRICE_INPUT then return end
    if Cl.uiOwner == PRICE_INPUT then Cl.uiOwner = nil end
    if type(values) ~= 'table' or Bird.state ~= 'shoulder' or not Bird.data then return end
    local price = Util.int(values[1], 1, tonumber(Config.Trade.maxPrice) or 100000)
    if not price then return end
    local netId = 0
    if Bird.ped and Cl.exists(Bird.ped) and Cl.is(NetworkGetEntityIsNetworked(Bird.ped)) then
        netId = NetworkGetNetworkIdFromEntity(Bird.ped)
    end
    TriggerServerEvent('huntingbirds:sell:create', Bird.data.id, price, netId)
end)

local function startSelling(point)
    if Bird.state ~= 'shoulder' then
        TriggerServerEvent('huntingbirds:sell:stop', point.id)
        return
    end
    Bird.state = 'selling'
    Bird.salePrice = point.price
    TaskStandStill(PlayerPedId(), -1)
end

local function stopSelling()
    if Bird.state ~= 'selling' then return end
    Bird.state = 'shoulder'
    Bird.salePrice = nil
    ClearPedTasks(PlayerPedId())
end

function Sell.stop()
    if Bird.data then TriggerServerEvent('huntingbirds:sell:stop', Bird.data.id) end
end

RegisterNetEvent('huntingbirds:sell:finishsell', function()
    ClearPedTasks(PlayerPedId())
    Bird.reset(false)
end)

-------------------------------------------------------------------------------- point list
RegisterNetEvent('huntingbirds:sell:gotpoints_c', function(points)
    if type(points) ~= 'table' then return end
    Sell.points = {}
    for id, p in pairs(points) do
        local n = Util.int(id, 1)
        if n and type(p) == 'table' then Sell.points[n] = p end
    end
end)

local function removed(birdId)
    Sell.points[birdId] = nil
    if Bird.data and Bird.data.id == birdId then stopSelling() end
end

RegisterNetEvent('huntingbirds:sell:updatepoints', function(point, birdId, netIdToDelete)
    birdId = Util.int(birdId, 1)
    if not birdId then return end
    if type(point) == 'table' then
        Sell.points[birdId] = point
        if point.owner == myServerId and Bird.data and Bird.data.id == birdId then startSelling(point) end
        return
    end
    removed(birdId)
    local netId = Util.int(netIdToDelete, 1)
    if netId and Cl.is(NetworkDoesNetworkIdExist(netId)) then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and Cl.exists(ent) and ent ~= Bird.ped then
            NetworkRequestControlOfEntity(ent)
            Cl.deleteEntity(ent)
        end
    end
end)

RegisterNetEvent('huntingbirds:sell:updatepoints1', function(birdId)
    birdId = Util.int(birdId, 1)
    if birdId then removed(birdId) end
end)

-------------------------------------------------------------------------------- buyers and markers
CreateThread(function()
    local buyGroup = Cl.newGroup()
    local buyPrompt = Cl.prompt(Config.Keys.buy, Locale.buy, buyGroup)
    while true do
        local sleep = 500
        local player = PlayerPedId()
        local pc = GetEntityCoords(player)
        for id, p in pairs(Sell.points) do
            local c = p.coords
            if c then
                c = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
                local d = #(pc - c)
                local mine = p.owner == myServerId
                if d < 25.0 then
                    sleep = 0
                    local markerRange = mine and 2.0 or 10.0
                    if d < markerRange and Config.Markers.showAtSellPoints then
                        Cl.drawMarker(c.x, c.y, c.z - 0.9, 2.0, 2.0, 0.3)
                    end
                    if not mine and d < 2.0 and not Cl.uiOwner and not Cl.isDead(player) then
                        Cl.showGroup(buyGroup, ('$%s'):format(Util.money(p.price)))
                        if Cl.pressed(buyPrompt) and not Cl.isHogtied(player) then
                            TriggerServerEvent('huntingbirds:sell:buyoffer', id)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    Wait(1000)
    myServerId = GetPlayerServerId(PlayerId())
    TriggerServerEvent('huntingbirds:sell:getpoints')
end)
