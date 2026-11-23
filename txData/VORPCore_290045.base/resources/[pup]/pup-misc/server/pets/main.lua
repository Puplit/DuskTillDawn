-- pup-misc / pets - server half

local out = {} -- source -> { [item] = netId (or true until the client reports one) }

-- COATS: `variant` is one fixed coat; `variants = { ... }` is a pool each character draws from once
-- and keeps (neither = coat 0). Only use indexes you have seen with /petscan.
local COAT_SQL = [[
CREATE TABLE IF NOT EXISTS `pet_coats` (
    `charid` INT NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `variant` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`charid`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local coats = {} -- charid -> { [item] = variant }

CreateThread(function()
    exports.oxmysql:execute(COAT_SQL, {})
end)

local function charIdOf(src)
    VorpCore = VorpCore or exports.vorp_core:GetCore()
    local user = VorpCore and VorpCore.getUser(src)
    local ch = user and user.getUsedCharacter
    if type(ch) ~= 'table' then return nil end
    return tonumber(ch.charIdentifier)
end

local function loadCoats(charid)
    if coats[charid] then return coats[charid] end
    local mine = {}
    local rows = exports.oxmysql:query_async('SELECT item, variant FROM pet_coats WHERE charid = ?', { charid })
    for _, r in ipairs(rows or {}) do mine[r.item] = tonumber(r.variant) end
    coats[charid] = mine
    return mine
end

-- the coat this character wears for this pet, drawing one the first time
local function coatFor(src, item, spec)
    if spec.variant ~= nil then return tonumber(spec.variant) or 0 end

    local pool = spec.variants
    if type(pool) ~= 'table' or #pool == 0 then return 0 end

    local charid = charIdOf(src)
    if not charid then return tonumber(pool[1]) or 0 end

    local mine = loadCoats(charid)
    local have = mine[item]
    -- a pool that shrank must not leave somebody on a coat it no longer offers
    if have then
        for _, v in ipairs(pool) do
            if tonumber(v) == have then return have end
        end
    end

    local picked = tonumber(pool[math.random(#pool)]) or 0
    mine[item] = picked
    exports.oxmysql:execute(
        'INSERT INTO pet_coats (charid, item, variant) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE variant = VALUES(variant)',
        { charid, item, picked })
    return picked
end

local function maxPets()
    return math.max(1, math.floor(tonumber(PetsConfig and PetsConfig.General.maxPets) or 1))
end

-- NAMING: the name and description live on the whistle item's metadata, which vorp shows
-- as the item's label and description, so the name travels with the whistle
local function namingCfg()
    return (PetsConfig and PetsConfig.Naming) or {}
end

-- the satchel inserts a label unencoded, so a name is whitelisted, not escaped
local function cleanPetName(s)
    s = tostring(s or ''):gsub('<[^>]*>', '')
    s = s:gsub("[^%w%s%-%.,!%?']", '')
    s = s:gsub('%s+', ' '):gsub("^%s+", ''):gsub("%s+$", '')
    s = s:gsub("'", '')
    local limit <const> = math.max(1, math.floor(tonumber(namingCfg().maxNameLength) or 24))
    if #s > limit then s = s:sub(1, limit) end
    return s
end

-- the description IS rendered as html, so it goes through vorp's own sanitiser
local function cleanPetDesc(s)
    local out = tostring(s or '')
    local ok, cleaned = pcall(function()
        return exports.vorp_inventory:SanitizeDescription(out)
    end)
    -- SanitizeDescription is only in the patched vorp_inventory; without it keep plain text only
    if ok and type(cleaned) == 'string' then out = cleaned else out = out:gsub('<[^>]*>', ''):gsub('[<>]', '') end
    local plain <const> = out:gsub('<[^>]*>', '')
    local limit <const> = math.max(1, math.floor(tonumber(namingCfg().maxDescLength) or 200))
    if #plain > limit then return nil end -- too long: refuse rather than cut markup in half
    return out
end

local function metaOf(item)
    local meta = item and item.metadata
    if type(meta) == 'string' then
        local ok, decoded = pcall(json.decode, meta)
        meta = ok and decoded or nil
    end
    return type(meta) == 'table' and meta or {}
end

-- every pet whistle in this player's satchel, each as its own stack. `namedAt`
-- is the unix time of the last naming, so the caller can hold a cooldown over it.
local function petItemsOf(src)
    local list = {}
    local items = exports.vorp_inventory:getUserInventoryItems(src)
    if type(items) ~= 'table' then return list end
    for _, it in ipairs(items) do
        local spec = ((PetsConfig or {}).Pets or {})[it.name]
        if spec then
            local meta <const> = metaOf(it)
            list[#list + 1] = {
                id      = tonumber(it.id),
                item    = it.name,
                breed   = spec.label or it.name,
                name    = meta.petName or '',
                desc    = meta.petDesc or '',
                namedAt = tonumber(meta.petNamedAt) or 0,
            }
        end
    end
    return list
end

-- the price and the cooldown are the CALLER'S business (pup_staffdesk owns both);
-- everything here is just "is this a pet of theirs, and write it safely"
exports('PetWhistles', petItemsOf)

exports('PetWhistleById', function(src, itemId)
    itemId = tonumber(itemId)
    for _, row in ipairs(petItemsOf(src)) do
        if row.id == itemId then return row end
    end
    return nil
end)

-- returns ok, errorMessage
exports('SetPetName', function(src, itemId, name, desc)
    if namingCfg().enabled == false then return false, PetsLocale.namingOff end
    itemId = tonumber(itemId)
    if not src or not itemId then return false, PetsLocale.nothingToName end

    local item <const> = exports.vorp_inventory:getItemById(src, itemId)
    if not item or not ((PetsConfig or {}).Pets or {})[item.name] then
        return false, PetsLocale.notYourPet
    end

    local cleanName <const> = cleanPetName(name)
    if cleanName == '' then return false, PetsLocale.nameFirst end

    local cleanDesc = cleanPetDesc(desc)
    if cleanDesc == nil then
        return false, (PetsLocale.descTooLong):format(namingCfg().maxDescLength or 200)
    end

    local meta = metaOf(item)
    -- a cleared field is written as '' - nil would be dropped by the metadata merge
    meta.petName    = cleanName
    meta.petDesc    = cleanDesc
    meta.petNamedAt = os.time()
    meta.description = cleanDesc
    if namingCfg().renameItem ~= false then
        meta.label = cleanName
    end

    exports.vorp_inventory:setItemMetadata(src, itemId, meta, item.count or 1)

    if PetsConfig and PetsConfig.General.debug then
        print(('^2[pup-misc:pets]^7 %s named %s "%s"'):format(tostring(src), item.name, cleanName))
    end
    return true, cleanName
end)

local function countOut(src)
    local n = 0
    for _ in pairs(out[src] or {}) do n = n + 1 end
    return n
end

-- the pet ped is networked, so it outlives the player who spawned it; the server can remove it by network id
local function deleteByNet(netId)
    netId = tonumber(netId)
    if not netId or netId == 0 then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
end

local function deleteAll(src)
    for _, netId in pairs(out[src] or {}) do
        if type(netId) == 'number' then deleteByNet(netId) end
    end
    out[src] = nil
end

-- Only the pet this player really spawned gets deleted by net id later: a ped they own, of that whistle's model.
local function isTheirPet(src, item, ent)
    if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return false end
    if NetworkGetEntityOwner(ent) ~= src then return false end
    local def = ((PetsConfig or {}).Pets or {})[item]
    if not def or not def.model then return false end
    -- hashes come back signed or unsigned depending on the native
    local function unsigned(h)
        h = tonumber(h) or 0
        return h < 0 and h + 4294967296 or h
    end
    return unsigned(GetEntityModel(ent)) == unsigned(GetHashKey(def.model))
end

RegisterNetEvent('pup-misc:pets:spawned', function(item, netId)
    local src = source
    netId = tonumber(netId)
    if not netId or type(item) ~= 'string' then return end
    if not (out[src] and out[src][item]) then return end
    -- the ped can take a moment to reach the server. If it never checks out, nothing is deleted by net id.
    CreateThread(function()
        for _ = 1, 10 do
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                if isTheirPet(src, item, ent) and out[src] and out[src][item] then out[src][item] = netId end
                return
            end
            Wait(200)
        end
    end)
end)

RegisterNetEvent('pup-misc:pets:cleared', function(item)
    -- the client's pet is gone (died, streamed out, resource restarted)
    local src = source
    if type(item) == 'string' and out[src] then out[src][item] = nil end
end)

-- THE ITEM IS THE LEASH: after any removal settles the count is re-read and the pet is put away
-- when none is left (given, dropped, stashed, boxed, wiped); part of a stack keeps it out
local function stillHas(src, item)
    local n = 0
    pcall(function() n = tonumber(exports.vorp_inventory:getItemCount(src, nil, item)) or 0 end)
    return n > 0
end

local function checkLeash(src, item)
    if not (out[src] and out[src][item]) then return end
    if stillHas(src, item) then return end

    local netId = out[src][item]
    out[src][item] = nil
    -- delete the ped server-side as well as telling the client: the ped is
    -- networked, so a client that has already streamed away would leave it
    if type(netId) == 'number' then deleteByNet(netId) end
    -- the client's own despawn handler tips the player; do not send a second one
    TriggerClientEvent('pup-misc:pets:despawn', src, item)
    if PetsConfig and PetsConfig.General.debug then
        print(('^3[pup-misc:pets]^7 %s lost the item for %s - pet put away'):format(tostring(src), item))
    end
end

local function isPetItem(name)
    return name ~= nil and ((PetsConfig or {}).Pets or {})[name] ~= nil
end

-- the count is only reliable after the removal lands: OnItemRemoved fires before the give path debits
local function leashLater(src, item)
    if not src or not isPetItem(item) then return end
    SetTimeout(400, function() checkLeash(src, item) end)
end

AddEventHandler('vorp_inventory:Server:OnItemRemoved', function(data, src)
    if type(data) ~= 'table' then return end
    leashLater(src, data.name)
end)

-- into a stash, a hideout or one of the portable storage boxes
AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(data, _, src)
    if type(data) ~= 'table' then return end
    leashLater(src, data.name)
end)

-- gone without putting them away: nothing may stay standing in the world
AddEventHandler('playerDropped', function()
    deleteAll(source)
end)

-- a new character must not inherit the old one's summoned pets
AddEventHandler('vorp:SelectedCharacter', function(src)
    if not src then return end
    deleteAll(src)
    -- warm the coats now so whistling a pet never waits on the database
    CreateThread(function()
        local charid = charIdOf(src)
        if charid then loadCoats(charid) end
    end)
end)

CreateThread(function()
    while GetResourceState('vorp_inventory') ~= 'started' do Wait(100) end

    for item, spec in pairs((PetsConfig or {}).Pets or {}) do
        exports.vorp_inventory:registerUsableItem(item, function(data)
            local src <const> = data.source
            if PetsConfig.General.debug then
                print(('^2[pup-misc:pets]^7 USE %s by %s'):format(item, tostring(src)))
            end
            -- closeInventory is a CLIENT export; from here it has to be the event
            TriggerClientEvent('vorp_inventory:CloseInv', src)

            out[src] = out[src] or {}

            -- toggle: the same whistle again puts THAT pet away, the others stay out
            if out[src][item] then
                out[src][item] = nil
                TriggerClientEvent('pup-misc:pets:despawn', src, item)
                return
            end

            local limit <const> = maxPets()
            if countOut(src) >= limit then
                TriggerClientEvent('vorp:TipRight', src,
                    limit == 1 and PetsLocale.alreadyOut or (PetsLocale.tooManyOut):format(limit), 4000)
                return
            end

            out[src][item] = true

            if PetsConfig.General.consumeItem then
                exports.vorp_inventory:subItem(src, item, 1)
            end

            -- Several pet models are on vorp_admin's spawn guard list (boar, cow, pig,
            -- snake, mangy lion) and the ped is created by the client, so it reads as a
            -- cheat spawn. Open a short window now the use has been validated here.
            pcall(function()
                exports.vorp_admin:SpawnGuardAllow(src, spec.model, 15000)
            end)

            -- the name is read from the WHISTLE THAT WAS USED, so two of the same
            -- breed answer to their own names
            local petName <const> = metaOf(data.item).petName

            -- the SPEC comes from the server's own config, never from the client
            TriggerClientEvent('pup-misc:pets:spawn', src, {
                label   = spec.label,
                name    = (type(petName) == 'string' and petName ~= '') and petName or nil,
                model   = spec.model,
                variant = coatFor(src, item, spec),
                scale   = spec.scale,
            }, item)
        end)
    end

    if PetsConfig and PetsConfig.General.debug then
        local n = 0
        for _ in pairs(PetsConfig.Pets or {}) do n = n + 1 end
        print(('^2[pup-misc:pets]^7 registered %d pet item(s), %d out at once'):format(n, maxPets()))
    end
end)

-- Rarity is NOT handled here. items.rarityId is set once by sql/pets/install.sql and owned by the database from then on
