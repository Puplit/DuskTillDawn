-- pup-stable | staff exports (vorp_admin owns the menu and the permission gate) and the
-- inventory description vorp_inventory asks for in its logs

local Inv = exports.vorp_inventory

local function ownerText(identifier, charid) return ('%s [%s]'):format(tostring(identifier), tostring(charid)) end

exports('GetPlayerStableAssets', function(charid)
    charid = U.int(charid)
    local out = { horses = {}, wagons = {} }
    if not charid then return out end
    for _, h in ipairs(HorsesOf(charid)) do
        out.horses[#out.horses + 1] = {
            id = h.id, name = h.name, model = h.model, charid = h.charid, identifier = h.identifier,
            speed = h.speed, acceleration = h.acceleration, handling = h.handling,
            bonding = h.st.bonding, health = h.st.health, stamina = h.st.stamina, isFemale = h.isFemale, distance = h.st.distance,
        }
    end
    for _, w in ipairs(WagonsOf(charid)) do
        out.wagons[#out.wagons + 1] = { id = w.id, name = WagonLabel(w), model = w.model, charid = w.charid, identifier = w.identifier }
    end
    return out
end)

exports('AdminTransferHorse', function(horseId, targetServerId)
    local h = Horses[U.int(horseId, -1)]
    if not h then return false, 'no such horse' end
    local t = Ctx(targetServerId)
    if not t then return false, 'target player is not loaded' end
    local from = ownerText(h.identifier, h.charid)
    local queries = { { query = 'UPDATE stable_horses SET identifier = ?, charid = ?, favourite = 0, isOut = 0 WHERE id = ?', values = { t.identifier, t.charid, h.id } } }
    local moved = {}
    if Config.AdminMovesTack then
        local bag = HorseCompOf(h, 'horse_saddlebags')
        queries[#queries + 1] = { query = 'UPDATE stable_bought SET identifier = ?, charid = ? WHERE equiped_on = ?', values = { t.identifier, t.charid, h.id } }
        if bag then queries[#queries + 1] = { query = 'UPDATE character_inventories SET character_id = ? WHERE inventory_type = ?', values = { t.charid, BagInvName(bag.id) } } end
        moved = HorseComps(h)
    else
        -- when Config.AdminMovesTack is off, tack and saddlebag contents stay with the old character
        queries[#queries + 1] = { query = 'UPDATE stable_bought SET equiped_on = 0 WHERE equiped_on = ? AND category NOT IN (?)', values = { h.id, { 'horse_heads', 'horse_bodies', 'horse_manes', 'horse_tails', 'horse_mustache', 'horse_shoes', 'palettesForHorseCoat' } } }
        queries[#queries + 1] = { query = 'UPDATE stable_bought SET identifier = ?, charid = ? WHERE equiped_on = ?', values = { t.identifier, t.charid, h.id } }
    end
    local ok, res = pcall(MySQL.transaction.await, queries)
    if not ok or not res or not Horses[h.id] then return false, 'database write failed' end
    UnlinkHorse(h.id, true)
    local look = {}
    for _, c in ipairs(HorseComps(h)) do
        if U.UNIQUE[c.category] then look[#look + 1] = c elseif not Config.AdminMovesTack then c.on = 0 end
    end
    for _, c in ipairs(Config.AdminMovesTack and moved or look) do
        DropComp(c)
        c.identifier, c.charid = t.identifier, t.charid
        AddComp(c)
    end
    DropHorse(h)
    h.identifier, h.charid, h.favourite, h.isOut = t.identifier, t.charid, false, false
    AddHorse(h)
    Notify(t.src, L('adminTransferred', h.name))
    TriggerClientEvent('pup-stable:listChanged', t.src)
    return true, h.name, from
end)

exports('AdminTransferWagon', function(wagonId, targetServerId)
    local w = Wagons[U.int(wagonId, -1)]
    if not w then return false, 'no such wagon' end
    local t = Ctx(targetServerId)
    if not t then return false, 'target player is not loaded' end
    local from = ownerText(w.identifier, w.charid)
    local queries = { { query = 'UPDATE stable_wagons SET identifier = ?, charid = ?, isOut = 0 WHERE id = ?', values = { t.identifier, t.charid, w.id } } }
    if Config.AdminMovesTack then
        queries[#queries + 1] = { query = 'UPDATE character_inventories SET character_id = ? WHERE inventory_type = ?', values = { t.charid, LockerInvName(w.id) } }
    end
    local ok, res = pcall(MySQL.transaction.await, queries)
    if not ok or not res or not Wagons[w.id] then return false, 'database write failed' end
    UnlinkWagon(w.id, true)
    DropWagon(w)
    w.identifier, w.charid, w.isOut = t.identifier, t.charid, false
    AddWagon(w)
    Notify(t.src, L('adminTransferred', WagonLabel(w)))
    TriggerClientEvent('pup-stable:listChanged', t.src, 'wagons')
    return true, WagonLabel(w), from
end)

-- a new horse for an online character (vorp_admin's give horse); the model must be a known coat
exports('AdminGiveHorse', function(targetServerId, model, name, isFemale)
    local t = Ctx(targetServerId)
    if not t then return false, 'target player is not loaded' end
    local _, coat = BreedOfModel(model)
    if not coat then return false, 'unknown horse model' end
    name = U.cleanName(name, Config.General.nameMax)
    if not name then return false, L('invalidName') end
    local st = Config.Starter
    local stable = StableById(st.stable) and st.stable or next(Config.Stables)
    if not stable then return false, 'no stable configured' end
    local ok, h = pcall(CreateHorse, {
        identifier = t.identifier, charid = t.charid, stable = stable, model = coat.model, isFemale = isFemale == true, name = name,
        speed = st.speed, acceleration = st.acceleration, handling = st.handling, favourite = FavouriteOf(t.charid) == nil,
    })
    if not ok or not h then return false, 'database write failed' end
    TriggerClientEvent('pup-stable:listChanged', t.src)
    return true, h.name
end)

exports('AdminFullyTrainHorse', function(horseId)
    local h = Horses[U.int(horseId, -1)]
    if not h then return false, 'no such horse' end
    local c = Config.Training.ceilings
    h.speed, h.acceleration, h.handling = c.speed, c.acceleration, c.handling
    h.st.bonding, h.st.health, h.st.stamina = 9500, 1000, 1000
    local top = Config.Training.levels[#Config.Training.levels]
    if h.st.xp < top then h.st.xp = top end
    SaveHorse(h, 'speed', 'acceleration', 'handling')
    SaveStats(h)
    PublishStats(h)
    return true, h.name
end)

exports('AdminResetHorseColor', function(horseId)
    local h = Horses[U.int(horseId, -1)]
    if not h then return false, 'no such horse' end
    local ids = {}
    for _, c in ipairs(HorseComps(h)) do
        if c.color then ids[#ids + 1] = c.id; c.color = nil end
    end
    if #ids > 0 then
        local ok = pcall(MySQL.update.await, 'DELETE FROM stable_color WHERE id IN (?)', { ids })
        if not ok then return false, 'database write failed' end
    end
    local ent = HorseEnt[h.id]
    if ent and DoesEntityExist(ent) and SpawnedBy[h.id] then
        TriggerClientEvent('pup-stable:redress', SpawnedBy[h.id], NetworkGetNetworkIdFromEntity(ent), HorsePayload(h))
    end
    return true, h.name
end)

exports('AdminOpenStorage', function(kind, assetId, staffServerId)
    local src = U.int(staffServerId)
    if not src or not Ctx(src) then return false, 'staff member is not loaded' end
    if kind == 'horse' then
        local h = Horses[U.int(assetId, -1)]
        if not h then return false, 'no such horse' end
        local bag = HorseCompOf(h, 'horse_saddlebags')
        if not bag then
            local row = MySQL.single.await('SELECT id FROM stable_bought WHERE equiped_on = ? AND category = ? LIMIT 1', { h.id, 'horse_saddlebags' })
            if row then bag = { id = U.int(row.id) } end
        end
        if not bag then return false, L('noSaddlebagFitted', h.name) end
        if not OpenBag(src, h, bag.id, true) then return false, 'could not open the saddlebag' end
        return true, h.name
    elseif kind == 'wagon' then
        local w = Wagons[U.int(assetId, -1)]
        if not w then return false, 'no such wagon' end
        if not OpenLocker(src, w, true) then return false, 'could not open the locker' end
        return true, WagonLabel(w)
    end
    return false, 'unknown kind'
end)

exports('AdminDeleteHorse', function(horseId, staffServerId)
    local h = Horses[U.int(horseId, -1)]
    if not h then return false, 'no such horse' end
    local name = h.name
    local bag = HorseCompOf(h, 'horse_saddlebags')
    if bag then CloseStaffViews(BagInvName(bag.id)) end
    UnlinkHorse(h.id, true)
    CreateThread(function()
        local ok = pcall(DeleteHorseRow, h)
        if ok and staffServerId then Notify(staffServerId, L('adminDeleted', name)) end
    end)
    return true, name
end)

exports('AdminDeleteWagon', function(wagonId, staffServerId)
    local w = Wagons[U.int(wagonId, -1)]
    if not w then return false, 'no such wagon' end
    local name = WagonLabel(w)
    CloseStaffViews(LockerInvName(w.id))
    UnlinkWagon(w.id, true)
    CreateThread(function()
        local ok = pcall(DeleteWagonRow, w)
        if ok and staffServerId then Notify(staffServerId, L('adminDeleted', name)) end
    end)
    return true, name
end)

-- "Horse 'Name' (model #id) owned by First Last [charid n]"
local nameCache = {}
local function charName(charid)
    if nameCache[charid] then return nameCache[charid] end
    local ok, row = pcall(MySQL.single.await, 'SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    local n = (ok and row) and U.trim(('%s %s'):format(row.firstname or '', row.lastname or '')) or '?'
    nameCache[charid] = n
    return n
end

exports('DescribeStableInventory', function(inventoryName)
    if type(inventoryName) ~= 'string' then return nil end
    local bagId = inventoryName:match('^saddlebagID_(%d+)$')
    if bagId then
        -- resolve through the component, whether or not the bag was opened since a restart
        local c = Comps[U.int(bagId)]
        local h = c and c.on and c.on > 0 and Horses[c.on]
        if not h and c then
            for _, hh in ipairs(HorsesOf(c.charid)) do if HorseCompOf(hh, 'horse_saddlebags') == c then h = hh break end end
        end
        if not h then
            if c then return ("Saddlebag #%d owned by %s [charid %d]"):format(c.id, charName(c.charid), c.charid) end
            return nil
        end
        return ("Horse '%s' (%s #%d) owned by %s [charid %d]"):format(h.name, h.model, h.id, charName(h.charid), h.charid)
    end
    local wId = inventoryName:match('^wagonID_(%d+)$')
    if wId then
        local w = Wagons[U.int(wId)]
        if not w then return nil end
        return ("Wagon '%s' (%s #%d) owned by %s [charid %d]"):format(WagonLabel(w), w.model, w.id, charName(w.charid), w.charid)
    end
    return nil
end)

-- close every open view of a container that is about to disappear
function CloseStaffViews(invName)
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ok, open = pcall(function() return Inv:getOpenCustomInventory(src) end)
        if ok and open == invName then pcall(function() Inv:closeInventory(src, invName) end) end
    end
end
