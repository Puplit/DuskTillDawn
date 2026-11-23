-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- An empty URL still logs to file and the /pupdebug console output.

Secrets = {
    Webhooks = {
        drops = '', -- Discord webhook: player drops before the world, instanced players
        load  = '', -- Discord webhook: server stalls, restart storms (can be the same URL)
    },
}
