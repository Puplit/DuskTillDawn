-- pup-misc / bountyhunting - client half
-- Boards, the party menu, and the contract itself on the LEADER's client (spawning, watching,
-- handing over). Partners only draw what the server relays to them. Everything that pays is
-- re-checked by the server; this side never names an amount.

local Cfg = BountyConfig
local Data = BountyShared
local Text = BountyLocale

local EV <const> = 'pup-misc:bountyhunting:'
local LIST_OWNER <const> = 'pup-misc:bountyhunting:party'
local INPUT_OWNER <const> = 'pup-misc:bountyhunting:partners'

local NATIVE <const> = {
    blipForCoords   = 0x554D9D53F696D002,
    blipForEntity   = 0x23F74C2FDA6E7C61,
    blipName        = 0x9CB1A1623062F402,
    blipModifier    = 0x662D364ABF16DE2F,
    activeGroup     = 0xC65A45D4453C2627,
    carrying        = 0xD806CD2A4F2C2996,
    randomOutfit    = 0x283978A15512B2FE,
    restrained      = 0xD453BB601D4A606E,
}

local state = {
    job = nil,          -- the character's job, from the vorp Character state bag
    boardBlips = {},
    menu = nil,         -- { board, count } while the party menu / form is up
    pending = false,    -- a request is on its way to the server
    run = nil,          -- the contract this client leads
    follow = nil,       -- the contract this client rides along on
}
local warned = {}

local function trace(fmt, ...)
    if Cfg.Debug then print(('[pup-misc:bountyhunting] ' .. fmt):format(...)) end
end

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[pup-misc:bountyhunting]^7 %s'):format(msg))
end

------------------------------------------------------------------------------ text

local function notify(text, ms)
    if Cfg.Notifier == 'redem' then
        TriggerEvent('redem_roleplay:ShowObjective', text, ms)
    else
        TriggerEvent('vorp:TipBottom', text, ms)
    end
end

local BRIEF_MS <const> = 8000

-- the board's notice: kind, who, why, and what to do
local function contractLine(kind, ct)
    if ct and ct.name and ct.notice and Text.briefLine then
        return Text.briefLine:format(Text.kindName[kind] or '', ct.name, ct.notice, Text.objective[kind] or '')
    end
    return Text.titleLine:format(Text.kindName[kind] or '', Text.objective[kind] or '')
end

local function endText(reason)
    if reason == 'failed' then return Text.failed end
    if reason == 'closed' then return Text.calledOff end
    return Text.over
end

------------------------------------------------------------------------------ map markers and routes

local function nameBlip(blip, name)
    if blip and blip ~= 0 and name then
        Citizen.InvokeNative(NATIVE.blipName, blip, CreateVarString(10, 'LITERAL_STRING', name))
    end
end

local function tintBlip(blip, modifier)
    if blip and blip ~= 0 and modifier then Citizen.InvokeNative(NATIVE.blipModifier, blip, modifier) end
end

local function coordBlip(sprite, pos, name, modifier, scale)
    local blip = Citizen.InvokeNative(NATIVE.blipForCoords, Cfg.Blips.CoordStyle, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    if not blip or blip == 0 then return nil end
    SetBlipSprite(blip, sprite, true)
    if scale then SetBlipScale(blip, scale + 0.0) end
    nameBlip(blip, name)
    tintBlip(blip, modifier)
    return blip
end

local function pedBlip(ped, name, modifier)
    local blip = Citizen.InvokeNative(NATIVE.blipForEntity, Cfg.Blips.EntityStyle, ped)
    if not blip or blip == 0 then return nil end
    SetBlipSprite(blip, Cfg.Blips.PedSprite, true)
    nameBlip(blip, name)
    tintBlip(blip, modifier)
    return blip
end

local function dropBlip(blip)
    if blip and blip ~= 0 and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function setRoute(pos)
    ClearGpsMultiRoute()
    StartGpsMultiRoute(GetHashKey(Cfg.Blips.RouteColour), true, true)
    AddPointToGpsMultiRoute(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    SetGpsMultiRouteRender(true)
end

local function clearRoute()
    ClearGpsMultiRoute()
end

------------------------------------------------------------------------------ job and board markers

local function readJob()
    local ch = LocalPlayer.state.Character
    return type(ch) == 'table' and ch.Job or nil
end

local function qualifies()
    return Data.jobAllowed(state.job)
end

local function clearBoardBlips()
    for _, b in ipairs(state.boardBlips) do dropBlip(b) end
    state.boardBlips = {}
end

local function refreshBoardBlips()
    local loaded = state.job ~= nil
    local want = loaded and (Cfg.Blips.BoardsForEveryone or qualifies())
    if want and #state.boardBlips == 0 then
        for _, b in ipairs(Cfg.Boards) do
            local blip = coordBlip(Cfg.Blips.BoardSprite, b.coords, Text.boardBlip, nil, Cfg.Blips.Scale)
            if blip then state.boardBlips[#state.boardBlips + 1] = blip end
        end
    elseif not want and #state.boardBlips > 0 then
        clearBoardBlips()
    end
end

AddStateBagChangeHandler('Character', ('player:%d'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    local job = type(value) == 'table' and value.Job or nil
    if job ~= state.job then
        state.job = job
        refreshBoardBlips()
    end
end)

------------------------------------------------------------------------------ peds

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + (Cfg.Contracts.ModelLoadTimeout or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

local function takeControl(ent, ms)
    if NetworkHasControlOfEntity(ent) then return true end
    local deadline = GetGameTimer() + ms
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < deadline do
        Wait(50)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

local function removePed(ped, wait)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    for attempt = 1, 2 do
        if wait then takeControl(ped, attempt == 1 and 1000 or 500) end
        if IsEntityAttached(ped) then DetachEntity(ped, true, true) end
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        if not DoesEntityExist(ped) or not wait then return end
    end
end

local function netOf(ped)
    if not NetworkGetEntityIsNetworked(ped) then return nil end
    local net = NetworkGetNetworkIdFromEntity(ped)
    if not net or net == 0 then return nil end
    return net
end

local function giveWeapon(ped, weapon)
    local name = Data.weaponName(weapon)
    if not name then return end
    local hash = GetHashKey(name)
    if not IsWeaponValid(hash) then
        warnOnce('weapon:' .. name, ('unknown weapon "%s" in the contract data; the ped spawns unarmed'):format(name))
        return
    end
    GiveWeaponToPed_2(ped, hash, 500, true, false, 0, false, 0.5, 1.0, 752097756, false, 0.0, false)
    SetCurrentPedWeapon(ped, hash, true, 0, false, false)
end

-- one networked ped from a model pool; nil after the configured attempts
local function makePed(poolName, pos)
    local pool = Data.pool(poolName)
    if not pool then
        warnOnce('pool:' .. tostring(poolName), ('ped pool "%s" is missing'):format(tostring(poolName)))
        return nil
    end
    for _ = 1, (Cfg.Contracts.SpawnAttempts or 3) do
        local name = pool[math.random(#pool)]
        local hash = GetHashKey(name)
        if loadModel(hash) then
            local ped = CreatePed(hash, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, math.random(0, 359) + 0.0, true, true, false, false)
            SetModelAsNoLongerNeeded(hash)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                Citizen.InvokeNative(NATIVE.randomOutfit, ped, true)
                SetEntityAsMissionEntity(ped, true, true)
                local deadline = GetGameTimer() + 2000
                while not netOf(ped) and GetGameTimer() < deadline do Wait(50) end
                local net = netOf(ped)
                if net then SetNetworkIdExistsOnAllMachines(net, true) end
                return ped
            end
        else
            warnOnce('model:' .. name, ('ped model "%s" did not load'):format(name))
        end
    end
    return nil
end

local function armHostile(ped, entry, target)
    giveWeapon(ped, entry.weapon)
    SetPedCombatMovement(ped, math.max(0, math.min(3, tonumber(entry.style) or 1)))
    SetPedCombatAttributes(ped, 46, true) -- always fight
    SetPedCombatAttributes(ped, 5, true)
    SetPedFleeAttributes(ped, 0, false)
    TaskCombatPed(ped, target, 0, 16)
end

local function isDead(ped)
    return not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
end

local function meDead()
    local me = PlayerPedId()
    return IsEntityDead(me) or IsPedDeadOrDying(me, true)
end

------------------------------------------------------------------------------ ending (both roles)

local function wipeRun(run, wait)
    for _, p in ipairs(run.peds) do
        dropBlip(p.blip)
        removePed(p.ped, wait)
    end
    run.peds = {}
    run.wiped = true
    dropBlip(run.startBlip)
    dropBlip(run.dropBlip)
    run.startBlip, run.dropBlip = nil, nil
end

local function wipeFollow(f)
    for _, b in pairs(f.blips) do dropBlip(b) end
    f.blips = {}
    dropBlip(f.startBlip)
    dropBlip(f.dropBlip)
    f.startBlip, f.dropBlip = nil, nil
end

local function routeFree()
    return state.run == nil and state.follow == nil
end

-- the leader's contract is over: message now, peds and markers after the end pause
local function finishRun(run, reason, silent)
    if run.over then return end
    run.over = true
    if state.run == run then state.run = nil end
    if not silent then notify(endText(reason), 4000) end
    trace('contract %d over (%s)', run.id, tostring(reason))
    if silent then
        wipeRun(run, false)
        if routeFree() then clearRoute() end
        return
    end
    local pause = (tonumber(Cfg.Contracts.EndPauseSeconds) or 5) * 1000
    SetTimeout(pause, function()
        CreateThread(function()
            wipeRun(run, true)
            if routeFree() then clearRoute() end
        end)
    end)
end

-- the leader gives up or fails: tell the server once, then end here
local function giveUp(run, reason)
    if run.over then return end
    TriggerServerEvent(EV .. 'finish', run.id, reason)
    finishRun(run, reason)
end

local function finishFollow(f, reason, silent)
    if state.follow == f then state.follow = nil end
    f.over = true
    wipeFollow(f)
    if routeFree() then clearRoute() end
    if not silent then notify(endText(reason), 4000) end
end

local function dropEverything()
    if state.run then finishRun(state.run, 'closed', true) end
    if state.follow then finishFollow(state.follow, 'closed', true) end
    state.menu = nil
    state.pending = false
end

------------------------------------------------------------------------------ the leader's contract

local function addPed(run, ped, role, blipName, modifier)
    -- a spawn still loading when the contract was wiped would otherwise be left in the world
    if run.wiped then
        removePed(ped, false)
        return nil
    end
    local entry = { ped = ped, net = netOf(ped), role = role }
    if blipName then entry.blip = pedBlip(ped, blipName, modifier) end
    run.peds[#run.peds + 1] = entry
    if entry.net then run.byNet[entry.net] = entry end
    return entry
end

local function register(run, role, list)
    local nets = {}
    for _, e in ipairs(list) do
        if e.net then nets[#nets + 1] = e.net end
    end
    if #nets > 0 then TriggerServerEvent(EV .. 'register', run.id, role, nets) end
end

-- camp spots are laid out around the contract point at its height: put each one on the
-- ground, looking only a little way up so nobody lands on a roof or a cliff top
local function campGround(pos)
    local found, gz = GetGroundZFor_3dCoord(pos.x + 0.0, pos.y + 0.0, pos.z + 8.0, false)
    if found and gz and math.abs(gz - pos.z) < 15.0 then return vector3(pos.x, pos.y, gz + 0.1) end
    return vector3(pos.x, pos.y, pos.z + 0.5)
end

local function spawnGroup(run, entries, poolName, role, blipName, modifier)
    local made = {}
    for _, entry in ipairs(entries or {}) do
        if run.over then break end
        local ped = makePed(poolName, campGround(entry.coords))
        if ped then
            armHostile(ped, entry, PlayerPedId())
            made[#made + 1] = addPed(run, ped, role, blipName, modifier)
        end
    end
    return made
end

local function showDrop(run, label)
    dropBlip(run.dropBlip)
    run.dropBlip = coordBlip(Cfg.Blips.DropSprite, run.ct.dropCoords, label, Cfg.Blips.DropColour)
    setRoute(run.ct.dropCoords)
end

local function anyAlive(run, role)
    for _, p in ipairs(run.peds) do
        if p.role == role and not p.delivered and not isDead(p.ped) then return true end
    end
    return false
end

local function spawnKill(run)
    local marks = Cfg.Contracts.HostileMarkers and Text.markHostile or nil
    local made = spawnGroup(run, run.block.enemies, run.block.pedPool, 'hostile', marks, Cfg.Blips.HostileColour)
    if run.over then return end
    -- nothing spawned: the contract can never be cleared, so close it now
    if #made == 0 then return giveUp(run, 'failed') end
    register(run, 'hostile', made)
    run.stage = 'fight'
end

local function spawnArrest(run)
    -- the wanted men first, always marked
    local targets = spawnGroup(run, run.block.targets, run.block.pedPool, 'target', Text.markTarget, Cfg.Blips.TargetColour)
    if run.over then return end
    if #targets == 0 then return giveUp(run, 'failed') end
    register(run, 'target', targets)
    local marks = Cfg.Contracts.HostileMarkers and Text.markHostile or nil
    local guards = spawnGroup(run, run.block.enemies, run.block.pedPool, 'hostile', marks, Cfg.Blips.HostileColour)
    register(run, 'hostile', guards)
    run.stage = 'deliver'
    notify(Text.arrestNext, 4000)
    showDrop(run, Text.markDrop)
end

local function followLeader(ped)
    TaskFollowToOffsetOfEntity(ped, PlayerPedId(), 0.0, -1.5, 0.0, 1.0, -1, 1.5, true, false, false, 0, 0, 1)
end

local function spawnEscort(run)
    local ped = makePed(run.block.clientPool, run.ct.coords)
    if not ped then
        giveUp(run, 'failed')
        return
    end
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanBeTargetted(ped, true)
    local health = math.floor(tonumber(run.block.health) or 0)
    if health > 0 then
        SetEntityMaxHealth(ped, health)
        SetEntityHealth(ped, health, 0)
    end
    local entry = addPed(run, ped, 'client', Text.markClient, Cfg.Blips.TargetColour)
    if not entry then return end
    run.client = entry
    register(run, 'client', { entry })
    followLeader(ped)

    local interval = math.max(1, tonumber(run.block.spawnIntervalSeconds) or 100) * 1000
    local first = tonumber(Cfg.Contracts.FirstWaveSeconds)
    run.interval = interval
    run.nextWave = GetGameTimer() + (first and first * 1000 or interval)
    run.nextFollow = GetGameTimer() + (Cfg.Contracts.EscortFollowRefresh or 10) * 1000
    run.stage = 'escort'
    notify(Text.escortNext, 4000)
    showDrop(run, Text.markDest)
end

local function groundAt(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 30.0, false)
    if found then return gz end
    return z
end

local function spawnWave(run)
    local client = run.client and run.client.ped
    if not client or not DoesEntityExist(client) then return end
    local at = GetEntityCoords(client)
    local made = {}
    for _, entry in ipairs(run.block.enemies or {}) do
        if run.over then break end
        local x = at.x + (math.random(2) == 1 and 20.0 or -20.0)
        local y = at.y + (math.random(2) == 1 and 20.0 or -20.0)
        local pos = vector3(x, y, groundAt(x, y, at.z))
        local ped = makePed(run.block.enemyPool, pos)
        if ped then
            local target = client
            if Cfg.Contracts.EscortRandomTarget and math.random(2) == 1 then target = PlayerPedId() end
            -- the wave can outlive the client by a frame: never task a ped at something gone
            if not DoesEntityExist(target) then target = PlayerPedId() end
            armHostile(ped, entry, target)
            made[#made + 1] = addPed(run, ped, 'attacker', Text.markAttacker, Cfg.Blips.HostileColour)
        end
    end
    register(run, 'attacker', made)
end

local function tickKill(run)
    if run.stage == 'fight' then
        local alive = anyAlive(run, 'hostile')
        if meDead() and alive then return giveUp(run, 'failed') end
        -- the server sees every ped (even ones out of this client's range) and answers
        -- with the 'deliver' stage once it agrees; ask again every few seconds until then
        if not alive and GetGameTimer() >= (run.nextClearAsk or 0) then
            run.nextClearAsk = GetGameTimer() + 3000
            TriggerServerEvent(EV .. 'cleared', run.id)
        end
    elseif meDead() and Cfg.Contracts.DeathFailsAfterClear then
        giveUp(run, 'failed')
    end
end

local function tickArrest(run)
    -- walk a snapshot: a loss reported here must not shift the list mid-walk
    local snapshot = {}
    for i, p in ipairs(run.peds) do snapshot[i] = p end
    for _, p in ipairs(snapshot) do
        -- only a body this client can see counts: a ped out of range is not a dead one
        if p.role == 'target' and not p.delivered and not p.lost and DoesEntityExist(p.ped) and isDead(p.ped) then
            p.lost = true
            dropBlip(p.blip)
            p.blip = nil
            if p.net then TriggerServerEvent(EV .. 'lost', run.id, p.net) end
        end
    end
    if meDead() and (anyAlive(run, 'hostile') or Cfg.Contracts.DeathFailsAfterClear) then
        giveUp(run, 'failed')
    end
end

local function tickEscort(run)
    local now = GetGameTimer()
    -- the arrival claim is out: the server removes the client and ends the contract.
    -- If no answer comes (claim refused), carry on and claim again.
    if run.claimedAt then
        if now - run.claimedAt < 5000 then return end
        run.claimedAt = nil
    end
    local client = run.client and run.client.ped
    if meDead() or not client or isDead(client) then return giveUp(run, 'failed') end
    local tied = Citizen.InvokeNative(NATIVE.restrained, client)
    if tied == true or tied == 1 or (PupIsRestrained and PupIsRestrained(client)) then
        return giveUp(run, 'failed')
    end

    if #(GetEntityCoords(client) - run.ct.dropCoords) <= (Cfg.Contracts.EscortArriveDistance or 2.0) then
        run.claimedAt = now
        TriggerServerEvent(EV .. 'escortDone', run.id)
        return
    end
    if now >= run.nextFollow then
        run.nextFollow = now + (Cfg.Contracts.EscortFollowRefresh or 10) * 1000
        followLeader(client)
    end
    if now >= run.nextWave then
        run.nextWave = now + run.interval
        spawnWave(run)
    end
    -- fallen attackers lose their markers
    for _, p in ipairs(run.peds) do
        if p.role == 'attacker' and p.blip and isDead(p.ped) then
            dropBlip(p.blip)
            p.blip = nil
        end
    end
end

local function runLeader(run)
    notify(contractLine(run.kind, run.ct), BRIEF_MS)
    local sprite = run.kind == 'escort' and Cfg.Blips.ClientSprite or Cfg.Blips.StartSprite
    run.startBlip = coordBlip(sprite, run.ct.coords, run.ct.name or Text.markStart[run.kind], Cfg.Blips.StartColour)
    setRoute(run.ct.coords)

    local arrive = Cfg.Contracts.ArriveDistance or 120.0
    while not run.over do
        if #(GetEntityCoords(PlayerPedId()) - run.ct.coords) <= arrive then break end
        Wait(1000)
    end
    if run.over then return end

    dropBlip(run.startBlip)
    run.startBlip = nil
    clearRoute()

    if run.kind == 'kill' then
        spawnKill(run)
    elseif run.kind == 'arrest' then
        spawnArrest(run)
    else
        spawnEscort(run)
    end

    while not run.over do
        Wait(250)
        if run.kind == 'kill' then
            tickKill(run)
        elseif run.kind == 'arrest' then
            tickArrest(run)
        else
            tickEscort(run)
        end
    end
end

------------------------------------------------------------------------------ hand-overs at the drop point

local function carriedEntity()
    local ent = Citizen.InvokeNative(NATIVE.carrying, PlayerPedId())
    if not ent or ent == 0 or ent == false or not DoesEntityExist(ent) then return nil end
    return ent
end

local function matchCarried(run, ent)
    local net = netOf(ent)
    local entry = net and run.byNet[net]
    if not entry then
        for _, p in ipairs(run.peds) do
            if p.ped == ent then entry = p break end
        end
    end
    if not entry then
        local orig = tonumber(Entity(ent).state.network)
        if orig then entry = run.byNet[orig] end
    end
    return entry, net
end

local function handOver(run)
    local ent = carriedEntity()
    if not ent then return notify(Text.carryNothing, 4000) end
    local entry, net = matchCarried(run, ent)
    local wanted = run.kind == 'kill' and 'hostile' or 'target'
    if not entry or entry.role ~= wanted or entry.delivered or entry.lost or not net then
        return notify(Text.notYourBounty, 4000)
    end
    run.handing = { ent = ent }
    TriggerServerEvent(EV .. 'deliver', run.id, net)
end

local function makePrompt(key, label, group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

local prompts = {}

CreateThread(function()
    local group = GetRandomIntInRange(0, 0xffffff)
    prompts.endRun = makePrompt(Cfg.Keys.End, Text.promptEnd, group)
    prompts.deliver = makePrompt(Cfg.Keys.Interact, Text.promptDeliver, group)
    local ready = 0
    while true do
        local run = state.run
        if not run or run.over or run.stage ~= 'deliver' then
            Wait(500)
        else
            local d = #(GetEntityCoords(PlayerPedId()) - run.ct.dropCoords)
            if d > (Cfg.Contracts.HandoverDistance or 10.0) then
                Wait(d > 60.0 and 1000 or 250)
            else
                Wait(0)
                Citizen.InvokeNative(NATIVE.activeGroup, group, CreateVarString(10, 'LITERAL_STRING', Text.promptTitle), 0, 0, 0, 0)
                local now = GetGameTimer()
                if now >= ready then
                    if PromptHasStandardModeCompleted(prompts.endRun, 0) then
                        ready = now + 1000
                        giveUp(run, 'abandon')
                    elseif PromptHasStandardModeCompleted(prompts.deliver, 0) then
                        ready = now + math.floor((Cfg.Contracts.HandoverPause or 2.5) * 1000)
                        handOver(run)
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------------------ the board and the party menu

local function nearestBoard(maxDist)
    local at = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, maxDist
    for i, b in ipairs(Cfg.Boards) do
        local d = #(at - b.coords)
        if d <= bestDist then best, bestDist = i, d end
    end
    return best, bestDist
end

-- a menu pup-ui hid without telling us (HideListMenu from elsewhere) must not lock the board forever
local MENU_STALE_MS <const> = 120000

local function boardUsable()
    local menuOpen = state.menu and GetGameTimer() - (state.menu.at or 0) < MENU_STALE_MS
    return not menuOpen and not state.pending and not state.run and not state.follow
        and state.job ~= nil and qualifies() and not meDead()
end

local function openPartyMenu(boardIndex)
    if PupBlockIfRestrained and PupBlockIfRestrained() then return end
    -- a leftover from an earlier contract on this client goes quietly
    dropEverything()
    state.menu = { board = boardIndex, at = GetGameTimer() }
    local options = {}
    for i, row in ipairs(Text.partyRows) do
        options[i] = { label = row.label, desc = row.desc, icon = i == 1 and 'user' or 'users' }
    end
    local ok = pcall(function()
        exports['pup-ui']:OpenListMenu({
            owner = LIST_OWNER,
            title = Text.menuTitle,
            subtitle = Text.menuSubtitle,
            keyboard = true,
            options = options,
        })
    end)
    if not ok then
        state.menu = nil
        warnOnce('pup-ui', 'pup-ui OpenListMenu is not available; the bounty board cannot open')
    end
end

local function sendRequest(boardIndex, count, ids)
    state.menu = nil
    state.pending = true
    TriggerServerEvent(EV .. 'request', boardIndex, count, ids)
    -- the server always answers; this only frees the board if the answer is lost
    SetTimeout(8000, function() state.pending = false end)
end

CreateThread(function()
    local group = GetRandomIntInRange(0, 0xffffff)
    prompts.board = makePrompt(Cfg.Keys.Interact, Text.promptOpen, group)
    local reach = Cfg.BoardPromptDistance or 2.0
    while true do
        if not boardUsable() then
            Wait(1000)
        else
            local idx, d = nearestBoard(40.0)
            if not idx then
                Wait(1000)
            elseif d > reach then
                Wait(250)
            else
                Wait(0)
                Citizen.InvokeNative(NATIVE.activeGroup, group, CreateVarString(10, 'LITERAL_STRING', Text.promptTitle), 0, 0, 0, 0)
                if PromptHasStandardModeCompleted(prompts.board, 0) then openPartyMenu(idx) end
            end
        end
    end
end)

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= LIST_OWNER or not state.menu or state.menu.count then return end
    index = tonumber(index)
    local max = math.min(#Text.partyRows, Cfg.Party.MaxHunters or 4)
    if not index or index < 1 or index > max then
        state.menu = nil
        return
    end
    local board = state.menu.board
    if index == 1 then return sendRequest(board, 1, {}) end

    state.menu.count = index
    local fields = {}
    for i = 1, index - 1 do
        fields[i] = { label = Text.partnerFields[i], type = 'number', min = 1, required = true }
    end
    local ok = pcall(function()
        exports['pup-ui']:OpenInput({
            owner = INPUT_OWNER,
            title = Text.menuTitle,
            subtitle = Text.menuSubtitle,
            submit = Text.confirm,
            fields = fields,
        })
    end)
    if not ok then
        state.menu = nil
        warnOnce('pup-ui-input', 'pup-ui OpenInput is not available; parties of two or more cannot be formed')
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner == LIST_OWNER and state.menu and not state.menu.count then state.menu = nil end
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner == LIST_OWNER and state.menu and not state.menu.count then state.menu = nil end
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= INPUT_OWNER or not state.menu or not state.menu.count then return end
    local board, count = state.menu.board, state.menu.count
    if type(values) ~= 'table' then
        state.menu = nil
        return
    end
    local me = GetPlayerServerId(PlayerId())
    local ids, seen = {}, { [me] = true }
    for i = 1, count - 1 do
        local id = tonumber(values[i])
        if id and id > 0 and id == math.floor(id) and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    sendRequest(board, count, ids)
end)

------------------------------------------------------------------------------ partner side

local function markRelayed(f, role, nets, aim)
    local names = { hostile = Text.markHostile, target = Text.markTarget, client = Text.markClient, attacker = Text.markAttacker }
    local colours = { hostile = Cfg.Blips.HostileColour, target = Cfg.Blips.TargetColour, client = Cfg.Blips.TargetColour, attacker = Cfg.Blips.HostileColour }
    for _, net in ipairs(nets) do
        net = tonumber(net)
        if net and not f.blips[net] then
            if aim then f.aim[net] = true end
            CreateThread(function()
                for _ = 1, Cfg.PartnerMarkerRetries or 360 do
                    if f.over or state.follow ~= f or f.blips[net] then return end
                    if NetworkDoesNetworkIdExist(net) then
                        local ped = NetworkGetEntityFromNetworkId(net)
                        if ped and ped ~= 0 and DoesEntityExist(ped) then
                            f.blips[net] = pedBlip(ped, names[role], colours[role])
                            -- marked already: aiming at him has nothing left to do
                            if f.blips[net] then f.aim[net] = nil end
                            return
                        end
                    end
                    Wait(Cfg.PartnerMarkerRetryMs or 500)
                end
            end)
        end
    end
    if aim then f.aimWatch() end
end

-- a partner aiming at a marked wanted man marks him, once
local function newFollow(payload, ct)
    local f = { id = payload.id, kind = payload.kind, ct = ct, blips = {}, aim = {}, over = false }
    local watching = false
    f.aimWatch = function()
        if watching then return end
        watching = true
        CreateThread(function()
            while not f.over and state.follow == f and next(f.aim) do
                if IsPlayerFreeAiming(PlayerId()) then
                    Wait(100)
                    local hit, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
                    local net = hit and ent and ent ~= 0 and netOf(ent)
                    if net and f.aim[net] then
                        f.aim[net] = nil
                        if not f.blips[net] then f.blips[net] = pedBlip(ent, Text.markTarget, Cfg.Blips.TargetColour) end
                    end
                else
                    Wait(500)
                end
            end
            watching = false
        end)
    end
    return f
end

------------------------------------------------------------------------------ server messages

RegisterNetEvent(EV .. 'refused', function(key, arg)
    state.pending = false
    local fmt = Text[key]
    if type(fmt) ~= 'string' then return end
    if key == 'cooldown' then
        local n = math.max(1, math.floor(tonumber(arg) or 1))
        return notify(fmt:format(n, n == 1 and Text.minuteOne or Text.minuteMany), 5000)
    end
    if fmt:find('%%d') then fmt = fmt:format(math.floor(tonumber(arg) or 0)) end
    notify(fmt, 5000)
end)

RegisterNetEvent(EV .. 'begin', function(payload)
    if type(payload) ~= 'table' or not Data.isKind(payload.kind) then return end
    state.pending = false
    local id, kind = tonumber(payload.id), payload.kind
    local block, ct = Data.block(kind, payload.town, tonumber(payload.idx), tonumber(payload.count))
    if not id or not block then return end

    if payload.leader then
        if state.run then finishRun(state.run, 'closed', true) end
        if state.follow then finishFollow(state.follow, 'closed', true) end
        local run = { id = id, kind = kind, block = block, ct = ct, peds = {}, byNet = {}, stage = 'travel', over = false }
        state.run = run
        trace('leading contract %d: %s %s #%s', id, kind, tostring(payload.town), tostring(payload.idx))
        CreateThread(function()
            local ok, err = pcall(runLeader, run)
            if not ok then
                print(('^1[pup-misc:bountyhunting]^7 contract loop error: %s'):format(tostring(err)))
                if not run.over then giveUp(run, 'failed') end
            end
        end)
    else
        if state.follow then finishFollow(state.follow, 'closed', true) end
        local f = newFollow(payload, ct)
        state.follow = f
        notify(contractLine(kind, ct), BRIEF_MS)
        local sprite = kind == 'escort' and Cfg.Blips.ClientSprite or Cfg.Blips.StartSprite
        f.startBlip = coordBlip(sprite, ct.coords, ct.name or Text.kindName[kind], Cfg.Blips.StartColour)
        setRoute(ct.coords)
    end
end)

RegisterNetEvent(EV .. 'stage', function(id, stage)
    local run = state.run
    if run and run.id == id then
        if stage == 'deliver' and run.kind == 'kill' and run.stage == 'fight' then
            run.stage = 'deliver'
            notify(Text.killNext, 4000)
            showDrop(run, Text.markDrop)
        end
        return
    end
    local f = state.follow
    if not f or f.id ~= id then return end
    dropBlip(f.startBlip)
    f.startBlip = nil
    local label
    if stage == 'deliver' then
        notify(f.kind == 'kill' and Text.killNext or Text.arrestNext, 4000)
        label = Text.markDrop
    elseif stage == 'escort' then
        notify(Text.escortNext, 4000)
        label = Text.markDest
    else
        return
    end
    dropBlip(f.dropBlip)
    f.dropBlip = coordBlip(Cfg.Blips.DropSprite, f.ct.dropCoords, label, Cfg.Blips.DropColour)
    setRoute(f.ct.dropCoords)
end)

RegisterNetEvent(EV .. 'marks', function(id, role, nets, aim)
    local f = state.follow
    if not f or f.id ~= id or type(nets) ~= 'table' then return end
    if role ~= 'hostile' and role ~= 'target' and role ~= 'client' and role ~= 'attacker' then return end
    markRelayed(f, role, nets, aim == true)
end)

RegisterNetEvent(EV .. 'delivered', function(id, net)
    local run = state.run
    if not run or run.id ~= id then return end
    local entry = run.byNet[tonumber(net)]
    if entry then
        entry.delivered = true
        dropBlip(entry.blip)
        entry.blip = nil
    end
    -- the server already removed the body; make sure the carry lets go here too
    local held = run.handing and run.handing.ent
    run.handing = nil
    if held and DoesEntityExist(held) then
        if IsEntityAttached(held) then DetachEntity(held, true, true) end
        removePed(held, false)
    end
    ClearPedSecondaryTask(PlayerPedId())
end)

RegisterNetEvent(EV .. 'ended', function(id, reason)
    if state.run and state.run.id == id then
        finishRun(state.run, reason)
    elseif state.follow and state.follow.id == id then
        finishFollow(state.follow, reason)
    end
end)

------------------------------------------------------------------------------ lifecycle

RegisterNetEvent('vorp:SelectedCharacter', function()
    -- a new character starts clean: the server closes the old character's contract too
    dropEverything()
    SetTimeout(1000, function()
        state.job = readJob()
        clearBoardBlips()
        refreshBoardBlips()
    end)
end)

-- a restart of pup-misc with the character already in play draws the boards straight away
CreateThread(function()
    Wait(1000)
    state.job = readJob()
    refreshBoardBlips()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if state.run then
        state.run.over = true
        wipeRun(state.run, false)
    end
    if state.follow then wipeFollow(state.follow) end
    if state.run or state.follow then clearRoute() end
    clearBoardBlips()
    for _, p in pairs(prompts) do PromptDelete(p) end
end)
