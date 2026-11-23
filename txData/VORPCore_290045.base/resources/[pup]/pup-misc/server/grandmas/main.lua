-- pup-misc / grandmas - server: validates and charges the NPC doctor revive

VorpCore = VorpCore or exports.vorp_core:GetCore()

local cooldowns = {}

RegisterServerEvent("pup-grandma:revive")
AddEventHandler("pup-grandma:revive", function(price, gold)
    local _source = source
    local user = VorpCore.getUser(_source)
    local Character = user and user.getUsedCharacter
    if not Character then return end
    local cooldownKey = Character.charIdentifier

    if cooldowns[cooldownKey] and GetGameTimer() < cooldowns[cooldownKey] then
        TriggerClientEvent("pup-grandma:reccooldown", _source, true)
        return
    end

    -- Security check: Distance and price validation
    local playerPed = GetPlayerPed(_source)
    local playerCoords = GetEntityCoords(playerPed)
    local validNpc = false
    local serverPrice = nil
    local serverGold = nil

    for k, v in pairs(GrandmasConfig.Doctors) do
        local dist = #(playerCoords - vector3(v.coords.x, v.coords.y, v.coords.z))
        if dist < 5.0 then
            validNpc = true
            serverPrice = v.price
            serverGold = v.gold
            break
        end
    end

    if not validNpc then
        return -- Too far from any doctor
    end

    -- vorp_core's death flag can miss a death after a character switch, so the ped's own health
    -- also counts as dead; refused only when both say alive
    if not (Character.isdead == true or Character.isdead == 1 or GetEntityHealth(playerPed) <= 0) then
        TriggerClientEvent("vorp:TipRight", _source, GrandmasLocale.notdead, 4000)
        return
    end

    price = serverPrice
    gold = serverGold

    local playercash = Character.money
    local gold2 = Character.gold
    if gold then
        if gold2 >= price then
            Character.removeCurrency(1, price)
            -- grandma revives get the same weakness period as medical revives (the countdown shows on fred_hud)
            VorpCore.Player.Revive(_source)
            TriggerClientEvent("pup-grandma:revived", _source)
            TriggerClientEvent("fred_meta:consume", _source, 50, 50, 0, 0, 0, 0, 0, 0, 0)
            TriggerClientEvent("vorp:TipRight", _source, GrandmasLocale.healed .. price .. GrandmasLocale.gold, 5000)
            TriggerClientEvent("pup-grandma:reccooldown", _source, true)
            cooldowns[cooldownKey] = GetGameTimer() + (GrandmasConfig.Treatment.cooldownMinutes * 60000)
        else
            TriggerClientEvent("vorp:TipRight", _source, GrandmasLocale.nocash, 5000)
        end
    else
        -- always treat, even when broke: the healer never turns a dying player away
        Character.removeCurrency(0, price)
        VorpCore.Player.Revive(_source)
        TriggerClientEvent("pup-grandma:revived", _source)
        TriggerClientEvent("fred_meta:consume", _source, 50, 50, 0, 0, 0, 0, 0, 0, 0)
        TriggerClientEvent("vorp:TipRight", _source, GrandmasLocale.healed .. price .. GrandmasLocale.cash, 5000)
        if playercash < price then
            TriggerClientEvent("vorp:TipRight", _source,
                (GrandmasLocale.onTab):format(playercash - price), 6000)
        end
        TriggerClientEvent("pup-grandma:reccooldown", _source, true)
        cooldowns[cooldownKey] = GetGameTimer() + (GrandmasConfig.Treatment.cooldownMinutes * 60000)
    end
end)
