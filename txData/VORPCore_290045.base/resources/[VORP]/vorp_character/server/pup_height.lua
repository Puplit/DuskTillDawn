-- Modified by Puppet (Dusk Till Dawn), 2026
-- height (ped scale) reset from the saved value, not stock VORP's client-side cache

local Core <const> = exports.vorp_core:GetCore()

-- /rc is spammable and a cache miss costs a query
local lastRequest = {}
local COOLDOWN <const> = 1000

-- the scale on the active character, or nil if there is none worth applying
local function savedScale(src)
    local user = Core.getUser(src)
    local character = user and user.getUsedCharacter
    if not character then return nil end

    local function usable(skin)
        if type(skin) ~= "table" then return nil end
        local n = tonumber(skin.Scale)
        -- 0.0 is the template default, meaning they never chose a height
        if not n or n < 0.1 or n > 5.0 then return nil end
        return n
    end

    -- 1. in-memory copy: a string on every build seen here, but accept a table too
    local src_skin = character.skin
    if type(src_skin) == "table" then
        local n = usable(src_skin)
        if n then return n end
    elseif type(src_skin) == "string" and src_skin ~= "" then
        local ok, skin = pcall(json.decode, src_skin)
        if ok then
            local n = usable(skin)
            if n then return n end
        end
    end

    -- 2. the column
    local charid = character.charIdentifier
    if not charid then return nil end

    local okr, raw = pcall(MySQL.scalar.await, "SELECT skinPlayer FROM characters WHERE charidentifier = ?", { charid })
    if not okr or type(raw) ~= "string" or raw == "" then return nil end

    local okj, skin = pcall(json.decode, raw)
    if not okj then return nil end
    return usable(skin)
end

-- bumped per push so the client observer can tell a repeat from a new value
local nonce = 0

local function setHeightState(src, scale)
    local p = Player(src)
    if not p or not p.state then return end
    nonce = nonce + 1
    -- `true` = replicated to all clients
    p.state:set("pupHeight", { s = scale, n = nonce }, true)
end

-- push the saved scale back to one player; `reason` is only for the debug line
local function pushHeight(src, reason)
    local scale = savedScale(src)
    if not scale then return end
    TriggerClientEvent("vorp_character:pupApplyHeight", src, scale, reason)
    setHeightState(src, scale)
end

-- character load
AddEventHandler("vorp:SelectedCharacter", function(src)
    src = tonumber(src)
    if not src then return end
    SetTimeout(3000, function() pushHeight(src, "selected") end)
end)

-- publish for everyone already online on restart
AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(4000, function()
        local n = 0
        for _, sid in ipairs(GetPlayers()) do
            local s = tonumber(sid)
            if s and savedScale(s) then
                pushHeight(s, "resource start")
                n = n + 1
            end
        end
        print(("^3[pup height]^7 published height for %d player(s) already online"):format(n))
    end)
end)

-- for anything that changes a height mid-session: the creator, the barber, the admin panel
exports("RefreshHeight", function(src)
    src = tonumber(src)
    if not src then return end
    pushHeight(src, "refresh")
end)


-- a published scale is the saved one or one the character creator offers (short 0.85 .. tall 1.05; ERP uses 1.0)
local PUBLISH_MIN <const> = 0.85
local PUBLISH_MAX <const> = 1.05

-- publish an effective scale that is not the saved one (disguises, ERP)
RegisterNetEvent("vorp_character:pupHeightPublish", function(scale)
    local _source <const> = source
    scale = tonumber(scale)
    if not scale or scale < 0.1 or scale > 5.0 then return end

    local now <const> = GetGameTimer()
    if lastRequest[_source] and now - lastRequest[_source] < COOLDOWN then return end
    lastRequest[_source] = now

    if scale < PUBLISH_MIN - 0.0001 or scale > PUBLISH_MAX + 0.0001 then
        local saved <const> = savedScale(_source)
        if not saved or math.abs(saved - scale) > 0.001 then return end
    end

    -- the client observer skips its own player, so the publisher's own ped is set directly too
    TriggerClientEvent("vorp_character:pupApplyHeight", _source, scale, "publish")
    setHeightState(_source, scale)
end)

-- client asks after /rc
RegisterNetEvent("vorp_character:pupResetHeight", function()
    local _source <const> = source
    local now <const> = GetGameTimer()
    if lastRequest[_source] and now - lastRequest[_source] < COOLDOWN then return end
    lastRequest[_source] = now

    pushHeight(_source, "rc")
end)

-- every revive path ends up here, so the push is repeated as the ped rebuilds
local REVIVE_PUSHES <const> = { 700, 1500, 3000, 6000 }

local function pushRepeatedly(src, reason, delays)
    for _, ms in ipairs(delays) do
        SetTimeout(ms, function()
            -- they may have dropped or swapped character in between
            if GetPlayerName(src) then pushHeight(src, reason) end
        end)
    end
end

AddEventHandler("vorp_core:Server:OnPlayerRevive", function(src)
    src = tonumber(src)
    if not src then return end
    pushRepeatedly(src, "revive", REVIVE_PUSHES)
end)

AddEventHandler("vorp_core:Server:OnPlayerRespawn", function(src)
    src = tonumber(src)
    if not src then return end
    pushRepeatedly(src, "respawn", { 1200, 2500, 5000 })
end)

-- restream after a carry
local RESTREAM_COOLDOWN <const> = 20000
local RESTREAM_BASE <const> = 90000 -- clear of the hideout/instance bucket ranges
local RESTREAM_MS <const> = 400 -- long enough out of view to drop the old copy
local lastRestream = {}

RegisterNetEvent("vorp_character:pupRestream", function()
    local _source <const> = source
    local now <const> = GetGameTimer()
    if lastRestream[_source] and now - lastRestream[_source] < RESTREAM_COOLDOWN then return end
    lastRestream[_source] = now

    local home <const> = GetPlayerRoutingBucket(_source)
    local temp <const> = RESTREAM_BASE + _source
    SetPlayerRoutingBucket(_source, temp)
    SetTimeout(RESTREAM_MS, function()
        if not GetPlayerName(_source) then return end
        -- only put them back if nothing else moved them meanwhile
        if GetPlayerRoutingBucket(_source) == temp then
            SetPlayerRoutingBucket(_source, home)
        end
        SetTimeout(500, function()
            if GetPlayerName(_source) then pushHeight(_source, "restream") end
        end)
    end)
end)

AddEventHandler("playerDropped", function()
    lastRequest[source] = nil
    lastRestream[source] = nil
end)
