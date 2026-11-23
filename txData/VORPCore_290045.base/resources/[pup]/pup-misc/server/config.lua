-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Secrets = {
    Webhooks = {
        storagebox = {
            main          = "", -- box log: deposits, withdrawals, shop trades, deletions
            societyAdmin  = "", -- staff actions on society boxes
            housingAdmin  = "", -- staff actions on house boxes
            clanAdmin     = "", -- staff actions on clan boxes
            hideoutAdmin  = "", -- staff actions on hideout boxes
            customAdmin   = "", -- staff actions on custom boxes
        },
        search = {
            admin = "", -- staff log for searches and steals
        },
        scene = {
            log = "", -- scene log: who placed which /scene text
        },
    },
}

-- search: one identifier (steam:..., license:..., discord:...) or a list of them that ignores every search restriction; '' = nobody
SearchServerConfig = SearchServerConfig or {}
SearchServerConfig.SuperBypass = ""
