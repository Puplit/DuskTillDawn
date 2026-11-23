-- pup_hideouts | selling contraband to locals: the offer, haggling at the price picker, the sting

local S <const> = Config.Sales
local B <const> = Config.Bargain
local ST <const> = Config.Sting
local OWNER <const> = 'pup_hideouts'

local N <const> = {
    groupForEntity = 0xB796970BD125FCE8, -- PROMPT_GET_GROUP_ID_FOR_TARGET_ENTITY
    isHogtied = 0x3AA24CCC0D451379,      -- IS_PED_HOGTIED
    lasso = 0xC716EB2BD16370A3,          -- TASK_LASSO_PED
    hogtie = 0x27829AFD3E03AC1A,         -- TASK_HOGTIE_TARGET_PED
    fullyLooted = 0x8DE41E9902E85756,    -- _IS_ENTITY_FULLY_LOOTED
}

local LAWMEN = {}
for _, m in ipairs(Config.LawmanModels) do LAWMEN[joaat(m)] = true end

local offered = {}   -- [ped] = true for this session of play
local session = nil  -- { ped, startedAt, label, qty }
local lootPed = nil  -- { ped, untilMs }

local function bool(v) return v == true or v == 1 end

local function isLawman(ped) return LAWMEN[GetEntityModel(ped)] == true end

local function eligible(ped)
    if not DoesEntityExist(ped) or not IsEntityAPed(ped) or IsPedAPlayer(ped) then return false end
    if offered[ped] or IsEntityDead(ped) then return false end
    local me = PlayerPedId()
    if U.dist(GetEntityCoords(me), GetEntityCoords(ped)) > S.buyerRange then return false end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return false end
    if IsPedInMeleeCombat(ped) or IsPedInCombat(ped, me) then return false end
    if bool(Citizen.InvokeNative(N.isHogtied, ped)) then return false end
    return S.pedTypes[GetPedType(ped)] == true or isLawman(ped)
end

----------------------------------------------------------------------------------------------------
-- the "Sell Contraband" prompt lives on the targeted ped's own prompt group
----------------------------------------------------------------------------------------------------
local prompt, promptPed = nil, nil

local function dropPrompt()
    if prompt then PromptDelete(prompt) end
    prompt, promptPed = nil, nil
end

local function promptFor(ped)
    if promptPed == ped and prompt then return prompt end
    dropPrompt()
    local group = Citizen.InvokeNative(N.groupForEntity, ped)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, Config.Keys.interact)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', L('sell_contraband')))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    prompt, promptPed = p, ped
    return p
end

----------------------------------------------------------------------------------------------------
-- the buyer
----------------------------------------------------------------------------------------------------
local function hold(ped)
    SetEntityAsMissionEntity(ped, true, true)
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), 2000)
end

local function release(ped, wander)
    if not ped or not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    if wander and not IsEntityDead(ped) then TaskWanderStandard(ped, 10.0, 10) end
    SetEntityAsNoLongerNeeded(ped)
end

local function endSession(msgKey, wander)
    local s = session
    session = nil
    pcall(function() exports['pup-ui']:HidePricePicker() end)
    if msgKey then HX.tip(L(msgKey)) end
    if s and not s.stung then release(s.ped, wander ~= false) end
end

local function openPicker(caption, notch)
    local s = session
    if not s then return end
    exports['pup-ui']:OpenPricePicker({
        owner = OWNER, caption = caption, title = L('buyer_offering', s.label, s.qty),
        min = s.min, max = s.max, steps = s.steps, notch = notch, prefix = '$', foot = L('slider_foot'),
    })
end

local function trade()
    local s = session
    if not s then return end
    local ped = PlayerPedId()
    local a = Config.Anims.trade
    if HX.loadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, B.handoffMs, 0, 0, false, false, false) end
    HX.progress(L('making_trade'), B.handoffMs)
    Wait(B.handoffMs)
    if session ~= s then return end
    local ok = HX.call('saleHandover', 5000)
    if not ok then HX.tip(L('no_answer')) end
    if session == s then endSession(nil, true) end
end

local function offer(ped)
    if session or HX.busy then return end
    offered[ped] = true
    dropPrompt()
    hold(ped)
    Wait(1200)
    local me = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) or U.dist(GetEntityCoords(me), GetEntityCoords(ped)) > S.buyerRange + 0.5 then
        release(ped, true)
        return HX.tip(L('too_far_sale'))
    end
    TaskStandStill(ped, S.sessionClientSeconds * 1000)
    local net = NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or 0
    session = { ped = ped, startedAt = GetGameTimer() }
    local ok, res = HX.call('saleOffer', S.firstScreenMs, isLawman(ped), net)
    if session == nil or session.ped ~= ped then return end
    if not ok or type(res) ~= 'table' then
        -- a late answer may still have opened a haggle (and armed a sting) on the server
        HX.send('saleQuit')
        return endSession('lost_interest')
    end
    if res.kind == 'refused' then
        HX.tip(L('dont_buy'))
        return endSession(nil, true)
    end
    if res.kind == 'instant' then return endSession(nil, true) end
    if res.kind == 'sting' then return end -- stingFire takes it from here
    if res.kind ~= 'haggle' then return endSession(nil, true) end
    session.label, session.qty = tostring(res.label or '?'), tonumber(res.qty) or 1
    session.min, session.max, session.steps = tonumber(res.min) or 0, tonumber(res.max) or 0, tonumber(res.steps) or B.notches
    openPicker(L('opening_line', U.money(res.offer or 0)), tonumber(res.notch) or 0)
end

AddEventHandler('pup-ui:client:priceConfirm', function(notch, owner)
    if owner ~= OWNER or not session then return end
    local s = session
    CreateThread(function()
        local ok, res = HX.call('saleAsk', 4000, notch)
        if session ~= s then return end
        if not ok or type(res) ~= 'table' then return endSession('lost_interest') end
        if res.kind == 'accept' then return trade() end
        if res.kind == 'counter' then return openPicker(L('counter_line', U.money(res.offer or 0)), tonumber(res.notch) or 0) end
        if res.kind == 'walk' then return endSession('walk_off') end
        endSession('lost_interest')
    end)
end)

AddEventHandler('pup-ui:client:priceCancel', function(owner)
    if owner ~= OWNER or not session then return end
    HX.send('saleQuit')
    endSession(nil, true)
end)

----------------------------------------------------------------------------------------------------
-- the sting
----------------------------------------------------------------------------------------------------
local function lassoAndTie(lawman)
    local me = PlayerPedId()
    if U.dist(GetEntityCoords(me), GetEntityCoords(lawman)) > ST.ropeRange then
        HX.tip(L('clear_of_him'))
        return release(lawman, true)
    end
    GiveWeaponToPed(lawman, joaat(Config.Lasso), 1, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    Citizen.InvokeNative(N.lasso, lawman, me)
    local t = GetGameTimer() + 4000
    while GetGameTimer() < t and not bool(Citizen.InvokeNative(N.isHogtied, me)) do Wait(250) end
    if not bool(Citizen.InvokeNative(N.isHogtied, me)) then
        if U.dist(GetEntityCoords(me), GetEntityCoords(lawman)) <= ST.tieRange then
            Citizen.InvokeNative(N.hogtie, lawman, me) -- tied by hand after a missed rope
            Wait(3000)
        else
            HX.tip(L('clear_of_him'))
            return release(lawman, true)
        end
    end
    -- struggle out of the ropes
    Wait(ST.struggleSeconds * 1000)
    me = PlayerPedId()
    if bool(Citizen.InvokeNative(N.isHogtied, me)) then ClearPedTasksImmediately(me) end
    release(lawman, true)
end

local function crookedDrink(lawman)
    local a = Config.Anims.crooked
    ClearPedTasks(lawman)
    if HX.loadDict(a.dict) then TaskPlayAnim(lawman, a.dict, a.name, 8.0, -8.0, 12000, 1, 0, false, false, false) end
    Wait(12000)
    release(lawman, true)
end

RegisterNetEvent('pup_hideouts:stingFire', function(kind, line)
    local s = session
    pcall(function() exports['pup-ui']:HidePricePicker() end)
    HX.progressCancel()
    session = nil
    local lawman = s and s.ped
    if kind == 'crooked' then
        HX.tip(type(line) == 'string' and line or L('crooked_default'))
    else
        HX.tip(kind == 'lawman' and L('offered_law') or L('undercover'))
        if type(line) == 'string' then HX.bottom(line) end
    end
    if not lawman or not DoesEntityExist(lawman) then return end
    lootPed = { ped = lawman, untilMs = GetGameTimer() + ST.lootMinutes * 60000 }
    CreateThread(function()
        Wait(ST.ropeDelayMs)
        if kind == 'crooked' then crookedDrink(lawman) else lassoAndTie(lawman) end
    end)
end)

----------------------------------------------------------------------------------------------------
-- loops: the target scan (idle 400 ms), the session watch, the loot-back watch
----------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 400
        if S.enabled and not HX.insideId and not session and not HX.busy and not HX.menuOpen then
            local player = PlayerId()
            local hit, target = GetPlayerTargetEntity(player)
            if not hit or not target or target == 0 then hit, target = GetEntityPlayerIsFreeAimingAt(player) end
            if hit and target and target ~= 0 and eligible(target) then
                sleep = 0
                local p = promptFor(target)
                if PromptHasStandardModeCompleted(p) then
                    local ped = target
                    CreateThread(function() offer(ped) end)
                end
            elseif prompt then
                dropPrompt()
            end
        elseif prompt then
            dropPrompt()
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        local s = session
        if s and s.label then
            local me = PlayerPedId()
            if not DoesEntityExist(s.ped) or IsEntityDead(s.ped)
                or U.dist(GetEntityCoords(me), GetEntityCoords(s.ped)) > S.sessionRange
                or GetGameTimer() - s.startedAt > S.sessionClientSeconds * 1000 then
                HX.send('saleQuit')
                endSession('lost_interest')
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local lp = lootPed
        if lp then
            if GetGameTimer() > lp.untilMs or not DoesEntityExist(lp.ped) then
                lootPed = nil
            elseif IsEntityDead(lp.ped) and bool(Citizen.InvokeNative(N.fullyLooted, lp.ped)) then
                lootPed = nil
                HX.send('stingLooted')
            end
        end
    end
end)

AddEventHandler('vorp:SelectedCharacter', function() offered = {} end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    dropPrompt()
    if session then
        pcall(function() exports['pup-ui']:HidePricePicker() end)
        release(session.ped, true)
    end
end)
