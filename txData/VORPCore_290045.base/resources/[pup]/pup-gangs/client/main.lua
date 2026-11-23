-- pup-gangs | client/main.lua: the gang panel (NUI), the map layer and the commands

local Core = exports.vorp_core:GetCore()

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs]^7 " .. table.concat(parts, " "))
end

-- 1284 -> "1,284" for the in-game blip labels
local function fmtPts(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (out:gsub('^,', ''))
end

-- territory list from the server; the blip layer fills it and the NUI map reads it
local knownTerritories = {}

local pendingInvite = nil

-- THE GANG UI (NUI)
local uiOpen = false

-- everything the page needs in one pull. getPanel drives the whole thing
local function bundle()
    local panel = Core.Callback.TriggerAwait('pup-gangs:getPanel')
    if panel == false or type(panel) ~= 'table' then return nil end
    local factions = Core.Callback.TriggerAwait('pup-gangs:getFactions') or {}
    -- no gang directory: who runs which gang is meant to be learned in the world
    return {
        panel = panel,
        factions = factions,
        territories = knownTerritories or {},
        dens = (GangDensMine and GangDensMine()) or {},
        -- claimable ground + why each entry is or is not open to a siege
        claimTargets = (panel.hasGang and Core.Callback.TriggerAwait('pup-gangs:getClaimTargets')) or {},
        forts = (panel.hasGang and Core.Callback.TriggerAwait('pup-gangs:getForts')) or {},
        -- the blood-money ledger (server/blood.lua). nil for a player with no gang.
        blood = (panel.hasGang and Core.Callback.TriggerAwait('pup-gangs:getBlood')) or nil,
        -- the gang's own product (server/drugs.lua). nil with no gang.
        drug = (panel.hasGang and Core.Callback.TriggerAwait('pup-gangs:getDrug')) or nil,
    }
end

-- static config snapshot for the page (sent once per open; cheap and simple)
local function uiConfig()
    local factions = {}
    for _, key in ipairs(Config.Factions.order) do
        local f = Config.Factions.list[key]
        if f then
            factions[#factions + 1] = {
                key = key, label = f.label, blurb = f.blurb,
                bonus = f.bonus and f.bonus.label or '',
            }
        end
    end
    local stashes = {}
    for _, s in ipairs(Config.Stashes.list or {}) do
        -- `den` rides along so the gang panel can leave the Den Inventory out of the hideout row: that one belongs to a shack
        stashes[#stashes + 1] = { key = s.key, label = s.label, unlock = s.unlock,
                                  minRank = s.minRank, den = s.den == true }
    end
    return {
        language    = Locale,
        ranks       = Config.Ranks.list,
        rankUnlocks = Config.Ranks.unlocks,
        levels      = Config.Perks.levels,
        perkLabels  = Config.Perks.labels,
        radiusCurve = Config.Map.radiusCurve,
        baseRadius  = Config.Map.baseRadius,
        maxRadius   = Config.Map.maxRadius,
        maxMembers  = Config.Creation.maxMembers,
        factions    = factions,
        stashes     = stashes,
        wars        = {
            enabled = Config.Wars.enabled,
            declareCost = Config.Wars.declareCost,
            pointsPerKill = Config.Wars.pointsPerKill,
            warWin = Config.Points.warWin,
        },
        missionsEnabled = Config.Missions.enabled,
        claims      = {
            enabled = Config.Claims.enabled,
            durationMinutes = Config.Claims.durationMinutes,
            travelGraceMinutes = Config.Claims.travelGraceMinutes,
            cooldownMinutes = Config.Claims.cooldownMinutes,
        },
        blood  = { enabled = Config.Blood and Config.Blood.enabled == true },
        dens   = { enabled = Config.Dens.enabled, unlock = Config.Dens.unlock,
                   playerDens = Config.Dens.playerDens == true },
        createPrice = Config.Creation.price,
        shortMin    = Config.Creation.minShortLength,
        shortMax    = Config.Creation.maxShortLength,
        hideFactions = Config.Factions.hidden == true,
        blipColors  = Config.Colors.list,
    }
end

-- ctx: 'table' (the gang table) or 'den' (a den)
local panelCtx = 'table'

function OpenGangPanel(view, ctx)
    local b = bundle()
    if not b then return end
    panelCtx = ctx or 'table'
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = b, config = uiConfig(), view = view, ctx = panelCtx })
    dbg('gang UI opened, ctx =', panelCtx)
end

-- THE DEN PANEL
local denPanelId = nil

function OpenDenPanel(denId)
    denId = tonumber(denId)
    if not denId then return end
    local d = Core.Callback.TriggerAwait('pup-gangs:getDenPanel', denId)
    if type(d) ~= 'table' then
        return exports['pup-ui']:Toast(Locale.denNotYours or 'That den is not yours.')
    end
    denPanelId = denId
    uiOpen = true
    SetNuiFocus(true, true)
    -- the GANG bundle rides along: the den's Claims and Raids tabs are the existing territory/fort pages
    SendNUIMessage({ action = 'open', mode = 'den', den = d, data = bundle(), config = uiConfig() })
    dbg('den panel opened for den', denId)
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    denPanelId = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- re-pull and push the bundle into the already-open page
local function pushData()
    if not uiOpen then return end
    if denPanelId then
        local d = Core.Callback.TriggerAwait('pup-gangs:getDenPanel', denPanelId)
        if type(d) == 'table' then
            SendNUIMessage({ action = 'data', mode = 'den', den = d, data = bundle() })
        end
        return
    end
    local b = bundle()
    if b then SendNUIMessage({ action = 'data', data = b, ctx = panelCtx }) end
end

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    uiOpen = false
    denPanelId = nil
    SetNuiFocus(false, false)
end)

-- THE BENCH COUNTDOWN
-- while a den panel is up; 10s is fine for a five-minute job and costs one
-- callback, not a per-frame timer in the page.
CreateThread(function()
    while true do
        Wait(10000)
        if uiOpen and denPanelId then pushData() end
    end
end)

-- every page action lands here and fans out to the server events
RegisterNUICallback('act', function(req, cb)
    cb('ok')
    local id = tostring(req and req.id or '')
    dbg('ui action:', id)

    if id == 'create' then
        TriggerServerEvent('pup-gangs:create', tostring(req.name or ''), tostring(req.faction or ''), tostring(req.short or ''))
        SetTimeout(700, pushData)
    elseif id == 'invite' then
        local target = GetClosestPlayer()
        if not target then return exports['pup-ui']:Toast('Nobody nearby.') end
        TriggerServerEvent('pup-gangs:invite', GetPlayerServerId(target))
    elseif id == 'promote' then
        TriggerServerEvent('pup-gangs:setRank', tonumber(req.charid), tonumber(req.rank))
        SetTimeout(600, pushData)
    elseif id == 'rank:save' then
        TriggerServerEvent('pup-gangs:rankSave', tonumber(req.index), tostring(req.label or ''), req.perms)
        SetTimeout(600, pushData)
    elseif id == 'rank:add' then
        TriggerServerEvent('pup-gangs:rankAdd', tostring(req.label or ''))
        SetTimeout(600, pushData)
    elseif id == 'rank:remove' then
        TriggerServerEvent('pup-gangs:rankRemove', tonumber(req.index))
        SetTimeout(600, pushData)
    elseif id == 'setcolor' then
        TriggerServerEvent('pup-gangs:setColor', tostring(req.key or ''))
        SetTimeout(600, pushData)
    elseif id == 'fortraid' then
        closeUi() -- the raid happens in the world, not in a menu
        TriggerServerEvent('pup-gangs:startFortRaid', tonumber(req.index))
    elseif id == 'bench' then
        TriggerServerEvent('pup-gangs:benchCraft', tonumber(req.tid), tonumber(req.index))
        SetTimeout(700, pushData)
    elseif id == 'kick' then
        TriggerServerEvent('pup-gangs:kick', tonumber(req.charid))
        SetTimeout(600, pushData)
    elseif id == 'leave' then
        TriggerServerEvent('pup-gangs:leave')
        SetTimeout(600, pushData)
    elseif id == 'declarewar' then
        TriggerServerEvent('pup-gangs:declareWar', tonumber(req.gangid))
        SetTimeout(600, pushData)
    elseif id == 'claim' then
        -- the target is picked in the panel (a claim is a 20-minute siege)
        TriggerServerEvent('pup-gangs:claimTerritory', tonumber(req.territoryId))
        SetTimeout(800, pushData)
    elseif id == 'placetable' then
        closeUi()
        PlaceGangTable()   -- client/features.lua: house context + placement gizmo
        SetTimeout(900, function() OpenGangPanel('perks') end)
    elseif id == 'pickuptable' then
        TriggerServerEvent('pup-gangs:pickupTable')
        SetTimeout(700, pushData)
    elseif id == 'stash' then
        -- vorp_inventory opens its own panel; ours must be gone first
        closeUi()
        TriggerServerEvent('pup-gangs:openStash', tostring(req.key or ''))
    elseif id == 'takepackage' then
        TriggerServerEvent('pup-gangs:takePackage')
        SetTimeout(600, pushData)
    elseif id == 'dens:designate' then
        closeUi()
        DesignateDen()   -- client/features.lua: house context + server gates
        SetTimeout(900, function() OpenGangPanel('perks') end)
    elseif id == 'dens:shutdown' then
        TriggerServerEvent('pup-gangs:shutdownDen', tonumber(req.tid))
        SetTimeout(600, pushData)

    -- ---------------------------------------------------------------- den panel
    elseif id == 'den:collect' then
        TriggerServerEvent('pup-gangs:collectDen', tonumber(req.tid))
        SetTimeout(700, pushData)
    elseif id == 'den:cook' then
        TriggerServerEvent('pup-gangs:startCook', tonumber(req.tid))
        SetTimeout(700, pushData)
    elseif id == 'den:run' then
        closeUi() -- a delivery run happens in the world
        TriggerServerEvent('pup-gangs:takePackage')
    elseif id == 'den:craft' then
        TriggerServerEvent('pup-gangs:benchCraft', tonumber(req.tid), tonumber(req.index))
        SetTimeout(900, pushData)
    elseif id == 'den:raid' then
        closeUi() -- so is a raid
        TriggerServerEvent('pup-gangs:startRaid', tonumber(req.target))
    elseif id == 'blood:deposit' then
        TriggerServerEvent('pup-gangs:bloodDeposit', 0)   -- 0 = bank the lot
        SetTimeout(700, pushData)
    elseif id == 'blood:slot' then
        TriggerServerEvent('pup-gangs:bloodBuySlot')
        SetTimeout(700, pushData)
    elseif id == 'blood:perk' then
        TriggerServerEvent('pup-gangs:bloodBuyPerk', tostring(req.flag or ''))
        SetTimeout(800, pushData)
    elseif id == 'den:stash' then
        -- vorp_inventory opens its own panel; ours must be gone first
        closeUi()
        TriggerServerEvent('pup-gangs:openStash', 'den')
    elseif id == 'den:gangpanel' then
        -- hand over to the GANG panel in den context (territory claims + fort raids)
        closeUi()
        SetTimeout(150, function() OpenGangPanel('territory', 'den') end)

    -- ----------------------------------------------------------- the gang drug
    -- The name is typed in the panel's own field, the same way the gang name and
    -- the rank labels are: the panel holds NUI focus, and a pup-ui input opened
    -- on top of it would fight for that focus. The server validates the name.
    elseif id == 'drug:create' then
        TriggerServerEvent('pup-gangs:drugCreate', tostring(req.name or ''), tostring(req.icon or ''))
        SetTimeout(800, pushData)
    elseif id == 'drug:rename' then
        TriggerServerEvent('pup-gangs:drugRename', tostring(req.name or ''))
        SetTimeout(800, pushData)
    elseif id == 'drug:icon' then
        TriggerServerEvent('pup-gangs:drugIcon', tostring(req.icon or ''))
        SetTimeout(700, pushData)
    elseif id == 'drug:seeds' then
        TriggerServerEvent('pup-gangs:drugBuySeeds', tonumber(req.batches) or 1)
        SetTimeout(800, pushData)
    elseif id == 'drug:unlock' then
        TriggerServerEvent('pup-gangs:drugUnlock', tostring(req.node or ''))
        SetTimeout(800, pushData)
    end
end)

RegisterNetEvent('pup-gangs:refresh', function()
    if uiOpen then pushData() end
end)

RegisterNetEvent('pup-gangs:inviteReceived', function(info)
    pendingInvite = info
    exports['pup-ui']:Toast(('%s invited you. Open /%s to accept.'):format(info.name or 'A gang', Config.General.panelCommand or 'gang'))
end)

-- Helpers
function GetClosestPlayer()
    local me = PlayerPedId()
    local myCoords = GetEntityCoords(me)
    local best, bestDist = nil, 5.0
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= me then
            local d = #(myCoords - GetEntityCoords(ped))
            if d < bestDist then best, bestDist = player, d end
        end
    end
    return best
end

-- MAP LAYER - one radius blip per territory/HQ
local territoryBlips = {}

local function clearTerritoryBlips()
    for blip in pairs(territoryBlips) do
        if DoesBlipExist(blip) then pcall(function() RemoveBlip(blip) end) end
    end
    territoryBlips = {}
end

local function drawTerritories(list)
    clearTerritoryBlips()
    knownTerritories = list or {}
    if not Config.Map.enabled then return end

    -- WORLD MAP vs GANG MAP (Config.Map.worldBlips)
    local mode <const> = Config.Map.worldBlips or 'all'
    if mode == 'none' then
        dbg('world-map territory blips off (worldBlips = none)')
        return
    end

    local toDraw = knownTerritories
    if mode == 'owned' then
        toDraw = {}
        for _, t in ipairs(knownTerritories) do
            if t.gang then toDraw[#toDraw + 1] = t end
        end
    end

    for _, t in ipairs(toDraw) do
        local blip
        if t.gang and Config.Map.worldCircles then
            -- painted influence circle in-game (off by default: the world map stays clean)
            blip = Citizen.InvokeNative(0x45F13B7E0A15C880, 1664425300,
                t.x + 0.0, t.y + 0.0, t.z + 0.0, (tonumber(t.radius) or Config.Map.baseRadius) + 0.0)
        else
            -- clean POINT marker (faction-coloured for owned ground, plain for unclaimed forts)
            blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300,
                t.x + 0.0, t.y + 0.0, t.z + 0.0)
        end
        if blip then
            territoryBlips[blip] = true
            if Config.Map.blipSprite and Config.Map.blipSprite ~= '' then
                pcall(function() SetBlipSprite(blip, GetHashKey(Config.Map.blipSprite)) end)
            end
            if t.gang then
                pcall(function()
                    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey(t.color or 'BLIP_MODIFIER_MP_COLOR_32'))
                end)
            end
            if Config.Map.showName then
                -- the map reads TAG * POINTS * FACTION, e.g. "VPR * 1,284 PTS * THE OUTLAWS"
                local label
                if t.gang then
                    -- TAG + POINTS only
                    label = ('%s \u{2022} %s PTS'):format(
                        (t.short and t.short ~= '') and t.short or t.gang,
                        fmtPts(t.points))
                    if t.mine then label = label .. ' \u{2022} YOURS' end
                else
                    label = ('%s (unclaimed)'):format(t.name)
                end
                pcall(function() Citizen.InvokeNative(0x9CB1A1623062F402, blip, label) end)
            end
        end
    end
    dbg('drew', #toDraw, 'territory blip(s) of', #knownTerritories, 'known')
end

local function refreshTerritories()
    local list = Core.Callback.TriggerAwait('pup-gangs:getTerritories')
    if type(list) == 'table' then
        drawTerritories(list)
        -- keep an open page's map live too
        if uiOpen then SendNUIMessage({ action = 'territories', territories = knownTerritories }) end
    end
end

RegisterNetEvent('pup-gangs:territoriesDirty', function()
    refreshTerritories()
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(3000)
    refreshTerritories()
    while true do
        Wait(math.max(10, Config.Map.refreshSeconds) * 1000)
        refreshTerritories()
    end
end)

-- which UNCLAIMED territory is the player standing in?
function ClosestTerritory()
    local coords = GetEntityCoords(PlayerPedId())
    for _, t in ipairs(knownTerritories) do
        local d = #(coords - vector3(t.x, t.y, t.z))
        if d <= (tonumber(t.radius) or Config.Map.baseRadius) and t.gangid == nil then
            return t
        end
    end
    return nil
end

-- the RIVAL-held territory the player is standing in, if any
function RivalTerritoryHere()
    local coords = GetEntityCoords(PlayerPedId())
    for _, t in ipairs(knownTerritories) do
        if t.gangid and not t.mine then
            local d = #(coords - vector3(t.x, t.y, t.z))
            if d <= (tonumber(t.radius) or Config.Map.baseRadius) then return t end
        end
    end
    return nil
end

-- entry point for the world prompts in client/features.lua: G at the table lands on the hideout page
function OpenStashPicker()
    OpenGangPanel('perks')
end

-- COMMANDS
if (Config.General.panelCommand or '') ~= '' then
    RegisterCommand(Config.General.panelCommand, function()
        if pendingInvite then
            TriggerServerEvent('pup-gangs:acceptInvite')
            pendingInvite = nil
            if Config.General.menuAnywhere then SetTimeout(600, function() OpenGangPanel() end) end
            return
        end
        if Config.General.menuAnywhere then return OpenGangPanel() end
        exports['pup-ui']:Toast(Locale.menuAtTable)
    end, false)
end

if (Config.General.createCommand or '') ~= '' then
    RegisterCommand(Config.General.createCommand, function()
        if Config.General.menuAnywhere then return OpenGangPanel() end
        exports['pup-ui']:Toast(Locale.createAtTable)
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearTerritoryBlips()
    if uiOpen then SetNuiFocus(false, false) end
end)
