-- pup_hideouts | the betting table: menu, fighter labels, and staging the fight (starter's client)

local BK <const> = Config.Bookie

HX.Bookie = {}
local state = {}   -- [hideoutId] = { pot, a, b, fight, netIds }
local staged = nil -- the fight this client runs: { id, peds = { A, B }, running } (the winner arrives only at the end)

RegisterNetEvent('pup_hideouts:bookieState', function(id, payload)
    id = tonumber(id)
    if not id or type(payload) ~= 'table' then return end
    state[id] = payload
    if HX.menuOpen and HX.insideId == id then HX.menuRefreshSoon() end
end)

local function st(id) return state[id] or { pot = 0, a = 0, b = 0, fight = false } end

----------------------------------------------------------------------------------------------------
-- menu
----------------------------------------------------------------------------------------------------
local function placeBet(id, cur)
    if st(id).fight then return HX.tip(L('fight_on')) end
    local v = HX.input(L('place_bet'), L('your_bet'), { { label = L('amount'), type = 'number', min = 1, required = true } })
    if not v then return end
    local amount = U.posInt(v[1])
    if not amount then return HX.tip(L('bad_amount')) end
    HX.menu({
        title = L('select_fighter'), subtitle = L('you_bet', amount),
        options = {
            { label = L('fighter_a'), onSelect = function(pick)
                HX.confirm(L('you_bet', amount), L('bet_sure'), pick, function()
                    HX.call('bet', 6000, id, 'A', amount)
                    HX.menuBack(cur)
                end)
            end },
            { label = L('fighter_b'), onSelect = function(pick)
                HX.confirm(L('you_bet', amount), L('bet_sure'), pick, function()
                    HX.call('bet', 6000, id, 'B', amount)
                    HX.menuBack(cur)
                end)
            end },
        },
    }, cur)
end

local function menuBuild(id)
    return function()
        local r = HX.rows[id]
        if not r or not r.bookie or HX.insideId ~= id then return nil end
        local s = st(id)
        local opts = {
            { label = L('place_bet'), onSelect = function(cur) placeBet(id, cur) end },
            { label = L('pot', U.money(s.pot or 0)) },
            { label = L('odds', U.money(s.a or 0), U.money(s.b or 0)) },
        }
        if r.member and (s.pot or 0) > 0 and not s.fight then
            opts[#opts + 1] = { label = L('start_fight'), onSelect = function()
                HX.call('fightStart', 6000, id)
                HX.menuClose()
            end }
        end
        return { title = L('bet_menu'), subtitle = s.fight and L('fight_on') or nil, options = opts }
    end
end

function HX.Bookie.openMenu(id)
    if HX.menuOpen then return end
    HX.menuClose()
    HX.page(menuBuild(id), nil)
end

----------------------------------------------------------------------------------------------------
-- labels over the fighters (everyone inside)
----------------------------------------------------------------------------------------------------
local function entityOf(net)
    net = tonumber(net)
    if not net or not NetworkDoesNetworkIdExist(net) then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end

function HX.Bookie.drawLabels()
    local s = HX.insideId and state[HX.insideId]
    if not s or not s.fight or type(s.netIds) ~= 'table' then return end
    for side, net in pairs(s.netIds) do
        local e = entityOf(net)
        if e then
            local c = GetEntityCoords(e)
            HX.text3d(vector3(c.x, c.y, c.z + 1.1), tostring(side))
        end
    end
end

----------------------------------------------------------------------------------------------------
-- staging (only on the starter's client)
----------------------------------------------------------------------------------------------------
local function deleteFighters()
    if not staged then return end
    for _, ped in pairs(staged.peds) do
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeletePed(ped)
        end
    end
    staged = nil
end

local function spawnFighter(spot)
    local model = BK.models[math.random(#BK.models)]
    local hash = HX.loadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, spot.coords.x, spot.coords.y, spot.coords.z, spot.heading, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SET_RANDOM_OUTFIT_VARIATION
    local hp = math.random(BK.healthMin, BK.healthMax)
    SetEntityMaxHealth(ped, hp)
    SetEntityHealth(ped, hp)
    RemoveAllPedWeapons(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

RegisterNetEvent('pup_hideouts:bookieStage', function(id, duration)
    id = tonumber(id)
    if not id or staged or HX.insideId ~= id then return end
    CreateThread(function()
        local r = HX.rows[id]
        local zone = U.zone(r and r.zone)
        local a, b = spawnFighter(zone.fighterA), spawnFighter(zone.fighterB)
        if not a or not b then
            if a then DeletePed(a) end
            if b then DeletePed(b) end
            HX.send('bookieAbort', id)
            return
        end
        staged = { id = id, peds = { A = a, B = b }, running = true }
        HX.send('bookieFighters', id, NetworkGetNetworkIdFromEntity(a), NetworkGetNetworkIdFromEntity(b))
        Wait(BK.startDelay * 1000)
        if not staged or staged.id ~= id then return end
        TaskCombatPed(a, b, 0, 16)
        TaskCombatPed(b, a, 0, 16)
        local apart = U.dist(zone.fighterA.coords, zone.fighterB.coords) + BK.pullBack
        local untilMs = GetGameTimer() + ((tonumber(duration) or BK.fightMax) + 15) * 1000
        while staged and staged.id == id and staged.running and GetGameTimer() < untilMs do
            Wait(500)
            if not DoesEntityExist(a) or not DoesEntityExist(b) or IsEntityDead(a) or IsEntityDead(b) then
                staged.running = false
                HX.send('bookieAbort', id)
                break
            end
            -- fists never settle it: health is topped up, the server picked the winner
            SetEntityHealth(a, GetEntityMaxHealth(a))
            SetEntityHealth(b, GetEntityMaxHealth(b))
            if U.dist(GetEntityCoords(a), GetEntityCoords(b)) > apart then
                SetEntityCoords(a, zone.fighterA.coords.x, zone.fighterA.coords.y, zone.fighterA.coords.z, false, false, false, false)
                SetEntityCoords(b, zone.fighterB.coords.x, zone.fighterB.coords.y, zone.fighterB.coords.z, false, false, false, false)
                TaskCombatPed(a, b, 0, 16)
                TaskCombatPed(b, a, 0, 16)
            end
        end
    end)
end)

RegisterNetEvent('pup_hideouts:bookieFinish', function(id, winner)
    if not staged or staged.id ~= tonumber(id) then return end
    staged.running = false
    local loser = staged.peds[winner == 'A' and 'B' or 'A']
    local champ = staged.peds[winner]
    if champ and DoesEntityExist(champ) then ClearPedTasks(champ) end
    if loser and DoesEntityExist(loser) then
        ClearPedTasks(loser)
        SetPedToRagdoll(loser, 6000, 6000, 0, false, false, false)
    end
end)

-- the table reset five seconds ago: the fighters go
RegisterNetEvent('pup_hideouts:bookieCleanup', function(id)
    if staged and staged.id == tonumber(id) then deleteFighters() end
end)

AddEventHandler('pup_hideouts:leavingHideout', function(id)
    if staged and staged.id == id then deleteFighters() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then deleteFighters() end
end)
