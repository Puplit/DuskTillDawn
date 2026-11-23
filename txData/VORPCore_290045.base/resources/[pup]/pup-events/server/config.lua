-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- Embed styling is Config.Logs in config/main.lua.

Secrets = {
    Webhooks = {
        easterGoldPickup = '', -- Discord webhook, Spring Hunt: someone found a golden egg
        easterGoldOpen   = '', -- Discord webhook, Spring Hunt: someone opened one, and what they got
        trickOrTreat     = '', -- Discord webhook, Trick or Treat: one channel for everything
    },
}
