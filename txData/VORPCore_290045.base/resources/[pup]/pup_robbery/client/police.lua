-- pup_robbery | lawmen: the small blinking "Robbery in Progress" blip

LawBlips = {}

local blips = {} -- [key] = blip

local function drop(key)
    if blips[key] then C.removeBlip(blips[key]) end
    blips[key] = nil
end

RegisterNetEvent('pup_robbery:police:blip', function(key, pos)
    if type(key) ~= 'string' or type(pos) ~= 'table' then return end
    drop(key)
    local b = C.blipAt(C.v3(pos), Config.LawBlip.sprite, Config.LawBlip.scale, L('lawBlip'))
    if b then
        C.blipModifier(b, Config.LawBlip.modifier)
        blips[key] = b
    end
end)

RegisterNetEvent('pup_robbery:police:clear', function(key)
    drop(key)
end)

RegisterNetEvent('pup_robbery:police:clearMine', function()
    for key in pairs(blips) do drop(key) end
end)

function LawBlips.cleanup()
    for key in pairs(blips) do drop(key) end
end
