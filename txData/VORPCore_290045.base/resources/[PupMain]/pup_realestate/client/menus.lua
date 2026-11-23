-- pup_realestate | house menus: door, buy, manage, ledgers, keys, furniture, upgrades, stash, wardrobe,
-- Sold Home Ledger, motels

local function info(label, description) return { label = label, description = description } end

function C.doorBySeq(h, seq)
    if seq == 0 then return (h.doors or {})[1] end
    for _, d in ipairs(h.other or {}) do
        if type(d) == 'table' and U.int(d.secondarydoorid) == seq then return d end
    end
    return nil
end

-- buy and manage menus hold the house's menu lock and keep the player standing still
local function startSession(id)
    local ok = Rpc('sv_lock', nil, id, true)
    if not ok then
        C.tip(Locale.menu_in_use)
        return false
    end
    C.menuHouse = id
    TaskStandStill(C.ped(), -1)
    return true
end

local function endSession(id)
    return function()
        ClearPedTasks(C.ped())
        if C.menuHouse == id then C.menuHouse = nil end
        CreateThread(function() Rpc('sv_lock', 3000, id, false) end)
    end
end

-- a house menu follows its house: refresh when it changes, close when it goes
C.onChange(function(id)
    if not C.menuHouse or not Menu.isOpen() then return end
    if id == nil or id == C.menuHouse then
        if not C.houses[C.menuHouse] then Menu.close() else Menu.refresh() end
    end
end)

-- door menu
function C.openDoorMenu(h)
    local id = h.id
    local opts = {}
    if not h.owned then
        opts[#opts + 1] = { label = Locale.buy_house, select = function() Menu.close(); C.openBuyMenu(id) end }
        opts[#opts + 1] = { label = Locale.view_inside, select = function() Send('sv_view', id); Menu.close() end }
    elseif h.kind == KIND_TELE then
        if C.hasAccess(h) then
            opts[#opts + 1] = { label = Locale.enter_house, select = function() Menu.close(); C.enterHouse(id) end }
        else
            opts[#opts + 1] = { label = Locale.knock_door, select = function() Menu.close(); C.knock(id) end }
        end
    elseif C.hasAccess(h) then
        opts[#opts + 1] = { label = Locale.manage_house, select = function() Menu.close(); C.openManage(id) end }
    end
    if #opts == 0 then return C.tip(Locale.nothing_here) end
    local subtitle
    if not h.owned then
        subtitle = T('for_sale_price', U.money(h.price))
    elseif h.kind == KIND_REAL and h.doors and h.doors[1] and h.doors[1].locked then
        subtitle = Locale.locked
    end
    Menu.open(function()
        return { title = T('house_title', id), subtitle = subtitle, options = opts }
    end)
end

-- buy menu
function C.openBuyMenu(id)
    local h = C.houses[id]
    if not h or h.owned then return end
    if not startSession(id) then return end
    local job = C.refreshJob()
    local mayRemove = (job.job == Config.Jobs.realtor and (tonumber(job.grade) or 0) >= Config.Jobs.realtorDeleteGrade)
        or job.group == 'admin' or job.group == 'superadmin'
    Menu.open(function()
        local cur = C.houses[id]
        if not cur or cur.owned then return nil end
        local opts = { info(T('house_id', id)) }
        local auctioned = C.auctioned[id]
        if not auctioned then
            opts[#opts + 1] = info(T('price_row', U.money(cur.price)))
            opts[#opts + 1] = info(T('tax_row', U.money(cur.tax)))
            opts[#opts + 1] = info(T('space_row', cur.slots))
        end
        if mayRemove then
            opts[#opts + 1] = { label = Locale.remove_house, select = function()
                Menu.confirm(Locale.remove_house, Locale.are_you_sure, function()
                    Send('sv_delete', id)
                    Menu.close()
                end)
            end }
        end
        if auctioned then
            opts[#opts + 1] = info(Locale.at_auction, Locale.at_auction_desc)
        else
            opts[#opts + 1] = { label = Locale.buy_house, select = function()
                Menu.confirm(Locale.buy_house, T('for_sale_price', U.money(cur.price)), function()
                    if C.ownedCount() >= Config.MaxHousesPerCharacter then
                        C.tip(T('house_cap', Config.MaxHousesPerCharacter))
                    else
                        Send('sv_buy', id)
                    end
                    Menu.close()
                end)
            end }
        end
        return { title = T('house_title', id), subtitle = Locale.buy_house, options = opts }
    end, endSession(id))
end

-- manage menu
local function ledgerMenu(id, state)
    return function()
        return {
            title = Locale.ledger, subtitle = T('house_title', id),
            options = {
                info(T('ledger_cash', U.money(state.ledger))),
                { label = Locale.ledger_deposit, select = function()
                    local n = AskAmount(Locale.ledger_deposit)
                    if n then Send('sv_ledger', id, 'deposit', n); state.reload() end
                end },
                { label = Locale.ledger_withdraw, select = function()
                    local n = AskAmount(Locale.ledger_withdraw)
                    if n then Send('sv_ledger', id, 'withdraw', n); state.reload() end
                end },
            },
        }
    end
end

local function takeKeysMenu(id)
    return function()
        local h = C.houses[id]
        if not h then return nil end
        local opts = {}
        for _, k in ipairs(h.keys or {}) do
            local charid, name = k.charid, tostring(k.name or k.charid)
            opts[#opts + 1] = { label = name, select = function()
                Send('sv_takeKey', id, charid)
                Menu.back()
            end }
        end
        if #opts == 0 then opts[1] = info(Locale.key_holders_none) end
        return { title = Locale.take_keys, subtitle = T('house_title', id), options = opts }
    end
end

local function interiorMenu(id)
    return function()
        local h = C.houses[id]
        if not h then return nil end
        local current = U.interiorName(h)
        local names = {}
        for name in pairs(Config.Interiors) do
            if name ~= current then names[#names + 1] = name end
        end
        table.sort(names)
        local opts = {}
        for _, name in ipairs(names) do
            local price = Config.Interiors[name].price or 0
            opts[#opts + 1] = { label = T('interior_row', name, U.money(price)), select = function()
                Menu.confirm(Locale.change_interior, T('interior_row', name, U.money(price)), function()
                    Send('sv_interior', id, name)
                    Menu.close()
                end)
            end }
        end
        return { title = Locale.change_interior, subtitle = T('house_title', id), options = opts }
    end
end

local function upgradeMenu(id)
    return function()
        local h = C.houses[id]
        if not h then return nil end
        local level = Upgrades.byLevel[(h.upgrade or 0) + 1]
        local opts = {}
        if level then
            for _, m in ipairs(level.materials) do opts[#opts + 1] = info(T('material_row', m.label, m.amount)) end
            opts[#opts + 1] = { label = T('upgrade_row', level.title, level.slots), select = function()
                Send('sv_upgrade', id)
            end }
        end
        return { title = Locale.upgrade_storage, subtitle = T('house_title', id), options = opts }
    end
end

local function piecesMenu(id, title, labelFn, onPick)
    return function()
        local h = C.houses[id]
        if not h then return nil end
        local opts = {}
        for _, p in ipairs(h.furniture or {}) do
            local piece = p
            opts[#opts + 1] = { label = labelFn(piece), select = function() onPick(piece) end }
        end
        return { title = title, subtitle = T('house_title', id), options = opts }
    end
end

local function furnitureMenu(id)
    return function()
        local opts = {}
        if Config.Furniture.useItems then
            opts[#opts + 1] = { label = Locale.place_furniture, select = function()
                local list = Rpc('sv_furnList', nil, id) or {}
                Menu.push(function()
                    local rows = {}
                    for _, e in ipairs(list) do
                        local entry = e
                        rows[#rows + 1] = { label = entry.name, select = function()
                            Menu.close()
                            C.placeFurniture(id, { key = entry.item, name = entry.name, model = entry.model })
                        end }
                    end
                    return { title = Locale.place_furniture, subtitle = T('house_title', id), options = rows }
                end)
            end }
            opts[#opts + 1] = { label = Locale.remove_furniture, sub = piecesMenu(id, Locale.remove_furniture,
                function(p) return tostring(p.name) end,
                function(p) Send('sv_furnRemove', id, p.id) end) }
        else
            opts[#opts + 1] = { label = Locale.buy_furniture, sub = function()
                local rows = {}
                for _, cat in ipairs(Catalog.sortedCategories) do
                    local category = cat
                    rows[#rows + 1] = { label = category.name, sub = function()
                        local entries = {}
                        for _, e in ipairs(category.entries) do
                            local entry = e
                            entries[#entries + 1] = { label = T('furniture_cost', entry.name, entry.cost), select = function()
                                Menu.close()
                                C.placeFurniture(id, { key = entry.name, name = entry.name, model = entry.model })
                            end }
                        end
                        return { title = category.name, subtitle = Locale.buy_furniture, options = entries }
                    end }
                end
                return { title = Locale.furniture_category, subtitle = Locale.buy_furniture, options = rows }
            end }
            opts[#opts + 1] = { label = Locale.sell_furniture, sub = piecesMenu(id, Locale.sell_furniture,
                function(p)
                    local refund = math.floor((tonumber(p.price) or 0) * (tonumber(Config.Furniture.sellRate) or 0))
                    return T('furniture_price', tostring(p.name), refund)
                end,
                function(p) Send('sv_furnSell', id, p.id) end) }
        end
        return { title = Locale.furniture, subtitle = T('house_title', id), options = opts }
    end
end

function C.openManage(id)
    local h = C.houses[id]
    if not h or not C.hasAccess(h) then return end
    if not startSession(id) then return end
    local state = { ledger = 0, taxledger = 0 }
    local function load()
        local l, t = Rpc('sv_balances', nil, id)
        state.ledger, state.taxledger = tonumber(l) or 0, tonumber(t) or 0
    end
    state.reload = function()
        CreateThread(function()
            Wait(400)
            load()
            Menu.refresh()
        end)
    end
    load()
    Menu.open(function()
        local cur = C.houses[id]
        if not cur or not C.hasAccess(cur) then return nil end
        local owner = C.isOwner(cur)
        local opts = { info(T('house_id', id)), info(T('tax_row', U.money(cur.tax))) }
        if owner then
            if Config.Ledger.taxLedger then
                opts[#opts + 1] = { label = T('tax_ledger_row', U.money(state.taxledger)), description = Locale.tax_ledger_desc, select = function()
                    local n = AskAmount(Locale.tax_ledger_box)
                    if n then Send('sv_ledger', id, 'tax', n); state.reload() end
                end }
            end
            opts[#opts + 1] = { label = Locale.give_keys, select = function()
                local v = Ask(Locale.give_keys, { { label = Locale.give_keys_box, type = 'number', min = 1, required = true } })
                local target = v and U.int(v[1])
                if target then Send('sv_giveKey', id, target) end
            end }
            opts[#opts + 1] = { label = Locale.take_keys, sub = takeKeysMenu(id) }
            if not Config.Ledger.disabled then
                opts[#opts + 1] = { label = Locale.ledger, sub = ledgerMenu(id, state) }
            end
            if Config.OwnerWebhooks then
                opts[#opts + 1] = { label = Locale.house_log, description = Locale.house_log_desc, select = function()
                    local v = Ask(Locale.house_log_box, { { label = 'URL', type = 'text', maxlength = 255 } })
                    if v then Send('sv_webhook', id, tostring(v[1] or '')) end
                end }
            end
            opts[#opts + 1] = { label = Locale.sell_house, select = function()
                Menu.confirm(Locale.sell_house, Locale.are_you_sure, function()
                    Send('sv_sell', id)
                    Menu.close()
                end)
            end }
            if Config.AllowInteriorChange and cur.kind == KIND_TELE and C.insideHouse(id) then
                opts[#opts + 1] = { label = Locale.change_interior, sub = interiorMenu(id) }
            end
        end
        local rules = Config.Rules
        if owner or rules.keyholderSpots then
            opts[#opts + 1] = { label = Locale.set_wardrobe, select = function() Menu.close(); C.setSpot(id, 'changing') end }
            opts[#opts + 1] = { label = Locale.set_stash, select = function() Menu.close(); C.setSpot(id, 'stash') end }
        end
        if owner or rules.keyholderFurniture then
            opts[#opts + 1] = { label = Locale.furniture, sub = furnitureMenu(id) }
        end
        if owner or rules.keyholderUpgrades then
            opts[#opts + 1] = { label = Locale.upgrade_storage, sub = upgradeMenu(id) }
        end
        return { title = T('house_title', id), subtitle = Locale.manage_house, options = opts }
    end, endSession(id))
end

-- setting the stash or wardrobe spot
local function justPressed(c) return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) end

function C.setSpot(id, which)
    if C.busy then return end
    C.busy = true
    CreateThread(function()
        local label = which == 'changing' and Locale.save_wardrobe_here or Locale.save_stash_here
        while true do
            Wait(0)
            local h = C.houses[id]
            if not h or not C.hasAccess(h) then break end
            UI:Prompt({ key = 'G', label = label })
            if justPressed(Config.Keys.interact) then
                local pos = C.pos()
                local door = U.frontDoor(h)
                if not C.insideHouse(id) and (not door or #(pos - door) > (tonumber(h.range) or 0)) then
                    C.tip(Locale.out_of_range)
                else
                    Send('sv_spot', id, which, { x = pos.x, y = pos.y, z = pos.z })
                    C.tip(which == 'changing' and Locale.wardrobe_set or Locale.stash_set)
                    break
                end
            elseif justPressed(Config.Keys.back) then
                break
            end
        end
        UI:PromptHide()
        C.busy = false
    end)
end

-- stash
C.stashPending = false
local stashToken

function C.openStash(row, isMotel)
    if C.stashPending then return end
    if not isMotel then
        local ok = Rpc('sv_lock', nil, row, true)
        if not ok then return C.tip(Locale.menu_in_use) end
        C.stashLock = row
    end
    C.stashPending = true
    local token = {}
    stashToken = token
    Send('sv_stash', row)
    SetTimeout(Config.Timers.stashGuard, function()
        if stashToken == token then C.stashPending = false end
    end)
end

AddEventHandler('pup:closeinv', function()
    C.stashPending = false
    stashToken = nil
    local row = C.stashLock
    C.stashLock = nil
    if row then CreateThread(function() Rpc('sv_lock', 3000, row, false) end) end
end)

RegisterNetEvent('pup_realestate:cl_stashDone', function()
    C.stashPending = false
    stashToken = nil
    C.stashLock = nil
end)

-- wardrobe
function C.openWardrobe(row)
    local list = Rpc('sv_outfits', nil, row)
    if type(list) ~= 'table' then return end
    Menu.open(function()
        local opts = {}
        for _, o in ipairs(list) do
            local outfit = o
            opts[#opts + 1] = { label = outfit.title, select = function()
                Send('sv_outfit', row, outfit.index, outfit.title)
                Menu.close()
            end }
        end
        if #opts == 0 then opts[1] = info(Locale.no_outfits) end
        return { title = Locale.wardrobe, options = opts }
    end)
end

local CATEGORIES = {
    Hat = 0x9925C067, EyeWear = 0x5E47CA6, Mask = 0x7505EF42, NeckWear = 0x5FC29285, NeckTies = 0x7A96FACA,
    Shirt = 0x2026C46D, Suspender = 0x877A2CF7, Vest = 0x485EE834, Coat = 0xE06D30CE, CoatClosed = 0x0662AC34,
    Poncho = 0xAF14310B, Cloak = 0x3C1A74CD, Glove = 0xEABE0032, RingRh = 0x7A6BBD0B, RingLh = 0xF16A1D23,
    Bracelet = 0x7BC10759, Gunbelt = 0x9B2C8B89, Belt = 0xA6D134C6, Buckle = 0xFAE9107F, Holster = 0xB6B6122D,
    Skirt = 0x8E84A2AA, Chap = 0x3107499B, Boots = 0x777EC6EF, Spurs = 0x18729F39, Spats = 0x514ADCEA,
    Gauntlets = 0x91CE9B20, Loadouts = 0x83887E88, Accessories = 0x79D7DF96, Satchels = 0x94504D26,
    GunbeltAccs = 0xF1542D11, Pant = 0x1D4C528A,
}

local function playAnim(a)
    if not a or not a.dict then return end
    RequestAnimDict(a.dict)
    local t = 0
    while not HasAnimDictLoaded(a.dict) and t < 2000 do Wait(50); t = t + 50 end
    if HasAnimDictLoaded(a.dict) then
        TaskPlayAnim(C.ped(), a.dict, a.name, 8.0, -8.0, a.ms or 2000, 0, 0, false, false, false)
    end
end

RegisterNetEvent('pup_realestate:cl_dress', function(comps)
    if type(comps) ~= 'string' then return end
    local ok, outfit = pcall(json.decode, comps)
    if not ok or type(outfit) ~= 'table' then return end
    TriggerEvent('vorpcharacter:savenew', comps)
    playAnim(Config.Anims.outfit)
    local ped = C.ped()
    local female = not IsPedMale(ped)
    for key, hash in pairs(CATEGORIES) do
        local comp = outfit[key]
        if type(comp) == 'table' then comp = comp.comp or comp.hash end
        comp = tonumber(comp)
        if comp and comp ~= -1 and comp ~= 0 then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, hash, 0) -- remove the category
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, comp, true, true, female)  -- temporary
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, comp, false, true, female) -- saved
        end
    end
    local skirt = tonumber(type(outfit.Skirt) == 'table' and (outfit.Skirt.comp or outfit.Skirt.hash) or outfit.Skirt)
    if skirt and skirt ~= -1 and skirt ~= 0 then
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, CATEGORIES.Pant, 0)
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) -- refresh variation
end)

-- Sold Home Ledger
C.soldList = nil

function C.openSoldLedger()
    C.soldList = Rpc('sv_soldList', nil) or {}
    Menu.open(function()
        local opts = {}
        for _, r in ipairs(C.soldList or {}) do
            local row = r
            opts[#opts + 1] = { label = T('sold_row', row.id, U.money(row.amount)), select = function()
                Send('sv_soldCollect', row.id, row.amount)
            end }
        end
        if #opts == 0 then opts[1] = info(Locale.no_sold) end
        return { title = Locale.sold_ledger, options = opts }
    end, function() C.soldList = nil end)
end

RegisterNetEvent('pup_realestate:cl_soldList', function(list)
    if C.soldList then
        C.soldList = type(list) == 'table' and list or {}
        Menu.refresh()
    end
end)

-- motels
function C.openMotelMenu(key)
    local m = U.motel(key)
    if not m then return end
    Menu.open(function()
        local room = C.roomAt(key)
        local opts = {}
        if room then
            opts[#opts + 1] = { label = Locale.enter, select = function()
                Menu.close()
                C.enterMotel(room.id, key)
            end }
        elseif not C.motelPending then
            opts[#opts + 1] = { label = T('buy_room', U.money(m.price)), select = function()
                C.motelPending = true
                local token = {}
                C.motelToken = token
                Send('sv_motelBuy', key)
                Menu.close()
                SetTimeout(Config.Timers.motelGuard, function()
                    if C.motelToken == token then C.motelPending = nil end
                end)
            end }
        end
        return { title = m.name, subtitle = room and Locale.hotel or T('hotel_price', U.money(m.price)), options = opts }
    end)
end

-- the small menu at a teleporter interior's entry point
function C.openExitMenu(row)
    local h = C.houses[row]
    Menu.open(function()
        local opts = { { label = Locale.exit, select = function() Menu.close(); C.leaveHouse() end } }
        if h and C.hasAccess(h) then
            opts[#opts + 1] = { label = Locale.manage_house, select = function() Menu.close(); C.openManage(row) end }
        end
        return { title = T('house_title', row), options = opts }
    end)
end
