-- Positional playback through xsound. Each phonograph's sound is named with its
-- id as a string; the optional crackle track adds "_effect".
-- Every start gets a new generation number, so callbacks from a replaced or
-- stopped sound (xsound's Destroy also fires onPlayEnd) are ignored.

PC = PC or {}
PC.Sounds = {} -- [id] = { gen, serial, url, volume, pos, loop, radius }

local gen = 0

local function soundName(id) return tostring(id) end
local function effectName(id) return tostring(id) .. '_effect' end

local function exists(name)
    return PC.Xs('soundExists', name) == true
end

local function destroy(name)
    if exists(name) then PC.Xs('Destroy', name) end
end

local function crackleOn()
    return Config.Crackle.enabled and type(Config.Crackle.url) == 'string' and Config.Crackle.url ~= ''
end

local function effectVolume(v)
    return PC.Clamp(v * (tonumber(Config.Crackle.volumeShare) or 0.0), 0.0, 1.0)
end

local onEnded

local function start(id, s, offset)
    gen = gen + 1
    s.gen = gen
    local myGen = gen
    local name, fx = soundName(id), effectName(id)

    -- forget the old play first so its end callback is ignored
    PC.Sounds[id] = s
    destroy(name)
    destroy(fx)

    local pos = PC.Vec(s.pos)
    PC.Xs('PlayUrlPos', name, s.url, s.volume, pos, s.loop)
    if not exists(name) then return end -- music turned off in xsound
    PC.Xs('onPlayEnd', name, function() onEnded(id, myGen) end)
    PC.Xs('Distance', name, s.radius)

    -- xsound sometimes ignores the first distance call
    SetTimeout(1000, function()
        local cur = PC.Sounds[id]
        if cur and cur.gen == myGen and exists(name) then PC.Xs('Distance', name, cur.radius) end
    end)

    if offset and offset > 0 then
        SetTimeout(500, function()
            local cur = PC.Sounds[id]
            if cur and cur.gen == myGen and exists(name) then PC.Xs('setTimeStamp', name, offset) end
        end)
    end

    if crackleOn() then
        PC.Xs('PlayUrlPos', fx, Config.Crackle.url, effectVolume(s.volume), pos, true)
        if exists(fx) then PC.Xs('Distance', fx, s.radius) end
    end
end

onEnded = function(id, myGen)
    local s = PC.Sounds[id]
    if not s or s.gen ~= myGen then return end
    if s.loop then
        -- restart it here if xsound let it go, and tell the server so late joiners line up
        if not exists(soundName(id)) then start(id, s, 0) end
        TriggerServerEvent('pup-phonograph:server:looped', id, s.serial)
        return
    end
    PC.Sounds[id] = nil
    destroy(effectName(id))
    destroy(soundName(id))
    TriggerServerEvent('pup-phonograph:server:ended', id, s.serial)
end

local function stop(id)
    PC.Sounds[id] = nil
    destroy(effectName(id))
    destroy(soundName(id))
end

function PC.StopAllSounds()
    local ids = {}
    for id in pairs(PC.Sounds) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do stop(id) end
end

RegisterNetEvent('pup-phonograph:client:play', function(d)
    if type(d) ~= 'table' then return end
    local id = tonumber(d.id)
    if not id or type(d.url) ~= 'string' or type(d.pos) ~= 'table' then return end
    local s = {
        serial = tonumber(d.serial) or 0,
        url = d.url,
        volume = PC.Clamp(tonumber(d.volume) or Config.DefaultVolume, 0.0, 1.0),
        pos = { x = tonumber(d.pos.x) or 0.0, y = tonumber(d.pos.y) or 0.0, z = tonumber(d.pos.z) or 0.0 },
        loop = d.loop == true,
        radius = tonumber(d.radius) or Config.Radius.default,
    }
    start(id, s, tonumber(d.offset) or 0)
end)

RegisterNetEvent('pup-phonograph:client:stop', function(id)
    id = tonumber(id)
    if id then stop(id) end
end)

RegisterNetEvent('pup-phonograph:client:stopAll', function()
    PC.StopAllSounds()
end)

RegisterNetEvent('pup-phonograph:client:volume', function(id, v)
    id, v = tonumber(id), tonumber(v)
    local s = id and PC.Sounds[id]
    if not s or not v then return end
    s.volume = PC.Clamp(v, 0.0, 1.0)
    if exists(soundName(id)) then PC.Xs('setVolume', soundName(id), s.volume) end
    if exists(effectName(id)) then PC.Xs('setVolume', effectName(id), effectVolume(s.volume)) end
end)

RegisterNetEvent('pup-phonograph:client:radius', function(id, r)
    id, r = tonumber(id), tonumber(r)
    local s = id and PC.Sounds[id]
    if not s or not r then return end
    s.radius = r
    if exists(soundName(id)) then PC.Xs('Distance', soundName(id), r) end
    if exists(effectName(id)) then PC.Xs('Distance', effectName(id), r) end
end)

RegisterNetEvent('pup-phonograph:client:loop', function(id, on)
    id = tonumber(id)
    local s = id and PC.Sounds[id]
    if not s then return end
    s.loop = on == true
    local name = soundName(id)
    if s.loop then
        if exists(name) then
            PC.Xs('setSoundLoop', name, true)
            PC.Xs('destroyOnFinish', name, false)
        else
            start(id, s, 0)
        end
    elseif exists(name) then
        -- let the current pass finish, then end normally
        PC.Xs('setSoundLoop', name, false)
        PC.Xs('destroyOnFinish', name, true)
    end
end)
