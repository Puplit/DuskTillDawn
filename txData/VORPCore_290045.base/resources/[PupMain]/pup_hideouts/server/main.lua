-- pup_hideouts | start-up, the online map, disconnects, character switches, scheduled restarts

local function migrate()
    local cols = MySQL.query.await([[
        SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'underground']], {}) or {}
    local have = {}
    for _, r in ipairs(cols) do have[r.c] = true end
    if not have.webhook then
        MySQL.query.await('ALTER TABLE `underground` ADD COLUMN `webhook` varchar(255) DEFAULT NULL', {})
    end
    if not have.raidopenedat then
        MySQL.query.await('ALTER TABLE `underground` ADD COLUMN `raidopenedat` int(11) DEFAULT 0', {})
    end
    -- the last world position before entering an interior (shared with pup_realestate)
    local ch = MySQL.query.await([[
        SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'moonshineenty']], {}) or {}
    if #ch == 0 then
        MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `moonshineenty` longtext DEFAULT '{}'", {})
    end
end

local function trackOnline(src)
    local cid = HX.charId(src)
    if cid then HX.online[src] = cid else HX.online[src] = nil end
    HX.buckets[src] = GetPlayerRoutingBucket(src)
    return cid
end

local function rebuildOnline()
    HX.online = {}
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        if s and HX.char(s) then trackOnline(s) end
    end
end

CreateThread(function()
    local ok, err = pcall(migrate)
    if not ok then print('^1[pup_hideouts]^7 migration check failed: ' .. tostring(err)) end
    HX.reloadAll()
    HX.Reloc.recover()
    HX.Raids.restoreLoot()
    HX.ready = true
    HX.Raids.startup()
    HX.salesCheck()
    -- players already in game when the resource (re)started
    SetTimeout(3000, function()
        rebuildOnline()
        for src, cid in pairs(HX.online) do
            TriggerClientEvent('pup_hideouts:hello', src, cid)
            HX.pushAllTo(src)
        end
        HX.blips()
    end)
end)

-- a character was picked (first join or a switch)
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    local before = HX.online[src]
    -- whatever the previous character was holding ends with it
    if before then
        for id, holder in pairs(HX.menuLock) do if holder == src then HX.menuLock[id] = nil end end
        for id, holder in pairs(HX.stashLock) do if holder == src then HX.stashLock[id] = nil end end
        HX.salesSwitch(src)
        -- a question, a knock or an invitation was meant for the character who is gone: an
        -- answer from the new one must not make it a co-owner or let it in
        HX.consentDropped(src)
        HX.knockDropped(src)
        HX.invites[src] = nil
    end
    SetTimeout(1000, function()
        if not GetPlayerName(src) then return end
        local cid = trackOnline(src)
        if not cid or not HX.ready then return end
        TriggerClientEvent('pup_hideouts:hello', src, cid)
        HX.pushAllTo(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not src then return end
    HX.Reloc.dropped(src)
    HX.Bookie.dropped(src)
    HX.knockDropped(src)
    HX.consentDropped(src)
    HX.salesDropped(src)
    HX.Raids.dropped(src)
    HX.Raids.teardownDropped(src)
    HX.Wagons.dropped(src)
    HX.invites[src] = nil
    for _, occ in pairs(HX.occupants) do occ[src] = nil end
    for id, holder in pairs(HX.menuLock) do if holder == src then HX.menuLock[id] = nil end end
    for id, holder in pairs(HX.stashLock) do if holder == src then HX.stashLock[id] = nil end end
    HX.online[src] = nil
    HX.buckets[src] = nil
    HX.forgetRate(src)
end)

-- scheduled restarts: refund tables and put everyone outside, once per configured minute
local firedMinute = nil
CreateThread(function()
    while true do
        Wait(20000)
        if HX.ready then
            local hhmm = tonumber(os.date('%H%M'))
            if hhmm ~= firedMinute and U.inList(Config.RestartTimes, hhmm) then
                firedMinute = hhmm
                HX.Bookie.refundEverything()
                for _, h in pairs(HX.hideouts) do HX.forceOut(h) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- pending relocations are already in KVP and are refunded on the next start;
    -- open bets live in memory only, so give them back now
    HX.stopping = true
    for id in pairs(HX.hideouts) do HX.Bookie.refundAll(id, 'fight_interrupted2') end
end)
