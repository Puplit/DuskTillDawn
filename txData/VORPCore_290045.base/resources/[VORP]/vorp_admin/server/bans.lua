-- Modified by Puppet (Dusk Till Dawn), 2026
-- SERVER BANS. One row per ban, enforced at playerConnecting.
-- Matched on: license (primary), steam/discord (only if that app was running),
-- tokens (hardware, shared between players so one is not enough), ip (off by default).

-- webhooks and keys come from server/config.lua (loaded first)
Secrets.Webhooks = Secrets.Webhooks or {}
Secrets.ApiKeys = Secrets.ApiKeys or {}

local BanCfg = {
    tokenMatchMin = 1,  -- hardware tokens that must match to count as the same machine
    matchIp = false,    -- off: catches whole households and misses a VPN anyway
    -- what the player sees. {reason} and {id} are filled in.
    message = 'You are banned from Dusk Till Dawn.\n\nReason: {reason}\nBan ID: {id}\n\nAppeal in Discord with that ID.',
    messageTemp = 'You are banned from Dusk Till Dawn until {until}.\n\nReason: {reason}\nBan ID: {id}\n\nAppeal in Discord with that ID.',

    -- minimum a connect step stays readable; the five steps are counted in code
    stepMs = 220,

    -- server/config.lua bansMatch. Blank uses adminBan, then default
    matchWebhook = Secrets.Webhooks.bansMatch or '',
    -- log a shared machine or address even when it was too weak to refuse the connect
    logNearMisses = true,

    -- hardware/IP match reports. Blank = same channel as matchWebhook.
    hwidWebhook = Secrets.Webhooks.bansHwid or '',

    identityKeepDays = 365,  -- how long a remembered identity is kept. 0 never prunes.

    -- server/config.lua bansPublic: a public channel that announces bans and lifted bans. Blank = off.
    publicWebhook = Secrets.Webhooks.bansPublic or '',
    publicLogUnbans = true,
    publicPreferCharName = true,
    -- blank keeps whatever name the webhook itself is set to in Discord
    publicName = 'Dusk Till Dawn',
}

-- resolved on first use: this file loads before vorp_core may be up
local BansCore
local function core()
    if not BansCore then
        local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
        if ok then BansCore = c end
    end
    return BansCore
end

local ID_ALPHABET <const> = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' -- no I/O/0/1

local function newBanId()
    local out = {}
    for i = 1, 9 do
        if i == 5 then
            out[i] = '-'
        else
            local n = math.random(#ID_ALPHABET)
            out[i] = ID_ALPHABET:sub(n, n)
        end
    end
    return table.concat(out)
end

-- One-time move from the old table names (pup_bans / pup_ban_identities): an older database keeps its
-- bans. Only when the old table exists and the new one does not; never overwrites anything.
local function renameOldTable(old, new)
    local function has(name)
        return (tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) or 0) > 0
    end
    if not has(old) then return end
    if has(new) then
        print(('^3[bans]^7 both %s and %s exist: using %s, the old table is left alone'):format(old, new, new))
        return
    end
    MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(old, new), {})
    print(('^2[bans]^7 renamed table %s to %s'):format(old, new))
end

CreateThread(function()
    renameOldTable('pup_bans', 'admin_bans')
    renameOldTable('pup_ban_identities', 'admin_ban_identities')

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `admin_bans` (
            `id`          INT AUTO_INCREMENT PRIMARY KEY,
            `ban_id`      VARCHAR(16)  NOT NULL,
            `charid`      INT          NULL,
            `charname`    VARCHAR(100) NOT NULL DEFAULT '',
            `playername`  VARCHAR(100) NOT NULL DEFAULT '',
            `license`     VARCHAR(80)  NOT NULL DEFAULT '',
            `license2`    VARCHAR(80)  NOT NULL DEFAULT '',
            `steam`       VARCHAR(50)  NOT NULL DEFAULT '',
            `discord`     VARCHAR(40)  NOT NULL DEFAULT '',
            `xbl`         VARCHAR(40)  NOT NULL DEFAULT '',
            `liveid`      VARCHAR(40)  NOT NULL DEFAULT '',
            `ip`          VARCHAR(64)  NOT NULL DEFAULT '',
            `tokens`      LONGTEXT     NULL,
            `reason`      VARCHAR(512) NOT NULL DEFAULT '',
            `staff`       VARCHAR(100) NOT NULL DEFAULT '',
            `created`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires`     INT          NOT NULL DEFAULT 0,
            `active`      TINYINT(1)   NOT NULL DEFAULT 1,
            `unbanned_by` VARCHAR(100) NULL,
            `unbanned_at` TIMESTAMP    NULL,
            UNIQUE KEY `ban_id_idx` (`ban_id`),
            KEY `license_idx` (`license`),
            KEY `steam_idx` (`steam`),
            KEY `discord_idx` (`discord`),
            KEY `active_idx` (`active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})

    -- Last known identity per steam id, written on every clean connect. An offline
    -- ban can only read characters.identifier, which is the steam id alone.
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `admin_ban_identities` (
            `steam`      VARCHAR(50)  NOT NULL,
            `license`    VARCHAR(80)  NOT NULL DEFAULT '',
            `license2`   VARCHAR(80)  NOT NULL DEFAULT '',
            `discord`    VARCHAR(40)  NOT NULL DEFAULT '',
            `ip`         VARCHAR(64)  NOT NULL DEFAULT '',
            `tokens`     LONGTEXT     NULL,
            `playername` VARCHAR(100) NOT NULL DEFAULT '',
            `last_seen`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`steam`),
            KEY `license_idx` (`license`),
            KEY `last_seen_idx` (`last_seen`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})

    -- one row per player: `created` is the LATEST ban, these two keep the history
    MySQL.query.await("ALTER TABLE `admin_bans` ADD COLUMN IF NOT EXISTS `ban_count` INT NOT NULL DEFAULT 1", {})
    MySQL.query.await("ALTER TABLE `admin_bans` ADD COLUMN IF NOT EXISTS `first_banned` TIMESTAMP NULL DEFAULT NULL", {})
    MySQL.query.await("UPDATE `admin_bans` SET `first_banned` = `created` WHERE `first_banned` IS NULL", {})

    local keep <const> = tonumber(BanCfg.identityKeepDays) or 0
    if keep > 0 then
        MySQL.update('DELETE FROM admin_ban_identities WHERE last_seen < DATE_SUB(NOW(), INTERVAL ? DAY)', { keep })
    end

    print('^2[bans]^7 ready - token match floor ' .. BanCfg.tokenMatchMin ..
          ', ip matching ' .. (BanCfg.matchIp and 'ON' or 'off'))
end)

-- ------------------------------------------------------------------ identity

-- every identifier the engine will give us, by prefix
local function identsOf(src)
    local out = { license = '', license2 = '', steam = '', discord = '', xbl = '', liveid = '', ip = '' }
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local kind, value = id:match('^(%w+):(.+)$')
        if kind == 'license' and out.license == '' then out.license = id
        elseif kind == 'license2' then out.license2 = id
        elseif kind == 'steam' then out.steam = id
        elseif kind == 'discord' then out.discord = value
        elseif kind == 'xbl' then out.xbl = value
        elseif kind == 'live' then out.liveid = value
        elseif kind == 'ip' then out.ip = value end
    end
    return out
end

local function tokensOf(src)
    local out = {}
    local ok = pcall(function()
        for i = 0, (GetNumPlayerTokens(src) or 0) - 1 do
            local t = GetPlayerToken(src, i)
            if t and t ~= '' then out[#out + 1] = t end
        end
    end)
    if not ok then return {} end
    return out
end

local function decodeTokens(v)
    if type(v) ~= 'string' or v == '' then return {} end
    local ok, out = pcall(json.decode, v)
    return (ok and type(out) == 'table') and out or {}
end

-- Fire and forget; a connect must not wait on it. Nothing is overwritten with a
-- blank, so a connect that read no tokens cannot wipe an earlier good set.
local function rememberIdentity(ids, tokens, pname)
    if not ids or ids.steam == '' then return end
    MySQL.insert([[
        INSERT INTO admin_ban_identities
            (steam, license, license2, discord, ip, tokens, playername)
        VALUES (?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE
            license    = IF(VALUES(license)    <> '', VALUES(license),    license),
            license2   = IF(VALUES(license2)   <> '', VALUES(license2),   license2),
            discord    = IF(VALUES(discord)    <> '', VALUES(discord),    discord),
            ip         = IF(VALUES(ip)         <> '', VALUES(ip),         ip),
            playername = IF(VALUES(playername) <> '', VALUES(playername), playername),
            tokens     = IF(? > 0, VALUES(tokens), tokens),
            last_seen  = CURRENT_TIMESTAMP
    ]], { ids.steam, ids.license, ids.license2, ids.discord, ids.ip,
          json.encode(tokens or {}), pname or '', #(tokens or {}) })
end

local function lastKnownIdentity(steam)
    if not steam or steam == '' then return nil end
    return MySQL.single.await('SELECT * FROM admin_ban_identities WHERE steam = ?', { steam })
end

-- ------------------------------------------------------------------ matching

-- oxmysql hands TINYINT(1) back as a BOOLEAN, so tonumber() on it is nil and every
-- "== 1" test would silently fail. Both shapes are accepted here.
local function truthy(v)
    return v == true or v == 1 or tonumber(v) == 1
end

local function isLive(row)
    if not truthy(row.active) then return false end
    local exp = tonumber(row.expires) or 0
    return exp == 0 or exp > os.time()
end

-- only the bans still in force, read once per connect
local function fetchActiveBans()
    local rows = MySQL.query.await('SELECT * FROM admin_bans WHERE active = 1', {}) or {}
    local live = {}
    for _, row in ipairs(rows) do
        if isLive(row) then live[#live + 1] = row end
    end
    return live
end

--- An exact identifier is decisive on its own.
local function matchExact(rows, ids)
    for _, row in ipairs(rows) do
        if ids.license ~= '' and row.license == ids.license then return row, 'license' end
        if ids.steam ~= '' and row.steam == ids.steam then return row, 'steam' end
        if ids.discord ~= '' and row.discord == ids.discord then return row, 'discord' end
    end
    return nil
end

-- a loopback or blank address is shared by everyone and means nothing
local function usableIp(ip)
    return ip ~= nil and ip ~= '' and ip ~= '127.0.0.1' and ip ~= 'localhost'
end

--- Blocking row (tokens at or over the floor), plus weaker signals worth seeing
local function matchFuzzy(rows, ids, tokens)
    local tokenSet = {}
    for _, t in ipairs(tokens) do tokenSet[t] = true end

    local floor <const> = math.max(1, BanCfg.tokenMatchMin)
    local hit, hitCount = nil, 0
    local near, ipHits = {}, {}

    for _, row in ipairs(rows) do
        local hits = 0
        for _, t in ipairs(decodeTokens(row.tokens)) do
            if tokenSet[t] then hits = hits + 1 end
        end
        if hits >= floor then
            if not hit then hit, hitCount = row, hits end
        elseif hits > 0 then
            near[#near + 1] = { row = row, hits = hits }
        end

        if usableIp(ids.ip) and row.ip == ids.ip then
            ipHits[#ipHits + 1] = row
        end
    end

    return hit, hitCount, near, ipHits
end

-- ------------------------------------------------------------------- the log

local function matchHook()
    if BanCfg.matchWebhook ~= '' then return BanCfg.matchWebhook end
    local W = Secrets.Webhooks
    return W.adminBan or W.default or ''
end

-- hardware/address matches get their own channel: leads to read, not ban records
local function hwidHook()
    if BanCfg.hwidWebhook ~= '' then return BanCfg.hwidWebhook end
    return matchHook()
end

local function postEmbed(title, colour, lines, url)
    local hook = url or matchHook()
    if hook == '' then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({
        username = (Config.Logs and Config.Logs.embedName) or 'VORP',
        embeds = { {
            title = title,
            description = table.concat(lines, '\n'),
            color = colour,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

-- red when refused, orange when it was only a signal
local function logMatch(blocked, title, lines)
    postEmbed(title, blocked and 15158332 or 15105570, lines, hwidHook())
end

local function publicName(pname, charname)
    if BanCfg.publicPreferCharName and charname and charname ~= '' then return charname end
    if pname and pname ~= '' then return pname end
    if charname and charname ~= '' then return charname end
    return 'Someone'
end

-- one line, no title. A mention inside an embed renders as a name without pinging.
local function publicLog(colour, text, discordId)
    local url = BanCfg.publicWebhook
    if not url or url == '' then return end

    if discordId and discordId ~= '' then
        text = ('%s   <@%s>'):format(text, discordId)
    end

    local body = { embeds = { { description = text, color = colour } } }
    if BanCfg.publicName and BanCfg.publicName ~= '' then
        body.username = BanCfg.publicName
    end

    PerformHttpRequest(url, function() end, 'POST', json.encode(body),
        { ['Content-Type'] = 'application/json' })
end

local function banLabel(row)
    local who = row.playername or ''
    if who == '' then who = row.charname or '' end
    if who == '' then who = 'unknown' end
    return ('`%s` (%s)'):format(tostring(row.ban_id), who)
end

--- One report for everything the fuzzy pass found, refused or not
local function reportFuzzy(name, ids, tokenCount, blockedBy, hitRow, hitCount, near, ipHits)
    local hasHardware = hitRow ~= nil or #near > 0
    local hasIp = #ipHits > 0
    if not hasHardware and not hasIp then return end
    if not BanCfg.logNearMisses and not hitRow and not (BanCfg.matchIp and hasIp) then return end

    local lines = {
        ('**Player:** %s'):format(tostring(name)),
        ('**Licence:** `%s`'):format(ids.license ~= '' and ids.license or 'none'),
        -- the mention renders as their name inside an embed without pinging them
        ('**Discord:** %s'):format(ids.discord ~= ''
            and ('<@%s> (`%s`)'):format(ids.discord, ids.discord)
            or 'none - Discord was not running'),
        ('**Hardware tokens read:** %d'):format(tokenCount),
    }

    if usableIp(ids.ip) then
        -- VpnLookup is global at call time (pup_vpnGate loads after this file) and is
        -- cached, so asking here costs nothing the VPN gate was not about to pay anyway
        local vpn = ''
        if VpnLookup then
            local bad, what = VpnLookup(ids.ip)
            vpn = bad and (' - **VPN/PROXY: %s**'):format(tostring(what))
                or (' - %s'):format(tostring(what or 'clean'))
        end
        lines[#lines + 1] = ('**IP:** `%s`%s'):format(ids.ip, vpn)
    end

    if hitRow then
        lines[#lines + 1] = ('**Hardware match:** %s - %d of %d tokens, at or over the floor of %d')
            :format(banLabel(hitRow), hitCount, tokenCount, math.max(1, BanCfg.tokenMatchMin))
    end
    -- a shared token can match dozens of rows; the embed description has a limit
    local LIST_CAP <const> = 6

    for i, n in ipairs(near) do
        if i > LIST_CAP then
            lines[#lines + 1] = ('...and %d more weak hardware match(es)'):format(#near - LIST_CAP)
            break
        end
        lines[#lines + 1] = ('**Weak hardware match:** %s - only %d token(s), floor is %d, NOT refused on this')
            :format(banLabel(n.row), n.hits, math.max(1, BanCfg.tokenMatchMin))
    end

    for i, row in ipairs(ipHits) do
        if i > LIST_CAP then
            lines[#lines + 1] = ('...and %d more ban(s) on that address'):format(#ipHits - LIST_CAP)
            break
        end
        lines[#lines + 1] = ('**Same IP as:** %s%s'):format(banLabel(row),
            BanCfg.matchIp and '' or ' - IP matching is off, NOT refused on this')
    end

    lines[#lines + 1] = blockedBy
        and ('**Outcome:** connection REFUSED (matched on %s)'):format(blockedBy)
        or '**Outcome:** allowed in - worth a look if this name is new to you'

    logMatch(blockedBy ~= nil,
        blockedBy and 'Ban evasion blocked' or 'Ban list: possible evasion',
        lines)
end

local function banMessage(row)
    local exp <const> = tonumber(row.expires) or 0
    local tpl = exp == 0 and BanCfg.message or BanCfg.messageTemp
    return (tpl
        :gsub('{reason}', (row.reason ~= '' and row.reason or 'No reason given'))
        :gsub('{id}', row.ban_id)
        :gsub('{until}', exp == 0 and '' or os.date('%d %b %Y, %H:%M', exp)))
end

-- ------------------------------------------------------------------- the gate

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src <const> = source -- captured BEFORE any yield, or it is gone
    deferrals.defer()
    Wait(0) -- required: one tick between defer() and anything else

    -- one per step() call below; change both together
    local STAGES <const> = 5
    local function step(n, what)
        deferrals.update(('Checking banlist %d/%d - %s'):format(n, STAGES, what))
        Wait(BanCfg.stepMs or 220)
    end

    -- wrapped so any failure lets the player IN rather than locking the server
    local ok, err = pcall(function()
        step(1, 'reading your identifiers')
        local ids = identsOf(src)

        step(2, 'reading hardware tokens')
        local tokens = tokensOf(src)

        -- RECORDED HERE, BEFORE ANY REFUSAL. Every branch below can return, so a near
        -- miss later refused by the Steam or VPN gate still leaves something to ban
        -- them by. Fire and forget, no yield,
        -- and the upsert never overwrites good data with a blank.
        rememberIdentity(ids, tokens, tostring(name or ''))

        step(3, 'fetching the ban list')
        local rows = fetchActiveBans()

        step(4, 'matching account identifiers')
        local exact, why = matchExact(rows, ids)
        if exact then
            print(('^1[bans]^7 refused %s - ban %s matched on %s'):format(
                tostring(name), exact.ban_id, tostring(why)))
            deferrals.done(banMessage(exact))
            return
        end

        step(5, 'matching hardware and address')
        local hitRow, hitCount, near, ipHits = matchFuzzy(rows, ids, tokens)

        local blockRow, blockWhy
        if hitRow then
            blockRow, blockWhy = hitRow, ('hardware (%d tokens)'):format(hitCount)
        elseif BanCfg.matchIp and #ipHits > 0 then
            blockRow, blockWhy = ipHits[1], 'ip'
        end

        -- logged either way: a refusal is evidence, a near miss is a lead
        reportFuzzy(name, ids, #tokens, blockWhy, hitRow, hitCount, near, ipHits)

        if blockRow then
            print(('^1[bans]^7 refused %s - ban %s matched on %s'):format(
                tostring(name), blockRow.ban_id, tostring(blockWhy)))
            deferrals.done(banMessage(blockRow))
            return
        end

        -- global at call time: pup_steamGate.lua loads after this file. `name` is passed
        -- because GetPlayerName is not readable yet during the connect deferral.
        if SteamGateCheck then
            local passed, refusal = SteamGateCheck(src, ids, function(n, of, what)
                deferrals.update(('Checking Steam account %d/%d - %s'):format(n, of, what))
                Wait(BanCfg.stepMs or 220)
            end, name)
            if not passed then
                print(('^1[bans]^7 refused %s - steam gate'):format(tostring(name)))
                deferrals.done(refusal or 'Your Steam account does not meet our entry requirement.')
                return
            end
        end

        -- global at call time: pup_vpnGate.lua loads after this file
        if VpnGateCheck then
            local passed, refusal = VpnGateCheck(src, ids, function(n, of, what)
                deferrals.update(('Checking connection %d/%d - %s'):format(n, of, what))
                Wait(BanCfg.stepMs or 220)
            end, name)
            if not passed then
                print(('^1[bans]^7 refused %s - vpn gate'):format(tostring(name)))
                deferrals.done(refusal or 'A VPN or proxy was detected on your connection.')
                return
            end
        end

        deferrals.update(('Checking banlist %d/%d - clear, welcome in'):format(STAGES, STAGES))
        Wait(0)
        deferrals.done()
    end)

    if not ok then
        print('^1[bans]^7 check failed for ' .. tostring(name) .. ': ' .. tostring(err))
        Wait(0)
        -- they may already be gone, which makes done() throw as well
        pcall(deferrals.done) -- fail open
    end
end)

-- ------------------------------------------------------------------- the acts

-- Any previous ban row for the SAME person, lifted or not. Identifiers only:
-- hardware is left to the connect gate, where a shared machine is a lead rather
-- than proof, and folding two housemates into one profile would be wrong here.
local function findPriorBan(ids)
    if ids.license == '' and ids.steam == '' and ids.discord == '' then return nil end
    return MySQL.single.await([[
        SELECT * FROM admin_bans
        WHERE (license <> '' AND license = ?)
           OR (steam   <> '' AND steam   = ?)
           OR (discord <> '' AND discord = ?)
        ORDER BY id DESC LIMIT 1
    ]], { ids.license, ids.steam, ids.discord })
end

-- keep every token ever seen for them: a reconnect can report a different subset,
-- so the union is a better fingerprint than whichever set the last ban happened to read
local function mergeTokens(stored, fresh)
    local out, seen = {}, {}
    for _, list in ipairs({ stored or {}, fresh or {} }) do
        for _, t in ipairs(list) do
            if type(t) == 'string' and t ~= '' and not seen[t] then
                seen[t] = true
                out[#out + 1] = t
            end
        end
    end
    return out
end

--- Ban someone. `target` may be a live server id, or a table of identifiers for
--- an offline ban. Returns the ban id.
function BanPlayer(target, reason, staff, seconds)
    local ids, tokens, pname = nil, {}, ''

    local recalled = false

    if type(target) == 'table' then
        ids = {
            license = target.license or '', license2 = target.license2 or '',
            steam = target.steam or '', discord = target.discord or '',
            xbl = '', liveid = '', ip = target.ip or '',
        }
        tokens = target.tokens or {}
        pname = target.name or ''

        -- an offline ban arrives with a steam id alone; fill the rest from their last connect
        if ids.steam ~= '' and (ids.license == '' or #tokens == 0) then
            local seen = lastKnownIdentity(ids.steam)
            if seen then
                if ids.license  == '' then ids.license  = seen.license  or '' end
                if ids.license2 == '' then ids.license2 = seen.license2 or '' end
                if ids.discord  == '' then ids.discord  = seen.discord  or '' end
                if ids.ip       == '' then ids.ip       = seen.ip       or '' end
                if pname        == '' then pname        = seen.playername or '' end
                if #tokens == 0 then tokens = decodeTokens(seen.tokens) end
                recalled = (ids.license ~= '' or #tokens > 0)
            end
        end
    else
        local src = tonumber(target)
        if not src or GetPlayerName(src) == nil then return nil, 'that player is not online' end
        ids = identsOf(src)
        tokens = tokensOf(src)
        pname = GetPlayerName(src) or ''
    end

    if ids.license == '' and ids.steam == '' and ids.discord == '' and #tokens == 0 then
        return nil, 'nothing to ban them by'
    end

    -- charid and name, when the ban is on someone with a character loaded
    local charid, charname = nil, ''
    if type(target) ~= 'table' then
        local c = core()
        local user = c and c.getUser(tonumber(target))
        local ch = user and user.getUsedCharacter
        if ch then
            charid = ch.charIdentifier
            charname = ((ch.firstname or '') .. ' ' .. (ch.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
    end

    local expires = (tonumber(seconds) or 0) > 0 and (os.time() + math.floor(tonumber(seconds))) or 0

    -- ONE ROW PER PLAYER. A repeat offender reuses their row: the reason, date,
    -- staff and length are overwritten, the token set grows, and the ban id they
    -- already know stays theirs. A blank never overwrites something we had.
    local prior = findPriorBan(ids)
    local banId, banCount
    if prior then
        banId    = prior.ban_id
        banCount = (tonumber(prior.ban_count) or 1) + 1
        tokens   = mergeTokens(decodeTokens(prior.tokens), tokens)
        MySQL.update.await([[
            UPDATE admin_bans SET
                charid      = COALESCE(?, charid),
                charname    = IF(? <> '', ?, charname),
                playername  = IF(? <> '', ?, playername),
                license     = IF(? <> '', ?, license),
                license2    = IF(? <> '', ?, license2),
                steam       = IF(? <> '', ?, steam),
                discord     = IF(? <> '', ?, discord),
                ip          = IF(? <> '', ?, ip),
                tokens      = ?,
                reason      = ?,
                staff       = ?,
                expires     = ?,
                created     = CURRENT_TIMESTAMP,
                active      = 1,
                ban_count   = ?,
                unbanned_by = NULL,
                unbanned_at = NULL
            WHERE ban_id = ?
        ]], { charid,
              charname, charname, pname, pname,
              ids.license, ids.license, ids.license2, ids.license2,
              ids.steam, ids.steam, ids.discord, ids.discord, ids.ip, ids.ip,
              json.encode(tokens),
              tostring(reason or ''):sub(1, 512), tostring(staff or 'console'):sub(1, 100),
              expires, banCount, banId })
    else
        banId, banCount = newBanId(), 1
        MySQL.insert.await([[
            INSERT INTO admin_bans
                (ban_id, charid, charname, playername, license, license2, steam, discord,
                 xbl, liveid, ip, tokens, reason, staff, expires, ban_count, first_banned)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)
        ]], { banId, charid, charname, pname, ids.license, ids.license2, ids.steam, ids.discord,
              ids.xbl, ids.liveid, ids.ip, json.encode(tokens),
              tostring(reason or ''):sub(1, 512), tostring(staff or 'console'):sub(1, 100),
              expires, banCount })
    end

    -- drop them now if they are still on
    if type(target) ~= 'table' then
        local src = tonumber(target)
        if src and GetPlayerName(src) then
            DropPlayer(src, banMessage({ ban_id = banId, reason = reason or '', expires = expires }))
        end
    end

    -- token count printed so it is obvious whether the hardware half caught anything
    print(('^1[bans]^7 %s banned %s (%s) - %s [%d hardware token(s), licence %s, offence #%d]'):format(
        tostring(staff or 'console'), pname, banId, tostring(reason),
        #tokens, ids.license ~= '' and 'yes' or 'NO', banCount))

    postEmbed(banCount > 1 and ('Ban placed - REPEAT OFFENDER (#%d)'):format(banCount) or 'Ban placed',
    15158332, {
        ('**Ban ID:** `%s`'):format(banId),
        ('**Offence:** %s'):format(banCount > 1
            and ('number %d for this player - same record reused'):format(banCount) or 'first'),
        ('**Player:** %s'):format(pname ~= '' and pname or 'unknown'),
        ('**Character:** %s'):format(charname ~= '' and charname or 'none loaded'),
        ('**Staff:** %s'):format(tostring(staff or 'console')),
        ('**Reason:** %s'):format(tostring(reason or 'No reason given')),
        ('**Length:** %s'):format(expires == 0 and 'permanent'
            or ('until ' .. os.date('%d %b %Y, %H:%M', expires))),
        ('**Type:** %s'):format(type(target) == 'table'
            and ('offline' .. (recalled and ' (identity recalled from their last connect)' or ' - never seen since this was added, steam id only'))
            or 'online'),
        ('**Captured:** licence %s, steam %s, discord %s, %d hardware token(s)'):format(
            ids.license ~= '' and 'yes' or '**NO**',
            ids.steam ~= '' and 'yes' or 'no',
            ids.discord ~= '' and 'yes' or 'no', #tokens),
    })

    publicLog(15158332, ('🔨  **%s** has been run out of Dusk Till Dawn `%s`. Reason: `%s`'):format(
        publicName(pname, charname),
        expires == 0 and 'for good' or ('until ' .. os.date('%d %b %Y', expires)),
        (reason and reason ~= '') and tostring(reason) or 'no reason given'), ids.discord)
    return banId
end

function UnbanPlayer(banId, staff)
    banId = tostring(banId or ''):upper()
    if banId == '' then return false, 'no ban id' end
    local row = MySQL.single.await('SELECT * FROM admin_bans WHERE ban_id = ?', { banId })
    if not row then return false, 'no ban with that id' end
    if not truthy(row.active) then return false, 'that ban is already lifted' end
    -- the row STAYS as the player's profile: a re-ban reuses it (see BanPlayer),
    -- so repeat offenders keep one row instead of one per ban.
    MySQL.update.await(
        'UPDATE admin_bans SET active = 0, unbanned_by = ?, unbanned_at = CURRENT_TIMESTAMP WHERE ban_id = ?',
        { tostring(staff or 'console'):sub(1, 100), banId })
    print(('^2[bans]^7 %s lifted ban %s'):format(tostring(staff or 'console'), banId))

    postEmbed('Ban lifted', 3066993, {
        ('**Ban ID:** `%s`'):format(banId),
        ('**Lifted by:** %s'):format(tostring(staff or 'console')),
        ('**Player:** %s'):format((row.playername ~= '' and row.playername)
            or (row.charname ~= '' and row.charname) or 'unknown'),
        ('**Originally banned by:** %s'):format(row.staff ~= '' and row.staff or 'unknown'),
        ('**Original reason:** %s'):format(row.reason ~= '' and row.reason or 'No reason given'),
    })

    if BanCfg.publicLogUnbans then
        publicLog(3066993, ('🕊️  **%s** has served their time and may ride back in. Ban `lifted`'):format(
            publicName(row.playername, row.charname)), row.discord)
    end
    return true
end

exports('BanPlayer', BanPlayer)
exports('UnbanPlayer', UnbanPlayer)
