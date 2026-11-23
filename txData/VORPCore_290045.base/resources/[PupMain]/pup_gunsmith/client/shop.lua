-- pup_gunsmith | gun store counter (pup-ui shop screen)
-- The client only names what it wants (kind, group, display name, amount). Prices and
-- stock are checked on the server against the counter this player opened.

ShopCl = {}

local visit = nil -- { counter, cash, asking, aborted }

local function stockOf(counter)
    return counter.stock or Config.ShopStock
end

local function show()
    if not visit then return end
    local items = {}
    for i, s in ipairs(stockOf(visit.counter)) do
        local img = s.kind == 'weapon' and tostring(s.weapon or ''):lower() or tostring(s.item or '')
        items[#items + 1] = {
            name = tostring(i),
            label = s.label,
            category = s.group,
            price = s.price,
            img = GS.itemImage(img),
            description = s.kind == 'ammo' and L('shop_ammo_desc') or nil,
        }
    end
    exports['pup-ui']:OpenShop({
        label = visit.counter.name or L('shop_title'),
        cash = visit.cash,
        items = items,
    })
end

local function leave()
    if not visit then return end
    visit = nil
    Cl.freeze(false)
    TriggerServerEvent('pup_gunsmith:shopLeave')
    if Cl.busy == 'shop' then Cl.busy = nil end
end

function ShopCl.open(counter)
    local res = Cl.rpc('shopOpen', counter.id)
    if not res or not res.ok then
        Cl.busy = nil
        Cl.tip(res and res.msg)
        return
    end
    visit = { counter = counter, cash = tonumber(res.cash) or 0, asking = false }
    Cl.busy = 'shop'
    Cl.freeze(true)
    Cl.blockJournal()
    show()
end

AddEventHandler('pup-ui:client:shopBuy', function(name)
    local v = visit
    if not v or v.asking then return end
    local entry = stockOf(v.counter)[tonumber(name) or -1]
    if not entry then return end
    v.asking = true

    local amount
    if entry.kind == 'weapon' then
        if Cl.askConfirm(entry.label, GS.dollars(entry.price), Config.Shop.confirmTimeoutMs) then amount = 1 end
    else
        amount = Cl.askAmount()
    end

    if amount and visit == v then
        local res = Cl.rpc('shopBuy', entry.kind, entry.group, entry.label, amount)
        if res then
            if res.msg then Cl.tip(res.msg) end
            if res.cash then v.cash = tonumber(res.cash) or v.cash end
        end
    end

    v.asking = false
    if visit ~= v then return end
    if v.aborted then return leave() end
    show() -- back to browsing with the current cash
end)

-- while the confirm or amount box is up, pup-ui closes the shop panel itself; that
-- close must not end the visit
AddEventHandler('pup-ui:client:shopClosed', function()
    if visit and not visit.asking then leave() end
end)

AddEventHandler('pup-ui:HideAllUI', function()
    if not visit then return end
    if visit.asking then visit.aborted = true else leave() end
end)

function ShopCl.stop()
    if not visit then return end
    pcall(function() exports['pup-ui']:HideShop() end)
    visit = nil
    Cl.freeze(false)
    ClearPedTasks(PlayerPedId())
end
