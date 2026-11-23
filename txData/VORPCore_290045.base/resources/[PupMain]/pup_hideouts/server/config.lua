-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

-- one webhook per log category
Secrets = {
    Webhooks = {
        Main       = '',
        Raids      = '',
        Missions   = '',
        Ledger     = '',
        Inventory  = '',
        Production = '',
        Sales      = '',
    },
}
