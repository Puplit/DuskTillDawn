fx_version 'adamant'
game 'rdr3'
author 'pup'
version '1.0.0'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'Player gangs: factions, ranks, points, territory, wars, dens - with their own NUI and a live map layer.'

-- the gang's own interface
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

-- ORDER MATTERS: config/main.lua declares `Config`; the other config/ files only extend it.
shared_scripts {
    'config/main.lua',      -- general, keys, creation, factions, ranks, map, wars, points, blood, missions, claims
    'config/rewards.lua',   -- mission payout tables
    'config/perks.lua',     -- level ladder, perk labels, stashes
    'config/dens.lua',      -- dens (player + fixed), seizing, cook, powder bench, shack interiors
    'config/fortraid.lua',  -- PvE fort raids: waves, boss, strongbox
    'config/drugs.lua',     -- the gang drug: perk, icons, seeds, sale, tree
    'config/locale.lua',    -- player-facing text (Locale)
}

-- ORDER MATTERS in both lists (no glob): later files call helpers defined in earlier ones.
client_scripts {
    '@pup-ui/ptt.lua',      -- push-to-talk survives NUI focus; must load first
    'client/main.lua',      -- the panel, the NUI bridge, the map blip layer
    'client/features.lua',  -- world prompts, the gang table, stashes, missions
    'client/den.lua',       -- the den DOOR (key, teleport, interiors)
    'client/fortraid.lua',  -- PvE fort raids
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',      -- gangs, members, ranks, territory, wars + the Gang* bridge
    'server/features.lua',  -- levels/perks, tables, stashes, dens, missions
    'server/fortraid.lua',  -- uses the Gang* bridge from the two above
    'server/blood.lua',     -- blood money: the currency, the ledger, what it buys
    'server/drugs.lua',     -- the gang drug: needs GangBloodMove from blood.lua
}

dependency {
    'vorp_core',
    'vorp_inventory',
    -- toasts, input dialogs and list menus
    'pup-ui',
}
