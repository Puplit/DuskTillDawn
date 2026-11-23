-- pup_clothing | everything that touches the ped's garments.

local U, Cat = PC.U, PC.Cat
local Ped = {}
PC.Ped = Ped

local N <const> = {
    numComponents = 0x90403E8107B60E81,
    categoryAt    = 0x9B90842304C938A7,
    shopItemAt    = 0x77BA37622E22023B,
    assetGuids    = 0xA9C28516A6DC9D56,
    assetTint     = 0xE7998FEC53A33BBE,
    usesCategory  = 0xFB4891BD7578CDC1,
    removeTag     = 0xD710A5007C2AC539,
    applyShopItem = 0xD3A7B003ED343FD9,
    setMetaTag    = 0xBC6DF00D7A4A6819,
    categoryTint  = 0x4EFC1F8FF1AD94DE,
    updateVariation = 0xCC8CA3E88256E58F,
    readyToRender = 0xA0BC8FAED8CFEB3C,
}

local function truthy(v) return v == true or (type(v) == 'number' and v ~= 0) end

local warned = false
local function warnOnce(msg)
    if warned then return end
    warned = true
    print(('^3[pup_clothing]^7 %s'):format(msg))
end

function Ped.dbg(fmt, ...)
    if Config.Debug.client then print(('^5[pup_clothing]^7 ' .. fmt):format(...)) end
end

function Ped.sex(ped)
    return IsPedMale(ped or PlayerPedId()) and 'male' or 'female'
end

function Ped.isReady(ped)
    return truthy(Citizen.InvokeNative(N.readyToRender, ped))
end

function Ped.waitReady(ped, frames)
    for _ = 1, frames or 100 do
        if not DoesEntityExist(ped) or Ped.isReady(ped) then return end
        Wait(0)
    end
end

function Ped.refresh(ped)
    Citizen.InvokeNative(N.updateVariation, ped, false, true, true, true, false)
end

function Ped.uses(ped, cat)
    return truthy(Citizen.InvokeNative(N.usesCategory, ped, Cat.categoryHash(cat)))
end

function Ped.remove(ped, cat)
    Citizen.InvokeNative(N.removeTag, ped, Cat.categoryHash(cat), 0)
end

function Ped.applyHash(ped, hash)
    local h = U.u32(hash)
    if not h or h == 0 then return end
    Citizen.InvokeNative(N.applyShopItem, ped, h, true, true, false)
end

function Ped.setTag(ped, t)
    Citizen.InvokeNative(N.setMetaTag, ped, t.d, t.a or 0, t.n or 0, t.m or 0, t.p or 0,
        t.t0 or 0, t.t1 or 0, t.t2 or 0)
end

function Ped.paletteHash(index)
    return Config.Palettes[U.int(index) or 1] or Config.Palettes[1]
end

-- colour a multiplayer garment by category
function Ped.tintCategory(ped, cat, palette, c)
    c = c or {}
    Citizen.InvokeNative(N.categoryTint, ped, Cat.categoryHash(cat), Ped.paletteHash(palette),
        U.int(c[1]) or 0, U.int(c[2]) or 0, U.int(c[3]) or 0)
end

-- a singleplayer garment, in its own colours or in a custom one
function Ped.applyNpc(ped, row, colour)
    local t = { d = row.d, a = row.a, n = row.n, m = row.m, p = row.p,
        t0 = row.t[1] or 0, t1 = row.t[2] or 0, t2 = row.t[3] or 0 }
    if colour and (colour.p or 0) > 0 then
        local c = colour.c or {}
        t.p = Ped.paletteHash(colour.p)
        t.t0, t.t1, t.t2 = U.int(c[1]) or 0, U.int(c[2]) or 0, U.int(c[3]) or 0
    end
    Ped.setTag(ped, t)
end

local function shopHashAt(ped, i)
    if type(DataView) ~= 'table' or type(DataView.ArrayBuffer) ~= 'function' then
        warnOnce("vorp_core's DataView helper did not load; worn garments cannot be read from the ped")
        return 0
    end
    local ok, h = pcall(function()
        local buf = DataView.ArrayBuffer(6 * 8)
        return Citizen.InvokeNative(N.shopItemAt, ped, i, true, buf:Buffer(), buf:Buffer(), Citizen.ResultAsInteger())
    end)
    return ok and (U.u32(h) or 0) or 0
end

-- what the ped wears: list of { cat = key|nil, catHash = u32, shop = u32 (0 if none), index }
function Ped.scan(ped)
    local out = {}
    local n = Citizen.InvokeNative(N.numComponents, ped, Citizen.ResultAsInteger()) or 0
    for i = 0, n - 1 do
        local catHash = U.u32(Citizen.InvokeNative(N.categoryAt, ped, i, 0, Citizen.ResultAsInteger()))
        if catHash then
            out[#out + 1] = { cat = Cat.catByHash[catHash], catHash = catHash, shop = shopHashAt(ped, i), index = i }
        end
    end
    return out
end

-- the component index of a category on the ped, or nil
function Ped.indexOf(ped, cat)
    local want = U.u32(Cat.categoryHash(cat))
    local n = Citizen.InvokeNative(N.numComponents, ped, Citizen.ResultAsInteger()) or 0
    for i = 0, n - 1 do
        if U.u32(Citizen.InvokeNative(N.categoryAt, ped, i, 0, Citizen.ResultAsInteger())) == want then return i end
    end
    return nil
end

-- the full look of one component: drawable, albedo, normal, material, palette and three tints
function Ped.tuple(ped, index)
    local d, a, n, m = Citizen.InvokeNative(N.assetGuids, ped, index,
        Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
    local p, t0, t1, t2 = Citizen.InvokeNative(N.assetTint, ped, index,
        Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
    return { d = d, a = a, n = n, m = m, p = p, t0 = t0, t1 = t1, t2 = t2 }
end

-- clean dirt, blood, damage decals and wetness off the ped (each step optional on this build)
function Ped.clean(ped)
    local steps = {
        function() ClearPedEnvDirt(ped) end,
        function() ClearPedBloodDamage(ped) end,
        function() ClearPedWetness(ped) end,
        function()
            for zone = 0, 5 do ClearPedDamageDecalByZone(ped, zone, 'ALL') end
        end,
    }
    for _, f in ipairs(steps) do pcall(f) end
end

-- wait for vorp_character's `rc` rebuild: a new ped, then its streaming, then a short settle
function Ped.waitRebuild(oldPed)
    local T = Config.Timing
    local t0 = GetGameTimer()
    while PlayerPedId() == oldPed and GetGameTimer() - t0 < T.pedSwapMaxMs do Wait(50) end
    local ped = PlayerPedId()
    t0 = GetGameTimer()
    while not Ped.isReady(ped) and GetGameTimer() - t0 < T.streamMaxMs do
        Wait(50)
        ped = PlayerPedId()
    end
    Wait(T.settleMs)
end

-- updateCache, then `rc`, then wait for the rebuilt ped
function Ped.rebuildWith(compsJson)
    TriggerEvent('vorpcharacter:updateCache', false, compsJson)
    Wait(Config.Timing.beforeRcMs)
    local old = PlayerPedId()
    ExecuteCommand('rc')
    Ped.waitRebuild(old)
end
