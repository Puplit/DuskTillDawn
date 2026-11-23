-- pup_gunsmith | staff Discord log (crafting attempts, repairs, tier upgrades)
-- One webhook, from server/config.lua. With no webhook set nothing is sent.

Discord = {}

Discord.GREEN = 3066993
Discord.RED   = 15158332
Discord.GREY  = 10197915

local function webhook()
    local url = Secrets.Webhooks and Secrets.Webhooks.admin
    if type(url) ~= 'string' or url == '' then return nil end
    return url
end

local function send(embed)
    local url = webhook()
    if not url then return end
    embed.footer = { text = GS.RES }
    embed.timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    PerformHttpRequest(url, function(status)
        if status and status >= 300 then
            print(('^3[pup_gunsmith]^7 Discord log refused (HTTP %s)'):format(tostring(status)))
        end
    end, 'POST', json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
end

local function field(name, value, inline)
    value = tostring(value or '')
    if value == '' then value = '-' end
    if #value > 1000 then value = value:sub(1, 997) .. '...' end
    return { name = name, value = value, inline = inline == true }
end

local function who(src, char)
    return {
        field('Character', ('%s  (#%s)'):format(Srv.fullName(char), tostring(char.charIdentifier)), true),
        field('Player', ('%s  [%s]\n%s'):format(GetPlayerName(src) or '?', tostring(src), tostring(char.identifier or '?')), true),
    }
end

-- "2x Iron Bar, 3x Coal" for the materials times the amount
local function materialsText(mats, times)
    local parts = {}
    for _, m in ipairs(mats or {}) do
        parts[#parts + 1] = ('%dx %s'):format(m.amount * times, m.label or m.name)
    end
    table.sort(parts)
    if #parts == 0 then return 'none' end
    return table.concat(parts, ', ')
end

--- info = { src, char, recipe, amount, won, consumed, gained, total, custom }
function Discord.craft(info)
    if not webhook() then return end
    local r = info.recipe
    local isAmmo = r.kind == 'ammo'
    local title
    if info.won then
        title = isAmmo and 'Ammo crafted' or 'Weapon crafted'
    else
        title = isAmmo and 'Ammo craft FAILED' or 'Weapon craft FAILED'
    end
    local colour = info.won and Discord.GREEN or (info.consumed and Discord.RED or Discord.GREY)

    local qty = tostring(info.amount)
    if isAmmo and (tonumber(r.qt) or 0) > 0 then
        qty = ('%s %s  (%s rounds)'):format(GS.thousands(info.amount), info.amount == 1 and 'box' or 'boxes',
            GS.thousands(info.amount * r.qt))
    end

    local fields = {
        field('Item', ('`%s`'):format(isAmmo and tostring(r.item) or tostring(r.hashname)), true),
        field('Quantity', qty, true),
        field('Category', r.category, true),
        field((info.won or info.consumed) and 'Materials consumed' or 'Materials NOT consumed', materialsText(r.mats, info.amount)),
    }
    if info.won then
        fields[#fields + 1] = field('Gunsmith XP', ('+%s  (total %s)'):format(GS.thousands(info.gained or 0), GS.thousands(info.total or 0)), true)
    end
    local custom = info.custom
    if custom and (custom.serial or custom.label) then
        local lines = {}
        if custom.serial then lines[#lines + 1] = 'Serial: ' .. custom.serial end
        if custom.label then lines[#lines + 1] = 'Label: ' .. custom.label end
        fields[#fields + 1] = field('Custom', table.concat(lines, '\n'))
    end
    for _, f in ipairs(who(info.src, info.char)) do fields[#fields + 1] = f end

    send({
        title = title,
        description = ('**%s** - %s'):format(Srv.fullName(info.char), r.label),
        color = colour,
        fields = fields,
    })
end

--- info = { src, char, gun, fee }
function Discord.repair(info)
    if not webhook() then return end
    local fields = {
        field('Weapon', ('%s  (`%s`, id %s)'):format(info.gun.label, info.gun.name, tostring(info.gun.id))),
        field('Fee', info.fee > 0 and GS.dollars(info.fee) or 'free', true),
    }
    for _, f in ipairs(who(info.src, info.char)) do fields[#fields + 1] = f end
    send({
        title = 'Weapon repaired',
        description = ('**%s** - %s'):format(Srv.fullName(info.char), info.gun.label),
        color = Discord.GREEN,
        fields = fields,
    })
end

--- info = { src, char, gun, tier, cash, mats }
function Discord.tier(info)
    if not webhook() then return end
    local fields = {
        field('Weapon', ('%s  (`%s`, id %s)'):format(info.gun.label, info.gun.name, tostring(info.gun.id))),
        field('Tier', tostring(info.tier), true),
        field('Cash', GS.dollars(info.cash or 0), true),
        field('Materials consumed', materialsText(info.mats, 1)),
    }
    for _, f in ipairs(who(info.src, info.char)) do fields[#fields + 1] = f end
    send({
        title = 'Weapon tempered',
        description = ('**%s** - %s to Tier %d'):format(Srv.fullName(info.char), info.gun.label, info.tier),
        color = Discord.GREEN,
        fields = fields,
    })
end
