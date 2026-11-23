-- pup-magic | refused spell casts: always to this console, and to Discord when server/config.lua has a webhook

local function clean(s, max)
    s = tostring(s or ''):gsub('[%c`@]', ''):sub(1, max or 64)
    return s
end

function LogRefusedCast(src, spellId)
    local name = clean(GetPlayerName(src) or '?', 48)
    local id = clean(spellId, 32)
    print(('^3[pup-magic]^7 unauthorised cast by %s (id %d): "%s"'):format(name, src, id))

    local hook = MagicSecrets and MagicSecrets.castWebhook or ''
    if hook == '' then return end

    local ch = CharOf(src)
    local body = json.encode({
        username = 'pup-magic',
        allowed_mentions = { parse = {} },
        embeds = { {
            title = 'Refused spell cast',
            color = 15158332,
            fields = {
                { name = 'Player',    value = ('%s (server id %d)'):format(name, src), inline = true },
                { name = 'Character', value = ch and tostring(ch.id) or 'none',       inline = true },
                { name = 'Spell',     value = id ~= '' and id or '(none)',             inline = true },
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
    PerformHttpRequest(hook, function(code)
        if code and (code < 200 or code >= 300) then
            WarnOnce('hook' .. tostring(code), 'Discord webhook answered ' .. tostring(code))
        end
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end
