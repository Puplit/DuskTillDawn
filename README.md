<div align="center">

# Dusk Till Dawn

**A full western roleplay server for RedM, built on VORP.**

Jobs, economy, crime, law, property, gangs, mail, events and a complete staff panel, in 80+ connected resources.

*The West lives after dark.*

![RedM](https://img.shields.io/badge/RedM-FXServer-8B0000) ![VORP](https://img.shields.io/badge/framework-VORP-c9a24d) ![Lua](https://img.shields.io/badge/Lua-5.4-2C2D72) ![MariaDB](https://img.shields.io/badge/MariaDB-oxmysql-003545)

</div>

## Repository Notice

Dusk Till Dawn VORP Core is provided as a free, open-source, plug-and-play framework for the RedM community.

This repository is intended for distribution only.

- Issues, discussions, and pull requests are disabled.
- External contributions are not being accepted.
- No official technical support or future updates are guaranteed.
- The project is no longer actively maintained.

You are welcome to download, use, and modify the framework in accordance with its license.

> [!WARNING]
> **Expect some bugs.** These scripts ran on a live server, but not every feature saw heavy use, so some may still have bugs. Test on a private server before you open to players.
>
> **pup-gangs was tested by the developer, not by real players.** It was played through in testing, but no live community has used it yet, so bugs may show up once real players do. Try every part of it yourself (founding, wars, dens, raids, drugs) before you rely on it.

## Overview

Every system feeds the others. A gunsmith crafts the weapon a robber carries into a bank heist. The law gets the alert in the MDT, then cuffs, escorts and books the robber into prison. The fence pays the gang later, by letter. Gang points, perk XP and business ledgers update along the way.

| Area | Covers |
|---|---|
| **Economy** | Businesses, ledgers, taxes, player and society shops, a player market, banks and tellers |
| **Property** | Houses, motels, hotels, ranches, camps, hideouts, furniture, auctions and repossession |
| **Professions** | Farming, ranching, mining, lumber, crafting, gunsmithing, tailoring, undertaking, railroading and publishing |
| **Crime** | Robberies, bank heists, a travelling fence, moonshine, contraband, gangs and territory wars |
| **Law** | MDT, arrests, sentencing, prison, bounties, lawyers, judges and badges |
| **Life in the West** | Horses, wagons, pets, mail, bathing, doctors, emotes, scenes, seasonal events and blood moons |

## Architecture

**Stack:** RedM and FXServer with txAdmin, the VORP framework, Lua 5.4, oxmysql with MariaDB, and **pup-ui**, the server's own RDR2-style interface layer for menus, toasts, progress bars and placement.

Every `pup` resource follows the same layout:

```
resource/
├── config/      settings, data lists and player text
├── client/      client code
├── server/      server code
│   └── config.lua   webhooks and keys (server only, never sent to players)
├── shared/      code both sides load
├── html/        interface pages
├── sql/         install.sql
└── README.md    what it does, its commands and its config
```

- **The server decides.** Every price, permission and distance is checked server side. The interface only displays.
- **Lean config.** Config files keep short labels (units, `0 = off`); every setting is explained in that resource's README.
- **Server-only settings.** Webhooks and tokens live in each resource's `server/config.lua`, which is never sent to players.
- **One naming scheme.** Events are named after the script that owns them, such as `pup_shaman:ritualAsk`.

## Core scripts

The main pack lives in `[PupMain]`. Most scripts have their own README with full details.

| Script | Purpose |
|---|---|
| **pup_armory** | Melee weapons carried on the body and swung as base-game weapons, with a `/wp` position editor |
| **pup_business** | Businesses with ledgers, ranks, payroll, billing and duty; staff create and run businesses from vorp_admin's **Society** page |
| **pup_camps** | Clans with ranked camps, furniture, raids, upkeep, supply runs and a hunting wagon |
| **pup_gunsmith** | Weapon and ammo crafting, gun stores, and a customization bench with live preview |
| **pup_hideouts** | Instanced hideouts with moonshine stills, contraband sales, raids and a hideout bar |
| **pup_homestead** | Farming with 35 crops, water, plant health and the `/farm` almanac |
| **pup_library** | Write, print and publish books and newspapers, with royalties |
| **pup_mercantile** | NPC general stores, player shops and society shops; lawmen can raid player shops for contraband |
| **pup_mortician** | Undertaking with casket preparation, burials, contracts and treasure digging |
| **pup_postoffice** | PO boxes, chats with reply threads, emoji and reactions, letters, business chats and full player styling |
| **pup_railroad** | Player-owned trains with upgrades, delivery routes and track switching |
| **pup_ranchero** | Ranches, herds, trail drives, sale barns, chores and produce |
| **pup_realestate** | Houses, motels, keys, furniture, auctions and locked door signs |
| **pup_shaman** | Curses, animal forms, ancient trees and rank based rituals for tribes |
| **pup_staffdesk** | Parcels, character changes, a bug bounty shop, playtime and a Discord bridge |
| **pup_tailor** | Turn outfits into clothing items and dye them |
| **pup_tradepost** | A player market with buy orders, sell listings and price checks |
| **pup_workbench** | Station and campfire crafting with timed jobs and tool wear |

## Everyday systems: pup-misc

One resource holding 29 small features that don't need a script of their own. Each has its own folders and config, so any of them can be tuned alone.

| Group | Features |
|---|---|
| **Law** | Cuffing, escorting, loading prisoners into wagons, rank badges, searching and hogtie rules |
| **Bounty work** | Kill, capture and escort contracts from 7 boards, for parties of up to 4 |
| **Storage** | A portable 1,000 slot storage box, and job packs that fill as you mine, chop and farm |
| **Pets and outfitting** | 110 whistle-called pets with orders, and camps and trail gear from the stable |
| **Character** | Tattoos and makeup, wearable props, bandanas and pomade |
| **Survival** | Smokes with effects, bathhouses, river water and bottles, NPC doctors and knockouts |
| **Roleplay** | Emotes, photo poses, gestures, scenarios, furniture interactions and floating scene text |
| **World** | Guarma ferry, instanced zones, traffic density, mounted guns, sale bonuses and coordinate tools |

See [`[pup]/pup-misc/README.md`](txData/VORPCore_290045.base/resources/%5Bpup%5D/pup-misc/README.md) for every feature and command.

## Gameplay and world

| Resource | Purpose |
|---|---|
| **pup-ui** | Shared interface layer: toasts, menus, inputs, progress bars, placement and posses |
| **pup-gangs** | Hidden factions with ranks, territory, wars, sieges, fort raids and dens |
| **pup_robbery** | Walk-up robberies, multi-stage bank heists and a travelling fence |
| **pup-events** | Seasonal events: Dead of Night, The Purge and The Spring Hunt |
| **pup-bloodmoon** | A red moon raised by a werewolf's howl, an admin or an event |
| **pup-perks** | Civilian and crime XP ladders with 9 perk trees and an in-game guide |
| **pup-bank** | Accounts per branch, statements and a teller job |
| **pup-medical** | Doctor revives, syringes, death screen, respawn rules and job alerts |
| **pup-hotel** | Clerk-run hotel rooms in 3 tiers |
| **pup-voting** | Mayoral elections across 5 regions |
| **pup-magic** | Vampire feeding, blood vials and a staff spell kit |
| **pup-pinboard** | Town notice boards with text and image notices |
| **pup-spawnselect** | Spawn picker for towns, jobs, houses and last location |
| **pup_clothing** | Clothing stores, wardrobes, tint palettes and garment toggles |
| **pup_id** | Western identity certificates with character ID and signature |
| **pup-minigames** | Skill bar, safe crack, wire cut and other shared minigames |
| **legendaryhunt** | Lure traps on the right hunting ground at the right hour to draw legendary animals |
| **skinanimals** | Per-animal skinning rewards and mercy kills |
| **doorlocks** | In-game door creation with job, character or item access, and lockpicking |
| **Others** | pup-camera, pup-debugs, pup-emote, pup-loading, pup-phonograph, pup-props and pup-trash |

Also included: goldpan, huntingbirds, boatshops, vorp_crawfish and vorp_herbs. Gravedigging, mining and lumber, fishing and NPC looting are supported, but installed separately (see [Install these separately](#install-these-separately)).

## Law and stables

| Resource | Purpose |
|---|---|
| **pup-mdt** | A 1904 western terminal for records, sentencing, prison, cases, bounties, fines, payroll, lawyers and judges. Fines and jail need the officer close to the player, direct fines and bounty rewards are capped, and bounties are paid from the police ledger (all in its config) |
| **pup-stable** | Horses and wagons with transfers, vet care, bonding, training, breeding and wild horses; every horse has its own price |

## Admin menu: vorp_admin

A heavily extended control panel. Staff only see the pages their permissions allow, and every action is logged.

| Section | Pages |
|---|---|
| **Overview** | Dashboard, Players, Live Map, Anti-Cheat |
| **Server** | Tools, Teleports, Items DB, Consumables, Smokes, Crafting, Weapon Crafting, Events, Weather, Deaths, Door Locks, Server Bans |
| **Management** | Housing, Society, Ranches, Stores, Gangs, Perks, Banks, Hideouts, Camps, Curses, Farms, World Props |

- **Anti-cheat:** detects teleport, noclip and free cam, flags large or fast cash gains, and blocks banned models and spawn spam.
- **Bans:** match license, Steam, Discord and hardware tokens, with temporary bans, ban IDs for appeals and evasion reports.
- **Connection gates:** optional Steam account age and VPN checks.
- **Permissions:** VORP groups or Discord roles, with wildcard keys.
- **Open storage:** shops, camps, houses, society storage and hideouts open their real inventory for staff, from anywhere, with every admin move logged.

## Supporting resources

| Group | Resources |
|---|---|
| **VORP** | vorp_core, vorp_character, vorp_animations, vorp_lib, vorp_admin (vorp_inventory: VORP's download plus this server's files, see [vorp_inventory](#vorp_inventory)). vorp_utils and vorp_outlaws are included but not started by default: nothing here uses them. |
| **HUD and needs** | fred_hud, fred_metabolism (in `[fred]`; `/hud` also holds the Menus: Left/Right setting the pup menus follow) |
| **Voice** | mumble (pma-voice) |
| **Queue** | DiscordQueue |
| **Utility** | oxmysql, ox_lib, PolyZone, xsound, radialmenu, redm-ipls, qadr-safe, dataview_lua |
| **Chat and weather** | poodlechat (chat box), weathersync (time and weather sync, event hour windows, rain watering) |
| **Base** | mapmanager, spawnmanager, redm-map-one, hardcap (Cfx.re defaults) |
| **Extras** | lockpick, female-fix, interiors, moonshine_interiors (kept stopped), weapon_log, mumble_display |
| **Installed separately** | The maps (MacFarlane's Ranch, weed props). See [Install these separately](#install-these-separately). |

## Installation

No recipe is needed. The repository is the whole server (clone it into a folder with any name):

```
<your folder>/
├── LICENSE                          ← GPL-3.0, for the pup resources
├── README.md
├── docs/                            ← vorp_inventory files and third-party changes
├── Server-data/                     ← put the RedM artifacts here
├── txData/VORPCore_290045.base/
│   ├── server.cfg                   ← ready to use, ensure order already set
│   └── resources/
└── VORPCore_FRESH_2026-11-19.sql    ← empty database
```

1. **Artifacts:** download the [RedM server artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) and extract them into `Server-data`, so that `Server-data\FXServer.exe` exists.
2. **Database:** you need **MariaDB 10.5 or newer**. MySQL 8 is not supported: the tables use `TEXT` columns with default values and `ADD COLUMN IF NOT EXISTS`, which MySQL rejects. Before the first server start, import `VORPCore_FRESH_2026-11-19.sql` into an empty MariaDB server (HeidiSQL, phpMyAdmin or the `mariadb` command line). It creates the `VORPCore_290045` database and every table for you, with no player data. Every resource's `sql/install.sql` is already included in it; those files are only needed to add a single resource to an existing database. To use another database name, change it at the top of that file and in `mysql_connection_string` in `server.cfg`.
3. **Keys:** at the top of `txData\VORPCore_290045.base\server.cfg`, fill in your Cfx.re license key (`sv_licenseKey`), Steam Web API key (`steam_webApiKey`) and database login (`mysql_connection_string`).
4. **Fred:** nothing to do. `fred_metabolism` and `fred_hud` are included in `resources\[fred]`, already set up for this server.
5. **vorp_inventory:** download VORP's copy, then copy this server's files over it. See [vorp_inventory](#vorp_inventory) below.
6. **Optional third-party scripts:** see [Install these separately](#install-these-separately) below. None of them is needed to start.
7. **Start:** run `Server-data\FXServer.exe`. txAdmin opens in your browser: choose **Existing Server Data** and point it at `txData\VORPCore_290045.base`.
8. **OneSync:** in txAdmin, open **Settings > FXServer** and set **OneSync** to **On**, then restart the server. `server.cfg` doesn't set it; txAdmin does.
9. **Make yourself admin:** join once so your account exists, then do one or both of these:
   - In `server.cfg`, uncomment one of the two lines at the bottom and put in your own identifier, then restart. This gives you the `group.admin` commands (weather, time, debug and so on):
     ```
     # add_principal identifier.fivem:YOUR_ID group.admin   # your own id, then uncomment
     # add_principal identifier.discord:YOUR_ID group.admin   # your own id, then uncomment
     ```
   - In the database, set your row's `group` in the `users` table to `admin` (for example `` UPDATE users SET `group` = 'admin' WHERE identifier = 'steam:...'; ``), then reconnect. This is the VORP group that opens the vorp_admin panel and the staff tools.
10. **Set up the world.** The database starts empty apart from items, workbench recipes, penal codes, gang territories and food effects. In game:
    - **Businesses:** stand where one should be and use **Create Business Here** on vorp_admin's Society page. That makes its ranks, ledger, stash and mail address. It has no map blip until you add a **Management Point** to it. See the pup_business and housing READMEs.
    - **Jobs:** give staff and players their VORP jobs (police, doctor, `standardtrain` for the railroad and so on).
    - **Doors:** make them with `/createdoor`, or list them in doorlocks' `Config.StartupDoors`.
    - **Workbench recipes:** 762 are included. Add or change them on vorp_admin's Crafting page.
    - Gunsmith recipes and stations, workbench stations and gang dens fill themselves on the first start.
    - Fred's own install SQL isn't needed: the food effects (`fred_consumables`) are already in the database.

### vorp_inventory

1. Download [VORPCORE/vorp_inventory-v2](https://github.com/VORPCORE/vorp_inventory-v2). The tested version is [this zip](https://github.com/VORPCORE/vorp_inventory-v2/archive/7927b22acf7e014b1fcb9065c6267ee5b721b1b3.zip); use it if VORP's newest doesn't match. Put it in `resources\[VORP]\vorp_inventory` (the folder must be called `vorp_inventory`). Install `vorp_lib` too.
2. Copy everything in [`docs/vorp_inventory/vorp_inventory/`](docs/vorp_inventory/vorp_inventory) into it. Overwrite all files.
3. Database: the fresh dump already has it. On a database made only from VORP's SQL, run the SQL in [`docs/vorp_inventory/README.md`](docs/vorp_inventory/README.md).
4. Restart the whole server.

[`docs/vorp_inventory/README.md`](docs/vorp_inventory/README.md) has the details and the list of VORP files that are replaced.

With VORP's own copy alone the server still starts, but container, camp, hideout, store and search transfers, gunsmith repairs and tiers, evidence lockers, storage boxes and the restart lock don't work.

### Install these separately

These resources have no licence (or no known author), so this repository can't include them. Download each one from its author and put it in the folder shown; where no public source is known, use your own copy or any resource that does the same job. Then in `server.cfg`, replace its line `# install separately: <name> (see README)` with `ensure <name>`. Resources in `[standalone]` or `[maps]` with no such line are started by `ensure [standalone]` / `ensure [maps]`; vorp_imapviewtool goes in `[VORP]` and needs its own `ensure vorp_imapviewtool` line. The changes this server made to them are described in [docs/third-party-changes.md](docs/third-party-changes.md).

| Resource | Author | Link | Folder | Needed? |
|---|---|---|---|---|
| gravedigging | devchacha | [Devchacha01/devchacha-graverobbery](https://github.com/Devchacha01/devchacha-graverobbery) | `[standalone]` | Optional. The original is for RSG/ox; see docs/third-party-changes.md for the VORP port. |
| miner_lumber | Blue | no public source found | `[standalone]` | Optional (mining and lumberjacking). |
| macfarlanes_ranch | Younra | [Younra/macfarlanes_ranch](https://github.com/Younra/macfarlanes_ranch) | `[maps]` | Optional (map). |
| prop_weed | Hobbs (RisingSunRP) | [DerHobbs/Weed_plant_prop_for_RedM](https://github.com/DerHobbs/Weed_plant_prop_for_RedM) | `[maps]` | Optional. Without it, pup_homestead's Hemp and Gang Crop plants grow invisibly. |
| vorp_barbershop | VORP | [VORPCORE/vorp_barbershop_lua](https://github.com/VORPCORE/vorp_barbershop_lua) | `[VORP]` | Optional (barber chairs). |
| vorp_fishing | VORP | [VORPCORE/vorp_fishing](https://github.com/VORPCORE/vorp_fishing) | `[VORP]` | Optional (fishing). |
| vorp_walkanim | VORP | [VORPCORE/Vorp_walkanim](https://github.com/VORPCORE/Vorp_walkanim) | `[VORP]` | Optional. Without it, walk styles still work but aren't saved. |
| vorp_lootnpcs | VORP | [VORPCORE/vorp_lootnpcs](https://github.com/VORPCORE/vorp_lootnpcs) | `[VORP]` | Optional (loot dead NPCs). |
| vorp_imapviewtool | VORP | [VORPCORE/vorp_imapviewtool](https://github.com/VORPCORE/vorp_imapviewtool) | `[VORP]` | Optional (developer tool). |

### Music, sounds and maps

- **No music ships.** For loading screen music, put your own `theme.mp3` in `[pup]/pup-loading/html/audio/` and list it in `html/config.js` (`music.tracks: ['audio/theme.mp3']`). With no track, the screen is silent and the music controls are hidden.
- **Purge siren:** put your own siren file in `[pup]/pup-events/sounds/` and set `Config.Events.purge.siren.file` in `config/events.lua`. With no file, the purge starts in silence.
- **Live maps:** the admin live map, the spawn picker, the pup-ui map block and the pup-gangs territory map load kibook/webmap's map image from `raw.githubusercontent.com`, so players need internet access for it. Without it, the maps show a plain background and every pin and button still works.

### Optional setup

- **Discord logs:** every webhook on the server is in a `server/config.lua`, see [Discord webhooks](#discord-webhooks) below.
- **Discord bots:** the Staff Desk bridge needs a bot token in `pup_staffdesk/server/config.lua`; leave it blank to keep it off.
- **Discord whitelist:** DiscordQueue ships with the whitelist and the Discord requirement off (`whitelistRequired` and `requireDiscord`), so anyone can join. To use it, put the bot token in `[discord]/DiscordQueue/server/config.lua`, your guild id (`guildId`) and role ids (`Config.RolePriority`) in `[discord]/DiscordQueue/config/main.lua`, then turn `whitelistRequired` on.
- **Other Discord ids:** the role ids in `vorp_admin/config/discord.lua` and the Discord Rich Presence app id in `vorp_core/config/config.lua` are blank placeholders. Fill them in to use those features.
- **VPN gate:** add a proxycheck.io key in `vorp_admin/server/config.lua`.
- **Staff:** give staff a VORP group (`admin` or `moderator`), or map Discord roles in `vorp_admin/config/discord.lua`. `/cam` staff go in `pup-camera/server/config.lua`.
> If you fork this repo, don't push your own keys, webhooks, bot tokens or Steam IDs: blank them in `server.cfg` and the `server/config.lua` files first.

## Discord webhooks

**Every Discord webhook on the server lives in one place: the `server/config.lua` file of the resource that sends it.** There are no webhooks anywhere else, not in `server.cfg` and not in the normal `config/` files.

- They all ship **blank** (`""`), which means that log is off.
- To turn one on, paste the webhook URL between the quotes and restart that resource (`ensure <resource>`).
- `server/config.lua` is loaded only on the server, so players never receive your webhook URLs.
- Each file has a short comment above every webhook saying what it logs.

| Folder | Resources with a `server/config.lua` |
|---|---|
| `[VORP]` | vorp_core, vorp_character, vorp_admin, vorp_inventory (from `docs/vorp_inventory/vorp_inventory/server/config.lua`) |
| `[PupMain]` | pup_business, pup_camps, pup_gunsmith, pup_hideouts, pup_homestead, pup_library, pup_mercantile, pup-mdt, pup-stable, pup_mortician, pup_postoffice, pup_railroad, pup_ranchero, pup_realestate, pup_staffdesk, pup_tradepost, pup_workbench |
| `[pup]` | legendaryhunt, pup-bank, pup-debugs, pup-events, pup-magic, pup-medical, pup-misc, pup-phonograph, pup-pinboard, pup-spawnselect, pup-voting, pup_robbery, skinanimals |
| `[standalone]` | boatshops, huntingbirds, weapon_log |
| `[discord]` | DiscordQueue |

Some of these files also hold other server-only settings, such as the Staff Desk and DiscordQueue bot tokens and vorp_admin's proxycheck.io key. `pup-camera/server/config.lua` holds only the `/cam` staff list.

Players can also give their own house, business, shop, camp, ranch, hideout or undertaker its own webhook from the in-game menus. Those are saved in the database, not in any file.

## Credits and licenses

The `pup` resources are written by **Puppet** and released under the **GNU GPL-3.0** (see [LICENSE](LICENSE)): you can use, change and share them, as long as anything you share stays open source under the same licence. They are built on or alongside the work below, and each of those authors' own licence applies to their code.

The VORP resources in `[VORP]` (vorp_admin, vorp_animations, vorp_character, vorp_core, vorp_crawfish, vorp_herbs, vorp_lib, vorp_outlaws, vorp_utils) are **GPL-2.0** (vorp_character: GPL-2.0 or later). They keep their own `LICENSE` file, and each has a `MODIFIED.md` listing what was changed. Those changes are under the same GPL-2.0 licence as the original, not GPL-3.0.

All bundled fonts are free fonts, with each licence next to its font file: Oswald, IM Fell English, Share Tech Mono and Roboto (SIL Open Font License 1.1), and Roboto Slab and Roboto Mono (Apache 2.0). Roboto and Roboto Mono are in ox_lib.

**Game art:** the Red Dead Redemption 2 menu textures, icons and item pictures taken from the game (in pup-ui, pup-perks, ox_lib, the VORP UIs, qadr-safe, female-fix and the vorp_inventory item pictures) are © Rockstar Games, used for RedM modding. They are not covered by the GPL licences here. The exception in pup-ui is `cs_bg`, `cs_btn`, `cs_header`, `cs_sep`, `selsected`, `menu_icon_circle` and `tick` in `html/img/western/`: those PNGs are this project's own drawings (GPL-3.0, SVG sources in `[pup]/pup-ui/art-src/western/`).

**Game names:** weapon and component names (`WEAPON_*`, `COMPONENT_*`) and store item names are Red Dead Redemption 2 game names. The gunsmith part catalogue, the NPC store tables and all weapon labels were rebuilt for this server in its own layout and wording.

**Based on free community scripts:** pup-bank and the pup-misc smokes, scene, police, grandmas, knockout, coordtool, scenario and gestures features started from free scripts shared in the RedM / FiveM community (authors unknown) and were reworked or rewritten for this server. pup-bank and the knockout loop have since been rewritten completely; pup-bank keeps the original `bank_users` column layout for database compatibility. If you wrote one of the originals and want credit or want it removed, contact the repository owner through GitHub.

| Resource | Original author and license | Source |
|---|---|---|
| VORP framework and `vorp_*` resources | The VORP team (outsider, Bytesizd, blue, BlackPegasus, adamdrakon, Snapopotamus and others) | [github.com/VORPCORE](https://github.com/VORPCORE) |
| vorp_admin | VORP @outsider, **GPL-2.0**, modified by Puppet | [VORPCORE/vorp_admin](https://github.com/VORPCORE/vorp_admin) |
| DiscordQueue | JaredScar, with Badger's Discord API merged in, both **MIT** | [JaredScar/Bad-DiscordQueue](https://github.com/JaredScar/Bad-DiscordQueue), [JaredScar/Badger_Discord_API](https://github.com/JaredScar/Badger_Discord_API) |
| doorlocks | Based on **gs_doorlocks** by _G[S]cripts (GlitchOo), **GPL-3.0** | [GlitchOo/gs_doorlocks](https://github.com/GlitchOo/gs_doorlocks) |
| pup-minigames | **BOII Development** (now PlayingInTraffic), **GPL-3.0**, modified by Puppet, 2026. Its 12 `.ogg` sounds and 4 Canva images are inherited unchanged from boii_minigames (original source unknown). pup-ui's `door_denied.ogg` is the same file as pup-minigames' `knob.ogg` | [boiidevelopment/boii_minigames](https://github.com/boiidevelopment/boii_minigames) (new version: [playingintraffic/mgc](https://github.com/playingintraffic/mgc)) |
| vorp_inventory | VORP team. `docs/vorp_inventory/vorp_inventory/` holds VORP's files as modified by this server, under VORP's licence (`license.md` in that folder). The `pup_*` files and `server/config.lua` there are Puppet's own code (GPL-3.0). The item pictures in its `html/img/items/` are not Puppet's work: most are RDR2 game icons (© Rockstar Games) or community-made icons |  [VORPCORE/vorp_inventory-v2](https://github.com/VORPCORE/vorp_inventory-v2) |
| vorp_barbershop, vorp_fishing, vorp_walkanim, vorp_lootnpcs, vorp_imapviewtool | VORP team, no licence published (not included, install separately) | [github.com/VORPCORE](https://github.com/VORPCORE) |
| gravedigging | devchacha, ported to VORP (not included, install separately) | [Devchacha01/devchacha-graverobbery](https://github.com/Devchacha01/devchacha-graverobbery) |
| fred_hud, fred_metabolism | SirFreddie (Fred), an edit of kamelzarandah's edit of Malik's spaghetti_metabolismo; included with this server's changes (HUD layout editor, menu side setting, Eco Boost gauge, indoor shelter bonus) | [SirFreddie/fred_metabolism_free](https://github.com/SirFreddie/fred_metabolism_free) |
| Garment, propset and camera-effect names (pup_clothing, pup_tailor, pup-misc) | femga / rdr3_discoveries community research | [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries) |
| Door list (pup_realestate `client/doors.lua`) | femga and contributors, rdr3_discoveries door hash list (door hashes, models and positions: game data). No licence is stated. Re-laid out for pup_realestate; two doors of existing houses added | [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries/tree/master/doorHashes) |
| pup-magic vampire feeding | First based on Jeffy DeTexas' "feed" resource (courtesy note; rewritten) | |
| DataView (dataview_lua, used by pup-misc, skinanimals, huntingbirds) | gottfriedleibniz (DataView for Lua), shared through femga/rdr3_discoveries. No licence is stated. | [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries/blob/master/AI/EVENTS/dataview_by_Gottfriedleibniz.lua) |
| miner_lumber | Blue (not included, install separately) | |
| radialmenu | Murphy Workshop, **GPL-3.0**, modified by Puppet (see its `MODIFIED.md`) | [levraimurphy/murphy_radialmenu](https://github.com/levraimurphy/murphy_radialmenu) |
| qadr-safe | abdulkadiraktas, **MIT** (its `LICENSE` names Victor Hall, 2021) | [abdulkadiraktas/qadr-safe](https://github.com/abdulkadiraktas/qadr-safe) |
| PolyZone | Michael Afrin, **MIT** | [mkafrin/PolyZone](https://github.com/mkafrin/PolyZone) |
| xsound | Xogy, **MIT** | [Xogy/xsound](https://github.com/Xogy/xsound) |
| redm-ipls | Heather Rhodes, **MIT** (its `LICENSE`). IPL list by koil, with CryptoGenics, PitchSean and Plouffe (see its README). No public repository found | [koil's RedM Interiors thread](https://forum.cfx.re/t/redm-interiors-wip/981753) |
| three.js r151 (inside vorp_lib) | Three.js Authors, **MIT** (header kept in `three.module.js`) | [mrdoob/three.js](https://github.com/mrdoob/three.js) |
| Safe crack and door lock sounds (pup-minigames, pup-ui) | [Fesliyan Studios](https://www.fesliyanstudios.com), free-use terms | |
| mumble | AvarianKnight (pma-voice), **MIT** | [AvarianKnight/pma-voice](https://github.com/AvarianKnight/pma-voice) |
| objectloader | kibukj (kibook), included (console prints quietened, see docs/third-party-changes.md). Its XML parser SLAXML is by Gavin Kistner, **MIT** | [kibook/redm-objectloader](https://github.com/kibook/redm-objectloader) |
| weathersync, poodlechat | kibukj (kibook), included with this server's changes (see docs/third-party-changes.md). poodlechat bundles Vue 2.3.3 (Evan You, **MIT**) and animate.css 3.5.2 (Daniel Eden, **MIT**) | [kibook/weathersync](https://github.com/kibook/weathersync), [kibook/poodlechat](https://github.com/kibook/poodlechat) |
| oxmysql | Overextended (now Community Ox), **LGPL-3.0** | [communityox/oxmysql](https://github.com/communityox/oxmysql) |
| ox_lib | Overextended (now Community Ox), **LGPL-3.0**. RedM build with a restyled UI by Rexshack-RedM, font changed by Puppet. The restyled UI ships compiled only: its source isn't public upstream either (see its `MODIFIED.md` for swapping in the official build) | [communityox/ox_lib](https://github.com/communityox/ox_lib), [Rexshack-RedM/ox_lib](https://github.com/Rexshack-RedM/ox_lib) |
| Maps: prop_weed, macfarlanes_ranch | Hobbs@RisingSunRP, Younra (not included, install separately) | [DerHobbs/Weed_plant_prop_for_RedM](https://github.com/DerHobbs/Weed_plant_prop_for_RedM), [Younra/macfarlanes_ranch](https://github.com/Younra/macfarlanes_ranch) |
| cfx-server-data: mapmanager, spawnmanager, redm-map-one, hardcap | Cfx.re, **MIT**. Default server resources, shipped unchanged apart from the header | [citizenfx/cfx-server-data](https://github.com/citizenfx/cfx-server-data) |
| Live map image (not shipped, loaded at runtime) | kibook | [kibook/webmap](https://github.com/kibook/webmap) |
| Leaflet 1.9.4 (vorp_admin) | Volodymyr Agafonkin and CloudMade, **BSD-2-Clause** (`vorp_admin/html/vendor/LICENSE-leaflet.txt`) | [leafletjs.com](https://leafletjs.com) |
| jQuery (pup-minigames, xsound, vorp_core) and jQuery UI (pup-minigames) | OpenJS Foundation, **MIT**. Loaded from a CDN at runtime, except in lockpick, which bundles its own copy | [jquery.com](https://jquery.com) |
| Fonts: Oswald, IM Fell English, Share Tech Mono, Roboto, Roboto Slab, Roboto Mono | Their font authors, **OFL 1.1** / **Apache 2.0** | [google/fonts](https://github.com/google/fonts) |
| lockpick, female-fix, interiors, moonshine_interiors, weapon_log, mumble_display | Authors unknown; publicly shared RedM resources, included as found. lockpick's page and art were saved from mixi.host (author unknown) and it bundles jQuery (**MIT**) and GSAP TweenMax (GreenSock standard licence). female-fix contains modified Rockstar Games ped assets | |

*If you are an original author and something here is not credited the way you want, contact the repository owner through GitHub and it will be fixed or removed.*

<div align="center">

**Dusk Till Dawn**, built by Puppet

</div>
