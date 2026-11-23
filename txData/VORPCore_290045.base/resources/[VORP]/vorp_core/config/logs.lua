Logs = {}

Logs.Whitelist = ""                -- only if you use whitelist in vorp core

Logs.EnableWebhookJoinleave = true -- Enable webhooks for player join and leave?

Logs.JoinWebhookURL = ""           -- only if you use join leave in vorp core

Logs.LeaveWebhookURL = ""          -- only if you use join leave in vorp core

-- "Player Joined" - fires once they are actually IN the session, after the whitelist and ban checks
Logs.JoinedWebhookURL = ""

-- put the connecting player's IP in the join log
Logs.JoinLogShowIP = false

Logs.DeathWebhookURL = ""          -- only if you use death webhook in vorp core

-- Every addCurrency / removeCurrency, with the resource that asked for it
Logs.CurrencyLog = ""

-- Ping @everyone when a balance ends up negative, or a negative amount is passed in (both mean something is wrong
Logs.CurrencyPingOnSuspicious = true

-- Webhook URLs: set them in `server/config.lua`.
