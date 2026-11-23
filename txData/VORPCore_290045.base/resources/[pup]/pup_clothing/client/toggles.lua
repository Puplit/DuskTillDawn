-- pup_clothing | /hat, /coat ...: take one garment off, and the same command puts it back exactly.

local Cat, Ped = PC.Cat, PC.Ped
local Toggles = { stored = {} } -- [category] = component tuple taken off
PC.Toggles = Toggles

function Toggles.clear()
    Toggles.stored = {}
end

local function toggle(cat)
    local ped = PlayerPedId()
    local kept = Toggles.stored[cat]
    if kept then
        Ped.waitReady(ped, 100)
        Ped.setTag(ped, kept)
        Ped.refresh(ped)
        Toggles.stored[cat] = nil
        return
    end
    local idx = Ped.indexOf(ped, cat)
    if idx then
        Toggles.stored[cat] = Ped.tuple(ped, idx)
        Ped.remove(ped, cat)
        Ped.refresh(ped)
        return
    end
    -- nothing worn and nothing kept (the hat was knocked off): ask for the saved garment back
    TriggerEvent('vorp_character:client:wearCategory', Cat.vorpCategoryHash(cat))
    PC.Extras.request(false)
end

exports('OwnsToggleCommand', function(command)
    return Config.Toggles.enabled == true and type(command) == 'string' and Config.ToggleCommands[command] ~= nil
end)

if Config.Toggles.enabled then
    local n = 0
    for command, cat in pairs(Config.ToggleCommands) do
        RegisterCommand(command, function()
            if PC.Store and PC.Store.isOpen() then return end
            toggle(cat)
        end, false)
        n = n + 1
    end
    print(('[pup_clothing] %s'):format(L('toggleCount', n)))
end
