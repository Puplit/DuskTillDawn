-- pup_clothing | extras: custom colours and singleplayer garments that VORP's record cannot hold.

local U, Cat, Ped = PC.U, PC.Cat, PC.Ped
local Extras = {
    own = {},        -- this character's saved extras (the colour memory for its own look)
    foreign = false, -- true while a borrowed look (a disguise's extras) is on the ped
}
PC.Extras = Extras

local function opts()
    return {
        keyMax = Config.Server.syncKeyMax, paletteCount = #Config.Palettes,
        chanMax = Config.Tints.channelMax, maxSlots = Config.Server.extrasMaxSlots,
    }
end

local function disguised()
    if GetResourceState('vorp_character') ~= 'started' then return false end
    local ok, v = pcall(function() return exports.vorp_character:IsDisguised() end)
    return ok and v == true
end
Extras.disguised = disguised

function Extras.parse(jsonStr)
    local t = U.decodeObject(jsonStr, Config.Server.payloadMax)
    if not t then return {} end
    return U.cleanExtras(t, opts()) or {}
end

-- put an extras map on the ped
function Extras.apply(map)
    local ped = PlayerPedId()
    local sex = Ped.sex(ped)
    local n = 0
    for cat, e in pairs(map or {}) do
        local colour = (e.p or 0) > 0 and e or nil
        local row = e.h and Cat.npcRow(sex, e.h) or nil
        if row then
            Ped.applyNpc(ped, row, colour)
            n = n + 1
        elseif colour and Ped.uses(ped, cat) then
            Ped.tintCategory(ped, cat, colour.p, colour.c)
            n = n + 1
        end
    end
    Ped.refresh(ped)
    Ped.dbg('extras applied: %d slot(s)', n)
    if not (PC.Store and PC.Store.isOpen()) then
        TriggerEvent('vorp_character:client:reassertRolledClothing')
    end
end

function Extras.request(sanitize)
    TriggerServerEvent('pup_clothing:getExtras', sanitize == true)
end

-- blank compPlayer slots that hold a garment hash the catalogue does not know
local function sanitize(compsJson)
    if not Cat.ready or Config.Npc.keepTailorPieces then return end
    local t = U.decodeObject(compsJson, 64000)
    if not t then return end
    local changed = 0
    for k, v in pairs(t) do
        if type(v) == 'number' and v ~= -1 and v ~= 0 and not Cat.known(v) then
            t[k] = -1
            changed = changed + 1
        end
    end
    if changed > 0 then
        Ped.dbg('login check blanked %d unknown garment slot(s)', changed)
        TriggerEvent('vorpcharacter:updateCache', false, json.encode(t))
    end
end

-- the server answers with origin 'own'; vorp_character's disguise fires this locally with only the JSON
RegisterNetEvent('pup_clothing:recExtras', function(jsonStr, origin, compsJson)
    local map = Extras.parse(jsonStr)
    if origin == 'own' then
        if disguised() then return end -- never dress a borrowed look in this character's extras
        Extras.own = map
        Extras.foreign = false
        Extras.apply(map)
        if type(compsJson) == 'string' then sanitize(compsJson) end
    else
        -- a borrowed look: shown on the ped, never kept as this character's colours
        Extras.foreign = true
        if PC.Toggles then PC.Toggles.clear() end
        Extras.apply(map)
    end
end)

AddEventHandler('vorp_character:client:reloadedComponents', function()
    if PC.Toggles then PC.Toggles.clear() end
    Extras.request(false)
end)

AddEventHandler('pup_clothing:client:dressExtras', function()
    if PC.Toggles then PC.Toggles.clear() end
    Extras.request(false)
end)

AddEventHandler('pup_clothing:client:undressExtras', function()
    if not Cat.npc then return end
    local ped = PlayerPedId()
    for cat, e in pairs(Extras.own) do
        if e.h then Ped.remove(ped, cat) end
    end
    Ped.refresh(ped)
    if PC.Toggles then PC.Toggles.clear() end
end)

RegisterCommand('reapplyclothes', function()
    Extras.request(false)
end, false)

-- the first fetch, with the login check
CreateThread(function()
    Wait(Config.Timing.extrasAfterStart)
    Extras.request(true)
end)
