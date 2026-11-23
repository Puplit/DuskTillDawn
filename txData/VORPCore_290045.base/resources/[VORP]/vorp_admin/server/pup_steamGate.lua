-- Modified by Puppet (Dusk Till Dawn), 2026
-- Steam account-age gate, called from the connect deferral in bans.lua.

local SteamCfg = {
    enabled = true,

    minAccountDays = 30,

    -- no Steam running = no steam: identifier; allowing that also lets the check be skipped
    requireSteam = false,

    allowIfUnreadable = true, -- private profile hides the creation date
    skipKnownPlayers = true,  -- anyone already in `users` is never re-screened
    allowlist = {},           -- 'license:xxxx' exactly as the identifier reads

    httpTimeoutMs = 6000,

    -- cached to keep connect time down, not for the Steam rate limit
    passTtl = 6 * 60 * 60,
    failTtl = 10 * 60,

    webhook = Secrets.Webhooks.steamGate or '', -- server/config.lua steamGate; blank = default

    refuse = {
        tooNew     = 'Your Steam account is too new to join Dusk Till Dawn.\n\nAccounts must be at least %d days old. Yours is %d.\n\nOpen a ticket in Discord if you believe this is wrong.',
        unreadable = 'We cannot read your Steam account.\n\nSet your Steam profile to Public, then reconnect.\nSteam > Profile > Edit Profile > Privacy Settings.\n\nOpen a ticket in Discord if you need help.',
        noSteam    = 'Steam must be running to join Dusk Till Dawn.\n\nStart Steam, then reconnect.\n\nOpen a ticket in Discord if you need help.',
    },
}

local API <const> = 'https://api.steampowered.com'
local cache = {} -- steamid64 -> { ok, msg, at }

local function apiKey()
    local k = GetConvar('steam_webApiKey', '')
    return (k ~= '' and k) or nil
end

local function hook()
    if SteamCfg.webhook ~= '' then return SteamCfg.webhook end
    return Secrets.Webhooks.default or ''
end

-- the URL carries the API key, so it is never logged
local function httpGet(url)
    local p = promise.new()
    local settled = false
    PerformHttpRequest(url, function(status, body)
        if settled then return end
        settled = true
        p:resolve({ status = status, body = body })
    end, 'GET')
    SetTimeout(SteamCfg.httpTimeoutMs, function()
        if settled then return end
        settled = true
        p:resolve(nil) -- Steam down reads as unreadable, never as a refusal
    end)
    return Citizen.Await(p)
end

local function getJson(url)
    local res = httpGet(url)
    if not res or res.status ~= 200 or type(res.body) ~= 'string' then return nil end
    local ok, parsed = pcall(json.decode, res.body)
    return ok and parsed or nil
end

-- the steam: identifier is hex; Lua's 64-bit integers convert it exactly
local function steamId64(ident)
    local hex = tostring(ident or ''):match('^steam:(%x+)$')
    if not hex then return nil end
    local n = tonumber(hex, 16)
    if not n then return nil end
    return ('%d'):format(n)
end

local function log(title, colour, lines)
    local url = hook()
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = (Config.Logs and Config.Logs.embedName) or 'VORP',
        embeds = { { title = title, description = table.concat(lines, '\n'),
            color = colour, footer = { text = os.date('%Y-%m-%d %H:%M:%S') } } },
    }), { ['Content-Type'] = 'application/json' })
end

-- bans.lua strips the prefix, so ids.discord is the bare snowflake
local function discordOf(ids)
    local d = ids and ids.discord or ''
    if d == '' then return 'none - Discord was not running' end
    return ('<@%s> (`%s`)'):format(d, d)
end

local function isAllowlisted(license)
    for _, l in ipairs(SteamCfg.allowlist or {}) do
        if l == license then return true end
    end
    return false
end

local function isKnownPlayer(license)
    if license == '' then return false end
    local row = MySQL.single.await('SELECT identifier FROM users WHERE identifier = ?', { license })
    return row ~= nil
end

--- ok(boolean), refusalMessage(string|nil), lines(table)
local function judge(sid, name)
    local key = apiKey()
    if not key then
        return true, nil, { 'No steam_webApiKey convar set - gate skipped' }
    end

    local lines = { ('**Player:** %s'):format(tostring(name)), ('**SteamID64:** `%s`'):format(sid) }

    local sum = getJson(('%s/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s'):format(API, key, sid))
    local player = sum and sum.response and sum.response.players and sum.response.players[1] or nil
    local visibility = player and tonumber(player.communityvisibilitystate) or nil
    local created = player and tonumber(player.timecreated) or nil

    lines[#lines + 1] = ('**Profile visibility:** %s'):format(
        visibility == 3 and 'public' or (visibility and ('restricted (%d)'):format(visibility) or 'unknown'))
    lines[#lines + 1] = ('**Account created:** %s'):format(
        created and os.date('%Y-%m-%d', created) or 'hidden')

    if created then
        local days = math.floor((os.time() - created) / 86400)
        lines[#lines + 1] = ('**Age:** %d days (minimum %d)'):format(days, SteamCfg.minAccountDays)
        if days >= SteamCfg.minAccountDays then
            lines[#lines + 1] = '**Outcome:** allowed'
            return true, nil, lines
        end
        lines[#lines + 1] = '**Outcome:** REFUSED - account too new'
        return false, SteamCfg.refuse.tooNew:format(SteamCfg.minAccountDays, days), lines
    end

    -- creation date hidden: nothing to judge on
    if SteamCfg.allowIfUnreadable then
        lines[#lines + 1] = '**Outcome:** allowed - creation date hidden, allowIfUnreadable is on'
        return true, nil, lines
    end
    lines[#lines + 1] = '**Outcome:** REFUSED - profile is private'
    return false, SteamCfg.refuse.unreadable, lines
end

--- ok(boolean), refusalMessage(string|nil). Called from bans.lua; update() drives
--- the connect screen.
function SteamGateCheck(src, ids, update, pname)
    if not SteamCfg.enabled then return true end

    -- bans.lua passes the connecting name: GetPlayerName is not readable yet here
    local who <const> = (pname and pname ~= '' and tostring(pname))
        or GetPlayerName(src) or '?'

    update(1, 2, 'reading your Steam account')

    local license <const> = ids.license or ''
    if isAllowlisted(license) then return true end

    if SteamCfg.skipKnownPlayers and isKnownPlayer(license) then return true end

    local sid = steamId64(ids.steam)
    if not sid then
        if SteamCfg.requireSteam then
            log('Steam gate: refused (Steam not running)', 15158332, {
                ('**Player:** %s'):format(who),
                ('**Licence:** `%s`'):format(license ~= '' and license or 'none'),
                ('**Discord:** %s'):format(discordOf(ids)),
                '**Outcome:** REFUSED - no steam identifier and requireSteam is on',
            })
            return false, SteamCfg.refuse.noSteam
        end
        return true
    end

    local hit = cache[sid]
    if hit and (os.time() - hit.at) < (hit.ok and SteamCfg.passTtl or SteamCfg.failTtl) then
        return hit.ok, hit.msg
    end

    update(2, 2, 'checking how old it is')

    local ok, msg, lines = judge(sid, who)
    cache[sid] = { ok = ok, msg = msg, at = os.time() }

    lines[#lines + 1] = ('**Licence:** `%s`'):format(license ~= '' and license or 'none')
    -- the mention renders as their name inside an embed without pinging them
    lines[#lines + 1] = ('**Discord:** %s'):format(discordOf(ids))
    log(ok and 'Steam gate: allowed' or 'Steam gate: REFUSED',
        ok and 3066993 or 15158332, lines)

    return ok, msg
end

-- /steamcheck <steamid64 | hex | steam:hex>
RegisterCommand('steamcheck', function(src, args)
    src = tonumber(src) or 0
    if src > 0 and not IsPlayerAceAllowed(src, 'command.steamcheck') then return end

    local raw = tostring(args[1] or '')
    -- a decimal SteamID64 is also valid hex, so match it first
    local sid
    if raw:match('^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$') then
        sid = raw
    else
        sid = steamId64(raw) or steamId64('steam:' .. raw)
    end
    if not sid then return print('[steamgate] usage: steamcheck <steamid64 | hex | steam:hex>') end

    CreateThread(function()
        local ok, msg, lines = judge(sid, 'manual check')
        print(('[steamgate] %s -> %s'):format(sid, ok and 'ALLOWED' or 'REFUSED'))
        for _, l in ipairs(lines) do print('  ' .. (l:gsub('%*%*', ''))) end
        if msg then print('  message: ' .. msg:gsub('\n', ' / ')) end
        if src > 0 then
            TriggerClientEvent('vorp:TipRight', src,
                ('Steam check %s - see server console'):format(ok and 'ALLOWED' or 'REFUSED'), 6000)
        end
    end)
end, false)

CreateThread(function()
    Wait(2000)
    if not SteamCfg.enabled then return print('^3[steamgate]^7 disabled') end
    if not apiKey() then
        return print('^1[steamgate]^7 no steam_webApiKey convar - the gate will pass everyone')
    end
    print(('^2[steamgate]^7 ready - min account age %d days, requireSteam=%s, known players skipped=%s')
        :format(SteamCfg.minAccountDays, tostring(SteamCfg.requireSteam),
            tostring(SteamCfg.skipKnownPlayers)))
end)
