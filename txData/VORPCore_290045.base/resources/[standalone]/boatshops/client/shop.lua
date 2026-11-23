-- boatshops | the shop menus: buying, your boats, upgrades, previews

local CFG <const> = BoatConfig
local L <const> = BoatLocale
local T <const> = CFG.Timings
local resName <const> = GetCurrentResourceName()

local preview = nil        -- the local buy preview or upgrade display boat
local previewSeq = 0
local previewExtras = {}   -- extras switched on on the display boat
local armed = false        -- Space pressed: the next Enter buys or pays
local watching = nil       -- token of the running Space watcher
local spawnGuardUntil = 0

-- ------------------------------------------------------------------ upgrades on a vehicle

function BC.applyComponent(veh, cat, value)
    local none = value == nil or value == 'none'
    if cat == 'Extras' then
        local n = tonumber(value)
        if none or not n then BN.extra(veh, 0, false) else BN.extra(veh, n, true) end
    elseif cat == 'Tints' then
        BN.tint(veh, none and 0 or (tonumber(value) or 0))
    elseif cat == 'Liveries' then
        BN.livery(veh, none and -1 or (tonumber(value) or -1))
    elseif cat == 'Propsets' then
        BN.clearPropsets(veh)
        if not none then BN.addPropset(veh, tostring(value)) end
    end
end

function BC.applyComponents(veh, comps)
    for _, cat in ipairs(CFG.Categories) do
        if comps[cat] ~= nil then BC.applyComponent(veh, cat, comps[cat]) end
    end
end

-- ------------------------------------------------------------------ preview boats (local only)

local function deletePreview()
    previewSeq = previewSeq + 1
    if preview and DoesEntityExist(preview) then
        SetEntityAsMissionEntity(preview, true, true)
        DeleteVehicle(preview)
        if DoesEntityExist(preview) then DeleteEntity(preview) end
    end
    preview = nil
    previewExtras = {}
end
BC.deletePreview = deletePreview

-- a non-networked copy at the launch point, anchored and frozen
local function makePreview(shop, key, comps)
    deletePreview()
    local seq = previewSeq
    local base = Boat.catalogue(key)
    local hash = (base and tonumber(base.hash)) or GetHashKey(key)
    if not BN.loadModel(hash) then return nil end
    if seq ~= previewSeq or not BoatMenu.isOpen() then return nil end
    local l = shop.launch
    local veh = CreateVehicle(hash, l.x + 0.0, l.y + 0.0, l.z + 0.0, (l.h or 0.0) + 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then return nil end
    BN.anchor(veh, true)
    FreezeEntityPosition(veh, true)
    BN.noSink(veh)
    if comps then
        BC.applyComponents(veh, comps)
        local n = tonumber(comps.Extras)
        if n then previewExtras[n] = true end
    end
    TaskTurnPedToFaceEntity(PlayerPedId(), veh, 2000)
    preview = veh
    return veh
end

local function previewOption(cat, value)
    if not preview or not DoesEntityExist(preview) then return end
    if cat == 'Extras' then
        -- only one extra at a time, as only one is saved
        for n in pairs(previewExtras) do BN.extra(preview, n, false) end
        previewExtras = {}
        local n = tonumber(value)
        if value == 'none' or not n then
            BN.extra(preview, 0, false)
        else
            BN.extra(preview, n, true)
            previewExtras[n] = true
        end
    else
        BC.applyComponent(preview, cat, value)
    end
end

-- ------------------------------------------------------------------ Space watcher

local function stopWatching()
    watching = nil
    armed = false
end

-- while a buy or upgrade list is up, Space arms the next Enter
local function watchSpace(shop, kind)
    local token = {}
    watching = token
    armed = false
    CreateThread(function()
        local pr = kind == 'buy' and BC.prompts.buy or BC.prompts.mods
        while watching == token and BoatMenu.isOpen() do
            Wait(0)
            DisableControlAction(0, CFG.Keys.use, true)
            if pr then BN.showPrompt(pr, shop.name) end
            local pressed = (pr and BN.promptDone(pr)) or IsDisabledControlJustPressed(0, CFG.Keys.use)
            if pressed and not armed then
                armed = true
                BC.tip(kind == 'buy' and L.pressBuy or L.pressPay, T.armedTipMs)
            end
        end
    end)
end

-- ------------------------------------------------------------------ input form

local inputWaiter = nil

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if not inputWaiter or owner ~= inputWaiter.owner then return end
    local w = inputWaiter
    inputWaiter = nil
    w.p:resolve(type(values) == 'table' and values or false)
end)

-- one-field form; the answer, or nil when cancelled
local function askOne(title, field)
    local owner = ('%s:input:%d'):format(resName, GetGameTimer())
    local p = promise.new()
    inputWaiter = { owner = owner, p = p }
    exports['pup-ui']:OpenInput({ owner = owner, title = title, submit = L.confirm, fields = { field } })
    local values = Citizen.Await(p)
    if type(values) ~= 'table' then return nil end
    return values[1]
end

-- ------------------------------------------------------------------ session

local session = { shop = nil, sale = false }

BoatMenu.onClose = function()
    stopWatching()
    deletePreview()
    local shop = session.shop
    if shop and not session.sale then BC.say(shop, 'FAREWELL_NO_SALE') end
    session.shop, session.sale = nil, false
    BC.shop = nil
end

-- closes the menu without the "no sale" farewell
local function closeForSale()
    session.sale = true
    BoatMenu.close()
end

-- shuts the menu if the player walks off or dies
local function guard(shop)
    CreateThread(function()
        while BoatMenu.isOpen() and session.shop == shop do
            Wait(500)
            local ped = PlayerPedId()
            if IsEntityDead(ped) or BC.dist3(GetEntityCoords(ped), shop.counter) > shop.openRadius + 5.0 then
                BoatMenu.close()
            end
        end
    end)
end

local hintsArm = {
    { keys = { 'Space' }, label = L.hintArm },
    { keys = { 'Enter' }, label = L.hintConfirm },
    { keys = { 'Esc' }, label = L.hintBack },
}

local function async(fn, ...)
    local args = table.pack(...)
    CreateThread(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then print(('^1[boatshops]^7 %s'):format(tostring(err))) end
    end)
end

-- ------------------------------------------------------------------ buying

local function buy(shop, entry)
    closeForSale()
    local name = askOne(L.nameTitle, { label = L.nameLabel, type = 'text', maxlength = CFG.Name.max, required = true })
    if type(name) ~= 'string' or name:gsub('%s', '') == '' then
        BC.tip(L.addValue)
        return BC.say(shop, 'FAREWELL_NO_SALE')
    end
    BC.say(shop, 'FAREWELL_BIG_SALE')
    TriggerServerEvent('boatshops:buy', shop.id, entry.key, name)
end

local function buyLevel(shop)
    local opts = {}
    for _, e in ipairs(shop.boats) do
        opts[#opts + 1] = {
            label = e.label,
            description = L.buyRowDesc:format(Boat.money(e.buy), tostring(e.slots), tostring(e.desc or '')),
            entry = e,
            onSelect = function(opt)
                if armed then return async(buy, shop, opt.entry) end
                async(makePreview, shop, opt.entry.key, nil)
            end,
        }
    end
    return {
        title = shop.name,
        subtitle = L.buyListTitle,
        options = opts,
        hints = hintsArm,
        onMove = function(_, opt) async(makePreview, shop, opt.entry.key, nil) end,
        onBack = function()
            BoatMenu.close()
            return true
        end,
        onLeave = function()
            stopWatching()
            deletePreview()
        end,
    }
end

-- ------------------------------------------------------------------ your boats

local function spawnBoat(shop, b)
    if GetGameTimer() < spawnGuardUntil then return BC.tip(L.spawning, 3000) end
    spawnGuardUntil = GetGameTimer() + T.spawnGuardMs
    BC.fetchBoats()
    if BC.isOut(b.id) then return BC.tip(L.alreadyOut) end
    if BC.active then return BC.tip(L.otherOut) end
    BoatMenu.close()
    TriggerServerEvent('boatshops:spawn', shop.id, b.id)
end

local function giveBoat(shop, b)
    BC.fetchBoats()
    if BC.isOut(b.id) then return BC.tip(L.parkFirst) end
    BoatMenu.close()
    local v = askOne(L.playerIdTitle, { label = L.playerIdLabel, type = 'number', min = 1, required = true })
    local id = tonumber(v)
    if not id or id <= 0 or id ~= math.floor(id) then return BC.tip(L.addValue) end
    TriggerServerEvent('boatshops:give', shop.id, b.id, id)
end

local function sellBoat(shop, b)
    if BC.isClosed(shop) then return BC.tip(L.storeClosed) end
    BC.fetchBoats()
    if BC.isOut(b.id) then return BC.tip(L.parkFirst) end
    BC.say(shop, 'ENTER_SELL_MENU')
    closeForSale()
    TriggerServerEvent('boatshops:sell', shop.id, b.id)
    BC.say(shop, 'FAREWELL_SALE')
end

local function boatLevel(shop, b, entry, closedMode)
    return {
        title = L.boatMenu,
        subtitle = shop.id,
        options = {
            { label = L.spawnBoat, description = L.spawnBoatDesc, onSelect = function() async(spawnBoat, shop, b) end },
            { label = L.giveBoat, description = L.giveBoatDesc, onSelect = function() async(giveBoat, shop, b) end },
            {
                label = L.sellBoat,
                description = L.sellBoatDesc:format(Boat.money(entry.sell)),
                onSelect = function() async(sellBoat, shop, b) end,
            },
        },
        onBack = function()
            if closedMode then
                BoatMenu.close()
                return true
            end
        end,
    }
end

local function ownedLevel(shop, closedMode)
    local opts = {}
    for _, b in ipairs(BC.boats) do
        opts[#opts + 1] = {
            label = b.name,
            description = L.ownedRowDesc:format(b.name),
            onSelect = function()
                local entry = Boat.entry(shop, b.boat)
                if not entry then
                    BC.tip(L.notHere)
                    return BoatMenu.close()
                end
                BoatMenu.push(boatLevel(shop, b, entry, closedMode))
            end,
        }
    end
    return { title = L.ownedTitle, subtitle = shop.name, options = opts }
end

-- ------------------------------------------------------------------ upgrades

local function pay(shop, b, cat, opt)
    closeForSale()
    TriggerServerEvent('boatshops:fit', shop.id, b.id, cat, opt.value)
    SetTimeout(2000, function() BC.say(shop, 'FAREWELL_BIG_SALE') end)
end

local function optionsLevel(shop, b, cat, list)
    local opts = {}
    for _, o in ipairs(list) do
        opts[#opts + 1] = {
            label = o.name,
            description = L.optionDesc:format(Boat.money(o.price)),
            opt = o,
            onSelect = function(row)
                if armed then return pay(shop, b, cat, row.opt) end
                previewOption(cat, row.opt.value)
                BC.say(shop, 'SALES_PITCH')
            end,
        }
    end
    return {
        title = L.categories[cat] or cat,
        subtitle = b.name,
        options = opts,
        hints = hintsArm,
        onMove = function(_, row) previewOption(cat, row.opt.value) end,
        onBack = function()
            BoatMenu.close()
            return true
        end,
        onLeave = function()
            stopWatching()
            deletePreview()
        end,
    }
end

local function openCategory(shop, b, cat)
    local list = Boat.options(cat, b.boat)
    if not list then return BC.tip(L.noMods, T.noModsTipMs) end
    BC.say(shop, 'HAVE_A_LOOK')
    makePreview(shop, b.boat, Boat.decode(b.components))
    if not BoatMenu.isOpen() then return deletePreview() end
    watchSpace(shop, 'mods')
    BoatMenu.push(optionsLevel(shop, b, cat, list))
end

local function categoryLevel(shop, b)
    local opts = {}
    for _, cat in ipairs(CFG.Categories) do
        opts[#opts + 1] = {
            label = L.categories[cat] or cat,
            onSelect = function() async(openCategory, shop, b, cat) end,
        }
    end
    return { title = L.categoryTitle, subtitle = b.name, options = opts }
end

local function pickUpgradeBoat(shop, b)
    BC.fetchBoats()
    if BC.isOut(b.id) then return BC.tip(L.parkFirst) end
    if not Boat.entry(shop, b.boat) then return BC.tip(L.notHereUpgrade) end
    BC.say(shop, 'HAVE_A_LOOK')
    BoatMenu.push(categoryLevel(shop, b))
end

local function upgradeLevel(shop)
    local opts = {}
    for _, b in ipairs(BC.boats) do
        opts[#opts + 1] = {
            label = b.name,
            description = L.upgradeRowDesc:format(b.name),
            onSelect = function() async(pickUpgradeBoat, shop, b) end,
        }
    end
    return { title = L.upgradeTitle, subtitle = shop.name, options = opts }
end

-- ------------------------------------------------------------------ main menu

local function openOwned(shop)
    BC.fetchBoats()
    if #BC.boats == 0 then return BoatMenu.close() end
    BoatMenu.push(ownedLevel(shop, false))
end

local function openUpgrades(shop)
    BC.fetchBoats()
    if #BC.boats == 0 then return end
    BC.say(shop, 'CATALOG_IDLING')
    BoatMenu.push(upgradeLevel(shop))
end

local function mainLevel(shop)
    return {
        title = shop.name,
        options = {
            {
                label = L.purchase, description = L.purchaseDesc,
                onSelect = function()
                    watchSpace(shop, 'buy')
                    BoatMenu.push(buyLevel(shop))
                end,
            },
            { label = L.yourBoats, description = L.yourBoatsDesc, onSelect = function() async(openOwned, shop) end },
            { label = L.upgradeBoats, description = L.upgradeBoatsDesc, onSelect = function() async(openUpgrades, shop) end },
        },
    }
end

local function openShop(shop)
    -- job-locked docks ask the server; others get nothing
    if type(shop.jobs) == 'table' and #shop.jobs > 0 and not BC.askAccess(shop.id) then return end

    local keeper = BC.keeperOf(shop)
    if keeper then
        BN.speak(keeper, 'WELCOME')
        TaskTurnPedToFaceEntity(keeper, PlayerPedId(), T.keeperFaceMs)
    end

    if BC.isClosed(shop) then
        BC.tip(BC.hoursText(shop), T.closedTipMs)
        BC.fetchBoats()
        if #BC.boats == 0 then return BC.tip(L.noBoats) end
        session.shop, session.sale = shop, false
        BC.shop = shop
        BoatMenu.open(ownedLevel(shop, true))
    else
        session.shop, session.sale = shop, false
        BC.shop = shop
        BoatMenu.open(mainLevel(shop))
    end
    guard(shop)
end

function BC.openShop(shop)
    local ok, err = pcall(openShop, shop)
    if not ok then print(('^1[boatshops]^7 %s'):format(tostring(err))) end
    BC.busy = false
end

function BC.cleanupShop()
    stopWatching()
    deletePreview()
    session.shop, session.sale = nil, false
end
