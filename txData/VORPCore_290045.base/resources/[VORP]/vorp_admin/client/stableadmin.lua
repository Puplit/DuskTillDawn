-- Modified by Puppet (Dusk Till Dawn), 2026
-- Stable admin: a player's horses and wagons, kept in vorp_admin so it
-- runs on the stable_admin permission instead of pup-stable's identifier whitelist.
-- pup-stable still owns the data operations; this is the menu and the gate.

local function players()
    local payload = VORP.Callback.TriggerAwait("vorp_admin:Callback:panelPlayers", { search = "" })
    if type(payload) ~= "table" or type(payload.rows) ~= "table" then return nil end
    local out = {}
    for _, row in ipairs(payload.rows) do
        local sid = tonumber(row.online)
        if sid then
            out[#out + 1] = { serverId = sid, PlayerName = row.name, name = row.steamname, Job = row.job }
        end
    end
    table.sort(out, function(a, b) return (a.serverId or 0) < (b.serverId or 0) end)
    return out
end

local function pickLabel(info)
    return ("%s - ID %s"):format(info.PlayerName or "?", tostring(info.serverId or 0))
end

local function assetsOf(serverId)
    local payload = VORP.Callback.TriggerAwait("vorp_admin:Callback:stableAssets", { serverId = serverId })
    if type(payload) ~= "table" then return nil end
    return payload
end

-- pick who receives the asset
local function BuildTransferTarget(kind, asset, owner)
    local list = players()
    if not list then
        TriggerEvent("vorp:TipRight", "The server sent no player list.", 4000)
        return nil
    end
    local options = {}
    for _, info in ipairs(list) do
        if info.serverId ~= owner.serverId then
            options[#options + 1] = {
                label = pickLabel(info),
                desc = "Give them this " .. kind,
                close = true,
                action = function()
                    TriggerServerEvent("vorp_admin:server:stableTransfer", kind, asset.id, info.serverId)
                end,
            }
        end
    end
    if #options == 0 then
        TriggerEvent("vorp:TipRight", "Nobody else is online to transfer to.", 4000)
        return nil
    end
    return {
        title = "Stable Admin",
        subtitle = ("Transfer %s to"):format(asset.name or kind),
        search = "Search players",
        options = options,
    }
end

local function BuildAssetActions(kind, asset, owner)
    local options = {
        {
            label = "Transfer Ownership",
            desc = "Hand this " .. kind .. " to another online player",
            submenu = function() return BuildTransferTarget(kind, asset, owner) end,
        },
        {
            label = "View Storage",
            desc = kind == "horse" and "Open the saddlebag: see everything and take items out"
                or "Open the wagon locker: see everything and take items out",
            close = true,
            action = function() TriggerServerEvent("vorp_admin:server:stableStorage", kind, asset.id) end,
        },
    }
    if kind == "horse" then
        options[#options + 1] = {
            label = "Fully Train",
            desc = "Max speed, acceleration, handling, bonding, health and stamina",
            close = true,
            action = function() TriggerServerEvent("vorp_admin:server:stableTrain", asset.id) end,
        }
        options[#options + 1] = {
            label = "Reset Coat Colour",
            desc = "Clear the bought tint off this horse",
            close = true,
            action = function() TriggerServerEvent("vorp_admin:server:stableResetColor", asset.id) end,
        }
    end
    options[#options + 1] = {
        label = "Delete",
        desc = "PERMANENT. Removes this " .. kind .. " from the owner",
        close = true,
        action = function() TriggerServerEvent("vorp_admin:server:stableDelete", kind, asset.id) end,
    }

    local stats = ""
    if kind == "horse" then
        stats = ("spd %s  acc %s  hdl %s  bond %s"):format(
            tostring(asset.speed), tostring(asset.acceleration),
            tostring(asset.handling), tostring(asset.bonding))
    end
    return {
        title = "Stable Admin",
        subtitle = ("%s  |  %s"):format(asset.name or "Unnamed", stats ~= "" and stats or tostring(asset.model)),
        options = options,
    }
end

local function BuildAssetList(kind, rows, owner)
    if type(rows) ~= "table" or #rows == 0 then
        TriggerEvent("vorp:TipRight", ("That player has no %ss."):format(kind), 4000)
        return nil
    end
    local options = {}
    for _, asset in ipairs(rows) do
        options[#options + 1] = {
            label = ("%s  (#%s)"):format(asset.name or "Unnamed", tostring(asset.id)),
            desc = tostring(asset.model or "?"),
            submenu = function() return BuildAssetActions(kind, asset, owner) end,
        }
    end
    return {
        title = "Stable Admin",
        subtitle = ("%s - %ss"):format(owner.PlayerName or "?", kind),
        search = "Search",
        options = options,
    }
end

local function BuildPlayerAssets(info)
    local data
    if info.charid then
        data = VORP.Callback.TriggerAwait("vorp_admin:Callback:stableAssets", { charid = info.charid })
        if type(data) == "table" and data.notFound then
            TriggerEvent("vorp:TipRight", ("No character with ID %s."):format(tostring(info.charid)), 4000)
            return nil
        end
        if type(data) ~= "table" then data = nil end
        if data and data.name then info.PlayerName = data.name end
    else
        data = assetsOf(info.serverId)
    end
    if not data then
        TriggerEvent("vorp:TipRight", "Could not read that player's stable.", 4000)
        return nil
    end
    local horses <const> = data.horses or {}
    local wagons <const> = data.wagons or {}
    return {
        title = "Stable Admin",
        subtitle = ("%s  |  char %s"):format(info.PlayerName or "?", tostring(data.charid or "?")),
        options = {
            {
                label = ("Horses (%d)"):format(#horses),
                desc = "Transfer, view storage, train, reset colour or delete",
                submenu = function() return BuildAssetList("horse", horses, info) end,
            },
            {
                label = ("Wagons (%d)"):format(#wagons),
                desc = "Transfer, view storage or delete",
                submenu = function() return BuildAssetList("wagon", wagons, info) end,
            },
        },
    }
end

function BuildStableAdminRoot()
    if not IsAdminAllowed("stable_admin") then return nil end

    local list = players() or {}

    local options = {
        -- any character, online or offline, by its character id
        {
            label = "Search by Character ID",
            desc = "Find any character's horses and wagons, online or offline",
            submenu = function()
                local vals = AskInput("Stable Admin", {
                    { label = "Character ID", type = 'number', placeholder = "Character ID", required = true },
                }, "Search by Character ID")
                local cid = vals and tonumber(vals[1])
                if not cid then return nil end
                return BuildPlayerAssets({ charid = math.floor(cid), PlayerName = "char " .. math.floor(cid) })
            end,
        },
    }
    for _, info in ipairs(list) do
        options[#options + 1] = {
            label = pickLabel(info),
            desc = ("%s  |  %s"):format(info.name or "", info.Job or ""),
            submenu = function() return BuildPlayerAssets(info) end,
        }
    end

    return {
        title = "Stable Admin",
        subtitle = "Pick a player to see their horses and wagons",
        search = "Search players",
        options = options,
    }
end

-- same command name as in pup-stable. The menu refuses without the
-- permission and every server event re-checks it.
RegisterCommand("stableadmin", function()
    local root = BuildStableAdminRoot()
    if root then PupMenu.Open(root) end
end, false)
