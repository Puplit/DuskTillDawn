-- Modified by Puppet (Dusk Till Dawn), 2026
-- ADMIN DASHBOARD (pup-ui "app" panel)
local T = Translation.Langs[Config.General.language]

local DASH_OWNER <const> = 'vorp_admin:dash'

local DASH_TABS <const> = {
    { id = 'dashboard', label = 'Dashboard', icon = 'home' },
    { id = 'main',      label = 'Main',      icon = 'star' },
    { id = 'players',   label = 'Players',   icon = 'users' },
    { id = 'economy',   label = 'Economy',   icon = 'coins' },
    { id = 'teleports', label = 'Teleports', icon = 'flag' },
    { id = 'items',     label = 'Items',     icon = 'box' },
    { id = 'dev',       label = 'Dev Tools', icon = 'doc' },
    { id = 'security',  label = 'Anti-Cheat', icon = 'skull' },
}

-- nav gate per tab: the SAME menu-permission keys the admin.lua submenus check
local TAB_GATES <const> = {
    dashboard = 'open_menu',
    main      = 'admin_actions_menu',
    players   = 'players_list_menu',
    economy   = 'open_menu', -- read-only analytics; server callback re-gates with the same key
    teleports = 'teleport_menu',
    items     = 'admin_actions_menu', -- DB item editor: browse needs the strong key too
    dev       = 'devtools_menu',
    security  = 'anticheat_panel',
}

local dashOpen = false
local currentTab = 'dashboard'
local dashInfo = nil    -- last vorp_admin:Callback:getDashboard payload
local playersCache = {} -- [serverId] = playersInfo row from vorp_admin:Callback:getplayersinfo
local freezeState = {}  -- [serverId] = bool (dashboard-local toggle; same event/payload as admin.lua)

-- helpers
local function fmtUptime(seconds)
    seconds = tonumber(seconds) or 0
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm"):format(m)
end

-- thousands-separated numbers: fmtNum(994270.5) -> "994,270", fmtNum(1234567.5, 2) -> "1,234,567.50"
local function fmtNum(v, decimals)
    local n = tonumber(v) or 0
    local s = decimals and ("%." .. decimals .. "f"):format(n) or ("%d"):format(math.floor(n))
    local sign, int, frac = s:match("^(%-?)(%d+)(.*)$")
    int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. int .. frac
end

local function fmtCash(v) -- compact whole-dollar form for player rows
    return "$" .. fmtNum(v)
end

local function fmtGold(v) -- whole when integer, 2dp otherwise (gold can be fractional)
    local n = tonumber(v) or 0
    if n == math.floor(n) then return fmtNum(n) end
    return fmtNum(n, 2)
end

-- NBSP gap between sub-line segments: plain runs of spaces collapse to one in NUI html
local SEG_GAP <const> = "\u{00A0}\u{00A0}\u{00A0}"

local function refreshDashInfo()
    local info = VORP.Callback.TriggerAwait("vorp_admin:Callback:getDashboard")
    if info then dashInfo = info end
end

local function closeDash()
    dashOpen = false
    exports['pup-ui']:CloseApp()
end

-- pup-ui's input panel replaces the app panel, so close the app FIRST (CloseApp fires no appClosed), then run the input
local function dashInputPrompt(title, fields, subtitle)
    closeDash()
    return AskInput(title, fields, subtitle)
end

-- PROP PLACER - put a prop where you want it and get the coordinate back
LastPlaceModel = LastPlaceModel or nil
local PLACE_OWNER <const> = 'vorp_admin:placeprop'

-- Copy + print one placement in every shape these configs actually want
local function reportPlacement(model, x, y, z, h, rot)
    -- the clipboard gets the heist/stage shape - the one being typed most often
    local main = ('{ x = %.3f, y = %.3f, z = %.3f }'):format(x, y, z)
    local okc = pcall(function() SendNUIMessage({ string = main }) end)

    print('^3[prop placer]^7 ' .. tostring(model) .. ' placed:')
    print(('  stage/loot   pos = { x = %.3f, y = %.3f, z = %.3f },'):format(x, y, z))
    print(('  station cfg  Pos = {x = %.3f, y = %.3f, z = %.3f},'):format(x, y, z))
    print(('  vector4      vector4(%.3f, %.3f, %.3f, %.3f)'):format(x, y, z, h))
    print(('  raw          %.3f %.3f %.3f  heading %.3f'):format(x, y, z, h))
    if rot then
        print(('  rotation     rot = { x = %.3f, y = %.3f, z = %.3f },  -- pitch, roll, yaw'):format(rot.x, rot.y, rot.z))
    end

    VORP.NotifyObjective(okc and 'Coordinate copied - see F8 for every format'
        or 'Placed - see F8 console (clipboard unavailable)', 5000)

    -- KEEP IT? The prop above is local and gone on the next restart. pup-props can
    -- make it permanent for everyone; the coordinates are copied either way.
    if GetResourceState('pup-props') ~= 'started' then return end
    CreateThread(function()
        Wait(400)
        local vals = AskInput('Keep this prop?', {
            { label = 'Type KEEP to make it permanent', type = 'text', required = false },
        }, ('%s would stay for everyone until removed. Blank = coordinates only.'):format(tostring(model)))
        if not (vals and vals[1] and tostring(vals[1]):upper() == 'KEEP') then return end

        TriggerServerEvent('pup-props:place', {
            model = model, x = x, y = y, z = z,
            rx = rot and rot.x or 0.0,
            ry = rot and rot.y or 0.0,
            rz = rot and rot.z or h,
        })
    end)
end

function PlaceProp(model)
    -- devtools_menu, not get_coords: one key for the whole Tools/Dev set
    if not IsAdminAllowed('devtools_menu') then return end

    if not model or model == '' then
        local vals = dashInputPrompt('Prop Placer', {
            { label = 'Prop model name', type = 'text', placeholder = 'p_dynamite01x', required = true },
        }, 'Look where you want it. Arrows = distance/height, G = ground, ENTER = place.')
        if not vals or not vals[1] or vals[1] == '' then return end
        model = tostring(vals[1]):gsub('%s+', '')
    else
        closeDash()
    end

    LastPlaceModel = model

    local ok = exports['pup-ui']:StartPlacement({
        owner    = PLACE_OWNER,
        model    = model,
        grounded = false,   -- a charge on a door is NOT on the ground
        title    = 'Place ' .. model,
    })
    if not ok then
        VORP.NotifyObjective('Could not load model: ' .. model, 4000)
    end
end

AddEventHandler('pup-ui:client:placeConfirm', function(owner, place)
    if owner ~= PLACE_OWNER or not place then return end

    reportPlacement(LastPlaceModel, place.x or 0.0, place.y or 0.0, place.z or 0.0, place.heading or 0.0)
end)

AddEventHandler('pup-ui:client:placeCancel', function(owner)
    if owner ~= PLACE_OWNER then return end
    VORP.NotifyObjective('Placement cancelled', 2500)
end)
local function dashLoadModel(model)
    if not IsModelInCdimage(model) then
        print("invalid model")
        return false
    end
    if not HasModelLoaded(model) then
        RequestModel(model, false)
        repeat Wait(0) until HasModelLoaded(model)
    end
    return true
end

-- PROP PLACER - GIZMO MODE. The crosshair placer above rides a camera raycast and only
-- sets a heading; this one uses vorp_lib's drag gizmo, so pitch and roll can be set too.

-- Where the camera is pointing, or 4m ahead when the ray hits nothing.
local function camRayPoint(maxDist)
    local ped <const> = PlayerPedId()
    local rot <const> = GetGameplayCamRot(2)
    local rz <const> = math.rad(rot.z)
    local rx <const> = math.rad(rot.x)
    local cosx <const> = math.cos(rx)
    -- same rotation->direction as devTools.lua's dev laser
    local dir <const> = vector3(-math.sin(rz) * cosx, math.cos(rz) * cosx, math.sin(rx))
    local start <const> = GetGameplayCamCoord()
    local dest <const> = start + (dir * maxDist)

    local ray <const> = StartShapeTestRay(start.x, start.y, start.z, dest.x, dest.y, dest.z, -1, ped, 0)
    local _, hit, endCoords = GetShapeTestResult(ray)

    if (hit == 1 or hit == true) and endCoords then
        -- lifted clear of the surface so the drag handles are grabbable rather than buried in the wall or floor it landed on
        return vector3(endCoords.x, endCoords.y, endCoords.z + 0.25)
    end
    return start + (dir * 4.0)
end

function PlacePropGizmo(model)
    if not IsAdminAllowed('devtools_menu') then return end

    if not model or model == '' then
        local vals = dashInputPrompt('Prop Placer (gizmo)', {
            { label = 'Prop model name', type = 'text', placeholder = 'p_dynamite01x', required = true },
        }, 'Drag the handles. T = move/rotate, WASD/QE = camera, ALT = ground, ENTER = apply, ESC = cancel.')
        if not vals or not vals[1] or vals[1] == '' then return end
        model = tostring(vals[1]):gsub('%s+', '')
    else
        closeDash()
    end

    if GetResourceState('vorp_lib') ~= 'started' then
        return VORP.NotifyObjective('vorp_lib is not started - gizmo unavailable', 5000)
    end

    LastPlaceModel = model

    local hash <const> = joaat(model)
    if not dashLoadModel(hash) then
        return VORP.NotifyObjective('Could not load model: ' .. model, 4000)
    end

    local spawn <const> = camRayPoint(30.0)
    local obj = CreateObject(hash, spawn.x, spawn.y, spawn.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if obj == 0 or not DoesEntityExist(obj) then
        return VORP.NotifyObjective('Could not place: ' .. model, 4000)
    end

    -- collision off while dragging: a solid prop shoves the player and the world around and makes the gizmo unusable
    SetEntityCollision(obj, false, false)
    SetEntityAsMissionEntity(obj, true)

    -- alpha 200, NO ground snap (a charge on a door is not on the ground), we delete the prop ourselves
    local result = exports.vorp_lib:StartGizmo(obj, 200, false, false, true)

    -- the prop is only ever a ruler; the coordinate is the deliverable
    if DoesEntityExist(obj) then DeleteObject(obj) end

    if not result or not result.position then
        return VORP.NotifyObjective('Placement cancelled', 2500)
    end

    local p <const> = result.position
    local r <const> = result.rotation
    reportPlacement(model, p.x, p.y, p.z, (r and r.z or 0.0) % 360.0, r)
end

-- permission filtering: dashInfo.perms is the set the server resolved for THIS player (Discord roles or group)
function AdminHasPerm(key)
    if not key then return true end -- unmarked rows stay visible
    local p = dashInfo and dashInfo.perms
    if not p then return true end   -- payload not in yet; server still gates
    if p.all then return true end
    return p[key] == true
end

-- strips entries whose `perm` the player lacks; returns nil if nothing survives so an empty block can be dropped entirely
local function keep(list)
    if type(list) ~= 'table' then return list end
    local out = {}
    for _, entry in ipairs(list) do
        if AdminHasPerm(entry.perm) then
            if entry.actions then entry.actions = keep(entry.actions) end
            if entry.actions == nil or #entry.actions > 0 or entry.perm then
                out[#out + 1] = entry
            end
        end
    end
    return out
end

-- Sidebar tabs the player can actually open
function visibleTabs()
    local out = {}
    for _, tab in ipairs(DASH_TABS) do
        if tab.id == 'dashboard' or AdminHasPerm(TAB_GATES[tab.id] or 'open_menu') then
            out[#out + 1] = tab
        end
    end
    return out
end

--- drops any actions/list block left empty by the filter above
local function prune(blocks)
    local out = {}
    for _, b in ipairs(blocks) do
        if b.buttons then
            b.buttons = keep(b.buttons)
            if #b.buttons > 0 then out[#out + 1] = b end
        elseif b.items and b.type == 'list' then
            b.items = keep(b.items)
            if #b.items > 0 then out[#out + 1] = b end
        else
            out[#out + 1] = b
        end
    end
    return out
end

-- tab content builders (pup-ui app blocks)
local function buildDashboardContent()
    local d = dashInfo or {}
    return prune({
        { type = 'heading', text = 'Dashboard', sub = 'Server overview · quick staff actions' },
        { type = 'stats', items = {
            { value = tostring(d.playerCount or 0), label = 'Online' },
            { value = tostring(d.maxPlayers or 0),  label = 'Max' },
            { value = tostring(d.staffCount or 0),  label = 'Staff' },
            { value = fmtUptime(d.uptime),          label = 'Uptime' },
        } },
        { type = 'heading', text = 'Quick Actions', sub = 'Server-validated staff actions' },
        { type = 'actions', buttons = {
            { id = 'selfHeal',   label = 'Heal Self', tone = 'green', perm = 'selfheal' },
            { id = 'selfRevive', label = 'Revive Self', tone = 'green', perm = 'selfrevive' },
            { id = 'godmode',    label = 'Godmode', perm = 'godmode' },
            { id = 'noclip',     label = 'NoClip', perm = 'noclip' },
            { id = 'invisible',  label = 'Invisible', perm = 'troll_invisible' },
            { id = 'tpWaypoint', label = 'TP to Waypoint', perm = 'tp_to_waypoint' },
            { id = 'announce',   label = 'Announcement', tone = 'red', perm = 'allow_announce' },
            { id = 'refresh',    label = 'Refresh', tone = 'ghost' },
        } },
    })
end

local function buildMainContent()
    return {
        { type = 'heading', text = 'Main', sub = 'Player mode · teleports · spawns · announcements' },
        { type = 'list', items = {
            { title = 'Player Mode', sub = 'Godmode · invisibility · noclip · infinite ammo · golden cores',
                actions = {
                    { id = 'godmode',   label = 'GOD', perm = 'godmode' },
                    { id = 'invisible', label = 'INVIS', perm = 'troll_invisible' },
                    { id = 'noclip',    label = 'NOCLIP', perm = 'noclip' },
                    { id = 'infAmmo',   label = 'AMMO', perm = 'infinite_ammo' },
                    { id = 'goldCores', label = 'CORES', perm = 'golden_cores' },
                } },
            { title = 'Self', sub = 'Heal or revive your own character',
                actions = {
                    { id = 'selfHeal',   label = 'HEAL', tone = 'green', perm = 'selfheal' },
                    { id = 'selfRevive', label = 'REVIVE', tone = 'green', perm = 'selfrevive' },
                } },
            { title = 'Teleport', sub = 'Waypoint · entered coordinates · back to your last location',
                actions = {
                    { id = 'tpWaypoint', label = 'WAYPOINT', perm = 'tp_to_waypoint' },
                    { id = 'tpCoords',   label = 'COORDS', perm = 'tp_to_coords' },
                    { id = 'tpBack',     label = 'GO BACK', perm = 'tp_player_back' },
                } },
            { title = 'Spawn', sub = 'Horse or wagon by model name · logged server-side',
                actions = {
                    { id = 'spawnHorse', label = 'HORSE', perm = 'spawn_horse' },
                    { id = 'spawnWagon', label = 'WAGON', perm = 'spawn_wagon' },
                } },
            { title = 'Delete', sub = 'Your mount · current wagon · all wagons in a radius',
                actions = {
                    { id = 'delHorse',        label = 'HORSE', perm = 'spawn_horse' },
                    { id = 'delWagon',        label = 'WAGON', perm = 'spawn_wagon' },
                    { id = 'delWagonsRadius', label = 'RADIUS', perm = 'spawn_wagon' },
                } },
            { title = 'Announcement', sub = 'Broadcast a message to everyone on the server',
                actions = { { id = 'announce', label = 'ANNOUNCE', tone = 'red' } } },
            { title = 'Reports', sub = 'View open player reports',
                actions = { { id = 'viewReports', label = 'VIEW' } } },
            { title = 'Offline Actions', sub = 'Ban or unban by static ID · whitelist by steam identifier',
                actions = {
                    { id = 'offlineBan',       label = 'BAN / UNBAN', tone = 'red', perm = 'ban_offline' },
                    { id = 'offlineWhitelist', label = 'WHITELIST', perm = 'whitelist_player' },
                } },
            { title = 'Coordinates', sub = 'Copy your current position to the clipboard',
                actions = {
                    { id = 'coordsXYZ',     label = 'X,Y,Z' },
                    { id = 'coordsV3',      label = 'VEC3' },
                    { id = 'coordsV4',      label = 'VEC4' },
                    { id = 'coordsHeading', label = 'HEADING' },
                } },
        } },
    }
end

local function fetchPlayers()
    local result = VORP.Callback.TriggerAwait("vorp_admin:Callback:getplayersinfo", { search = "all" })
    playersCache = {}
    local sorted = {}
    if result then
        for _, info in pairs(result) do
            sorted[#sorted + 1] = info
            playersCache[tonumber(info.serverId) or -1] = info
        end
        table.sort(sorted, function(a, b) return a.serverId < b.serverId end)
    end
    return sorted
end

local function buildPlayersContent()
    local sorted = fetchPlayers()
    local items = {}
    for _, p in ipairs(sorted) do
        -- one short line of essentials; noise dropped (default group, empty WL, matching steam name)
        local seg = {}
        if p.Group and p.Group ~= "user" then
            seg[#seg + 1] = tostring(p.Group)
        end
        if p.Job then
            seg[#seg + 1] = ("%s · grade %s"):format(tostring(p.Job), tostring(p.Grade or 0))
        end
        seg[#seg + 1] = ("%s · %sg"):format(fmtCash(p.Money), fmtGold(p.Gold))
        if p.name and p.name ~= "" and p.name ~= p.PlayerName then
            seg[#seg + 1] = "aka " .. tostring(p.name)
        end
        if p.WLstatus and p.WLstatus ~= "" and p.WLstatus ~= "no status" then
            seg[#seg + 1] = "wl: " .. tostring(p.WLstatus)
        end
        items[#items + 1] = {
            title = ("%s\u{00A0} (ID %s)"):format(p.PlayerName or "?", tostring(p.serverId)),
            sub = table.concat(seg, SEG_GAP),
            actions = {
                { id = 'pl:goto:' .. p.serverId,     label = 'GOTO', perm = 'tp_to_player' },
                { id = 'pl:bring:' .. p.serverId,    label = 'BRING', perm = 'bring_player' },
                { id = 'pl:heal:' .. p.serverId,     label = 'HEAL', tone = 'green', perm = 'heal_player' },
                { id = 'pl:revive:' .. p.serverId,   label = 'REVIVE', tone = 'green', perm = 'revive_player' },
                { id = 'pl:freeze:' .. p.serverId,   label = 'FREEZE', perm = 'freeze_player' },
                { id = 'pl:spectate:' .. p.serverId, label = 'SPECTATE', perm = 'spectate' },
                { id = 'pl:pobox:' .. p.serverId,    label = 'PO BOX', perm = 'admin_actions_menu' },
                { id = 'pl:kick:' .. p.serverId,     label = 'KICK', tone = 'red', perm = 'kick_player' },
                { id = 'pl:ban:' .. p.serverId,      label = 'BAN', tone = 'red', perm = 'ban_player' },
            },
        }
    end
    local d = dashInfo or {} -- cached getDashboard payload; no extra fetch
    return {
        { type = 'heading', text = 'Players',
            sub = 'Row actions here; deeper character edits live on the web panel' },
        { type = 'stats', items = {
            { value = tostring(#items),             label = 'Online' },
            { value = tostring(d.staffCount or 0),  label = 'Staff' },
            { value = tostring(d.maxPlayers or 0),  label = 'Max' },
        } },
        { type = 'actions', buttons = {
            { id = 'refreshPlayers', label = 'Refresh', tone = 'ghost' },
        } },
        { type = 'list', items = items },
    }
end

local function buildTeleportsContent()
    return {
        { type = 'heading', text = 'Teleports', sub = 'Waypoint · coordinates · players · Guarma' },
        { type = 'list', items = {
            { title = 'Waypoint', sub = 'Teleport to your active map waypoint',
                actions = { { id = 'tpWaypoint', label = 'TELEPORT', perm = 'tp_to_waypoint' } } },
            { title = 'Auto Waypoint', sub = 'Re-teleport to each new waypoint you set · toggle',
                actions = { { id = 'tpAuto', label = 'TOGGLE' } } },
            { title = 'Coordinates', sub = 'Teleport to entered x, y, z',
                actions = { { id = 'tpCoords', label = 'ENTER COORDS', perm = 'tp_to_coords' } } },
            { title = 'To Player', sub = 'Teleport yourself to a player by server ID',
                actions = { { id = 'tpToPlayerId', label = 'ENTER ID' } } },
            { title = 'Go Back', sub = 'Return to where you were before the last teleport',
                actions = { { id = 'tpBack', label = 'GO BACK', perm = 'tp_player_back' } } },
            { title = 'Bring Player', sub = 'Bring a player to your position by server ID',
                actions = { { id = 'bringPlayerId', label = 'ENTER ID' } } },
            { title = 'Send Player Back', sub = 'Return a brought player to where they were',
                actions = { { id = 'sendPlayerBackId', label = 'ENTER ID' } } },
            { title = 'Guarma', sub = 'Travel to Guarma · back to the mainland if you are there',
                actions = { { id = 'guarma', label = 'TRAVEL' } } },
        } },
    }
end

local function buildDevContent()
    return {
        { type = 'heading', text = 'Dev Tools', sub = 'Coordinates · model spawning · inspection helpers' },
        { type = 'list', items = {
            { title = 'Copy Coordinates', sub = 'Copy your current position to the clipboard',
                actions = {
                    { id = 'coordsXYZ',     label = 'X,Y,Z' },
                    { id = 'coordsV3',      label = 'VEC3' },
                    { id = 'coordsV4',      label = 'VEC4' },
                    { id = 'coordsHeading', label = 'HEADING' },
                } },
            { title = 'Prop Placer', sub = 'Camera = fast position · Gizmo = drag handles with full rotation',
                actions = {
                    { id = 'devPlaceProp',  label = 'ENTER MODEL', perm = 'devtools_menu' },
                    { id = 'devPlaceAgain', label = 'REPEAT LAST', perm = 'devtools_menu' },
                    { id = 'devPlaceGizmo', label = 'GIZMO', perm = 'devtools_menu' },
                } },
            { title = 'Ped Menu', sub = 'Become another ped, or put one on a player · temporary, a relog restores them',
                actions = { { id = 'pedMenu', label = 'OPEN', perm = 'ped_menu' } } },
            { title = 'Spawn Ped', sub = 'Spawn a ped in front of you by model name',
                actions = { { id = 'devSpawnPed', label = 'ENTER MODEL' } } },
            { title = 'Spawn Wagon', sub = 'Spawn a wagon by model name and sit in it',
                actions = { { id = 'devSpawnWagon', label = 'ENTER MODEL' } } },
            { title = 'Closest Object', sub = 'Print info about or delete the nearest object',
                actions = {
                    { id = 'devObjInfo',   label = 'INFO', perm = 'admin_actions_menu' },
                    { id = 'devObjDelete', label = 'DELETE', tone = 'red', perm = 'admin_actions_menu' },
                } },
            { title = 'Dev Laser', sub = 'Aim raycast with entity info · H copies info, G copies vector3',
                actions = { { id = 'devLaser', label = 'TOGGLE' } } },
            { title = 'Interior ID', sub = 'Print your current interior to the console',
                actions = { { id = 'devInterior', label = 'PRINT' } } },
            { title = 'Imap Viewer', sub = 'Runs the imapview command',
                actions = { { id = 'devImap', label = 'TOGGLE' } } },
        } },
    }
end

-- ECONOMY tab: READ-ONLY server-wide money analytics (vorp_admin:Callback:getEconomy)
local function fmtDollars(v)
    if v == nil then return 'N/A' end
    return "$" .. fmtNum(v, 2)
end

local function buildEconomyContent()
    local econ = VORP.Callback.TriggerAwait("vorp_admin:Callback:getEconomy")
    if not econ then
        return {
            { type = 'heading', text = 'Economy', sub = 'No data returned — no permission or a server error' },
            { type = 'actions', buttons = { { id = 'econRefresh', label = 'Refresh', tone = 'ghost' } } },
        }
    end
    local t = econ.totals or {}

    -- clans + underground + housing rolled up (nil-safe: excluded blocks count as 0)
    local otherSum = nil
    for _, k in ipairs({ 'clans', 'underground', 'housing' }) do
        if t[k] ~= nil then otherSum = (otherSum or 0) + t[k] end
    end

    -- the server caches these aggregates for a minute (17 SUMs over the whole database)
    local age = tonumber(econ.ageSeconds) or 0
    local freshness = age < 2 and 'just recalculated'
        or ('as of %ds ago'):format(age)

    local blocks = {
        { type = 'heading', text = 'Economy',
            sub = ('Read-only · sums from the database, %s · nothing here moves money'):format(freshness) },
        { type = 'stats', items = {
            { value = fmtDollars(t.cash),   label = 'Total Cash' },
            { value = t.gold ~= nil and fmtGold(t.gold) or 'N/A', label = 'Total Gold' },
            { value = fmtDollars(t.banked), label = 'Total Banked' },
            { value = fmtDollars(t.grand),  label = 'Grand Total' },
        } },
        { type = 'stats', items = {
            { value = fmtDollars(t.societies),        label = 'Societies' },
            { value = fmtDollars(t.playerShops),      label = 'Player Shops' },
            { value = fmtDollars(t.ranches),          label = 'Ranches' },
            { value = fmtDollars(otherSum),           label = 'Clans + Other' },
        } },
    }

    -- misc holdings: zero-value entries are noise — show a source only when it holds money
    local misc = {}
    for _, m in ipairs({
        { key = 'clans',            label = 'Clans' },
        { key = 'underground',      label = 'Underground' },
        { key = 'housing',          label = 'Housing' },
        { key = 'billsOutstanding', label = 'Bills Outstanding' },
    }) do
        if (tonumber(t[m.key]) or 0) > 0 then
            misc[#misc + 1] = { value = fmtDollars(t[m.key]), label = m.label }
        end
    end
    if #misc > 0 then
        blocks[#blocks + 1] = { type = 'stats', items = misc }
    end

    blocks[#blocks + 1] = { type = 'actions', buttons = {
        { id = 'econRefresh', label = 'Refresh', tone = 'ghost' },
    } }

    if econ.societies and #econ.societies > 0 then
        local rows = {}
        for _, s in ipairs(econ.societies) do
            rows[#rows + 1] = { cells = {
                job    = { text = tostring(s.job) },
                ledger = { text = fmtDollars(s.ledger), tone = 'pos' },
            } }
        end
        blocks[#blocks + 1] = { type = 'table', title = 'Society Ledgers',
            columns = { { key = 'job', label = 'Job' }, { key = 'ledger', label = 'Ledger' } },
            rows = rows }
    end

    if econ.topHolders and #econ.topHolders > 0 then
        local rows = {}
        for i, h in ipairs(econ.topHolders) do
            rows[#rows + 1] = { cells = {
                rank   = { text = tostring(i), tone = 'muted' },
                name   = { text = tostring(h.name) },
                cash   = { text = fmtDollars(h.cash), tone = 'pos' },
                banked = { text = fmtDollars(h.banked), tone = 'pos' },
                total  = { text = fmtDollars(h.total), tone = 'pos' },
            } }
        end
        blocks[#blocks + 1] = { type = 'table', title = 'Top Money Holders',
            columns = {
                { key = 'rank',   label = '#' },
                { key = 'name',   label = 'Name' },
                { key = 'cash',   label = 'Cash' },
                { key = 'banked', label = 'Banked' },
                { key = 'total',  label = 'Total' },
            },
            rows = rows }
    end

    if econ.shops and #econ.shops > 0 then
        local rows = {}
        for _, s in ipairs(econ.shops) do
            rows[#rows + 1] = { cells = {
                name   = { text = tostring(s.name) },
                kind   = { text = tostring(s.type or 'player'):upper(), tone = 'badge-neutral' },
                ledger = { text = fmtDollars(s.ledger), tone = 'pos' },
            } }
        end
        blocks[#blocks + 1] = { type = 'table', title = 'Top Shop Ledgers',
            columns = {
                { key = 'name',   label = 'Shop' },
                { key = 'kind',   label = 'Type' },
                { key = 'ledger', label = 'Ledger' },
            },
            rows = rows }
    end

    if econ.ranches and #econ.ranches > 0 then
        local rows = {}
        for _, r in ipairs(econ.ranches) do
            rows[#rows + 1] = { cells = {
                name   = { text = tostring(r.name) },
                ledger = { text = fmtDollars(r.ledger), tone = 'pos' },
            } }
        end
        blocks[#blocks + 1] = { type = 'table', title = 'Top Ranch Ledgers',
            columns = { { key = 'name', label = 'Ranch' }, { key = 'ledger', label = 'Ledger' } },
            rows = rows }
    end

    if econ.missing and #econ.missing > 0 then
        blocks[#blocks + 1] = { type = 'heading', text = 'Unavailable Sources',
            sub = table.concat(econ.missing, ' · ') .. ' — table or column not found; excluded from the totals' }
    end

    return blocks
end

-- ITEMS tab: browse/edit the `items` DB table (vorp_admin:Callback:itemsSearch + items:update)
local itemsCache = { rows = {}, total = 0, term = "", loaded = false,
                     view = nil, detail = nil } -- view = item name drilled into

-- one row per DB column of the detail page, in display order. kind drives the edit input
local ITEM_DETAIL_FIELDS <const> = {
    { col = 'label',        kind = 'text',   hint = 'display name' },
    { col = 'limit',        kind = 'number', hint = '-1 = unlimited' },
    { col = 'weight',       kind = 'number', hint = 'decimal, e.g. 0.25' },
    { col = 'type',         kind = 'text',   hint = 'e.g. item_standard' },
    { col = 'usable',       kind = 'bool',   hint = 'can be Used from the satchel' },
    { col = 'can_remove',   kind = 'bool',   hint = 'can be dropped/removed' },
    { col = 'useExpired',   kind = 'bool',   hint = 'usable after expiry' },
    { col = 'degradation',  kind = 'number', hint = '0 = never decays' },
    { col = 'durability',   kind = 'number', hint = '-1 = NULL (unset)' },
    { col = 'groupId',      kind = 'number', hint = 'inventory filter group' },
    { col = 'rarityId',     kind = 'number', hint = 'rarity filter' },
    { col = 'desc',         kind = 'text',   hint = 'item description' },
    { col = 'metadata',     kind = 'text',   hint = 'raw JSON - validated server-side' },
    { col = 'instructions', kind = 'text',   hint = 'empty = NULL' },
}

local function refreshItems(term)
    if term ~= nil then itemsCache.term = term end
    local res = VORP.Callback.TriggerAwait("vorp_admin:Callback:itemsSearch", { term = itemsCache.term })
    if res then
        itemsCache.rows = res.rows or {}
        itemsCache.total = res.total or 0
        itemsCache.loaded = true
    end
end

local function fetchItemDetail(name)
    local row = VORP.Callback.TriggerAwait("vorp_admin:Callback:itemsGet", { item = name })
    if row then
        itemsCache.view, itemsCache.detail = name, row
    else
        itemsCache.view, itemsCache.detail = nil, nil
    end
end

local function shortVal(v, kind)
    if v == nil then return 'NULL' end
    if kind == 'bool' then return (tonumber(v) == 1) and 'yes' or 'no' end
    local s = tostring(v)
    if #s > 60 then s = s:sub(1, 57) .. '...' end
    if s == '' then s = '(empty)' end
    return s
end

local function buildItemsContent()
    -- DETAIL page: every DB column of one item, each with its own Edit
    if itemsCache.view and itemsCache.detail then
        local d = itemsCache.detail
        local rows = {}
        for i, f in ipairs(ITEM_DETAIL_FIELDS) do
            rows[#rows + 1] = {
                title = f.col,
                sub = ('%s%s%s'):format(shortVal(d[f.col], f.kind), SEG_GAP, f.hint),
                actions = { { id = ('it:set:%d'):format(i), label = 'Edit' } },
            }
        end
        return {
            { type = 'heading', text = itemsCache.view,
              sub = ('DB id %s%sEdits apply in-game only after a vorp_inventory restart')
                  :format(tostring(d.id or '?'), SEG_GAP) },
            { type = 'list', items = rows },
            { type = 'list', items = {
                { title = 'Back to list', actions = { { id = 'it:back', label = 'Back' } } },
                { title = 'Delete this item', sub = 'Permanent - removes the DB row',
                  actions = { { id = 'it:del', label = 'Delete' } } },
            } },
        }
    end

    -- LIST page
    local blocks = {
        { type = 'heading', text = 'Items Database',
          sub = ('%d item definitions in the DB%sEdits apply in-game only after a vorp_inventory restart')
              :format(itemsCache.total or 0, SEG_GAP) },
        { type = 'list', items = { {
            title = 'Search',
            sub = itemsCache.term ~= '' and ('Filter: "%s"  (first 30 matches)'):format(itemsCache.term)
                  or 'Showing first 30 of all items',
            actions = {
                { id = 'it:search', label = 'Search' },
                { id = 'it:clear',  label = 'Clear' },
            },
        }, {
            title = 'Create a new item',
            sub = 'Adds a row to the items table' .. SEG_GAP
                .. 'Everything else takes its default and can be edited after',
            actions = { { id = 'it:new', label = 'Create' } },
        } } },
    }
    local rows = {}
    for _, r in ipairs(itemsCache.rows) do
        local lim = tonumber(r.limit)
        rows[#rows + 1] = {
            title = r.item,
            sub = ('%s%slimit %s%s%.2fkg%s%s%s%s'):format(
                r.label or '-', SEG_GAP,
                (lim == -1) and 'unlimited' or tostring(lim or '?'), SEG_GAP,
                tonumber(r.weight) or 0, SEG_GAP,
                tostring(r.type or '-'), SEG_GAP,
                (tonumber(r.usable) == 1) and 'usable' or 'not usable'),
            actions = { { id = 'it:view:' .. r.item, label = 'Open' } },
        }
    end
    if #rows == 0 then
        rows[1] = { title = itemsCache.loaded and 'No matches' or 'Loading...',
                    sub = itemsCache.loaded and 'Try another search term' or '' }
    end
    blocks[#blocks + 1] = { type = 'list', items = rows }
    return blocks
end

local function reopenItemsTab()
    currentTab = 'items'
    if itemsCache.view then fetchItemDetail(itemsCache.view) else refreshItems() end
    OpenAdminDashboard()
    exports['pup-ui']:UpdateApp({ active = 'items', content = buildItemsContent() })
end

local flagCache = { loaded = false, data = nil }

local function refreshFlags()
    local r = VORP.Callback.TriggerAwait("vorp_admin:Callback:getFlags")
    flagCache.data = r or false
    flagCache.loaded = true
end

local function agoText(at, now)
    local s = math.max(0, (now or os.time()) - (at or 0))
    if s < 60 then return s .. 's ago' end
    if s < 3600 then return math.floor(s / 60) .. 'm ago' end
    if s < 86400 then return math.floor(s / 3600) .. 'h ago' end
    return math.floor(s / 86400) .. 'd ago'
end

local function buildSecurityContent()
    local d = flagCache.data
    if d == false or d == nil then
        return { { type = 'heading', text = 'Anti-Cheat', sub = 'No access, or nothing loaded yet' } }
    end

    local blocks = {
        { type = 'heading', text = 'Anti-Cheat', sub = 'Detections are evidence, not proof - spectate before acting' },
        { type = 'stats', items = {
            { value = tostring(#(d.flags or {})), label = 'Recent Flags' },
            { value = tostring(d.guardBlocked or 0), label = 'Spawns Blocked' },
            { value = tostring(d.guardMode or 'off'):upper(), label = 'Guard Mode' },
            { value = d.kickOn and 'KICK' or 'LOG', label = 'Response' },
        } },
    }

    local det = {}
    if d.teleportOn then det[#det + 1] = 'teleport' end
    if d.noclipOn then det[#det + 1] = 'noclip' end
    det[#det + 1] = 'spawn guard (server-side)'
    blocks[#blocks + 1] = { type = 'heading', text = 'Detectors', sub = table.concat(det, '  |  ') ..
        '  -  teleport and noclip run client-side and can be defeated; the spawn guard cannot' }

    local now = os.time()
    local rows = {}
    for _, f in ipairs(d.flags or {}) do
        -- spawn and cash are server-side facts; movement flags are client-reported
        local hard = (f.kind == 'spawn' or f.kind == 'cash')
        local tone = hard and 'badge-red' or 'badge-neutral'
        rows[#rows + 1] = { cells = {
            when  = cell(agoText(f.at, now), 'muted'),
            who   = cell(f.name or '?'),
            kind  = cell((f.kind or ''):upper(), tone),
            what  = cell(f.detail or ''),
            total = cell(f.total and tostring(f.total) or '-', (f.total or 0) >= 3 and 'neg' or 'muted'),
        } }
    end

    if #rows == 0 then
        blocks[#blocks + 1] = { type = 'heading', sub = 'No flags recorded. Nothing to look at - that is the good outcome.' }
    else
        blocks[#blocks + 1] = { type = 'table',
            columns = {
                { key = 'when',  label = 'When' },
                { key = 'who',   label = 'Player' },
                { key = 'kind',  label = 'Type' },
                { key = 'what',  label = 'Detail' },
                { key = 'total', label = 'Total' },
            },
            rows = rows }
    end

    -- World cleanup (server/pup_worldCleanup.lua). Only holders of anticheat_cleanup get the button.
    local wc = d.cleanup or {}
    local buttons = {}
    if d.canCleanup then
        local sub
        if wc.running then
            sub = ('Counting down: %ds left (started by %s)'):format(wc.secondsLeft or 0, tostring(wc.by or '?'))
        elseif wc.last then
            sub = ('Last run %s by %s: %d vehicles, %d peds, %d objects deleted, %d kept'):format(
                agoText(wc.last.at, now), tostring(wc.last.by or '?'),
                wc.last.vehicle or 0, wc.last.ped or 0, wc.last.object or 0, wc.last.kept or 0)
        else
            sub = 'Deletes every script-spawned wagon, horse, ped and prop after a chat countdown. Players are never touched, nor what they ride.'
        end
        blocks[#blocks + 1] = { type = 'heading', text = 'World Cleanup', sub = sub }
        if not wc.running then
            buttons[#buttons + 1] = { id = 'worldCleanup', label = 'Clear spawned entities', tone = 'red', perm = 'anticheat_cleanup' }
        end
    end
    buttons[#buttons + 1] = { id = 'flagsRefresh', label = 'Refresh', tone = 'ghost' }
    blocks[#blocks + 1] = { type = 'actions', buttons = buttons }
    return prune(blocks)
end

local function buildTabContent(tab)
    -- same per-menu permission the admin.lua submenus ask the server for
    if tab ~= 'dashboard' and not IsAdminAllowed(TAB_GATES[tab] or 'open_menu') then
        return { { type = 'heading', text = 'No Permission', sub = T.Notify.noperms } }
    end
    if tab == 'main' then return buildMainContent() end
    if tab == 'players' then return buildPlayersContent() end
    if tab == 'economy' then return buildEconomyContent() end
    if tab == 'teleports' then return buildTeleportsContent() end
    if tab == 'items' then
        if not itemsCache.loaded then refreshItems() end
        return buildItemsContent()
    end
    if tab == 'dev' then return buildDevContent() end
    if tab == 'security' then
        if not flagCache.loaded then refreshFlags() end
        return buildSecurityContent()
    end
    return buildDashboardContent()
end

-- open / reopen
local function openDashUI(tab)
    if not dashInfo then return end
    currentTab = tab or currentTab or 'dashboard'
    dashOpen = true
    local title = 'ADMIN'
    if dashInfo.serverName and dashInfo.serverName ~= "" then
        title = tostring(dashInfo.serverName):upper()
    end
    exports['pup-ui']:OpenApp({
        owner = DASH_OWNER,
        title = title,
        subtitle = 'MANAGEMENT',
        badge = tostring(dashInfo.group or 'STAFF'):upper(),
        tabs = visibleTabs(),
        active = currentTab,
        content = buildTabContent(currentTab),
    })
end

function OpenAdminDashboard()
    -- server re-validates with the same AllowedToExecuteAction("open_menu") gate
    local info = VORP.Callback.TriggerAwait("vorp_admin:Callback:getDashboard")
    if not info then
        return VORP.NotifyObjective(T.Notify.noperms, 5000)
    end
    dashInfo = info
    openDashUI('dashboard')
end

-- actions: per-player row buttons; every handler fires the SAME event/function as the admin.lua menu
local PLAYER_ACTIONS = {
    ["goto"] = function(target, p) -- admin.lua BuildSimpleActionMenu playerGoTo
        closeDash()
        TriggerServerEvent("vorp_admin:TpToPlayer", target, 'vorp.staff.GoTo', p and p.PlayerName)
    end,
    bring = function(target, p) -- admin.lua playerBring
        local adminCoords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent("vorp_admin:Bring", target, adminCoords, 'vorp.staff.Bring', p and p.PlayerName)
    end,
    heal = function(target, p) -- admin.lua playerHeal
        TriggerServerEvent('vorp_admin:heal', target, 'vorp.staff.Heal', p and p.PlayerName)
    end,
    revive = function(target, p) -- admin.lua playerRevive
        TriggerServerEvent('vorp_admin:revive', target, 'vorp.staff.Revive', p and p.PlayerName)
    end,
    freeze = function(target, p) -- admin.lua playerFreeze (same event/payload; toggle kept per target)
        local state = not freezeState[target]
        freezeState[target] = state
        if state then
            TriggerServerEvent("vorp_admin:freeze", target, true, 'vorp.staff.Frezee', p and p.PlayerName)
            TriggerEvent("vorp:TipRight", T.Notify.switchedOn, 3000)
        else
            TriggerServerEvent("vorp_admin:freeze", target, false, 'vorp.staff.Frezee')
            TriggerEvent("vorp:TipRight", T.Notify.switchedOff, 3000)
        end
    end,
    spectate = function(target, p) -- admin.lua playerSpectate
        closeDash()
        TriggerServerEvent("vorp_admin:spectate", target, 'vorp.staff.Spectate', p and p.PlayerName)
    end,
    -- change a player's mail PO Box
    pobox = function(target, p)
        if not p then return end
        local who = p.PlayerName or ('ID ' .. target)
        local current = VORP.Callback.TriggerAwait("vorp_admin:Callback:getPoBox", target)

        if current then -- MOVE an existing box
            local vals = dashInputPrompt('PO Box — ' .. who, {
                { label = 'New PO Box number', type = 'number',
                  placeholder = 'current: ' .. current, required = true },
            }, 'Enter a whole number above 0')
            if vals and vals[1] then
                TriggerServerEvent('vorp_admin:setPoBox', target, tonumber(vals[1]), p.PlayerName)
            end
        else            -- no box: registering one is a separate, deliberate call
            local vals = dashInputPrompt('Register a PO Box — ' .. who, {
                { label = 'PO Box number (leave blank for the next free one)',
                  type = 'number', placeholder = 'blank = next free', required = false },
            })
            if vals then
                TriggerServerEvent('vorp_admin:createPoBox', target, tonumber(vals[1]), p.PlayerName)
            end
        end
        openDashUI('players')
    end,
    kick = function(target, p) -- admin.lua BuildAdvancedActions playerKick (same staff guard)
        if not p then return end
        local vals = dashInputPrompt(T.Menus.SubAdvancedActionOptions.KickInput.title, {
            { label = T.Menus.SubAdvancedActionOptions.KickInput.placeholder, type = 'text', placeholder = T.Menus.SubAdvancedActionOptions.KickInput.placeholder, required = true }
        }, T.Menus.SubAdvancedActionOptions.KickInput.errorMsg)
        if vals then
            local reason = tostring(vals[1])
            if reason ~= "" then
                if p.Group ~= "user" then
                    TriggerEvent("vorp:TipRight", T.Notify.cantKickStaff, 4000)
                else
                    TriggerServerEvent("vorp_admin:kick", target, reason, 'vorp.staff.Kick', p.PlayerName)
                end
            else
                VORP.NotifyObjective(T.Notify.empty, 5000)
            end
        end
        openDashUI('players')
    end,
    ban = function(target, p) -- admin.lua playerBan (same staff guard + staticID payload)
        if not p then return end
        local vals = dashInputPrompt(T.Menus.SubAdvancedActionOptions.BanInput.title, {
            { label = T.Menus.SubAdvancedActionOptions.BanInput.placeholder, type = 'text', placeholder = T.Menus.SubAdvancedActionOptions.BanInput.placeholder, required = true }
        }, T.Menus.SubAdvancedActionOptions.BanInput.errorMsg)
        if vals then
            local time = tostring(vals[1])
            if time ~= "" then
                if p.Group ~= "user" then
                    TriggerEvent("vorp:TipRight", T.Notify.cantBanStaff, 4000)
                else
                    TriggerServerEvent("vorp_admin:BanPlayer", target, p.staticID, time, 'vorp.staff.Ban', p.PlayerName)
                end
            else
                VORP.NotifyObjective(T.Notify.empty, 5000)
            end
        end
        openDashUI('players')
    end,
}

local ACTIONS = {
    ------------------------------------------------------------------ player mode / boosters
    godmode = function() -- boosters.lua selfGodMode
        if IsAdminAllowed("godmode") then GODmode() end
    end,
    invisible = function() -- boosters.lua selfInvisible
        if IsAdminAllowed("invisibility") then ToggleInvisible() end
    end,
    noclip = function() -- boosters.lua selfNoClip (close first: noclip is unusable under fullscreen NUI)
        if IsAdminAllowed("noclip") then
            closeDash()
            ToggleNoClip()
        end
    end,
    infAmmo = function() -- boosters.lua enabledInfinityAmmo
        if IsAdminAllowed("infinite_ammo") then InfiAmmo() end
    end,
    goldCores = function() -- boosters.lua selfGoldCores
        if IsAdminAllowed("golden_cores") then GoldenCores() end
    end,
    selfHeal = function() -- boosters.lua selfHeal -> vorp_admin:HealSelf (server-checked)
        SelfHeal()
    end,
    selfRevive = function() -- boosters.lua selfRevive -> vorp_admin:ReviveSelf (server-checked)
        TriggerServerEvent('vorp_admin:ReviveSelf', "selfrevive")
    end,

    ------------------------------------------------------------------ teleports
    tpWaypoint = function() -- teleport.lua tpmToMarker -> vorp:teleportWayPoint (server-checked)
        closeDash()
        TpToWaypoint()
    end,
    tpAuto = function() -- teleport.lua tpmAuto toggle
        closeDash()
        ToggleAutoTPM()
    end,
    tpCoords = function() -- teleport.lua tpToCoords (same gate + input + event)
        if not IsAdminAllowed("tp_to_coords") then return end
        local vals = dashInputPrompt(T.Menus.MainTeleportOptions.InsertCoordsInput.title, {
            { label = 'X', type = 'number', placeholder = 'X', required = true },
            { label = 'Y', type = 'number', placeholder = 'Y', required = true },
            { label = 'Z', type = 'number', placeholder = 'Z', required = true },
        }, T.Menus.MainTeleportOptions.InsertCoordsInput.errorMsg)
        if not vals then return openDashUI(currentTab) end
        local x, y, z = tonumber(vals[1]), tonumber(vals[2]), tonumber(vals[3])
        if x and y and z then
            TeleportToCoords(x, y, z) -- stays closed so the fade/teleport is visible
        else
            VORP.NotifyObjective(T.Notify.empty, 5000)
            openDashUI(currentTab)
        end
    end,
    tpToPlayerId = function() -- teleport.lua tpToPlayer -> vorp_admin:TpToPlayer (server-checked)
        local vals = dashInputPrompt(T.Menus.DefaultsInputs.confirm, {
            { label = T.Menus.DefaultsInputs.serverID, type = 'number', placeholder = T.Menus.DefaultsInputs.serverID, required = true }
        })
        if not vals then return openDashUI(currentTab) end
        local TargetID = tonumber(vals[1])
        if TargetID then
            TriggerServerEvent("vorp_admin:TpToPlayer", TargetID)
        else
            VORP.NotifyObjective(T.Notify.empty, 5000)
            openDashUI(currentTab)
        end
    end,
    tpBack = function() -- teleport.lua adminGoBackLastLocation -> vorp_admin:sendAdminBack
        closeDash()
        TriggerServerEvent("vorp_admin:sendAdminBack")
    end,
    bringPlayerId = function() -- teleport.lua bringPlayer -> vorp_admin:Bring (same payload shape)
        local vals = dashInputPrompt(T.Menus.DefaultsInputs.confirm, {
            { label = T.Menus.DefaultsInputs.serverID, type = 'number', placeholder = T.Menus.DefaultsInputs.serverID, required = true }
        })
        if vals then
            local TargetID = tonumber(vals[1])
            if TargetID then
                local adminCoords = GetEntityCoords(PlayerPedId())
                TriggerServerEvent("vorp_admin:Bring", TargetID, adminCoords, "", nil, TargetID)
            else
                VORP.NotifyObjective(T.Notify.empty, 5000)
            end
        end
        openDashUI(currentTab)
    end,
    sendPlayerBackId = function() -- teleport.lua sendPlayerToLastLocation -> vorp_admin:TeleportPlayerBack
        local vals = dashInputPrompt(T.Menus.DefaultsInputs.confirm, {
            { label = T.Menus.DefaultsInputs.serverID, type = 'number', placeholder = T.Menus.DefaultsInputs.serverID, required = true }
        })
        if vals then
            local TargetID = tonumber(vals[1])
            if TargetID then
                TriggerServerEvent("vorp_admin:TeleportPlayerBack", TargetID)
            else
                TriggerEvent("vorp:TipRight", T.Notify.goToPlayerFirst, 4000)
            end
        end
        openDashUI(currentTab)
    end,
    guarma = function() -- teleport.lua teleportToGuarma (same gate)
        if not IsAdminAllowed("teleport_to_guarma") then return end
        closeDash()
        ToggleGuarma()
    end,

    ------------------------------------------------------------------ spawns / deletes
    spawnHorse = function() -- boosters.lua spawnHorse (same gate + input + logged event)
        if not IsAdminAllowed("spawn_horse") then return end
        local vals = dashInputPrompt(T.Menus.MainBoostOptions.SpawnHorseInput.title, {
            { label = T.Menus.MainBoostOptions.SpawnHorseInput.placeholder, type = 'text', placeholder = T.Menus.MainBoostOptions.SpawnHorseInput.placeholder, required = true }
        }, T.Menus.MainBoostOptions.SpawnHorseInput.errorMsg)
        if not vals then return openDashUI(currentTab) end
        local horse_model = tostring(vals[1])
        if horse_model ~= "" then
            SpawnHorseModel(horse_model) -- stays closed: you are being sat on the horse
        else
            VORP.NotifyObjective(T.Notify.empty, 3000)
            openDashUI(currentTab)
        end
    end,
    spawnWagon = function() -- boosters.lua spawnWagon
        if not IsAdminAllowed("spawn_wagon") then return end
        local vals = dashInputPrompt(T.Menus.MainBoostOptions.SpawnWagonInput.title, {
            { label = T.Menus.MainBoostOptions.SpawnWagonInput.placeholder, type = 'text', placeholder = T.Menus.MainBoostOptions.SpawnWagonInput.placeholder, required = true }
        }, T.Menus.MainBoostOptions.SpawnWagonInput.errorMsg)
        if not vals then return openDashUI(currentTab) end
        local wagon_model = tostring(vals[1])
        if wagon_model ~= "" then
            SpawnWagonModel(wagon_model) -- stays closed: you are being sat in the wagon
        else
            VORP.NotifyObjective(T.Notify.empty, 3000)
            openDashUI(currentTab)
        end
    end,
    delHorse = function() -- admin.lua deleteMountHorse
        if IsAdminAllowed('delete_horse') then
            TriggerEvent("vorp:delHorse")
        end
    end,
    delWagon = function() -- admin.lua deleteMountWagon
        if IsAdminAllowed('delete_wagon') then
            Delwagon()
        end
    end,
    delWagonsRadius = function() -- admin.lua deleteWagonInRadius
        if not IsAdminAllowed('delete_wagons_radius') then return end
        local vals = dashInputPrompt(T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.title, {
            { label = T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.placeholder, type = 'number', placeholder = T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.placeholder, required = true }
        }, T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.errorMsg)
        if vals then
            local radius = tonumber(vals[1])
            if radius then
                TriggerEvent("vorp:deleteVehicle", radius)
            else
                VORP.NotifyObjective(T.Notify.empty, 5000)
            end
        end
        openDashUI(currentTab)
    end,

    ------------------------------------------------------------------ announce / reports / offline
    announce = function() -- admin.lua adminAnnounce -> vorp_admin:announce (server-checked)
        local vals = dashInputPrompt(T.Menus.SubActionsAdminOptions.AnnounceInput.title, {
            { label = T.Menus.SubActionsAdminOptions.AnnounceInput.placeholder, type = 'text', placeholder = T.Menus.SubActionsAdminOptions.AnnounceInput.placeholder, required = true }
        }, T.Menus.SubActionsAdminOptions.AnnounceInput.errorMsg)
        if vals then
            local announce = vals[1]
            if announce and announce ~= "" then
                TriggerServerEvent("vorp_admin:announce", announce)
            else
                VORP.NotifyObjective(T.Notify.empty, 5000)
            end
        end
        openDashUI(currentTab)
    end,
    viewReports = function() -- admin.lua viewReports (same gate + event)
        if not IsAdminAllowed('view_reports_menu') then return end
        closeDash()
        TriggerEvent("vorp_admin:viewreports")
    end,
    offlineBan = function() -- admin.lua BuildOffLine banOrUnban (same gate + events)
        if not IsAdminAllowed('offline_actions_menu') then return end
        local vals = dashInputPrompt(T.Menus.SubOfflineOptions.BanTypeInput.title, {
            { label = 'Type', type = 'select', required = true, default = 'ban',
                options = { { label = 'ban', value = 'ban' }, { label = 'unban', value = 'unban' } } },
            { label = 'Static ID', type = 'number', placeholder = 'ID', required = true },
            { label = 'Time (1h/1d/1w/1m/1y, 0 = perma)', type = 'text', placeholder = '1d' },
        }, T.Menus.SubOfflineOptions.BanTypeInput.errorMsg)
        if vals then
            local btype = tostring(vals[1])
            local StaticID = tonumber(vals[2])
            local time = vals[3] and tostring(vals[3]) or ""
            if btype and StaticID then
                if btype == "ban" then
                    TriggerServerEvent("vorp_admin:BanOffline", StaticID, time, 'vorp.staff.Ban')
                elseif btype == "unban" then
                    TriggerServerEvent("vorp_admin:UnBan", StaticID, 'vorp.staff.Unban')
                else
                    VORP.NotifyObjective(T.Notify.incorrectType, 5000)
                end
            else
                VORP.NotifyObjective(T.Notify.missingArgument, 5000)
            end
        end
        openDashUI(currentTab)
    end,
    offlineWhitelist = function() -- admin.lua BuildOffLine whiteOrUnwhite (same gate + event + payload)
        if not IsAdminAllowed('offline_actions_menu') then return end
        local vals = dashInputPrompt(T.Menus.SubOfflineOptions.WhiteTypeInput.title, {
            { label = 'Type (whitelist)', type = 'text', placeholder = 'whitelist', required = true },
            { label = 'Steam ID', type = 'text', placeholder = 'steam:...', required = true },
        }, T.Menus.SubOfflineOptions.WhiteTypeInput.errorMsg)
        if vals then
            local wtype = tostring(vals[1])
            local steam = tostring(vals[2])
            if wtype and steam then
                if wtype == "whitelist" then
                    TriggerServerEvent("vorp_admin:Whitelistoffline", steam, wtype)
                else
                    VORP.NotifyObjective(T.Notify.incorrectType, 5000)
                end
            else
                VORP.NotifyObjective(T.Notify.missingArgument, 5000)
            end
        end
        openDashUI(currentTab)
    end,

    -- prop placer: reuses pup-ui's placement gizmo (the same one pup-housing and pup-clan furnish with)
    devPlaceProp  = function() PlaceProp(nil) end,
    devPlaceAgain = function() PlaceProp(LastPlaceModel) end,
    -- gizmo mode: drag handles instead of a raycast, and it reports pitch/roll as well as yaw
    devPlaceGizmo = function() PlacePropGizmo(nil) end,

    ------------------------------------------------------------------ coordinates (clipboard)
    coordsXYZ = function() if IsAdminAllowed('get_coords') then CopyToClipboard('v2') end end,
    coordsV3 = function() if IsAdminAllowed('get_coords') then CopyToClipboard('v3') end end,
    coordsV4 = function() if IsAdminAllowed('get_coords') then CopyToClipboard('v4') end end,
    coordsHeading = function() if IsAdminAllowed('get_coords') then CopyToClipboard('heading') end end,

    ------------------------------------------------------------------ players tab utilities
    refreshPlayers = function()
        exports['pup-ui']:UpdateApp({ active = 'players', content = buildPlayersContent() })
    end,
    econRefresh = function() -- read-only: rebuilds the tab, which refetches getEconomy
        exports['pup-ui']:UpdateApp({ active = 'economy', content = buildEconomyContent() })
    end,
    flagsRefresh = function()
        refreshFlags()
        exports['pup-ui']:UpdateApp({ active = 'security', content = buildSecurityContent() })
    end,
    worldCleanup = function() -- server/pup_worldCleanup.lua re-checks anticheat_cleanup
        local vals = dashInputPrompt('Clear spawned entities', {
            { label = 'Type CLEAR to confirm', type = 'text', required = true },
        }, 'Every script-spawned wagon, horse, ped and prop is deleted for everyone after a chat countdown.')
        if vals and tostring(vals[1] or ''):upper() == 'CLEAR' then
            TriggerServerEvent('vorp_admin:worldCleanup:start')
            Wait(600)
        end
        refreshFlags()
        openDashUI('security')
    end,
    refresh = function()
        refreshDashInfo()
        exports['pup-ui']:UpdateApp({ active = 'dashboard', content = buildDashboardContent() })
    end,

    ------------------------------------------------------------------ dev tab
    devSpawnPed = function() -- devTools.lua spawnPedWithInput (same body)
        local vals = dashInputPrompt(T.Menus.MainDevToolsOptions.SpawnPedInput.title, {
            { label = T.Menus.MainDevToolsOptions.SpawnPedInput.placeholder, type = 'text', placeholder = T.Menus.MainDevToolsOptions.SpawnPedInput.placeholder, required = true }
        }, T.Menus.MainDevToolsOptions.SpawnPedInput.errorMsg)
        if vals then
            local ped = tostring(vals[1])
            if ped ~= "" then
                if dashLoadModel(ped) then
                    local offset = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 5.0, 0.0)
                    local npc = CreatePed(joaat(ped), offset.x, offset.y, offset.z, 0.0, true, true, true, false)
                    repeat Wait(0) until DoesEntityExist(npc)
                    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, npc, 1, 0)
                    SetModelAsNoLongerNeeded(ped)
                    SetEntityAsNoLongerNeeded(npc)
                end
            else
                TriggerEvent('vorp:TipRight', T.Notify.empty, 3000)
            end
        end
        openDashUI('dev')
    end,
    devSpawnWagon = function() -- devTools.lua spawnWagonWithInput (same body)
        local vals = dashInputPrompt(T.Menus.MainDevToolsOptions.SpawnWagonInput.title, {
            { label = T.Menus.MainDevToolsOptions.SpawnWagonInput.placeholder, type = 'text', placeholder = T.Menus.MainDevToolsOptions.SpawnWagonInput.placeholder, required = true }
        }, T.Menus.MainDevToolsOptions.SpawnWagonInput.errorMsg)
        if vals then
            local wagon = tostring(vals[1])
            if wagon ~= "" then
                if dashLoadModel(wagon) then
                    local player = PlayerPedId()
                    local playerCoords = GetOffsetFromEntityInWorldCoords(player, 0.0, 5.0, 0.0)
                    local Wagon = CreateVehicle(wagon, playerCoords.x, playerCoords.y, playerCoords.z, 0, true, true, true)
                    repeat Wait(0) until DoesEntityExist(Wagon)
                    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Wagon, 1, 0)
                    SetPedIntoVehicle(player, Wagon, -1)
                    SetModelAsNoLongerNeeded(wagon)
                    SetEntityAsNoLongerNeeded(Wagon)
                    return -- stays closed: you are in the wagon now
                end
            else
                TriggerEvent('vorp:TipRight', T.Notify.empty, 3000)
            end
        end
        openDashUI('dev')
    end,
    devObjInfo = function() -- devTools.lua printModel
        local coords = GetEntityCoords(PlayerPedId())
        local closestObject = GetClosestObject(coords)
        local objectCoords = GetEntityCoords(closestObject)
        local model = GetEntityModel(closestObject)
        print(T.Notify.closesObject .. " " .. model, objectCoords)
        TriggerEvent("vorp:TipRight", T.Notify.closesObject .. " " .. model, 6000)
    end,
    devObjDelete = function() -- devTools.lua deleteModel
        local coords = GetEntityCoords(PlayerPedId())
        local closestObject = GetClosestObject(coords)
        TriggerEvent("vorp:TipRight", T.Notify.closesObject .. " " .. closestObject, 4000)
        DeleteObject(closestObject)
    end,
    devLaser = function() -- devTools.lua devtoolOn (needs the world visible)
        closeDash()
        ToggleDevLaser()
    end,
    devInterior = function() -- devTools.lua interiorId
        local interiorId = GetInteriorFromEntity(PlayerPedId())
        print("interiorId", interiorId)
        TriggerEvent("vorp:TipRight", "interiorId " .. tostring(interiorId), 4000)
    end,
    devImap = function() -- devTools.lua imapViwer
        closeDash()
        ExecuteCommand("imapview")
    end,
    -- the ped menu is a pup-ui list, so the panel has to let go of the screen first
    pedMenu = function()
        closeDash()
        if BuildPedRoot then PupMenu.Open(BuildPedRoot()) end
    end,
    stableAdmin = function()
        closeDash()
        if BuildStableAdminRoot then
            local root = BuildStableAdminRoot()
            if root then PupMenu.Open(root) end
        end
    end,
}

-- pup-ui app events (owner-token filtered)
AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= DASH_OWNER then return end
    currentTab = tab
    if tab == 'dashboard' then refreshDashInfo() end
    exports['pup-ui']:UpdateApp({ active = tab, content = buildTabContent(tab) })
end)

AddEventHandler('pup-ui:client:appAction', function(owner, action, _)
    if owner ~= DASH_OWNER then return end
    local verb, idStr = tostring(action):match('^pl:(%w+):(%d+)$')
    if verb then
        local target = tonumber(idStr)
        local fn = PLAYER_ACTIONS[verb]
        if fn and target then fn(target, playersCache[target]) end
        return
    end
    -- ITEMS tab actions (it:search / it:clear / it:<verb>:<itemname>)
    if tostring(action):sub(1, 3) == 'it:' then
        if action == 'it:search' then
            local vals = dashInputPrompt('Search Items', {
                { label = 'Item name or label (empty = all)', type = 'text' },
            })
            refreshItems(vals and tostring(vals[1] or '') or itemsCache.term)
            reopenItemsTab()
            return
        end
        if action == 'it:clear' then
            refreshItems('')
            exports['pup-ui']:UpdateApp({ active = 'items', content = buildItemsContent() })
            return
        end
        -- open an item's detail page
        local viewName = tostring(action):match('^it:view:(.+)$')
        if viewName then
            fetchItemDetail(viewName)
            exports['pup-ui']:UpdateApp({ active = 'items', content = buildItemsContent() })
            return
        end
        if action == 'it:back' then
            itemsCache.view, itemsCache.detail = nil, nil
            refreshItems()
            exports['pup-ui']:UpdateApp({ active = 'items', content = buildItemsContent() })
            return
        end
        -- create a new item row; the server validates and refuses duplicates
        if action == 'it:new' then
            local vals = dashInputPrompt('Create Item', {
                { label = 'Item name (letters, numbers, underscore - this is the DB key)', type = 'text' },
                { label = 'Label (what players see)', type = 'text' },
                { label = 'Carry limit', type = 'number', default = 10 },
                { label = 'Usable', type = 'select', default = '0',
                  options = { { label = 'No', value = '0' }, { label = 'Yes', value = '1' } } },
            })
            if vals and tostring(vals[1] or '') ~= '' and tostring(vals[2] or '') ~= '' then
                TriggerServerEvent('vorp_admin:items:create', {
                    item   = tostring(vals[1]),
                    label  = tostring(vals[2]),
                    limit  = tonumber(vals[3]) or 10,
                    usable = (tostring(vals[4]) == '1') and 1 or 0,
                })
                Wait(400) -- let the insert land before the list re-reads
            end
            reopenItemsTab()
            return
        end
        -- edit one column of the open item (index into ITEM_DETAIL_FIELDS)
        local fidx = tonumber(tostring(action):match('^it:set:(%d+)$'))
        if fidx and itemsCache.view then
            local f = ITEM_DETAIL_FIELDS[fidx]
            if not f then return end
            local itemName = itemsCache.view
            local cur = itemsCache.detail and itemsCache.detail[f.col]
            local field
            if f.kind == 'bool' then
                field = { label = f.col .. ' (' .. f.hint .. ')', type = 'select',
                          default = (tonumber(cur) == 1) and '1' or '0',
                          options = { { label = 'Yes', value = '1' }, { label = 'No', value = '0' } } }
            elseif f.kind == 'number' then
                field = { label = f.col .. ' (' .. f.hint .. ')', type = 'number',
                          default = tonumber(cur) }
            else
                field = { label = f.col .. ' (' .. f.hint .. ')', type = 'text',
                          default = (cur ~= nil) and tostring(cur) or '' }
            end
            local vals = dashInputPrompt(('%s . %s'):format(itemName, f.col), { field })
            if vals and vals[1] ~= nil and tostring(vals[1]) ~= '' then
                local v = vals[1]
                if f.kind == 'bool' or f.kind == 'number' then v = tonumber(v) end
                TriggerServerEvent('vorp_admin:items:update', itemName, f.col, v)
                Wait(300) -- let the DB write land before re-reading
            elseif vals and f.col == 'instructions' then
                -- empty submit on instructions intentionally sets NULL
                TriggerServerEvent('vorp_admin:items:update', itemName, f.col, '')
                Wait(300)
            end
            reopenItemsTab()
            return
        end
        -- delete the OPEN item (detail page only)
        if action == 'it:del' and itemsCache.view then
            local itemName = itemsCache.view
            local vals = dashInputPrompt('Delete Item: ' .. itemName, {
                { label = ('Type DELETE to remove "%s" from the database'):format(itemName), type = 'text' },
            })
            if vals and tostring(vals[1] or ''):upper() == 'DELETE' then
                TriggerServerEvent('vorp_admin:items:update', itemName, 'delete')
                itemsCache.view, itemsCache.detail = nil, nil
                Wait(300)
            end
            reopenItemsTab()
            return
        end
        return
    end

    local fn = ACTIONS[action]
    if fn then fn() end
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= DASH_OWNER then return end
    dashOpen = false
    playersCache = {}
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if dashOpen then
        dashOpen = false
        exports['pup-ui']:CloseApp()
    end
end)

-- entry point override: this file loads LAST of the menu files

function OpenMenu()
    OpenAdminDashboard()
end
