-- huntingbirds | bird shops: blips, markers, the shop prompt, the preview bird and the buy menu

Shop = {}

local OWNER <const> = 'huntingbirds:shop'
local NAME_INPUT <const> = 'huntingbirds:name'

local blips = {}
local cur = nil      -- { index, cat, variant, row } while a shop is open
local preview = nil
local previewGen = 0

function Shop.isOpen()
    return cur ~= nil
end

-------------------------------------------------------------------------------- blips
CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        if shop.blip.show then
            local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(b, shop.blip.sprite, true)
            SetBlipScale(b, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, Cl.varString(shop.name))
            blips[#blips + 1] = b
        end
    end
end)

function Shop.removeBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

-------------------------------------------------------------------------------- preview
local function deletePreview()
    previewGen = previewGen + 1
    local p = preview
    preview = nil
    if p then Cl.deleteAndWait(p, 2000) end
end

local function showPreview(catIndex, variantIndex)
    deletePreview()
    local gen = previewGen
    local shop = cur and Config.Shops[cur.index]
    local _, v = Util.variant(catIndex, variantIndex)
    if not shop or not v then return end
    local pos = shop.previewPos
    local ped = Cl.spawnPed(v.model, vector3(pos.x, pos.y, pos.z - 1.0), pos.w, false)
    if not ped then return end
    if gen ~= previewGen or not cur then Cl.deleteEntity(ped) return end
    SetEntityVisible(ped, false)
    Cl.dress(ped, v.preset)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    Cl.blockEvents(ped)
    if gen ~= previewGen or not cur then Cl.deleteEntity(ped) return end
    SetEntityVisible(ped, true)
    preview = ped
end

-------------------------------------------------------------------------------- menu
local function openMenu(startIndex)
    if not cur then return end
    local shop = Config.Shops[cur.index]
    local cat = Config.BirdCatalog[cur.cat]
    local names = {}
    for i, c in ipairs(Config.BirdCatalog) do names[i] = c.name end
    local options = { { label = Locale.menuSpecies, values = names, valueIndex = cur.cat } }
    for _, v in ipairs(cat.variants) do
        options[#options + 1] = {
            label = v.name,
            description = ('%s %s   $%s'):format(v.type, Locale.birdType, Util.money(Util.finalPrice(shop, v))),
        }
    end
    Cl.uiOwner = OWNER
    exports['pup-ui']:OpenInkMenu({
        owner = OWNER, title = shop.name, subtitle = Locale.shopGroup, startIndex = startIndex or 1, options = options,
    })
end

function Shop.close()
    if cur then
        exports['pup-ui']:HideInkMenu()
    end
    cur = nil
    if Cl.uiOwner == OWNER or Cl.uiOwner == NAME_INPUT then Cl.uiOwner = nil end
    deletePreview()
    ClearPedTasks(PlayerPedId())
end

local function open(shopIndex)
    local shop = Config.Shops[shopIndex]
    if not shop or cur or #Config.BirdCatalog == 0 then return end
    cur = { index = shopIndex, cat = 1 }
    Cl.uiOwner = OWNER
    TaskStandStill(PlayerPedId(), -1)

    local first = Config.BirdCatalog[1].variants[1]
    if not Cl.is(HasModelLoaded(first.model)) then Cl.toast(Locale.waitLoad, 'gold') end
    for _, c in ipairs(Config.BirdCatalog) do
        local m = c.variants[1].model
        if Cl.is(IsModelValid(m)) then RequestModel(m, false) end
    end
    for _, c in ipairs(Config.BirdCatalog) do Cl.loadModel(c.variants[1].model, 5000) end
    if not cur then return end

    showPreview(1, 1)
    if not cur then return end
    openMenu(1)
end

RegisterNetEvent('huntingbirds:openshop', function(shopIndex)
    shopIndex = Util.int(shopIndex, 1)
    if not shopIndex or Bird.isOut() then return end
    open(shopIndex)
end)

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner ~= OWNER or not cur then return end
    if index >= 2 then
        CreateThread(function() showPreview(cur and cur.cat or 1, index - 1) end)
    end
end)

AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    if owner ~= OWNER or not cur or index ~= 1 then return end
    if not Config.BirdCatalog[valueIndex] then return end
    cur.cat = valueIndex
    openMenu(1)
    CreateThread(function() showPreview(valueIndex, 1) end)
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not cur or index < 2 then return end
    local _, v = Util.variant(cur.cat, index - 1)
    if not v then return end
    cur.variant, cur.row = index - 1, index
    exports['pup-ui']:HideInkMenu()
    Cl.uiOwner = NAME_INPUT
    exports['pup-ui']:OpenInput({
        owner = NAME_INPUT,
        title = Locale.birdName,
        subtitle = v.name,
        submit = Locale.confirm,
        fields = { { label = Locale.birdName, type = 'text', maxlength = 32, required = true } },
    })
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER then return end
    Shop.close()
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= NAME_INPUT then return end
    if not cur then
        if Cl.uiOwner == NAME_INPUT then Cl.uiOwner = nil end
        return
    end
    local name = type(values) == 'table' and tostring(values[1] or '') or ''
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if name ~= '' then
        TriggerServerEvent('huntingbirds:buybird', cur.index, cur.cat, cur.variant, name)
        Shop.close()
    else
        openMenu(cur.row or 1)
    end
end)

-------------------------------------------------------------------------------- near a shop
CreateThread(function()
    local group = Cl.newGroup()
    local openPrompt = Cl.prompt(Config.Keys.openShop, Locale.openShop, group)
    while true do
        local sleep = 500
        local player = PlayerPedId()
        local pc = GetEntityCoords(player)
        for i, shop in ipairs(Config.Shops) do
            local d = #(pc - shop.coords)
            if d < 30.0 then
                sleep = 0
                if d < 15.0 and Config.Markers.showAtShops then
                    Cl.drawMarker(shop.coords.x, shop.coords.y, shop.coords.z - 1.0, 2.0, 2.0, 0.3)
                end
                if d < 1.3 and not cur and not Cl.uiOwner and not Cl.isDead(player) then
                    Cl.showGroup(group, ('%s - %s'):format(shop.name, Locale.shopGroup))
                    if Cl.pressed(openPrompt) and not Cl.isHogtied(player) then
                        if Bird.isOut() then
                            Cl.toast(Locale.sendHomeFirst, 'red')
                        else
                            TriggerServerEvent('huntingbirds:checkmenujob', i)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if preview then Cl.deleteEntity(preview) end
    Shop.removeBlips()
end)
