-- pup_mortician | the burial limit
-- Counts live in memory per character. In 'window' mode they are loaded from
-- mortician_shift once (the only wait) and written back on every burial, so the
-- check-and-count step itself never waits and two requests cannot both take
-- the last slot.

local Shift = {}   -- charId -> { started = unix, burials = n }
local loading = {} -- charId -> promise while the row is being read

local function windowSeconds()
    return math.floor((tonumber(Config.Limit.windowHours) or 24) * 3600)
end

local function isWindow()
    return Config.Limit.mode == 'window'
end

local function windowOpen(s, now)
    return s.started > 0 and now < s.started + windowSeconds()
end

-- loads (once) and returns the character's count; nil when the database failed
function LimitLoad(charId)
    if Shift[charId] then return Shift[charId] end
    if not isWindow() then
        Shift[charId] = { started = 0, burials = 0 }
        return Shift[charId]
    end
    if loading[charId] then
        Citizen.Await(loading[charId])
        return Shift[charId]
    end
    local p = promise.new()
    loading[charId] = p
    local ok, row = pcall(MySQL.single.await, 'SELECT started, burials FROM mortician_shift WHERE charid = ?', { charId })
    if ok then
        if not Shift[charId] then
            Shift[charId] = row and { started = tonumber(row.started) or 0, burials = tonumber(row.burials) or 0 }
                or { started = 0, burials = 0 }
        end
    else
        Warn('could not read mortician_shift for char ' .. tostring(charId))
    end
    loading[charId] = nil
    p:resolve(true)
    return Shift[charId]
end

-- burials left from an already loaded count (no waiting)
local function leftOf(s)
    local limit = Config.Limit.perCharacter
    if not s then return 0 end
    if isWindow() then
        if not windowOpen(s, os.time()) then return limit end
        return math.max(0, limit - s.burials)
    end
    return math.max(0, limit - s.burials)
end

-- waits for the row the first time; afterwards answers from memory
function BurialsLeft(charId)
    return leftOf(LimitLoad(charId))
end

-- unix time the window reopens, only when nothing is left (window mode)
function LimitReopensAt(charId)
    local s = Shift[charId]
    if not isWindow() or not s or leftOf(s) > 0 then return nil end
    return s.started + windowSeconds()
end

-- Takes one burial slot. Must be called with the count loaded (BurialsLeft
-- first). Never waits, so the check and the count happen together.
function LimitReserve(charId)
    local s = Shift[charId]
    if not s or leftOf(s) <= 0 then return false end
    local now = os.time()
    if isWindow() then
        if not windowOpen(s, now) then
            s.started, s.burials = now, 1
            MySQL.update('REPLACE INTO mortician_shift (charid, started, burials) VALUES (?, ?, 1)', { charId, now })
        else
            s.burials = s.burials + 1
            MySQL.update('UPDATE mortician_shift SET burials = burials + 1 WHERE charid = ?', { charId })
        end
    else
        s.burials = s.burials + 1
    end
    return true
end

-- window mode re-reads from the database next time; restart mode keeps its count
function LimitForget(charId)
    if isWindow() then Shift[charId] = nil end
end
