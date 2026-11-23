local Core <const> = exports.vorp_core:GetCore()

CreateThread(function()
    local sql <const> = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if sql and sql ~= '' then
        if not pcall(MySQL.query.await, sql) then
            print('^1[pup-emote]^7 emotewheel table could not be created')
        end
    end
end)

local function charIdOf(src)
    local user = Core.getUser(src)
    local ch = user and user.getUsedCharacter
    return ch and tonumber(ch.charIdentifier) or nil
end

local function sendWheel(src, charid)
    local ok, row = pcall(MySQL.scalar.await, 'SELECT emotes FROM emotewheel WHERE charid = ?', { charid })
    local stored, live = {}, 1
    if ok and type(row) == 'string' and row ~= '' then
        local okJ, decoded = pcall(json.decode, row)
        if okJ and type(decoded) == 'table' then
            stored = decoded.sets or {}
            live = tonumber(decoded.live) or 1
        end
    end
    TriggerClientEvent('pup-emote:client:wheel', src, stored, live)
end

-- per-player gap between database requests; a save inside the gap is held and the newest one written after it
local GET_EVERY_MS <const>, SAVE_EVERY_MS <const> = 2000, 1500
local lastGet, lastSave, heldSave = {}, {}, {}
AddEventHandler('playerDropped', function()
    lastGet[source], lastSave[source], heldSave[source] = nil, nil, nil
end)

RegisterNetEvent('pup-emote:server:get', function()
    local src <const> = source
    local charid <const> = charIdOf(src)
    if not charid then return end
    local now <const> = GetGameTimer()
    if lastGet[src] and now - lastGet[src] < GET_EVERY_MS then return end
    lastGet[src] = now
    sendWheel(src, charid)
end)

local saveWheel

RegisterNetEvent('pup-emote:server:save', function(stored, live)
    local src <const> = source
    if type(stored) ~= 'table' then return end
    local now <const> = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < SAVE_EVERY_MS then
        local waiting <const> = heldSave[src] ~= nil
        heldSave[src] = { stored = stored, live = live }
        if waiting then return end
        SetTimeout(SAVE_EVERY_MS, function()
            local held <const> = heldSave[src]
            heldSave[src] = nil
            if not held or not GetPlayerName(src) then return end
            lastSave[src] = GetGameTimer()
            saveWheel(src, held.stored, held.live)
        end)
        return
    end
    lastSave[src] = now
    saveWheel(src, stored, live)
end)

saveWheel = function(src, stored, live)
    local charid <const> = charIdOf(src)
    if not charid then return end

    -- client data bound for the DB: only a known emote id and a known mode survive
    local setCount <const> = math.min(16, tonumber(Config.Wheel.sets) or 4)
    local slotCount <const> = math.min(16, tonumber(Config.Wheel.slots) or 4)
    local clean = {}
    for s = 1, setCount do
        clean[s] = {}
        local row = stored[s]
        for i = 1, slotCount do
            local v = type(row) == 'table' and row[i] or nil
            local e = type(v) == 'table' and EmoteList.find(v.cmd) or nil
            if e then
                clean[s][i] = { cmd = e.id, mode = (v.mode == 'upper') and 'upper' or 'full' }
            else
                clean[s][i] = false -- keeps the slot's position in the json
            end
        end
    end

    live = tonumber(live) or 1
    if live < 1 or live > setCount then live = 1 end

    -- awaited so a failed write is seen rather than lost in a fire-and-forget call
    local ok, err = pcall(MySQL.update.await,
        'INSERT INTO emotewheel (charid, emotes) VALUES (?, ?) ON DUPLICATE KEY UPDATE emotes = VALUES(emotes)',
        { charid, json.encode({ sets = clean, live = live }) })
    if not ok then
        print(('^1[pup-emote]^7 could not save the wheel for char %s: %s'):format(charid, tostring(err)))
        return
    end
    TriggerClientEvent('pup-emote:client:saved', src)
end

-- re-sent on every character pick; the client also asks, for a mid-session resource start
AddEventHandler('vorp:SelectedCharacter', function(src, character)
    if not character or not character.charIdentifier then return end
    local s, cid = tonumber(src), tonumber(character.charIdentifier)
    if not s or not cid then return end
    SetTimeout(2000, function()
        if GetPlayerName(s) then sendWheel(s, cid) end
    end)
end)
