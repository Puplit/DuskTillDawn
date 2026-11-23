-- pup-magic | who is a vampire. The server works it out and tells that player's client.
-- CurseSent[src] is the only truth for "is this player a vampire" in every server check.

CurseSent = {}

local askedAt = {}

local function send(src, key)
    if not Online(src) then return end
    CurseSent[src] = key
    TriggerClientEvent('pup-magic:curse', src, key)
end

-- pup_shaman first; when it has nothing yet, the characters table. nil = the character changed while reading.
function ResolveCurse(src)
    local key
    if GetResourceState('pup_shaman') == 'started' then
        local ok, v = pcall(function() return exports.pup_shaman:GetCurse(src) end)
        if ok and type(v) == 'string' then key = v end
    end
    if key and key ~= '' then return key end

    local ch = CharOf(src)
    if not ch then return '' end

    local ok, raw = pcall(MySQL.scalar.await, 'SELECT `curse` FROM `characters` WHERE `charidentifier` = ? LIMIT 1', { ch.id })
    if not ok then
        WarnOnce('curse.db', 'reading characters.curse failed: ' .. tostring(raw))
        return ''
    end

    -- the read waited: make sure the same character is still in play
    local now = CharOf(src)
    if not now or now.id ~= ch.id then return nil end
    return type(raw) == 'string' and raw or ''
end

-- force = send even when the client already has this value
function PushCurse(src, force)
    local key = ResolveCurse(src)
    if key == nil or not Online(src) then return end
    if not force and CurseSent[src] == key then return end
    send(src, key)
end

function IsVampire(src)
    return CurseSent[src] == 'vamp'
end

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = PlayerIdOf(src)
    if not src then return end
    CurseSent[src] = nil
    CreateThread(function() PushCurse(src, true) end)
end)

-- server-local only (AddEventHandler, not a net event): no client can fake it
AddEventHandler('pup_shaman:curseChanged', function(src, key)
    src = PlayerIdOf(src)
    if not src then return end
    if type(key) ~= 'string' then key = '' end
    if CurseSent[src] ~= key then send(src, key) end
end)

RegisterNetEvent('pup-magic:askCurse', function()
    local src = PlayerIdOf(source)
    if not src or not Throttle(askedAt, src, 2000) then return end
    PushCurse(src, true)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(3000, function()
        for _, src in ipairs(ConnectedPlayers()) do
            PushCurse(src, true)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = math.tointeger(tonumber(source))
    if not src then return end
    CurseSent[src] = nil
    askedAt[src] = nil
end)

RegisterCommand('feedcurse', function(src, args)
    src = math.tointeger(tonumber(src)) or 0
    local named = args and args[1] and math.tointeger(tonumber(args[1])) or nil
    local target

    if src == 0 then
        if not named then print(Locale.consoleNeedsId) return end
        target = named
    else
        if named and named ~= src and not IsPlayerAceAllowed(tostring(src), 'command.feedcurse') then
            TipRight(src, Locale.ownCurseOnly, 5000)
            return
        end
        target = named or src
    end

    if not Online(target) then
        if src == 0 then print('[pup-magic] ' .. Locale.noSuchPlayer) else TipRight(src, Locale.noSuchPlayer, 4000) end
        return
    end

    CreateThread(function()
        local key = ResolveCurse(target) or ''
        if not Online(target) then return end
        send(target, key)
        local line = Locale.curseLine:format(target, key, key == 'vamp' and Locale.curseFeedOn or Locale.curseFeedOff)
        print(line)
        if src ~= 0 then TipRight(src, line, 6000) end
    end)
end, false)
