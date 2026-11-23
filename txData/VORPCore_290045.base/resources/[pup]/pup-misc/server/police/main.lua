local badgeOffsets = {}
local cuffedPlayers = {}

-- DUTY COMES FROM pup-mdt
local function isOnDuty(src)
    local ok, res = pcall(function()
        return exports['pup-mdt']:IsPlayerOnDuty(src)
    end)
    return ok and res == true
end

-- PoliceConfig.Jobs.law is the only list of law jobs
local function hasLawJob(character)
    if character == nil or character.job == nil then return false end
    for _, jobName in ipairs(PoliceConfig.Jobs.law) do
        if character.job == jobName then return true end
    end
    return false
end

-- vorp:getCharacter never answers when the character is not loaded, so law commands
-- read the character straight off the core instead (getChar)
local Core = exports.vorp_core:GetCore()

local function getChar(src)
    local ok, user = pcall(function() return Core.getUser(src) end)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    -- UsedCharacter() returns an EMPTY TABLE, not nil, before a character is picked
    if type(ch) ~= 'table' or not ch.charIdentifier then return nil end
    return ch
end

-- pup-mdt owns the rank LADDER too (grades 0-12, named in its locales/*.lua as grade_0 .. grade_12)
local function rankNameFor(grade)
    local ok, res = pcall(function()
        return exports['pup-mdt']:GetRankNameByGrade(grade)
    end)
    if ok and type(res) == 'string' and res ~= '' and res ~= 'Unknown Rank' then
        return res
    end
    return nil
end

-- The handshake
RegisterNetEvent('pup-misc:police:checkmyjob')
AddEventHandler('pup-misc:police:checkmyjob', function()
    local src = source
    local character = getChar(src)

    if not character then
        TriggerClientEvent('pup-misc:police:thejob', src, "retry", nil, nil)
        return
    end

    TriggerClientEvent('pup-misc:police:thejob', src,
        hasLawJob(character) and "pass" or "none",
        character.job, character.jobGrade)
end)

RegisterNetEvent('pup-misc:police:checkBadgeDuty')
AddEventHandler('pup-misc:police:checkBadgeDuty', function()
    local src = source
    local character = getChar(src)

    -- NO REPLY AT ALL to someone without the job
    if not hasLawJob(character) then
        return
    end
    if isOnDuty(src) then
        TriggerClientEvent('pup-misc:police:badgeDutyResponse', src, true,
            character.job, character.jobGrade, rankNameFor(character.jobGrade))
    else
        TriggerClientEvent('pup-misc:police:badgeDutyResponse', src, false, nil, nil, nil)
    end
end)

RegisterNetEvent('pup-misc:police:checkMenuDuty')
AddEventHandler('pup-misc:police:checkMenuDuty', function()
    local src = source
    local character = getChar(src)

    -- same rule as the badge: silence for anyone without the job
    if not hasLawJob(character) then
        return
    end
    TriggerClientEvent('pup-misc:police:menuDutyResponse', src, isOnDuty(src) == true)
end)

local function isLawOnDuty(character, src)
    if not hasLawJob(character) then return false end
    return isOnDuty(src)
end

-- Refusal feedback
local function refuse(character, src)
    if hasLawJob(character) then
        TriggerClientEvent('vorp:TipRight', src, PoliceLocale.mustBeOnDuty, 3000)
    end
end

-- A real player right beside this one. The client picks the nearest within 2 m, then runs a short bar.
local function reachableTarget(src, targetId, reach)
    targetId = tonumber(targetId)
    if not targetId or targetId <= 0 or targetId == src then return nil end
    if not getChar(targetId) then return nil end
    local a, b = GetPlayerPed(src), GetPlayerPed(targetId)
    if not a or a == 0 or not b or b == 0 then return nil end
    local ca, cb = GetEntityCoords(a), GetEntityCoords(b)
    local dx, dy, dz = ca.x - cb.x, ca.y - cb.y, ca.z - cb.z
    if dx * dx + dy * dy + dz * dz > reach * reach then return nil end
    return targetId
end

-- [copSrc] = draggedSrc. Mirrors piggyback: an attachment applied only by the
-- dragged player does not render for anyone else, so the pair is broadcast and every client pins it locally
local dragging = {}

-- lets go of one person, on every screen and on theirs
local function endDrag(cop, target)
    dragging[cop] = nil
    TriggerClientEvent('pup-misc:police:dragSync', -1, cop, target, false)
    TriggerClientEvent('pup-misc:police:drag', target, cop, false)
end

RegisterNetEvent('pup-misc:police:handcuff')
AddEventHandler('pup-misc:police:handcuff', function(targetId)
    local src = source
    -- getChar, not vorp:getCharacter - see the note at the top
    local character = getChar(src)
    if isLawOnDuty(character, src) then
        targetId = reachableTarget(src, targetId, 6.0)
        if targetId then
            -- send the state, not "flip it", so the client can never end up inverted
            cuffedPlayers[targetId] = not cuffedPlayers[targetId]
            TriggerClientEvent('pup-misc:police:handcuff', targetId, cuffedPlayers[targetId] and true or false)
            -- uncuffed while being led: otherwise the next cuff starts following that cop again
            if not cuffedPlayers[targetId] then
                for cop, target in pairs(dragging) do
                    if target == targetId then endDrag(cop, target) end
                end
            end
        end
    else
        refuse(character, src)
    end
end)

-- The server's table is the truth
RegisterNetEvent('pup-misc:police:syncMyCuff')
AddEventHandler('pup-misc:police:syncMyCuff', function()
    local src = source
    TriggerClientEvent('pup-misc:police:handcuff', src, cuffedPlayers[src] and true or false)
end)

RegisterNetEvent('pup-misc:police:checkCuffed')
AddEventHandler('pup-misc:police:checkCuffed', function(targetId)
    local src = source
    if not isLawOnDuty(getChar(src), src) then return end
    targetId = tonumber(targetId)
    if targetId then
        TriggerClientEvent('pup-misc:police:cuffStatus', src, targetId, cuffedPlayers[targetId] or false)
    end
end)

RegisterNetEvent('pup-misc:police:drag')
AddEventHandler('pup-misc:police:drag', function(targetId)
    local src = source
    local character = getChar(src)
    if isLawOnDuty(character, src) then
        targetId = tonumber(targetId)
        -- letting go always works; starting a drag needs them right there
        if targetId and dragging[src] ~= targetId then targetId = reachableTarget(src, targetId, 6.0) end
        if targetId then
            local on = dragging[src] ~= targetId
            -- cuffed is checked HERE, against the server's own table
            if on and not cuffedPlayers[targetId] then
                TriggerClientEvent('vorp:TipRight', src, PoliceLocale.notCuffed, 3000)
                return
            end
            if on then
                -- one person per cop and one cop per person: whoever is let go has to be told
                if dragging[src] then endDrag(src, dragging[src]) end
                for cop, target in pairs(dragging) do
                    if target == targetId then endDrag(cop, target) end
                end
            end
            dragging[src] = on and targetId or nil
            TriggerClientEvent('pup-misc:police:dragSync', -1, src, targetId, on)
            TriggerClientEvent('pup-misc:police:drag', targetId, src, on)
        end
    else
        refuse(character, src)
    end
end)

RegisterNetEvent('pup-misc:police:dragResync')
AddEventHandler('pup-misc:police:dragResync', function()
    local src = source
    for cop, target in pairs(dragging) do
        TriggerClientEvent('pup-misc:police:dragSync', src, cop, target, true)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if dragging[src] then endDrag(src, dragging[src]) end
    for cop, target in pairs(dragging) do
        if target == src then
            TriggerClientEvent('pup-misc:police:dragSync', -1, cop, target, false)
            dragging[cop] = nil
        end
    end
end)

-- SERVER-SIDE ONLY (no RegisterNetEvent, so a client cannot fire it): another resource frees a player from cuffs and
-- any drag, e.g. pup-mdt once a sentence starts. TriggerEvent('pup-misc:police:server:release', targetSrc)
AddEventHandler('pup-misc:police:server:release', function(targetId)
    targetId = tonumber(targetId)
    if not targetId then return end
    if cuffedPlayers[targetId] then
        cuffedPlayers[targetId] = false
        TriggerClientEvent('pup-misc:police:lockpicked', targetId)
    end
    for cop, target in pairs(dragging) do
        if target == targetId then
            TriggerClientEvent('pup-misc:police:dragSync', -1, cop, target, false)
            TriggerClientEvent('pup-misc:police:drag', targetId, cop, false)
            dragging[cop] = nil
        end
    end
end)

-- fines are handled by pup-mdt (/mdtbill)

RegisterNetEvent('pup-misc:police:putinoutvehicle')
AddEventHandler('pup-misc:police:putinoutvehicle', function(targetId)
    local src = source
    if not isLawOnDuty(getChar(src), src) then return end
    targetId = reachableTarget(src, targetId, 10.0)
    if targetId then
        TriggerClientEvent('pup-misc:police:putinoutvehicle', targetId)
    end
end)

RegisterNetEvent('pup-misc:police:GetID')
AddEventHandler('pup-misc:police:GetID', function(targetId)
    local src = source
    if not isLawOnDuty(getChar(src), src) then return end
    if not targetId then return end

    local target = getChar(tonumber(targetId))
    if target then
        TriggerClientEvent('vorp:TipRight', src,
            PoliceLocale.name .. tostring(target.firstname) .. ' ' .. tostring(target.lastname), 5000)
    end
end)

-- BADGE POSITION - saved PER CHARACTER, in the database
CreateThread(function()
    Wait(2000)
    local ok = pcall(function()
        exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS police_badge_offsets (
            charid INT NOT NULL PRIMARY KEY,
            offset TEXT NOT NULL
        )]], {})
    end)
    if not ok then
        print('[pup-misc/police] ^3could not reach oxmysql - badge positions will not persist^7')
    end
end)

-- hand the character's charIdentifier to `fn`, or do nothing if the character is not loaded
local function withCharId(src, fn)
    local character = getChar(src)
    local charid = character and tonumber(character.charIdentifier)
    if charid then fn(charid) end
end

RegisterNetEvent('pup-misc:police:badge:saveBadgeOffset')
AddEventHandler('pup-misc:police:badge:saveBadgeOffset', function(offset)
    local src = source
    if type(offset) ~= 'string' or #offset > 512 then return end

    withCharId(src, function(charid)
        badgeOffsets[charid] = offset
        pcall(function()
            exports.oxmysql:execute(
                'INSERT INTO police_badge_offsets (charid, offset) VALUES (?, ?) ' ..
                'ON DUPLICATE KEY UPDATE offset = VALUES(offset)',
                { charid, offset })
        end)
    end)
end)

RegisterNetEvent('pup-misc:police:badge:loadBadgeOffset')
AddEventHandler('pup-misc:police:badge:loadBadgeOffset', function()
    local src = source

    withCharId(src, function(charid)
        -- memory first, so a relog inside one session never waits on a query
        if badgeOffsets[charid] then
            TriggerClientEvent('pup-misc:police:badge:setBadgeOffset', src, badgeOffsets[charid])
            return
        end

        pcall(function()
            exports.oxmysql:execute('SELECT offset FROM police_badge_offsets WHERE charid = ?',
                { charid }, function(rows)
                    if rows and rows[1] and rows[1].offset then
                        badgeOffsets[charid] = rows[1].offset
                        TriggerClientEvent('pup-misc:police:badge:setBadgeOffset', src, rows[1].offset)
                    end
                end)
        end)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    cuffedPlayers[src] = nil
end)

AddEventHandler('vorp:playerLogout', function(source)
    local src = source
    cuffedPlayers[src] = nil
end)
