-- Modified by Puppet (Dusk Till Dawn), 2026
-- VPN / proxy gate via proxycheck.io. Called from the connect deferral in bans.lua.

local VpnCfg = {
    enabled = true,
    apiKey = Secrets.ApiKeys.proxycheck or '', -- server/config.lua

    blockVpn = true,
    blockTor = true,
    blockProxy = true,  -- real tunnels only: SOCKS, Shadowsocks, HTTP(S), compromised

    -- these two control false positives
    days = 2,     -- how far back proxycheck looks (0.01-60); lower = fewer false alerts on dynamic IPs
    riskMin = 67, -- refuse only at or above this 0-100 risk score; 0 = off

    skipKnownPlayers = true,  -- anyone already in `users` is never screened
    allowlist = {},           -- licences that always pass

    httpTimeoutMs = 5000,
    cacheHours = 24,

    webhook = Secrets.Webhooks.vpnGate or '', -- server/config.lua; blank = adminBan, then default

    refuse = 'A VPN or proxy was detected on your connection.\n\nTurn it off and reconnect.\n\nOpen a ticket in Discord if you believe this is wrong.',
}

local cache = {}   -- ip -> { bad = bool, what = string, at = os.time() }

local function hook()
    if VpnCfg.webhook ~= '' then return VpnCfg.webhook end
    local W = Secrets.Webhooks
    return W.adminBan or W.default or ''
end

local function log(title, colour, lines)
    local url = hook()
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = (Config.Logs and Config.Logs.embedName) or 'VORP',
        embeds = { { title = title, description = table.concat(lines, '\n'), color = colour,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') } } },
    }), { ['Content-Type'] = 'application/json' })
end

local function httpGet(url)
    local p = promise.new()
    local settled = false
    PerformHttpRequest(url, function(status, body)
        if settled then return end
        settled = true
        p:resolve({ status = status, body = body })
    end, 'GET')
    SetTimeout(VpnCfg.httpTimeoutMs, function()
        if settled then return end
        settled = true
        p:resolve(nil) -- unknown, never a refusal
    end)
    return Citizen.Await(p)
end

local function isPrivate(ip)
    if not ip or ip == '' then return true end
    if ip == '127.0.0.1' or ip == 'localhost' then return true end
    if ip:match('^10%.') or ip:match('^192%.168%.') then return true end
    local a, b = ip:match('^172%.(%d+)%.')
    if a then
        local n = tonumber(a) or 0
        if n >= 16 and n <= 31 then return true end
    end
    return false
end

--- bad(boolean), what(string). An unknown answer is never bad.
local function lookup(ip)
    if isPrivate(ip) then return false, 'local address' end
    if VpnCfg.apiKey == '' then return false, 'no api key' end

    local hit = cache[ip]
    if hit and (os.time() - hit.at) < (VpnCfg.cacheHours * 3600) then
        return hit.bad, hit.what
    end

    -- risk=1 asks for the 0-100 score used below
    local res = httpGet(('https://proxycheck.io/v2/%s?key=%s&vpn=1&asn=1&risk=1&days=%s')
        :format(ip, VpnCfg.apiKey, tostring(VpnCfg.days or 2)))
    if not res or res.status ~= 200 or type(res.body) ~= 'string' then
        return false, 'lookup failed'
    end

    local ok, data = pcall(json.decode, res.body)
    if not ok or type(data) ~= 'table' then return false, 'bad response' end
    if data.status ~= 'ok' and data.status ~= 'warning' then
        return false, 'api said ' .. tostring(data.status)
    end

    local row = data[ip]
    if type(row) ~= 'table' then return false, 'no record' end

    local flagged <const> = tostring(row.proxy or 'no'):lower() == 'yes'
    local kind <const> = tostring(row.type or ''):lower()
    local provider <const> = tostring(row.provider or row.organisation or '?')
    local risk <const> = tonumber(row.risk)

    -- proxycheck also returns ordinary types (Residential, Wireless, Business, Hosting); only these are tunnels
    local PROXY_TYPES <const> = {
        'socks', 'shadowsocks', 'http', 'https', 'scraper', 'compromised',
    }
    local isTor <const> = kind:find('tor') ~= nil
    local isVpn <const> = kind:find('vpn') ~= nil
    local isProxy = false
    for _, t in ipairs(PROXY_TYPES) do
        if kind:find(t, 1, true) then isProxy = true; break end
    end

    local bad, why = false, nil
    if flagged then
        if isTor then bad, why = VpnCfg.blockTor, 'tor'
        elseif isVpn then bad, why = VpnCfg.blockVpn, 'vpn'
        elseif isProxy then bad, why = VpnCfg.blockProxy, 'proxy'
        else why = 'ordinary connection type' end
    end

    -- a flag with a low risk score is usually stale data
    local floor <const> = tonumber(VpnCfg.riskMin) or 0
    if bad and floor > 0 and risk ~= nil and risk < floor then
        bad, why = false, ('risk %d is under the floor of %d'):format(risk, floor)
    end

    local what
    if flagged then
        what = ('%s (%s)%s%s'):format(row.type or 'proxy', provider,
            risk and (' risk %d'):format(risk) or '',
            (not bad and why) and (' - allowed: ' .. why) or '')
    else
        what = 'clean'
    end

    cache[ip] = { bad = bad, what = what, at = os.time() }
    return bad, what
end

--- bad(boolean), what(string). Global so the ban-evasion report in bans.lua can say
--- whether an evader is on a VPN. Shares the cache, so it costs no extra lookup.
function VpnLookup(ip)
    local ok, bad, what = pcall(lookup, ip)
    if not ok then return false, 'lookup failed' end
    return bad, what
end

local function allowlisted(license)
    for _, l in ipairs(VpnCfg.allowlist or {}) do
        if l == license then return true end
    end
    return false
end

local function knownPlayer(license)
    if license == '' then return false end
    return MySQL.single.await('SELECT identifier FROM users WHERE identifier = ?', { license }) ~= nil
end

--- ok(boolean), refusalMessage(string|nil). Called from bans.lua, which passes the
--- connecting name because GetPlayerName is not readable during the deferral.
function VpnGateCheck(src, ids, update, pname)
    if not VpnCfg.enabled then return true end

    local license <const> = ids.license or ''
    if allowlisted(license) then return true end
    if VpnCfg.skipKnownPlayers and knownPlayer(license) then return true end

    local ip <const> = ids.ip or ''
    if isPrivate(ip) then return true end

    update(1, 1, 'checking your connection')

    local ok, bad, what = pcall(lookup, ip)
    if not ok then return true end -- fail open
    if not bad then return true end

    local name <const> = (pname and pname ~= '' and tostring(pname))
        or GetPlayerName(src) or '?'
    local discord <const> = ids.discord or ''
    local lines = {
        ('**Player:** %s'):format(name),
        ('**Detected:** %s'):format(what),
        ('**Licence:** `%s`'):format(license ~= '' and license or 'none'),
        -- the mention renders as their name inside an embed without pinging them
        ('**Discord:** %s'):format(discord ~= ''
            and ('<@%s> (`%s`)'):format(discord, discord)
            or 'none - Discord was not running'),
        ('**IP:** `%s`'):format(ip),
    }

    lines[#lines + 1] = '**Outcome:** connection REFUSED'
    log('VPN check: refused', 15158332, lines)
    print(('^1[vpngate]^7 refused %s - %s'):format(name, what))
    return false, VpnCfg.refuse
end

-- /vpncheck <ip>
RegisterCommand('vpncheck', function(src, args)
    src = tonumber(src) or 0
    if src > 0 and not IsPlayerAceAllowed(src, 'command.vpncheck') then return end
    local ip = tostring(args[1] or '')
    if ip == '' then return print('[vpngate] usage: vpncheck <ip>') end

    CreateThread(function()
        cache[ip] = nil -- fresh answer when asked by hand
        local ok, bad, what = pcall(lookup, ip)
        local msg = ok and ('%s -> %s (%s)'):format(ip, bad and 'WOULD REFUSE' or 'allowed', what)
            or ('%s -> lookup error'):format(ip)
        print('[vpngate] ' .. msg)
        if src > 0 then TriggerClientEvent('vorp:TipRight', src, msg, 8000) end
    end)
end, false)

CreateThread(function()
    Wait(2500)
    if not VpnCfg.enabled then return end
    if VpnCfg.apiKey == '' then
        return print('^1[vpngate]^7 enabled but no proxycheck.io apiKey - every connect will pass')
    end
    print(('^2[vpngate]^7 ready - enforcing, known players skipped=%s'):format(
        tostring(VpnCfg.skipKnownPlayers)))
end)
