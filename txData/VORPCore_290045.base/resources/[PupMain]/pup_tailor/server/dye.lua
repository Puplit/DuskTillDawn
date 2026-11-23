-- pup_tailor | the dye book's server side: list items, read one item, dye it.
local U = Tailor.U
local Cat = Tailor.Cat
local Inv = Srv.Inv

local function inventory(src)
    local ok, items = pcall(function() return Inv:getUserInventoryItems(src) end)
    if not ok or type(items) ~= 'table' then return {} end
    return items
end

local function findItem(src, id)
    for _, it in ipairs(inventory(src)) do
        if U.int(it.id) == id then return it end
    end
    return nil
end

local function outfitOf(item)
    local meta = type(item.metadata) == 'table' and item.metadata or nil
    if meta and type(meta.outfit) == 'table' then return meta.outfit, meta end
    return nil, meta
end

local function isDyed(item)
    if type(item.name) == 'string' and item.name:sub(1, 9) == 'pristine_' then return true end
    local outfit, meta = outfitOf(item)
    if outfit and type(outfit.colors) == 'table' and next(outfit.colors) then return true end
    if meta and type(meta.colors) == 'table' and next(meta.colors) then return true end
    return false
end
Srv.isDyedItem = isDyed

local function sexOf(meta)
    local s = meta and meta.sex
    return (s == 'f' or s == 'female') and 'female' or 'male'
end
Srv.itemSex = sexOf

local function itemList(src)
    local list = {}
    for _, it in ipairs(inventory(src)) do
        local outfit, meta = outfitOf(it)
        if outfit then
            list[#list + 1] = {
                id = U.int(it.id),
                label = (meta and type(meta.label) == 'string' and meta.label) or it.label or it.name,
                description = meta and type(meta.description) == 'string' and meta.description or '',
            }
        end
    end
    table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return list
end

Srv.answer('dyeItems', function(src)
    return itemList(src)
end)

Srv.answer('dyeItem', function(src, _, id)
    id = U.int(id)
    if not id then return nil end
    local it = findItem(src, id)
    local outfit, meta
    if it then outfit, meta = outfitOf(it) end
    if not it or not outfit then return { id = id } end
    return { id = id, name = it.name, outfit = outfit, sex = sexOf(meta), dyed = isDyed(it) }
end)

---------------------------------------------------------------------------
-- save
---------------------------------------------------------------------------
local function refuse(src, msg)
    TriggerClientEvent('pup_tailor:dyeResult', src, false, msg)
end

-- keep only valid entries for slots that may be dyed on this item
local function cleanColours(colours, outfit, itemName)
    local allowed = Cat.dyeableSlots(outfit, itemName)
    local out, n = {}, 0
    for slot, c in pairs(colours) do
        if type(slot) == 'string' and allowed[slot] and type(c) == 'table' then
            local pal = U.int(c.palette)
            local okPal
            if pal and pal >= 0 and pal <= 25 then
                okPal = pal
            else
                local u = U.unsigned(c.palette)
                if u and Cat.paletteSet[u] then okPal = u end
            end
            local function ch(v)
                v = tonumber(v)
                if not v or v ~= v or v < 0 or v > 255 then return nil end
                return math.floor(v)
            end
            local c1, c2, c3 = ch(c.color1), ch(c.color2), ch(c.color3)
            if okPal and c1 and c2 and c3 then
                out[slot] = { palette = okPal, color1 = c1, color2 = c2, color3 = c3 }
                n = n + 1
            end
        end
    end
    return out, n
end

local function dyeSave(src, id, colours)
    local char = Srv.char(src)
    if not char then return end
    local okBench, why = Srv.requireBench(src, char)
    if not okBench then return refuse(src, why or L('onlyTailorDye')) end
    if type(colours) ~= 'table' then return end
    id = U.int(id)
    if not id then return end

    local item = findItem(src, id)
    local outfit, meta
    if item then outfit, meta = outfitOf(item) end
    if not item or not outfit then return end
    if isDyed(item) then return refuse(src, L('alreadyDyed')) end

    local clean, n = cleanColours(colours, outfit, item.name)
    if n == 0 then return refuse(src, L('nothingDyed')) end

    local newMeta = U.copy(meta)
    newMeta.outfit = U.copy(outfit)
    newMeta.outfit.colors = clean

    local variant = 'pristine_' .. item.name
    if not Srv.itemExists(variant) then variant = nil end

    local needs = Cat.dyeCost(n)
    for _, m in ipairs(needs) do
        local have = Srv.itemCount(src, m.name)
        if have < m.count then
            return refuse(src, L('shortMaterials', ('%s %d/%d'):format(m.label, have, m.count)))
        end
    end
    if variant and not Srv.canCarry(src, variant, 1) then return refuse(src, L('cantCarryDye')) end

    -- still the same character, and the item is still there and still undyed
    if not Srv.sameChar(src, char.charIdentifier) then return end
    item = findItem(src, id)
    if not item or isDyed(item) then return end

    if not Srv.takeMaterials(src, needs) then
        return refuse(src, L('shortMaterialsPlain'))
    end

    local done = false
    if variant then
        local ok, res = pcall(function() return Inv:subItemById(src, id, nil, nil, 1) end)
        if ok and res == true then
            if Srv.addItem(src, variant, 1, newMeta) then
                done = true
            else
                Srv.addItem(src, item.name, 1, meta)
            end
        end
    else
        local ok, res = pcall(function() return Inv:setItemMetadata(src, id, newMeta, 1) end)
        done = ok and res ~= false
    end

    if not done then
        Srv.giveBack(src, needs)
        return refuse(src, L('cantCarryDye'))
    end
    TriggerClientEvent('pup_tailor:dyeResult', src, true, L('dyed', n), itemList(src))
end

RegisterNetEvent('pup_tailor:dyeSave', function(id, colours)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'dyeSave', 1000) then return end
    if Srv.isBusy(src) then return end
    Srv.exclusive(src, 'dyeSave', dyeSave, src, id, colours)
end)
