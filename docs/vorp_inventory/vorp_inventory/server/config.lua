-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- Fills in CONFIG.LOGS from config/config_server.lua (loaded just before), so it only sets keys, never replaces the table.

CONFIG                            = CONFIG or {}
CONFIG.LOGS                       = CONFIG.LOGS or {}
CONFIG.LOGS.NetDupWebHook         = CONFIG.LOGS.NetDupWebHook or {}

-- every log below falls back to `webhook` when its own url is empty
CONFIG.LOGS.ItemUseWebhook        = "" -- item consumed / used
CONFIG.LOGS.CraftWebhook          = "" -- crafting (hand + location)
CONFIG.LOGS.ApiGiveWebhook        = "" -- items handed out BY A SCRIPT (admin give, shops, jobs)
CONFIG.LOGS.WeaponApiWebhook      = "" -- weapons handed out or deleted by a script
CONFIG.LOGS.PlayerGiveWebhook     = "" -- a player handed an item to another player
CONFIG.LOGS.DestroyWebhook        = "" -- a player destroyed or dropped an item
CONFIG.LOGS.webhook               = "" -- main inventory logs (the noisy catch-all)

-- custom inventory logs
CONFIG.LOGS.CustomInventoryTakeFrom = "" -- taken out of a custom inventory
CONFIG.LOGS.CustomInventoryMoveTo   = "" -- moved into a custom inventory

-- someone tries to use dev tools to cheat (invalid NUI callback)
CONFIG.LOGS.NetDupWebHook.webhook = ""
