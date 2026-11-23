-- pup_ranchero | client core: server calls, ranch data, blips, the ranch marker and the activity runner

OWNER = 'pup_ranchero'
Ranch = { list = {}, me = nil }      -- me = this character's ranch info from the server (id 0 = none)
Deadlines = { chores = {} }          -- GetGameTimer() deadlines; -1 = busy with no known end
Pending = 0                          -- server calls still waiting for an answer
Cleanups = {}                        -- run on resource stop and character switch

local KEYS = Config.Keys

------------------------------------------------------------------------------
-- server calls
------------------------------------------------------------------------------
local seq, waiting = 0, {}

-- blocking call; must run inside a thread
function Call(name, ...)
    seq = seq + 1
    local id, p = seq, promise.new()
    waiting[id] = p
    Pending = Pending + 1
    TriggerServerEvent('pup_ranchero:rpc', id, name, ...)
    SetTimeout(10000, function()
        if waiting[id] then
            waiting[id] = nil
            p:resolve(table.pack(false))
        end
    end)
    local res = Citizen.Await(p)
    Pending = math.max(0, Pending - 1)
    return table.unpack(res, 1, res.n)
end

-- fire and forget
function Send(name, ...)
    TriggerServerEvent('pup_ranchero:rpc', 0, name, ...)
end

RegisterNetEvent('pup_ranchero:reply', function(id, ...)
    local p = waiting[id]
    if p then
        waiting[id] = nil
        p:resolve(table.pack(...))
    end
end)

------------------------------------------------------------------------------
-- small helpers
------------------------------------------------------------------------------
function TipBottom(msg, ms)
    TriggerEvent('vorp:TipBottom', msg, ms or 4000)
end

function DrawTxt(text, x, y, scale, center, r, g, b)
    SetTextScale(scale or 0.4, scale or 0.4)
    SetTextColor(r or 255, g or 255, b or 255, 230)
    SetTextCentre(center ~= false)
    SetTextDropshadow(1, 0, 0, 0, 200)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(text)), x, y)
end

-- the G prompt: the game's own prompt (Config.PromptStyle = 'native') or pup-ui's pill ('pill')
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local nativePrompt, nativeLabel = nil, nil
local promptHit = false

local function nativeShow(label, title)
    if not nativePrompt then
        nativePrompt = PromptRegisterBegin()
        PromptSetControlAction(nativePrompt, KEYS.interact)
        PromptSetText(nativePrompt, CreateVarString(10, 'LITERAL_STRING', label))
        PromptSetEnabled(nativePrompt, true)
        PromptSetVisible(nativePrompt, true)
        PromptSetStandardMode(nativePrompt, true)
        PromptSetGroup(nativePrompt, promptGroup)
        PromptRegisterEnd(nativePrompt)
        nativeLabel = label
    elseif nativeLabel ~= label then
        PromptSetText(nativePrompt, CreateVarString(10, 'LITERAL_STRING', label))
        nativeLabel = label
    end
    PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', title or L('promptTitle')))
end

--- Show the G prompt this frame. Pressed(KEYS.interact) right after it reports the press.
function Pill(label, title)
    if Config.PromptStyle == 'pill' then
        exports['pup-ui']:Prompt({ key = KEYS.interactLabel, label = label })
        return
    end
    promptHit = false
    nativeShow(label, title)
    if PromptHasStandardModeCompleted(nativePrompt) then promptHit = true end
end

Cleanups[#Cleanups + 1] = function(stopping)
    if stopping and nativePrompt then PromptDelete(nativePrompt) nativePrompt = nil end
end

function Text3D(coords, text)
    exports['pup-ui']:Draw3DText(coords, text)
end

function MyPos()
    local c = GetEntityCoords(PlayerPedId())
    return { x = c.x, y = c.y, z = c.z }
end

function SetFrozen(on)
    FreezeEntityPosition(PlayerPedId(), on == true)
end

function Pressed(key)
    -- with the native prompt, G counts once, when the prompt itself completes
    if key == KEYS.interact and Config.PromptStyle ~= 'pill' then
        local hit = promptHit
        promptHit = false
        return hit
    end
    return IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key)
end

function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local stop = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > stop then return nil end
        Wait(50)
    end
    return hash
end

function SpawnPed(model, pos, heading, networked)
    local hash = LoadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, heading or 0.0, networked ~= false, false, false, false)
    if not ped or ped == 0 then return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- random outfit variation: peds are invisible without one
    SetModelAsNoLongerNeeded(hash)
    return ped
end

function DeletePedSafe(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
    end
end

function Role() return Ranch.me and Ranch.me.role end
function IsBoss() local r = Role() return r == 'owner' or r == 'manager' end
function HasRanch() return Ranch.me ~= nil and (Ranch.me.id or 0) > 0 end

-- seconds left on a deadline; -1 = busy with no known end
function LeftOf(deadline)
    if not deadline then return 0 end
    if deadline == -1 then return -1 end
    return math.max(0, math.ceil((deadline - GetGameTimer()) / 1000))
end

function OtherPlayerNear(radius)
    local me = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and #(GetEntityCoords(ped) - me) <= radius then return true end
        end
    end
    return false
end

------------------------------------------------------------------------------
-- blips
------------------------------------------------------------------------------
local barnBlips, ranchBlips = {}, {}
local blipTimer = 0

local function makeBlip(sprite, c, name)
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, c.x, c.y, c.z) -- BLIP_ADD_FOR_COORDS
    SetBlipSprite(b, sprite, true)
    SetBlipScale(b, Config.Blips.scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, b, name) -- set blip name
    return b
end

local function rebuildRanchBlips()
    for _, b in ipairs(ranchBlips) do RemoveBlip(b) end
    ranchBlips = {}
    local myId = Ranch.me and Ranch.me.id or 0
    for _, r in ipairs(Ranch.list) do
        if r.coords then
            if r.owned ~= 1 then
                ranchBlips[#ranchBlips + 1] = makeBlip(Config.Blips.forSale, r.coords, L('forSale'))
            elseif r.id == myId then
                ranchBlips[#ranchBlips + 1] = makeBlip(Config.Blips.owned, r.coords, r.name)
            end
        end
    end
end

function QueueBlips()
    blipTimer = blipTimer + 1
    local mine = blipTimer
    SetTimeout(Config.Blips.rebuildDelay, function()
        if mine == blipTimer then rebuildRanchBlips() end
    end)
end

CreateThread(function()
    for _, b in ipairs(Config.SaleBarns) do
        if not b.disabled then
            barnBlips[#barnBlips + 1] = makeBlip(Config.Blips.barn, b, ('%s Sale Barn'):format(b.town))
        end
    end
end)

Cleanups[#Cleanups + 1] = function(stopping)
    if not stopping then return end
    for _, b in ipairs(ranchBlips) do RemoveBlip(b) end
    for _, b in ipairs(barnBlips) do RemoveBlip(b) end
    ranchBlips, barnBlips = {}, {}
end

------------------------------------------------------------------------------
-- data from the server
------------------------------------------------------------------------------
InfoListeners = {}

RegisterNetEvent('pup_ranchero:list', function(list)
    if type(list) ~= 'table' then return end
    Ranch.list = list
    QueueBlips()
end)

RegisterNetEvent('pup_ranchero:info', function(info)
    if type(info) ~= 'table' then return end
    local now = GetGameTimer()
    local function dl(sec)
        sec = tonumber(sec) or 0
        if sec == -1 then return -1 end
        if sec <= 0 then return nil end
        return now + sec * 1000
    end
    Ranch.me = info
    Deadlines.herd = dl(info.herdLeft)
    Deadlines.sell = dl(info.sellLeft)
    Deadlines.milk = dl(info.milkLeft)
    Deadlines.eggs = dl(info.eggLeft)
    Deadlines.chores = {}
    for name, sec in pairs(info.choreLeft or {}) do Deadlines.chores[name] = dl(sec) end
    -- who is out on a drive: turn "seconds left" into a local deadline for the menu countdown
    for _, k in ipairs({ 'herdBy', 'sellBy' }) do
        local w = info[k]
        if type(w) == 'table' and tonumber(w.left) then w.endsAt = now + tonumber(w.left) * 1000 end
    end
    QueueBlips()
    for _, fn in ipairs(InfoListeners) do fn(info) end
end)

RegisterNetEvent('pup_ranchero:closeMenus', function()
    if Menu then Menu.closeAll() end
end)

------------------------------------------------------------------------------
-- activities: one at a time; G acts, Backspace cancels
------------------------------------------------------------------------------
Activity = nil

function EndActivity()
    local a = Activity
    Activity = nil
    if a and a.cleanup then a.cleanup(a) end
    return a
end

-- a = { tick(a) draws and sets a.ready/a.pill, interact(a) runs in its own thread,
--       cancel(a), expire(a), expiresIn (ms), noHint, cleanup(a) }
function StartActivity(a)
    EndActivity()
    Activity = a
    if a.expiresIn then a.expiresAt = GetGameTimer() + a.expiresIn end
    CreateThread(function()
        while Activity == a do
            Wait(0)
            a.ready, a.pill = false, nil
            if not a.running then a.tick(a) end
            if Activity ~= a then break end
            if a.pill then Pill(a.pill) end
            if not a.noHint and not a.running then DrawTxt(L('backspaceHint'), 0.5, 0.92, 0.32) end
            if not a.running then
                if Pressed(KEYS.cancel) then
                    EndActivity()
                    TipBottom(L('cancelled'))
                    if a.cancel then a.cancel(a) end
                    break
                end
                if a.expiresAt and GetGameTimer() > a.expiresAt then
                    EndActivity()
                    TipBottom(L('tookTooLong'))
                    if a.expire then a.expire(a) end
                    break
                end
                if a.ready and a.interact and Pressed(KEYS.interact) then
                    a.running = true
                    CreateThread(function()
                        a.interact(a)
                        a.running = false
                    end)
                end
            end
        end
    end)
end

------------------------------------------------------------------------------
-- the ranch marker and its prompt
------------------------------------------------------------------------------
-- a running drive does not hide the prompt: the ranch menu has a drive-only view
function PromptHidden()
    return (Menu and Menu.isOpen()) or Activity ~= nil or Working or Pending > 0
end

Working = false

CreateThread(function()
    while true do
        local wait = 1000
        if not PromptHidden() and #Ranch.list > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            local best, bestD
            for _, r in ipairs(Ranch.list) do
                if r.coords then
                    local d = #(pos - vector3(r.coords.x, r.coords.y, r.coords.z))
                    if not bestD or d < bestD then best, bestD = r, d end
                end
            end
            if bestD and bestD < 40.0 then wait = 250 end
            if best and bestD <= Config.Reach.marker then
                wait = 0
                local c = best.coords
                Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, c.x, c.y, c.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    2.0, 2.0, 0.25, 200, 160, 80, 120, false, false, 2, false, nil, nil, false)
                if bestD > Config.Reach.prompt then
                    if Config.ShowRanchIdText or Config.PromptStyle == 'pill' then
                        Text3D(vector3(c.x, c.y, c.z + 0.2), L('ranchId', best.id))
                    end
                else
                    local mine = HasRanch() and Ranch.me.id == best.id
                    local label
                    if best.owned ~= 1 and not HasRanch() then label = L('pillBuy')
                    elseif mine then label = L('pillMenu') end
                    if label then
                        Pill(label, (mine and best.name) or L('ranchId', best.id))
                        if Pressed(Config.Keys.interact) then
                            if OtherPlayerNear(Config.Reach.crowd) then
                                TipBottom(L('tooClose'))
                            elseif mine then
                                CreateThread(OpenRanchMenu)
                            else
                                CreateThread(function() OpenBuyMenu(best) end)
                            end
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

------------------------------------------------------------------------------
-- lifecycle
------------------------------------------------------------------------------
local function runCleanups(stopping)
    for _, fn in ipairs(Cleanups) do pcall(fn, stopping) end
end

function ResetLocal()
    Ranch.me = nil
    Deadlines = { chores = {} }
    EndActivity()
    runCleanups(false)
end

-- character switch: forget everything and ask again (the server ends any drive on its side)
RegisterNetEvent('vorp:SelectedCharacter', function()
    ResetLocal()
    SetTimeout(Config.Timers.infoDelayMs, function() Send('requestInfo') end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(Config.Timers.infoDelayMs, function() Send('requestInfo') end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Activity = nil
    runCleanups(true)
    SetNuiFocus(false, false)
    SetFrozen(false)
    pcall(function() exports['pup-ui']:HideInkMenu() end)
end)
