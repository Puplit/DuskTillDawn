-- pup-mdt | opening the MDT, player data, start-up and timers

---------------------------------------------------------------------------
-- Player data for the screen
---------------------------------------------------------------------------
function MDT.playerData(a)
    local region = Duty.region(a.src)
    if not region and a.isLaw then
        region = DB.val('SELECT region FROM mdt_lawman_profiles WHERE citizen_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1', { a.cid })
        if region == '' then region = nil end
    end
    local gender = a.gender
    if type(gender) == 'string' then gender = gender:lower() == 'female' and 'female' or (gender:lower() == 'male' and 'male' or nil) end
    local rank = Perms.rankName(a.job, a.grade)
    return {
        name = a.name, firstname = a.firstname, lastname = a.lastname,
        job = a.job, jobLabel = a.jobLabel, grade = a.grade, gradeName = rank, rank = rank, rankLabel = rank,
        serverId = a.src, citizenid = a.cid,
        isBoss = a.grade >= (Config.Profiles.bossGrade or 4),
        gender = gender,
        permissions = Perms.flags(a),
        onDuty = Duty.isOn(a.src),
        dutyRegion = region or 'N/A',
        isLawyer = a.isLawyer,
        footerLabel = a.isLawyer and Config.Legal.footerLabel or nil,
        canEditProfiles = Lawmen.canEdit(a),
        autoRoster = Config.Profiles.autoCreate,
        settings = Settings.snapshot(),
    }
end

function MDT.pushPlayerData(src)
    local a = MDT.player(src)
    if a then MDT.nui(src, { action = 'receivePlayerData', playerData = MDT.playerData(a) }) end
end

MDT.rpc('getPlayerData', { staff = true, deny = { denied = true } }, function(actor)
    return MDT.playerData(actor)
end)

---------------------------------------------------------------------------
-- The open gate
---------------------------------------------------------------------------
local lastOpen = {}

RegisterNetEvent('pup-mdt:server:open', function()
    local src = source
    local now = GetGameTimer()
    if lastOpen[src] and now - lastOpen[src] < 1000 then return end
    lastOpen[src] = now
    local a = MDT.player(src)
    if not a then return end
    if a.isLaw then
        if not Duty.isOn(src) then return MDT.notify(src, L('must_be_on_duty_mdt', Config.Duty.onCommand), 4000) end
        Duty.addOnline(src, 1)
        TriggerClientEvent('pup-mdt:client:open', src, false, MDT.playerData(a), Settings.snapshot())
    elseif a.isLawyer then
        if Config.Legal.requireDuty and not Duty.isOn(src) then
            return MDT.notify(src, L('must_be_on_duty_mdt', Config.Duty.onCommand), 4000)
        end
        TriggerClientEvent('pup-mdt:client:open', src, true, MDT.playerData(a), Settings.snapshot())
    else
        MDT.notify(src, L('no_permission'), 4000)
    end
end)

AddEventHandler('playerDropped', function() lastOpen[source] = nil end)

-- /mycoords: the caller's position, to the server console only. Restricted (ace
-- command.<name>, which admins with the `command` ace have) unless Config.Debug is on
if Config.CoordsCommand then
    RegisterCommand(Config.CoordsCommand, function(src)
        if src <= 0 then return end
        local c = MDT.coords(src)
        if not c then return end
        local ped = GetPlayerPed(src)
        local h = (GetEntityHeading and ped and ped ~= 0) and (GetEntityHeading(ped) or 0.0) or 0.0
        print(('[pup-mdt] %s (%d): vector4(%.2f, %.2f, %.2f, %.2f)'):format(GetPlayerName(src) or '?', src, c.x, c.y, c.z, h))
    end, not Config.Debug)
end

if not Config.UseCommand then
    CreateThread(function()
        while GetResourceState('vorp_inventory') ~= 'started' do Wait(1000) end
        exports.vorp_inventory:registerUsableItem(Config.ItemName, function(data)
            local src = type(data) == 'table' and data.source or nil
            if src then TriggerClientEvent('pup-mdt:client:tryOpen', src) end
        end, GetCurrentResourceName())
    end)
end

---------------------------------------------------------------------------
-- Start-up: schema top-ups, caches, timers
---------------------------------------------------------------------------
local function schema()
    DB.q([[CREATE TABLE IF NOT EXISTS mdt_settings (
        setting_key VARCHAR(64) NOT NULL PRIMARY KEY, setting_value TEXT NULL, updated_by VARCHAR(100) NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    DB.q([[CREATE TABLE IF NOT EXISTS evidence_lockers (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, station VARCHAR(50) NOT NULL UNIQUE, label VARCHAR(100) NULL,
        items LONGTEXT NULL, weapons LONGTEXT NULL, updated INT NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    local adds = {
        'ALTER TABLE mdt_evidence_items ADD COLUMN IF NOT EXISTS image_urls TEXT NULL',
        'ALTER TABLE mdt_evidence_items ADD COLUMN IF NOT EXISTS collected_by VARCHAR(100) NULL',
        'ALTER TABLE mdt_prison_records ADD COLUMN IF NOT EXISTS charidentifier VARCHAR(50) NULL',
        'ALTER TABLE mdt_reports_warrants ADD COLUMN IF NOT EXISTS revoked_by VARCHAR(100) NULL',
        'ALTER TABLE mdt_reports_warrants ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMP NULL',
        'ALTER TABLE mdt_criminals ADD COLUMN IF NOT EXISTS wanted_by_hand TINYINT(1) NOT NULL DEFAULT 0',
    }
    for _, sql in ipairs(adds) do
        local ok, err = pcall(DB.q, sql)
        if not ok then print('^3[pup-mdt]^7 schema: ' .. tostring(err)) end
    end
    Records.hasCreated = (tonumber(DB.val([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'character_created']])) or 0) > 0
end

local function every(ms, fn, name)
    CreateThread(function()
        while true do
            Wait(ms)
            local ok, err = pcall(fn)
            if not ok then print(('^1[pup-mdt]^7 %s: %s'):format(name, tostring(err))) end
        end
    end)
end

CreateThread(function()
    MySQL.ready.await()
    local ok, err = pcall(schema)
    if not ok then print('^1[pup-mdt]^7 database check failed (run sql/install.sql): ' .. tostring(err)) end
    Settings.load()
    for _, job in ipairs(Config.LawJobs) do Ledger.ensure(job) end
    Lockers.init()

    SetTimeout(2000, function() pcall(Admin.cleanBulletins) end)
    SetTimeout(6000, function() pcall(Perms.load) end)
    SetTimeout(10000, function() pcall(Lawmen.backfill) end)
    SetTimeout(15000, function()
        for _, s in ipairs(GetPlayers()) do pcall(Prison.resume, tonumber(s)) end
    end)
    SetTimeout(30000, function() pcall(Admin.auditRetention) end)

    every(5 * 60000, Bounty.sweep, 'bounty sweep')
    every(5 * 60000, Records.syncNames, 'name sync')
    every(5 * 60000, Legal.sweepBail, 'bail sweep')
    every(6 * 3600000, Admin.auditRetention, 'audit retention')

    MDT.log('mdt', 'MDT', 'Logging system initialised.', 'green')
    print('^2[pup-mdt]^7 started.')
end)
