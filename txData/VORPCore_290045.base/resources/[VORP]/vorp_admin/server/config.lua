-- Modified by Puppet (Dusk Till Dawn), 2026
-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- A blank webhook falls back to `default`, unless its comment says otherwise.

Secrets = {
    Webhooks = {

        -- CATCH-ALL. Every blank webhook below falls back to this one, so nothing goes unlogged.
        default               = "", -- catch-all for every blank entry

        -- REPORTS  (players' own menu)
        reportPlayer          = "", -- player reports
        reportRequestStaff    = "", -- request staff
        reportBug             = "", -- bug reports
        reportRulesBroken     = "", -- rules broken reports
        reportCheating        = "", -- cheating reports

        -- BOOSTERS  (staff self actions)
        boosterNoClip         = "", -- noclip toggled
        boosterInfiniteAmmo   = "", -- infinite ammo toggled
        boosterGoldenCores    = "", -- golden cores
        boosterGodMode        = "", -- god mode toggled
        boosterSelfHeal       = "", -- self heal
        boosterSelfRevive     = "", -- self revive
        boosterSpawnHorse     = "", -- spawned a horse or animal
        boosterSpawnWagon     = "", -- spawned a wagon

        -- ADMIN ACTIONS
        adminFreeze           = "", -- freeze player
        adminBring            = "", -- bring player
        adminGoto             = "", -- go to player
        adminRevive           = "", -- revive player
        adminHeal             = "", -- heal player
        adminSpectate         = "", -- spectate
        adminRespawn          = "", -- respawn player
        adminKick             = "", -- kick
        adminBan              = "", -- ban (also the fallback for ban match and VPN reports)
        adminUnban            = "", -- unban
        adminWhitelist        = "", -- whitelist
        adminUnwhitelist      = "", -- unwhitelist
        adminSetGroup         = "", -- set group
        adminSetJob           = "", -- set job
        adminAnnounce         = "", -- announce
        adminTroll            = "", -- troll actions: kill, fire, heaven, ragdoll, handcuff, stamina, temp high, invisible

        -- TELEPORTS
        teleportWaypoint      = "", -- teleport to waypoint
        teleportCoords        = "", -- teleport to coords
        teleportToPlayer      = "", -- teleport to player
        teleportBringPlayer   = "", -- bring player

        -- DATABASE  (give / clear)
        databaseGiveItem      = "", -- give item
        databaseGiveWeapon    = "", -- give weapon
        databaseGiveCurrency  = "", -- give money / gold
        databaseGiveHorse     = "", -- give horse
        databaseGiveWagon     = "", -- give wagon
        databaseClearMoney    = "", -- clear money
        databaseClearGold     = "", -- clear gold
        databaseClearItems    = "", -- clear items
        databaseClearWeapons  = "", -- clear weapons

        -- WEB PANEL  (everything the panel can change; blank = default)
        panelHeight           = "", -- character height / ped scale
        panelCharacter        = "", -- delete character, PO box, ped menu, stable admin, bans tab, mail
        panelGangs            = "", -- gang points, disband
        panelPerks            = "", -- perk grants and track changes
        panelRanch            = "", -- ranch price / tax / create / delete
        panelSociety          = "", -- business create, update, delete, hire, fire, shops
        panelHousing          = "", -- house actions and auctions
        panelBank             = "", -- bank balance and cash wipes / sets
        panelHideouts         = "", -- underground hideouts: ledger, stash, owners, raids, evict, delete
        panelCamps            = "", -- pup_camps: safe, tax, stash, members, leader, repo, delete
        panelCurses           = "", -- pup_shaman: curses given, eased and cleansed (blank = the default log)
        panelFarms            = "", -- pup_homestead: plants pulled up (blank = the default log)
        panelProps            = "", -- pup-props: permanent world props removed from the map
        panelStores           = "", -- player-owned shops
        panelItems            = "", -- items table: create, edit a field, delete
        panelConsumables      = "", -- fred_metabolism consumables
        panelCrafting         = "", -- pup_workbench recipes and locations
        panelWeapons          = "", -- pup_gunsmith recipes
        panelEvents           = "", -- pup-events: seasonal events forced on/off, in-game clock changes

        -- SERVER BANS AND CONNECT GATES
        bansMatch             = "", -- ban matches at connect. Blank = adminBan, then default
        bansHwid              = "", -- hardware / IP match reports. Blank = same as bansMatch
        bansPublic            = "", -- public channel that announces bans and lifted bans (blank = off)
        steamGate             = "", -- Steam account-age refusals. Blank = default
        vpnGate               = "", -- VPN / proxy refusals. Blank = adminBan, then default

        -- ANTI-CHEAT
        spawnGuard            = "", -- spawn guard blocks, cleanup sweeps and movement flags. Blank = not posted
    },

    ApiKeys = {
        proxycheck            = "", -- proxycheck.io API key for the VPN gate. Blank = gate cannot check
    },
}
