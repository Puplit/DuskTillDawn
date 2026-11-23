-- goldpan | paying a worked pan: every roll and every item is decided here

local PAN <const> = Config.Panning

-- chance in percent for a loot row at this quality
local function chance(e, q)
    return math.min(tonumber(e.cap) or 0, (tonumber(e.base) or 0) + (tonumber(e.perQ) or 0) * q)
end

local function hits(e, q)
    return math.random() * 100 < chance(e, q)
end

local function amountOf(min, max, q)
    min = math.floor(tonumber(min) or 1)
    max = math.max(min, math.floor(tonumber(max) or min))
    return math.random(min, max) + math.floor(math.max(0, q - 1))
end

local function listText(found)
    local parts = {}
    for i, f in ipairs(found) do parts[i] = GP.msg('ListItem'):format(f.label, f.amount) end
    return table.concat(parts, GP.msg('ListAnd'))
end

local function hint(p)
    if p <= 0 then return GP.msg('HintNone') end
    if p < 0.35 then return GP.msg('HintFaint') end
    if p < 0.75 then return GP.msg('HintClose') end
    return GP.msg('HintHot')
end

local function within(pos, ped, metres)
    local c = GetEntityCoords(ped)
    local dx, dy = c.x - pos.x, c.y - pos.y
    return dx * dx + dy * dy <= metres * metres, c
end

RegisterNetEvent('pup_goldpan:reward', function(token, score)
    local src = source
    local s = Srv.Sessions[src]
    if not s then return end
    -- any reward request ends the session
    Srv.Sessions[src] = nil

    -- 1. the character and the session
    local char = Srv.character(src)
    if not char or char.charIdentifier ~= s.charId then return end
    if type(token) ~= 'string' or token ~= s.token then return end

    -- 2. elapsed time
    local elapsed = GetGameTimer() - s.at
    if elapsed < (PAN.MinSessionMs or 9000) or elapsed > (PAN.MaxSessionMs or 60000) then return end

    -- 3. still alive and still where the pan started
    local ped = Srv.pedAlive(src)
    if not ped then return end
    local near, here = within(s.pos, ped, tonumber(PAN.MaxDrift) or 8.0)
    if not near then return end

    -- 4. still holds a pan
    if not Srv.hasPan(src) then return Srv.say(src, 'NoItem') end

    -- 5. the score
    score = tonumber(score)
    if not score or score ~= score then return end
    score = GP.clamp(score, 0.0, 1.0)
    if score <= 0 then return end

    -- 6. cooldown, then this counts as a paid pan
    if not Srv.cooledDown(src) then return Srv.say(src, 'TooSoon') end
    Srv.LastPaid[src] = GetGameTimer()

    -- 7. the water fixed when the pan started
    local water = GP.Waters[s.water]
    if not water then return end
    local richness = PAN.TypeRichness[water.type]
    if richness == nil then richness = PAN.DefaultRichness or 0.6 end
    if richness <= 0 then
        return Srv.toast(src, GP.msg('HintDead'), nil, 'gold', GP.msOf('Nothing'))
    end

    -- 8-11. streaks, perk and quality
    local p, nearest = Streaks.check(s.water, here.x, here.y)
    local streakBonus = 1 + ((tonumber(PAN.Streaks.bonus) or 1) - 1) * p
    local perk = 1 + Srv.panLuck(src) / 100
    local quality = richness * streakBonus * score * perk

    -- 12. main roll, floor, byproducts
    local main
    for _, k in ipairs(Config.LootOrder) do
        local e = Config.Loot[k]
        if e and hits(e, quality) then main = e break end
    end
    local mainMin, mainMax = main and main.min, main and main.max
    if not main and Config.DustFloor.enabled and score >= (Config.DustFloor.minScore or 0) then
        main = Config.Loot[Config.DustFloor.lootKey]
        mainMin, mainMax = Config.DustFloor.min, Config.DustFloor.max
    end

    local given = false
    local mainFind
    if main then
        local n = amountOf(mainMin, mainMax, quality)
        if n >= 1 then
            if not Srv.give(src, main.item, n) then return Srv.say(src, 'CantCarry') end
            mainFind = { label = main.label or main.item, amount = n }
            given = true
        end
    end

    local extras = {}
    for _, e in ipairs(Config.Extras or {}) do
        if hits(e, quality) then
            local n = amountOf(e.min, e.max, quality)
            if n >= 1 and Srv.give(src, e.item, n) then
                extras[#extras + 1] = { label = e.label or e.item, amount = n }
                given = true
            end
        end
    end

    Streaks.recordPan(s.water, here.x, here.y)

    -- 13. XP
    if given then Srv.award(src) end

    -- 14. the result
    local h = hint(p)
    if mainFind then
        local line = GP.msg('Found'):format(mainFind.label, mainFind.amount)
        if #extras > 0 then line = line .. ' ' .. GP.msg('AlsoFound'):format(listText(extras)) end
        Srv.toast(src, line, h, 'gold', GP.msOf('Found'))
    elseif #extras > 0 then
        Srv.toast(src, GP.msg('OnlyExtras'):format(listText(extras)), h, 'gold', GP.msOf('Found'))
    else
        Srv.toast(src, h, nil, 'gold', GP.msOf('Nothing'))
    end

    -- 15. drain the nearest streak
    if p > 0 and nearest and Streaks.drain(s.water, nearest) then
        Srv.say(src, 'Drained')
    end
end)
