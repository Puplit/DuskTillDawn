-- THE PURGE | the siren, broadcast to everyone when it goes live.
-- 2D (PlayUrl): an announcement, not a place; the file needs a files{} entry for xsound

local SOUND_ID <const> = 'pup_purge_siren'

local function cfg()
    local purge = Config.Events and Config.Events.purge
    return (purge and purge.siren) or {}
end

-- no siren ships with the resource: add your own file to sounds/ and name it in config/events.lua
local function sirenFile()
    local file = tostring(cfg().file or ''):gsub('^/+', '')
    if file == '' then return nil end
    if not LoadResourceFile(GetCurrentResourceName(), file) then
        print(('^3[pup-events]^7 purge siren skipped - %s is not in the resource'):format(file))
        return nil
    end
    return file
end

local function sirenUrl(file)
    return ('https://cfx-nui-%s/%s'):format(GetCurrentResourceName(), file)
end

local function play()
    local c <const> = cfg()
    if c.enabled == false then return end
    local file <const> = sirenFile()
    if not file then return end -- no file: the purge starts in silence
    if GetResourceState('xsound') ~= 'started' then
        print('^3[pup-events]^7 purge siren skipped - xsound is not started')
        return
    end

    local volume <const> = tonumber(c.volume) or 0.4
    local ok, err = pcall(function()
        -- -1 is every player
        exports.xsound:PlayUrl(-1, SOUND_ID, sirenUrl(file), volume, false)
    end)
    if not ok then
        print('^3[pup-events]^7 purge siren failed: ' .. tostring(err))
    end
end

local function stop()
    if GetResourceState('xsound') ~= 'started' then return end
    pcall(function() exports.xsound:Destroy(-1, SOUND_ID) end)
end

AddEventHandler('pup-events:server:state', function(key, on)
    if key ~= 'purge' then return end
    if on == true then play() else stop() end
end)

-- a format xsound's NUI cannot decode fails silently, so this fires it on demand
RegisterCommand('purgesirentest', function(src)
    if not (EVT and EVT.isAdmin and EVT.isAdmin(src)) then return end
    local file <const> = sirenFile()
    print(('^3[pup-events]^7 siren test -> %s'):format(file and sirenUrl(file) or 'no siren file set'))
    play()
end, false)
