-- pup_camps | functional furniture at the player's own camp: storage, beer box, water
-- barrel, wardrobe, stable, stew pot, trapper; and "calling mode" for wagons

Functional = {}
Calling = {}

local REACH <const> = { inv = 2.0, beerbox = 1.0, waterbarrel = 0.8, changing = 2.0, stable = 2.0, stew = 2.0, hunting = 2.0 }
local stashOpenFor = nil   -- campId while the clan panel is open

------------------------------------------------------------------------------ storage

function Functional.openStash(id)
    if stashOpenFor then return end
    local ok = Ask('stashOpen', id)
    if ok then stashOpenFor = id end
end

-- staff opened a camp stash from vorp_admin: remember it so the close is reported
RegisterNetEvent('pup_camps:cl:staffStash', function(id)
    stashOpenFor = tonumber(id)
end)

-- vorp_inventory fires this when its panel closes
AddEventHandler('pup:closeinv', function()
    if not stashOpenFor then return end
    stashOpenFor = nil
    CreateThread(function() Request('stashClosed') end)
end)

------------------------------------------------------------------------------ beer box

local drinks = 0
local drunkUntil = 0
local drunkLevel = 0

local function setDrunk(level)
    local ped = PlayerPedId()
    if level <= 0 then
        if drunkLevel > 0 then
            AnimpostfxStop(Config.Effects.drunkLight)
            AnimpostfxStop(Config.Effects.drunkStrong)
            AnimpostfxStop(Config.Effects.hallucinate)
            N(0x406CCF555B04FAD3, ped, false, 0.0)
        end
        drunkLevel = 0
        return
    end
    drunkLevel = level
    local fx = level >= 1.0 and Config.Effects.hallucinate or (level >= 0.75 and Config.Effects.drunkStrong or Config.Effects.drunkLight)
    AnimpostfxPlay(fx)
    N(0x406CCF555B04FAD3, ped, true, level + 0.0)
end

local decayRunning = false
local function startDecay()
    if decayRunning then return end
    decayRunning = true
    CreateThread(function()
        local nextDrop = GetGameTimer() + Config.Beer.decayMin * 60000
        while drinks > 0 or drunkLevel > 0 do
            Wait(1000)
            local now = GetGameTimer()
            if now >= nextDrop and drinks > 0 then
                drinks = drinks - 1
                nextDrop = now + Config.Beer.decayMin * 60000
            end
            if drunkLevel > 0 and (now >= drunkUntil or drinks <= 0) then setDrunk(0) end
        end
        decayRunning = false
    end)
end

local function grabBeer(piece)
    FaceEntity(World.object(piece.campId, piece.id))
    Scenario(Config.Anim.drink, 4000)
    Wait(4000)
    StopScenario()
    local ped = PlayerPedId()
    local bottle = nil
    local model = LoadModel(Config.Anim.bottleProp)
    if model then
        local c = GetEntityCoords(ped)
        bottle = CreateObject(model, c.x, c.y, c.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
        if bottle and bottle ~= 0 then
            AttachEntityToEntity(bottle, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Hand'), 0.08, -0.04, -0.05, -75.0, 0.0, 0.0, true, true, false, true, 1, true)
        end
    end
    Wait(5000)
    if bottle and DoesEntityExist(bottle) then DeleteObject(bottle) end
    drinks = drinks + 1
    local s = Config.Beer.stats
    Integrations.consume(s.hunger, s.thirst, s.metabolism, s.cores)
    local level = nil
    if drinks > Config.Beer.hallucinateAbove then level = 1.0
    elseif drinks == Config.Beer.strongAt then level = 0.75
    elseif drinks == Config.Beer.drunkAt then level = 0.5 end
    if level then
        setDrunk(0)
        setDrunk(level)
        drunkUntil = GetGameTimer() + Config.Beer.durationMin * 60000
    end
    startDecay()
end

------------------------------------------------------------------------------ water barrel

local function washFace(piece)
    FaceEntity(World.object(piece.campId, piece.id))
    local ped = PlayerPedId()
    local anim = IsPedMale(ped) and Config.Anim.washMale or Config.Anim.washFemale
    if LoadDict(anim[1]) then
        TaskPlayAnim(ped, anim[1], anim[2], 4.0, -4.0, 2000, 0, 0.0, false, false, false)
    end
    Wait(2000)
    ClearPedTasks(ped)
    N(0x8FE22675A5A45817, ped)          -- blood
    N(0x6585D955A68452A5, ped)          -- dirt
    N(0x523C79AEEFCC4A2A, ped, 10, 'ALL') -- damage decals
    drinks = 0
    setDrunk(0)
    TriggerEvent('pup_camps:washedface')
end

------------------------------------------------------------------------------ wardrobe

local SKIRT <const> = 'Skirt'
local PANTS_TAG <const> = 0x1D4C528A

local function applyOutfit(comps)
    local ok, t = pcall(json.decode, comps)
    if not ok or type(t) ~= 'table' then return end
    local ped = PlayerPedId()
    for category, value in pairs(t) do
        local hash = type(value) == 'table' and tonumber(value.comp) or tonumber(value)
        if hash and hash ~= 0 and hash ~= -1 then
            N(0xD3A7B003ED343FD9, ped, U.signed(hash), false, true, true)
            if category == SKIRT then N(0xD710A5007C2AC539, ped, PANTS_TAG, 0) end
        end
    end
    N(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    TriggerEvent('vorpcharacter:savenew', t)
end

local function wardrobe()
    local list = Request('outfits')
    if type(list) ~= 'table' then return end
    if #list == 0 then return Notify(L('wardrobe_none')) end
    local rows = {}
    for _, o in ipairs(list) do
        rows[#rows + 1] = { label = o.title, description = L('wardrobe_wear'), onSelect = function()
            Menu.closeAll()
            local ped = PlayerPedId()
            local anim = IsPedMale(ped) and Config.Anim.washMale or Config.Anim.washFemale
            if LoadDict(anim[1]) then TaskPlayAnim(ped, anim[1], anim[2], 4.0, -4.0, 2500, 0, 0.0, false, false, false) end
            Wait(2500)
            local comps = Ask('outfitWear', o.id)
            if type(comps) == 'string' then applyOutfit(comps) end
        end }
    end
    if Menu.begin({ noFreeze = true }) then Menu.push({ title = L('wardrobe'), rows = rows }) end
end

------------------------------------------------------------------------------ calling mode (hunting wagon and deliveries)

local calling = nil

-- onCall(pos, heading) runs when the player presses Call within reach of the camp
function Calling.start(campId, onCall)
    if calling then return end
    local me = { campId = campId }
    calling = me
    CreateThread(function()
        while calling == me do
            local v = State.camps[campId]
            if not v then break end
            local pos = PedPos()
            DrawHint(L('calling_hint'), 0.90)
            if U.dist3(pos, v.coords) <= Config.Camp.renderDistance then
                if UiRunning() then exports['pup-ui']:Prompt({ key = 'G', label = L('wagon_title') .. ': ' .. L('call') }) end
                if IsControlJustReleased(0, Config.Keys.interact) then
                    calling = nil
                    pcall(function() exports['pup-ui']:PromptHide() end)
                    local ped = PlayerPedId()
                    onCall(GetOffsetFromEntityInWorldCoords(ped, 3.0, 2.0, 0.0), GetEntityHeading(ped))
                    break
                end
            else
                DrawHint(L('furni_out_of_area'), 0.86)
            end
            if IsControlJustPressed(0, Config.Keys.cancel) or IsDisabledControlJustPressed(0, Config.Keys.cancel) then
                calling = nil
                Notify(L('calling_stopped'))
                break
            end
            if IsDeadOrDying() then calling = nil break end
            Wait(0)
        end
        if calling == me then calling = nil end
    end)
end

function Calling.active() return calling ~= nil end

local huntingWagon = nil

local function callHuntingWagon(campId, pos, heading)
    if not Ask('wagonPermit', campId, 'hunting') then return end
    if huntingWagon and DoesEntityExist(huntingWagon) then DeleteEnt(huntingWagon) end
    huntingWagon = nil
    local model = LoadModel(Config.HuntingWagon.model)
    if not model then return end
    FadeOut(500)
    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, heading, true, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if veh and veh ~= 0 then
        huntingWagon = veh
        SetVehicleOnGroundProperly(veh)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        local list = Request('hwList')
        local n = type(list) == 'table' and (list.count or 0) or 0
        Hunting.dressWagon(veh, n)
    end
    FadeIn(500)
end

------------------------------------------------------------------------------ stable

local function stableMenu(campId)
    local horses = {}
    local okH, h = pcall(Integrations.horses)
    if okH and type(h) == 'table' then horses = h end
    local wagons = {}
    local okW, w = pcall(Integrations.wagons)
    if okW and type(w) == 'table' then wagons = w end

    local active = nil
    for _, horse in ipairs(horses) do if horse.active then active = horse end end
    local rows = {}
    for _, horse in ipairs(horses) do
        local state = horse.dead and L('horse_dead') or (horse.active and L('horse_active') or L('horse_inactive'))
        rows[#rows + 1] = { label = tostring(horse.name or '?'), description = state, onSelect = function()
            local sub = {}
            if not horse.dead then
                sub[#sub + 1] = { label = L('bring_horse'), onSelect = function()
                    local ped = PlayerPedId()
                    local c = GetOffsetFromEntityInWorldCoords(ped, 2.0, 0.0, 0.0)
                    if Integrations.spawnHorse(horse.id, { x = c.x, y = c.y, z = c.z }, GetEntityHeading(ped)) then Notify(L('brought_out')) end
                    Menu.closeAll()
                end }
            end
            sub[#sub + 1] = { label = L('select_active'), description = L('select_active_desc'), onSelect = function()
                if horse.active then return Notify(L('horse_already_active')) end
                Integrations.selectFavourite(horse.id)
                Notify(L('horse_selected', tostring(horse.name or '?')))
                Menu.closeAll()
            end }
            sub[#sub + 1] = { label = L('change_name_row'), onSelect = function()
                local name = Menu.text(L('change_name_row'), L('name_field'), horse.name, 30)
                if not name or name == '' then return Notify(L('webhook_invalid')) end
                Integrations.renameHorse(horse.id, name)
                Menu.closeAll()
            end }
            Menu.push({ title = tostring(horse.name or '?'), subtitle = state, rows = sub })
        end }
    end
    if #horses == 0 then rows[#rows + 1] = { label = L('no_horses'), disabled = true } end

    rows[#rows + 1] = { label = L('owned_wagons'), description = L('owned_wagons_desc'), onSelect = function()
        local wr = {}
        for _, wagon in ipairs(wagons) do
            wr[#wr + 1] = { label = tostring(wagon.name or '?'), description = tostring(wagon.model or ''), onSelect = function()
                Menu.push({ title = tostring(wagon.name or '?'), rows = {
                    { label = L('bring_wagon'), onSelect = function()
                        local ped = PlayerPedId()
                        local c = GetOffsetFromEntityInWorldCoords(ped, 4.0, 2.0, 0.0)
                        if Integrations.spawnWagon(wagon.id, { x = c.x, y = c.y, z = c.z }, GetEntityHeading(ped)) then Notify(L('brought_out')) end
                        Menu.closeAll()
                    end },
                    { label = L('change_name_row'), onSelect = function()
                        local name = Menu.text(L('change_name_row'), L('name_field'), wagon.name, 30)
                        if not name or name == '' then return Notify(L('webhook_invalid')) end
                        Integrations.renameWagon(wagon.id, name)
                        Menu.closeAll()
                    end },
                } })
            end }
        end
        if #wr == 0 then wr[1] = { label = L('no_wagons'), disabled = true } end
        Menu.push({ title = L('owned_wagons'), rows = wr })
    end }

    local v = State.camps[campId]
    if Config.HuntingWagon.enabled and v and v.hwagon ~= 1 and CanDo(v, 'buyWagon') then
        rows[#rows + 1] = { label = L('buy_hwagon'), description = L('price', U.money(Config.HuntingWagon.price)), onSelect = function()
            if Ask('buyWagon', campId) then Menu.closeAll() end
        end }
    end
    if Config.HuntingWagon.enabled and v and v.hwagon == 1 then
        rows[#rows + 1] = { label = L('call_wagon'), description = L('call_wagon_desc'), onSelect = function()
            Menu.closeAll()
            Calling.start(campId, function(pos, heading) callHuntingWagon(campId, pos, heading) end)
        end }
    end
    local subtitle = active and L('saddled', tostring(active.name)) or L('no_horse_picked')
    if Menu.begin({ noFreeze = true }) then Menu.push({ title = L('stable'), subtitle = subtitle, rows = rows }) end
end

------------------------------------------------------------------------------ stew pot

local function stewMenu(campId)
    if not CampMenu.takeLock(campId) then return end
    if not Menu.begin({ campId = campId, onClose = function() Request('unlock', campId) end }) then
        Request('unlock', campId)
        return
    end
    local v = State.camps[campId]
    local level = v and tonumber(v.stewlevel) or 0
    local rows = {}
    local recipe = Config.Stews[level]
    if recipe then
        rows[1] = { label = L('stew_eat', recipe.name), onSelect = function()
            local res = Ask('stewEat', campId)
            Menu.closeAll()
            -- only a confirmed full pot feeds the player
            if type(res) ~= 'table' then return end
            local ped = PlayerPedId()
            local bowl = LoadModel(Config.Anim.bowlProp)
            local spoon = LoadModel(Config.Anim.spoonProp)
            local c = GetEntityCoords(ped)
            local b = bowl and CreateObject(bowl, c.x, c.y, c.z, false, false, false) or nil
            local s = spoon and CreateObject(spoon, c.x, c.y, c.z, false, false, false) or nil
            if b and b ~= 0 then AttachEntityToEntity(b, ped, GetEntityBoneIndexByName(ped, 'SKEL_L_Hand'), 0.08, 0.0, 0.05, 0.0, 0.0, 0.0, true, true, false, true, 1, true) end
            if s and s ~= 0 then AttachEntityToEntity(s, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Hand'), 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true) end
            Scenario(Config.Anim.eat, 5000)
            Wait(5000)
            StopScenario()
            if b and DoesEntityExist(b) then DeleteObject(b) end
            if s and DoesEntityExist(s) then DeleteObject(s) end
            local n = tonumber(res.stats) or 0
            Integrations.consume(n, n, n, n)
        end }
    else
        rows[1] = { label = L('stew_cook'), description = L('stew_cook_desc'), onSelect = function()
            local list = {}
            for i, r in ipairs(Config.Stews) do
                list[#list + 1] = { label = r.name, description = L('stew_time', r.spoilMin), onSelect = function()
                    local sub = {}
                    for _, ing in ipairs(r.ingredients) do
                        sub[#sub + 1] = { label = ('%s x%d'):format(Config.IngredientLabels[ing[1]] or ing[1], ing[2]), disabled = true }
                    end
                    sub[#sub + 1] = { label = L('stew_cook_row'), onSelect = function()
                        if Ask('stewCook', campId, i) then
                            Menu.closeAll()
                            Notify(L('stew_cooked'))
                            Scenario(Config.Anim.crouch, 10000)
                            Wait(10000)
                            StopScenario()
                        end
                    end }
                    Menu.push({ title = r.name, subtitle = L('stew_time', r.spoilMin), rows = sub })
                end }
            end
            Menu.push({ title = L('stew_cook'), rows = list })
        end }
    end
    Menu.push({ title = L('stew_prompt'), rows = rows })
end

------------------------------------------------------------------------------ trapper

local function trapperMenu(campId)
    local info = Request('trapperInfo', campId)
    if type(info) ~= 'table' then return end
    if not CampMenu.takeLock(campId) then return end
    if not Menu.begin({ campId = campId, onClose = function() Request('unlock', campId) end }) then
        Request('unlock', campId)
        return
    end
    local v = State.camps[campId]
    local rows = {}
    local cap = math.max(1, tonumber(info.maxstock) or Config.Economy.stockCap)
    local pct = math.floor((tonumber(info.stock) or 0) / cap * 100 + 0.5)
    rows[#rows + 1] = {
        label = L('stock_line', math.floor(info.stock or 0), math.floor(cap), pct),
        description = L('stock_desc', ('%.2f'):format(tonumber(info.material) or 0), math.floor(info.supply or 0)),
        disabled = true,
    }
    local needSupplies = Config.Economy.perCycle * Config.Economy.suppliesPerStock
    if (tonumber(info.supply) or 0) < needSupplies then
        rows[#rows + 1] = { label = L('low_supplies', needSupplies), disabled = true }
    end
    if CanDo(v, 'buySupplies') then
        rows[#rows + 1] = { label = L('buy_supplies'), description = L('supply_each', U.money(Config.Economy.supplyPrice)), onSelect = function()
            local n = Menu.amount(L('buy_supplies'), L('supply_each', U.money(Config.Economy.supplyPrice)))
            if n and Ask('buySupplies', campId, n) then Menu.closeAll() end
        end }
    end
    for _, row in ipairs(Missions.rows(campId, info)) do rows[#rows + 1] = row end
    Menu.push({ title = L('trapper'), rows = rows })
end

------------------------------------------------------------------------------ prompts

local function nearestPiece(pos)
    local v = MyCamp()
    if not v or v.repo or not World.isRendered(v.id) then return nil end
    local best, bestD
    for _, p in ipairs(v.furni or {}) do
        local reach = REACH[p.functional]
        if reach and p.active and p.coords and math.abs(p.coords.z - pos.z) <= 3.0 then
            local d = U.dist2(pos, p.coords)
            if d <= reach and (not bestD or d < bestD) then
                best, bestD = p, d
                p.campId = v.id
            end
        end
    end
    return best, bestD, v
end

Interact.add(function(pos, ped)
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return nil end
    local p, d, v = nearestPiece(pos)
    if not p then return nil end
    local f = p.functional
    if f == 'inv' then
        if not CanDo(v, 'stashOpen') then return nil end
        return { dist = d, title = L('storage_prompt'), keys = { { control = Config.Keys.interact, label = L('storage_action'), fn = function() Functional.openStash(v.id) end } } }
    elseif f == 'beerbox' then
        return { dist = d, title = L('beer_box'), keys = { { control = Config.Keys.interact, label = L('grab_beer'), fn = function() grabBeer(p) end } } }
    elseif f == 'waterbarrel' then
        return { dist = d, title = L('water_barrel'), keys = { { control = Config.Keys.interact, label = L('wash_face'), fn = function() washFace(p) end } } }
    elseif f == 'changing' then
        return { dist = d, title = L('wardrobe'), keys = { { control = Config.Keys.interact, label = L('wardrobe_action'), fn = wardrobe } } }
    elseif f == 'stable' then
        return { dist = d, title = L('stable'), keys = { { control = Config.Keys.interact, label = L('stable_action'), fn = function() stableMenu(v.id) end } } }
    elseif f == 'stew' then
        return { dist = d, title = L('stew_prompt'), keys = { { control = Config.Keys.interact, label = L('stew_action'), fn = function() stewMenu(v.id) end } } }
    elseif f == 'hunting' then
        return { dist = d, title = L('trapper'), keys = {
            { control = Config.Keys.interact, label = L('trapper_donate'), fn = function() Hunting.donate(v.id) end },
            { control = Config.Keys.confirm, label = L('trapper_open'), fn = function() trapperMenu(v.id) end },
        } }
    end
    return nil
end)

OnState('stop', function()
    setDrunk(0)
    if huntingWagon and DoesEntityExist(huntingWagon) then DeleteEntity(huntingWagon) end
    calling = nil
end)

OnState('mycamp', function()
    calling = nil
end)
