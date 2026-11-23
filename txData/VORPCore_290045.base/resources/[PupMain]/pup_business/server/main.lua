-- pup_business | start-up order and console commands

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    Wait(250)
    EnsureSchema()
    LoadBusinesses()
    ReconcileRanks()
    BizLoaded = true
    PushBusinesses(-1)
    BootStashes()
    local n = 0
    for _ in pairs(Biz) do n = n + 1 end
    print(('^2[%s]^7 %d business(es) loaded'):format(RES, n))
end)

-- /societywebhook job : console or the VORP admin group
RegisterCommand('societywebhook', function(src, args)
    if src > 0 and GroupOf(src) ~= 'admin' then return end
    local job = PB.jobCode(args[1] or '')
    local b = Biz[job]
    local url = LedgerInfo[job] and LedgerInfo[job].webhook or ''
    local target = b and BusinessWebhook(job) or nil
    print(('[%s] webhook check for "%s"'):format(RES, job))
    print(('  logs enabled ........ %s'):format(tostring(Config.BusinessLogs)))
    print(('  business exists ..... %s'):format(tostring(b ~= nil)))
    print(('  webhook flag ........ %s'):format(tostring(b and b.webhook or false)))
    print(('  stash container ..... %s'):format(tostring(b and b.containerid or '-')))
    print(('  saved URL ........... %s'):format(url ~= '' and 'yes' or 'no'))
    print(('  log would be sent ... %s'):format(tostring(target ~= nil)))
    if src > 0 then Notify(src, L('webhook_check_console')) end
    if target then
        SendLog(job, 'Webhook test', COLOUR.blue, table.pack(
            F('Business', job, true), F('Stash container', b.containerid, true)),
            'If you can read this, society logging works.')
    end
end, false)
