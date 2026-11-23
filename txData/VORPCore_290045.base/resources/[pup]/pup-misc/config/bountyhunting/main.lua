-- pup-misc / bountyhunting | settings (see README)
BountyConfig = {
    Debug = false,            -- F8 / server console tracing

    -- 'vorp' = vorp:TipBottom, 'redem' = redem_roleplay:ShowObjective
    Notifier = 'vorp',

    Keys = {
        Interact = 0x760A9C6F, -- G
        End      = 0xB2F377E8, -- F
    },

    Jobs = {
        Lock   = true,           -- false = anyone may use the boards
        Law    = { 'police' },
        Hunter = { 'bvbounty' },
    },

    -- town keys must match the keys used in kill.lua / arrest.lua / escort.lua
    Boards = {
        { town = 'blackwater', coords = vector3(-767.144, -1261.2151, 43.6312) },
        { town = 'rhodes',     coords = vector3(1353.38, -1304.39, 76.87) },
        { town = 'saintdenis', coords = vector3(2517.132, -1312.142, 48.565) },
        { town = 'armadillo',  coords = vector3(-3620.6003, -2597.2446, -13.5762) },
        { town = 'annesburg',  coords = vector3(2913.39, 1313.05, 44.29) },
        { town = 'strawberry', coords = vector3(-1806.1760, -346.2611, 164.4589) },
        { town = 'valentine',  coords = vector3(-270.21, 804.4065, 119.4683) },
    },
    BoardPromptDistance = 2.0,  -- metres
    BoardServerSlack    = 6.0,  -- metres

    Blips = {
        BoardsForEveryone = false,
        Scale         = 0.2,
        CoordStyle    = 1664425300,  -- marker style for map points
        EntityStyle   = 953018525,   -- marker style for markers riding on peds
        BoardSprite   = -1747825963,
        StartSprite   = 1779658797,  -- kill / capture start
        ClientSprite  = -1103135225, -- escort client start
        DropSprite    = -2108463156,
        PedSprite     = 1481032477,  -- marked peds (targets, hostiles, client, attackers)
        StartColour   = 0x6F85C3CE,
        HostileColour = 0x6F85C3CE,
        DropColour    = 0xA9DBBFDC,
        TargetColour  = 0xA9DBBFDC,
        RouteColour   = 'COLOR_RED',
    },

    Cooldown = {
        Minutes   = 30,          -- per character; 0 = none
        StartsAt  = 'approval',  -- 'approval' (when the board hands out the contract) or 'end'
        Partners  = false,       -- true = partners get the same cooldown as the leader
    },

    Party = {
        MaxHunters      = 4,
        PartnersNeedJob = false, -- true = every named partner must hold a law / hunter job too
        PartnerDistance = 10.0,  -- metres: named partners must stand this close to the leader when the contract is taken
    },

    Contracts = {
        HostileMarkers       = true,
        ArriveDistance       = 120.0, -- metres
        HandoverDistance     = 10.0,  -- metres
        EscortArriveDistance = 2.0,   -- metres
        EscortFollowRefresh  = 10,    -- seconds
        EscortRandomTarget   = true,
        FirstWaveSeconds     = nil,   -- seconds; nil = the block's interval
        ShareAttackerMarkers = false,
        DeadTargetFails      = false,
        DeathFailsAfterClear = false,
        EndPauseSeconds      = 5,     -- seconds
        HandoverPause        = 2.5,   -- seconds
        ModelLoadTimeout     = 5000,  -- ms
        SpawnAttempts        = 3,
    },

    Payout = {
        Multiplier        = 0.75,
        MaxCash           = 5000,  -- per payment
        MaxGold           = 0,     -- per payment; 0 = no gold
        Radius            = 40.0,  -- metres
        SplitAmongPresent = false,
        PerkKey           = 'bounty', -- pup-perks Award key
    },

    -- partner side: retry for a marked ped that has not streamed in yet
    PartnerMarkerRetryMs = 500,
    PartnerMarkerRetries = 360,

    -- weapon names in the data files that the game does not know, mapped to the intended one
    WeaponFixes = {},

    -- what a contract's tier means, per party size [1] solo ... [4] four hunters
    --   hostiles  = outlaws at a kill camp; at a capture camp the wanted men come out of this count
    --   targets   = wanted men at a capture camp
    --   attackers = ambushers per wave on an escort
    --   purse     = total cash before Payout.Multiplier (split per body / wanted man)
    --   arms      = key in Arms; styles = combat movement handed out in turn (0-3, see README)
    --   wave      = seconds between escort waves; health = escort client health
    Tiers = {
        [1] = { label = 'Petty',     hostiles = { 3, 4, 6, 7 },  targets = { 1, 1, 2, 2 }, attackers = { 2, 2, 3, 4 },
                purse = { 150, 240, 340, 440 },  arms = 'light', styles = { 1, 1, 2 },    wave = 110, health = 450 },
        [2] = { label = 'Wanted',    hostiles = { 4, 6, 7, 9 },  targets = { 1, 2, 2, 3 }, attackers = { 2, 3, 4, 5 },
                purse = { 260, 400, 560, 720 },  arms = 'mixed', styles = { 1, 2, 1, 3 }, wave = 95,  health = 550 },
        [3] = { label = 'Notorious', hostiles = { 5, 7, 9, 11 }, targets = { 1, 2, 3, 3 }, attackers = { 3, 4, 5, 6 },
                purse = { 420, 640, 880, 1120 }, arms = 'heavy', styles = { 2, 1, 3, 1, 2 }, wave = 80, health = 700 },
    },

    -- purse factor by contract kind (taking a man alive is harder than shooting him)
    KindPay = { kill = 1.0, arrest = 1.3, escort = 1.1 },

    -- metres from the contract point: kill camps, capture guards, and the wanted men themselves
    Spread = { kill = 10.0, guards = 10.0, wanted = 3.0 },

    -- each ped takes the next weapon in the tier's list; wanted men always carry a sidearm
    Arms = {
        sidearm = { 'WEAPON_REVOLVER_CATTLEMAN', 'WEAPON_REVOLVER_DOUBLEACTION', 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REVOLVER_SCHOFIELD' },
        light   = { 'WEAPON_REVOLVER_CATTLEMAN', 'WEAPON_REPEATER_CARBINE', 'WEAPON_SHOTGUN_DOUBLEBARREL',
                    'WEAPON_REVOLVER_DOUBLEACTION', 'WEAPON_RIFLE_VARMINT' },
        mixed   = { 'WEAPON_REPEATER_WINCHESTER', 'WEAPON_REVOLVER_SCHOFIELD', 'WEAPON_SHOTGUN_PUMP',
                    'WEAPON_RIFLE_SPRINGFIELD', 'WEAPON_SHOTGUN_SAWEDOFF', 'WEAPON_PISTOL_SEMIAUTO' },
        heavy   = { 'WEAPON_REPEATER_HENRY', 'WEAPON_RIFLE_BOLTACTION', 'WEAPON_SHOTGUN_REPEATING', 'WEAPON_PISTOL_MAUSER',
                    'WEAPON_REPEATER_EVANS', 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', 'WEAPON_REVOLVER_LEMAT' },
    },
}

--------------------------------------------------------------------------------
-- Nothing to edit below: kill.lua, arrest.lua and escort.lua hand their contract lists to
-- BountyConfig.build, which turns each one into the per-party-size blocks the code reads.
-- Spots are laid out from the contract's name, so client and server build the same thing.
--------------------------------------------------------------------------------
do
    local GOLDEN <const> = 2.39996323 -- radians between neighbours on the spiral

    local function warn(msg)
        print(('^3[pup-misc:bountyhunting]^7 %s'):format(msg))
    end

    local function seedOf(text)
        local n = 7
        for i = 1, #text do n = (n * 31 + text:byte(i)) % 1000003 end
        return n
    end

    local function nth(list, i)
        return list[(i - 1) % #list + 1]
    end

    local function nearest5(n)
        return math.floor(n / 5 + 0.5) * 5
    end

    -- count spots on a spiral around `at`, between minR and spread metres out
    local function spiral(at, count, spread, minR, seed)
        local spots = {}
        local turn = (seed % 628) / 100
        for i = 1, count do
            local r = minR + math.max(0.0, spread - minR) * math.sqrt((i - 0.5) / count)
            local a = turn + i * GOLDEN
            spots[i] = vector3(at.x + math.cos(a) * r, at.y + math.sin(a) * r, at.z)
        end
        return spots
    end

    local function arm(count, spots, arms, styles, seed)
        local list = {}
        for i = 1, count do
            list[i] = { coords = spots and spots[i] or nil, weapon = nth(arms, i + seed), style = nth(styles, i) }
        end
        return list
    end

    local function boardOf(town)
        for _, b in ipairs(BountyConfig.Boards) do
            if b.town == town then return b.coords end
        end
        return nil
    end

    local function one(kind, town, c, where)
        local Cfg = BountyConfig
        local pools = Cfg.PedPools or {}
        local tier = Cfg.Tiers[c.tier or 1]
        if not tier then return warn(('%s: unknown tier %s'):format(where, tostring(c.tier))) end
        local drop = c.drop or (kind ~= 'escort' and boardOf(town) or nil)
        if not c.at or not drop then return warn(('%s: needs at (and drop for an escort)'):format(where)) end
        if not pools[c.gang] then return warn(('%s: unknown ped pool "%s"'):format(where, tostring(c.gang))) end
        if kind == 'escort' and not pools[c.client] then
            return warn(('%s: unknown client pool "%s"'):format(where, tostring(c.client)))
        end

        local seed = seedOf(c.name or where)
        local arms = Cfg.Arms[tier.arms] or Cfg.Arms.sidearm
        local spread = c.spread or (kind == 'kill' and Cfg.Spread.kill or Cfg.Spread.guards)
        local pay = (Cfg.KindPay[kind] or 1.0) * (c.pay or 1.0)
        local ct = { name = c.name, notice = c.notice, coords = c.at, dropCoords = drop, levels = {} }

        for size = 1, #tier.purse do
            local block = { rewardCash = nearest5(tier.purse[size] * pay), rewardGold = 0 }
            local hostiles = math.max(1, (tier.hostiles[size] or 1) + (c.extra or 0))
            if kind == 'kill' then
                block.pedPool = c.gang
                block.enemies = arm(hostiles, spiral(c.at, hostiles, spread, 2.0, seed), arms, tier.styles, seed)
            elseif kind == 'arrest' then
                local wanted = tier.targets[size] or 1
                local guards = math.max(0, hostiles - wanted)
                block.pedPool = c.gang
                block.targets = arm(wanted, spiral(c.at, wanted, Cfg.Spread.wanted, 1.0, seed + 1), Cfg.Arms.sidearm, { 1 }, seed)
                block.enemies = arm(guards, spiral(c.at, guards, spread, 5.0, seed + 2), arms, tier.styles, seed + 3)
            else
                local attackers = math.max(1, (tier.attackers[size] or 1) + (c.extra or 0))
                block.enemyPool = c.gang
                block.clientPool = c.client
                block.health = c.health or tier.health
                block.spawnIntervalSeconds = c.wave or tier.wave
                block.enemies = arm(attackers, nil, arms, tier.styles, seed)
            end
            ct.levels[size] = block
        end
        return ct
    end

    function BountyConfig.build(kind, byTown)
        local out = {}
        for town, list in pairs(byTown) do
            local built = {}
            for i, c in ipairs(list) do
                local ct = one(kind, town, c, ('%s %s #%d'):format(kind, town, i))
                if ct then built[#built + 1] = ct end
            end
            out[town] = built
        end
        return out
    end
end
