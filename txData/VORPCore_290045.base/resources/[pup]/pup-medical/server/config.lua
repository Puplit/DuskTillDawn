-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- Read through Hook(...) in server/core.lua.

Hooks = {
    -- job alerts: the type's own channel beats alertDefault; a job entry beats both
    alertDefault = "",
    alerts = {
        Medical = {
            default = "",
            jobs = {
                doctor     = "",
                pharmacist = "",
            },
        },
    },

    -- completed paid calls: the responder's job channel first, then callPay
    callPay = "",
    callPayByJob = {
        doctor     = "",
        pharmacist = "",
    },

    -- respawn losses
    death = "",

    -- every /duty toggle, plus a per-job channel for doctor jobs
    duty = "",
    dutyByJob = {
        doctor     = "",
        pharmacist = "",
        drbarber   = "",
    },

    -- every revive, plus a per-job channel ("illegal" = back-alley syringe)
    reviveAdmin = "",
    reviveByJob = {
        doctor     = "",
        pharmacist = "",
        drbarber   = "",
        illegal    = "",
    },
}
