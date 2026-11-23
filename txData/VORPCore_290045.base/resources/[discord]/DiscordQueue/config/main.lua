-- DiscordQueue | main settings (server side only)
-- Connection queue with Discord role priority/whitelist. Bot token: set it in server/config.lua.

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug = false,                -- print crash-priority debug lines to the server console
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
-- Nothing to switch here. Other resources call into this one:
--   exports.DiscordQueue:GetDiscordRoles(src)  -- used by vorp_admin (server/pup_discordPerms.lua)
--   exports.DiscordQueue:IsDiscordConfigured()
--   exports.DiscordQueue:ClearDiscordRoleCache(discordId)
-- Optional Discord webhook for queue logs: Secrets.Webhooks.queue in server/config.lua.
Config.Integrations = {}

-------------------------------------------------------------------------------
-- QUEUE
-------------------------------------------------------------------------------
-- Connecting-animation pieces (badger, herb, broccoli), written as escapes so this file stays ASCII.
local B, H, K = '\u{1F9A1}', '\u{1F33F}', '\u{1F966}'

Config.Queue = {
    defaultPriority     = 200,    -- priority for players with no ranked role (LOWER number = sooner)
    connectorsPerTick   = 40,     -- how many players may be connecting at the same time
    ghostCheckSeconds   = 40,     -- how often to drop players who left while waiting in the queue
    showQueueInHostname = false,  -- prefix sv_hostname with "[queued/queued+1]" while people wait
    onlyWhenFull        = false,  -- true = only queue players when the server is full

    -- Frames cycled after the queue message (one every 3 seconds while waiting).
    loadingFrames = {
        B..H..B..H..B..H,
        H..B..H..B..H..B,
        B..H..B..H..B..K,
        H..B..H..B..K..B,
        B..H..B..K..B..K,
        H..B..K..B..K..B,
        B..K..B..K..B..K,
        K..B..K..B..K..B,
        B..K..B..K..B..H,
        K..B..K..B..H..B,
        B..K..B..H..B..H,
        K..B..H..B..H..B,
    },
}

-------------------------------------------------------------------------------
-- CRASH PRIORITY  (hold a spot for someone who dropped while actually PLAYING)
-------------------------------------------------------------------------------
Config.CrashPriority = {
    enabled       = true,         -- true = boost players who reconnect after an in-session drop
    windowSeconds = 300,          -- how long after the drop the boost still applies (300 = 5 min)
    bonus         = 5,            -- how much their priority NUMBER improves (lower = sooner);
                                  -- never better than one step behind the best ranked role
}

-------------------------------------------------------------------------------
-- DISCORD  (guild, entry requirements, rejection behaviour)
-------------------------------------------------------------------------------
-- The bot token is Secrets.Discord.botToken (server/config.lua).
-- WARNING: with an empty bot token every role lookup fails, so while
-- whitelistRequired = true EVERY player is rejected with Locale.notWhitelisted.
-- Shipped with the whitelist off: set the bot token, guildId and Config.RolePriority first, then turn it on.
Config.Discord = {
    guildId          = '',        -- your Discord server (guild) id; primary guild when multiguild is on
    multiguild       = false,     -- true = also read roles from every guild in `guilds`
    guilds           = {          -- extra guilds for multiguild: ["name"] = "guild_id"
        ["name"] = "guild_id",
    },
    roleList         = {},        -- optional role name -> role id aliases: ["Admin"] = "1234..."
    cacheRoles       = true,      -- true = cache player roles, false = ask Discord every time
    cacheRolesSeconds = 60,       -- how long cached roles are kept (seconds)

    -- Rejection rules, checked in this order when a player connects.
    requireSteam      = true,     -- reject players without a Steam identifier (Locale.steamRequired)
    requireDiscord    = false,    -- reject players without a Discord identifier (Locale.discordRequired)
    whitelistRequired = false,    -- reject players with no role in Config.RolePriority (Locale.notWhitelisted)
}

-------------------------------------------------------------------------------
-- ROLE PRIORITY  (Discord role id -> queue priority; this list IS the whitelist)
-------------------------------------------------------------------------------
-- LOWER NUMBER = HIGHER PRIORITY. With several roles the best one wins.
--   ['<discord role id>'] = { priority = <number>, message = '<queue text>' },
-- message supports {QUEUE_NUM} and {QUEUE_MAX}.
-- Example: ['123456789012345678'] = { priority = 10, message = "VIP queue [{QUEUE_NUM}/{QUEUE_MAX}]:" },
Config.RolePriority = {
    -- Replace the ids with your own role ids and uncomment.
    -- STAFF
    -- ['STAFF_ROLE_ID']     = { priority = 1,  message = "You are being connected [{QUEUE_NUM}/{QUEUE_MAX}]:" },

    -- SUPPORTERS
    -- ['SUPPORTER_ROLE_ID'] = { priority = 20, message = "Thank you for supporting the server [{QUEUE_NUM}/{QUEUE_MAX}]:" },

    -- MEMBERS
    -- ['MEMBER_ROLE_ID']    = { priority = 60, message = "You are being connected [{QUEUE_NUM}/{QUEUE_MAX}]:" },
}
