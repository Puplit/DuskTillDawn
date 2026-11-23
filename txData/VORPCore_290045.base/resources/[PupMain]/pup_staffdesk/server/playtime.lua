-- pup_staffdesk | playtime: a minute per loaded character, kept in memory and written in batches
-- characters.hours is a VORP column; this is what fills it. Milestones pay a parcel on crossing a mark.
Playtime = {}

local TICK <const> = 60      -- seconds per credited minute
local FLUSH <const> = 5      -- write every 5 ticks

local unsaved = {}           -- charid -> minutes not yet written
local ticks = 0

local function milestones(charid, before, after)
    local m = Config.Playtime.milestones
    if not m.enabled then return end
    for _, ms in ipairs(m.list) do
        local h = tonumber(ms.hours) or 0
        if h > 0 and before < h and after >= h then
            -- the primary key makes each milestone pay once, even across restarts
            local fresh = MySQL.update.await('INSERT IGNORE INTO staffdesk_milestones (charid, hours, paid_at) VALUES (?, ?, ?)',
                { charid, h, os.time() }) or 0
            if fresh == 1 then
                local note = ms.note or Locale.milestoneNote:format(h)
                if (tonumber(ms.cash) or 0) > 0 then
                    Parcels.send({ charid = charid, kind = 'cash', amount = ms.cash, note = note, by = Locale.milestoneBy, origin = 'milestone' })
                end
                for _, it in ipairs(ms.items or {}) do
                    Parcels.send({ charid = charid, kind = 'item', name = it.name, amount = it.count or 1, note = note, by = Locale.milestoneBy, origin = 'milestone' })
                end
            end
        end
    end
end

local function write(charid, minutes)
    if minutes <= 0 then return end
    local before = tonumber(MySQL.scalar.await('SELECT hours FROM characters WHERE charidentifier = ?', { charid })) or 0
    MySQL.update.await('UPDATE characters SET hours = COALESCE(hours, 0) + ? WHERE charidentifier = ?', { minutes / 60.0, charid })
    milestones(charid, before, before + minutes / 60.0)
end

function Playtime.flush()
    local batch = unsaved
    unsaved = {}
    for charid, mins in pairs(batch) do write(charid, mins) end
end

-- one minute for everyone with a character loaded
function Playtime.tick()
    for _, s in ipairs(GetPlayers()) do
        local charid = Desk.charid(s)
        if charid then unsaved[charid] = (unsaved[charid] or 0) + TICK / 60 end
    end
    ticks = ticks + 1
    if ticks >= FLUSH then ticks = 0 Playtime.flush() end
end

-- hours for a character, including the minutes not written yet
function Playtime.of(charid)
    charid = tonumber(charid)
    local h = tonumber(MySQL.scalar.await('SELECT hours FROM characters WHERE charidentifier = ?', { charid })) or 0
    return h + (unsaved[charid] or 0) / 60
end

-- this character, the whole account, and the next milestone
function Playtime.summary(src)
    local ch = Desk.char(src)
    if not ch then return nil end
    local charid = tonumber(ch.charIdentifier)
    local mine, total, count = 0, 0, 0
    for _, r in ipairs(MySQL.query.await('SELECT charidentifier, hours FROM characters WHERE identifier = ?', { ch.identifier }) or {}) do
        local id = tonumber(r.charidentifier)
        local h = (tonumber(r.hours) or 0) + (unsaved[id] or 0) / 60
        total, count = total + h, count + 1
        if id == charid then mine = h end
    end
    local nextMs
    if Config.Playtime.milestones.enabled then
        for _, ms in ipairs(Config.Playtime.milestones.list) do
            if mine < ms.hours and (not nextMs or ms.hours < nextMs.hours) then nextMs = ms end
        end
    end
    return { mine = mine, total = total, count = count, nextMs = nextMs }
end

CreateThread(function()
    while true do
        Wait(TICK * 1000)
        Playtime.tick()
    end
end)

-- leaving or a restart must not lose the minutes since the last write
AddEventHandler('playerDropped', function()
    local charid = Desk.charid(source)
    if charid and unsaved[charid] then
        local mins = unsaved[charid]
        unsaved[charid] = nil
        write(charid, mins)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Playtime.flush() end
end)
