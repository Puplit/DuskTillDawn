-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Secrets = {
    Discord = {
        -- Discord bot token (Developer Portal > Bot > Token). The bot must be in Config.Discord.guildId.
        -- LEFT EMPTY = every role lookup fails, so with Config.Discord.whitelistRequired = true
        -- the queue rejects EVERYONE as not whitelisted.
        botToken = "",
    },
    Webhooks = {
        queue = "",   -- Discord webhook for queue join/leave logs ("" = no logging)
    },
}
