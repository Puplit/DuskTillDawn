-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Secrets = {
    -- every business log is mirrored here when Config.AdminMirror is on
    AdminWebhook = '',

    -- fallback webhook per job code, used when the boss has not saved one
    JobWebhooks = {
        doctor = '',
        drbarber = '',
        police = '',
        marshal = '',
        sbundertaker = '',
        rdblacksmith = '',
        rdgunsmith = '',
    },
}
