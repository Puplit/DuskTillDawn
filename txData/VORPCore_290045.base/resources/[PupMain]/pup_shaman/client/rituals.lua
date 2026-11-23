-- pup_shaman | rituals on the client: menus, the scene around the fire, the chant
-- The server decides everything; this file only shows it and sends presses.

Rituals = {}

local OWNER_MENU <const> = 'pup_shaman:ritual'
local OWNER_ASK <const> = 'pup_shaman:ask'

local R <const> = Config.Ritual
local LOOK <const> = Config.Ritual.look

local scenes = {}          -- id -> scene from the server, plus local bits (fire, joinable)
local menuChoices = nil    -- choices of the open "Old Ways" menu
local askId = nil          -- session we are being asked to join (ask menu open)
local praying = false
local lastPress = 0
local rendering = false
local promptShown = false

local function myId()
    return GetPlayerServerId(PlayerId())
end

local function roleIn(sc)
    local me = myId()
    if sc.leader == me then return 'leader' end
    if sc.target == me then return 'target' end
    for _, h in ipairs(sc.helpers or {}) do
        if h == me then return 'helper' end
    end
    return nil
end

--- Taking part in a ritual (or answering one): tree prompts stay away.
function Rituals.Participating()
    if askId or menuChoices then return true end
    for _, sc in pairs(scenes) do
        if roleIn(sc) then return true end
    end
    return false
end

-- praying --------------------------------------------------------------------------------

local function stopPraying()
    if not praying then return end
    praying = false
    StopAnimTask(PlayerPedId(), LOOK.pray.dict, LOOK.pray.clip, 1.0)
end

local function startPraying()
    if praying then return end
    praying = true
    CreateThread(function()
        while praying do
            local ped = PlayerPedId()
            -- a prayer knocked loose is picked up again once the player stands still
            if not IsEntityPlayingAnim(ped, LOOK.pray.dict, LOOK.pray.clip, 3)
                and GetEntitySpeed(ped) < 0.2 and not IsPedRagdoll(ped) and not Shaman.IsDead(ped) then
                Shaman.PlayAnim(ped, LOOK.pray.dict, LOOK.pray.clip, -1, 1)
            end
            Wait(1000)
        end
    end)
end

-- fire ---------------------------------------------------------------------------------------

local function removeFire(sc)
    if sc.fire and DoesEntityExist(sc.fire) then DeleteObject(sc.fire) end
    sc.fire = nil
end

local function ensureFire(sc)
    if sc.fire or sc.fireLoading then return end
    sc.fireLoading = true
    CreateThread(function()
        local hash = Shaman.LoadModel(LOOK.fire.model, 5000)
        sc.fireLoading = false
        if not hash or scenes[sc.id] ~= sc or sc.fire then return end
        local c = sc.center
        local obj = CreateObject(hash, c.x, c.y, c.z - LOOK.fire.below, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, true)
            SetEntityCollision(obj, false, false)
            sc.fire = obj
        end
    end)
end

local FIRE_STAGES <const> = { circle = true, chant = true, draw = true }
local MARK_STAGES <const> = { circle = true, chant = true }

local function drawMarks(sc)
    local m = LOOK.marker
    for i, mark in ipairs(sc.marks or {}) do
        local walked = i <= (sc.walked or 0)
        local col = walked and LOOK.walked or LOOK.unwalked
        local alpha = (i == (sc.walked or 0) + 1) and LOOK.alphaNext or LOOK.alphaOther
        -- DRAW_MARKER
        Citizen.InvokeNative(0x2A32FAA57B937173, m.type, mark.x, mark.y, mark.z - m.below,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.size.x, m.size.y, m.size.z,
            col[1], col[2], col[3], alpha, false, false, 2, false, nil, nil, false)
    end
end

local function drawLight(sc)
    local l = LOOK.light
    local c = sc.center
    local range, intensity = l.range, l.intensity + math.random() * l.flicker
    if sc.stage == 'draw' then range, intensity = l.drawRange, l.drawIntensity end
    -- DRAW_LIGHT_WITH_RANGE
    Citizen.InvokeNative(0xD2D9E04C0DF927F4, c.x, c.y, c.z - l.below, l.color[1], l.color[2], l.color[3], range, intensity)
end

local function showPrompt(label)
    exports['pup-ui']:Prompt({ key = Config.ActionKeyLabel, label = label })
    promptShown = true
end

local function render()
    if rendering then return end
    rendering = true
    CreateThread(function()
        while next(scenes) do
            local sleep = 500
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local wantPrompt = false
            for id, sc in pairs(scenes) do
                local d = #(pos - sc.center)
                local role = roleIn(sc)
                if FIRE_STAGES[sc.stage] and d <= R.viewRange then
                    sleep = 0
                    ensureFire(sc)
                    drawLight(sc)
                    if MARK_STAGES[sc.stage] then drawMarks(sc) end
                    -- the leader marks the ground at the next mark
                    if sc.stage == 'circle' and role == 'leader' and not Shaman.busy then
                        local idx = (sc.walked or 0) + 1
                        local mark = sc.marks and sc.marks[idx]
                        if mark and Rules.Flat(pos, mark) <= R.markReach then
                            wantPrompt = true
                            showPrompt(L('rit_mark'))
                            local now = GetGameTimer()
                            if IsControlJustPressed(0, Config.ActionKey) and now - lastPress >= R.markResendMs then
                                lastPress = now
                                TaskStartScenarioInPlace(ped, joaat(LOOK.crouch), LOOK.markCrouchMs, true, false, false, false)
                                TriggerServerEvent('pup_shaman:server:ritualMark', id, idx)
                            end
                        end
                    end
                elseif sc.fire and not FIRE_STAGES[sc.stage] then
                    removeFire(sc)
                end
                -- bystanders with a rank may join while the fire is being laid and the circle walked
                if sc.joinable and not role and (sc.stage == 'kindle' or sc.stage == 'circle') and d <= R.stayRange
                    and not Shaman.busy and not Shaman.form and not Shaman.dream then
                    sleep = 0
                    wantPrompt = true
                    showPrompt(L('rit_join'))
                    local now = GetGameTimer()
                    if IsControlJustPressed(0, Config.ActionKey) and now - lastPress >= R.markResendMs then
                        lastPress = now
                        TriggerServerEvent('pup_shaman:server:ritualJoin', id)
                    end
                end
            end
            if promptShown and not wantPrompt then
                exports['pup-ui']:PromptHide()
                promptShown = false
            end
            Wait(sleep)
        end
        if promptShown then
            exports['pup-ui']:PromptHide()
            promptShown = false
        end
        rendering = false
    end)
end

-- stage changes, as each client sees them ----------------------------------------------------------

local function onStage(sc, prevStage)
    local role = roleIn(sc)
    local ped = PlayerPedId()
    if sc.stage == prevStage then
        -- a helper who just joined during the chant starts praying
        if sc.stage == 'chant' and role then startPraying() end
        return
    end
    if sc.stage == 'kindle' then
        if role == 'leader' then
            TaskStartScenarioInPlace(ped, joaat(LOOK.crouch), R.kindleSeconds * 1000, true, false, false, false)
        elseif role == 'target' then
            startPraying()
        end
    elseif sc.stage == 'chant' then
        if role then
            if role == 'leader' then ClearPedTasks(ped) end
            startPraying()
        end
    elseif sc.stage == 'draw' then
        if role == 'target' then Shaman.FxPlay(LOOK.drawEffect) end
    end
end

RegisterNetEvent('pup_shaman:client:ritualScene', function(scene)
    if type(scene) ~= 'table' or not scene.id or type(scene.center) ~= 'vector3' then return end
    local old = scenes[scene.id]
    if old then
        scene.fire, scene.joinable = old.fire, old.joinable
    end
    scenes[scene.id] = scene
    onStage(scene, old and old.stage or nil)
    render()
end)

RegisterNetEvent('pup_shaman:client:ritualJoinable', function(id, joinable)
    local sc = scenes[id]
    if sc then sc.joinable = joinable == true end
end)

RegisterNetEvent('pup_shaman:client:ritualVerse', function(_, title, line)
    exports['pup-ui']:Toast({ title = tostring(title or ''), subtitle = tostring(line or ''), symbol = LOOK.toast.symbol, duration = LOOK.toast.ms })
end)

RegisterNetEvent('pup_shaman:client:ritualBar', function(id, token, width, perfect, speed)
    local answered = false
    local function answer(result)
        if answered then return end
        answered = true
        TriggerServerEvent('pup_shaman:server:ritualVerseResult', id, token, result)
    end
    if GetResourceState('pup-minigames') ~= 'started' then return answer('failed') end
    local bar = LOOK.bar
    local ok = pcall(function()
        exports['pup-minigames']:skill_bar({
            style = bar.style, icon = bar.icon, orientation = bar.orientation, scale = bar.scale,
            area_size = tonumber(width) or 20, perfect_area_size = tonumber(perfect) or 6, speed = tonumber(speed) or 0.3,
            moving_icon = bar.movingIcon,
        }, function(result) answer(result) end)
    end)
    if not ok then answer('failed') end
end)

RegisterNetEvent('pup_shaman:client:ritualEnd', function(id, outcome)
    if askId == id then
        askId = nil
        exports['pup-ui']:HideInkMenu()
    end
    local sc = scenes[id]
    if not sc then return end
    scenes[id] = nil
    local role = roleIn(sc)
    local c = sc.center
    if outcome == 'lifted' or outcome == 'given' then
        Citizen.InvokeNative(0x67943537D179597C, c.x, c.y, c.z, -1.0) -- FORCE_LIGHTNING_FLASH_AT_COORDS
        if role then
            PlaySoundFrontend(LOOK.chime.name, LOOK.chime.set, true, 0)
            Shaman.FxPlay(LOOK.successEffect)
        end
    elseif outcome == 'eased' and role then
        Shaman.FxPlay(LOOK.successEffect)
    end
    if role then stopPraying() end
    if role == 'target' then Shaman.FxStop(LOOK.drawEffect) end
    removeFire(sc)
    SetTimeout(3000, function() Shaman.FxStop(LOOK.successEffect) end)
end)

RegisterNetEvent('pup_shaman:client:ritualBacklash', function()
    local b = R.backlash
    local ped = PlayerPedId()
    if Shaman.IsDead(ped) then return end
    local health = GetEntityHealth(ped)
    local after = health - math.floor(GetEntityMaxHealth(ped) * b.share)
    -- never below the floor, and never raised to it
    after = math.max(after, math.min(health, b.floor))
    if after < health then SetEntityHealth(ped, after) end
    SetPedToRagdoll(ped, b.ragdollMs, b.ragdollMs, 0, false, false, false)
    Shaman.FxPlay(LOOK.drawEffect)
    SetTimeout(b.effectMs, function() Shaman.FxStop(LOOK.drawEffect) end)
end)

-- menus -----------------------------------------------------------------------------------------------

RegisterNetEvent('pup_shaman:client:ritualMenu', function(title, subtitle, options)
    if type(options) ~= 'table' then return end
    local rows, choices = {}, {}
    for i, o in ipairs(options) do
        rows[i] = { label = tostring(o.label or ''), description = o.description and tostring(o.description) or nil }
        choices[i] = o.choice
    end
    menuChoices = choices
    exports['pup-ui']:OpenInkMenu({ owner = OWNER_MENU, title = tostring(title or ''), subtitle = subtitle, options = rows })
end)

RegisterNetEvent('pup_shaman:client:ritualAsk', function(id, title, text)
    askId = id
    menuChoices = nil -- the ask replaces any Old Ways menu we had open
    exports['pup-ui']:OpenInkMenu({
        owner = OWNER_ASK,
        title = tostring(title or ''),
        subtitle = tostring(text or ''),
        options = { { label = L('rit_accept') }, { label = L('rit_refuse') } },
    })
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner == OWNER_MENU and menuChoices then
        local choice = menuChoices[index]
        menuChoices = nil
        exports['pup-ui']:HideInkMenu()
        if choice then TriggerServerEvent('pup_shaman:server:ritualChoose', choice) end
    elseif owner == OWNER_ASK and askId then
        local id = askId
        askId = nil
        exports['pup-ui']:HideInkMenu()
        TriggerServerEvent('pup_shaman:server:ritualAnswer', id, index == 1)
    elseif owner ~= OWNER_MENU and owner ~= OWNER_ASK then
        -- pup-ui has one active menu: an event for another owner means ours were replaced.
        -- A replaced ask menu is left to the server's answer timeout.
        menuChoices, askId = nil, nil
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner == OWNER_MENU then
        menuChoices = nil
    elseif owner == OWNER_ASK and askId then
        -- closing counts as refusing
        local id = askId
        askId = nil
        TriggerServerEvent('pup_shaman:server:ritualAnswer', id, false)
    elseif owner ~= OWNER_MENU and owner ~= OWNER_ASK then
        menuChoices, askId = nil, nil
    end
end)

-- cleanup -----------------------------------------------------------------------------------------------

local function clearAll()
    if menuChoices or askId then exports['pup-ui']:HideInkMenu() end
    menuChoices, askId = nil, nil
    stopPraying()
    Shaman.FxStop(LOOK.drawEffect)
    Shaman.FxStop(LOOK.successEffect)
    for id, sc in pairs(scenes) do
        removeFire(sc)
        scenes[id] = nil
    end
    if promptShown then exports['pup-ui']:PromptHide() end
end

Shaman.OnReset(clearAll)
Shaman.OnStop(clearAll)
