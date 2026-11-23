-- pup_realestate | native prompt groups: one group per frame, the nearest thing wins

local function str(s) return CreateVarString(10, 'LITERAL_STRING', tostring(s)) end

local function newPrompt(group, control, label)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, control)
    PromptSetText(p, str(label))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return { handle = p, label = label, visible = true }
end

local function setLabel(pr, label)
    if pr.label ~= label then
        pr.label = label
        PromptSetText(pr.handle, str(label))
    end
end

local function setShown(pr, on)
    if pr.visible ~= on then
        pr.visible = on
        PromptSetVisible(pr.handle, on)
        PromptSetEnabled(pr.handle, on)
    end
end

local function pressed(pr)
    return pr.visible and PromptHasStandardModeCompleted(pr.handle)
end

local G = {}

CreateThread(function()
    G.door = { id = GetRandomIntInRange(0, 0xffffff) }
    G.door.main = newPrompt(G.door.id, Config.Keys.interact, Locale.open)
    G.door.lock = newPrompt(G.door.id, Config.Keys.lock, Locale.lock_door)
    G.single = { id = GetRandomIntInRange(0, 0xffffff) }
    G.single.main = newPrompt(G.single.id, Config.Keys.interact, Locale.open)
    G.knock = { id = GetRandomIntInRange(0, 0xffffff) }
    G.knock.allow = newPrompt(G.knock.id, Config.Keys.interact, Locale.allow_in)
    G.knock.ignore = newPrompt(G.knock.id, Config.Keys.decline, Locale.ignore)
end)

-- candidates near the player, rebuilt every half second
local function add(list, pos, c)
    -- a little wider than the reach, so the frame loop sees someone walking up
    if #(pos - c.pos) <= c.reach + 3.0 then list[#list + 1] = c end
end

local function scan(pos)
    local list = {}
    -- house doors
    for id, h in pairs(C.houses) do
        local front = type(h.doors) == 'table' and h.doors[1]
        local fpos = U.vec(front)
        if fpos and (h.kind == KIND_TELE or C.near[id]) and #(pos - fpos) < 12.0 then
            local ppos = (h.kind == KIND_REAL and tonumber(front.o)) and vector3(front.o + 0.0, front.p + 0.0, front.q + 0.0) or fpos
            add(list, pos, { kind = 'door', house = id, seq = 0, pos = ppos, doorPos = fpos, reach = Config.Reach.door })
            if h.kind == KIND_REAL then
                for i, d in ipairs(h.other or {}) do
                    local dp = U.vec(d)
                    if dp then
                        local pp = tonumber(d.o) and vector3(d.o + 0.0, d.p + 0.0, d.q + 0.0) or dp
                        add(list, pos, { kind = 'door', house = id, seq = U.int(d.secondarydoorid) or i, pos = pp, doorPos = dp, reach = Config.Reach.door, extra = true })
                    end
                end
            end
        end
        -- stash and wardrobe spots of houses near you (outside)
        if C.near[id] and h.kind ~= KIND_TELE and C.hasAccess(h) then
            local s, w = U.vec(h.stash), U.vec(h.changing)
            if s then add(list, pos, { kind = 'stash', row = id, pos = s, reach = Config.Reach.houseSpot }) end
            if w then add(list, pos, { kind = 'wardrobe', row = id, pos = w, reach = Config.Reach.houseSpot }) end
        end
    end
    -- inside an interior
    if C.inside then
        if C.inside.kind == 'house' then
            local h = C.houses[C.inside.row]
            local int = U.interior(h)
            if int then add(list, pos, { kind = 'exit', row = C.inside.row, pos = int.entry, reach = Config.Reach.exit }) end
            if h and C.hasAccess(h) then
                local s, w = U.vec(h.stash), U.vec(h.changing)
                if s then add(list, pos, { kind = 'stash', row = h.id, pos = s, reach = Config.Reach.interiorSpot }) end
                if w then add(list, pos, { kind = 'wardrobe', row = h.id, pos = w, reach = Config.Reach.interiorSpot }) end
            end
        else
            add(list, pos, { kind = 'motelExit', row = C.inside.row, pos = Config.MotelRoom.exit, reach = Config.Reach.exit })
            add(list, pos, { kind = 'stash', row = C.inside.row, pos = Config.MotelRoom.stash, reach = Config.Reach.motelSpot, motel = true })
            add(list, pos, { kind = 'wardrobe', row = C.inside.row, pos = Config.MotelRoom.wardrobe, reach = Config.Reach.motelSpot, motel = true })
        end
    end
    -- motel entrances
    if Config.Motels.enabled and not C.inside then
        for key in pairs(Config.Motels.list) do
            local m = U.motel(key)
            add(list, pos, { kind = 'motel', motel = key, pos = m.entrance, reach = Config.Reach.motelEntrance })
        end
    end
    for _, p in ipairs(Config.LedgerPoints) do
        add(list, pos, { kind = 'ledger', pos = p.coords, reach = Config.Reach.ledger, name = p.name })
    end
    for _, t in ipairs(Config.TownHalls) do
        add(list, pos, { kind = 'hall', pos = t.coords, reach = Config.Reach.townHall })
    end
    return list
end

local function nearest(list, pos)
    local best, bestD
    for _, c in ipairs(list) do
        local d = #(pos - c.pos)
        if d <= c.reach and (not best or d < bestD) then best, bestD = c, d end
    end
    return best
end

-- knocks waiting inside
C.knocks = {}

RegisterNetEvent('pup_realestate:cl_knock', function(houseId, knocker, name)
    if not C.insideHouse(houseId) then return end
    for _, k in ipairs(C.knocks) do
        if k.knocker == knocker then
            k.expires = GetGameTimer() + Config.Timers.knockWindow * 1000
            return
        end
    end
    C.knocks[#C.knocks + 1] = { house = houseId, knocker = knocker, name = name, expires = GetGameTimer() + Config.Timers.knockWindow * 1000 }
end)

local function activeKnock()
    local now = GetGameTimer()
    for i = #C.knocks, 1, -1 do
        local k = C.knocks[i]
        if k.expires < now or not C.insideHouse(k.house) then table.remove(C.knocks, i) end
    end
    return C.knocks[1]
end

local function canPrompt()
    return C.started and C.charid and not C.menuOpen and not C.busy and not C.creating and not C.placing
        and not IsPauseMenuActive()
end

local function doorTitle(c)
    return T('house_title', c.house)
end

local lockHeldUntil = 0

-- what each candidate shows and does
local function drawDoor(c)
    local h = C.houses[c.house]
    if not h then return end
    local g = G.door
    setShown(g.main, not c.extra)
    setLabel(g.main, Locale.open)
    local canLock = h.kind == KIND_REAL and h.owned and C.hasAccess(h) and not Config.Doorlocks.enabled
    local door = c.extra and C.doorBySeq(h, c.seq) or (h.doors or {})[1]
    -- an extra door only ever offers the lock prompt: with nothing to offer, show nothing
    if c.extra and not (canLock and door) then return end
    setShown(g.lock, canLock and door ~= nil)
    if canLock and door then setLabel(g.lock, door.locked and Locale.unlock_door or Locale.lock_door) end
    PromptSetActiveGroupThisFrame(g.id, str(doorTitle(c)), 0, 0, 0, 0)
    if pressed(g.main) then
        C.openDoorMenu(h)
    elseif canLock and door and GetGameTimer() > lockHeldUntil and pressed(g.lock) then
        Send('sv_door', h.id, c.seq)
        UI:DoorSound('unlock')
        -- wait for the key to be let go plus 300 ms so a held key does not toggle back
        lockHeldUntil = math.huge
        CreateThread(function()
            while IsControlPressed(0, Config.Keys.lock) do Wait(50) end
            Wait(300)
            lockHeldUntil = 0
        end)
    end
end

local SINGLE = {
    stash = { title = function() return Locale.inventory end, label = function() return Locale.inventory end },
    wardrobe = { title = function() return Locale.wardrobe end, label = function() return Locale.wardrobe end },
    exit = { title = function(c) return T('house_title', c.row) end, label = function() return Locale.exit end },
    motelExit = { title = function() return Locale.hotel end, label = function() return Locale.exit end },
    motel = { title = function(c) return U.motel(c.motel).name end, label = function() return Locale.open end },
    ledger = { title = function() return Locale.sold_ledger end, label = function() return Locale.sold_ledger end },
    hall = { title = function() return Locale.auction_house end, label = function() return Locale.view_auctions end },
}

local function act(c)
    if c.kind == 'stash' then C.openStash(c.row, c.motel)
    elseif c.kind == 'wardrobe' then C.openWardrobe(c.row)
    elseif c.kind == 'exit' then C.openExitMenu(c.row)
    elseif c.kind == 'motelExit' then C.leaveMotel()
    elseif c.kind == 'motel' then C.openMotelMenu(c.motel)
    elseif c.kind == 'ledger' then C.openSoldLedger()
    elseif c.kind == 'hall' then C.openBoard()
    end
end

local function drawSingle(c)
    local def = SINGLE[c.kind]
    if not def then return end
    local g = G.single
    setLabel(g.main, def.label(c))
    PromptSetActiveGroupThisFrame(g.id, str(def.title(c)), 0, 0, 0, 0)
    if pressed(g.main) then act(c) end
end

local function drawKnock(k)
    local g = G.knock
    PromptSetActiveGroupThisFrame(g.id, str(Locale.door_knocking .. (k.name and (' - ' .. k.name) or '')), 0, 0, 0, 0)
    if pressed(g.allow) then
        Send('sv_allow', k.house, k.knocker)
        table.remove(C.knocks, 1)
    elseif pressed(g.ignore) then
        table.remove(C.knocks, 1)
    end
end

CreateThread(function()
    while not G.knock do Wait(100) end
    local cands, nextScan = {}, 0
    while true do
        local sleep = 500
        if canPrompt() then
            local pos = C.pos()
            local now = GetGameTimer()
            if now >= nextScan then
                cands = scan(pos)
                nextScan = now + 500
            end
            local knock = activeKnock()
            local best = nearest(cands, pos)
            if knock or best then
                sleep = 0
                TriggerEvent('pup:promptYield', 250)
                if knock then
                    drawKnock(knock)
                elseif best.kind == 'door' then
                    drawDoor(best)
                else
                    drawSingle(best)
                end
            elseif #cands > 0 then
                sleep = 100
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, g in pairs(G) do
        for k, pr in pairs(g) do
            if k ~= 'id' then PromptDelete(pr.handle) end
        end
    end
end)
