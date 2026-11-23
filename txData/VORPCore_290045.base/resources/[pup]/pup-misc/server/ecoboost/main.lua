-- Eco Boost: a per-character sale bonus with a cap and a cooldown
-- exports: EndEcoBoost(src) and the store hooks below

local Core = exports.vorp_core:GetCore()
local Cfg  = EcoBoostConfig

local Active = {}   -- src -> { charid, earned, activatedAt }
local Rows   = {}   -- charid -> { earned, exhausted, completed, activated }

local TABLE_SQL = [[
CREATE TABLE IF NOT EXISTS `ecoboost` (
    `charid` INT NOT NULL,
    `last_activated` INT NOT NULL DEFAULT 0,
    `exhausted` TINYINT(1) NOT NULL DEFAULT 0,
    `earned` DOUBLE NOT NULL DEFAULT 0,
    `completed_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

CreateThread(function()
    exports.oxmysql:execute(TABLE_SQL, {})
    -- older rows lack these two columns
    exports.oxmysql:execute('ALTER TABLE `ecoboost` ADD COLUMN IF NOT EXISTS `earned` DOUBLE NOT NULL DEFAULT 0', {})
    exports.oxmysql:execute('ALTER TABLE `ecoboost` ADD COLUMN IF NOT EXISTS `completed_at` INT NOT NULL DEFAULT 0', {})
end)

-- helpers

local function round2(n)
    return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100
end

local function cap()
    return tonumber(Cfg.Boost.bonusCap) or 0
end

local function getChar(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local ok, user = pcall(function() return Core.getUser(src) end)
    if not ok or not user then return nil end
    return user.getUsedCharacter
end

local function charIdOf(src)
    local char = getChar(src)
    if not char then return nil, nil end
    return tonumber(char.charIdentifier), char
end

local function fmtMoney(n)
    n = round2(n)
    if n == math.floor(n) then return ('$%d'):format(n) end
    return ('$%.2f'):format(n)
end

local function fmtLeft(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h <= 0 and m <= 0 then m = 1 end
    return ('%dh %02dm'):format(h, m), h, m
end

-- vorp tip on the right
local function toast(src, title, subtitle, symbol, duration)
    local text = title
    if subtitle and subtitle ~= "" then text = text .. ". " .. subtitle end
    TriggerClientEvent('vorp:TipRight', src, text, duration or 6000)
end

-- the gauge lives in fred_hud
local function pushUi(src, state)
    TriggerClientEvent('pup-misc:ecoboost', src, state)
end

local function uiState(src)
    local a = Active[src]
    if not a then return { active = false } end
    return { active = true, earned = round2(a.earned), cap = cap() }
end

-- rows are read once per character and kept in memory afterwards
local function rowFor(charid)
    local row = Rows[charid]
    if row then return row end
    local db = exports.oxmysql:single_async('SELECT earned, exhausted, completed_at, last_activated FROM ecoboost WHERE charid = ?', { charid })
    row = {
        earned    = round2(db and db.earned or 0),
        exhausted = (db and (db.exhausted == true or tonumber(db.exhausted) == 1)) or false,
        completed = tonumber(db and db.completed_at) or 0,
        activated = tonumber(db and db.last_activated) or 0,
    }
    Rows[charid] = row
    return row
end

local function saveRow(charid, row)
    Rows[charid] = row
    exports.oxmysql:execute(
        'INSERT INTO ecoboost (charid, last_activated, exhausted, earned, completed_at) VALUES (?, ?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE last_activated = VALUES(last_activated), exhausted = VALUES(exhausted), earned = VALUES(earned), completed_at = VALUES(completed_at)',
        { charid, row.activated or 0, row.exhausted and 1 or 0, row.earned, row.completed })
end

-- true once the activation that started this progress is older than Window
local function windowOver(row)
    if row.exhausted or (row.activated or 0) <= 0 then return false end
    return os.time() - row.activated >= (tonumber(Cfg.Boost.windowSeconds) or 0)
end

-- drop expired progress; the next activation starts from $0
local function expireRow(src, charid, row)
    if not windowOver(row) then return false end
    saveRow(charid, { earned = 0, exhausted = false, completed = 0, activated = 0 })
    if src and Active[src] and Active[src].charid == charid then
        Active[src] = nil
        pushUi(src, { active = false })
        toast(src, EcoBoostLocale.expiredTitle, EcoBoostLocale.expiredText, 'clock', 8000)
    end
    return true
end

local function saveEarned(charid, earned)
    local row = Rows[charid]
    if row then row.earned = earned end
    exports.oxmysql:execute('UPDATE ecoboost SET earned = ? WHERE charid = ?', { earned, charid })
end

local function categoryForStore(storeName)
    local name = tostring(storeName or ''):lower()
    for category, patterns in pairs(Cfg.Sales.storeCategories or {}) do
        for _, p in ipairs(patterns) do
            if name:find(tostring(p):lower(), 1, true) then return category end
        end
    end
    return nil
end

local function eligible(placeName)
    local category = categoryForStore(placeName)
    return category ~= nil and (Cfg.Sales.eligible or {})[category] == true
end

-- state

local function endBoost(src, notifyHide)
    if not Active[src] then return end
    Active[src] = nil
    if notifyHide then pushUi(src, { active = false }) end
end

-- seconds left on the cooldown, 0 when none is running
local function cooldownLeft(row)
    if not row.exhausted then return 0 end
    local left = (row.completed + (tonumber(Cfg.Boost.cooldownSeconds) or 0)) - os.time()
    return left > 0 and left or 0
end

-- what the pinboard button shows
local function getStatus(src)
    if not Cfg.General.enabled then return { state = 'disabled', cap = cap() } end
    local charid = charIdOf(src)
    if not charid then return { state = 'disabled', cap = cap() } end

    local row = rowFor(charid)
    expireRow(src, charid, row)
    row = Rows[charid]

    local a = Active[src]
    if a and a.charid == charid then
        return { state = 'active', earned = round2(a.earned), cap = cap() }
    end

    local left = cooldownLeft(row)
    if left > 0 then
        local text, h, m = fmtLeft(left)
        return {
            state          = 'completed',
            cap            = cap(),
            remaining      = left,
            remaining_text = text,
            hours          = h,
            minutes        = m,
        }
    end
    -- unfinished progress carries over; a finished, cooled-down boost starts fresh
    local earned = row.exhausted and 0 or row.earned
    return { state = 'available', earned = round2(earned), cap = cap() }
end

local function activate(src)
    local status = getStatus(src)
    if status.state == 'disabled' then return false, status, 'disabled' end
    if status.state == 'active' then return false, status, 'active' end
    if status.state == 'completed' then
        toast(src, EcoBoostLocale.cooldownTitle,
            (EcoBoostLocale.cooldownText):format(status.hours, status.minutes), 'clock')
        return false, status, 'cooldown'
    end

    local charid = charIdOf(src)
    if not charid then return false, status, 'nochar' end

    local earned = round2(status.earned or 0)
    -- resuming keeps the window of the activation that started the progress
    local prev = Rows[charid]
    local activated = (earned > 0 and prev and (prev.activated or 0) > 0) and prev.activated or os.time()
    Active[src] = { charid = charid, earned = earned, activatedAt = activated }
    saveRow(charid, { earned = earned, exhausted = false, completed = 0, activated = activated })
    pushUi(src, uiState(src))
    if earned > 0 then
        toast(src, EcoBoostLocale.resumedTitle,
            (EcoBoostLocale.resumedText):format(fmtMoney(earned), fmtMoney(cap())),
            'money', 8000)
    else
        toast(src, EcoBoostLocale.activatedTitle,
            (EcoBoostLocale.activatedText):format(fmtMoney(cap())),
            'money', 8000)
    end
    return true, getStatus(src), 'ok'
end

-- called by the store during the sale; returns the bonus to pay on top
local function applySale(src, placeName, total)
    if not Cfg.General.enabled then return 0 end
    src = tonumber(src)
    local a = src and Active[src]
    if not a then return 0 end
    if not eligible(placeName) then return 0 end

    local charid = charIdOf(src)
    if not charid or charid ~= a.charid then
        endBoost(src, true)
        return 0
    end
    if expireRow(src, charid, rowFor(charid)) then return 0 end

    total = tonumber(total)
    if not total or total ~= total then return 0 end
    total = round2(total)
    if total <= 0 then return 0 end

    local boosted   = round2(total * (tonumber(Cfg.Boost.multiplier) or 1))
    local bonus     = round2(boosted - total)
    local remaining = round2(cap() - a.earned)
    local allowed   = round2(math.min(bonus, remaining))
    if allowed <= 0 then
        endBoost(src, true)
        return 0
    end

    a.earned = round2(a.earned + allowed)

    if a.earned >= cap() then
        -- finished: the cooldown starts now
        saveRow(charid, { earned = cap(), exhausted = true, completed = os.time(), activated = a.activatedAt })
        endBoost(src, true)
        toast(src, EcoBoostLocale.completedTitle,
            (EcoBoostLocale.completedText):format(fmtMoney(cap())), 'check', 8000)
    else
        saveEarned(charid, a.earned)
        pushUi(src, uiState(src))
        if Cfg.General.notifyProgress then
            toast(src, (EcoBoostLocale.bonusTitle):format(fmtMoney(allowed)),
                (EcoBoostLocale.progressText):format(fmtMoney(a.earned), fmtMoney(cap())), 'money', 4000)
        end
    end
    return allowed
end

-- session ends: the active boost goes, the saved progress stays

AddEventHandler('playerDropped', function()
    endBoost(source, false)
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    endBoost(src, true)
end)

-- running boosts whose window ran out end on their own
CreateThread(function()
    while true do
        Wait(60000)
        for src, a in pairs(Active) do
            local row = Rows[a.charid]
            if row then expireRow(src, a.charid, row) end
        end
    end
end)

-- fred_hud asks after it (re)starts so the gauge matches the server
RegisterNetEvent('pup-misc:ecoboost:sync', function()
    local src = source
    pushUi(src, uiState(src))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Active) do pushUi(src, { active = false }) end
    Active = {}
end)

-- exports

-- what a store may SHOW this player: the multiplier while boosted and eligible, else 1
exports('EcoBoostMultiplierFor', function(src, placeName)
    src = tonumber(src)
    local a = src and Active[src]
    if not Cfg.General.enabled or not a then return 1 end
    if not eligible(placeName) then return 1 end
    if (cap() - a.earned) <= 0 then return 1 end
    return tonumber(Cfg.Boost.multiplier) or 1
end)

exports('GetEcoBoostStatus', getStatus)
exports('ActivateEcoBoost', function(src)
    local ok, status, reason = activate(src)
    return { ok = ok, status = status, reason = reason }
end)
exports('ApplyEcoBoostSale', applySale)
exports('EndEcoBoost', function(src) endBoost(tonumber(src), true) end)
