-- pup-medical | doctors: /med, revive, bandage, cabinets, back-alley syringe

local M = Config.Medical or {}

local reviveLock   = {}   -- [src] = GetGameTimer() until which a revive is in progress
local revivedAt    = {}   -- [target] = os.time() of their last revive
local bandageAt    = {}   -- [src] = GetGameTimer() of the last bandage
local illegalUsed  = {}   -- [src] = os.time() the syringe was used from the inventory
local reviveCount  = {}   -- [src] = revives this session

local REVIVE_RANGE  = 10.0
local CABINET_REACH = 3.0  -- the prompt shows at 1.5 m; a little slack for lag

local function isDoctor(job) return InList(M.doctorJobs, job) end

---------------------------------------------------------------------------
-- Shared checks
---------------------------------------------------------------------------
local function validTarget(src, target)
    target = tonumber(target)
    if not target or target <= 0 or target ~= math.floor(target) or target == src then return nil end
    if not Online(target) then return nil end
    local ped = GetPlayerPed(target)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    if DistBetween(src, target) > REVIVE_RANGE then
        Warn(('player %d asked to treat %d from too far away'):format(src, target))
        return nil
    end
    return target
end

local function needsRevive(target)
    local tctx = GetCtx(target)
    if not tctx or not tctx.dead then return false end
    if revivedAt[target] and os.time() - revivedAt[target] < 5 then return false end
    return true
end

local function lockRevive(src)
    local now = GetGameTimer()
    if reviveLock[src] and reviveLock[src] > now then return false end
    reviveLock[src] = now + 5000
    return true
end

local function unlockRevive(src) reviveLock[src] = nil end

---------------------------------------------------------------------------
-- Revive log
---------------------------------------------------------------------------
local function logRevive(reviverCtx, job, targetSrc)
    local tctx = GetCtx(targetSrc)
    local embed = {
        title  = 'Medical revive',
        color  = Colors.green,
        fields = {
            PersonField('Reviver', reviverCtx),
            Field('Job', job),
            PersonField('Revived', tctx),
            Field('Time', os.date('%Y-%m-%d %H:%M:%S')),
            Field('Revives this session', reviveCount[reviverCtx.src] or 0),
        },
    }
    local avatar = Config.Logs and Config.Logs.avatarUrl
    local admin = Hook('reviveAdmin')
    local perJob = Hook('reviveByJob', job)
    if admin then PostWebhook(admin, embed, 'Medical Records', avatar) end
    if perJob and perJob ~= admin then PostWebhook(perJob, embed, 'Medical Records', avatar) end
end

-- the revive itself and everything that follows it
local function doRevive(reviverCtx, target, job, kind)
    revivedAt[target] = os.time()
    Core.Player.Revive(target)
    Alerts.OnRevived(target)
    Respawn.OnRevived(target)
    reviveCount[reviverCtx.src] = (reviveCount[reviverCtx.src] or 0) + 1
    logRevive(reviverCtx, job, target)
    CallPay.Complete(target, reviverCtx.src, kind, job)
end

---------------------------------------------------------------------------
-- /med
---------------------------------------------------------------------------
RegisterCommand('med', function(src)
    if src == 0 then return end
    local ctx = GetCtx(src)
    if not ctx then return TipBottom(src, L('noCharacter'), 4000) end
    if not isDoctor(ctx.job) then return TipBottom(src, L('needCertificate'), 4000) end
    if not IsOnDuty(src, ctx.job) then return TipBottom(src, L('mustBeOnDuty'), 4000) end
    if ctx.dead then return end
    TriggerClientEvent('pup-medical:client:openMed', src)
end, false)

---------------------------------------------------------------------------
-- Doctor (or police) revive
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:revive', function(target)
    local src = source
    if not RateOk(src, 'revive', 1500) then return end
    target = validTarget(src, target)
    if not target then return end
    local ctx = GetCtx(src)
    if not ctx then return end
    if not IsOnDuty(src, ctx.job) then return TipBottom(src, L('mustBeOnDuty'), 4000) end
    if ctx.dead then return end
    if not needsRevive(target) then return TipBottom(src, L('notUnconscious'), 4000) end

    if isDoctor(ctx.job) then
        if not lockRevive(src) then return end
        local item = M.reviveItem
        local ok = ItemCount(src, item) >= 1
        -- re-check: the patient may have been revived meanwhile
        if ok and not needsRevive(target) then
            unlockRevive(src)
            return TipBottom(src, L('notUnconscious'), 4000)
        end
        ok = ok and TakeItem(src, item, 1)
        if not ok then
            unlockRevive(src)
            return TipBottom(src, L('youLack', L('wordSyringe')), 4000)
        end
        ctx = StillSame(ctx)
        if not ctx then unlockRevive(src) return end
        doRevive(ctx, target, ctx.job, 'revive')
        unlockRevive(src)
        return
    end

    local pr = M.policeRevive
    if type(pr) == 'table' and pr.enabled and InList(pr.jobs, ctx.job) then
        doRevive(ctx, target, ctx.job, 'revive')
        return
    end
    TipBottom(src, L('cantNow'), 4000)
end)

---------------------------------------------------------------------------
-- Bandage
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:bandage', function(target)
    local src = source
    if not RateOk(src, 'bandage', 1000) then return end
    target = validTarget(src, target)
    if not target then return end
    local ctx = GetCtx(src)
    if not ctx then return end
    if not IsOnDuty(src, ctx.job) then return TipBottom(src, L('mustBeOnDuty'), 4000) end
    if not isDoctor(ctx.job) or ctx.dead then return TipBottom(src, L('cantNow'), 4000) end

    local now = GetGameTimer()
    if bandageAt[src] and now - bandageAt[src] < 8000 then return TipBottom(src, L('cantNow'), 3000) end
    local item = M.healItem
    if ItemCount(src, item) < 1 or not TakeItem(src, item, 1) then
        return TipBottom(src, L('youLack', L('wordBandage')), 4000)
    end
    bandageAt[src] = now
    TriggerClientEvent('pup-medical:client:bandaged', target)
    TipBottom(src, L('bandageDone'), 3000)
    CallPay.Complete(target, src, 'heal', ctx.job)
end)

---------------------------------------------------------------------------
-- Cabinets
---------------------------------------------------------------------------
local cab = M.cabinet or {}
local lastRestock = {}

local function cabinetId(n) return ('pup_medical_cabinet_%d'):format(n) end

local function registerCabinets()
    if not Started('vorp_inventory') then return end
    for n in ipairs(cab.locations or {}) do
        local ok, err = pcall(function()
            Inv:registerInventory({
                id                   = cabinetId(n),
                name                 = cab.name or 'Medical Cabinet',
                limit                = tonumber(cab.limit) or 0,
                acceptWeapons        = false,
                shared               = true,
                ignoreItemStackLimit = true,
                whitelistItems       = false,
                UsePermissions       = false,
                UseBlackList         = false,
                whitelistWeapons     = false,
            })
        end)
        if not ok then WarnOnce('cabinet-register', 'could not register cabinets: ' .. tostring(err)) return end
    end
end

CreateThread(function()
    while not Started('vorp_inventory') do Wait(1000) end
    registerCabinets()
end)

AddEventHandler('onResourceStart', function(name)
    if name == 'vorp_inventory' then SetTimeout(2000, registerCabinets) end
end)

-- tops each stock line up to its amount; true when anything was added
local function restock(n, charId)
    local mins = tonumber(cab.restockMinutes) or 0
    local now = os.time()
    if mins > 0 and lastRestock[n] and now - lastRestock[n] < mins * 60 then return false end
    lastRestock[n] = now
    local id = cabinetId(n)
    local added = false
    for _, line in ipairs(cab.stock or {}) do
        local want = math.floor(tonumber(line.amount) or 0)
        if type(line.item) == 'string' and want > 0 then
            local ok, have = pcall(function() return Inv:getCustomInventoryItemCount(id, line.item) end)
            have = ok and tonumber(have) or nil
            if have and have < want then
                local ok2, res = pcall(function()
                    return Inv:addItemsToCustomInventory(id, { { name = line.item, amount = want - have } }, charId)
                end)
                if ok2 and res then added = true end
            end
        end
    end
    return added
end

RegisterNetEvent('pup-medical:server:openCabinet', function()
    local src = source
    if not RateOk(src, 'cabinet', 1000) then return end
    local ctx = GetCtx(src)
    if not ctx then return end
    if not isDoctor(ctx.job) then return TipBottom(src, L('needCertificate'), 4000) end
    if not IsOnDuty(src, ctx.job) then return TipBottom(src, L('needDuty'), 4000) end
    if ctx.dead then return end

    local pos = Pos(src)
    if not pos then return end
    local found = nil
    for n, loc in ipairs(cab.locations or {}) do
        if #(pos - loc) <= CABINET_REACH then found = n break end
    end
    if not found then return end

    if restock(found, ctx.charId) then Wait(300) end
    ctx = StillSame(ctx)
    if not ctx or ctx.dead then return end
    pos = Pos(src)
    if not pos or #(pos - cab.locations[found]) > CABINET_REACH then return end
    local ok, err = pcall(function() Inv:openInventory(src, cabinetId(found)) end)
    if not ok then Warn('openInventory failed: ' .. tostring(err)) end
end)

---------------------------------------------------------------------------
-- Back-alley syringe
---------------------------------------------------------------------------
local ill = M.illegalSyringe or {}

local function useSeconds() return (tonumber(ill.useTimeMs) or 10000) / 1000 end

local function registerSyringe()
    if not Started('vorp_inventory') then return end
    local ok, err = pcall(function()
        Inv:registerUsableItem(ill.item, function(data)
            local src = tonumber(data and data.source)
            if not src then return end
            local now = os.time()
            if illegalUsed[src] and now - illegalUsed[src] < useSeconds() then return end
            illegalUsed[src] = now
            TriggerClientEvent('pup-medical:client:useIllegal', src)
        end, RES)
    end)
    if not ok then Warn('could not register the back-alley syringe: ' .. tostring(err)) end
end

if ill.enabled and type(ill.item) == 'string' then
    CreateThread(function()
        while not Started('vorp_inventory') do Wait(1000) end
        registerSyringe()
    end)
    -- vorp_inventory forgets usable items when it restarts
    AddEventHandler('onResourceStart', function(name)
        if name == 'vorp_inventory' then SetTimeout(2000, registerSyringe) end
    end)
end

RegisterNetEvent('pup-medical:server:illegalRevive', function(target)
    local src = source
    if not ill.enabled then return end
    if not RateOk(src, 'illegal', 1500) then return end
    target = validTarget(src, target)
    if not target then return end
    local ctx = GetCtx(src)
    if not ctx or ctx.dead then return end
    if not needsRevive(target) then return TipBottom(src, L('illegalNotNeeded'), 4000) end

    local used = illegalUsed[src]
    local since = used and (os.time() - used) or nil
    if not since or since < useSeconds() - 2 or since > useSeconds() + 60 then return end
    if not lockRevive(src) then return end

    if ItemCount(src, ill.item) < 1 or not TakeItem(src, ill.item, 1) then
        unlockRevive(src)
        return TipBottom(src, L('youLack', ItemLabel(ill.item)), 4000)
    end
    illegalUsed[src] = nil

    if math.random(1, 100) <= (tonumber(ill.failChance) or 0) then
        unlockRevive(src)
        return TipBottom(src, L('illegalFailed'), 5000)
    end
    ctx = StillSame(ctx)
    if not ctx or not needsRevive(target) then unlockRevive(src) return end
    doRevive(ctx, target, 'illegal', 'revive')
    TipBottom(src, L('illegalSuccess'), 5000)
    unlockRevive(src)
end)

OnPlayerLeft(function(src)
    reviveLock[src] = nil
    revivedAt[src] = nil
    bandageAt[src] = nil
    illegalUsed[src] = nil
    reviveCount[src] = nil
end)
