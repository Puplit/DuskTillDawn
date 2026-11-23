-- pup-misc / hogtie - server: removes the lasso from a non-law player who hogtied someone

-- Get VORP Core instance to access character data and jobs
local VORPcore = nil

Citizen.CreateThread(function()
    while VORPcore == nil do
        TriggerEvent("getCore", function(core)
            VORPcore = core
        end)
        if VORPcore == nil then
            VORPcore = exports.vorp_core:GetCore()
        end
        Citizen.Wait(100)
    end
end)

-- Register and handle the event to remove the lasso @param hogtierserverid
RegisterServerEvent("pup-misc:hogtie:removelasso")
local lastLassoClaim = {}
-- [hogtier] = { victim = src, at = GetGameTimer() }: the last tie the server accepted against that player
local tiedBy = {}
AddEventHandler("playerDropped", function()
    lastLassoClaim[source] = nil
    tiedBy[source] = nil
end)

AddEventHandler("pup-misc:hogtie:removelasso", function(hogtierserverid, weapon)
    local _source = source -- The victim who triggered the event

    -- the victim's client names who tied them, so hold that claim to what it can be: a real lasso, from someone close by
    hogtierserverid = tonumber(hogtierserverid)
    if not hogtierserverid or hogtierserverid == _source then return end
    local isLasso = false
    for _, w in ipairs(HogtieConfig.Lasso.removeWeapons or {}) do
        if w == weapon then isLasso = true break end
    end
    if not isLasso then return end
    local now = GetGameTimer()
    if lastLassoClaim[_source] and now - lastLassoClaim[_source] < 5000 then return end
    lastLassoClaim[_source] = now
    local myPed, theirPed = GetPlayerPed(_source), GetPlayerPed(hogtierserverid)
    if not myPed or myPed == 0 or not theirPed or theirPed == 0 then return end
    -- a hogtie is done hand to hand, so the one who tied them is right next to them
    local a, b = GetEntityCoords(myPed), GetEntityCoords(theirPed)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    if dx * dx + dy * dy + dz * dz > 5.0 * 5.0 then return end
    -- one lasso per tie: the same player is not stripped again within 30 seconds
    local prev = tiedBy[hogtierserverid]
    if prev and now - prev.at < 30000 then return end
    tiedBy[hogtierserverid] = { victim = _source, at = now }

    if HogtieConfig.General.debug then
        print(string.format("[DEBUG] hogtie:removelasso triggered by %s for attacker %s with weapon %s", _source, hogtierserverid, weapon))
    end

    if VORPcore == nil then
        if HogtieConfig.General.debug then print("[DEBUG] VORPcore is nil!") end
        return
    end

    local User = VORPcore.getUser(hogtierserverid)
    if not User then
        if HogtieConfig.General.debug then print(string.format("[DEBUG] No User found for server ID %s", hogtierserverid)) end
        return
    end

    local Character = User.getUsedCharacter
    if not Character then 
        if HogtieConfig.General.debug then print(string.format("[DEBUG] No Character found for server ID %s", hogtierserverid)) end
        return 
    end

    local job = Character.job
    if HogtieConfig.General.debug then print(string.format("[DEBUG] Attacker job: %s", job)) end

    local isWhitelisted = false

    for _, whitelistedJob in ipairs(HogtieConfig.Lasso.keepJobs) do
        if job == whitelistedJob then
            isWhitelisted = true
            break
        end
    end

    -- whitelisted jobs (police, marshal, ...) keep their lasso
    if isWhitelisted then 
        if HogtieConfig.General.debug then print("[DEBUG] Attacker job is whitelisted, keeping lasso") end
        return 
    end

    if HogtieConfig.General.debug then print("[DEBUG] Attacker job NOT whitelisted, proceeding to removal") end

    -- otherwise remove the lasso from their inventory
    exports.vorp_inventory:getUserInventoryWeapons(hogtierserverid, function(weapons)
        if HogtieConfig.General.debug then print(string.format("[DEBUG] Found %s weapons in attacker inventory", #weapons)) end
        for _, w in ipairs(weapons) do
            if w.name == weapon then
                if HogtieConfig.General.debug then print(string.format("[DEBUG] Matching weapon found: %s (ID: %s). Removing...", w.name, w.id)) end
                exports.vorp_inventory:subWeapon(hogtierserverid, w.id, function(success)
                    if success then
                        if HogtieConfig.General.debug then print("[DEBUG] Weapon successfully removed") end
                        TriggerClientEvent("pup-misc:hogtie:lassoRemoved", hogtierserverid, weapon)
                    else
                        if HogtieConfig.General.debug then print("[DEBUG] Weapon removal failed in vorp_inventory:subWeapon") end
                    end
                end)
                break
            end
        end
    end)
end)
