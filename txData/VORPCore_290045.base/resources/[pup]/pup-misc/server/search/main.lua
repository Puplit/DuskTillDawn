-- search | server: every rule, every transfer, the per-victim limit, the
-- new-character shield, the Discord log and the exports. The client only asks.
-- Reads SearchConfig / SearchLocale / SearchRules (shared), SearchServerConfig
-- (config/search/server.lua) and Secrets (server/config.lua).

local CFG <const> = SearchConfig
local L <const> = SearchLocale
local T <const> = CFG.Timings
local INV <const> = exports.vorp_inventory

local Core = nil
do
    local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
    if ok then Core = core end
    if not Core then print('^1[pup-misc/search]^7 vorp_core GetCore() failed; notifications fall back to chat') end
end

local function dbg(...)
    if CFG.General.debug then print('[pup-misc/search]', ...) end
end

local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[pup-misc/search]^7 %s'):format(msg))
end

local function notify(src, text, ms)
    if not text then return end
    if Core and Core.NotifyObjective then
        Core.NotifyObjective(src, text, ms or CFG.Notify.normalMs)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'Search', text } })
    end
end

local function now() return GetGameTimer() end

local function money(v)
    v = tonumber(v) or 0
    if v == math.floor(v) then return ('%d'):format(v) end
    return ('%.2f'):format(v)
end

-- ------------------------------------------------------------------ players

local function charOf(src)
    if not Core or not src then return nil end
    local ok, user = pcall(Core.getUser, src)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    if not ch or not ch.charIdentifier then return nil end
    return ch
end

local function online(src)
    return src and GetPlayerName(src) ~= nil
end

local function superSet()
    local set = {}
    local v = SearchServerConfig and SearchServerConfig.SuperBypass
    if type(v) == 'string' then v = { v } end
    if type(v) == 'table' then
        for _, id in ipairs(v) do
            if type(id) == 'string' and id ~= '' then set[id:lower()] = true end
        end
    end
    return set
end

local function isSuper(src)
    local set = superSet()
    if not next(set) then return false end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if set[tostring(id):lower()] then return true end
    end
    return false
end

local function pedOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return ped
end

local function zeroVec(v)
    return v.x == 0.0 and v.y == 0.0 and v.z == 0.0
end

-- reach rule: unknown position passes, missing ped fails, 0 turns it off
local function inReach(a, b)
    local reach = tonumber(CFG.Limits.reach) or 0
    if reach <= 0 then return true end
    local pa, pb = pedOf(a), pedOf(b)
    if not pa or not pb then return false end
    local ca, cb = GetEntityCoords(pa), GetEntityCoords(pb)
    if zeroVec(ca) or zeroVec(cb) then return true end
    return #(ca - cb) <= reach
end

local function inSisikaNow(src)
    local ped = pedOf(src)
    if not ped then return false end
    local c = GetEntityCoords(ped)
    return SearchInSisika(c.x, c.y, c.z)
end

-- ------------------------------------------------------------------ rate limit

local lastHit = {}
local function limited(src, key)
    local gap = CFG.RateLimit[key] or 500
    local per = lastHit[src]
    if not per then
        per = {}
        lastHit[src] = per
    end
    local t = now()
    if per[key] and t - per[key] < gap then return true end
    per[key] = t
    return false
end

-- ------------------------------------------------------------------ rules

local function lawPriv(src, job)
    if not SearchIsLawJob(job) then return false end
    if CFG.Law.requireDutyForAll then return SearchIsOnDuty(src, 'Law') end
    return true
end

local function bypassOnDuty(src, job)
    return SearchJobInList(job, CFG.Limits.bypassJobs) and SearchIsOnDuty(src, 'Law')
end

local function limitExempt(src, job, super)
    return super or bypassOnDuty(src, job)
end

local function targetProtected(target, tJob)
    if not CFG.Duty.enabled then return false end
    if not SearchRules.protectedSet[tJob] then return false end
    local category = 'Law'
    if CFG.Duty.doctorViaMedical and SearchJobInList(tJob, CFG.Duty.medicalJobs) then category = 'Medical' end
    return SearchIsOnDuty(target, category, tJob)
end

local function cashAllowed(src, job, super)
    if super then return true end
    local law = lawPriv(src, job)
    if CFG.Law.cashOnly and not law then return false end
    return CFG.Steal.cash or (CFG.Law.cashBypass and law)
end

local function itemsAllowed(src, job, super)
    if super then return true end
    return CFG.Steal.items or (CFG.Law.itemBypass and lawPriv(src, job))
end

local function weaponsAllowed(src, job, super)
    if super then return true end
    return CFG.Steal.weapons or (CFG.Law.weaponBypass and lawPriv(src, job))
end

local function itemBlocked(name)
    if SearchRules.itemSet[name] then return true end
    for _, prefix in ipairs(SearchRules.prefixes) do
        if name:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function weaponBlocked(name)
    return SearchRules.weaponSet[tostring(name):upper()] == true
end

-- new-character shield: true when the character is younger than the shield.
-- A missing creation time counts as not protected.
local function shielded(charId)
    local mins = tonumber(SearchRules.shieldMinutes) or 0
    if mins <= 0 then return false end
    local ok, ts = pcall(function()
        return exports.oxmysql:scalar_async(
            'SELECT UNIX_TIMESTAMP(character_created) FROM characters WHERE charidentifier = ?', { charId })
    end)
    if not ok then
        warnOnce('shieldDb', 'could not read character_created: ' .. tostring(ts))
        return false
    end
    ts = tonumber(ts)
    if not ts then return false end
    return os.time() - ts < mins * 60
end

-- ------------------------------------------------------------------ per-victim limit

local counters = {} -- [victim charId] = { count, start } or { times = { ... } }

local function limitHit(charId)
    local max = tonumber(SearchRules.maxStacks) or 0
    local window = (tonumber(SearchRules.windowMinutes) or 0) * 60
    local t = os.time()
    local c = counters[charId]
    if not c then return max <= 0 end
    if CFG.Limits.slidingWindow then
        local kept = {}
        for _, at in ipairs(c.times or {}) do
            if t - at < window then kept[#kept + 1] = at end
        end
        c.times = kept
        return #kept >= max
    end
    if not c.start or t - c.start >= window then
        counters[charId] = nil
        return max <= 0
    end
    return (c.count or 0) >= max
end

local function countTheft(charId)
    local t = os.time()
    if CFG.Limits.slidingWindow then
        local c = counters[charId] or { times = {} }
        c.times = c.times or {}
        c.times[#c.times + 1] = t
        counters[charId] = c
        return
    end
    local c = counters[charId]
    if not c or not c.start then
        c = { count = 0, start = t }
        counters[charId] = c
    end
    c.count = (c.count or 0) + 1
end

-- gives back a slot taken by countTheft when the move then failed
local function uncountTheft(charId)
    local c = counters[charId]
    if not c then return end
    if CFG.Limits.slidingWindow then
        if c.times and #c.times > 0 then c.times[#c.times] = nil end
        return
    end
    c.count = math.max(0, (c.count or 0) - 1)
end

-- ------------------------------------------------------------------ sessions

local sessions = {}   -- [searcher] = { target, targetChar }
local openedAt = {}   -- [target] = GetGameTimer() when a search on them opened
local opening = {}    -- [searcher] = true while an open request is being decided
local transferBusy = {}

local function validSession(src)
    local s = sessions[src]
    if not s then return nil end
    if not online(s.target) then return nil end
    if not charOf(src) then return nil end
    local tChar = charOf(s.target)
    if not tChar or tChar.charIdentifier ~= s.targetChar then return nil end
    if not inReach(src, s.target) then return nil end
    return s
end

local function endSession(src, clearLock)
    local s = sessions[src]
    sessions[src] = nil
    if s and clearLock then openedAt[s.target] = nil end
end

-- tell a searcher their search is over and shut the panel
local function kickSearcher(src)
    endSession(src, true)
    TriggerClientEvent('vorp_inventory:CloseInv', src)
    TriggerClientEvent('pup-search:stopanime', src)
end

local function locked(target)
    local at = openedAt[target]
    return at ~= nil and now() - at < (tonumber(CFG.Limits.lockSeconds) or 5) * 1000
end

local function otherSearcherOn(target, src)
    for searcher, s in pairs(sessions) do
        if searcher ~= src and s.target == target and validSession(searcher) then return true end
    end
    return false
end

-- ------------------------------------------------------------------ panel

local function victimLists(target)
    local okI, items = pcall(function() return INV:getUserInventoryItems(target) end)
    local okW, weapons = pcall(function() return INV:getUserInventoryWeapons(target) end)
    return (okI and type(items) == 'table') and items or {}, (okW and type(weapons) == 'table') and weapons or {}
end

local function pushPanel(src, target)
    local items, weapons = victimLists(target)
    local list = {}
    for _, row in ipairs(items) do list[#list + 1] = row end
    for _, w in ipairs(weapons) do
        local row = {}
        for k, v in pairs(w) do row[k] = v end
        row.type, row.count, row.limit = 'item_weapon', 1, 1
        list[#list + 1] = row
    end
    TriggerClientEvent('vorp_inventory:ReloadstealInventory', src,
        json.encode({ itemList = list, action = 'setSecondInventoryItems' }))
end

-- ------------------------------------------------------------------ discord

local function discordMention(src)
    local id = GetPlayerIdentifierByType(src, 'discord')
    if not id then return 'N/A' end
    return ('<@%s>'):format((id:gsub('^discord:', '')))
end

local function personBlock(src, ch)
    return ('**Name:** %s %s\n**Discord:** %s\n**Character ID:** %s\n**Steam Name:** %s\n**Steam ID:** %s'):format(
        tostring(ch and ch.firstname or '?'), tostring(ch and ch.lastname or ''),
        discordMention(src),
        tostring(ch and ch.charIdentifier or '?'),
        tostring(GetPlayerName(src) or '?'),
        tostring(GetPlayerIdentifierByType(src, 'steam') or 'N/A'))
end

local function webhookUrl()
    local s = Secrets and Secrets.Webhooks and Secrets.Webhooks.search
    local url = s and s.admin
    if type(url) ~= 'string' or url == '' then return nil end
    return url
end

local function sendLog(title, colour, robber, rChar, victim, vChar, fieldName, fieldValue)
    if not CFG.Webhook.enabled then return end
    local url = webhookUrl()
    if not url then return end
    local payload = {
        username = CFG.Webhook.username,
        embeds = { {
            title = title,
            color = colour,
            fields = {
                { name = 'Robber:', value = personBlock(robber, rChar), inline = true },
                { name = 'Victim:', value = personBlock(victim, vChar), inline = true },
                { name = fieldName, value = fieldValue, inline = false },
            },
            footer = { text = ('%s • %s'):format(CFG.Webhook.footer, os.date('%d/%m/%Y %H:%M:%S')) },
        } },
    }
    if CFG.Webhook.avatar and CFG.Webhook.avatar ~= '' then payload.avatar_url = CFG.Webhook.avatar end
    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- ------------------------------------------------------------------ target state

local stateSeq = 0
local pendingState = {} -- [nonce] = { target, p }

local function targetStateOk(target)
    if not CFG.VerifyTarget.enabled then return true end
    stateSeq = stateSeq + 1
    local nonce = stateSeq
    local p = promise.new()
    pendingState[nonce] = { target = target, p = p }
    TriggerClientEvent('pup-misc:search:stateQuery', target, nonce)
    SetTimeout(tonumber(CFG.VerifyTarget.timeoutMs) or 1500, function()
        local e = pendingState[nonce]
        if e then
            pendingState[nonce] = nil
            e.p:resolve(false)
        end
    end)
    local r = Citizen.Await(p)
    if type(r) ~= 'table' then return false end
    if r.dead then return SearchRules.deadSearch == true end
    if r.hogtied then return CFG.Targets.hogtied == true end
    if r.cuffed then return CFG.Targets.cuffed == true end
    return false
end

RegisterNetEvent('pup-misc:search:stateReply', function(nonce, hogtied, cuffed, dead)
    local src = source
    local e = pendingState[tonumber(nonce) or -1]
    if not e or e.target ~= src then return end
    pendingState[tonumber(nonce)] = nil
    e.p:resolve({ hogtied = hogtied == true, cuffed = cuffed == true, dead = dead == true })
end)

-- ------------------------------------------------------------------ job

RegisterNetEvent('pup-search:getjob', function()
    local src = source
    if limited(src, 'getjob') then return end
    local ch = charOf(src)
    if not ch then
        Wait(500)
        ch = charOf(src)
        if not ch then return end
    end
    TriggerClientEvent('pup-search:recjob', src, ch.job, isSuper(src))
end)

-- push the new job instead of waiting for the client to ask
AddEventHandler('vorp:playerJobChange', function(src, newJob)
    src = tonumber(src)
    if not src or not online(src) then return end
    TriggerClientEvent('pup-search:recjob', src, newJob, isSuper(src))
end)

-- ------------------------------------------------------------------ opening a search

-- steps that must still hold after any wait: loaded, reach, busy, locks
local function liveChecks(src, target)
    local sChar, tChar = charOf(src), charOf(target)
    if not sChar or not tChar then return false end
    if not inReach(src, target) then return false end
    if validSession(target) then return false, L.targetBusy end
    if locked(src) then return false, L.beingSearched end
    if locked(target) then return false, L.beingSearched end
    if CFG.Limits.exclusiveVictim and otherSearcherOn(target, src) then return false, L.beingSearched end
    return true, nil, sChar, tChar
end

local function decideOpen(src, target)
    if not target or target <= 0 or target ~= math.floor(target) or target == src then return false end
    if not online(target) then return false end

    local sChar, tChar = charOf(src), charOf(target)
    if not sChar or not tChar then return false end
    if not inReach(src, target) then return false end

    local super = isSuper(src)
    local job = sChar.job
    if not super and not lawPriv(src, job) then
        if CFG.Sisika.block and inSisikaNow(src) then return false, L.cantSearchJob end
        if CFG.Law.searchOnly then return false, L.cantSearchJob end
    end

    local ok, msg = liveChecks(src, target)
    if not ok then return false, msg end

    if not super and targetProtected(target, tChar.job) then return false, L.cantSearchJob, CFG.Notify.longMs end

    local bypass = super or bypassOnDuty(src, job)
    if not bypass and not lawPriv(src, job) and shielded(sChar.charIdentifier) then
        return false, L.newPlayer, CFG.Notify.longMs
    end
    if not bypass and not SearchIsLawJob(tChar.job) and shielded(tChar.charIdentifier) then
        return false, L.newPlayer, CFG.Notify.longMs
    end

    local tCharId = tChar.charIdentifier
    if not tCharId then return false end

    if not targetStateOk(target) then return false end

    -- everything above may have waited (database, target's answer): look again
    local ok2, msg2, _, tNow = liveChecks(src, target)
    if not ok2 then return false, msg2 end
    if tNow.charIdentifier ~= tCharId then return false end
    if not super and targetProtected(target, tNow.job) then return false, L.cantSearchJob, CFG.Notify.longMs end

    openedAt[target] = now()
    sessions[src] = { target = target, targetChar = tCharId }
    return true, tNow
end

RegisterNetEvent('pup-search:getinfo', function(targetId)
    local src = source
    if limited(src, 'getinfo') or opening[src] then return end
    opening[src] = true
    local ok, allowed, a, b = pcall(decideOpen, src, tonumber(targetId))
    opening[src] = nil

    if not ok then
        print(('^1[pup-misc/search]^7 open failed: %s'):format(tostring(allowed)))
        TriggerClientEvent('pup-misc:search:refused', src)
        return
    end
    if not allowed then
        if a then notify(src, a, b) end
        TriggerClientEvent('pup-misc:search:refused', src)
        return
    end

    local tChar = a
    local target = sessions[src].target
    TriggerClientEvent('pup-search:recinfo', src, {
        job = tChar.job,
        charid = tChar.charIdentifier,
        cash = tonumber(tChar.money) or 0,
        gold = tonumber(tChar.gold) or 0,
        serverId = target,
    })
    dbg(('%d opened a search on %d'):format(src, target))
end)

RegisterNetEvent('pup-search:endsearch', function()
    endSession(source, true)
end)

-- ------------------------------------------------------------------ cash

RegisterNetEvent('pup-search:takecash', function(targetId, amount)
    local src = source
    if limited(src, 'takecash') then return end
    amount, targetId = tonumber(amount), tonumber(targetId)
    if not amount or amount ~= amount or amount == math.huge or amount <= 0 then return end

    local s = validSession(src)
    if not s or s.target ~= targetId then return end
    local target = s.target
    local sChar, tChar = charOf(src), charOf(target)
    if not sChar or not tChar then return end

    local super = isSuper(src)
    if not cashAllowed(src, sChar.job, super) then return end

    local have = tonumber(tChar.money) or 0
    if have <= 0 then return end
    local take
    if CFG.Cash.takeAllIncludesCents and amount >= have then
        -- never more than the victim holds, even after float rounding
        take = math.min(math.floor(have * 100 + 0.0001) / 100, have)
    else
        take = math.floor(amount)
        if take < 1 then return end
        take = math.min(take, math.floor(have))
    end
    if take <= 0 then return end

    -- robber first, then the victim (no wait in between)
    sChar.addCurrency(0, take)
    tChar.removeCurrency(0, take)

    notify(src, L.cashGot:format(money(take)))
    notify(target, L.cashLost:format(money(take)))
    sendLog('CASH ROBBERY', CFG.Webhook.colours.cash, src, sChar, target, tChar,
        'Amount Stolen:', '$' .. money(take))
end)

-- ------------------------------------------------------------------ the steal panel

RegisterNetEvent('pup-search:ReloadstealInventory', function(targetId)
    local src = source
    if limited(src, 'reload') then return end
    local s = validSession(src)
    if not s or s.target ~= tonumber(targetId) then return end
    local sChar = charOf(src)
    if not sChar then return end
    local super = isSuper(src)
    if not itemsAllowed(src, sChar.job, super) and not weaponsAllowed(src, sChar.job, super) then return end
    pushPanel(src, s.target)
    TriggerClientEvent('vorp_inventory:OpenstealInventory', src, L.panelTitle, s.targetChar)
end)

local function findRow(list, id)
    for _, row in ipairs(list) do
        if tonumber(row.id) == id then return row end
    end
    return nil
end

local function canCarryItem(src, name, qty)
    local ok, n = pcall(function() return INV:canCarryAmount(src, name, qty) end)
    if ok and tonumber(n) then return tonumber(n) >= qty end
    warnOnce('canCarryAmount', 'vorp_inventory canCarryAmount unavailable; using canCarryItems + canCarryItem')
    local ok1, total = pcall(function() return INV:canCarryItems(src, qty) end)
    local ok2, one = pcall(function() return INV:canCarryItem(src, name, qty) end)
    return ok1 and total == true and ok2 and one == true
end

local function noteBox(name, from, to, label)
    if type(PupStorageBoxNoteTransfer) ~= 'function' then return end
    local ok, err = pcall(PupStorageBoxNoteTransfer, name, from, to, label)
    if not ok then warnOnce('boxHook', 'storagebox hand-off failed: ' .. tostring(err)) end
end

local function takeWeapon(src, s, sChar, tChar, super, id)
    local target = s.target
    if not weaponsAllowed(src, sChar.job, super) then return notify(src, L.cantWeapons) end
    local _, weapons = victimLists(target)
    local w = findRow(weapons, id)
    if not w then return notify(src, L.stealFailed) end
    local name = tostring(w.name or '')
    local label = tostring(w.custom_label or w.label or name)

    if not super and weaponBlocked(name) then return notify(src, L.blacklisted) end
    -- weapons always need on-duty law, whatever Steal.weapons says
    if not super and not (SearchIsLawJob(sChar.job) and SearchIsOnDuty(src, 'Law')) then
        return notify(src, L.cantWeapons)
    end
    local exempt = limitExempt(src, sChar.job, super)
    if not exempt and limitHit(tChar.charIdentifier) then return notify(src, L.limitReached) end

    local okC, can = pcall(function() return INV:canCarryWeapons(src, 1, nil, name) end)
    if not okC or can ~= true then return notify(src, L.cantCarry) end

    if not validSession(src) then return end

    -- one path: giveWeapon moves ownership and clears the victim's
    -- client itself; only a confirmed move is counted and logged.
    local okG, given = pcall(function() return INV:giveWeapon(src, id, target) end)
    if not okG or given ~= true then return notify(src, L.carryFailed) end

    if not exempt then countTheft(tChar.charIdentifier) end
    TriggerClientEvent('vorp_inventory:RefreshInventory', target)
    Wait(T.afterWeaponMs)
    notify(src, L.weaponGot:format(label))
    notify(target, L.weaponLost:format(label))
    sendLog('WEAPON ROBBERY', CFG.Webhook.colours.weapon, src, sChar, target, tChar, 'Weapon:', label)
end

local function takeItem(src, s, sChar, tChar, super, id, qty)
    local target = s.target
    if not itemsAllowed(src, sChar.job, super) then return notify(src, L.stealFailed) end
    local items = victimLists(target)
    local row = findRow(items, id)
    if not row then return notify(src, L.stealFailed) end
    local held = tonumber(row.count) or 0
    if not qty or qty ~= math.floor(qty) or qty < 1 or qty > held then return notify(src, L.stealFailed) end

    local name = tostring(row.name or '')
    local label = tostring(row.label or name)
    local metadata = type(row.metadata) == 'table' and row.metadata or {}

    local exempt = limitExempt(src, sChar.job, super)
    if not exempt and limitHit(tChar.charIdentifier) then return notify(src, L.limitReached) end
    if not super and itemBlocked(name) then return notify(src, L.blacklisted) end
    if not canCarryItem(src, name, qty) then return notify(src, L.cantCarry) end

    if not validSession(src) then return end

    -- the slot is taken BEFORE the move: addItem waits on the database, and a
    -- second robber on the same victim must not slip past the limit meanwhile
    if not exempt then countTheft(tChar.charIdentifier) end

    noteBox(name, target, src, 'Box Robbed from Player')
    local okR, removed = pcall(function() return INV:subItemID(target, id, nil, nil, qty) end)
    if not okR or removed ~= true then
        if not exempt then uncountTheft(tChar.charIdentifier) end
        return notify(src, L.carryFailed)
    end

    local okA, added = pcall(function() return INV:addItem(src, name, qty, metadata) end)
    if not okA or added ~= true then
        pcall(function() return INV:addItem(target, name, qty, metadata) end)
        noteBox(name, target, target, 'Box Robbery Failed (returned)')
        if not exempt then uncountTheft(tChar.charIdentifier) end
        return notify(src, L.carryFailed)
    end

    TriggerClientEvent('vorp_inventory:RefreshInventory', target)
    Wait(T.afterItemMs)
    notify(src, L.itemGot:format(qty, label))
    notify(target, L.itemLost:format(qty, label))
    sendLog('ITEM ROBBERY', CFG.Webhook.colours.item, src, sChar, target, tChar,
        'Item:', ('%s x**%d**'):format(label, qty))
end

local function doTransfer(src, raw, entry)
    local s = validSession(src)
    if not s then return end

    -- a drag onto the victim's panel is the robber's own item, never theft
    if entry == 'move' then return notify(src, L.cantGive) end

    if type(raw) ~= 'string' or #raw > 16384 then return end
    local okJ, data = pcall(json.decode, raw)
    if not okJ or type(data) ~= 'table' or type(data.item) ~= 'table' then return end
    local id = tonumber(data.item.id)
    if not id then return notify(src, L.stealFailed) end

    local sChar, tChar = charOf(src), charOf(s.target)
    if not sChar or not tChar then return end
    local super = isSuper(src)

    -- the protected-job re-check runs for every take
    if not super and targetProtected(s.target, tChar.job) then
        return notify(src, L.cantSearchJob, CFG.Notify.longMs)
    end

    if data.type == 'item_weapon' then
        takeWeapon(src, s, sChar, tChar, super, id)
    else
        takeItem(src, s, sChar, tChar, super, id, tonumber(data.number))
    end
end

local function transfer(src, raw, entry)
    -- a request that arrives mid-transfer is dropped, but the
    -- running one always refreshes the panel when it finishes, which releases it
    if transferBusy[src] then return end
    if limited(src, 'transfer') then
        local s = validSession(src)
        if s then pushPanel(src, s.target) end
        return
    end
    transferBusy[src] = true
    local ok, err = pcall(doTransfer, src, raw, entry)
    transferBusy[src] = nil
    if not ok then print(('^1[pup-misc/search]^7 transfer failed: %s'):format(tostring(err))) end

    local s = validSession(src)
    if s then
        pushPanel(src, s.target)
    elseif sessions[src] then
        -- the session died (out of reach, logged off, new character)
        kickSearcher(src)
    else
        TriggerClientEvent('vorp_inventory:CloseInv', src)
    end
end

RegisterNetEvent('pup-search:TakeFromsteal', function(raw)
    transfer(source, raw, 'take')
end)

RegisterNetEvent('pup-search:MoveTosteal', function(raw)
    transfer(source, raw, 'move')
end)

-- ------------------------------------------------------------------ clean-up

local function dropTargetsOf(src)
    for searcher, s in pairs(sessions) do
        if s.target == src then kickSearcher(searcher) end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    endSession(src, true)
    dropTargetsOf(src)
    openedAt[src], opening[src], transferBusy[src], lastHit[src] = nil, nil, nil, nil
    for nonce, e in pairs(pendingState) do
        if e.target == src then
            pendingState[nonce] = nil
            e.p:resolve(false)
        end
    end
end)

AddEventHandler('vorp:SelectedCharacter', function(src, character)
    src = tonumber(src)
    if not src then return end
    if sessions[src] then endSession(src, true) end
    dropTargetsOf(src)
    openedAt[src] = nil

    local charId = type(character) == 'table' and (character.charIdentifier or character.charidentifier) or nil
    if not charId then
        local ch = charOf(src)
        charId = ch and ch.charIdentifier
    end
    if not charId then return end
    local ok, err = pcall(function()
        exports.oxmysql:update_async(
            'UPDATE characters SET character_created = CURRENT_TIMESTAMP WHERE charidentifier = ? AND character_created IS NULL',
            { charId })
    end)
    if not ok then warnOnce('createdStamp', 'could not stamp character_created: ' .. tostring(err)) end
end)

-- ------------------------------------------------------------------ database column

CreateThread(function()
    Wait(CFG.Database.checkColumnDelayMs)
    local ok, err = pcall(function()
        local n = exports.oxmysql:scalar_async([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'character_created'
        ]], {})
        if (tonumber(n) or 0) > 0 then return end
        exports.oxmysql:update_async(
            'ALTER TABLE characters ADD COLUMN character_created TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP', {})
        print('^3[pup-misc/search]^7 added characters.character_created')
        -- existing characters are not new
        if CFG.Database.backfillOnCreate then
            exports.oxmysql:update_async('UPDATE characters SET character_created = ?', { CFG.Database.backfillDate })
        end
    end)
    if not ok then print(('^1[pup-misc/search]^7 character_created check failed: %s'):format(tostring(err))) end
end)

-- ------------------------------------------------------------------ purge

local function pollPurge()
    local res = CFG.Duty.resources.events
    if GetResourceState(res) ~= 'started' then
        SearchSetPurge(false)
        return
    end
    local ok, live = pcall(function() return exports[res]:IsLive(CFG.Purge.eventKey) end)
    SearchSetPurge(ok and live == true)
end

AddEventHandler('pup-events:server:state', function(key, on)
    if key ~= CFG.Purge.eventKey then return end
    SearchSetPurge(on == true)
end)

CreateThread(function()
    Wait(T.purgeFirstPollMs)
    while true do
        pollPurge()
        Wait(T.purgePollMs)
    end
end)

-- ------------------------------------------------------------------ exports

-- pup-mdt evidence locker: who is this player searching right now
exports('GetSearchTarget', function(searcher)
    local s = validSession(tonumber(searcher))
    return s and s.target or nil
end)

-- pup-mdt: redraw the searcher's panel after a seizure (no session check)
exports('RefreshSearchView', function(searcher, target)
    searcher, target = tonumber(searcher), tonumber(target)
    if not online(searcher) or not online(target) then return end
    pushPanel(searcher, target)
end)

-- pup-events admin panel
exports('PurgeSearchStatus', function()
    return {
        applied = SearchPurgeActive(),
        isDead = SearchRules.deadSearch == true,
        maxItems = SearchRules.maxStacks,
        shieldMins = SearchRules.shieldMinutes,
        protectedJobs = SearchRules.protectedCount,
        blacklisted = SearchRules.itemCount,
        cooldownMins = SearchRules.windowMinutes,
    }
end)

-- additional exports (not used by other pup resources)
exports('getPlayTime', function() return 0 end)
exports('getHWIDCount', function() return 0 end)
