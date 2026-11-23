# Documentation as well as updates to this resource have been moved to: https://docs.badger.store/fivem-discord-scripts/bad-discordqueue

## Jared's Developer Community [Discord]
[![Developer Discord](https://discordapp.com/api/guilds/597445834153525298/widget.png?style=banner4)](https://discord.com/invite/WjB5VFz)

## All I ask

All I ask is that if you enjoy this resource, please give it a like on the forum page, on GitHub (if you have an account), and pop me a follow over on GitHub.

## What is it?

This is basically a discord queue for logging into a server. When you connect to the server, you get added to a queue. Depending on your priority, you can be at the back of the queue or added to the top automatically. This all depends on what discord roles you have considering it works off of priority numbers. I'm not the best at writing descriptions. I'll be honest, I personally am probably not going to use this script, but I had a lot of people request this script from me, so here it is. Why not increase my rep within the Fivem community?

## Dependencies

https://github.com/sadboilogan/discord_perms

## Installation

https://www.youtube.com/watch?v=sjbFzkII2T0

## Screenshots 

![Queue Gif](https://i.gyazo.com/3606be50c8770850b86a83fd8efbec18.gif)

## Configuration

All settings are server side (this is a connection queue; `client.lua` reads no config).

```
config/main.lua             -- Config: General, Integrations, Queue, CrashPriority, Discord, RolePriority
config/locale.lua           -- Locale: connecting-screen text (prefix, queue and rejection messages)
server/config.lua           -- Secrets: bot token / webhook (server only, never sent to players)
```

- `Secrets.Discord.botToken` (set it in `server/config.lua`): the Discord bot token. **If it is empty every role
  lookup fails, and with `Config.Discord.whitelistRequired = true` the queue rejects EVERYONE as not
  whitelisted.**
- `Secrets.Webhooks.queue`: optional webhook for queue join/leave logs.
- `Config.Discord`: `guildId`, `multiguild` / `guilds`, `roleList`, role caching, and the rejection
  rules `requireSteam`, `requireDiscord`, `whitelistRequired`.
- `Config.Queue`: `defaultPriority`, `connectorsPerTick`, `ghostCheckSeconds`, `showQueueInHostname`,
  `onlyWhenFull`, `loadingFrames`.
- `Config.CrashPriority`: `enabled`, `windowSeconds`, `bonus` - reconnect boost after an in-session drop.
- `Config.RolePriority`: the whitelist and priority list. LOWER number = HIGHER priority.

```
Config.RolePriority = {
    ['<discord role id>'] = { priority = 1,  message = "You are being connected [{QUEUE_NUM}/{QUEUE_MAX}]:" },
    ['<discord role id>'] = { priority = 60, message = "You are being connected [{QUEUE_NUM}/{QUEUE_MAX}]:" },
}
```
- Replace `<discord role id>` with the Discord role ID you want to set up priority for.

## Download

https://github.com/JaredScar/Bad-DiscordQueue
