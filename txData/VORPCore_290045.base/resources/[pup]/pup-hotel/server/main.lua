local Core <const> = exports.vorp_core:GetCore()

local function dbg(fmt, ...)
    if not Config.General.debug then return end
    print(('^5[pup-hotel]^7 ' .. fmt):format(...))
end

local function notify(src, msg, ms)
    TriggerClientEvent('vorp:TipRight', src, tostring(msg), tonumber(ms) or 5000)
end

-- per-player answers to the lookup callbacks (myStay, myAccess); a repeat inside the gap gets the last answer again
local recentAnswer = {}

-- every client re-asks on this event, so the remembered answers are dropped first
local function refreshAll(hotelId)
    recentAnswer = {}
    TriggerClientEvent('pup-hotel:refresh', -1, hotelId)
end

-- ------------------------------------------------------------------ schema

local Ready = false

CreateThread(function()
    local ok = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS hotel_rentals (
                id INT NOT NULL AUTO_INCREMENT,
                hotel VARCHAR(50) NOT NULL,
                room VARCHAR(50) NOT NULL,
                charid INT NOT NULL,
                identifier VARCHAR(50) NOT NULL DEFAULT '',
                guest VARCHAR(100) NOT NULL DEFAULT '',
                tier VARCHAR(30) NOT NULL DEFAULT '',
                rentedat INT NOT NULL DEFAULT 0,
                expiresat INT NOT NULL DEFAULT 0,
                PRIMARY KEY (id),
                KEY hotelroom (hotel, room),
                KEY charid (charid)
            )
        ]])
    end)
    if not ok then
        return print('^1[pup-hotel]^7 could not create hotel_rentals - the hotel stays off')
    end
    Ready = true
    dbg('schema ready')
end)

-- ---------------------------------------------------------------- settings
-- office prices win over Config.Tiers

local priceOverride = {} -- [tier] = price

CreateThread(function()
    while not Ready do Wait(250) end
    local ok = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS hotel_settings (
                k VARCHAR(64) NOT NULL,
                v VARCHAR(255) NOT NULL DEFAULT '',
                PRIMARY KEY (k)
            )
        ]])
        local rows = MySQL.query.await('SELECT k, v FROM hotel_settings') or {}
        for _, r in ipairs(rows) do
            local tier = tostring(r.k):match('^price:(.+)$')
            if tier then priceOverride[tier] = tonumber(r.v) end
        end
    end)
    if not ok then print('^1[pup-hotel]^7 settings table failed - prices fall back to the config') end
end)

--- What a room costs per day right now, override first.
local function priceOf(room)
    local tier <const> = room and room.tier
    if tier and priceOverride[tier] then return math.max(0, math.floor(priceOverride[tier])) end
    return RoomPrice(room)
end

--- The business's share of a room payment, banked after the guest has paid.
local function paySociety(price, what, who)
    local cfg <const> = Config.Integrations.society
    if not cfg or not cfg.job then return end
    local pct <const> = tonumber(cfg.cutPercent) or 0
    if pct <= 0 then return end
    local cut <const> = math.floor(((tonumber(price) or 0) * pct / 100) * 100) / 100
    if cut <= 0 then return end

    local ok, err = pcall(function()
        return exports['pup_business']:AddToLedger(cfg.job, cut, what, who)
    end)
    if not ok then
        print(('^1[pup-hotel]^7 could not bank %s for %s: %s'):format(cut, cfg.job, tostring(err)))
    else
        dbg('banked %s to %s from %s', cut, cfg.job, tostring(who))
    end
end

local function tierList()
    local out = {}
    for id, t in pairs(Config.Tiers or {}) do
        out[#out + 1] = {
            id = id,
            label = t.label or id,
            price = priceOverride[id] and math.max(0, math.floor(priceOverride[id])) or (tonumber(t.price) or 0),
            fromConfig = priceOverride[id] == nil,
        }
    end
    table.sort(out, function(a, b) return a.price < b.price end)
    return out
end

-- ------------------------------------------------------------------- query

--- Live rentals for one hotel, keyed by room id.
local function rentalsFor(hotelId)
    if not Ready then return {} end
    local rows = MySQL.query.await(
        'SELECT * FROM hotel_rentals WHERE hotel = ? AND expiresat > ?',
        { hotelId, os.time() }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[r.room] = r end
    return out
end

local function rentalOfChar(charid)
    if not Ready then return nil end
    return MySQL.single.await(
        'SELECT * FROM hotel_rentals WHERE charid = ? AND expiresat > ? ORDER BY expiresat DESC',
        { tonumber(charid) or 0, os.time() })
end

local function roomCountOfChar(charid)
    if not Ready then return 0 end
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM hotel_rentals WHERE charid = ? AND expiresat > ?',
        { tonumber(charid) or 0, os.time() })
    return tonumber(n) or 0
end

local function characterOf(src)
    local user = Core.getUser(src)
    return user and user.getUsedCharacter or nil
end

--- The source currently playing this character, or nil when they are offline.
local function sourceOfChar(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local ch = s and characterOf(s)
        if ch and tonumber(ch.charIdentifier) == charid then return s end
    end
    return nil
end

-- -------------------------------------------------------------- permission

local function isStaff(src)
    if GetResourceState('vorp_admin') == 'started' then
        local ok, allowed = pcall(function()
            return exports['vorp_admin']:hasPermission(src, Config.Staff.permission)
        end)
        if ok and allowed then return true end
    end
    local ok, group = pcall(function()
        local user = Core.getUser(src)
        return user and user.getGroup
    end)
    return ok and (group == 'admin' or group == 'superadmin' or group == 'owner')
end

local function mayManage(src)
    if isStaff(src) then return true end
    local ch = characterOf(src)
    if not ch then return false end
    local want = Config.Staff.jobs[ch.job]
    if want == nil then return false end
    return (tonumber(ch.jobGrade) or 0) >= (tonumber(want) or 0)
end

-- ---------------------------------------------------------------- the desk

--- Everything the clerk menu needs for one hotel, in one round trip.
Core.Callback.Register('pup-hotel:deskState', function(source, cb, hotelId)
    local src <const> = source
    CreateThread(function() DeskState(src, cb, hotelId) end)
end)

function DeskState(src, cb, hotelId)
    if not Ready then return cb(nil) end
    local hotel <const> = HotelById(tostring(hotelId or ''))
    if not hotel then return cb(nil) end

    -- who is staying where is the clerk's to know. A guest's menu only ever shows their own stay.
    local manage <const> = mayManage(src)
    local taken <const> = manage and rentalsFor(hotelId) or {}
    local now <const> = os.time()
    local rooms = {}
    for _, room in ipairs(hotel.rooms or {}) do
        local r = taken[room.id]
        local ends = r and tonumber(r.expiresat) or nil
        rooms[#rooms + 1] = {
            id = room.id,
            label = room.label or room.id,
            tier = room.tier,
            tierLabel = TierLabel(room),
            price = priceOf(room),
            guest = r and r.guest or nil,
            charid = r and tonumber(r.charid) or nil,
            -- the client has no `os` library, so it gets seconds and a ready string
            left = ends and math.max(0, ends - now) or nil,
            untilText = ends and os.date('%d %b %H:%M', ends) or nil,
        }
    end

    -- players standing near the desk, so a clerk can pick one off a list
    local nearby = {}
    local deskCoords <const> = hotel.desk
    if deskCoords and manage then
        for _, sid in ipairs(GetPlayers()) do
            local s = tonumber(sid)
            local ped = s and GetPlayerPed(s)
            if ped and ped ~= 0 then
                local d = #(GetEntityCoords(ped) - deskCoords)
                if d <= 12.0 then
                    local ch = characterOf(s)
                    if ch then
                        nearby[#nearby + 1] = {
                            charid = tonumber(ch.charIdentifier),
                            name = ('%s %s'):format(ch.firstname or '', ch.lastname or ''):gsub('^%s*(.-)%s*$', '%1'),
                            serverId = s,
                        }
                    end
                end
            end
        end
    end

    return cb({
        manage = manage,
        staff = isStaff(src),
        rooms = manage and rooms or {},
        nearby = nearby,
        tiers = tierList(),
        maxDays = Config.Rent.maxDays,
    })
end

--- The office setting a nightly rate. Stored against the tier, so every room of
--- that type changes at once.
RegisterServerEvent('pup-hotel:setPrice')
AddEventHandler('pup-hotel:setPrice', function(tier, price)
    local src <const> = source
    if not Ready then return end
    if not mayManage(src) then return notify(src, Locale.notRunHotel) end

    tier = tostring(tier or '')
    if not Config.Tiers[tier] then return notify(src, Locale.noSuchRoomType) end

    price = math.floor(tonumber(price) or -1)
    if price ~= price or price < 0 then return notify(src, Locale.notAPrice) end
    if price > 100000 then price = 100000 end

    priceOverride[tier] = price
    local ok = pcall(function()
        MySQL.update.await(
            'INSERT INTO hotel_settings (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)',
            { 'price:' .. tier, tostring(price) })
    end)
    if not ok then
        print('^1[pup-hotel]^7 could not store the price for ' .. tier .. ' - it will reset on restart')
    end

    notify(src, Locale.priceSet:format(Config.Tiers[tier].label or tier, price))
    dbg('%s set %s to %d', src, tier, price)
    for hotelId in pairs(Config.Hotels or {}) do
        refreshAll(hotelId)
    end
end)

AddEventHandler('playerDropped', function() recentAnswer[source] = nil end)

local function recent(src, name, gap)
    local mine <const> = recentAnswer[src]
    local last <const> = mine and mine[name]
    if last and GetGameTimer() - last.at < gap then return true, last.answer end
    return false
end

local function remember(src, name, answer)
    recentAnswer[src] = recentAnswer[src] or {}
    recentAnswer[src][name] = { at = GetGameTimer(), answer = answer }
    return answer
end

--- A guest asking after their own stay. No permission needed.
Core.Callback.Register('pup-hotel:myStay', function(source, cb)
    local src <const> = source
    local hit <const>, answer <const> = recent(src, 'myStay', 1500)
    if hit then return cb(answer) end
    remember(src, 'myStay', nil)
    CreateThread(function()
        local ch <const> = characterOf(src)
        if not Ready or not ch then return cb(nil) end
        local r <const> = rentalOfChar(ch.charIdentifier)
        if not r then return cb(nil) end
        local hotel <const> = HotelById(r.hotel)
        local room <const> = RoomById(r.hotel, r.room)
        local ends <const> = tonumber(r.expiresat) or 0
        return cb(remember(src, 'myStay', {
            hotel = r.hotel,
            hotelLabel = (hotel and hotel.label) or r.hotel,
            room = r.room,
            roomLabel = (room and room.label) or r.room,
            left = math.max(0, ends - os.time()),
            untilText = os.date('%d %b %H:%M', ends),
        }))
    end)
end)

-- ------------------------------------------------------------------ assign

local function findCharacter(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    return MySQL.single.await(
        'SELECT charidentifier, identifier, firstname, lastname FROM characters WHERE charidentifier = ?',
        { charid })
end

-- A clerk offers a room or more nights. Only the guest can agree to pay: without that, anyone on the
-- job could set the price to what somebody holds and take it from them, wherever they were.
local OFFER_SECONDS <const> = 45
local offers = {}  -- [guest source] = the offer they are looking at
local working = {} -- ['hotel:room'] = true while a stay is being written

local function balanceOf(ch)
    return Config.Rent.currency == 1 and (tonumber(ch.gold) or 0) or (tonumber(ch.money) or 0)
end

local function fullName(ch)
    return ('%s %s'):format(ch.firstname or '', ch.lastname or '')
end

local function tell(src, msg, ms)
    if src and GetPlayerName(src) then notify(src, msg, ms) end
end

--- One thing at a time on a room: the checks and the write wait on the database in between.
local function onRoom(hotelId, roomId, clerk, fn)
    local k <const> = hotelId .. ':' .. roomId
    if working[k] then return tell(clerk, Locale.roomBusy) end
    working[k] = true
    local ok <const>, err <const> = pcall(fn)
    working[k] = nil
    if not ok then print(('^1[pup-hotel]^7 %s: %s'):format(k, tostring(err))) end
end

--- Checked again here, because anything can change while a guest reads an offer.
local function writeStay(clerk, hotelId, room, guest, days, charge)
    local charid <const> = tonumber(guest.charidentifier)

    local taken <const> = rentalsFor(hotelId)
    if taken[room.id] then
        return tell(clerk, Locale.roomTaken
            :format(room.label or room.id, os.date('%d %b %H:%M', tonumber(taken[room.id].expiresat))))
    end
    if roomCountOfChar(charid) >= (tonumber(Config.Rent.roomsPerCharacter) or 1) then
        return tell(clerk, Locale.alreadyHoldsRoom)
    end

    -- PAY BEFORE THE ROOM IS WRITTEN, and only from the guest's own pocket
    local payer <const> = charge > 0 and sourceOfChar(charid) or nil
    local gch <const> = payer and characterOf(payer) or nil
    if charge > 0 then
        if not gch then return tell(clerk, Locale.mustBeOnline) end
        if balanceOf(gch) < charge then
            tell(clerk, Locale.cannotAffordStay)
            return tell(payer, Locale.guestNeedsMoney:format(charge))
        end
        gch.removeCurrency(Config.Rent.currency, charge)
    end

    local now <const> = os.time()
    local expires <const> = now + (days * (tonumber(Config.Rent.daySeconds) or 86400))
    local name <const> = ('%s %s'):format(guest.firstname or '', guest.lastname or ''):gsub('^%s*(.-)%s*$', '%1')

    local written <const> = pcall(MySQL.insert.await, [[
        INSERT INTO hotel_rentals (hotel, room, charid, identifier, guest, tier, rentedat, expiresat)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { hotelId, room.id, charid, guest.identifier or '', name, room.tier or '', now, expires })
    if not written then
        if gch then gch.addCurrency(Config.Rent.currency, charge) end
        return tell(clerk, Locale.deskClosed)
    end
    if gch then paySociety(charge, 'Room rent', fullName(gch)) end

    tell(clerk, Locale.assigned
        :format(name, room.label or room.id, os.date('%d %b %H:%M', expires)))

    local guestSrc <const> = sourceOfChar(charid)
    if guestSrc then
        notify(guestSrc, Locale.guestAssigned
            :format(room.label or room.id, os.date('%d %b %H:%M', expires)), 8000)
    end
    dbg('%s assigned %s/%s to %s for %d day(s)', tostring(clerk), hotelId, room.id, name, days)
    refreshAll(hotelId)
end

local function writeExtension(clerk, hotelId, room, rentalId, days, charge)
    local r <const> = rentalsFor(hotelId)[room.id]
    if not r or (rentalId and r.id ~= rentalId) then return tell(clerk, Locale.nobodyStaying) end

    local payer <const> = charge > 0 and sourceOfChar(r.charid) or nil
    local gch <const> = payer and characterOf(payer) or nil
    if charge > 0 then
        if not gch then return tell(clerk, Locale.mustBeOnline) end
        if balanceOf(gch) < charge then return tell(clerk, Locale.cannotAfford) end
        gch.removeCurrency(Config.Rent.currency, charge)
    end

    local expires <const> = (tonumber(r.expiresat) or os.time()) + (days * (tonumber(Config.Rent.daySeconds) or 86400))
    local written <const> = pcall(MySQL.update.await, 'UPDATE hotel_rentals SET expiresat = ? WHERE id = ?', { expires, r.id })
    if not written then
        if gch then gch.addCurrency(Config.Rent.currency, charge) end
        return tell(clerk, Locale.deskClosed)
    end
    if gch then paySociety(charge, 'Room extension', fullName(gch)) end

    tell(clerk, Locale.extended:format(room.label or room.id, os.date('%d %b %H:%M', expires)))
    refreshAll(hotelId)
end

local function sendOffer(guestSrc, offer)
    local current <const> = offers[guestSrc]
    if current and current.expires > os.time() then return notify(offer.clerk, Locale.guestHasOffer) end

    offer.expires = os.time() + OFFER_SECONDS
    offers[guestSrc] = offer
    local hotel <const> = HotelById(offer.hotelId)
    TriggerClientEvent('pup-hotel:offer', guestSrc, {
        hotel = (hotel and hotel.label) or offer.hotelId,
        room = offer.room.label or offer.room.id,
        days = offer.days,
        total = offer.charge,
        extend = offer.rentalId ~= nil,
    })
    notify(offer.clerk, Locale.offerSent)

    SetTimeout(OFFER_SECONDS * 1000, function()
        if offers[guestSrc] ~= offer then return end
        offers[guestSrc] = nil
        tell(offer.clerk, Locale.offerExpired)
        if GetPlayerName(guestSrc) then TriggerClientEvent('pup-hotel:offerGone', guestSrc) end
    end)
end

RegisterServerEvent('pup-hotel:offerAnswer')
AddEventHandler('pup-hotel:offerAnswer', function(accept)
    local src <const> = source
    local offer <const> = offers[src]
    offers[src] = nil
    if not offer or not Ready then return end

    if os.time() > offer.expires then
        notify(src, Locale.offerExpired)
        return tell(offer.clerk, Locale.offerExpired)
    end
    if accept ~= true then return tell(offer.clerk, Locale.offerDeclined) end

    -- the offer was made to this character by someone who runs the desk. Both still have to be true.
    local ch <const> = characterOf(src)
    if not ch or tonumber(ch.charIdentifier) ~= offer.charid
        or not GetPlayerName(offer.clerk) or not mayManage(offer.clerk) then
        return notify(src, Locale.deskClosed)
    end

    onRoom(offer.hotelId, offer.room.id, offer.clerk, function()
        if offer.rentalId then
            writeExtension(offer.clerk, offer.hotelId, offer.room, offer.rentalId, offer.days, offer.charge)
        else
            writeStay(offer.clerk, offer.hotelId, offer.room, offer.guest, offer.days, offer.charge)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    offers[source] = nil
end)

RegisterServerEvent('pup-hotel:assign')
AddEventHandler('pup-hotel:assign', function(hotelId, roomId, charid, days, free)
    local src <const> = source
    if not Ready then return end
    if not mayManage(src) then
        return notify(src, Locale.notYourDesk)
    end

    hotelId, roomId = tostring(hotelId or ''), tostring(roomId or '')
    local hotel <const> = HotelById(hotelId)
    local room <const> = RoomById(hotelId, roomId)
    if not hotel or not room then return notify(src, Locale.noSuchRoom) end

    days = math.floor(tonumber(days) or 0)
    if days ~= days or days < 1 then return notify(src, Locale.notDays) end
    if days > Config.Rent.maxDays then days = Config.Rent.maxDays end

    local guest <const> = findCharacter(charid)
    if not guest then return notify(src, Locale.noCharacter) end
    charid = tonumber(guest.charidentifier)

    -- the room has to be free, checked here and not in the menu
    local taken <const> = rentalsFor(hotelId)
    if taken[room.id] then
        return notify(src, Locale.roomTaken
            :format(room.label or room.id, os.date('%d %b %H:%M', tonumber(taken[room.id].expiresat))))
    end

    if roomCountOfChar(charid) >= (tonumber(Config.Rent.roomsPerCharacter) or 1) then
        return notify(src, Locale.alreadyHoldsRoom)
    end

    local price <const> = priceOf(room) * days
    free = free == true and Config.Staff.allowFreeAssign and isStaff(src)
    if price <= 0 or free then
        return onRoom(hotelId, room.id, src, function() writeStay(src, hotelId, room, guest, days, 0) end)
    end

    local guestSrc <const> = sourceOfChar(charid)
    if not guestSrc then return notify(src, Locale.mustBeOnline) end
    if balanceOf(characterOf(guestSrc)) < price then
        notify(src, Locale.cannotAffordStay)
        return notify(guestSrc, Locale.guestNeedsMoney:format(price))
    end

    sendOffer(guestSrc, {
        clerk = src, hotelId = hotelId, room = room, guest = guest,
        charid = charid, days = days, charge = price,
    })
end)

RegisterServerEvent('pup-hotel:extend')
AddEventHandler('pup-hotel:extend', function(hotelId, roomId, days)
    local src <const> = source
    if not Ready then return end
    if not mayManage(src) then return notify(src, Locale.notYourDesk) end

    hotelId, roomId = tostring(hotelId or ''), tostring(roomId or '')
    local room <const> = RoomById(hotelId, roomId)
    if not room then return notify(src, Locale.noSuchRoom) end

    days = math.floor(tonumber(days) or 0)
    if days ~= days or days < 1 then return end
    if days > Config.Rent.maxDays then days = Config.Rent.maxDays end

    local r <const> = rentalsFor(hotelId)[room.id]
    if not r then return notify(src, Locale.nobodyStaying) end

    local price <const> = priceOf(room) * days
    if price <= 0 then
        return onRoom(hotelId, room.id, src, function() writeExtension(src, hotelId, room, r.id, days, 0) end)
    end

    local guestSrc <const> = sourceOfChar(r.charid)
    if not guestSrc then return notify(src, Locale.mustBeOnline) end
    if balanceOf(characterOf(guestSrc)) < price then return notify(src, Locale.cannotAfford) end

    sendOffer(guestSrc, {
        clerk = src, hotelId = hotelId, room = room, rentalId = r.id,
        charid = tonumber(r.charid), days = days, charge = price,
    })
end)

RegisterServerEvent('pup-hotel:evict')
AddEventHandler('pup-hotel:evict', function(hotelId, roomId)
    local src <const> = source
    if not Ready then return end
    if not mayManage(src) then return notify(src, Locale.notYourDesk) end

    local room <const> = RoomById(tostring(hotelId or ''), tostring(roomId or ''))
    if not room then return end
    local r <const> = rentalsFor(hotelId)[room.id]
    if not r then return notify(src, Locale.nobodyStaying) end

    MySQL.update.await('DELETE FROM hotel_rentals WHERE id = ?', { r.id })
    TriggerEvent('pup-hotel:internal:relock', hotelId, room.id)
    notify(src, Locale.roomFreed:format(room.label or room.id))

    local guestSrc <const> = sourceOfChar(r.charid)
    if guestSrc then notify(guestSrc, Locale.guestEvicted, 8000) end
    dbg('%s evicted %s from %s/%s', src, tostring(r.guest), hotelId, room.id)
    refreshAll(hotelId)
end)

-- ------------------------------------------------------------------- sweep

local warned = {}

CreateThread(function()
    while true do
        Wait(math.max(10, tonumber(Config.Rent.sweepSeconds) or 60) * 1000)
        if Ready then
            local now <const> = os.time()

            -- a word before they lose it
            local soon = MySQL.query.await(
                'SELECT * FROM hotel_rentals WHERE expiresat > ? AND expiresat <= ?',
                { now, now + (tonumber(Config.Rent.warnBeforeSeconds) or 3600) }) or {}
            for _, r in ipairs(soon) do
                if not warned[r.id] then
                    warned[r.id] = true
                    local s = sourceOfChar(r.charid)
                    if s then
                        notify(s, Locale.stayEndingSoon:format(os.date('%H:%M', tonumber(r.expiresat))), 8000)
                    end
                end
            end

            local gone = MySQL.query.await('SELECT * FROM hotel_rentals WHERE expiresat <= ?', { now }) or {}
            if #gone > 0 then
                MySQL.update.await('DELETE FROM hotel_rentals WHERE expiresat <= ?', { now })
                for _, r in ipairs(gone) do
                    warned[r.id] = nil
                    local s = sourceOfChar(r.charid)
                    if s then notify(s, Locale.stayEnded, 8000) end
                    TriggerEvent('pup-hotel:internal:relock', r.hotel, r.room)
                    refreshAll(r.hotel)
                end
                dbg('swept %d expired stay(s)', #gone)
            end
        end
    end
end)

-- ------------------------------------------------------------- room doors
-- Every room door is locked unless somebody has deliberately opened it.

local doorOpen = {} -- ['hotel:room'] = true when unlocked

local function doorKey(hotelId, roomId) return ('%s:%s'):format(hotelId, roomId) end

local function broadcastDoor(hotelId, roomId, open)
    TriggerClientEvent('pup-hotel:doorState', -1, hotelId, roomId, open == true)
end

--- Locks a room again and tells everyone. Used on eviction and on expiry.
local function relock(hotelId, roomId)
    local k <const> = doorKey(hotelId, roomId)
    if not doorOpen[k] then return end
    doorOpen[k] = nil
    broadcastDoor(hotelId, roomId, false)
end

-- eviction and the sweep sit above this block, so they reach it by event
AddEventHandler('pup-hotel:internal:relock', function(hotelId, roomId)
    relock(tostring(hotelId or ''), tostring(roomId or ''))
end)

--- May this player work this room's door right now?
local function mayOpenRoom(src, hotelId, roomId)
    if mayManage(src) then return true end
    local ch <const> = characterOf(src)
    if not ch then return false end
    local r <const> = rentalsFor(hotelId)[roomId]
    return r ~= nil and tonumber(r.charid) == tonumber(ch.charIdentifier)
end

-- a client that has just loaded needs the full picture
RegisterServerEvent('pup-hotel:doorsPlease')
AddEventHandler('pup-hotel:doorsPlease', function()
    local src <const> = source
    local open = {}
    for k in pairs(doorOpen) do open[#open + 1] = k end
    TriggerClientEvent('pup-hotel:doorsAll', src, open)
end)

local lastDoor = {}
AddEventHandler('playerDropped', function() lastDoor[source] = nil end)

RegisterServerEvent('pup-hotel:doorToggle')
AddEventHandler('pup-hotel:doorToggle', function(hotelId, roomId)
    local src <const> = source
    -- each toggle goes out to every player
    local nowMs <const> = GetGameTimer()
    if lastDoor[src] and nowMs - lastDoor[src] < 1000 then return end
    lastDoor[src] = nowMs
    hotelId, roomId = tostring(hotelId or ''), tostring(roomId or '')
    local room <const> = RoomById(hotelId, roomId)
    if not room or not room.door then return end

    -- CHECKED HERE, not in the prompt. The client only decides what to draw.
    if not mayOpenRoom(src, hotelId, roomId) then
        return notify(src, Locale.notYourRoom)
    end

    local k <const> = doorKey(hotelId, roomId)
    local open <const> = not doorOpen[k]
    doorOpen[k] = open or nil
    broadcastDoor(hotelId, roomId, open)
    dbg('%s %s %s/%s', src, open and 'unlocked' or 'locked', hotelId, roomId)

    local after <const> = tonumber(Config.Doors and Config.Doors.relockSeconds) or 0
    if open and after > 0 then
        SetTimeout(after * 1000, function() relock(hotelId, roomId) end)
    end
end)

--- Which rooms this player may open, so their client can draw the right prompt.
Core.Callback.Register('pup-hotel:myAccess', function(source, cb)
    local src <const> = source
    local hit <const>, answer <const> = recent(src, 'myAccess', 1000)
    if hit then return cb(answer or {}) end
    CreateThread(function()
        if not Ready then return cb({}) end
        local out = {}
        remember(src, 'myAccess', out)
        if mayManage(src) then
            for hotelId, hotel in pairs(Config.Hotels or {}) do
                for _, room in ipairs(hotel.rooms or {}) do
                    out[#out + 1] = doorKey(hotelId, room.id)
                end
            end
            return cb(out)
        end
        local ch <const> = characterOf(src)
        if not ch then return cb({}) end
        local rows = MySQL.query.await(
            'SELECT hotel, room FROM hotel_rentals WHERE charid = ? AND expiresat > ?',
            { tonumber(ch.charIdentifier) or 0, os.time() }) or {}
        for _, r in ipairs(rows) do out[#out + 1] = doorKey(r.hotel, r.room) end
        return cb(out)
    end)
end)

-- ---------------------------------------------------------------- setup aid

-- The three setup commands are ACE-restricted (the `true` argument).

RegisterCommand('hotelcoords', function(src)
    TriggerClientEvent('pup-hotel:printCoords', src)
end, true)

--- Aim at a door and this names it, so /hotelroom has something to be given.
RegisterCommand('hoteldoor', function(src)
    if src == 0 then return print('run this in-game, looking at the door') end
    TriggerClientEvent('pup-hotel:findDoor', src)
end, true)

--- /hotelroom <hotel> <id> <tier> [door] [label...]
RegisterCommand('hotelroom', function(src, args)
    if src == 0 then return print('run this in-game, standing at the door') end

    local function usage(why)
        if why then notify(src, why, 6000) end
        notify(src, Locale.hotelroomUsage, 9000)
        print('^3[pup-hotel]^7 /hotelroom <hotel> <id> <tier> [doorName] [label...]')
        local names = {}
        for id in pairs(Config.Hotels or {}) do names[#names + 1] = id end
        local tiers = {}
        for id in pairs(Config.Tiers or {}) do tiers[#tiers + 1] = id end
        print(('   hotels: %s'):format(table.concat(names, ', ')))
        print(('   tiers:  %s'):format(table.concat(tiers, ', ')))
    end

    local hotelId <const> = tostring(args[1] or '')
    local roomId  <const> = tostring(args[2] or '')
    local tier    <const> = tostring(args[3] or '')
    -- both of these get written into a Lua file that loads at every start
    local door    <const> = args[4] and (tostring(args[4]):gsub("['\\%c]", '')) or nil

    local hotel <const> = Config.Hotels[hotelId]
    if not hotel then return usage(Locale.noHotelByName) end
    if roomId == '' or roomId:find('[^%w_]') then
        return usage(Locale.badRoomId)
    end
    if not Config.Tiers[tier] then return usage(Locale.noTierByName) end
    if RoomById(hotelId, roomId) then return usage(Locale.roomIdTaken) end

    local label = table.concat(args, ' ', 5)
    if label == '' then label = roomId:gsub('_', ' '):gsub('^%l', string.upper) end
    label = label:gsub("['\\%c]", '')

    local ped <const> = GetPlayerPed(src)
    local c <const> = GetEntityCoords(ped)

    local line <const> = ("HotelAddRoom('%s', { id = '%s', label = '%s', tier = '%s',%s coords = vector3(%.3f, %.3f, %.3f) })")
        :format(hotelId, roomId, label:gsub("'", ""), tier,
            door and (" door = '" .. door .. "',") or '', c.x, c.y, c.z)

    local res <const> = GetCurrentResourceName()
    local path <const> = 'config/rooms_custom.lua'
    local existing <const> = LoadResourceFile(res, path) or ''
    local ok <const> = SaveResourceFile(res, path, existing .. '\n' .. line .. '\n', -1)

    if not ok then
        print('^1[pup-hotel]^7 could not write ' .. path .. ' - is the resource folder read-only?')
        return notify(src, Locale.roomWriteFailed, 8000)
    end

    -- live now so the room can be let immediately; the file is what survives a restart
    HotelAddRoom(hotelId, {
        id = roomId, label = label, tier = tier, door = door,
        coords = vector3(c.x, c.y, c.z),
    })
    TriggerClientEvent('pup-hotel:addRoom', -1, hotelId, {
        id = roomId, label = label, tier = tier, door = door,
        coords = vector3(c.x, c.y, c.z),
    })

    print(('^2[pup-hotel]^7 %s'):format(line))
    notify(src, Locale.roomAdded:format(label, hotel.label or hotelId), 6000)
end, true)

-- ----------------------------------------------------------------- exports

--- Does this character hold this room right now?
exports('HasRoom', function(charid, hotelId, roomId)
    if not Ready then return false end
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM hotel_rentals WHERE charid = ? AND hotel = ? AND room = ? AND expiresat > ?',
        { tonumber(charid) or 0, tostring(hotelId), tostring(roomId), os.time() })
    return (tonumber(n) or 0) > 0
end)

--- Who holds a room, or nil.
exports('RoomHolder', function(hotelId, roomId)
    if not Ready then return nil end
    return MySQL.single.await(
        'SELECT charid, guest, expiresat FROM hotel_rentals WHERE hotel = ? AND room = ? AND expiresat > ?',
        { tostring(hotelId), tostring(roomId), os.time() })
end)
