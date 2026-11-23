CORE = exports.vorp_core:GetCore()
LANG = CONFIG.LANG[CONFIG.LANGUAGE]
local LIB = Import 'dataview'
DataView = LIB.DataView


-- REBINDABLE KEYS (see CONFIG.KEYBINDS)
local KB <const>     = CONFIG.KEYBINDS or {}
local KB_ON <const>  = KB.ENABLE == true
local wantOpenInv    = false
local wantHotbarShow = false
local wantHotbarSlot = nil
local holdingHotbar  = false

-- A KEYBIND MUST NOT FIRE WHILE A NUI HAS THE KEYBOARD
-- otherwise typing into the inventory's own SEARCH box, or any pup-ui input
-- dialog, presses these binds: an "i" in "fish" would re-open the inventory
local function typing()
    return IsNuiFocused()
end

if KB_ON then
    RegisterCommand("vorpinv_open", function()
        if typing() then return end
        wantOpenInv = true
    end, false)
    RegisterKeyMapping("vorpinv_open", "Open Inventory", "keyboard", KB.OPEN_INVENTORY or "I")

    if CONFIG.HOTBAR.ENABLE then
        RegisterCommand("vorpinv_hotbar", function()
            if typing() then return end
            wantHotbarShow = true
        end, false)
        RegisterKeyMapping("vorpinv_hotbar", "Hotbar: show/hide", "keyboard", KB.HOTBAR_TOGGLE or "X")

        -- a hold needs the +/- command pair; the runtime calls -name on release
        RegisterCommand("+vorpinv_hotbarhold", function()
            if typing() then return end
            holdingHotbar = true
        end, false)
        RegisterCommand("-vorpinv_hotbarhold", function() holdingHotbar = false end, false)
        RegisterKeyMapping("+vorpinv_hotbarhold", "Hotbar: hold to use", "keyboard", KB.HOTBAR_HOLD or "LMENU")

        for i = 1, 5 do
            RegisterCommand("vorpinv_slot" .. i, function()
                if typing() then return end
                -- checked at PRESS time: without this a number pressed during normal play would queue and then fire the moment the hold key went down
                if KB.REQUIRE_HOLD ~= false and not holdingHotbar then return end
                if not LocalPlayer.state.IsInSession then return end
                wantHotbarSlot = i
            end, false)
            RegisterKeyMapping("vorpinv_slot" .. i, "Hotbar: slot " .. i, "keyboard",
                (KB.HOTBAR_SLOTS or {})[i] or tostring(i))
        end
    end
end


if CONFIG.HOTBAR.ENABLE then
    CreateThread(function()
        repeat Wait(5000) until LocalPlayer.state.IsInSession
        local hotbarHudVisible = false
        local hotbarSuppressed = false
        local IsPauseMenuActive = IsPauseMenuActive
        local IsUiappActiveByHash = IsUiappActiveByHash
        local IsInCinematicMode = IsInCinematicMode
        local IsScreenFadedOut = IsScreenFadedOut
        local IsControlJustPressed = IsControlJustPressed

        while true do
            local sleep = 1000
            if not IS_INV_OPEN then
                sleep = 0

                local toggled = false
                if KB_ON then
                    toggled, wantHotbarShow = wantHotbarShow, false
                else
                    toggled = IsControlJustPressed(0, CONFIG.HOTBAR.TOGGLE_KEY)
                end
                if toggled then
                    hotbarHudVisible = not hotbarHudVisible
                    hotbarSuppressed = false
                    NUI_SERVICE.HOTBAR.SET_VISIBLE(hotbarHudVisible)
                end

                for i = 1, 5 do
                    if (KB_ON and holdingHotbar) or (not KB_ON and IsControlPressed(0, CONFIG.HOTBAR.HOLD_KEY)) then
                        if CONFIG.HOTBAR.SHOW_WHEN_HOLD and not hotbarHudVisible then
                            hotbarHudVisible = true
                            hotbarSuppressed = false
                            NUI_SERVICE.HOTBAR.SET_VISIBLE(hotbarHudVisible)
                            SetTimeout(3000, function()
                                hotbarHudVisible = false
                                hotbarSuppressed = true
                                NUI_SERVICE.HOTBAR.SET_VISIBLE(hotbarHudVisible)
                            end)
                        end

                        DisableControlAction(0, CONFIG.HOTBAR.SLOT_KEYS[i], true)
                        if KB_ON then
                            if wantHotbarSlot then
                                local slot <const> = wantHotbarSlot
                                wantHotbarSlot = nil
                                NUI_SERVICE.HOTBAR.USE_ITEM(slot, true)
                                break
                            end
                        elseif IsDisabledControlJustPressed(0, CONFIG.HOTBAR.SLOT_KEYS[i]) then
                            NUI_SERVICE.HOTBAR.USE_ITEM(i, true)
                            break
                        end
                    end
                end
            end

            local isMenuOpen <const> = IsPauseMenuActive() == 1
            local isHudHidden <const> = IsHudHidden()
            local isCinematic <const> = IsInCinematicMode() == 1
            local isMapOpen <const> = IsUiappActiveByHash(joaat("MAP")) == 1
            local isScreenFaded <const> = IsScreenFadedOut()
            local shouldSuppress = isMenuOpen or isHudHidden or isCinematic or isMapOpen or isScreenFaded

            if shouldSuppress and hotbarHudVisible and not hotbarSuppressed then
                hotbarSuppressed = true
                NUI_SERVICE.HOTBAR.SET_VISIBLE(false)
            elseif not shouldSuppress and hotbarSuppressed then
                hotbarSuppressed = false
                NUI_SERVICE.HOTBAR.SET_VISIBLE(hotbarHudVisible)
            end

            Wait(sleep)
        end
    end)
end



AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    if not CONFIG.DEV_MODE then return end

    SendNUIMessage({ action = "hide" })
    TriggerServerEvent("DEV:loadweapons")
    TriggerServerEvent("vorpinventory:getItemsTable")
    Wait(1000)
    TriggerServerEvent("vorpinventory:getInventory")
    Wait(1000)
    TriggerServerEvent("vorpCore:LoadAllAmmo")
end)



if CONFIG.USE_LANTERN_ON_BELT then
    CreateThread(function()
        repeat Wait(5000) until LocalPlayer.state.IsInSession

        local IsWeaponLantern = IsWeaponLantern
        local lastLantern = 0

        while true do
            local pedid = CACHE.Ped
            local weaponHeld <const> = CACHE.Weapon
            local isLantern <const> = IsWeaponLantern(weaponHeld) == 1 -- assuming it will return all lanterns to true
            if isLantern then
                lastLantern = weaponHeld
            end

            if lastLantern ~= 0 and not isLantern then
                SetCurrentPedWeapon(pedid, lastLantern, true, 12, false, false)
                lastLantern = 0
            end
            Wait(500)
        end
    end)
end



if CONFIG.PUSH_TO_TALK then
    CreateThread(function()
        repeat Wait(5000) until LocalPlayer.state.IsInSession
        local isNuiFocused = false
        local DisableAllControlActions = DisableAllControlActions
        local EnableControlAction = EnableControlAction

        while true do
            local sleep = 0
            if IS_INV_OPEN then
                if not isNuiFocused then
                    SetNuiFocusKeepInput(true)
                    isNuiFocused = true
                end

                DisableAllControlActions(0)
                EnableControlAction(0, `INPUT_PUSH_TO_TALK`, true)
                -- mumble latches the mic with SetControlNormal; re-assert it after the disable
                if LocalPlayer.state.pup_ptt_latched then SetControlNormal(0, `INPUT_PUSH_TO_TALK`, 1.0) end
                if LocalPlayer.state.pup_radio_talking then
                    EnableControlAction(0, 249, true)
                    SetControlNormal(0, 249, 1.0)
                    SetControlNormal(1, 249, 1.0)
                    SetControlNormal(2, 249, 1.0)
                end
            else
                sleep = 1000
                if isNuiFocused then
                    SetNuiFocusKeepInput(false)
                    isNuiFocused = false
                end
            end
            Wait(sleep)
        end
    end)
end

CreateThread(function()
    local controlVar = false -- best to use variable than to check statebag every frame
    local isWalking = false
    if CONFIG.DISABLE_WEAPON_WHELL_ITEMS then
        EnableHudContext(-2106452847)
    end
    if CONFIG.DISABLE_WEAPON_WHEEL_WEAPONS then
        EnableHudContext(-1249243147)
    end

    repeat Wait(5000) until LocalPlayer.state.IsInSession
    repeat Wait(1000) until LocalPlayer.state?.Character?.CharId
    CHARID = LocalPlayer.state.Character.CharId

    NUI_SERVICE.SHARED.SEND_LANG()

    if CONFIG.HOTBAR.ENABLE then
        RegisterCommand(CONFIG.HOTBAR.EDIT_COMMAND, function()
            if IS_INV_OPEN then return end
            SendNUIMessage({ action = "hotbarEditPos" })
            SetNuiFocus(true, true)
        end, false)
    end

    local IsControlJustReleased = IsControlJustReleased
    local IsControlPressed      = IsControlPressed
    local IsPedHogtied          = IsPedHogtied
    local IsPedCuffed           = IsPedCuffed

    while true do
        local sleep = 1000
        if not CACHE.IsDead then
            sleep = 0
            local openPressed = false
            if KB_ON then
                openPressed, wantOpenInv = wantOpenInv, false
            else
                openPressed = IsControlJustReleased(1, CONFIG.OPEN_INVENTORY_KEY)
            end
            if openPressed then
                local player          = CACHE.Ped
                local hogtied <const> = IsPedHogtied(player) == 1
                local cuffed <const>  = IsPedCuffed(player)
                -- no inventory before a character is chosen (selection / creator)
                if not hogtied and not cuffed and not INVENTORY_DISABLED and LocalPlayer.state.IsInSession then
                    if CONFIG.WALK_WHILE_INV_OPEN then
                        if IsControlPressed(1, `INPUT_MOVE_UP_ONLY`) == 1 and not isWalking then
                            isWalking = true
                            local mount <const> = CACHE.Mount
                            local vehicle <const> = CACHE.Vehicle
                            player = mount > 0 and mount or vehicle > 0 and vehicle or player
                            local _isWalking <const> = IsPedWalking(player)
                            local isRunning <const> = IsPedRunning(player)
                            local isSprinting <const> = IsPedSprinting(player)
                            local speed <const> = _isWalking and 1.0 or isRunning and 2.0 or isSprinting and 3.0 or 0.0
                            local heading <const> = GetEntityHeading(player)
                            CreateThread(function()
                                repeat Wait(0) until IsNuiFocused()
                                SimulatePlayerInputGait(PlayerId(), speed, -1, heading, false, false)
                                repeat Wait(0) until not IsNuiFocused()
                                isWalking = false
                                if GetMount(player) > 0 or IsPedInAnyVehicle(player, false) then
                                    ResetPlayerInputGait(PlayerId()) -- needs to reset on vehcicles or mount or only works for the first time for walking no need pressing the W key will reset it it seems
                                end
                            end)
                        end
                    end
                    NUI_SERVICE.INVENTORY.OPEN()
                end
            end
        end

        if IS_INV_OPEN and CACHE.IsDead then
            NUI_SERVICE.INVENTORY.CLOSE()
        end

        if IS_INV_OPEN then
            if not controlVar then
                controlVar = true
                LocalPlayer.state:set("IsInvActive", true, true) -- can also listen for statebag change
                TriggerEvent("vorp_inventory:Client:OnInvStateChange", true)
            end
        else
            if controlVar then
                controlVar = false
                LocalPlayer.state:set("IsInvActive", false, true)
                TriggerEvent("vorp_inventory:Client:OnInvStateChange", false)
            end
        end

        Wait(sleep)
    end
end)


LAST_CLIENT_WEAPON_STATUS = LAST_CLIENT_WEAPON_STATUS or {}
if CONFIG.USE_WEAPON_DEGRADATION then
    CreateThread(function()
        repeat Wait(5000) until LocalPlayer.state.IsInSession
        local updateTimer = 10000 -- only updates if weapons are equipped and the values are changing

        local function weaponWearPayload(weapon)
            local weaponStatus <const> = weapon:getStatus()
            if weaponStatus and next(weaponStatus) then
                return {
                    degradation = weaponStatus.degradation,
                    damage = weaponStatus.damage,
                    dirt = weaponStatus.dirt,
                    soot = weaponStatus.soot,
                }
            end
            return { degradation = weapon.degradation, damage = weapon.damage, dirt = weapon.dirt, soot = weapon.soot }
        end

        while true do
            if not CACHE.IsDead then
                local batch = {}
                for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
                    if weapon.canDegrade then
                        local weaponId <const> = weapon:getId()
                        if weapon:getUsed() or weapon:getUsed2() then
                            local payload <const> = weaponWearPayload(weapon)
                            local encoded <const> = json.encode(payload)
                            if LAST_CLIENT_WEAPON_STATUS[weaponId] ~= encoded then
                                LAST_CLIENT_WEAPON_STATUS[weaponId] = encoded
                                batch[weaponId] = payload
                            end
                        else
                            LAST_CLIENT_WEAPON_STATUS[weaponId] = nil
                        end
                    end
                end

                if next(batch) then
                    -- send as a batch because of spam
                    TriggerServerEvent("vorpinventory:saveWeaponStatus", batch)
                end
            end
            Wait(updateTimer)
        end
    end)

    -- cant fire weapons that are degraded and damaged
    if CONFIG.DISABLE_WEAPON_FIRE_WHEN_DEGRADED then
        CreateThread(function()
            repeat Wait(5000) until LocalPlayer.state.IsInSession
            local DisablePlayerFiring = DisablePlayerFiring
            local IsDisabledControlJustPressed = IsDisabledControlJustPressed
            local IsPedArmed = IsPedArmed
            local GetPedWeaponObject = GetPedWeaponObject
            local GetWeaponDegradation = GetWeaponDegradation

            while true do
                local sleep = 1000
                if not CACHE.IsDead and not IS_INV_OPEN then
                    local weaponHeld = CACHE.Weapon
                    if weaponHeld ~= `WEAPON_UNARMED` then
                        local isArmed = IsPedArmed(CACHE.Ped, 4) == 1
                        if isArmed then
                            local weaponObject <const> = GetPedWeaponObject(CACHE.Ped, true)
                            local degradation <const> = GetWeaponDegradation(weaponObject)

                            if degradation >= 1.0 then
                                sleep = 0
                                DisablePlayerFiring(CACHE.Player, true)

                                if IsDisabledControlJustPressed(0, `INPUT_ATTACK`) then
                                    CORE.NotifyRightTip(LANG.weaponDegradedCantUse, 5000)
                                end
                            end
                        end
                    end
                end
                Wait(sleep)
            end
        end)
    end
end


if CONFIG.DISABLE_HIP_FIRE then
    CreateThread(function()
        repeat Wait(5000) until LocalPlayer.state.IsInSession
        local DisablePlayerFiring = DisablePlayerFiring
        local IsPlayerFreeAiming = IsPlayerFreeAiming
        local IsPedArmed = IsPedArmed

        while true do
            local sleep = 500
            if not CACHE.IsDead and not IS_INV_OPEN then
                local weaponHeld <const> = CACHE.Weapon
                if weaponHeld ~= `WEAPON_UNARMED` then
                    sleep = 100
                    local isAiming <const> = IsPlayerFreeAiming(CACHE.Player)
                    local isArmed <const> = IsPedArmed(CACHE.Ped, 4) == 1
                    if not isAiming and isArmed then
                        sleep = 0
                        DisablePlayerFiring(CACHE.Player, true)
                    end
                end
            end
            Wait(sleep)
        end
    end)
end
