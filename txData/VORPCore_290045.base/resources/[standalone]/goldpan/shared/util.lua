-- goldpan | shared helpers (client and server)

GP = {}

-- every water hash is compared as unsigned 32-bit, whatever sign the game or GetHashKey gives
function GP.u32(v)
    v = tonumber(v)
    if not v or v ~= v then return 0 end
    v = math.tointeger(math.floor(v))
    if not v then return 0 end -- inf or out of integer range
    return v & 0xFFFFFFFF
end

function GP.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- [u32 hash] = { name, type }
GP.Waters = {}
for _, w in ipairs(Config.WaterTypes or {}) do
    local h = type(w.hash) == 'number' and GP.u32(w.hash) or GP.u32(GetHashKey(w.hash))
    if h ~= 0 then GP.Waters[h] = { name = w.name, type = w.type } end
end

function GP.water(hash)
    hash = GP.u32(hash)
    if hash == 0 then return nil end
    return GP.Waters[hash], hash
end

function GP.msg(key)
    return (Config.Messages and Config.Messages[key]) or tostring(key)
end

function GP.toneOf(key)
    return (Config.RedMessages and Config.RedMessages[key]) and 'red' or 'gold'
end

function GP.msOf(key, fallback)
    return (Config.MessageMs and Config.MessageMs[key]) or fallback or 5000
end
