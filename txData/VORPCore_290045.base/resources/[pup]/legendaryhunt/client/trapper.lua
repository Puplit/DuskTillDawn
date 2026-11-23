-- legendaryhunt | client: the trapper NPC, his blip and his shop menus
-- The menus only name an item; the server checks distance, lists and prices.

Trapper = {}

local TR = Config.Trapper
local group, pShop
local shopData = Config.Shop or {}
local buyOpt = shopData.buy or {}
local sellOpt = shopData.sell or {}

CreateThread(function()
    group = Cli.newGroup()
    pShop = Cli.prompt(Config.Keys.shop, Rules.text('promptShop'), group)
end)

function Trapper.spawn()
    if Trapper.ped and DoesEntityExist(Trapper.ped) then return end
    local hash = Cli.loadModel(TR.model, 10000)
    if not hash then
        Cli.warnOnce('trapper_model', 'trapper model did not load')
        return
    end
    local c = TR.coords
    local ped = CreatePed(hash, c.x, c.y, c.z, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- random outfit first
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, 0, false) -- then outfit preset 0
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStandStill(ped, -1)
    FreezeEntityPosition(ped, true)
    -- not hostile: he keeps his ambient civilian standing and ignores anything that is not scripted
    Trapper.ped = ped

    if TR.showBlip and not Trapper.blip then
        local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, c.x, c.y, c.z)
        if b and b ~= 0 then
            SetBlipSprite(b, TR.blipSprite, true)
            SetBlipScale(b, 1.0)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, TR.name)
            Trapper.blip = b
        end
    end
end

function Trapper.remove()
    if Menu.isOpen() then Menu.hide() end
    Cli.deleteEntity(Trapper.ped)
    Trapper.ped = nil
    if Trapper.blip and DoesBlipExist(Trapper.blip) then RemoveBlip(Trapper.blip) end
    Trapper.blip = nil
end

function Trapper.distance()
    local c = TR.coords
    return #(GetEntityCoords(PlayerPedId()) - vector3(c.x, c.y, c.z))
end

-- menus
local openRoot, openBuy, openSellGroups, openSellGroup

local function standStill() TaskStandStill(PlayerPedId(), -1) end
local function release() ClearPedTasks(PlayerPedId()) end

local function rowsOf(list, desc)
    local options, items = {}, {}
    for _, row in ipairs(list or {}) do
        local name, label, price = row[1], row[2], tonumber(row[3])
        if type(name) == 'string' and price then
            options[#options + 1] = { label = tostring(label or name), desc = desc, price = price }
            items[#items + 1] = name
        end
    end
    return options, items
end

openBuy = function()
    local options, items = rowsOf(buyOpt.rows, buyOpt.desc)
    Menu.open({ title = buyOpt.title, subtitle = buyOpt.subtitle, options = options }, {
        select = function(i)
            if items[i] then TriggerServerEvent('legendaryhunt:buy', items[i]) end
            openBuy() -- stay on the list
        end,
        back = openRoot,
        closed = release,
    })
end

openSellGroup = function(index)
    local group = sellOpt.groups and sellOpt.groups[index] or {}
    local options, items = rowsOf(group.rows, sellOpt.desc)
    Menu.open({ title = sellOpt.title, subtitle = tostring(group.label or ''), options = options }, {
        select = function(i)
            if items[i] then TriggerServerEvent('legendaryhunt:sell', items[i]) end
            openSellGroup(index) -- one item per selection; stay on the list
        end,
        back = openSellGroups,
        closed = release,
    })
end

openSellGroups = function()
    -- every group shows, in config order
    local options = {}
    for _, group in ipairs(sellOpt.groups or {}) do
        options[#options + 1] = { label = tostring(group.label or ''), desc = sellOpt.desc }
    end
    Menu.open({ title = sellOpt.title, subtitle = sellOpt.subtitle, options = options }, {
        select = function(i)
            if sellOpt.groups and sellOpt.groups[i] then openSellGroup(i) else openSellGroups() end
        end,
        back = openRoot,
        closed = release,
    })
end

openRoot = function()
    standStill()
    local opened = Menu.open({
        title = shopData.title,
        subtitle = shopData.subtitle,
        options = {
            { label = tostring(buyOpt.title), desc = tostring(buyOpt.subtitle) },
            { label = tostring(sellOpt.title), desc = tostring(sellOpt.subtitle) },
        },
    }, {
        select = function(i)
            if i == 1 then openBuy() elseif i == 2 then openSellGroups() else release() end
        end,
        back = release,
        closed = release,
    })
    if not opened then release() end
end

-- called every frame by client/main.lua while the player stands by the trapper
function Trapper.frame()
    PromptSetActiveGroupThisFrame(group, Cli.varString(TR.name))
    if Cli.pressed(pShop) then openRoot() end
end
