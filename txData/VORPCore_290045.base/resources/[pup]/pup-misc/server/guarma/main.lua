-- pup-misc / guarma - server half

-- own reference: the VorpCore in server/cannon/main.lua is a file-local, not shared
local Core = exports.vorp_core:GetCore()

local COOLDOWN <const> = 3000
local lastUse = {}

local function dist(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

RegisterNetEvent('pup-misc:guarma:request', function(direction)
    local src <const> = source
    if direction ~= 'island' and direction ~= 'mainland' then return end

    local now <const> = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < COOLDOWN then return end
    lastUse[src] = now

    -- must actually be standing at the dock they claim to be at
    local from <const> = (direction == 'island') and GuarmaConfig.Docks.mainland or GuarmaConfig.Docks.island
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if dist(GetEntityCoords(ped), from) > (GuarmaConfig.Docks.promptDistance + 3.0) then
        if GuarmaConfig.General.debug then
            print(('^1[pup-misc:guarma]^7 %s asked to sail but is not at the dock'):format(src))
        end
        return
    end

    local user = Core.getUser(src)
    local char = user and user.getUsedCharacter
    if not char then return end

    if #(GuarmaConfig.Crossing.jobs or {}) > 0 then
        local ok = false
        for _, j in ipairs(GuarmaConfig.Crossing.jobs) do
            if char.job == j then ok = true break end
        end
        if not ok then
            return Core.NotifyRightTip(src, GuarmaLocale.notForYou, 4000)
        end
    end

    if GuarmaConfig.Crossing.ticketItem then
        local count = exports.vorp_inventory:getItemCount(src, nil, GuarmaConfig.Crossing.ticketItem)
        if not count or count < 1 then
            return Core.NotifyRightTip(src, GuarmaLocale.needTicket, 4000)
        end
    end

    -- both are checked before either is taken, so a refused crossing costs nothing
    local price <const> = tonumber(GuarmaConfig.Crossing.price) or 0
    if price > 0 then
        local have <const> = (GuarmaConfig.Crossing.moneyType == 1) and char.gold or char.money
        if have < price then
            return Core.NotifyRightTip(src, (GuarmaLocale.tooPoor):format(price), 4000)
        end
    end

    if GuarmaConfig.Crossing.ticketItem then
        exports.vorp_inventory:subItem(src, GuarmaConfig.Crossing.ticketItem, 1)
    end
    if price > 0 then
        char.removeCurrency(GuarmaConfig.Crossing.moneyType or 0, price)
    end

    TriggerClientEvent('pup-misc:guarma:board', src, direction)
end)

AddEventHandler('playerDropped', function()
    lastUse[source] = nil
end)
