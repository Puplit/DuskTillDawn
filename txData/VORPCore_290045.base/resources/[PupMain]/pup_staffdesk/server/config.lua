-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Secrets = {
    Webhooks = {
        log = '', -- Discord webhook URL for the desk's log (parcels, renames, bounty, bridge actions)
    },
    Discord = {
        botToken  = "", -- https://discord.com/developers/applications -> your app -> Bot -> Token
        channelId = "", -- the channel the bot reads commands from and answers in
        guildId   = "", -- your Discord server id (needed for role checks)
        users     = {}, -- Discord user ids allowed to run commands, e.g. { '123456789012345678' }
        roles     = {}, -- Discord role ids allowed to run commands. users and roles both empty = the bridge stays off
        banUsers  = {}, -- who may !ban and !unban. banUsers and banRoles both empty = everyone allowed above
        banRoles  = {}, -- role ids that may !ban and !unban
    },
}
