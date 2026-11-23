-- Modified by Puppet (Dusk Till Dawn), 2026
-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- Fills in the Logs table from config/logs.lua (loaded earlier), so it only sets keys, never replaces Logs.

Logs = Logs or {}

Logs.Whitelist        = "" -- whitelist log (only if you use whitelist in vorp core)
Logs.JoinWebhookURL   = "" -- "Player Connecting" log
Logs.LeaveWebhookURL  = "" -- "Player Leave" log
Logs.JoinedWebhookURL = "" -- "Player Joined" log; blank = uses JoinWebhookURL
Logs.DeathWebhookURL  = "" -- player death log
Logs.CurrencyLog      = "" -- every addCurrency / removeCurrency, with the resource that asked for it
