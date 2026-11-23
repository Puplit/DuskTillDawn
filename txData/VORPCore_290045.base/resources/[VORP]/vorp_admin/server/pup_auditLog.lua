-- Modified by Puppet (Dusk Till Dawn), 2026
-- Audit log for panel actions handled by other resources.
-- These are client-fired events, so each handler checks staff() before logging.

local function staff(src, key)
    if not src or src == 0 then return false end
    local ok, allowed = pcall(HasPermission, src, key)
    return ok and allowed and true or false
end

local function audit(src, hook, title, description)
    TriggerEvent("vorp_admin:logs", src, hook, title, description)
end

-- k=v of a changes table, sorted so the same edit always reads the same way
local function pairsToText(t)
    if type(t) ~= "table" then return tostring(t) end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local v = t[k]
        if type(v) == "table" then
            out[#out + 1] = ("%s = <%d entries>"):format(k, #v)
        else
            out[#out + 1] = ("%s = %s"):format(k, tostring(v))
        end
    end
    return table.concat(out, "\n")
end

-- a shop "value" is a coords table for Move Here
local function valueText(v)
    if type(v) == "table" then
        if v.x and v.y and v.z then
            return ("%.1f, %.1f, %.1f"):format(v.x, v.y, v.z)
        end
        return pairsToText(v)
    end
    if v == nil or v == "" then return "(none)" end
    return tostring(v)
end

local function charName(charid)
    charid = tonumber(charid)
    if not charid then return "unknown" end
    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    end)
    if not ok or type(row) ~= "table" then return ("charid %d"):format(charid) end
    return ("%s %s (charid %d)"):format(row.firstname or "?", row.lastname or "", charid)
end

-- BUSINESS
RegisterNetEvent('pup_business:admin:create')
AddEventHandler('pup_business:admin:create', function(data)
    local src = source
    if not staff(src, "manage_society") then return end
    if type(data) ~= "table" then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("CREATED business %s\nName: %s\nBoss rank: %s"):format(
            tostring(data.job), tostring(data.name), tostring(data.bossrank)))
end)

RegisterNetEvent('pup_business:admin:update')
AddEventHandler('pup_business:admin:update', function(job, changes)
    local src = source
    if not staff(src, "manage_society") then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("Updated business %s\n%s"):format(tostring(job), pairsToText(changes)))
end)

-- same permission pup_business requires, so a refused attempt is not logged as a deletion
RegisterNetEvent('pup_business:admin:delete')
AddEventHandler('pup_business:admin:delete', function(job)
    local src = source
    if not staff(src, "delete_society") then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("DELETED business %s"):format(tostring(job)))
end)

-- Danger Zone handover wipes
local CLEAR_LABEL <const> = {
    stash = "EMPTIED the storage container of %s\nEvery item staff had in the shared stash is gone.",
    shops = "EMPTIED every shop front of %s\nStock, prices and buy listings cleared. The shops themselves remain.",
}

RegisterNetEvent('pup_business:admin:clear')
AddEventHandler('pup_business:admin:clear', function(job, kind)
    local src = source
    if not staff(src, "delete_society") then return end
    local line = CLEAR_LABEL[tostring(kind or '')]
    if not line then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        line:format(tostring(job)))
end)

RegisterNetEvent('pup_business:hire')
AddEventHandler('pup_business:hire', function(serverId, job)
    local src = source
    if not staff(src, "manage_society") then return end
    local who = tonumber(serverId) and GetPlayerName(tonumber(serverId)) or nil
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("HIRED into %s\nPlayer: %s (server id %s)"):format(
            tostring(job), who or "unknown", tostring(serverId)))
end)

RegisterNetEvent('pup_business:fire')
AddEventHandler('pup_business:fire', function(charid, job)
    local src = source
    if not staff(src, "manage_society") then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("FIRED from %s\nPlayer: %s"):format(
            job and tostring(job) or "their current job", charName(charid)))
end)

RegisterNetEvent('pup_business:admin:setSelfRank')
AddEventHandler('pup_business:admin:setSelfRank', function(job, grade, charid)
    local src = source
    if not staff(src, "manage_society") then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("Set rank in %s\nPlayer: %s\nNew grade: %s"):format(
            tostring(job), charName(charid), tostring(grade)))
end)

RegisterNetEvent('pup_business:admin:shopAction')
AddEventHandler('pup_business:admin:shopAction', function(job, shopId, act, value)
    local src = source
    if not staff(src, "manage_society") then return end
    audit(src, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("Shop %s on %s\nShop id: %s\nValue: %s"):format(
            tostring(act), tostring(job), tostring(shopId), valueText(value)))
end)

-- HOUSE AUCTIONS
RegisterNetEvent('pup_realestate:auctionCreate')
AddEventHandler('pup_realestate:auctionCreate', function(id, minbid, hours)
    local src = source
    if not staff(src, "manage_housing") then return end
    audit(src, Secrets.Webhooks.panelHousing, "Admin Panel - Housing",
        ("Auction opened on house %s\nMin bid: %s\nRuns: %s h"):format(
            tostring(id), tostring(minbid), tostring(hours)))
end)

RegisterNetEvent('pup_realestate:auctionCancel')
AddEventHandler('pup_realestate:auctionCancel', function(aucid)
    local src = source
    if not staff(src, "manage_housing") then return end
    audit(src, Secrets.Webhooks.panelHousing, "Admin Panel - Housing",
        ("Auction %s cancelled"):format(tostring(aucid)))
end)
