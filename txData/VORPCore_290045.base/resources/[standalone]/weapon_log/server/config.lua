-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Config.webhook = "" -- shared / fallback log

Config.webhooks = {
    pvp       = "", -- player killed by another player
    suicide   = "", -- killed themselves
    natural   = "", -- died with no killer (fall, animal, drowning, NPC)
    combatlog = "", -- disconnected while downed
}
