-- huntingbirds | owned-birds menu and selling a bird back to the shop

local OWNER <const> = 'huntingbirds:owned'
local SELLBACK <const> = 'huntingbirds:sellback'

local rows = nil -- [index] = { kind = 'call'|'sell'|'home'|'none', bird }
local sellBackId = nil

AddEventHandler('huntingbirds:callowneds', function()
    local ped = PlayerPedId()
    if Cl.isHogtied(ped) or Cl.isCuffed(ped) or Cl.isDead(ped) then return end
    TriggerServerEvent('huntingbirds:getOwnedBirds')
end)
RegisterNetEvent('huntingbirds:callowneds')

RegisterNetEvent('huntingbirds:ownedbirds', function(list)
    if type(list) ~= 'table' then return end
    if Shop.isOpen() then Shop.close() end

    local options = {}
    rows = {}
    for _, b in ipairs(list) do
        options[#options + 1] = { label = ('%s - %s'):format(tostring(b.name), Locale.menuCall), description = Locale.menuXp:format(tonumber(b.xp) or 0) }
        rows[#options] = { kind = 'call', bird = b }
        options[#options + 1] = { label = ('%s - %s $%s'):format(tostring(b.name), Locale.menuSell, Util.money(b.sellValue or 0)), description = Locale.menuSellDesc }
        rows[#options] = { kind = 'sell', bird = b }
    end
    if #list == 0 then
        options[#options + 1] = { label = Locale.menuNoBirds }
        rows[#options] = { kind = 'none' }
    else
        options[#options + 1] = { label = Locale.menuSendHome, description = Locale.menuSendHomeDesc }
        rows[#options] = { kind = 'home' }
    end

    Cl.uiOwner = OWNER
    exports['pup-ui']:OpenInkMenu({
        owner = OWNER, title = Locale.menuOwnedBirds, subtitle = Locale.menuSelectDesc, startIndex = 1, options = options,
    })
end)

local function closeMenu()
    exports['pup-ui']:HideInkMenu()
    if Cl.uiOwner == OWNER then Cl.uiOwner = nil end
    rows = nil
end

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not rows then return end
    local row = rows[index]
    if not row then return end
    local dead = Cl.isDead()

    if row.kind == 'call' then
        if Bird.isOut() or dead then Cl.toast(Locale.sendHomeFirst, 'red') return end
        closeMenu()
        Bird.callOut(row.bird.id)
    elseif row.kind == 'sell' then
        if Bird.isOut() or dead then Cl.toast(Locale.sendHomeFirst, 'red') return end
        closeMenu()
        sellBackId = row.bird.id
        Cl.uiOwner = SELLBACK
        exports['pup-ui']:OpenInput({
            owner = SELLBACK,
            title = Locale.menuSell,
            subtitle = Locale.confirmDelete:format(Config.SellBack.confirmWord),
            submit = Locale.confirm,
            fields = { { label = Config.SellBack.confirmWord, type = 'text', maxlength = 32 } },
        })
    elseif row.kind == 'home' then
        if Bird.isOut() and not dead then
            closeMenu()
            Bird.sendHome(false)
        else
            Cl.toast(Locale.sendHomeFirst, 'red')
            TriggerServerEvent('huntingbirds:birdhome') -- clears a record the server may still hold
        end
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER then return end
    if Cl.uiOwner == OWNER then Cl.uiOwner = nil end
    rows = nil
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= SELLBACK then return end
    if Cl.uiOwner == SELLBACK then Cl.uiOwner = nil end
    local id = sellBackId
    sellBackId = nil
    if not id or type(values) ~= 'table' then return end
    local typed = tostring(values[1] or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if typed:lower() == tostring(Config.SellBack.confirmWord):lower() then
        TriggerServerEvent('huntingbirds:DeleteBird', id)
    end
end)
