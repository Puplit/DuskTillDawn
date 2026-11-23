-- pup-medical | behaviour switches (explained in README.md)

local defaults = {
    -- a responder who is already busy on a call may not take a second one
    busyBlocksAccept    = false,
    -- respawn losses count every job of the "Medical" alert type as a medic (false: only doctor and pharmacist)
    medicsFromAlertType = false,
    -- a respawn (not just a doctor's revive) starts the weakness period
    recoveryOnRespawn   = true,
    -- ace permission needed for /dutycheck; "" = any player may run it
    dutycheckAce        = '',
    -- one duty log per toggle: the per-job channel when it is set, else the general one
    mergeDutyLogs       = false,
}

Config.Switches = Config.Switches or {}
for k, v in pairs(defaults) do
    if Config.Switches[k] == nil then Config.Switches[k] = v end
end
