-- storagebox | server: opening, carrying, hideouts, putting down and picking up, and what happens
-- when a box leaves a satchel. Start-up, stop, drop and character select are at the bottom.

local S = PupSBX
local C = StorageBoxConfig
local L = StorageBoxLocale

S.Placed   = {}  -- boxId -> { boxId, x, y, z, h, name, label, model } while standing in the world
S.sessions = {}  -- src -> box id this module opened for them
S.carriers = {}  -- src -> true while the server has them carrying

local hideoutSent = {}  -- src -> last in-hideout state sent
local pendingOpen = {}  -- src -> { boxId, token, expires }
local pendingGive = {}  -- giver src -> { to, title, at }

local function boxText(d, boxId)
    return ('%s (%s)'):format(d and d.label or '?', tostring(boxId))
end

------------------------------------------------------------------------------ hideouts
function S.inHideout(src)
    return (tonumber(GetPlayerRoutingBucket(src)) or 0) >= C.HideoutBucketFrom
end

-- only carriers are polled: the state only changes anything while a box is in someone's arms
CreateThread(function()
    while true do
        Wait(C.HideoutPollMs)
        for src in pairs(S.carriers) do
            if GetPlayerName(src) then
                local inside = S.inHideout(src)
                if hideoutSent[src] ~= inside then
                    hideoutSent[src] = inside
                    TriggerClientEvent('pup-misc:storagebox:hideout', src, inside)
                end
            else
                S.carriers[src] = nil
                hideoutSent[src] = nil
            end
        end
    end
end)

------------------------------------------------------------------------------ carrying
-- the loaded box shown in the hands (lowest move rate); nil when no loaded box counts
function S.carriedBox(src)
    local best, n = nil, 0
    for _, c in ipairs(S.containers(src)) do
        if c.boxId and c.def.kind == 'box' and S.units(c.boxId) > 0 then
            n = n + 1
            if not best or c.def.moveRate < best.def.moveRate then best = c end
        end
    end
    return best, n
end

function S.sendCarry(src)
    if not S.char(src) then return end
    local best, n = S.carriedBox(src)
    if not best then
        S.carriers[src] = nil
        hideoutSent[src] = nil
        TriggerClientEvent('pup-misc:storagebox:carry', src, false)
        return
    end
    local inside = S.inHideout(src)
    S.carriers[src] = true
    hideoutSent[src] = inside
    TriggerClientEvent('pup-misc:storagebox:carry', src, {
        rate = best.def.moveRate * (C.Carry.extraBoxFactor ^ (n - 1)),
        model = best.def.model,
        count = n,
        hideout = inside,
    })
end

------------------------------------------------------------------------------ placed boxes
local function placedEntry(row)
    local d = S.def(row.item_name)
    return {
        boxId = row.box_id,
        x = tonumber(row.pos_x) or 0.0, y = tonumber(row.pos_y) or 0.0, z = tonumber(row.pos_z) or 0.0,
        h = tonumber(row.pos_h) or 0.0,
        name = row.item_name,
        label = d and d.label or L.promptGroup,
        model = d and d.model or C.Carry.defaultModel,
    }
end

function S.placedList()
    local out = {}
    for _, e in pairs(S.Placed) do out[#out + 1] = e end
    return out
end

function S.loadPlaced()
    S.Placed = {}
    local rows = S.query('SELECT box_id, pos_x, pos_y, pos_z, pos_h, item_name FROM storage_boxes WHERE placed = 1 AND pos_x IS NOT NULL')
    for _, r in ipairs(rows) do S.Placed[r.box_id] = placedEntry(r) end
end

------------------------------------------------------------------------------ opening a box or pack
-- closes whatever custom inventory the player has open (vorp refuses to open a second)
function S.closeOpen(src)
    local open = S.openInv(src)
    if open then S.inv('closeInventory', src, open) end
    S.sessions[src] = nil
end

function S.beginOpen(src, boxId)
    S.closeOpen(src)
    local token = math.random(1, 1073741824)
    pendingOpen[src] = { boxId = boxId, token = token, expires = GetGameTimer() + 10000 }
    TriggerClientEvent('pup-misc:storagebox:confirmOpen', src, token)
end

RegisterNetEvent('pup-misc:storagebox:openConfirmed', function(token)
    local src = source
    local ch = S.netGate(src, 'openConfirmed', 200)
    if not ch then return end
    local p = pendingOpen[src]
    pendingOpen[src] = nil
    if not p or p.token ~= tonumber(token) or GetGameTimer() > p.expires then return end
    local c = S.findStamped(src, p.boxId)
    if not c or not S.jobAllowed(ch, c.def) then return end
    Wait(C.OpenDelayMs)
    -- the satchel or the job may have changed during the pause
    ch = S.char(src)
    c = ch and S.findStamped(src, p.boxId)
    if not c then return end
    if not S.jobAllowed(ch, c.def) then return S.tip(src, L.wrongJob) end
    if not S.ensure(p.boxId, c.item.name) then return S.tip(src, L.notFound) end
    S.closeOpen(src)
    S.sessions[src] = p.boxId
    S.inv('openInventory', src, p.boxId)
end)

local function onUse(data)
    local src = tonumber(type(data) == 'table' and data.source)
    local used = type(data) == 'table' and data.item or nil
    if not src or type(used) ~= 'table' then return end
    local ch = S.char(src)
    if not ch or not S.throttle(src, 'use', 750) then return end
    -- only the server's copy of the item counts
    local c = S.containerById(src, used.id)
    if not c then return end
    local d = c.def
    if not S.jobAllowed(ch, d) then return S.tip(src, L.wrongJob) end
    local boxId = c.boxId
    if not boxId then
        if S.hasStampedOfName(src, c.item.name) then return S.tip(src, L.alreadyHave:format(d.label)) end
        boxId = S.createBox(c.item.name)
        if not boxId then return S.tip(src, L.initFailed) end
        if not S.stamp(src, c.item.id, boxId) then
            S.dropFresh(boxId)
            return S.tip(src, L.initFailed)
        end
        S.log('Box Created', S.Colour.created, src, { { 'Box', boxText(d, boxId) } })
    else
        -- a stamp whose row was retired (an empty box that went into storage, or was dropped)
        if not S.getRow(boxId) then
            S.insert('INSERT IGNORE INTO storage_boxes (box_id, capacity, item_name) VALUES (?, ?, ?)', { boxId, d.capacity, c.item.name })
        end
        if not S.ensure(boxId, c.item.name) then return S.tip(src, L.notFound) end
    end
    S.beginOpen(src, boxId)
end

------------------------------------------------------------------------------ putting a box down
RegisterNetEvent('pup-misc:storagebox:place', function(x, y, z, h)
    local src = source
    local ch = S.netGate(src, 'place', C.PlaceThrottleMs)
    if not ch then return end
    if S.inHideout(src) then return end
    x, y, z, h = S.finite(x), S.finite(y), S.finite(z), S.finite(h)
    if not x or not y or not z or not h then return end
    local pos = S.pedPos(src)
    if not pos or S.dist(pos, x, y, z) > C.ServerReach then return end
    local c = S.carriedBox(src)
    if not c then return end
    local boxId, name = c.boxId, c.item.name
    -- a second put-down of the same box while the first still waits on the DB would roll the first back
    if not S.lock('place:' .. boxId, 15000) then return end
    local ok0, err = pcall(S.placeBox, src, c, boxId, name, x, y, z, h % 360.0)
    S.unlock('place:' .. boxId)
    if not ok0 then print(('^1[%s:storagebox]^7 put-down failed: %s'):format(S.RES, tostring(err))) end
end)

function S.placeBox(src, c, boxId, name, x, y, z, h)
    S.flag(S.placing, boxId, C.PlacingFlagMs)
    local _, ok = S.insert([[
        INSERT INTO storage_boxes (box_id, capacity, placed, pos_x, pos_y, pos_z, pos_h, item_name)
        VALUES (?, ?, 1, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE placed = 1, pos_x = VALUES(pos_x), pos_y = VALUES(pos_y), pos_z = VALUES(pos_z),
            pos_h = VALUES(pos_h), item_name = VALUES(item_name)
    ]], { boxId, c.def.capacity, x, y, z, h, name })
    if not ok then return S.unflag(S.placing, boxId) end
    -- the satchel may have changed while the row was written
    local still = S.findStamped(src, boxId)
    local removed = still and S.inv('subItemById', src, still.item.id, nil, true, 1) == true
    if not removed then
        S.update('UPDATE storage_boxes SET placed = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL WHERE box_id = ?', { boxId })
        S.unflag(S.placing, boxId)
        return
    end
    S.closeBoxFor(src, boxId)
    local entry = placedEntry({ box_id = boxId, pos_x = x, pos_y = y, pos_z = z, pos_h = h, item_name = name })
    S.Placed[boxId] = entry
    TriggerClientEvent('pup-misc:storagebox:placedAdd', -1, entry)
    S.refreshCarry(src, 0)
    S.tip(src, L.placed)
    S.log('Box Placed on Ground', S.Colour.placed, src, {
        { 'Box', boxText(c.def, boxId) },
        { 'Position', ('%.2f, %.2f, %.2f  (heading %.1f)'):format(x, y, z, h) },
        { 'Contents', S.contentsText(S.contents(boxId)) },
    })
end

------------------------------------------------------------------------------ a placed box: open and pick up
-- a refused open / pick-up says why on the server console (and tells the player), never silently
local function refuse(src, boxId, why)
    print(('^3[%s:storagebox]^7 placed box %s refused for %s: %s'):format(S.RES, tostring(boxId), tostring(src), why))
    S.tip(src, L.notFound)
    return nil
end

local function placedRowNear(src, boxId)
    if not S.isBoxId(boxId) then return refuse(src, boxId, 'bad box id (' .. type(boxId) .. ')') end
    local row = S.getRow(boxId)
    if not row then return refuse(src, boxId, 'no database row') end
    -- oxmysql hands a TINYINT(1) back as a boolean (true/false), not 1/0
    if not (row.placed == true or tonumber(row.placed) == 1) then
        return refuse(src, boxId, 'row not marked placed (placed=' .. tostring(row.placed) .. ')')
    end
    if not S.def(row.item_name) then return refuse(src, boxId, 'unknown box type ' .. tostring(row.item_name)) end
    local px, py, pz = tonumber(row.pos_x), tonumber(row.pos_y), tonumber(row.pos_z)
    local pos = S.pedPos(src)
    if not px or not py or not pz then return refuse(src, boxId, 'row has no position') end
    if not pos then return refuse(src, boxId, 'no server position for the player') end
    local d = S.dist(pos, px, py, pz)
    if d > C.ServerReach then
        return refuse(src, boxId, ('too far: %.1f m (reach %.1f) player %.1f,%.1f,%.1f box %.1f,%.1f,%.1f')
            :format(d, C.ServerReach, pos.x, pos.y, pos.z, px, py, pz))
    end
    return row
end

RegisterNetEvent('pup-misc:storagebox:openPlaced', function(boxId)
    local src = source
    if not S.netGate(src, 'openPlaced', 1000) then return end
    local row = placedRowNear(src, boxId)
    if not row then return end
    S.closeOpen(src)
    TriggerClientEvent('vorp_inventory:OpenInv', src)
    Wait(C.OpenDelayMs)
    row = S.char(src) and placedRowNear(src, boxId)
    if not row then return end
    if not S.ensure(boxId, row.item_name) then return refuse(src, boxId, 'could not register its inventory with vorp_inventory') end
    S.sessions[src] = boxId
    S.inv('openInventory', src, boxId)
    S.log('Placed Box Opened', S.Colour.opened, src, {
        { 'Box', boxText(S.def(row.item_name), boxId) },
        { 'Contents', S.contentsText(S.contents(boxId)) },
    })
end)

RegisterNetEvent('pup-misc:storagebox:pickup', function(boxId)
    local src = source
    if not S.netGate(src, 'pickup', 1000) then return end
    local row = placedRowNear(src, boxId)
    if not row then return end
    local name = row.item_name
    local d = S.def(name)
    local count = S.stampedCount(src)
    if count >= C.Carry.maxStamped then return S.tip(src, L.tooMany:format(count, C.Carry.maxStamped)) end
    if S.hasStampedOfName(src, name) then return S.tip(src, L.alreadyHave:format(d.label)) end
    -- atomic claim: only one player can move it from placed to not placed
    if S.update('UPDATE storage_boxes SET placed = 0 WHERE box_id = ? AND placed = 1', { boxId }) ~= 1 then
        return refuse(src, boxId, 'pick-up claim changed no row (someone else took it, or the database refused)')
    end
    S.Placed[boxId] = nil
    S.log('Box Picked Up', S.Colour.pickedUp, src, {
        { 'Box', boxText(d, boxId) },
        { 'Position', ('%.2f, %.2f, %.2f'):format(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0) },
        { 'Contents', S.contentsText(S.contents(boxId)) },
    })
    local given = S.char(src) and S.inv('addItem', src, name, 1, { boxId = boxId }) == true
    if not given then
        -- the position (heading included) was never cleared, so the box stands again where it was
        S.update('UPDATE storage_boxes SET placed = 1 WHERE box_id = ?', { boxId })
        S.Placed[boxId] = placedEntry(row)
        return refuse(src, boxId, 'vorp_inventory would not give the box item (full satchel or item limit?)')
    end
    S.update('UPDATE storage_boxes SET pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL WHERE box_id = ? AND placed = 0', { boxId })
    TriggerClientEvent('pup-misc:storagebox:placedRemove', -1, boxId)
    -- anyone still looking into the box on the ground must not keep taking from someone's satchel
    S.closeViewers(boxId, src)
    S.refreshCarry(src, 400)
    S.tip(src, L.pickedUp)
end)

------------------------------------------------------------------------------ a box leaves a satchel
-- the search module calls this before it moves an item from a robbed player (no give event fires)
function PupStorageBoxNoteTransfer(itemName, fromSrc, toSrc, logTitle)
    if not S.def(itemName) then return end
    fromSrc = tonumber(fromSrc)
    if not fromSrc then return end
    pendingGive[fromSrc] = { to = tonumber(toSrc), title = type(logTitle) == 'string' and logTitle or nil, at = GetGameTimer() }
end

-- vorp's give: remember who the box is going to (vorp_inventory registers and runs the give itself)
RegisterNetEvent('vorpinventory:serverGiveItem', function(itemId, _, target)
    local src = source
    if not S.char(src) then return end
    local c = S.containerById(src, itemId, true)
    if not c then return end
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return end
    pendingGive[src] = { to = target, at = GetGameTimer() }
end)

function S.afterRemoval(src, d, boxId, name)
    local g = pendingGive[src]
    -- vorp's give waits for the receiver to accept, which can take a while
    if g and GetGameTimer() - g.at > 120000 then g = nil end
    if g and g.to and GetPlayerName(g.to) and S.findStamped(g.to, boxId) then
        pendingGive[src] = nil
        S.log(g.title or 'Box Given to Player', g.title and S.Colour.robbed or S.Colour.given, src, {
            { 'To', ('%s (ID %s)'):format(S.charName(S.char(g.to)), tostring(g.to)) },
            { 'Box', boxText(d, boxId) },
            { 'Contents', S.contentsText(S.contents(boxId)) },
        })
        S.refreshCarry(g.to, 0)
        return
    end
    pendingGive[src] = nil
    -- still (or again) with the same player, being handled elsewhere, or standing in the world
    if GetPlayerName(src) and S.findStamped(src, boxId) then return end
    if S.flagged(S.fallback, boxId) or S.flagged(S.depositing, boxId) or S.flagged(S.placing, boxId) then return end
    if S.Placed[boxId] then return end
    local contents = S.contents(boxId)
    local kept = #contents > 0 and C.Switches.LoadedDroppedBox ~= 'delete'
    if kept then
        -- the item still exists somewhere (a drop pickup, another player's stash): whoever holds it can open it again
        S.ensure(boxId, name)
    else
        S.retire(boxId)
    end
    S.log('Box Deleted from Inventory', S.Colour.deleted, src, {
        { 'Box', boxText(d, boxId) },
        { 'Contents', S.contentsText(contents) },
        { 'Inventory', kept and 'kept (the box still holds goods)' or 'removed' },
    })
end

AddEventHandler('vorp_inventory:Server:OnItemRemoved', function(data, src)
    src = tonumber(src)
    if type(data) ~= 'table' or not src then return end
    local d = S.def(data.name)
    if not d then return end
    local boxId = S.metaBoxId(data.metadata)
    if not boxId then return end
    if S.flagged(S.depositing, boxId) or S.flagged(S.placing, boxId) then return end
    -- only a panel that shows this very box is closed (on the server too, or vorp would still
    -- let this player take from a box that now sits in someone else's satchel)
    S.closeBoxFor(src, boxId)
    S.refreshCarry(src, 200)
    local name = data.name
    SetTimeout(C.GiveCheckMs, function() S.afterRemoval(src, d, boxId, name) end)
end)

------------------------------------------------------------------------------ fallback: vorp moved a box item into a custom inventory
local function craftedOfBox(invId, name, boxId)
    local r = S.query([[
        SELECT ci.item_crafted_id AS id FROM character_inventories ci
        INNER JOIN items_crafted ic ON ic.id = ci.item_crafted_id
        WHERE ci.inventory_type = ? AND ci.item_name = ? AND ic.metadata LIKE ? LIMIT 1
    ]], { invId, name, '%"' .. boxId .. '"%' })
    return r[1] and tonumber(r[1].id) or nil
end

function S.fallbackDeposit(src, d, boxId, moved, invId)
    local ch = S.char(src)
    if not ch then return end
    local name = moved.name
    local meta = S.decodeMeta(moved.metadata)
    local crafted = craftedOfBox(invId, name, boxId)
    if not crafted then return end

    local function takeBack()
        if not S.inv('removeItemFromCustomInventory', invId, name, 1, crafted) then return false end
        if S.inv('addItem', src, name, 1, meta) ~= true then
            S.inv('addItemsToCustomInventory', invId, { { name = name, amount = 1, metadata = meta } }, ch.charIdentifier)
            return false
        end
        return true
    end

    if d.kind == 'pack' then
        if not takeBack() then return end
        local back = S.waitFor(function() return S.findStamped(src, boxId) end)
        S.reloadInv(src, invId)
        if back then S.unloadPack(src, back.item.id, boxId, 'custom', invId, false) end
        return
    end

    if S.units(boxId) == 0 then
        if takeBack() then S.tip(src, L.boxEmptyHere) end
        S.reloadInv(src, invId)
        return
    end

    -- loaded: every non-box stack goes in, and is read back before the box is destroyed
    local stacks, nested, want, before, items = {}, {}, {}, {}, {}
    for _, e in ipairs(S.contents(boxId)) do
        if S.def(e.name) then
            nested[#nested + 1] = e
        else
            stacks[#stacks + 1] = e
            want[e.name] = (want[e.name] or 0) + e.amount
            items[#items + 1] = { name = e.name, amount = e.amount, metadata = e.metadata }
        end
    end
    local names = {}
    for n in pairs(want) do
        before[n] = S.countByName(invId, n)
        names[#names + 1] = n
    end
    -- vorp checked the box item itself, not what is inside it
    local allowed = S.mayPut(ch, S.invRules(invId), names)
    local added = allowed and (#items == 0 or S.inv('addItemsToCustomInventory', invId, items, ch.charIdentifier) == true)
    local arrived = added and S.waitFor(function()
        for n, w in pairs(want) do
            if S.countByName(invId, n) - before[n] < w then return false end
        end
        return true
    end)
    if not arrived then
        S.tip(src, L.noRoom)
        S.reloadInv(src, invId)
        return
    end
    S.flag(S.depositing, boxId, C.DepositingFlagMs)
    S.inv('removeItemFromCustomInventory', invId, name, 1, crafted)
    for _, e in ipairs(nested) do S.inv('addItem', src, e.name, e.amount, e.metadata) end
    S.retire(boxId)
    S.tip(src, L.deposited)
    S.reloadInv(src, invId)
    S.refreshCarry(src, 0)
    S.log('Box Deposited to Inventory', S.Colour.deposited, src, {
        { 'Box', boxText(d, boxId) }, { 'Into', tostring(invId) }, { 'Contents', S.contentsText(stacks) },
    })
end

AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(moved, invId, src)
    src = tonumber(src)
    if type(moved) ~= 'table' or not src or invId == nil then return end
    invId = tostring(invId)
    local d = S.def(moved.name)
    if not d or S.isBoxId(invId) then return end
    local boxId = S.metaBoxId(moved.metadata)
    if not boxId or S.flagged(S.depositing, boxId) or S.flagged(S.fallback, boxId) then return end
    S.flag(S.fallback, boxId, 15000)
    SetTimeout(300, function() S.fallbackDeposit(src, d, boxId, moved, invId) end)
end)

------------------------------------------------------------------------------ state requests
local function sendPlaced(target)
    TriggerClientEvent('pup-misc:storagebox:placedList', target, S.placedList())
end

RegisterNetEvent('pup-misc:storagebox:requestState', function()
    local src = source
    if not S.netGate(src, 'requestState', 2000) then return end
    S.refreshCarry(src, 0)
    sendPlaced(src)
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    -- the previous character's open box and pending open belong to nobody now
    S.sessions[src] = nil
    pendingOpen[src] = nil
    SetTimeout(C.StateResendMs, function()
        if not GetPlayerName(src) then return end
        S.refreshCarry(src, 0)
        sendPlaced(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    TriggerClientEvent('pup-misc:storagebox:stop', src)
    S.sessions[src] = nil
    S.carriers[src] = nil
    hideoutSent[src] = nil
    pendingOpen[src] = nil
    pendingGive[src] = nil
    S.forgetPlayer(src)
end)

------------------------------------------------------------------------------ start-up
local function columnSet()
    local set = {}
    for _, r in ipairs(S.query("SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'storage_boxes'")) do
        set[r.c] = true
    end
    return set
end

local function ensureSchema()
    S.query([[
        CREATE TABLE IF NOT EXISTS `storage_boxes` (
            `box_id` varchar(20) NOT NULL,
            `capacity` int NOT NULL DEFAULT 500,
            `placed` tinyint(1) NOT NULL DEFAULT 0,
            `pos_x` float NULL DEFAULT NULL,
            `pos_y` float NULL DEFAULT NULL,
            `pos_z` float NULL DEFAULT NULL,
            `pos_h` float NULL DEFAULT NULL,
            `item_name` varchar(50) NULL DEFAULT NULL,
            PRIMARY KEY (`box_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local have = columnSet()
    local wanted = {
        { 'placed', '`placed` tinyint(1) NOT NULL DEFAULT 0' },
        { 'pos_x', '`pos_x` float NULL DEFAULT NULL' },
        { 'pos_y', '`pos_y` float NULL DEFAULT NULL' },
        { 'pos_z', '`pos_z` float NULL DEFAULT NULL' },
        { 'pos_h', '`pos_h` float NULL DEFAULT NULL' },
        { 'item_name', '`item_name` varchar(50) NULL DEFAULT NULL' },
    }
    for _, w in ipairs(wanted) do
        if not have[w[1]] then S.query('ALTER TABLE `storage_boxes` ADD COLUMN ' .. w[2]) end
    end
end

local function syncItems()
    local I = C.ItemDefaults
    for _, name in ipairs(S.BoxNames) do
        local d = S.Defs[name]
        S.query([[
            INSERT INTO `items` (`item`, `label`, `limit`, `weight`, `can_remove`, `type`, `usable`, `desc`, `rarityId`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `limit` = VALUES(`limit`), `weight` = VALUES(`weight`),
                `can_remove` = VALUES(`can_remove`), `type` = VALUES(`type`), `usable` = VALUES(`usable`),
                `desc` = VALUES(`desc`), `rarityId` = VALUES(`rarityId`)
        ]], { name, d.label, d.limit or I.limit, I.weight, I.canRemove, I.type, I.usable, d.desc or '', d.rarity or I.rarity })
    end
    local missing = {}
    for _, name in ipairs(S.BoxNames) do
        if type(S.inv('getItemDB', name)) ~= 'table' then missing[#missing + 1] = name end
    end
    if #missing > 0 then
        print(('^1[%s:storagebox] vorp_inventory has not loaded these items: %s. They were written to the items table; restart vorp_inventory once (or import sql/storagebox/install.sql before starting).^7')
            :format(S.RES, table.concat(missing, ', ')))
    end
end

function S.registerAll()
    local n = 0
    for _, r in ipairs(S.query('SELECT box_id, capacity, item_name FROM storage_boxes')) do
        if S.isBoxId(r.box_id) and S.register(r.box_id, r.item_name, r.capacity) then n = n + 1 end
    end
    S.debug(('registered %d box inventories'):format(n))
end

-- vorp calls the handler inline; the work waits on the DB, so it runs in its own thread
-- one use per player at a time: a second use while the first still creates and stamps a box
-- would create a second box id for the same item
local function onUseThread(data)
    local src = tonumber(type(data) == 'table' and data.source)
    if not src then return end
    CreateThread(function()
        if not S.lock('use:' .. src, 15000) then return end
        local ok, err = pcall(onUse, data)
        S.unlock('use:' .. src)
        if not ok then print(('^1[%s:storagebox]^7 box use failed: %s'):format(S.RES, tostring(err))) end
    end)
end

local function registerUsables()
    for _, name in ipairs(S.BoxNames) do S.inv('registerUsableItem', name, onUseThread, S.RES) end
end

CreateThread(function()
    local waited = 0
    while not S.resStarted('vorp_inventory') and waited < 60000 do
        Wait(500)
        waited = waited + 500
    end
    ensureSchema()
    syncItems()
    registerUsables()
    Wait(C.RegisterDelayMs)
    S.registerAll()
    S.loadPlaced()
    Wait(C.PlacedSyncDelayMs)
    sendPlaced(-1)
end)

-- vorp_inventory keeps custom inventories in memory only: register them again after it restarts
AddEventHandler('onResourceStart', function(name)
    if name ~= 'vorp_inventory' then return end
    SetTimeout(2000, function()
        registerUsables()
        S.registerAll()
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= S.RES then return end
    for src in pairs(S.sessions) do
        TriggerClientEvent('pup-misc:storagebox:stop', src)
        TriggerClientEvent('pup_storagebox:closeBoxPanel', src)
    end
    for src in pairs(S.carriers) do TriggerClientEvent('pup-misc:storagebox:stop', src) end
    for _, name2 in ipairs(S.BoxNames) do S.inv('unRegisterUsableItem', name2) end
end)
