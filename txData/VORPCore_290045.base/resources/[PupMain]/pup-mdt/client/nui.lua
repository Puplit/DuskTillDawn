-- pup-mdt client | NUI callbacks: each one relays to the server over the RPC channel and answers the page

MdtC = MdtC or {}

-- callbacks whose data goes back to the page as a message instead of the reply
local PUSHED = {
    lookupCitizen = 'citizenLookupResult',
    getMyProfile = 'receiveMyProfile',
    saveLawmanProfile = 'lawmanProfileSaveResult',
    deleteLawmanProfile = 'deleteLawmanProfileResult',
    getDutyStats = 'receiveDutyStats',
    getDutyStatus = 'receiveDutyStatus',
    getCriminalDetails = 'receiveCriminalDetails',
    saveCriminal = 'criminalSaveResult',
    updateCriminal = 'criminalSaveResult',
    deleteCriminal = 'criminalDeleteResult',
    updateCriminalInfo = 'criminalInfoUpdateResult',
    updateCriminalPhoto = 'criminalPhotoUpdateResult',
    validatePlayerIdentity = 'playerValidationResult',
    getCriminalHistory = 'receiveCriminalHistory',
    releasePrisoner = 'prisonActionResult',
    extendSentence = 'prisonActionResult',
    transferPrisoner = 'prisonActionResult',
    massRelease = 'prisonActionResult',
    sendPrisonerToCell = 'prisonActionResult',
    civSearchPerson = 'civPersonResults',
    civViewPerson = 'civPersonDetail',
    civGetPrisonRecords = 'civPrisonRecords',
    civGetBountyBoard = 'civBountyBoard',
    civGetPenalCode = 'civPenalCode',
    bhTip = 'bountyTipResult',
}

-- messages whose answer sits under `result`: a refusal ({ success=false, message }) is moved
-- there so the page shows the server's reason (off duty, no permission) instead of a blank failure
local RESULT_KEYED = {
    lawmanProfileSaveResult = true, deleteLawmanProfileResult = true, criminalSaveResult = true,
    criminalDeleteResult = true, criminalInfoUpdateResult = true, criminalPhotoUpdateResult = true,
    playerValidationResult = true, prisonActionResult = true,
}

-- callbacks answered with the value itself
local VALUE = {
    'getCitizenProfile', 'terminateLawman', 'getDashboardData', 'getLawmen',
    'getPermissionsLawmen', 'saveLawmanPermissions', 'resetLawmanPermissions', 'getAuditLog',
    'getCriminals', 'getPenalCodes', 'savePenalCode', 'deletePenalCode', 'processArrest', 'getFines',
    'getReports', 'saveReport', 'updateReport', 'deleteReport', 'getReportLinkables',
    'getCases', 'saveCase', 'deleteCase', 'getCasesList', 'getEvidenceItems',
    'getEvidence', 'saveEvidence', 'deleteEvidence',
    'getBolos', 'createBolo', 'resolveBolo', 'deleteBolo', 'lookupBoloCitizen',
    'getWarrants', 'createWarrant', 'updateWarrant', 'deleteWarrant',
    'getMostWanted', 'lookupMostWantedCitizen', 'addMostWanted', 'resolveMostWanted',
    'getPrisons',
    'getBail', 'lookupBailPrisoner', 'requestBail', 'approveBail', 'denyBail', 'resolveBail',
    'getAppeals', 'lookupAppealPrisoner', 'requestAppeal', 'approveAppeal', 'denyAppeal',
    'getExpungements', 'getExpungementSnapshot', 'getExpungementPreview', 'lookupExpungementCitizen', 'requestExpungement', 'approveExpungement', 'denyExpungement',
    'getDefenseCases', 'lookupDefenseCase', 'lookupDefenseLawyer', 'getDefenseCaseDetail', 'assignDefense', 'unassignDefense', 'fileDefenseStatement',
    'getBarRoster', 'getLawyerProfile', 'getFirmHome', 'getFirmSettings', 'saveFirmMotd', 'respondCounsel', 'cancelCounsel', 'fireLawyer',
    'getLedger', 'ledgerDeposit', 'ledgerWithdraw',
    'getBulletins', 'createBulletin', 'deleteBulletin', 'getMdtSettings', 'saveMdtSettings',
    'getTips', 'markTipRead', 'deleteTip',
    'respondToExistingAlert', 'getAlertResponseCounts',
}

-- the timeouts the page expects
local TIMEOUT = {
    processArrest = 15000,
    getPermissionsLawmen = 10000, getAuditLog = 10000,
    saveLawmanPermissions = 10000, resetLawmanPermissions = 10000,
    getDashboardData = 5000, deleteBulletin = 5000,
}
local FALLBACK = {
    getDashboardData = false,
    processArrest = function() return { success = false, message = L('cl_timeout') } end,
}

local function clean(data)
    if type(data) ~= 'table' then return {}, nil end
    local rid = data._rid
    data._rid = nil
    return data, rid
end

local function fallbackFor(name)
    local f = FALLBACK[name]
    if type(f) == 'function' then return f() end
    if f ~= nil then return f end
    return { success = false, message = L('cl_timeout'), timeout = true }
end

for _, name in ipairs(VALUE) do
    RegisterNUICallback(name, function(data, cb)
        local payload = clean(data)
        MdtC.rpc(name, payload, TIMEOUT[name] or 8000, fallbackFor(name), function(result)
            if result == nil then result = {} end
            cb(result)
        end)
    end)
end

for name, msgName in pairs(PUSHED) do
    RegisterNUICallback(name, function(data, cb)
        local payload, rid = clean(data)
        cb('ok')
        MdtC.rpc(name, payload, TIMEOUT[name] or 8000, { success = false, message = L('cl_timeout') }, function(result)
            local msg = {}
            if type(result) == 'table' then for k, v in pairs(result) do msg[k] = v end end
            if RESULT_KEYED[msgName] and msg.result == nil then
                msg.result = { success = false, message = msg.message or L('cl_timeout') }
            end
            if name == 'lookupCitizen' then msg.type = msgName else msg.action = msgName end
            msg._rid = rid
            MdtC.send(msg)
        end)
    end)
end

-- player data, or the online player list for the arrest form
RegisterNUICallback('getPlayerData', function(data, cb)
    local payload, rid = clean(data)
    if payload.type == 'onlinePlayers' then
        MdtC.rpc('getOnlinePlayers', nil, 5000, {}, function(result) cb(result or {}) end)
        return
    end
    cb('ok')
    MdtC.rpc('getPlayerData', nil, 8000, nil, function(result)
        if type(result) == 'table' and result.success ~= false and not result.denied then
            MdtC.send({ action = 'receivePlayerData', playerData = result, _rid = rid })
        end
    end)
end)

-- tips answer the page with the server's result so it can show success only on success
RegisterNUICallback('submitTip', function(data, cb)
    local payload = clean(data)
    local where = MdtC.zoneName(MdtC.myCoords())
    payload.location = where
    MdtC.rpc('submitTip', payload, 8000, { success = false, message = L('cl_timeout') }, function(result) cb(result or {}) end)
end)

RegisterNUICallback('bhClaim', function(data, cb)
    local payload = clean(data)
    cb('ok')
    MdtC.rpc('bhClaim', { id = payload.id }, 15000, nil, function(result)
        if type(result) == 'table' and result.success then
            MdtC.send({ action = 'bountyClaimed', id = payload.id })
        end
    end)
end)

RegisterNUICallback('barSetDuty', function(data, cb)
    local payload = clean(data)
    MdtC.rpc('barSetDuty', { onDuty = payload.onDuty == true }, 8000, { ok = false }, function(result) cb(result or {}) end)
end)

---------------------------------------------------------------------------
-- callbacks the client answers itself
---------------------------------------------------------------------------
RegisterNUICallback('closeMDT', function(_, cb)
    cb('ok')
    MdtC.closeMdt(false)
end)

RegisterNUICallback('closeFromEsc', function(_, cb)
    cb('ok')
    MdtC.closeMdt(false)
end)

RegisterNUICallback('mdtNotify', function(data, cb)
    cb('ok')
    if type(data) == 'table' and data.message then
        MdtC.notify(tostring(data.message):sub(1, 400), tonumber(data.duration) or 4000)
    end
end)

RegisterNUICallback('getPrisonCells', function(_, cb)
    local out = {}
    for i, c in ipairs((Config.Prison and Config.Prison.cells) or {}) do
        out[#out + 1] = { index = i, label = c.label or ('Cell ' .. i) }
    end
    cb(out)
end)

-- alerts: leave and dismiss also act locally
RegisterNUICallback('leaveAlert', function(data, cb)
    local payload = clean(data)
    if MdtC.leaveAlertLocal then MdtC.leaveAlertLocal(payload.alertId) end
    MdtC.rpc('leaveAlert', { alertId = payload.alertId }, 8000, { success = false }, function(result) cb(result or {}) end)
end)

RegisterNUICallback('removePoliceAlert', function(data, cb)
    local payload = clean(data)
    -- removed here only once the server agrees (a locked alert stays for its holder)
    MdtC.rpc('removePoliceAlert', { alertId = payload.alertId }, 8000, { success = false, message = L('cl_timeout') }, function(result)
        if type(result) == 'table' and result.success then
            if MdtC.removeAlertLocal then MdtC.removeAlertLocal(payload.alertId, true) end
            MdtC.notify(L('alert_removed'), 2000)
        elseif type(result) == 'table' and result.message then
            MdtC.notify(result.message, 3000)
        end
        cb(result or {})
    end)
end)

RegisterNUICallback('toggleAlertLock', function(data, cb)
    local payload = clean(data)
    cb('ok')
    MdtC.rpc('toggleAlertLock', { alertId = payload.alertId }, 8000, nil, function(result)
        if type(result) == 'table' and result.success == false and result.message then MdtC.notify(result.message, 3000) end
    end)
end)

RegisterNUICallback('locateAlert', function(data, cb)
    local payload = clean(data)
    if MdtC.locateAlert and MdtC.locateAlert(payload.alertId, payload.coords) then
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('closeCivilianRecord', function(_, cb)
    cb({})
    if MdtC.closeKiosk then MdtC.closeKiosk(false) end
end)

RegisterNUICallback('bhClose', function(_, cb)
    cb('ok')
    if MdtC.closeBoard then MdtC.closeBoard('bh', false) end
end)

RegisterNUICallback('jrClose', function(_, cb)
    cb('ok')
    if MdtC.closeBoard then MdtC.closeBoard('jr', false) end
end)
