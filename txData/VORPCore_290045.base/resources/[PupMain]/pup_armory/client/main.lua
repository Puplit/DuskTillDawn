-- pup_armory | client
-- Props are local (non-networked) objects drawn from each player's 'pup_armory' state bag.

local drawn = {}       -- [serverId] = { sig, ped, objs = { [item] = { main } } }
local given = nil      -- the base weapon hash this resource handed the local player
local myHand = nil     -- the hand item the server says I carry

-- the editor's live preview for the local player: { item, slot, off }
ArmoryPreview = nil

local function dbg(...) if Config.General.debug then print('[pup_armory]', ...) end end

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelValid(hash) then return nil end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
        if not HasModelLoaded(hash) then return nil end
    end
    return hash
end

local function spawnProp(name, ped)
    local hash = loadModel(name)
    if not hash then dbg('model not found: ' .. tostring(name)) return nil end
    local p = GetEntityCoords(ped)
    local obj = CreateObject(hash, p.x, p.y, p.z - 3.0, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    SetEntityCanBeDamaged(obj, false)
    return obj
end

local function hang(obj, target, boneIndex, o)
    AttachEntityToEntity(obj, target, boneIndex, o[1], o[2], o[3], o[4], o[5], o[6],
        false, false, false, false, 0, true, false, false)
end

local function bone(ped, name) return GetEntityBoneIndexByName(ped, name) end

-- where one slot of one item sits for this player: editor preview > saved > default
local function spot(sid, state, def, slot)
    if ArmoryPreview and sid == GetPlayerServerId(PlayerId()) and ArmoryPreview.item == def.item and ArmoryPreview.slot == slot then
        return ArmoryPreview.off
    end
    local saved = state.pos and state.pos[def.item] and state.pos[def.item][slot]
    return saved or Armory.default(def, slot)
end

local function clearPlayer(sid)
    local r = drawn[sid]
    if not r then return end
    for _, o in pairs(r.objs) do
        if o.main and DoesEntityExist(o.main) then DeleteEntity(o.main) end
    end
    drawn[sid] = nil
end

local function isDrawn(ped, def)
    local base = Armory.baseWeapon(def)
    if not base then return false end
    local _, current = GetCurrentPedWeapon(ped, true, 0, true)
    return current == joaat(base)
end

-- hang every prop for one player; called only when something about them changed
local function arrange(sid, ped, state, r, inHand)
    for _, item in ipairs({ state.hand, state.shield }) do
        local def = item and Armory.get(item)
        local o = def and r.objs[item]
        if o then
            if def.kind == 'shield' then
                hang(o.main, ped, bone(ped, def.bone), spot(sid, state, def, 'worn'))
            else
                if inHand then hang(o.main, ped, bone(ped, 'SKEL_R_HAND'), spot(sid, state, def, 'hand'))
                else hang(o.main, ped, bone(ped, def.bone), spot(sid, state, def, 'worn')) end
            end
        end
    end
end

local function updatePlayer(sid, ped, state)
    local r = drawn[sid]
    -- a new ped (respawn, model change) drops every prop: they were hung on the old one
    if r and r.ped ~= ped then clearPlayer(sid) r = nil end
    if not r then r = { objs = {}, ped = ped } drawn[sid] = r end

    -- spawn what is carried, delete what no longer is
    local want = {}
    for _, item in ipairs({ state.hand, state.shield }) do
        local def = item and Armory.get(item)
        if def then
            want[item] = true
            if not r.objs[item] then
                r.objs[item] = { main = spawnProp(def.model, ped) }
                r.sig = nil
            end
        end
    end
    for item, o in pairs(r.objs) do
        if not want[item] then
            if o.main and DoesEntityExist(o.main) then DeleteEntity(o.main) end
            r.objs[item] = nil
            r.sig = nil
        end
    end

    local handDef = state.hand and Armory.get(state.hand)
    local me = sid == GetPlayerServerId(PlayerId())
    local previewHand = me and ArmoryPreview and ArmoryPreview.slot == 'hand'
    local inHand = handDef and (previewHand or isDrawn(ped, handDef)) or false

    -- the real weapon model stays hidden whenever our prop is the one in the hand; if the
    -- prop failed to load (a wrong model name) the real weapon shows instead of nothing
    local handObj = handDef and r.objs[state.hand]
    local propOk = handObj and handObj.main
    if inHand and propOk and not previewHand then
        local w = GetCurrentPedWeaponEntityIndex(ped, 0)
        if w and w ~= 0 and IsEntityVisible(w) then SetEntityVisible(w, false) end
    end

    -- re-hang only on a change; the preview re-hangs every tick so the editor is live
    local sig = ('%s|%s|%s|%s|%s'):format(tostring(state.hand), tostring(state.shield), tostring(inHand),
        json.encode(state.pos or {}), tostring(GlobalState.pup_armory_defaults_v))
    local stale = false
    for _, o in pairs(r.objs) do
        if o.main and not IsEntityAttached(o.main) then stale = true end
    end
    if sig ~= r.sig or stale or (me and ArmoryPreview) then
        arrange(sid, ped, state, r, inHand)
        r.sig = sig
    end
end

CreateThread(function()
    while true do
        Wait(Config.General.tickMs)
        local myPed = PlayerPedId()
        local myPos = GetEntityCoords(myPed)
        local seen = {}
        for _, pid in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(pid)
            local ped = GetPlayerPed(pid)
            local state = Player(sid).state.pup_armory
            if state and ped ~= 0 and DoesEntityExist(ped)
                and (ped == myPed or #(GetEntityCoords(ped) - myPos) <= Config.General.drawRange) then
                seen[sid] = true
                updatePlayer(sid, ped, state)
            end
        end
        for sid in pairs(drawn) do if not seen[sid] then clearPlayer(sid) end end
    end
end)

-- the base weapon: handed over when a hand item is taken out, taken back when put away
local function giveBase(item)
    local ped = PlayerPedId()
    if given then
        Citizen.InvokeNative(0x4899CB088EDF59B8, ped, given, true, 0)   -- REMOVE_WEAPON_FROM_PED
        given = nil
    end
    myHand = item or nil
    local def = item and Armory.get(item)
    local base = def and Armory.baseWeapon(def)
    if base then
        given = joaat(base)
        GiveWeaponToPed(ped, given, 0, false, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    end
end
RegisterNetEvent('pup_armory:arm', giveBase)

-- death, a clothing reload or another script can strip the weapon: hand it back
CreateThread(function()
    while true do
        Wait(2000)
        if given and myHand then
            local ped = PlayerPedId()
            if not IsEntityDead(ped) and not HasPedGotWeapon(ped, given, 0, false) then
                GiveWeaponToPed(ped, given, 0, false, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
            end
        end
    end
end)

-- a new character starts empty-handed; the server also re-checks whether we are staff
RegisterNetEvent('vorp:SelectedCharacter', function()
    giveBase(nil)
    TriggerServerEvent('pup_armory:clear')
    TriggerServerEvent('pup_armory:hello')
end)
CreateThread(function() Wait(2000) TriggerServerEvent('pup_armory:hello') end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for sid in pairs(drawn) do clearPlayer(sid) end
    if given then Citizen.InvokeNative(0x4899CB088EDF59B8, PlayerPedId(), given, true, 0) end
end)
