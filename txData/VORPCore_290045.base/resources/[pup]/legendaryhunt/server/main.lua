-- legendaryhunt | server core
-- Shared helpers and state for server/hunt.lua, server/shop.lua and server/log.lua.
-- nothing here trusts a client: handlers use the sender's own id and re-read the character after every inventory call

Srv = {}

local RES <const> = GetCurrentResourceName()

local Core
do
    local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
    if ok then Core = core else print(('^1[%s]^7 vorp_core GetCore failed: %s'):format(RES, tostring(core))) end
end

local warned = {}
function Srv.warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(RES, msg))
end

-- the sender is a real, connected player
function Srv.valid(src)
    return type(src) == 'number' and src > 0 and GetPlayerName(src) ~= nil
end

-- the active character, or nil when none is selected
function Srv.character(src)
    if not Core or not Srv.valid(src) then return nil end
    local ok, user = pcall(Core.getUser, src)
    if not ok or type(user) ~= 'table' then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' or char.charIdentifier == nil then return nil end
    return char
end

function Srv.charId(src)
    local c = Srv.character(src)
    return c and c.charIdentifier or nil
end

function Srv.tip(src, text)
    TriggerClientEvent('vorp:TipBottom', src, tostring(text), 3000)
end

function Srv.tipRight(src, text, ms)
    TriggerClientEvent('vorp:TipRight', src, tostring(text), ms or 3000)
end

-- per player, per action rate limit
local lastCall = {}
function Srv.allow(src, action, gapMs)
    local now = GetGameTimer()
    local row = lastCall[src]
    if not row then row = {}; lastCall[src] = row end
    local last = row[action]
    if last and now - last < gapMs then return false end
    row[action] = now
    return true
end

-- vorp_inventory calls, wrapped so a missing or failing export reads as "no"
local function inv(name, ...)
    local args = table.pack(...)
    local ok, result = pcall(function()
        local api = exports.vorp_inventory
        return api[name](api, table.unpack(args, 1, args.n))
    end)
    if not ok then
        Srv.warnOnce('inv_' .. name, ('vorp_inventory export %s failed: %s'):format(name, tostring(result)))
        return nil
    end
    return result
end

function Srv.subItem(src, item, amount)
    return inv('subItem', src, item, amount) == true
end

-- vorp_inventory's addItem does not check limits or weight, so ask canCarryItem first
function Srv.giveItem(src, item, amount)
    if inv('canCarryItem', src, item, amount) ~= true then return false end
    return inv('addItem', src, item, amount) == true
end

function Srv.canCarry(src, item, amount)
    return inv('canCarryItem', src, item, amount) == true
end

-- State (server memory; a restart clears all but the owed traps)
Srv.Out       = {} -- [src] = { charId, busy } a trap the server took from this hunter's satchel
Srv.UseGrant  = {} -- [src] = game timer when the trap item was used (single use)
Srv.Approval  = {} -- [src] = { id, charId, at } the one legendary this hunter may start
Srv.AnimalCd  = {} -- [legendary id] = game timer when its cooldown ends
Srv.HunterCd  = {} -- [charIdentifier] = game timer when this character's cooldown ends
Srv.LastLog   = {} -- [src] = game timer of the last log line
Srv.Owed      = {} -- [charIdentifier] = traps owed back (kept in resource KVP across restarts)

-- owed traps: a trap out when its hunter left, switched character or the resource stopped is handed back next time
local KVP_PREFIX <const> = 'owed:'

local function setOwed(charId, n)
    charId = tostring(charId)
    n = math.max(0, math.floor(tonumber(n) or 0))
    Srv.Owed[charId] = n > 0 and n or nil
    if n > 0 then SetResourceKvpInt(KVP_PREFIX .. charId, n) else DeleteResourceKvp(KVP_PREFIX .. charId) end
end

function Srv.owe(charId, add)
    if charId == nil then return end
    setOwed(charId, (Srv.Owed[tostring(charId)] or 0) + (add or 1))
end

do
    local handle = StartFindKvp(KVP_PREFIX)
    if handle and handle ~= -1 then
        while true do
            local key = FindKvp(handle)
            if not key then break end
            local n = GetResourceKvpInt(key)
            if n and n > 0 then Srv.Owed[key:sub(#KVP_PREFIX + 1)] = n end
        end
        EndFindKvp(handle)
    end
end

-- the trap that was out for src becomes owed to the character that took it
function Srv.releaseOut(src)
    local out = Srv.Out[src]
    if not out then return end
    Srv.Out[src] = nil
    -- a take still waiting on vorp_inventory settles its own debt (server/hunt.lua)
    if out.busy then out.cancelled = true return end
    Srv.owe(out.charId, 1)
end

local delivering = {}
function Srv.deliverOwed(src)
    local cid = Srv.charId(src)
    if cid == nil then return end
    local key = tostring(cid)
    if delivering[key] or not Srv.Owed[key] then return end
    delivering[key] = true
    while (Srv.Owed[key] or 0) > 0 do
        if not Srv.giveItem(src, Config.Items.trap, 1) then break end
        setOwed(key, (Srv.Owed[key] or 1) - 1)
        Srv.tip(src, Config.Text.trapOwed)
        -- re-check after the inventory await: a switch stops further deliveries
        local now = Srv.charId(src)
        if now == nil or tostring(now) ~= key then break end
    end
    delivering[key] = nil
end

-- retry owed traps for everyone online (satchel full, inventory not loaded yet, just restarted)
CreateThread(function()
    Wait(10000)
    while true do
        if next(Srv.Owed) then
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                local cid = src and Srv.charId(src)
                if cid ~= nil and Srv.Owed[tostring(cid)] then Srv.deliverOwed(src) end
            end
        end
        Wait(30000)
    end
end)

-- expired cooldowns and stale approvals go about every 5 seconds (reads also check the time)
CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for id, untilMs in pairs(Srv.AnimalCd) do if untilMs <= now then Srv.AnimalCd[id] = nil end end
        for cid, untilMs in pairs(Srv.HunterCd) do if untilMs <= now then Srv.HunterCd[cid] = nil end end
        for src, ap in pairs(Srv.Approval) do if now - ap.at > 120000 then Srv.Approval[src] = nil end end
        for src, at in pairs(Srv.UseGrant) do if now - at > 15000 then Srv.UseGrant[src] = nil end end
    end
end)

-- lifecycle
AddEventHandler('playerDropped', function()
    local src = source
    Srv.releaseOut(src)
    Srv.UseGrant[src], Srv.Approval[src], Srv.LastLog[src], lastCall[src] = nil, nil, nil, nil
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    -- the client drops its trap on every selection, so the server always owes it back to whoever took it out
    Srv.releaseOut(src)
    Srv.Approval[src], Srv.UseGrant[src] = nil, nil
    -- give vorp_inventory time to load the satchel before handing anything back
    SetTimeout(15000, function()
        if Srv.valid(src) then Srv.deliverOwed(src) end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for src in pairs(Srv.Out) do Srv.releaseOut(src) end
    pcall(function() exports.vorp_inventory:unRegisterUsableItem(Config.Items.trap) end)
end)
