-- pup_realestate | interiors: who may be inside, routing buckets, knocks and guests, motels, startup data

local function passValid(src, rowId)
    local pass = S.passes[src]
    return pass and pass.house == rowId and pass.expires >= Now()
end

-- may this character be inside this row's interior
function S.mayEnter(src, ch, rowId)
    local r, isMotel = S.row(rowId)
    if not r then return false end
    if isMotel then return r.owner == ch.charid end
    if r.kind ~= KIND_TELE or not U.interior(r) then return false end
    return S.hasAccess(r, ch.charid) or passValid(src, r.id)
end

function S.clearInside(src)
    local p = S.players[src]
    if not p or not p.inside then return end
    local occ = S.occupants[p.inside]
    if occ then
        occ[src] = nil
        if not next(occ) then S.occupants[p.inside] = nil end
    end
    p.inside = nil
end

local function setInside(src, rowId)
    local p = S.player(src)
    if p.inside and p.inside ~= rowId then S.clearInside(src) end
    p.inside = rowId
    if S.houses[rowId] then
        S.occupants[rowId] = S.occupants[rowId] or {}
        S.occupants[rowId][src] = true
    end
end

local function writeRecord(charid, value)
    MySQL.update('UPDATE characters SET motel = ? WHERE charidentifier = ?', { value, charid })
end

Net('sv_enter', 500, function(src, ch, rowId)
    rowId = U.int(rowId)
    if not rowId or not S.mayEnter(src, ch, rowId) then return end
    local r, isMotel = S.row(rowId)
    local record
    if isMotel then
        record = { motel = r.motel, id = r.id }
    else
        record = { motel = U.interiorName(r), id = r.id, ishouse = 1 }
        local pass = S.passes[src]
        if pass and pass.house == r.id and not Config.Rules.guestPassReusable and not S.hasAccess(r, ch.charid) then
            S.passes[src] = nil
        end
    end
    writeRecord(ch.charid, json.encode(record))
    setInside(src, rowId)
end)

Net('sv_left', 300, function(src, ch)
    writeRecord(ch.charid, '0')
    S.clearInside(src)
end)

-- answers true when the bucket was set; a refusal leaves the bucket as it was
Rpc('sv_bucket', 200, function(src, ch, rowId)
    rowId = U.int(rowId) or 0
    if rowId == 0 then
        SetPlayerRoutingBucket(tostring(src), 0)
        return true
    end
    if not (S.insideRow(src, rowId) or S.mayEnter(src, ch, rowId)) then return false end
    local bucket = rowId + Config.BucketOffset
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetPlayerRoutingBucket(tostring(src), bucket)
    return true
end)

-- knocking at a teleporter house
Net('sv_knock', 3000, function(src, ch, id)
    local h = S.house(id)
    if not h or h.kind ~= KIND_TELE or not h.owned then return end
    local door, ped = U.frontDoor(h), S.pedPos(src)
    if not door or not ped or #(ped - door) > Config.Reach.serverDoor then return end
    local occ = S.occupants[h.id]
    if not occ then return end
    local told = false
    for osrc in pairs(occ) do
        if S.online(osrc) then
            TriggerClientEvent('pup_realestate:cl_knock', osrc, h.id, src, ch.name)
            told = true
        else
            occ[osrc] = nil
        end
    end
    if not told then return end
    S.knocks[h.id] = S.knocks[h.id] or {}
    S.knocks[h.id][src] = Now()
end)

Net('sv_allow', 500, function(src, _, id, knocker)
    local h = S.house(id)
    knocker = U.int(knocker)
    if not h or not knocker or knocker == src or not S.insideRow(src, h.id) then return end
    if not S.online(knocker) then return end
    local list = S.knocks[h.id]
    local at = list and list[knocker]
    if not at or Now() - at > Config.Timers.knockWindow then return end
    list[knocker] = nil
    S.passes[knocker] = { house = h.id, expires = Now() + Config.Timers.guestPass }
    TriggerClientEvent('pup_realestate:cl_letIn', knocker, h.id)
end)

-- motels
function S.roomsOf(charid)
    local list = {}
    for _, m in pairs(S.motels) do
        if m.owner == charid then list[#list + 1] = { id = m.id, motel = m.motel } end
    end
    return list
end

local buying = {}

Net('sv_motelBuy', 2000, function(src, ch, key)
    if not Config.Motels.enabled then return end
    local m = U.motel(key)
    if not m then return end
    local ped = S.pedPos(src)
    if not ped or #(ped - m.entrance) > Config.Reach.motelEntrance + 4.0 then return end
    for _, room in pairs(S.motels) do
        if room.owner == ch.charid and room.motel == m.key then
            return TriggerClientEvent('pup_realestate:cl_rooms', src, S.roomsOf(ch.charid))
        end
    end
    local guard = ch.charid .. ':' .. m.key
    if buying[guard] then return end
    if not S.takeCash(ch, m.price) then
        TriggerClientEvent('pup_realestate:cl_rooms', src, S.roomsOf(ch.charid))
        return Tip(src, T('cant_afford_hotel', m.price))
    end
    buying[guard] = true
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO playerhousing (`type`, primarydoor, otherdoors, `range`, owned, selleridentifier, sellercharidentifier,
            ledger, tax, repoed, invspace, `upgrade`, keyholders, changingroom, inventorylocation, items, furniture,
            price, buyeridentifier, buyercharidentifier, taxledger, motel)
        VALUES (1, '[]', '[]', 0, 1, '', 0, 0, 0, 0, ?, 0, '[]', '[]', '[]', '[]', '[]', ?, ?, ?, 0, ?)]],
        { m.slots, m.price, ch.ident, ch.charid, m.key })
    buying[guard] = nil
    id = ok and U.int(id)
    if not id then
        S.giveCash(ch, m.price)
        return Warn('buying a motel room failed for char %s', ch.charid)
    end
    S.motels[id] = { id = id, motel = m.key, owner = ch.charid, ownerIdent = ch.ident, slots = m.slots }
    S.ensureContainer(id)
    TriggerClientEvent('pup_realestate:cl_rooms', src, S.roomsOf(ch.charid))
    AdminLog(('%s (%s) bought a room at motel %s for $%s (row %s)'):format(ch.name, ch.ident, m.key, m.price, id))
end)

-- the relog record in characters.motel
local function relogRecord(src, ch)
    local ok, raw = pcall(MySQL.scalar.await, 'SELECT motel FROM characters WHERE charidentifier = ?', { ch.charid })
    if not ok or raw == nil or raw == '0' or raw == '' then return nil end
    local rec = S.decode(raw, nil)
    local rowId = type(rec) == 'table' and U.int(rec.id)
    local function reset() writeRecord(ch.charid, '0') end
    if not rowId then reset(); return nil end
    if rec.ishouse then
        local h = S.houses[rowId]
        if h and h.kind == KIND_TELE and U.interior(h) then
            if S.mayEnter(src, ch, rowId) then
                setInside(src, rowId)
                return { kind = 'house', id = rowId }
            end
            -- a guest or former owner logs back in at the house door
            reset()
            return { kind = 'house', id = rowId, outside = true }
        end
        reset()
        return { kind = 'gone' }
    end
    local m = U.motel(rec.motel)
    local room = S.motels[rowId]
    if m and room and room.motel == m.key and room.owner == ch.charid then
        setInside(src, rowId)
        return { kind = 'motel', id = rowId, motel = m.key }
    end
    reset()
    if m then return { kind = 'motel', motel = m.key, outside = true } end
    return { kind = 'gone' }
end

local function auctionedList()
    local list = {}
    for hid in pairs(S.auctioned) do list[#list + 1] = hid end
    return list
end
S.auctionedList = auctionedList

-- everything a client needs after selecting a character (and after a restart)
Rpc('sv_init', 2000, function(src, ch)
    local p = S.player(src)
    if p.charid and p.charid ~= ch.charid then
        -- character switch: drop the old character's records and return to the world
        S.dropPlayer(src, true)
        SetPlayerRoutingBucket(tostring(src), 0)
    end
    p.charid = ch.charid
    if p.inside then S.clearInside(src) end
    -- (the bucket is only touched for a character switch above, or by the client's relog placement:
    -- a restart must not pull players out of other resources' instances)
    local record = relogRecord(src, ch)
    S.sendFull(src)
    return {
        charid = ch.charid,
        rooms = S.roomsOf(ch.charid),
        auctioned = auctionedList(),
        job = { job = ch.job, grade = ch.grade, group = ch.group },
        record = record,
    }
end)
