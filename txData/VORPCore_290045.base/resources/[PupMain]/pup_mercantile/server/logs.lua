-- pup_mercantile | Discord embeds for staff and, when allowed, the shop's own channel

Colours = {
    sale = 3066993,
    stock = 15105570,
    money = 15844367,
    setup = 3447003,
    repo = 15158332,
}

local function post(url, payload)
    if type(url) ~= 'string' or url == '' then return end
    PerformHttpRequest(url, function(code)
        if code and code >= 300 and code ~= 429 then Dbg('webhook answered ' .. tostring(code)) end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- the acting player, as the embed description
function ActorInfo(src)
    if not src or src <= 0 then return nil end
    local char = GetChar(src)
    local lines = {}
    if char then lines[#lines + 1] = ('**%s** #%s'):format(FullName(char), tostring(char.charIdentifier)) end
    local pname = GetPlayerName(src)
    if pname then lines[#lines + 1] = pname end
    local discord = DiscordId(src)
    if discord then lines[#lines + 1] = ('<@%s>'):format(discord) end
    return table.concat(lines, '\n')
end

function ItemField(label, name)
    return ('**%s**\n%s'):format(tostring(label or name or '?'), tostring(name or '?'))
end

-- opts: { title, colour, src, shop, fields = { {name, value}, ... }, staffOnly }
function Log(opts)
    local fields = {}
    for _, f in ipairs(opts.fields or {}) do
        local v = tostring(f[2] == nil and '-' or f[2])
        if #v > 1000 then v = v:sub(1, 997) .. '...' end
        fields[#fields + 1] = { name = tostring(f[1]), value = v ~= '' and v or '-', inline = f[3] == true }
    end
    local footer = ResName()
    if opts.shop then
        footer = footer .. (' • %s #%d'):format(tostring(opts.shop.name), opts.shop.id)
    end
    local embed = {
        title = opts.title,
        description = opts.src and ActorInfo(opts.src) or nil,
        color = opts.colour or Colours.setup,
        fields = fields,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = { text = footer },
    }
    local payload = { username = Config.Logs.poster, embeds = { embed } }
    if Config.Logs.avatar and Config.Logs.avatar ~= '' then payload.avatar_url = Config.Logs.avatar end

    post(Secrets.webhooks.admin, payload)
    if not opts.staffOnly and opts.shop and Config.Shops.ownerWebhooks and Util.validWebhook(opts.shop.webhook) then
        post(opts.shop.webhook, payload)
    end
end
