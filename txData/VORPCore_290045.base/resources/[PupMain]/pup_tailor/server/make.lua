-- pup_tailor | making clothing: copy what you wear, and make from the mannequin.
local U = Tailor.U
local Cat = Tailor.Cat

local DESC_MAX <const> = 255
local MAX_ENTRIES <const> = 64
local MAX_SLOT_LEN <const> = 32

-- validate and price the outfit; returns { outfit, cash, materials } or nil
-- anySlot: the garment only has to belong to the sex (worn data uses VORP's slot names)
local function priceOutfit(outfit, sex, anySlot)
    if not U.isMap(outfit) or U.count(outfit) > MAX_ENTRIES then return nil end
    local clean, cash = {}, 0
    local mats, order = {}, {}
    for slot, h in pairs(outfit) do
        if type(slot) ~= 'string' or #slot > MAX_SLOT_LEN or slot == 'colors' then return nil end
        local hash = U.int(h)
        if not hash then return nil end
        if Srv.isHidden(hash) then return nil end
        local p = Cat.price(hash)
        if not p then return nil end
        if anySlot then
            if not Cat.belongsSex(hash, sex) then return nil end
        elseif not Cat.belongs(hash, sex, slot) then return nil end
        clean[slot] = hash
        cash = cash + p.cash
        for _, m in ipairs(p.items) do
            if not mats[m.name] then
                mats[m.name] = { name = m.name, label = m.label, count = 0 }
                order[#order + 1] = mats[m.name]
            end
            mats[m.name].count = mats[m.name].count + m.count
        end
    end
    return { outfit = clean, cash = cash, materials = order }
end

---------------------------------------------------------------------------
-- copy the worn outfit (garments only, never dye)
-- priced like the mannequin: Config.CopyPrice plus each garment's cash and materials;
-- a hidden, unpriced or other-sex garment cannot be copied
---------------------------------------------------------------------------
local function copyOutfit(src, sex, desc)
    if sex ~= 'm' and sex ~= 'f' then return end
    local char = Srv.char(src)
    if not char then return end
    if not Srv.requireBench(src, char) then return end
    desc = U.cleanText(desc, DESC_MAX, true)
    if desc == '' then return end

    -- the character's own sex when the server knows it
    local g = type(char.gender) == 'string' and char.gender:lower() or ''
    if g == 'male' or g == 'female' then sex = g:sub(1, 1) end
    local sexName = sex == 'm' and 'male' or 'female'

    local worn = U.decodeMap(char.comps) or {}
    local garments = {}
    for slot, v in pairs(worn) do
        if slot ~= 'colors' and type(slot) == 'string' and slot:lower() ~= 'teeth' and U.isReal(v) then
            garments[slot] = U.int(v)
        end
    end
    if next(garments) == nil then return Srv.notify(src, L('nothingToCopy'), 5000) end

    local priced = priceOutfit(garments, sexName, true)
    if not priced then return Srv.notify(src, L('cannotCopy'), 5000) end
    local outfit = priced.outfit
    local price = (tonumber(Config.CopyPrice) or 0) + priced.cash
    local needs = priced.materials

    if (tonumber(char.money) or 0) < price then
        return Srv.notify(src, L('notEnoughMoney', price), 5000)
    end
    local short = Srv.shortList(src, needs)
    if short then
        return Srv.notify(src, L('notEnoughMaterials') .. ' - ' .. table.concat(short, ', '), 6000)
    end
    if not Srv.canCarry(src, 'clothingset', 1) then return Srv.notify(src, L('cantCarry'), 5000) end

    -- re-check on a fresh snapshot right before paying
    local same, now = Srv.sameChar(src, char.charIdentifier)
    if not same or (tonumber(now.money) or 0) < price then return end

    if not Srv.takeMaterials(src, needs) then
        return Srv.notify(src, L('notEnoughMaterials'), 5000)
    end
    same, now = Srv.sameChar(src, char.charIdentifier)
    if not same or (tonumber(now.money) or 0) < price then
        Srv.giveBack(src, needs)
        return Srv.notify(src, L('notEnoughMoney', price), 5000)
    end
    now.removeCurrency(0, price)
    local meta = { description = desc, outfit = outfit, sex = sex, image = 'clothingset' }
    if not Srv.addItem(src, 'clothingset', 1, meta) then
        local c = Srv.char(src)
        if c and c.charIdentifier == char.charIdentifier then c.addCurrency(0, price) end
        Srv.giveBack(src, needs)
        return Srv.notify(src, L('cantCarry'), 5000)
    end
    Srv.notify(src, L('clothingCreated'), 4000)
end

RegisterNetEvent('pup_tailor:copy', function(sex, desc)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'make', 750) then return end
    Srv.exclusive(src, 'copy', copyOutfit, src, sex, desc)
end)

---------------------------------------------------------------------------
-- make from the mannequin
---------------------------------------------------------------------------

local function makeOutfit(src, keep, outfit, code, desc, sex, amount)
    local char = Srv.char(src)
    if not char then return end
    if not Srv.requireBench(src, char) then return end

    if not U.isMap(outfit) then return end
    if type(code) ~= 'string' or (code ~= 'clothingset2' and not Cat.itemCategory[code]) then return end
    if sex ~= 'male' and sex ~= 'female' then return end
    desc = U.cleanText(desc, DESC_MAX, true)
    if desc == '' then return end
    amount = U.int(amount)
    if not amount or amount < 1 then return end
    if amount > Config.MaxAmount then
        return Srv.notify(src, L('amountMax', Config.MaxAmount), 5000)
    end

    local priced = priceOutfit(outfit, sex)
    if not priced then return Srv.notify(src, L('invalidSelection'), 5000) end

    -- a category code is only for exactly one garment of that category
    if code ~= 'clothingset2' then
        local onlySlot = next(priced.outfit)
        if U.count(priced.outfit) ~= 1 or onlySlot ~= Cat.slotFor(code) then
            return Srv.notify(src, L('invalidSelection'), 5000)
        end
    end

    local totalCash = priced.cash * amount
    local needs = {}
    for _, m in ipairs(priced.materials) do
        needs[#needs + 1] = { name = m.name, label = m.label, count = m.count * amount }
    end

    if (tonumber(char.money) or 0) < totalCash then
        return Srv.notify(src, L('notEnoughMoney', totalCash), 5000)
    end
    local short = Srv.shortList(src, needs)
    if short then
        local msg = L('notEnoughMaterials') .. (amount > 1 and L('forAmount', amount) or '')
            .. ' - ' .. table.concat(short, ', ')
        return Srv.notify(src, msg, 6000)
    end

    local grant, metaSex
    if code == 'clothingset2' then
        grant, metaSex = 'clothingset', (sex == 'male' and 'm' or 'f')
    else
        grant, metaSex = code, sex
    end
    if not Srv.canCarry(src, grant, amount) then return Srv.notify(src, L('cantCarry'), 5000) end

    -- re-check right before taking anything
    local same, now = Srv.sameChar(src, char.charIdentifier)
    if not same or not Srv.validSource(src) then return end
    if (tonumber(now.money) or 0) < totalCash then
        return Srv.notify(src, L('notEnoughMoney', totalCash), 5000)
    end

    if not Srv.takeMaterials(src, needs) then
        return Srv.notify(src, L('notEnoughMaterials'), 5000)
    end
    local paid = false
    if totalCash > 0 then
        same, now = Srv.sameChar(src, char.charIdentifier)
        if not same or (tonumber(now.money) or 0) < totalCash then
            Srv.giveBack(src, needs)
            return Srv.notify(src, L('notEnoughMoney', totalCash), 5000)
        end
        now.removeCurrency(0, totalCash)
        paid = true
    end

    local meta = {
        description = desc,
        outfit = priced.outfit,
        sex = metaSex,
        set = keep == true,
        image = grant,
    }
    if not Srv.addItem(src, grant, amount, meta) then
        if paid then
            local c = Srv.char(src)
            if c and c.charIdentifier == char.charIdentifier then c.addCurrency(0, totalCash) end
        end
        Srv.giveBack(src, needs)
        return Srv.notify(src, L('cantCarry'), 5000)
    end
    Srv.notify(src, L('clothingCreated'), 4000)
end

RegisterNetEvent('pup_tailor:make', function(outfit, code, desc, sex, amount)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'make', 750) then return end
    Srv.exclusive(src, 'make', makeOutfit, src, false, outfit, code, desc, sex, amount)
end)

RegisterNetEvent('pup_tailor:makeKeep', function(outfit, code, desc, sex, amount)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'make', 750) then return end
    Srv.exclusive(src, 'make', makeOutfit, src, true, outfit, code, desc, sex, amount)
end)
