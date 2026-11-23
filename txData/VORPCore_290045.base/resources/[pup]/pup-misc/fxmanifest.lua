-- pup-misc: many small features in one resource; each has its own folder under client/, server/ and config/

fx_version 'adamant'
game 'rdr3'
version '1.0.0'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

-- ONE NUI page per resource: the tattoo mirror menu owns it
ui_page 'html/tattoos/index.html'
files {
    'html/tattoos/index.html',
    'html/tattoos/style.css',
    'html/tattoos/app.js',
    'html/tattoos/img/*.png',
    'html/tattoos/img/icons/*.png',
    'html/tattoos/img/slider/*.png',
    'html/tattoos/fonts/*.ttf',
}

shared_scripts {
    -- HogtieConfig + HogtieLocale: the server reads the lasso rules
    'config/hogtie/main.lua',
    'config/hogtie/locale.lua',
    -- BathhouseConfig + BathhouseLocale: the server takes the prices, the bathhouse list and the text
    'config/bathing/main.lua',     -- creates BathhouseConfig, so first
    'config/bathing/houses.lua',   -- fills BathhouseConfig.Houses
    'config/bathing/locale.lua',
    -- CannonConfig + CannonLocale, read on BOTH sides: the server gates on Access, the client reads models
    'config/cannon/main.lua',
    'config/cannon/locale.lua',
    -- GrandmasConfig + GrandmasLocale, read on BOTH sides: the server re-validates the distance to a doctor and its price
    'config/grandmas/main.lua',
    'config/grandmas/doctors.lua',
    'config/grandmas/locale.lua',
    -- TattooConfig + TattooLocale, read on BOTH sides (the server charges TattooConfig.Prices)
    'config/tattoos/main.lua',
    'config/tattoos/locale.lua',
    -- PetsConfig + PetsLocale, read on BOTH sides: the SERVER resolves item -> animal from it
    'config/pets/main.lua',
    'config/pets/pets.lua',
    'config/pets/anims.lua',
    'config/pets/locale.lua',
    -- GuarmaConfig + GuarmaLocale, read on BOTH sides: the server re-checks the dock distance, the price and the job
    'config/guarma/main.lua',
    'config/guarma/locale.lua',
    -- PoliceConfig + PoliceLocale, read on BOTH sides: the server gates on PoliceConfig.Jobs.law, the client reads keys and badges
    'config/police/main.lua',
    'config/police/badges.lua',
    'config/police/locale.lua',
    'config/ecoboost/main.lua',     -- EcoBoostConfig: boost, cap, cooldown, eligible sales
    'config/ecoboost/locale.lua',   -- EcoBoostLocale
    -- PropsConfig + PropsLocale: main.lua first (creates PropsConfig), props.lua = items + placements
    'config/props/main.lua',
    'config/props/props.lua',
    'config/props/locale.lua',
    'config/pomade/main.lua',    -- PomadeConfig + PomadeLocale: the item + the male-only gate
    -- SmokesConfig + SmokesLocale: smokes.lua seeds the smokes table and is the fallback when the database is down
    'config/smokes/main.lua',
    'config/smokes/smokes.lua',
    'config/smokes/locale.lua',
    -- StorageConfig + StorageLocale: main.lua first (creates StorageConfig), boxes.lua folds packs into Boxes
    'config/storagebox/main.lua',
    'config/storagebox/boxes.lua',
    'config/storagebox/locale.lua',
    -- BountyConfig (main.lua first: it creates the table the data files fill) + BountyLocale
    'config/bountyhunting/main.lua',
    'config/bountyhunting/locale.lua',
    'config/bountyhunting/peds.lua',
    'config/bountyhunting/kill.lua',
    'config/bountyhunting/arrest.lua',
    'config/bountyhunting/escort.lua',
    'shared/bountyhunting/functions.lua',
    -- SearchConfig + SearchLocale: the server re-checks jobs, the new-player shield and the steal toggles
    'config/search/main.lua',
    'config/search/blacklist.lua',
    'config/search/locale.lua',
    'shared/search/purge.lua',   -- swaps SearchConfig settings while the purge is live (after config)
    'shared/search/functions.lua',
    -- SceneConfig (main.lua first: styles.lua fills it) + SceneLocale + shared/scene/main.lua's inline colour markup, read by BOTH sides
    'config/scene/main.lua',
    'config/scene/styles.lua',
    'config/scene/locale.lua',
    'shared/scene/main.lua',
    -- ErpConfig + ErpLocale: zone list + the paired poses, read on both sides
    'config/erp/main.lua',
    'config/erp/emotes.lua',
    'config/erp/locale.lua',
    -- OutfitterConfig + OutfitterIndex + OutfitterLocale: the server re-checks price, limit and stable distance from here
    'config/outfitter/main.lua',
    'config/outfitter/items.lua',
    'config/outfitter/locale.lua',
    -- WaterConfig + WaterLocale: the server registers the bottle / antidote items and rolls the poison from them
    'config/river/main.lua',
    'config/river/locale.lua',
    -- InstanceConfig + InstanceLocale: the server reads Buckets, the client the zones
    'config/instance/main.lua',
    'config/instance/zones.lua',
    'config/instance/locale.lua',
    'config/coordtool/main.lua',  -- CoordtoolConfig + CoordtoolLocale: command names on both sides
}

client_scripts {
    '@pup-ui/ptt.lua', -- push-to-talk survives NUI focus; must load first
    'shared/dataview.lua',
    'config/knockout/main.lua',  -- KnockoutConfig + KnockoutLocale
    'client/knockout/main.lua',
    'config/traffic/main.lua',   -- TrafficConfig: density multipliers
    'client/traffic/main.lua',
    -- ScenarioConfig (main.lua first: scenarios.lua fills it) + ScenarioLocale
    'config/scenario/main.lua',
    'config/scenario/scenarios.lua',
    'config/scenario/locale.lua',
    'client/scenario/gunspin.lua',
    'client/scenario/main.lua',
    'client/hogtie/main.lua',
    -- interactions: common.lua publishes InteractionsUtil; config/interactions/main.lua creates InteractionsConfig and must load before models.lua and interactions.lua (interactions.lua reads InteractionsConfig.Models)
    'client/interactions/common.lua',
    'config/interactions/main.lua',
    'config/interactions/models.lua',
    'config/interactions/interactions.lua',
    'config/interactions/locale.lua',
    'client/interactions/main.lua',
    '@PolyZone/client.lua',      -- zone shapes for client/instance/zones.lua
    'client/instance/zones.lua',
    'client/instance/main.lua',
    -- river: main.lua publishes WaterClient and MUST load before washbarrel.lua
    'client/river/main.lua',
    'client/river/washbarrel.lua',
    'client/bathing/movenet.lua',       -- BathhouseMoveNet: move networks with init params; before main.lua
    'client/bathing/main.lua',
    'client/coordtool/main.lua',
    'config/ragdoll/main.lua',   -- RagdollConfig + RagdollLocale: key, gates
    'client/ragdoll/main.lua',
    -- EmotesConfig (main.lua first: emotes.lua / poses.lua fill it) + EmotesLocale
    'config/emotes/main.lua',
    'config/emotes/emotes.lua',
    'config/emotes/poses.lua',
    'config/emotes/locale.lua',
    'client/emotes/main.lua',
    -- poses.lua calls EmotesPlayAnim, so it MUST load after client/emotes/main.lua
    'client/emotes/poses.lua',          -- /photopose: plays EmotesConfig.Poses
    -- gestures reuses client/emotes/main.lua's anim loader through the Emotes* globals it publishes, so it MUST load after it
    'config/gestures/main.lua',  -- GesturesConfig: the X / L keybinds
    'config/gestures/locale.lua',
    'client/gestures/main.lua',
    'config/bandana/main.lua',   -- BandanaConfig: /bandana mask up/down
    'config/bandana/locale.lua',
    'client/bandana/main.lua',
    'client/cannon/main.lua',         -- CannonConfig comes from shared_scripts
    'client/grandmas/main.lua',       -- GrandmasConfig comes from shared_scripts
    -- overlay.lua defines TattooExistAndReset, which expression.lua calls; nui.lua is the mirror menu and reads both
    'client/tattoos/overlay.lua',
    'client/tattoos/expression.lua',
    'client/tattoos/nui.lua',
    'client/pets/main.lua',           -- PetsConfig comes from shared_scripts
    'client/guarma/main.lua',         -- GuarmaConfig comes from shared_scripts
    -- badges.lua defines CreateBadge/AttachBadge/EquipBadgeByGrade, which client/police/main.lua's duty handler calls - order matters
    'client/police/badges.lua',
    'client/police/main.lua',
    'client/props/main.lua',          -- PropsConfig comes from shared_scripts; worn defs ride in pup_props:toggle
    'client/pomade/main.lua',         -- the pomade hair state + apply animation
    'client/storagebox/main.lua',     -- carry/place the portable boxes
    'client/smokes/main.lua',         -- pipe/cigar/chew anims, the high and its filters
    -- bountyhunting: NPC kill/arrest/escort contracts off the board prompt
    'client/bountyhunting/main.lua',
    -- search: rob a hogtied/cuffed player. pupmenu.lua publishes PupMenu and MUST load before client/search/main.lua
    'client/search/pupmenu.lua',
    'client/search/main.lua',
    -- scene: /scene props and text markers. Globals prefixed Scene*
    'client/scene/main.lua',
    -- erp: /erp invite menu, prompt to accept, paired placement
    'client/erp/main.lua',
    -- outfitter: uses PupMenu, so it must stay below client/search/pupmenu.lua
    'client/outfitter/main.lua',
}

server_scripts {
    'config/search/server.lua',  -- server only: what must not reach clients
    'server/config.lua',         -- server only: Secrets.Webhooks + SearchServerConfig.SuperBypass (after config/search/server.lua)
    -- the MySQL global: server/storagebox/*.lua, server/tattoos/main.lua and server/scene/main.lua use it
    '@oxmysql/lib/MySQL.lua',
    'server/cannon/main.lua',
    'server/grandmas/main.lua',       -- sets the shared VorpCore global; must stay above props/pomade
    'server/tattoos/main.lua',
    'server/hogtie/main.lua',
    'server/instance/main.lua',
    'server/river/main.lua',
    'server/bathing/main.lua',
    'server/coordtool/main.lua',
    'server/pets/main.lua',
    'server/guarma/main.lua',
    'server/police/main.lua',
    'server/bandana/main.lua',   -- hands the client Character.comps for /bandana
    'server/ecoboost/main.lua',
    'server/props/main.lua',          -- reads PropsConfig.Props (shared)
    -- server/pomade/main.lua reads the shared VorpCore global set by server/grandmas/main.lua above, so it must stay below it
    'server/pomade/main.lua',
    'server/smokes/main.lua',         -- smokes: DB-backed usable items
    -- storagebox: core.lua first (creates PupSBX), then logs, then the rest; webhooks from Secrets.Webhooks.storagebox (server/config.lua).
    -- boxes.lua defines PupStorageBoxNoteTransfer, which server/search/main.lua calls, so it stays above search.
    'server/storagebox/core.lua',
    'server/storagebox/logs.lua',
    'server/storagebox/boxes.lua',
    'server/storagebox/transfer.lua',
    'server/storagebox/packs.lua',
    'server/storagebox/trade.lua',
    'server/bountyhunting/main.lua',
    -- search: webhook comes from Secrets.Webhooks.search.admin; scene: from Secrets.Webhooks.scene.log
    'server/search/main.lua',
    'server/scene/main.lua',
    'server/erp/main.lua',
    -- outfitter: owns the money, the limit and the world list of pitched camps
    'server/outfitter/main.lua',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'PolyZone',
    'oxmysql',   -- several modules use the database (storagebox, tattoos, scene, ...)
}
