-- pup_staffdesk | Discord bridge: reads one channel, runs commands staff type there, answers back
-- A handler returns ok, text (posted as a reply), or posts its own embed through Bridge.embed.
Bridge = { commands = {}, order = {} }

local API <const> = 'https://discord.com/api/v10'
local BT <const> = string.char(96)

local D = Config.Discord
local S = Secrets.Discord
local lastId, botId = nil, nil

-- formatting helpers (built from char 96 so this file stays plain text)
function Bridge.code(s) return BT .. tostring(s) .. BT end
function Bridge.block(lines, empty)
    local body = type(lines) == 'table' and table.concat(lines, '\n') or tostring(lines or '')
    if body == '' then body = empty or 'none' end
    if #body > 990 then body = body:sub(1, 980) .. '\n... (cut short)' end
    return BT:rep(3) .. '\n' .. body .. '\n' .. BT:rep(3)
end
-- a long list over as many embed fields as it needs (each field holds 1024 characters)
function Bridge.fields(out, title, lines, empty)
    if #lines == 0 then out[#out + 1] = { name = title, value = Bridge.block({}, empty) } return end
    local part, size, n = {}, 0, 0
    local function push()
        if #part == 0 then return end
        n = n + 1
        out[#out + 1] = { name = n == 1 and title or (title .. ' (cont.)'), value = Bridge.block(part) }
        part, size = {}, 0
    end
    for _, l in ipairs(lines) do
        if size + #l + 1 > 980 then push() end
        part[#part + 1] = l
        size = size + #l + 1
    end
    push()
end
function Bridge.row(label, value, width) return ('%-' .. (width or 14) .. 's %s'):format(label, tostring(value)) end

local function auth()
    return { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bot ' .. (S.botToken or '') }
end

local function post(payload)
    if (S.channelId or '') == '' then return end
    PerformHttpRequest(('%s/channels/%s/messages'):format(API, S.channelId), function() end, 'POST', json.encode(payload), auth())
end

function Bridge.say(text) if D.reply then post({ content = tostring(text):sub(1, 1900) }) end end
function Bridge.embed(e)
    if not D.reply then return end
    e.color = e.color or 9067051
    post({ embeds = { e } })
end

function Bridge.add(name, info, fn)
    name = tostring(name):lower()
    if not Bridge.commands[name] then Bridge.order[#Bridge.order + 1] = name end
    Bridge.commands[name] = { fn = fn, group = info.group or 'OTHER', usage = info.usage or '', help = info.help or '', audit = info.audit ~= false, ban = info.ban == true }
end

exports('AddDiscordCommand', function(name, info, fn)
    if type(name) ~= 'string' or type(fn) ~= 'function' then return false end
    Bridge.add(name, type(info) == 'table' and info or {}, fn)
    return true
end)

function Bridge.prefix()
    local p = D.prefix or '!'
    return p .. (p:match('%w$') and ' ' or '')
end

-------------------------------------------------------------------------------
-- WHO MAY RUN COMMANDS
-------------------------------------------------------------------------------
local roleCache = {}

local function rolesOf(userId, cb)
    local c = roleCache[userId]
    if c and os.time() - c.t < 300 then return cb(c.roles) end
    if (S.guildId or '') == '' then return cb({}) end
    PerformHttpRequest(('%s/guilds/%s/members/%s'):format(API, S.guildId, userId), function(code, body)
        local roles = {}
        if code == 200 then
            local ok, m = pcall(json.decode, body or '{}')
            if ok and type(m) == 'table' and type(m.roles) == 'table' then roles = m.roles end
        end
        roleCache[userId] = { t = os.time(), roles = roles }
        cb(roles)
    end, 'GET', '', auth())
end

-- empty lists allow nobody (the bridge does not even start without one)
local function listed(author, roles, users, want)
    for _, u in ipairs(users or {}) do if tostring(u) == author then return true end end
    for _, has in ipairs(roles or {}) do
        for _, r in ipairs(want or {}) do if tostring(r) == tostring(has) then return true end end
    end
    return false
end

local function allowed(author, roles)
    return listed(author, roles, S.users, S.roles)
end

-- !ban / !unban: banUsers / banRoles when either is filled in, otherwise the normal staff lists
local function banAllowed(author, roles)
    if #(S.banUsers or {}) == 0 and #(S.banRoles or {}) == 0 then return allowed(author, roles) end
    return listed(author, roles, S.banUsers, S.banRoles)
end

-------------------------------------------------------------------------------
-- RUNNING A COMMAND
-------------------------------------------------------------------------------
-- runs one line as `who`. Exposed so the console can test the bridge without Discord.
function Bridge.run(content, who, msg)
    local args = {}
    for w in content:gmatch('%S+') do args[#args + 1] = w end
    if #args == 0 then return end
    local name = args[1]:lower()
    local cmd = Bridge.commands[name]
    if cmd then
        CreateThread(function()
            local ok, res, text = pcall(cmd.fn, args, who, msg)
            local good = ok and res ~= false
            if not ok then
                print('^1[pup_staffdesk/discord]^7 ' .. tostring(res))
                Bridge.say(('X %s failed: %s'):format(Bridge.code(name), tostring(res)))
            elseif type(text) == 'string' then
                Bridge.say((res == false and 'X ' or 'OK ') .. text)
            end
            if cmd.audit then DeskDB.audit('discord', who, name, table.concat(args, ' ', 2), good) end
        end)
    end
    -- always, known or not, so other resources can listen for their own words
    TriggerEvent('pup_staffdesk:recfromdiscord', content, args, who, msg)
end

local function handle(msg)
    local content = msg.content
    if type(content) ~= 'string' then return end
    local p = D.prefix or '!'
    if content:sub(1, #p) ~= p then return end
    local author = msg.author and msg.author.id
    if not author or author == botId or msg.author.bot then return end

    local function go(roles)
        if not allowed(author, roles) then
            return Bridge.say(('<@%s> %s'):format(author, Locale.discordDenied))
        end
        local line = content:sub(#p + 1)
        local cmd = Bridge.commands[(line:match('^%s*(%S+)') or ''):lower()]
        if cmd and cmd.ban and not banAllowed(author, roles) then
            return Bridge.say(('<@%s> %s'):format(author, Locale.discordBanDenied))
        end
        Bridge.run(line, ('%s (Discord)'):format(msg.author.username or author), msg)
    end
    if #(S.roles or {}) > 0 or #(S.banRoles or {}) > 0 then rolesOf(author, go) else go({}) end
end

local function poll()
    local url = ('%s/channels/%s/messages?limit=%d'):format(API, S.channelId, lastId and 50 or 1)
    if lastId then url = url .. '&after=' .. lastId end
    PerformHttpRequest(url, function(code, body)
        if code ~= 200 then
            local stop = ({ [401] = 'the bot token is wrong', [403] = 'the bot cannot read that channel', [404] = 'there is no such channel' })[code]
            if stop then
                print(('^1[pup_staffdesk/discord]^7 %s (%d) - bridge stopped'):format(stop, code))
                D.enabled = false
            end
            return
        end
        local ok, list = pcall(json.decode, body or '[]')
        if not ok or type(list) ~= 'table' then return end
        local first = lastId == nil
        -- newest first from Discord: walk it backwards so commands run in the order typed
        for i = #list, 1, -1 do
            local m = list[i]
            if m and m.id then
                if not lastId or #m.id > #lastId or (#m.id == #lastId and m.id > lastId) then lastId = m.id end
                -- the first read only marks where we are, so a restart never replays old commands
                if not first then handle(m) end
            end
        end
    end, 'GET', '', auth())
end

CreateThread(function()
    Wait(2500)
    if not D.enabled then return end
    if (S.botToken or '') == '' or (S.channelId or '') == '' then
        print('^3[pup_staffdesk/discord]^7 no bot token or channel in server/config.lua - bridge off')
        return
    end
    if #(S.users or {}) == 0 and #(S.roles or {}) == 0 then
        print('^1[pup_staffdesk/discord]^7 no Discord users or roles in server/config.lua - bridge off (it would let anyone in the channel run commands)')
        return
    end
    PerformHttpRequest(API .. '/users/@me', function(code, body)
        local ok, me = pcall(json.decode, body or '{}')
        if code == 200 and ok and me and me.id then
            botId = me.id
            print(('^2[pup_staffdesk/discord]^7 bridge live as %s'):format(me.username or me.id))
        else
            print(('^1[pup_staffdesk/discord]^7 could not sign the bot in (%s) - check the token'):format(tostring(code)))
        end
    end, 'GET', '', auth())
    Wait(1000)
    poll()
    while D.enabled do
        Wait(math.max(2, D.intervalSeconds or 3) * 1000)
        poll()
    end
end)

-- console: deskcmd <line> runs a bridge command as the console (answers go to the channel)
RegisterCommand('deskcmd', function(src, args)
    if src ~= 0 then return end
    Bridge.run(table.concat(args, ' '), 'Console')
end, true)
