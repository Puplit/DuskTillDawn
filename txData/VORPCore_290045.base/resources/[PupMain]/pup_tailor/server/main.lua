-- pup_tailor | server core: players, characters, notifications, bench and staff checks, sign-in.
local U = Tailor.U
local Core = exports.vorp_core:GetCore()
local Inv = exports.vorp_inventory

Srv = {}
Srv.Core = Core
Srv.Inv = Inv

local RES <const> = GetCurrentResourceName()

function Srv.log(fmt, ...)
    print(('[%s] ' .. fmt):format(RES, ...))
end

function Srv.debug(fmt, ...)
    if Config.Debug then Srv.log(fmt, ...) end
end

-- a real, connected player id
function Srv.validSource(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if GetPlayerName(src) == nil then return nil end
    return src
end

-- a fresh snapshot of the character in use (money, job and comps are copies taken now)
function Srv.char(src)
    local user = Core.getUser(src)
    if not user then return nil end
    local c = user.getUsedCharacter
    if not c or not c.charIdentifier then return nil end
    return c
end

function Srv.notify(src, text, ms)
    Core.NotifyRightTip(src, text, ms or 4000)
end

-- run a handler body safely; a failure is logged, never thrown into the event system
function Srv.safe(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Srv.log('^1error in %s:^7 %s', name, tostring(err)) end
    return ok
end

---------------------------------------------------------------------------
-- rate limits and one job at a time
---------------------------------------------------------------------------
local lastHit = {}  -- [src][key] = GetGameTimer()
function Srv.throttle(src, key, ms)
    local now = GetGameTimer()
    local p = lastHit[src]
    if not p then p = {}; lastHit[src] = p end
    if p[key] and now - p[key] < ms then return false end
    p[key] = now
    return true
end

local busy = {}
function Srv.isBusy(src) return busy[src] == true end
function Srv.setBusy(src, v) busy[src] = v or nil end

-- run work with the busy flag held; cleared on success, refusal and error alike
function Srv.exclusive(src, name, fn, ...)
    if busy[src] then return end
    busy[src] = true
    Srv.safe(name, fn, ...)
    busy[src] = nil
end

---------------------------------------------------------------------------
-- benches, jobs, staff
---------------------------------------------------------------------------
local function benchTakesJob(bench, job)
    if not bench.jobLocked then return true end
    for _, j in ipairs(bench.jobs or {}) do
        if j == job then return true end
    end
    return false
end
Srv.benchTakesJob = benchTakesJob

-- returns true, or false plus the notification text
function Srv.benchCheck(src, char)
    char = char or Srv.char(src)
    if not char then return false, nil end
    local job = char.job
    local hasJob = false
    for _, b in ipairs(Config.Benches) do
        if benchTakesJob(b, job) then hasJob = true break end
    end
    if not hasJob then
        Srv.log('%s (id %d) tried to make clothing without a tailor job', GetPlayerName(src) or '?', src)
        return false, L('onlyTailor')
    end

    local ped = GetPlayerPed(src)
    local pos = (ped and ped ~= 0) and GetEntityCoords(ped) or nil
    if not pos or (pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0) then
        if Config.PassUnknownPosition then return true end
        return false, L('needBench')
    end
    for _, b in ipairs(Config.Benches) do
        if benchTakesJob(b, job) and #(pos - b.prompt) <= Config.BenchReach then return true end
    end
    return false, L('needBench')
end

-- bench check that notifies on refusal; returns ok, message
function Srv.requireBench(src, char)
    local ok, msg = Srv.benchCheck(src, char)
    if not ok and msg then Srv.notify(src, msg, 5000) end
    return ok, msg
end

function Srv.isStaff(src, char)
    char = char or Srv.char(src)
    if char and Config.StaffGroups[char.group] then return true end
    if GetResourceState('vorp_admin') == 'started' then
        local ok, res = pcall(function()
            return exports.vorp_admin:hasPermission(src, Config.StaffPermissionKey)
        end)
        if ok and res then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- inventory helpers
---------------------------------------------------------------------------
function Srv.itemCount(src, name)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, name) end)
    return ok and (tonumber(n) or 0) or 0
end

function Srv.canCarry(src, name, amount)
    local ok, res = pcall(function() return Inv:canCarryItem(src, name, amount) end)
    return ok and res == true
end

function Srv.addItem(src, name, amount, meta)
    local ok, res = pcall(function() return Inv:addItem(src, name, amount, meta) end)
    return ok and res == true
end

function Srv.itemExists(name)
    local ok, res = pcall(function() return Inv:getItemDB(name) end)
    return ok and res ~= nil and res ~= false
end

-- take every material or none. needs = { { name, label, count } }. returns true or false.
function Srv.takeMaterials(src, needs)
    local taken = {}
    for _, m in ipairs(needs) do
        local ok, res = pcall(function() return Inv:subItem(src, m.name, m.count) end)
        if not ok or res ~= true then
            for _, t in ipairs(taken) do Srv.addItem(src, t.name, t.count) end
            return false
        end
        taken[#taken + 1] = m
    end
    return true
end

function Srv.giveBack(src, needs)
    for _, m in ipairs(needs) do Srv.addItem(src, m.name, m.count) end
end

-- "Label have/need" for each short material, or nil when all are held
function Srv.shortList(src, needs)
    local short = {}
    for _, m in ipairs(needs) do
        local have = Srv.itemCount(src, m.name)
        if have < m.count then short[#short + 1] = ('%s %d/%d'):format(m.label, have, m.count) end
    end
    if #short == 0 then return nil end
    return short
end

-- the character is still the same one we started with
function Srv.sameChar(src, charId)
    local c = Srv.char(src)
    return c ~= nil and c.charIdentifier == charId, c
end

---------------------------------------------------------------------------
-- request/answer for the client's questions
---------------------------------------------------------------------------
local rpc = {}
function Srv.answer(name, fn) rpc[name] = fn end

local ASK_GAP_MS <const> = 200
local askDeferred = {}  -- [src][name] = true while one too-early question waits its turn

RegisterNetEvent('pup_tailor:ask', function(id, name, ...)
    local src = Srv.validSource(source)
    if not src or type(name) ~= 'string' or not rpc[name] then return end
    id = U.int(id)
    if not id then return end
    if not Srv.throttle(src, 'ask:' .. name, ASK_GAP_MS) then
        -- too soon: hold ONE question per name until the gap has passed, so the latest
        -- dye-book pick is still answered; any further ones in the gap are dropped
        local d = askDeferred[src]
        if not d then d = {}; askDeferred[src] = d end
        if d[name] then return end
        d[name] = true
        Wait(ASK_GAP_MS)
        if askDeferred[src] then askDeferred[src][name] = nil end
        if not Srv.validSource(src) or not Srv.throttle(src, 'ask:' .. name, ASK_GAP_MS) then return end
    end
    local args = { ... }
    Srv.safe('ask ' .. name, function()
        local char = Srv.char(src)
        if not char then return end
        local res = { rpc[name](src, char, table.unpack(args)) }
        if Srv.validSource(src) then
            TriggerClientEvent('pup_tailor:answer', src, id, table.unpack(res))
        end
    end)
end)

Srv.answer('job', function(_, char) return char.job end)

---------------------------------------------------------------------------
-- sign-in, job changes, drop
---------------------------------------------------------------------------
RegisterNetEvent('pup_tailor:signIn', function()
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'signIn', 1000) then return end
    local char = Srv.char(src)
    if not char then return end
    TriggerClientEvent('pup_tailor:job', src, char.job)
    TriggerClientEvent('pup_tailor:hidden', src, Srv.hiddenList and Srv.hiddenList() or {})
    TriggerClientEvent('pup_tailor:staff', src, Srv.isStaff(src, char))
end)

AddEventHandler('vorp:playerJobChange', function(src)
    src = Srv.validSource(src)
    if not src then return end
    -- VORP fires this just before it stores the new job
    SetTimeout(250, function()
        if not Srv.validSource(src) then return end
        local char = Srv.char(src)
        if char then TriggerClientEvent('pup_tailor:job', src, char.job) end
    end)
end)

-- the busy flag and every rate-limit entry (including palette renames) go with the player
AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastHit[src] = nil
    askDeferred[src] = nil
end)

---------------------------------------------------------------------------
-- startup checks (console only)
---------------------------------------------------------------------------
CreateThread(function()
    if #Config.ItemCategories == 0 then
        Srv.log('^3warning:^7 the item-category list is empty, single garments cannot be made')
    end
    if type(cloth_hash_names) ~= 'table' or #cloth_hash_names == 0 then
        Srv.log('^3warning:^7 the multiplayer clothing data is missing, prices cannot be checked')
    end
    Tailor.Cat.buildPrices()

    Wait(3000)
    local missing = {}
    local seen = {}
    for _, group in ipairs({ Config.DyeMaterials.flat or {}, Config.DyeMaterials.perGarment or {} }) do
        for _, m in ipairs(group) do
            if not seen[m.name] then
                seen[m.name] = true
                if not Srv.itemExists(m.name) then missing[#missing + 1] = m.name end
            end
        end
    end
    if #missing > 0 then
        Srv.log('^3warning:^7 %d dye material(s) are not real items (%s); every dye will be refused until they exist',
            #missing, table.concat(missing, ', '))
    end

    Wait(2000)
    local names = { 'pristine_clothingset', 'pristine_clothingset2' }
    for _, cat in ipairs(Config.ItemCategories) do names[#names + 1] = 'pristine_' .. cat end
    local found = 0
    for _, n in ipairs(names) do
        if Srv.itemExists(n) then found = found + 1 end
    end
    Srv.log('%d of %d pristine_ (dyed) items exist in the item database', found, #names)
    if found == 0 then
        Srv.log('^3warning:^7 no pristine_ items found; run sql/install.sql. Dyed items will keep their own name')
    end
end)
