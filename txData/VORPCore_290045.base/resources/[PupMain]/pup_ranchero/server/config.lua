-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Secrets = {
    ledger  = '', -- Discord webhook for ledger movements, purchases, sale income, tax and repossessions
    general = '', -- Discord webhook for everything else (purchases, staff, herding, chores, produce, kills)
}
