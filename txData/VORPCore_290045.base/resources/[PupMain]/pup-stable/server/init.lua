-- pup-stable | start-up, character selection, disconnects and shutdown

local function rememberChar(src)
    local ctx = Ctx(src)
    if ctx then PlayerChar[src] = { charid = ctx.charid, identifier = ctx.identifier } end
    return ctx
end

-- entities that outlived a restart are linked again by their tags
local function relink()
    for _, ent in ipairs(GetAllPeds()) do
        local id = U.int(Entity(ent).state.pup_stable_horseID)
        local h = id and Horses[id]
        if h and not h.isDead then
            local owner = SrcOfChar(h.charid)
            LinkHorse(h.id, ent, owner)
            TagHorse(h, ent, owner or 0)
            h.isOut = true
            SaveHorse(h, 'isOut')
            Tracked[h.id] = { ent = ent, last = GetEntityCoords(ent), acc = 0.0, walkMark = h.st.distance, rideSecs = 0,
                minuteStart = os.time(), minuteXP = 0, pool = 0, poolAt = os.time(), poolGains = {} }
        elseif Entity(ent).state.wildhorse then
            DeleteEntity(ent)
        end
    end
    for _, ent in ipairs(GetAllVehicles()) do
        local id = U.int(Entity(ent).state.pup_stable_wagonID)
        local w = id and Wagons[id]
        if w then
            local owner = SrcOfChar(w.charid)
            LinkWagon(w.id, ent, owner)
            TagWagon(w, ent, owner or 0)
            w.isOut = true
            SaveWagon(w, 'isOut')
        end
    end
end

local function sendPermission(src)
    local ctx = Ctx(src)
    if ctx then TriggerClientEvent('pup-stable:colorPermission', src, CanColor(ctx)) end
end

CreateThread(function()
    local ok, err = pcall(CreateSchema)
    if not ok then print('^1[pup-stable]^7 schema step failed: ' .. tostring(err)) end
    local okT = pcall(MySQL.transaction.await, {
        { query = 'UPDATE stable_horses SET isOut = 0', values = {} },
        { query = 'UPDATE stable_wagons SET isOut = 0', values = {} },
        { query = 'UPDATE stable_bought SET equiped_on = 0 WHERE equiped_on = -1', values = {} },
    })
    if not okT then print('^1[pup-stable]^7 could not reset horses/wagons to "in" at start') end
    LoadAll()
    LoadBred()
    relink()
    Ready = true
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        if rememberChar(src) then
            Player(src).state:set('pup_stable_carry', {}, true)
            TriggerClientEvent('pup-stable:refind', src)
        end
    end
    SetTimeout(2000, function()
        for _, sid in ipairs(GetPlayers()) do sendPermission(tonumber(sid)) end
    end)
    print('[pup-stable] ready')
end)

-- every character selection re-runs this, so switching character in one session works
AddEventHandler('vorp:SelectedCharacter', function(source)
    local src = tonumber(source)
    if not src then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 5000
        while not Ready or not Ctx(src) do
            if GetGameTimer() > deadline then return end
            Wait(250)
        end
        local prev = PlayerChar[src]
        local ctx = rememberChar(src)
        -- the previous character's carried bag/lantern go back to storage
        if prev and prev.charid ~= ctx.charid then
            ReturnCarried(src, prev.charid)
            -- the previous character's horse and wagon go back in instead of staying in
            -- the world tagged with this server id (the new character's client would treat them as its own)
            for id, by in pairs(SpawnedBy) do
                local h = Horses[id]
                if by == src and h and h.charid == prev.charid then PutAway(h, nil) end
            end
            for id, by in pairs(WagonSpawnedBy) do
                local w = Wagons[id]
                if by == src and w and w.charid == prev.charid then PutWagonAway(w, nil) end
            end
        end
        Player(src).state:set('pup_stable_carry', {}, true)
        sendPermission(src)
        for _, h in ipairs(HorsesOf(ctx.charid)) do
            local ent = HorseEnt[h.id]
            if ent and DoesEntityExist(ent) then
                Entity(ent).state:set('pup_stable_horseOwner', src, true)
                SpawnedBy[h.id] = src
            end
        end
        for _, w in ipairs(WagonsOf(ctx.charid)) do
            local ent = WagonEnt[w.id]
            if ent and DoesEntityExist(ent) then
                Entity(ent).state:set('pup_stable_wagonOwner', src, true)
                WagonSpawnedBy[w.id] = src
            end
        end
        TriggerClientEvent('pup-stable:refind', src)
        Wait(3000)
        StarterCheck(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local pc = PlayerChar[src]
    PlayerChar[src] = nil
    DropLocks(src)
    DropStamps(src)
    DropWatch(src)
    WildDrop(src)
    LeaveInstance(src)
    if pc then ReturnCarried(src, pc.charid) end
    for id, by in pairs(SpawnedBy) do
        if by == src then
            local h = Horses[id]
            if h then
                local mine = pc and h.charid == pc.charid
                PutAway(h, nil)
                if not mine then
                    local owner = OwnerSrc(h)
                    if owner then Notify(owner, L('stabledOnDrop')) end
                end
            else
                UnlinkHorse(id, true)
            end
        end
    end
    for id, by in pairs(WagonSpawnedBy) do
        if by == src then
            local w = Wagons[id]
            if w then PutWagonAway(w, nil) else UnlinkWagon(id, true) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    SaveAllStats(true)
    LeaveAllInstances()
    WildStop()
end)
