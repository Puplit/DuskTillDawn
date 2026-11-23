-- pup_realestate | secrets, admin Discord log, activity feed and owner house logs

-- secrets: global Secrets, set in server/config.lua
function S.adminWebhook()
    local s = type(Secrets) == 'table' and Secrets or {}
    local url = type(s.Webhooks) == 'table' and s.Webhooks.admin or nil
    if type(url) ~= 'string' or url == '' then return nil end
    return url
end

-- staff log through vorp_core's webhook helper
function AdminLog(text)
    local url = S.adminWebhook()
    if not url then return end
    local c = Config.AdminLog
    pcall(Core.AddWebhook, c.title, url, text, c.color, c.name, c.logo, nil, c.avatar)
end

-- owner webhooks: allowed prefixes, cached per house ('' = none)
local HOOK_PREFIXES = {
    'https://discord.com/api/webhooks/',
    'https://discordapp.com/api/webhooks/',
    'https://ptb.discord.com/api/webhooks/',
    'https://canary.discord.com/api/webhooks/',
}

function S.validHook(url)
    if type(url) ~= 'string' or #url > 255 then return false end
    local low = url:lower()
    for _, p in ipairs(HOOK_PREFIXES) do
        if low:sub(1, #p) == p and #url > #p then return true end
    end
    return false
end

local hookCache = {}

function S.forgetHook(id) hookCache[id] = nil end
function S.setHookCache(id, url) hookCache[id] = url or '' end

local function houseHook(id)
    local cached = hookCache[id]
    if cached ~= nil then return cached ~= '' and cached or nil end
    local ok, url = pcall(MySQL.scalar.await, 'SELECT webhook FROM playerhousing WHERE id = ?', { id })
    if not ok then return nil end
    url = (type(url) == 'string' and S.validHook(url)) and url or ''
    hookCache[id] = url
    return url ~= '' and url or nil
end

local COLOURS = {
    DEPOSIT = 3066993, TAX = 3447003, WITHDRAW = 15158332, STORAGE = 15105570,
    BUY = 3066993, SELL = 15105570, KEY_GIVE = 3447003, KEY_TAKE = 15105570, REPO = 10038562,
}

local function postOwnerLog(id, kind, detail, actor)
    if not Config.OwnerWebhooks then return end
    local url = houseHook(id)
    if not url then return end
    local who = ('**%s**'):format(actor and actor.name or 'System')
    if actor and actor.charid then who = who .. (' - char `%s`'):format(actor.charid) end
    if actor and actor.discord then who = who .. (' - <@%s>'):format(actor.discord) end
    local text = tostring(detail or ''):sub(1, 1000)
    if text == '' then text = '-' end
    local body = json.encode({
        username = 'House Logs',
        embeds = { {
            title = ('House #%s - %s'):format(id, kind),
            color = COLOURS[kind] or 16777215,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = { text = RES },
            fields = {
                { name = 'Who', value = who, inline = true },
                { name = 'Action', value = kind, inline = true },
                { name = 'Detail', value = text },
            },
        } },
    })
    PerformHttpRequest(url, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

-- activity row (+ owner channel). actor = { name, charid?, discord? } or nil for System
local insertCount = 0
function Activity(houseId, kind, detail, actor)
    houseId = U.int(houseId)
    if not houseId then return end
    local name = actor and actor.name or 'System'
    detail = tostring(detail or '')
    local short = detail:sub(1, 191) -- the column is varchar(191); the owner's channel gets up to 1000
    CreateThread(function()
        pcall(MySQL.insert.await, 'INSERT INTO housing_activity (houseid, ts, type, detail, actor) VALUES (?, ?, ?, ?, ?)',
            { houseId, Now(), kind, short, tostring(name):sub(1, 100) })
        insertCount = insertCount + 1
        if insertCount % 10 == 0 then
            pcall(MySQL.update.await, 'DELETE FROM housing_activity WHERE ts < ?', { Now() - 30 * 86400 })
        end
    end)
    -- the webhook lookup may wait on the database; never make the caller (a money handler) wait
    CreateThread(function() postOwnerLog(houseId, kind, detail, actor) end)
end

-- actor from a character snapshot
function S.actor(ch)
    if not ch then return nil end
    return { name = ch.name, charid = ch.charid, discord = S.discordId(ch.src) }
end
