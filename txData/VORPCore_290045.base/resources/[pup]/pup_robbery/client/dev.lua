-- pup_robbery | test and debug tools. Test-mode tools need Config.TestMode.enabled; /testminigame
-- needs Config.Debug; /testenemy needs Config.Debug and an admin (checked on the server).

local preview = nil   -- bank id whose points are labelled
local draft = {}      -- /heistloot draft spots

local function testMode()
    if Config.TestMode.enabled then return true end
    C.tip(L('testOff'))
    return false
end

local function fmt(v) return ('vector3(%.3f, %.3f, %.3f)'):format(v.x, v.y, v.z) end

--------------------------------------------------------------------------------
-- /heistpreview key: labels at every configured point of a bank, and the whole plan in the console

local function previewPoints(b)
    local pts = {}
    local function add(pos, text) if pos then pts[#pts + 1] = { pos = pos, text = text } end end
    add(b.anchor, 'anchor')
    add(b.securityBox, 'security box')
    if b.prep then
        for i, box in ipairs(b.prep.boxes) do add(box.pos, ('prep %d: %s'):format(i, b.prep.label)) end
    end
    for key, e in pairs(b.entries) do add(e.pos, ('entry %s: %s'):format(key, e.label)) end
    for i, s in ipairs(b.stages) do add(s.pos, ('stage %d %s: %s'):format(i, s.id or '', s.label)) end
    if b.clue then add(b.clue.pos, 'clue: ' .. b.clue.label) end
    for i, d in ipairs(b.extraDoors) do add(d.pos, ('door %d: %s'):format(i, d.label or '')) end
    for i, spot in ipairs(b.loot) do add(spot.pos, ('loot %d: %s'):format(i, spot.label or '')) end
    for i, z in ipairs(b.escapeZones) do add(z.pos, ('escape %d: %s'):format(i, z.label or '')) end
    return pts
end

RegisterCommand('heistpreview', function(_, args)
    if not testMode() then return end
    if not C.cb('pup_robbery:isAdmin') then return C.tip(L('noPermission')) end
    local key = args[1]
    if preview == key or not key then preview = nil return end
    local b = Config.Banks[key]
    if not b then return C.tip(L('unknownKey', tostring(key))) end
    preview = key
    print(('[pup_robbery] plan for %s (%s): %d stage(s) wanted'):format(key, b.label, b.stageCount or #b.stages))
    for i, s in ipairs(b.stages) do
        print(('  stage %d %s "%s" game=%s tool=%s always=%s last=%s vault=%s onlyVia=%s neverVia=%s alt=%s'):format(
            i, s.id or '', s.label, s.game, tostring(s.tool), tostring(s.always == true), tostring(s.last == true),
            tostring(s.opensVault == true), table.concat(s.onlyVia or {}, ','), table.concat(s.neverVia or {}, ','),
            s.alt and s.alt.label or '-'))
    end
    for _, p in ipairs(previewPoints(b)) do print(('  %s  %s'):format(p.text, fmt(p.pos))) end
    CreateThread(function()
        local pts = previewPoints(b)
        while preview == key do
            local me = C.myPos()
            local near = false
            for _, p in ipairs(pts) do
                if #(me - p.pos) <= 80.0 then
                    near = true
                    C.text3D(p.pos + vector3(0.0, 0.0, 0.3), p.text, 120, 200, 255)
                end
            end
            Wait(near and 0 or 500)
        end
    end)
end, false)

--------------------------------------------------------------------------------
-- /heistloot safe|grab [quiet] | list | undo | clear  (a draft printed to the console, nothing saved)

RegisterCommand('heistloot', function(_, args)
    if not testMode() then return end
    local what = args[1]
    if what == 'safe' or what == 'grab' then
        local p = C.myPos()
        draft[#draft + 1] = { pos = p, safe = what == 'safe', quiet = args[2] == 'quiet' }
        C.tip(('Draft spot %d added'):format(#draft))
    elseif what == 'undo' then
        table.remove(draft)
        C.tip(('Draft now has %d spot(s)'):format(#draft))
    elseif what == 'clear' then
        draft = {}
        C.tip('Draft cleared')
    end
    if what == 'list' or what == 'safe' or what == 'grab' or what == 'undo' then
        print('[pup_robbery] loot draft:')
        for _, d in ipairs(draft) do
            if d.safe then
                print(('    { pos = %s, safe = true, label = \'Crack the safe\', game = \'safe_crack\', tool = \'banktools\', failStep = 1%s },'):format(fmt(d.pos), d.quiet and ', quietOnly = true' or ''))
            else
                print(('    { pos = %s%s },'):format(fmt(d.pos), d.quiet and ', quietOnly = true' or ''))
            end
        end
    end
end, false)

RegisterCommand('heistmark', function(_, args)
    if not testMode() then return end
    local p = C.myPos()
    print(('[pup_robbery] %s = %s, heading %.2f'):format(args[1] or 'point', fmt(p), GetEntityHeading(PlayerPedId())))
    C.tip(('%s marked (console)'):format(args[1] or 'point'))
end, false)

--------------------------------------------------------------------------------
-- door tools

local function nearestDoor()
    local me = C.myPos()
    local best, bestD = nil, 6.0
    local ok, active = pcall(DoorSystemGetActive)
    if not ok or type(active) ~= 'table' then return nil end
    for _, pair in ipairs(active) do
        local hash, obj = pair[1], pair[2]
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            local d = #(GetEntityCoords(obj) - me)
            if d < bestD then best, bestD = { obj = obj, hash = hash }, d end
        end
    end
    return best
end

RegisterCommand('doorhash', function()
    if not testMode() then return end
    local d = nearestDoor()
    if not d then return C.tip('No door-system door nearby') end
    local p = GetEntityCoords(d.obj)
    print(('[pup_robbery] door hash %d model %d at %s'):format(d.hash, GetEntityModel(d.obj), fmt(p)))
    C.tip(('Door %d (console)'):format(d.hash))
end, false)

RegisterCommand('vaultdoor', function(_, args)
    if not testMode() then return end
    local d = nearestDoor()
    if not d then return C.tip('No door-system door nearby') end
    local state = DoorSystemGetDoorState(d.hash)
    if args[1] == 'open' then
        DoorSystemSetDoorState(d.hash, 0)
        DoorSystemSetOpenRatio(d.hash, 1.0, true, true)
    elseif args[1] == 'close' then
        DoorSystemSetOpenRatio(d.hash, 0.0, true, true)
        DoorSystemSetDoorState(d.hash, 1)
    end
    print(('[pup_robbery] door %d state %s'):format(d.hash, tostring(state)))
end, false)

--------------------------------------------------------------------------------
-- debug

RegisterCommand('testminigame', function(_, args)
    if not Config.Debug then return C.tip(L('debugOnly')) end
    local game = args[1] or 'normal'
    CreateThread(function()
        local won
        if game == 'safe' then
            won = C.minigame('safe', { style = 'default' }, { difficulty = Config.Minigames.tester.safeDifficulty }, Locale.tips.safe)
        elseif game == 'lockpick' then
            won = C.minigame('wire_cut', Config.Minigames.walkup.wire_cut, nil, Locale.tips.wire_cut)
        else
            won = C.boxGame(game)
        end
        C.tip(L('minigameResult', game, won and 'won' or 'lost'))
    end)
end, false)

-- needs debug mode and an admin (checked on the server)
RegisterCommand('testenemy', function(_, args)
    CreateThread(function()
        if not C.cb('pup_robbery:canTestEnemy') then return C.tip(L('noPermission')) end
        local kind = args[1] == 'police' and 'police' or 'outlaw'
        local ped = PlayerPedId()
        local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
        Guards.spawn({
            pos = pos, type = kind, weapon = 'WEAPON_REVOLVER_CATTLEMAN',
            model = kind == 'police' and 'A_M_M_RANCHER_01' or 'G_M_M_UNITEDBANDITS_01',
        }, 'test')
    end)
end, false)

function Dev_cleanup()
    preview = nil
    Guards.clear('test')
end
