-- pup_tailor | wearing clothing items, and storing what the character now wears.
local U = Tailor.U
local Cat = Tailor.Cat
local Inv = Srv.Inv

local SAVE_MAX <const> = 16384

local WHOLE = { clothingset = true, pristine_clothingset = true }

local function onUse(data)
    local src = Srv.validSource(data and data.source)
    if not src then return end
    pcall(function() Inv:closeInventory(src) end)
    local item = data.item
    if type(item) ~= 'table' then return end
    local char = Srv.char(src)
    if not char then return end
    local meta = type(item.metadata) == 'table' and item.metadata or {}
    if type(meta.outfit) ~= 'table' then return end

    local outfit = U.copy(meta.outfit)
    -- some items carry their colours beside the outfit instead of inside it
    if type(outfit.colors) ~= 'table' and type(meta.colors) == 'table' then outfit.colors = U.copy(meta.colors) end
    local dyed = type(outfit.colors) == 'table' and next(outfit.colors) ~= nil

    TriggerClientEvent('pup_tailor:wear', src, {
        whole = WHOLE[item.name] == true,
        outfit = outfit,
        dyed = dyed,
        sex = Srv.itemSex(meta),
        worn = U.decodeMap(char.comps) or {},
        keep = meta.set == true,
    })
end

local usable = { 'clothingset', 'pristine_clothingset', 'clothingset2', 'pristine_clothingset2' }
for _, cat in ipairs(Config.ItemCategories) do
    usable[#usable + 1] = cat
    usable[#usable + 1] = 'pristine_' .. cat
end

CreateThread(function()
    for _, name in ipairs(usable) do
        Inv:registerUsableItem(name, function(data)
            Srv.safe('use ' .. name, onUse, data)
        end, GetCurrentResourceName())
    end
end)

-- the worn-clothing JSON the client built (vorp_character got it first)
RegisterNetEvent('pup_tailor:saveWorn', function(str)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'saveWorn', 1000) then return end
    if type(str) ~= 'string' or #str > SAVE_MAX or not U.decodeMap(str) then return end
    Srv.safe('saveWorn', function()
        local char = Srv.char(src)
        if char then char.updateComps(str) end
    end)
end)

-- tint update: merged slot by slot into the character's tint store
RegisterNetEvent('pup_tailor:saveTints', function(str)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'saveTints', 1000) then return end
    if type(str) ~= 'string' or #str > SAVE_MAX then return end
    local update = U.decodeMap(str)
    if not update then return end
    Srv.safe('saveTints', function()
        local char = Srv.char(src)
        if not char then return end
        local store = U.decodeMap(char.compTints) or {}
        local changed = false
        for slot, v in pairs(update) do
            if type(slot) == 'string' and type(v) == 'table' then
                store[slot] = v
                changed = true
            end
        end
        if changed then char.updateCompTints(json.encode(store)) end
    end)
end)

-- after a VORP clothing reload: the colours of what THIS character wears now
Srv.answer('wornColours', function(_, char)
    local worn = U.decodeMap(char.comps) or {}
    local out = {}
    if type(worn.colors) == 'table' then
        for slot, c in pairs(worn.colors) do
            if type(slot) == 'string' and type(c) == 'table' and U.isReal(worn[slot]) then
                out[slot] = {
                    palette = Cat.resolvePalette(c.palette),
                    color1 = tonumber(c.color1) or 0,
                    color2 = tonumber(c.color2) or 0,
                    color3 = tonumber(c.color3) or 0,
                }
            end
        end
    end
    return out
end)
