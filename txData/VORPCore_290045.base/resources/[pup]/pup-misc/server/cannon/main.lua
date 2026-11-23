-- pup-misc / cannon - server: owns the permission gate

local VorpCore = {}
TriggerEvent('getCore', function(core) VorpCore = core end)
if not VorpCore or not VorpCore.getUser then
    VorpCore = exports.vorp_core:GetCore()
end

local function isLaw(character)
    if not character then return false end
    local job = tostring(character.job or '')
    for _, allowed in ipairs(CannonConfig.Access.jobs or {}) do
        if job == allowed then return true end
    end
    return false
end

-- pup-mdt being down reads as off duty: this hands out heavy weapons, so it doesn't guess
local function onDuty(src)
    local ok, duty = pcall(function() return exports['pup-mdt']:IsPlayerOnDuty(src) end)
    return ok and duty == true
end

local function rankFor(model)
    return tonumber(model.minGrade) or tonumber(CannonConfig.Access.minGrade) or 5
end

-- pieces standing per player: the server keeps the list and clears up when that player is gone
local issued = {}   -- [src] = /gat placements not reported back yet
local pieces = {}   -- [src] = { [netId] = true }

local function isCannonModel(ent)
    local model = GetEntityModel(ent) % 4294967296.0
    for _, m in ipairs(CannonConfig.Models or {}) do
        if GetHashKey(m.model) % 4294967296.0 == model then return true end
    end
    return false
end

-- the entity reaches the server a moment after this event does, so it is looked for over a few seconds
RegisterNetEvent('pup-misc:cannon:placed', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId or netId ~= netId or netId <= 0 then return end
    if (issued[src] or 0) <= 0 then return end
    issued[src] = issued[src] - 1
    CreateThread(function()
        for _ = 1, 50 do
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                if not isCannonModel(ent) or NetworkGetEntityOwner(ent) ~= src then return end
                if GetPlayerName(src) then
                    pieces[src] = pieces[src] or {}
                    pieces[src][netId] = true
                else
                    DeleteEntity(ent)
                end
                return
            end
            Wait(100)
        end
    end)
end)

RegisterNetEvent('pup-misc:cannon:gone', function(netId)
    local mine = pieces[source]
    netId = tonumber(netId)
    if mine and netId then mine[netId] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    issued[src] = nil
    for netId in pairs(pieces[src] or {}) do
        local ent = NetworkGetEntityFromNetworkId(netId)
        -- the net id may have been reused since, so it must still be one of these models
        if ent and ent ~= 0 and DoesEntityExist(ent) and isCannonModel(ent) then DeleteEntity(ent) end
    end
    pieces[src] = nil
end)

RegisterCommand(CannonConfig.General.command or 'gat', function(source, args)
    local src = source
    if src == 0 then return end
    local user = VorpCore.getUser(src)
    local ch = user and user.getUsedCharacter
    if not ch then return end

    if not isLaw(ch) then
        VorpCore.NotifyRightTip(src, CannonLocale.notAuthorised, 4000)
        return
    end

    if not onDuty(src) then
        VorpCore.NotifyRightTip(src, CannonLocale.notOnDuty, 4000)
        return
    end

    local want = tonumber(args[1]) or 1
    local pick
    for _, m in ipairs(CannonConfig.Models or {}) do
        if m.key == want then pick = m break end
    end
    if not pick then
        local names = {}
        local grade = tonumber(ch.jobGrade) or 0
        for _, m in ipairs(CannonConfig.Models or {}) do
            if grade >= rankFor(m) then names[#names + 1] = ('%d = %s'):format(m.key, m.label) end
        end
        VorpCore.NotifyRightTip(src, CannonLocale.pickOne .. table.concat(names, ', '), 6000)
        return
    end

    if (tonumber(ch.jobGrade) or 0) < rankFor(pick) then
        VorpCore.NotifyRightTip(src, CannonLocale.needRank:format(rankFor(pick), pick.label), 5000)
        return
    end

    issued[src] = (issued[src] or 0) + 1
    TriggerClientEvent('pup-misc:cannon:spawn', src, pick.model, pick.label)
end, false)

RegisterCommand(CannonConfig.General.removeCommand or 'gatremove', function(source)
    if source == 0 then return end
    TriggerClientEvent('pup-misc:cannon:remove', source)
end, false)
