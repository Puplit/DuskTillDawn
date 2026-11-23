-- pup_robbery | lawmen: the chat tip and map blip for on-duty lawmen, and pup-mdt board alerts

Police = {}

local alerted = {}     -- [src] = true while the lawman has an unread robbery alert
local live = {}        -- [key] = { pos, label } alert blips currently up

-- tip + blip to on-duty lawmen in the regions, skipping anyone in `skip`
function Police.alert(key, pos, label, regions, skip)
    local _, set = S.lawmen(regions)
    live[key] = { pos = pos, label = label }
    for s in pairs(set) do
        if not (skip and skip[s]) then
            alerted[s] = true
            S.tip(s, L('lawTip', label), 8000)
            TriggerClientEvent('pup_robbery:police:blip', s, key, { x = pos.x, y = pos.y, z = pos.z })
        end
    end
end

-- the alert blip goes for everyone
function Police.clear(key)
    if not live[key] then return end
    live[key] = nil
    TriggerClientEvent('pup_robbery:police:clear', -1, key)
end

function Police.clearAll()
    for key in pairs(live) do Police.clear(key) end
end

-- one pup-mdt board alert; the robber is never named (forcedSource false)
function Police.board(pos, text, persistent, location, region)
    if not Config.MdtAlerts or not S.up('pup-mdt') then return false end
    local ok, sent = S.call('pup-mdt', 'SendPoliceAlert', { x = pos.x, y = pos.y, z = pos.z }, text, persistent == true, false, location, region)
    if not ok or sent == false then
        S.warn('pup-mdt alert was not sent: %s', tostring(text))
        return false
    end
    return true
end

RegisterCommand(Config.AlertClearCommand, function(source)
    local src = tonumber(source)
    if not src or src <= 0 then return end
    alerted[src] = nil
    if Config.AlertClearRemovesBlips then
        TriggerClientEvent('pup_robbery:police:clearMine', src)
    end
end, false)

AddEventHandler('playerDropped', function()
    alerted[source] = nil
end)
