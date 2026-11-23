-- pup_hideouts | small helpers shared by both sides

U = {}

function U.vec(c)
    if type(c) == 'vector3' or type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) ~= 'table' then return nil end
    local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
    if not (x and y and z) then return nil end
    return vector3(x, y, z)
end

function U.plain(c)
    local v = U.vec(c)
    if not v then return nil end
    return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 }
end

function U.dist(a, b)
    a, b = U.vec(a), U.vec(b)
    if not (a and b) then return math.huge end
    return #(a - b)
end

function U.flat(a, b)
    a, b = U.vec(a), U.vec(b)
    if not (a and b) then return math.huge end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- a position that failed to parse ends up at the origin; it never counts
function U.isOrigin(c)
    local v = U.vec(c)
    return not v or (math.abs(v.x) < 0.01 and math.abs(v.y) < 0.01 and math.abs(v.z) < 0.01)
end

function U.int(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    if n ~= math.floor(n) then return nil end
    return math.floor(n)
end

function U.posInt(v)
    local n = U.int(v)
    if not n or n < 1 then return nil end
    return n
end

function U.round2(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end

function U.money(n)
    n = U.round2(n)
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return ('%.2f'):format(n)
end

function U.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function U.clipName(s, max)
    -- control characters and angle brackets out: a name is shown to other players and to
    -- staff panels, and must never be able to carry markup
    s = U.trim((U.trim(s):gsub('[%c<>]', '')))
    if #s > (max or 50) then s = s:sub(1, max or 50) end
    return s
end

function U.mmss(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ('%d:%02d'):format(sec // 60, sec % 60)
end

function U.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = U.copy(v) end
    return out
end

-- an optional-resource call failed: say so on the console, once per adapter per minute
local lastWarn = {}
function U.warnIntegration(name, err)
    local now = GetGameTimer()
    if lastWarn[name] and now - lastWarn[name] < 60000 then return end
    lastWarn[name] = now
    print(('^3[pup_hideouts]^7 optional integration "%s" failed and was skipped (fail safe): %s'):format(tostring(name), tostring(err)))
end

function U.isEmpty(t) return type(t) ~= 'table' or next(t) == nil end

function U.inList(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

function U.decode(s, fallback)
    if type(s) == 'table' then return s end
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end

-- deep compare of two metadata tables (empty and nil are the same)
function U.sameMeta(a, b)
    a = type(a) == 'table' and a or {}
    b = type(b) == 'table' and b or {}
    for k, v in pairs(a) do
        if type(v) == 'table' then
            if not U.sameMeta(v, b[k]) then return false end
        elseif b[k] ~= v then return false end
    end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function U.zone(name)
    return Config.Zones[name or Config.DefaultZone] or Config.Zones[Config.DefaultZone]
end

function U.recipe(kind, resultitem)
    local list = kind == 'mash' and Config.Mash or Config.Distill
    for _, r in ipairs(list) do
        if r.resultitem == resultitem and (kind == 'mash' or r.distill) then return r end
    end
    return nil
end

function U.decoBySet(set)
    for _, d in ipairs(Config.Decorations) do if d.set == set then return d end end
    return nil
end

function U.themeBySet(set)
    for _, t in ipairs(Config.Themes) do if t.set == set then return t end end
    return nil
end

function U.tiersAt(level)
    local out = {}
    for _, t in ipairs(Config.StorageTiers) do
        if t.level == level then out[#out + 1] = t end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function U.tierByName(name)
    for _, t in ipairs(Config.StorageTiers) do if t.name == name then return t end end
    return nil
end

function U.jobsFor(stillLevel)
    return Config.Wagons.allowed[math.max(0, math.min(3, stillLevel or 0))] or {}
end

local WEBHOOK_HOSTS = { ['discord.com'] = true, ['discordapp.com'] = true, ['ptb.discord.com'] = true, ['canary.discord.com'] = true }
function U.validWebhook(url)
    if type(url) ~= 'string' then return nil end
    url = url:gsub('%s+', '')
    if #url > 255 then return nil end
    local host, path = url:match('^https?://([%w%.%-]+)(/api/webhooks/%d+/[%w%-_]+[%w%-_%?=&]*)$')
    if not host or not WEBHOOK_HOSTS[host:lower()] then return nil end
    return 'https://' .. host:lower() .. path
end
