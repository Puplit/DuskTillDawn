-- pup_realestate | client core: state, server sync, request/answer, near tracking

UI = exports['pup-ui']

C = {
    houses = {},        -- id -> public house data from the server
    listVersion = 0,
    charid = nil,
    job = { job = '', grade = 0, group = 'user' },
    rooms = {},         -- { id, motel }
    auctioned = {},     -- house id -> true
    inside = nil,       -- { row, kind = 'house' | 'motel', motel? }
    near = {},          -- house id -> true (real-door and marker houses near you, or the interior you are in)
    menuOpen = false,
    menuHouse = nil,
    busy = false,       -- an action is running (prompts hidden)
    creating = false,
    placing = false,
    started = false,
}

function C.tip(text, ms) TriggerEvent('vorp:TipRight', tostring(text), ms or 4000) end
function C.tipBottom(text, ms) TriggerEvent('vorp:TipBottom', tostring(text), ms or 4000) end

function C.ped() return PlayerPedId() end
function C.pos() return GetEntityCoords(PlayerPedId()) end

-- request/answer with the server
local pending, seq = {}, 0

function Rpc(name, timeout, ...)
    seq = seq + 1
    local id = seq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('pup_realestate:' .. name, id, ...)
    SetTimeout(timeout or Config.Timers.clientReply, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ n = 0 })
        end
    end)
    local r = Citizen.Await(p)
    return table.unpack(r, 1, r.n or 0)
end

RegisterNetEvent('pup_realestate:cl_reply', function(id, ...)
    local p = pending[id]
    if p then
        pending[id] = nil
        p:resolve(table.pack(...))
    end
end)

function Send(name, ...) TriggerServerEvent('pup_realestate:' .. name, ...) end

-- access as the client sees it (the server re-checks everything)
function C.isOwner(h) return h and h.owned and C.charid and h.owner == C.charid end

function C.isKeyholder(h)
    if not h or not h.owned or not C.charid then return false end
    for _, k in ipairs(h.keys or {}) do
        if k.charid == C.charid then return true end
    end
    return false
end

function C.hasAccess(h) return C.isOwner(h) or C.isKeyholder(h) end

function C.ownedCount()
    local n = 0
    for _, h in pairs(C.houses) do
        if C.isOwner(h) then n = n + 1 end
    end
    return n
end

function C.insideHouse(id)
    return C.inside and C.inside.kind == 'house' and C.inside.row == id
end

-- house list and updates
local changeHooks = {}
function C.onChange(fn) changeHooks[#changeHooks + 1] = fn end

local function changed(id, refresh, old)
    for _, fn in ipairs(changeHooks) do
        local ok, err = pcall(fn, id, refresh, old)
        if not ok then print('^1[pup_realestate]^7 ' .. tostring(err)) end
    end
end

RegisterNetEvent('pup_realestate:cl_full', function(list)
    if type(list) ~= 'table' then return end
    local map = {}
    for _, h in ipairs(list) do
        if type(h) == 'table' and h.id then map[h.id] = h end
    end
    C.houses = map
    C.listVersion = C.listVersion + 1
    changed(nil, true)
end)

RegisterNetEvent('pup_realestate:cl_house', function(h, refresh)
    if type(h) ~= 'table' or not h.id then return end
    local old = C.houses[h.id]
    C.houses[h.id] = h
    changed(h.id, refresh == 1, old)
end)

RegisterNetEvent('pup_realestate:cl_removed', function(id)
    if C.houses[id] then
        C.houses[id] = nil
        changed(id, true)
    end
end)

RegisterNetEvent('pup_realestate:cl_rooms', function(list)
    C.rooms = type(list) == 'table' and list or {}
    C.motelPending = nil
end)

RegisterNetEvent('pup_realestate:cl_auctioned', function(list)
    local set = {}
    for _, id in ipairs(type(list) == 'table' and list or {}) do set[id] = true end
    C.auctioned = set
end)

RegisterNetEvent('pup_realestate:cl_closeMenus', function(id)
    if C.menuHouse == id and Menu then Menu.close() end
end)

function C.roomAt(key)
    for _, r in ipairs(C.rooms) do
        if r.motel == key then return r end
    end
    return nil
end

-- near tracking (once a second): real-door and marker houses within render distance,
-- plus the teleporter interior you are in
local function sameSet(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

CreateThread(function()
    while true do
        Wait(1000)
        if C.charid then
            local pos = C.pos()
            local set = {}
            for id, h in pairs(C.houses) do
                if h.kind == KIND_REAL or h.kind == KIND_MARKER then
                    local door = U.frontDoor(h)
                    if door and #(pos - door) <= Config.RenderDistance then set[id] = true end
                elseif h.kind == KIND_TELE and C.insideHouse(id) then
                    set[id] = true
                end
            end
            if not sameSet(set, C.near) then
                local old = C.near
                C.near = set
                local ids = {}
                for id in pairs(set) do ids[#ids + 1] = id end
                Send('sv_near', ids)
                if C.onNearChanged then C.onNearChanged(old, set) end
            end
        end
    end
end)

-- force a near recheck right away (entering or leaving an interior)
function C.refreshNear()
    local set = {}
    for id in pairs(C.near) do
        local h = C.houses[id]
        if h and h.kind ~= KIND_TELE then set[id] = true end
    end
    if C.inside and C.inside.kind == 'house' then set[C.inside.row] = true end
    local old = C.near
    C.near = set
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    Send('sv_near', ids)
    if C.onNearChanged then C.onNearChanged(old, set) end
end

-- startup for the selected character
local initRunning, initAgain = false, false

local function initDone()
    initRunning = false
    if initAgain then
        -- a character was selected while the previous startup was still running
        initAgain = false
        CreateThread(function() C.init(10) end)
    end
end

-- retry: the server may not answer the first time (still booting, or rate-limited after a restart resync)
function C.init(retry, fresh)
    if initRunning then
        if fresh then initAgain = true end -- a new character selection must not be lost
        return
    end
    initRunning = true
    local version = C.listVersion
    local data = Rpc('sv_init', 20000)
    if type(data) ~= 'table' then
        initDone()
        if retry and retry > 0 then
            SetTimeout(3000, function() C.init(retry - 1) end)
        end
        return
    end
    C.charid = data.charid
    C.rooms = data.rooms or {}
    C.job = data.job or C.job
    local set = {}
    for _, id in ipairs(data.auctioned or {}) do set[id] = true end
    C.auctioned = set
    local waited = 0
    while C.listVersion == version and waited < 10000 do
        Wait(100)
        waited = waited + 100
    end
    C.started = true
    if C.queueWorldRebuild then C.queueWorldRebuild() end
    if C.handleRelog then C.handleRelog(data.record) end
    initDone()
end

-- character switch: drop the old character's interior state and go back to the world first
RegisterNetEvent('vorp:SelectedCharacter', function(charid)
    if Menu then Menu.close() end
    if C.resetForSwitch then C.resetForSwitch() end
    C.charid = tonumber(charid) or C.charid
    CreateThread(function()
        Wait(1000)
        C.init(10, true)
    end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- interior map files only appear while someone is inside
    for _, int in pairs(Config.Interiors) do
        for _, name in ipairs(int.imaps or {}) do RemoveImap(GetHashKey(name)) end
    end
    if Config.ResyncOnRestart then
        CreateThread(function()
            Wait(3000)
            C.init(5)
        end)
    end
end)

function C.refreshJob()
    local j = Rpc('sv_job', Config.Timers.clientJobReply)
    if type(j) == 'table' then C.job = j end
    return C.job
end

-- client export for pup-gangs
exports('getCurrentHouseId', function()
    if C.inside and C.inside.kind == 'house' then return C.inside.row end
    local pos = C.pos()
    local best, bestD
    for id, h in pairs(C.houses) do
        if Config.Rules.currentHouseAnyOwner or C.hasAccess(h) then
            local door = U.frontDoor(h)
            local d = door and #(pos - door)
            if d and d <= 15.0 and (not best or d < bestD) then best, bestD = id, d end
        end
    end
    if best then return best end
    return C.menuHouse
end)
