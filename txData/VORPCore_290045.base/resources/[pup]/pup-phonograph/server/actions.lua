-- Every request a client can make. The server decides; client values are only hints.

PH = PH or {}

local SPAM_MS <const> = 250

-- placement tickets: a save is only taken after the server started that placement
-- [src] = { player = { charId, at }, staff = { charId, at } }
local tickets = {}
-- per-player placement save lock
local saving = {}

-- rules ---------------------------------------------------------------------

local function passesJob(src, p, char)
    if PH.IsStaff(src) then return true end
    if not p then return false end
    if p.job == '' then return true end
    local job = char and char.job
    if type(job) ~= 'string' or job:lower() ~= p.job:lower() then return false end
    return (tonumber(char.jobGrade) or 0) >= p.rank
end

-- nil on success, or the message to show
local function controlError(src, p, char)
    if not passesJob(src, p, char) then return Lang.noJob end
    if PH.IsStaff(src) then return nil end
    if Config.OwnerOnlyControl and p.ownerCharId > 0
        and tonumber(char.charIdentifier) ~= p.ownerCharId then
        return Lang.noPermission
    end
    if PH.DistTo(src, p) > Config.Ranges.control then return Lang.tooFar end
    return nil
end

-- the common front of every phonograph request: throttle, character, phonograph, control
local function controlled(src, rawId, key)
    if not PH.Throttle(src, key, SPAM_MS) then return nil end
    local char = PH.GetChar(src)
    if not char then return nil end
    local id = PH.ReadId(rawId)
    local p = id and PH.Phonos[id]
    if not p then return nil end
    local err = controlError(src, p, char)
    if err then
        PH.Tip(src, err, 3000)
        return nil
    end
    return id, p, char
end

PH.PassesJob = passesJob

-- lists and status ----------------------------------------------------------

RegisterNetEvent('pup-phonograph:server:requestList', function()
    local src = source
    if not PH.Throttle(src, 'list', 2000) then return end
    TriggerClientEvent('pup-phonograph:client:list', src, PH.PublicList())
end)

RegisterNetEvent('pup-phonograph:server:requestStaff', function()
    local src = source
    if not PH.Throttle(src, 'staff', 1000) then return end
    TriggerClientEvent('pup-phonograph:client:staff', src, PH.IsStaff(src))
end)

RegisterNetEvent('pup-phonograph:server:resync', function()
    local src = source
    if not PH.Throttle(src, 'resync', 2000) then return end
    PH.ResyncPlayer(src)
end)

-- placement -----------------------------------------------------------------

-- one ticket per mode, so a staff member who runs /addphono while a player
-- placement is still open does not void the placement already on screen
function PH.IssueTicket(src, mode, charId)
    local t = tickets[src]
    if not t then t = {}; tickets[src] = t end
    t[mode] = { charId = charId, at = os.time() }
    TriggerClientEvent('pup-phonograph:client:startPlacement', src, mode)
end

local function takeTicket(src, mode, charId)
    local all = tickets[src]
    local t = all and all[mode]
    if not t or t.charId ~= charId then return false end
    all[mode] = nil
    return os.time() - t.at <= Config.Timing.placementTicketSec
end

local function waitReady()
    local deadline = GetGameTimer() + Config.Timing.readyWaitMs
    while not PH.Ready and GetGameTimer() < deadline do Wait(100) end
    return PH.Ready
end

function PH.OnItemUsed(data)
    local src = type(data) == 'table' and tonumber(data.source) or nil
    if not src then return end
    if not PH.Throttle(src, 'use', 1000) then return end
    if not waitReady() then
        PH.Tip(src, Lang.notReady, 3000)
        return
    end
    local char = PH.GetChar(src)
    if not char then return end
    local charId = tonumber(char.charIdentifier)
    if PH.AtLimit(charId) then
        PH.Tip(src, Lang.limitReached, 4000)
        return
    end
    PH.CloseInventory(src)
    PH.IssueTicket(src, 'player', charId)
end

RegisterNetEvent('pup-phonograph:server:savePlayer', function(rawPos, rawRot)
    local src = source
    if not PH.Throttle(src, 'save', SPAM_MS) then return end
    local char = PH.GetChar(src)
    if not char then return end
    local charId = tonumber(char.charIdentifier)
    local pos, rot = PH.ReadVec(rawPos), PH.ReadVec(rawRot)
    if not pos or not rot then return end
    if not takeTicket(src, 'player', charId) then return end
    if PH.DistTo(src, pos) > Config.Ranges.place then
        PH.Tip(src, Lang.tooFar, 4000)
        return
    end
    if saving[src] and GetGameTimer() - saving[src] < Config.Timing.saveLockMs then return end
    if PH.AtLimit(charId) then
        PH.Tip(src, Lang.limitReached, 4000)
        return
    end
    if PH.ItemCount(src, Config.Item) < 1 then
        PH.Tip(src, Lang.noItem, 4000)
        return
    end

    saving[src] = GetGameTimer()
    local p = PH.Insert(char.identifier, charId, pos, rot, '', 0)
    saving[src] = nil
    if not p then return end

    -- the player may have left, switched character or dropped the item during the insert
    local now = PH.GetChar(src)
    local ok = now and tonumber(now.charIdentifier) == charId and PH.TakeItem(src, Config.Item, 1)
    if not ok then
        PH.Phonos[p.id] = nil
        PH.DeleteRow(p.id)
        if now then PH.Tip(src, Lang.noItem, 4000) end
        return
    end

    TriggerClientEvent('pup-phonograph:client:upsert', -1, PH.PublicView(p))
    PH.Tip(src, Lang.playerPlaced, 4000)
end)

RegisterCommand('addphono', function(src)
    if src == 0 then return end
    local char = PH.GetChar(src)
    if not char then return end
    if not PH.IsStaff(src) then
        PH.Tip(src, Lang.noPermission, 3000)
        return
    end
    PH.IssueTicket(src, 'staff', tonumber(char.charIdentifier))
end, false)

RegisterNetEvent('pup-phonograph:server:saveStaff', function(rawPos, rawRot, rawJob, rawRank)
    local src = source
    if not PH.Throttle(src, 'save', SPAM_MS) then return end
    local char = PH.GetChar(src)
    if not char then return end
    if not PH.IsStaff(src) then
        PH.Tip(src, Lang.noPermission, 3000)
        return
    end
    local charId = tonumber(char.charIdentifier)
    local pos, rot = PH.ReadVec(rawPos), PH.ReadVec(rawRot)
    if not pos or not rot then return end

    local job = type(rawJob) == 'string' and rawJob:match('^%s*(.-)%s*$') or ''
    local rank = tonumber(rawRank) or 0
    if #job > Config.StaffJobMaxLength or job:find('[%c]')
        or not PH.IsFinite(rank) or rank < 0 or rank > Config.StaffRankMax then
        PH.Tip(src, Lang.badSetup, 4000)
        return
    end
    rank = math.floor(rank)

    if not takeTicket(src, 'staff', charId) then return end
    if PH.DistTo(src, pos) > Config.Ranges.place then
        PH.Tip(src, Lang.tooFar, 4000)
        return
    end
    if saving[src] and GetGameTimer() - saving[src] < Config.Timing.saveLockMs then return end

    saving[src] = GetGameTimer()
    local p = PH.Insert('admin', 0, pos, rot, job, rank)
    saving[src] = nil
    if not p then return end

    TriggerClientEvent('pup-phonograph:client:upsert', -1, PH.PublicView(p))
    PH.Tip(src, Lang.staffPlaced, 4000)
end)

-- menu ----------------------------------------------------------------------

local function recordDef(item)
    for _, r in ipairs(Config.Records) do
        if r.item == item then return r end
    end
    return nil
end

RegisterNetEvent('pup-phonograph:server:openMenu', function(rawId)
    local src = source
    local id, p = controlled(src, rawId, 'menu')
    if not id then return end
    local play = PH.Playing[id]
    local records = {}
    for _, r in ipairs(Config.Records) do
        records[#records + 1] = { item = r.item, label = r.label or r.item }
    end
    local current = p.record and recordDef(p.record)
    TriggerClientEvent('pup-phonograph:client:menu', src, {
        id = id,
        isStaff = PH.IsStaff(src),
        radius = p.radius,
        volume = play and play.volume or p.volume,
        playing = play ~= nil,
        loop = play ~= nil and play.loop or false,
        records = records,
        record = p.record,
        recordLabel = current and (current.label or current.item) or p.record,
    })
end)

-- playing -------------------------------------------------------------------

local function logPlay(char, url)
    local line = Lang.logLine:format(tostring(char.firstname), tostring(char.lastname),
        tostring(char.charIdentifier), url)
    print(('[%s] %s'):format(PH.Res, line))
    if Config.DiscordLog and PH.Secrets.webhook then
        local ok, err = pcall(PH.Core.AddWebhook, Lang.logTitle, PH.Secrets.webhook, line)
        if not ok then PH.WarnOnce('webhook', 'Discord log failed: ' .. tostring(err)) end
    end
end

RegisterNetEvent('pup-phonograph:server:play', function(rawId, url, volume, loop, radius)
    local src = source
    if not PH.Throttle(src, 'playSpam', SPAM_MS) then return end
    if PH.Cooling(src, 'play', Config.Timing.playCooldownMs) then return end
    local char = PH.GetChar(src)
    if not char then return end
    local id = PH.ReadId(rawId)
    local p = id and PH.Phonos[id]
    if not p then return end
    if not passesJob(src, p, char) then
        PH.Tip(src, Lang.noJob, 3000)
        return
    end

    local staff = PH.IsStaff(src)
    if staff then
        if not PH.IsWebLink(url) then
            PH.Tip(src, Lang.badLink, 3000)
            return
        end
        if not Config.StaffSkipSiteCheck and not PH.SiteApproved(url) then
            PH.Tip(src, Lang.siteNotApproved, 3000)
            return
        end
    else
        if not Config.PlayersMayPlay then
            PH.Tip(src, Lang.noPermission, 3000)
            return
        end
        if not PH.SiteApproved(url) then
            PH.Tip(src, Lang.siteNotApproved, 3000)
            return
        end
        local err = controlError(src, p, char)
        if err then
            PH.Tip(src, err, 3000)
            return
        end
    end

    PH.Stamp(src, 'play')
    logPlay(char, url)
    PH.StartPlay(id, url, PH.CleanVolume(volume), loop == true, PH.CleanRadius(radius), src)
end)

RegisterNetEvent('pup-phonograph:server:stop', function(rawId)
    local src = source
    local id = controlled(src, rawId, 'stop')
    if not id then return end
    PH.StopPlay(id)
end)

RegisterNetEvent('pup-phonograph:server:volume', function(rawId, volume)
    local src = source
    local id, p = controlled(src, rawId, 'volume')
    if not id then return end
    local v = PH.CleanVolume(volume)
    p.volume = v
    local play = PH.Playing[id]
    if play then
        play.volume = v
        PH.SendToListeners(id, 'pup-phonograph:client:volume', id, v)
    end
end)

RegisterNetEvent('pup-phonograph:server:radius', function(rawId, radius)
    local src = source
    local id, p = controlled(src, rawId, 'radius')
    if not id then return end
    local r = PH.CleanRadius(radius)
    p.radius = r
    local play = PH.Playing[id]
    if play then
        play.radius = r
        PH.SendToListeners(id, 'pup-phonograph:client:radius', id, r)
    end
    TriggerClientEvent('pup-phonograph:client:upsert', -1, PH.PublicView(p))
end)

RegisterNetEvent('pup-phonograph:server:toggleLoop', function(rawId)
    local src = source
    local id = controlled(src, rawId, 'loop')
    if not id then return end
    local play = PH.Playing[id]
    if not play then return end
    play.loop = not play.loop
    play.startedAt = os.time()
    play.loopResetAt = play.startedAt
    play.endedBy = {}
    PH.SendToListeners(id, 'pup-phonograph:client:loop', id, play.loop)
    PH.Tip(src, play.loop and Lang.loopOn or Lang.loopOff, 3000)
end)

RegisterNetEvent('pup-phonograph:server:stopAll', function()
    local src = source
    if not PH.Throttle(src, 'stopAll', 1000) then return end
    if not PH.GetChar(src) then return end
    if not PH.IsStaff(src) then
        PH.Tip(src, Lang.noPermission, 3000)
        return
    end
    PH.StopAllPlays()
    PH.Tip(src, Lang.globalStop, 3000)
end)

-- reports from clients (checked against the play serial and the listener list)
RegisterNetEvent('pup-phonograph:server:ended', function(rawId, serial)
    local src = source
    if not PH.Throttle(src, 'ended', SPAM_MS) then return end
    local id = PH.ReadId(rawId)
    if not id or type(serial) ~= 'number' then return end
    PH.ReportEnded(src, id, serial)
end)

RegisterNetEvent('pup-phonograph:server:looped', function(rawId, serial)
    local src = source
    if not PH.Throttle(src, 'looped', SPAM_MS) then return end
    local id = PH.ReadId(rawId)
    if not id or type(serial) ~= 'number' then return end
    PH.ReportLooped(src, id, serial)
end)

-- picking up ----------------------------------------------------------------

local picking = {}

RegisterNetEvent('pup-phonograph:server:pickup', function(rawId)
    local src = source
    if not PH.Throttle(src, 'pickup', 1000) then return end
    local char = PH.GetChar(src)
    if not char then return end
    local charId = tonumber(char.charIdentifier)
    local id = PH.ReadId(rawId)
    if not id or picking[id] then return end

    picking[id] = true
    local row = PH.ReadRow(id)
    picking[id] = nil
    if not row then return end

    -- re-check the player after the database wait
    local now = PH.GetChar(src)
    if not now or tonumber(now.charIdentifier) ~= charId then return end

    local staff = PH.IsStaff(src)
    if row.ownerCharId ~= charId and not staff then
        PH.Tip(src, Lang.noPermission, 3000)
        return
    end
    if PH.DistTo(src, row) > Config.Ranges.pickup then
        PH.Tip(src, Lang.tooFarCollect, 4000)
        return
    end
    local playerOwned = row.ownerCharId > 0
    if playerOwned and not PH.CanCarry(src, Config.Item, 1) then
        PH.Tip(src, Lang.cannotCarry, 4000)
        return
    end

    TriggerClientEvent('pup-phonograph:client:remove', -1, id)
    PH.StopPlay(id)
    local record = PH.Phonos[id] and PH.Phonos[id].record
    PH.Phonos[id] = nil

    if not PH.DeleteRow(id) then return end
    if not GetPlayerName(src) then return end
    if playerOwned then PH.GiveItem(src, Config.Item, 1) end
    -- a record left on the turntable goes back with it
    if record and recordDef(record) and PH.CanCarry(src, record, 1) then
        PH.GiveItem(src, record, 1)
    end
    PH.Tip(src, Lang.pickedUp, 4000)
end)

-- records (inactive while Config.Records is empty) --------------------------

RegisterNetEvent('pup-phonograph:server:insertRecord', function(rawId, item)
    local src = source
    if #Config.Records == 0 then return end
    local id, p, char = controlled(src, rawId, 'record')
    if not id then return end
    local def = type(item) == 'string' and recordDef(item)
    if not def then return end
    if PH.ItemCount(src, def.item) < 1 then
        PH.Tip(src, Lang.noRecord, 3000)
        return
    end
    local old = p.record
    if old and old ~= def.item and not PH.CanCarry(src, old, 1) then
        PH.Tip(src, Lang.cannotCarryRecord, 3000)
        return
    end
    local charId = tonumber(char.charIdentifier)
    if not PH.TakeItem(src, def.item, 1) then
        PH.Tip(src, Lang.noRecord, 3000)
        return
    end
    if old then PH.GiveItem(src, old, 1) end
    p.record = def.item
    PH.SetRecord(id, def.item)
    -- the phonograph may have been picked up during the write
    if not PH.Phonos[id] then
        local still = PH.GetChar(src)
        if still and tonumber(still.charIdentifier) == charId then PH.GiveItem(src, def.item, 1) end
        return
    end
    TriggerClientEvent('pup-phonograph:client:upsert', -1, PH.PublicView(p))
end)

RegisterNetEvent('pup-phonograph:server:playRecord', function(rawId)
    local src = source
    if #Config.Records == 0 then return end
    if PH.Cooling(src, 'play', Config.Timing.playCooldownMs) then return end
    local id, p, char = controlled(src, rawId, 'record')
    if not id then return end
    local def = p.record and recordDef(p.record)
    if not def or not PH.IsWebLink(def.url) then return end
    PH.Stamp(src, 'play')
    logPlay(char, def.url)
    PH.StartPlay(id, def.url, PH.CleanVolume(Config.RecordVolume), false, p.radius, src)
end)

RegisterNetEvent('pup-phonograph:server:removeRecord', function(rawId)
    local src = source
    if #Config.Records == 0 then return end
    local id, p = controlled(src, rawId, 'record')
    if not id then return end
    local item = p.record
    if not item then return end
    if not PH.CanCarry(src, item, 1) then
        PH.Tip(src, Lang.cannotCarryRecord, 3000)
        return
    end
    p.record = nil
    PH.StopPlay(id)
    if not PH.SetRecord(id, nil) then return end
    if not GetPlayerName(src) then return end
    PH.GiveItem(src, item, 1)
    if PH.Phonos[id] then
        TriggerClientEvent('pup-phonograph:client:upsert', -1, PH.PublicView(p))
    end
end)

-- cleanup -------------------------------------------------------------------

function PH.ForgetPlacement(src)
    tickets[src] = nil
    saving[src] = nil
end
