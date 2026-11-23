-- pup-misc / pomade (server) Registers the usable item and gates it on the character's sex

CreateThread(function()
    local item  = PomadeConfig.Item.name
    local label = PomadeConfig.Item.label or "Hair Pomade"
    if not item then return end

    exports.oxmysql:execute(
        "INSERT INTO items (item, label, `limit`, can_remove, type, usable) VALUES (?, ?, 10, 1, 'item_standard', 1) " ..
        "ON DUPLICATE KEY UPDATE usable = 1, label = VALUES(label)",
        { item, label })

    exports.vorp_inventory:registerUsableItem(item, function(data)
        local src = data.source
        exports.vorp_inventory:closeInventory(src)

        if PomadeConfig.Use.maleOnly then
            local Character = VorpCore.getUser(src) and VorpCore.getUser(src).getUsedCharacter
            -- characters.gender is "Male" / "Female"; skin.sex is the model name
            local isFemale = false
            if Character then
                local g = tostring(Character.gender or ""):lower()
                if g == "female" or g == "f" then isFemale = true end
                if g == "" and type(Character.skin) == "string" then
                    isFemale = Character.skin:find("mp_female") ~= nil
                end
            end
            if isFemale then
                VorpCore.NotifyRightTip(src, PomadeLocale.denyFemale or "You cant use that", 4000)
                return
            end
        end

        exports.vorp_inventory:subItem(src, item, 1)
        TriggerClientEvent("pup_pomade:apply", src)
    end, GetCurrentResourceName())
end)
