-- pup-misc / outfitter - client half.
-- The shop menu, the placement preview, and drawing whatever the server says is
-- standing in the world. A propset is not a networked entity, so each client
-- builds its own copy of every placement from the shared list.

local owned = {}        -- what this character owns, from the server
local world = {}        -- [id] = { id, sku, owner, x, y, z, h }
local live = {}         -- [id] = { propset = hash } | { object = entity }
local placing = nil     -- the piece being positioned

local function dbg(fmt, ...)
    if not OutfitterConfig.General.debug then return end
    print(('^5[pup-misc/outfitter]^7 ' .. fmt):format(...))
end

local function tip(msg, ms)
    TriggerEvent('vorp:TipBottom', msg, ms or 4000)
end

-- ------------------------------------------------------------------ drawing

local function drawTextTop(text)
    local str = CreateVarString(10, 'LITERAL_STRING', text, Citizen.ResultAsLong())
    SetTextScale(0.35, 0.35)
    SetTextColor(255, 255, 255, 220)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    Citizen.InvokeNative(0xADA9255D, 10)
    DisplayText(str, 0.5, 0.86)
end

-- same call pup-stable's Marker() uses, argument for argument
local function marker(pos, size, r, g, b, a)
    Citizen.InvokeNative(0x2A32FAA57B937173, -1795314153,
        pos.x, pos.y, pos.z, 0, 0, 0, 0, 0, 0,
        size, size, 0.6, r, g, b, a, 0, 0, 2, 0, 0, 0, 0)
end

-- --------------------------------------------------------- world build/tear

local function buildCamp(entry)
    local hash = GetHashKey(entry.model)
    Citizen.InvokeNative(0xF3DE57A46D5585E9, hash) -- REQUEST_PROPSET
    local tries = 0
    while not Citizen.InvokeNative(0x48A88FC684C55FDC, hash) and tries < 20 do -- HAS_PROPSET_LOADED
        tries = tries + 1
        Wait(50)
    end
    if not Citizen.InvokeNative(0x48A88FC684C55FDC, hash) then
        Citizen.InvokeNative(0xB1964A83B345B4AB, hash) -- RELEASE_PROPSET
        return nil
    end
    -- CREATE_PROPSET_2 returns the id the remove native wants
    local id = Citizen.InvokeNative(0x899C97A1CCE7D483, hash,
        entry.x, entry.y, entry.z, entry.h or 0.0, 60.0, 1200.0, true, true)
    Citizen.InvokeNative(0xB1964A83B345B4AB, hash) -- RELEASE_PROPSET
    return id
end

local function buildGear(entry)
    local hash = GetHashKey(entry.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 3000 do Wait(10) t = t + 10 end
    if not HasModelLoaded(hash) then return nil end
    -- NOT networked: every client makes its own from the same list, so a
    -- networked object here would be one per player
    local obj = CreateObject(hash, entry.x, entry.y, entry.z, false, false, false)
    SetEntityHeading(obj, entry.h or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function showPiece(id)
    if live[id] then return end
    local entry = world[id]
    if not entry then return end
    local def = OutfitterIndex[entry.sku]
    if not def then return end

    local payload = { model = def.model, x = entry.x, y = entry.y, z = entry.z, h = entry.h }
    if def.kind == 'camp' then
        local propset = buildCamp(payload)
        if propset then live[id] = { propset = propset } end
    else
        local obj = buildGear(payload)
        if obj then live[id] = { object = obj } end
    end
end

local function hidePiece(id)
    local held = live[id]
    if not held then return end
    if held.propset then
        Citizen.InvokeNative(0x58AC173A55D9D7B4, held.propset, 1, 1) -- REMOVE_PROPSET
    elseif held.object and DoesEntityExist(held.object) then
        DeleteObject(held.object)
        if DoesEntityExist(held.object) then SetEntityAsNoLongerNeeded(held.object) end
    end
    live[id] = nil
end

local function hideEverything()
    for id in pairs(live) do hidePiece(id) end
end

-- near enough to see, far enough to forget
CreateThread(function()
    while true do
        Wait(OutfitterConfig.World.renderPollMs or 2000)
        if OutfitterConfig.General.enabled then
            local me = GetEntityCoords(PlayerPedId())
            local range = OutfitterConfig.World.renderDistance or 180.0
            for id, entry in pairs(world) do
                local near = #(me - vector3(entry.x, entry.y, entry.z)) <= range
                if near and not live[id] then
                    showPiece(id)
                elseif not near and live[id] then
                    hidePiece(id)
                end
            end
        end
    end
end)

RegisterNetEvent('pup-misc:outfitter:world', function(list)
    world = {}
    hideEverything()
    for _, entry in ipairs(list or {}) do world[tonumber(entry.id)] = entry end
    dbg('%d pieces in the world', #(list or {}))
end)

RegisterNetEvent('pup-misc:outfitter:added', function(entry)
    if not entry or not entry.id then return end
    world[tonumber(entry.id)] = entry
end)

RegisterNetEvent('pup-misc:outfitter:removed', function(id)
    id = tonumber(id)
    if not id then return end
    hidePiece(id)
    world[id] = nil
end)

-- does not redraw an open menu (PupMenu.Open resets to the root); submenus read `owned` when entered
RegisterNetEvent('pup-misc:outfitter:owned', function(list)
    owned = list or {}
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hideEverything()
end)

-- ask again after a character swap, the world list is per session
RegisterNetEvent('vorp:SelectedCharacter', function()
    CreateThread(function()
        Wait(5000)
        TriggerServerEvent('pup-misc:outfitter:request')
    end)
end)

-- --------------------------------------------------------------- placement

local function bannedHere(coords)
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, coords, 1)
    for _, name in ipairs(OutfitterConfig.Placement.bannedTowns or {}) do
        if town == GetHashKey(name) then return true end
    end
    return false
end

-- the stable's own G prompt sits within 3 m of the counter; refuse pitching there so G does not fire both
local stableSpots = nil

local function nearACounter(coords)
    if not stableSpots then
        stableSpots = {}
        local ok, cfg = pcall(function() return exports['pup-stable']:getConfig() end)
        if ok and type(cfg) == 'table' and type(cfg.Stables) == 'table' then
            for _, s in pairs(cfg.Stables) do
                local p = s.location
                if p and p.x and p.y and p.z then
                    stableSpots[#stableSpots + 1] = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
                end
            end
        end
        dbg('%d stable counters to keep clear of', #stableSpots)
    end
    for _, p in ipairs(stableSpots) do
        if #(coords - p) <= 5.0 then return true end
    end
    return false
end

function OutfitterBeginPlacing(item)
    if placing then return end
    local def = OutfitterIndex[item.sku]
    if not def then return end
    placing = { id = item.id, def = def, dist = OutfitterConfig.Placement.startDistance or 3.0, turn = 0.0 }
    tip((OutfitterLocale.pitching):format(def.label), 6000)
end

CreateThread(function()
    local K = OutfitterConfig.Keys
    -- one step per tap, then repeat on a clock while held, so the turn speed does not follow the framerate
    local holdStart, lastStep = nil, 0
    while true do
        if not placing then
            Wait(250)
            holdStart = nil
        else
            Wait(0)
            local ped = PlayerPedId()
            local me = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local aim = math.rad(heading + (placing.turn or 0.0))
            local spot = vector3(me.x - math.sin(aim) * placing.dist,
                                 me.y + math.cos(aim) * placing.dist,
                                 me.z)

            local atCounter = nearACounter(me)
            local blocked = atCounter or bannedHere(spot)
            if atCounter then
                marker(spot, 1.4, 170, 40, 30, 150)
                drawTextTop((OutfitterLocale.hudCounter):format(placing.def.label))
            elseif blocked then
                marker(spot, 1.4, 170, 40, 30, 150)
                drawTextTop((OutfitterLocale.hudTown):format(placing.def.label))
            else
                marker(spot, 1.4, 201, 162, 77, 150)
                drawTextTop((OutfitterLocale.hudPlace):format(placing.def.label))
            end

            local held = IsControlPressed(0, K.turnLeft) or IsControlPressed(0, K.turnRight)
                or IsControlPressed(0, K.further) or IsControlPressed(0, K.nearer)
            local nowMs = GetGameTimer()
            local step = false
            if not held then
                holdStart = nil
            elseif not holdStart then
                holdStart, lastStep, step = nowMs, nowMs, true
            elseif (nowMs - holdStart) >= 250 and (nowMs - lastStep) >= 40 then
                lastStep, step = nowMs, true
            end

            if step then
                local turn = OutfitterConfig.Placement.turnStepDegrees or 5.0
                local nudge = OutfitterConfig.Placement.stepDistance or 0.25
                if IsControlPressed(0, K.turnLeft) then placing.turn = (placing.turn - turn) % 360.0 end
                if IsControlPressed(0, K.turnRight) then placing.turn = (placing.turn + turn) % 360.0 end
                if IsControlPressed(0, K.further) then
                    placing.dist = math.min(OutfitterConfig.Placement.maxDistance, placing.dist + nudge)
                end
                if IsControlPressed(0, K.nearer) then
                    placing.dist = math.max(OutfitterConfig.Placement.minDistance, placing.dist - nudge)
                end
            end

            if IsControlJustPressed(0, K.cancel) then
                placing = nil
                tip(OutfitterLocale.cancelled, 3000)
            elseif IsControlJustPressed(0, K.place) then
                if atCounter then
                    tip(OutfitterLocale.awayFromCounter, 4000)
                elseif blocked then
                    tip(OutfitterLocale.tooCloseToTown, 4000)
                else
                    local found, groundZ = GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 2.0, false)
                    TriggerServerEvent('pup-misc:outfitter:place', placing.id,
                        spot.x, spot.y, found and groundZ or spot.z, (heading + placing.turn) % 360.0)
                    placing = nil
                end
            end
        end
    end
end)

-- -------------------------------------------------------------------- menu

local function money(n)
    return '$' .. tostring(math.floor(tonumber(n) or 0))
end

local function shopSpec(kind, title)
    local options = {}
    for _, def in ipairs(kind == 'camp' and OutfitterConfig.Camps or OutfitterConfig.Gear) do
        options[#options + 1] = {
            label = def.label,
            price = def.price,
            desc = kind == 'camp' and OutfitterLocale.campDesc or OutfitterLocale.gearDesc,
            action = function()
                TriggerServerEvent('pup-misc:outfitter:buy', def.sku)
            end,
            reopen = true,
        }
    end
    return { title = OutfitterLocale.title, subtitle = title, options = options }
end

local function kitSpec()
    local options = {}
    for _, item in ipairs(owned) do
        if item.placed then
            options[#options + 1] = {
                label = item.label,
                value = OutfitterLocale.valuePitched,
                desc = OutfitterLocale.pitchedDesc,
                action = function()
                    TriggerServerEvent('pup-misc:outfitter:pack', item.id)
                end,
                -- closes rather than reopening: PupMenu re-renders the spec it
                -- stored, so a list left open would still show what was packed
                close = true,
            }
        else
            options[#options + 1] = {
                label = item.label,
                value = OutfitterLocale.valueInWagon,
                desc = OutfitterLocale.inWagonDesc,
                action = function()
                    PupMenu.Close()
                    OutfitterBeginPlacing(item)
                end,
                close = true,
            }
        end
    end
    if #options == 0 then
        options[1] = { label = OutfitterLocale.emptyKit, desc = OutfitterLocale.emptyKitDesc, disabled = true }
    end
    return { title = OutfitterLocale.title, subtitle = OutfitterLocale.kit, options = options }
end

local function scrapSpec()
    local options = {}
    for _, item in ipairs(owned) do
        if not item.placed then
            options[#options + 1] = {
                label = item.label,
                desc = OutfitterLocale.scrapDesc,
                action = function()
                    TriggerServerEvent('pup-misc:outfitter:scrap', item.id)
                end,
                close = true,
            }
        end
    end
    if #options == 0 then
        options[1] = { label = OutfitterLocale.emptyScrap, desc = OutfitterLocale.emptyScrapDesc, disabled = true }
    end
    return { title = OutfitterLocale.title, subtitle = OutfitterLocale.scrap, options = options }
end

local function tally()
    local carried, pitched = 0, 0
    for _, item in ipairs(owned) do
        if item.placed then pitched = pitched + 1 else carried = carried + 1 end
    end
    return carried, pitched
end

-- two counters: the stable shop sells; the wagon pitches and packs

-- at the stable
function OutfitterShowShop()
    local carried, pitched = tally()
    PupMenu.Open({
        title = OutfitterLocale.title,
        subtitle = (OutfitterLocale.counts):format(carried, pitched),
        options = {
            { label = OutfitterLocale.camps, desc = OutfitterLocale.campsDesc, submenu = function() return shopSpec('camp', OutfitterLocale.camps) end },
            { label = OutfitterLocale.gear,  desc = OutfitterLocale.gearMenuDesc,     submenu = function() return shopSpec('gear', OutfitterLocale.gear) end },
        },
    })
end

-- at the wagon
function OutfitterShowKit()
    local carried, pitched = tally()
    PupMenu.Open({
        title = OutfitterLocale.title,
        subtitle = (OutfitterLocale.counts):format(carried, pitched),
        options = {
            { label = OutfitterLocale.kit,  desc = OutfitterLocale.kitDesc, submenu = kitSpec },
            { label = OutfitterLocale.scrap, desc = OutfitterLocale.scrapMenuDesc,        submenu = scrapSpec },
        },
    })
end

-- ------------------------------------------------------------ the way in

-- U, next to a wagon. The same bind pup-stable's horse menu uses, which is why
-- the loop below stands down while mounted or leading a horse: that menu owns
-- the key in those states and both would open at once.
local WAGON_KEY = OutfitterConfig.Keys.openKit
local WAGON_RANGE = OutfitterConfig.Wagon.range

-- a raw keybind still reaches the game while a NUI has the keyboard, so typing
-- a u into a letter box would otherwise open this
local function typing()
    return IsNuiFocused() or IsPauseMenuActive() or UpdateOnscreenKeyboard() == 0
end

-- the nearest wagon that came out of a stable. The state bag is pup-stable's,
-- set on every wagon it spawns, so a random world cart is not a shop counter.
local function wagonNearby()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist = nil, WAGON_RANGE
    for _, veh in pairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and Entity(veh).state.pup_stable_wagonID then
            local d = #(GetEntityCoords(veh) - coords)
            if d < bestDist then best, bestDist = veh, d end
        end
    end
    return best
end

CreateThread(function()
    while true do
        local wait = 700
        if OutfitterConfig.General.enabled and not placing and not (PupMenu and PupMenu.IsOpen()) then
            local ped = PlayerPedId()
            -- pup-stable's horse menu has U whenever a horse is involved
            -- pup-stable's wagon U menu has an Outfitter row; where that menu owns U, stand down
            if not IsPedOnMount(ped) and not IsPedLeadingHorse(ped) and not IsEntityDead(ped)
                and not LocalPlayer.state.pupWagonMenu then
                if wagonNearby() then
                    wait = 0
                    drawTextTop(OutfitterLocale.wagonHint)
                    if not typing()
                        and (IsControlJustReleased(0, WAGON_KEY) or IsDisabledControlJustReleased(0, WAGON_KEY)) then
                        TriggerEvent('pup-misc:outfitter:kit')
                    end
                end
            end
        end
        Wait(wait)
    end
end)

-- both are local events: pup-stable's menu row fires one on the same client and
-- the U loop above fires the other, so neither needs to be a net event
local function openCounter(show)
    if not OutfitterConfig.General.enabled then return end
    if placing then return end
    PupMenu.OnClose = function() end
    -- ask first, draw a moment later: the counts in the subtitle and the kit
    -- list both come from the server's answer
    TriggerServerEvent('pup-misc:outfitter:request')
    CreateThread(function()
        Wait(250)
        show()
    end)
end

-- lets pup-stable's wagon menu know whether to offer the Outfitter row
LocalPlayer.state:set('pupOutfitterEnabled', OutfitterConfig.General.enabled == true, false)

-- the stable sells
AddEventHandler('pup-misc:outfitter:shop', function() openCounter(OutfitterShowShop) end)
-- the wagon carries
AddEventHandler('pup-misc:outfitter:kit', function() openCounter(OutfitterShowKit) end)

CreateThread(function()
    Wait(6000)
    TriggerServerEvent('pup-misc:outfitter:request')
end)
