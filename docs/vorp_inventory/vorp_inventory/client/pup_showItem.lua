-- SHOW ITEM - hold an item up so nearby players see what it is.
-- html/js/pup_showitem.js draws the card; this resolves head position to screen
-- coords once per frame and sends one batched message.

local CFG <const> = (CONFIG and CONFIG.SHOW_ITEM) or {}
local SHOW_SECONDS <const> = tonumber(CFG.SECONDS) or 8.0
local RANGE <const> = tonumber(CFG.RANGE) or 8.0

-- clamped: equal values would divide by zero in the fade below
local fade = tonumber(CFG.FADE_FROM) or (RANGE * 0.7)
if fade >= RANGE or fade < 0.0 then fade = RANGE * 0.7 end
local FADE_FROM <const> = fade

-- the skeleton's head, not a guess from the root: a fixed offset floats on short
-- peds and sinks on mounts
local HEAD_BONE  <const> = 21030
local HEAD_CLEAR <const> = 0.25

local showing = {}   -- serverId -> { label, item, expires }
local painted = false

-- the inventory refuses while it is open: the card would be behind the panel
RegisterNUICallback('ShowItem', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local item = tostring(data.item or '')
    if item == '' then return end
    TriggerServerEvent('vorp_inventory:pupShowItem', item, tostring(data.label or item))
end)

RegisterNetEvent('vorp_inventory:pupShowItemSync', function(serverId, item, label)
    serverId = tonumber(serverId)
    if not serverId then return end
    showing[serverId] = {
        item    = tostring(item or ''),
        label   = tostring(label or item or ''),
        expires = GetGameTimer() + math.floor(SHOW_SECONDS * 1000),
    }
end)

local function hideAll()
    if not painted then return end
    painted = false
    SendNUIMessage({ action = 'pupShowItemHide' })
end

CreateThread(function()
    while true do
        if next(showing) == nil then
            hideAll()
            Wait(500)
        else
            local now = GetGameTimer()
            local me = PlayerPedId()
            local myCoords = GetEntityCoords(me)
            local items, n = {}, 0

            for serverId, entry in pairs(showing) do
                if now >= entry.expires then
                    showing[serverId] = nil
                else
                    local ply = GetPlayerFromServerId(serverId)
                    local ped = ply ~= -1 and GetPlayerPed(ply) or 0
                    if ped == 0 or not DoesEntityExist(ped) then
                        showing[serverId] = nil
                    else
                        local c = GetEntityCoords(ped)
                        local dist = #(myCoords - c)
                        if dist <= RANGE then
                            -- the skeleton's head, not a guess from the root
                            local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
                            if not head or head.z == 0.0 then
                                head = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.9)
                            end
                            local onScreen, sx, sy =
                                GetScreenCoordFromWorldCoord(head.x, head.y, head.z + HEAD_CLEAR)
                            if onScreen then
                                local a = 1.0
                                if dist > FADE_FROM then
                                    a = 1.0 - ((dist - FADE_FROM) / (RANGE - FADE_FROM))
                                end
                                n = n + 1
                                items[n] = {
                                    id    = serverId,
                                    x     = sx,
                                    y     = sy,
                                    label = entry.label,
                                    img   = entry.item,
                                    a     = a,
                                }
                            end
                        end
                    end
                end
            end

            if n > 0 then
                painted = true
                SendNUIMessage({ action = 'pupShowItem', data = { items = items } })
            else
                hideAll()
            end
            Wait(0)
        end
    end
end)

-- a resource stop must not leave a card painted on a page that outlives us
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SendNUIMessage({ action = 'pupShowItemHide' })
    end
end)
