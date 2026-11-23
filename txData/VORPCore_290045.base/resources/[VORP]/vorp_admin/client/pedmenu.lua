-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_admin / ped menu - become another ped, or put one on another player.
-- Temporary: it drives vorp_character's /rc Custom override, so a relog, a death
-- or a plain /rc puts the real character back. Nothing is written to the DB.

local RC <const> = Config.Integrations.vorpCharacter.reloadCommand or "rc"

-- The category, and also the filter dropdown value.
-- nil means "not a ped": Peds carries seven saddle props that would crash a transform.
local function pedGroup(model)
    local s <const> = (model:lower():gsub("^mp_", ""))
    if s:find("_saddle", 1, true) then return nil end
    if s:find("^a_c_horse") or s:find("^p_c_horse") then return "Horse" end
    if s:find("^a_c_") then return "Animal" end
    -- the gender letter is its own segment (a_m_m_, u_f_o_, mp_de_u_f_m_). A plain
    -- find("_m_") is wrong: a_f_m_valentine_01 carries _m_ as the BUILD letter.
    for seg in s:gmatch("[^_]+") do
        if seg == "m" then return "Male" end
        if seg == "f" then return "Female" end
    end
    if s:find("_females") then return "Female" end
    if s:find("_males") then return "Male" end
    if s:find("^cs_") then return "Story" end
    return "Other"
end

-- "a_m_m_armtownfolk_01" -> "Armtownfolk 01". The exact model sits in the row's desc
local function prettyPed(model)
    local s = model:lower()
    s = s:gsub("^mp_", ""):gsub("^a_c_", ""):gsub("^p_c_", ""):gsub("^cs_", "")
    s = s:gsub("^%a+_[mf]_%a_", "") -- a_m_m_ / u_f_o_ style prefix
    s = s:gsub("_", " ")
    return (s:gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end))
end

local catalog  -- built once: 1,975 rows out of the 1,982 in Peds
local allowed  -- model -> true, so a relayed model can be checked before it is used

local function pedCatalog()
    if catalog then return catalog end
    catalog, allowed = {}, {}
    for _, model in ipairs(Peds or {}) do
        local group <const> = pedGroup(model)
        if group then
            catalog[#catalog + 1] = { model = model, label = prettyPed(model), group = group }
            allowed[model:lower()] = true
        end
    end
    table.sort(catalog, function(a, b) return a.label < b.label end)
    return catalog
end

local function isKnownPed(model)
    if not allowed then pedCatalog() end
    return model ~= nil and allowed[tostring(model):lower()] == true
end

local function verifiedCount()
    local n = 0
    for _ in pairs(PedsVerified or {}) do n = n + 1 end
    return n
end

local FILTERS <const> = {
    { label = "All", value = "" },
    { label = "Male", value = "Male" },
    { label = "Female", value = "Female" },
    { label = "Story", value = "Story" },
    { label = "Animal", value = "Animal" },
    { label = "Horse", value = "Horse" },
    { label = "Other", value = "Other" },
}

-- /rc runs SetPlayerModel, which DESTROYS the ped and builds a new one whose
-- engine weapon inventory is EMPTY. vorp_inventory only puts the dual-wield
-- holster back on a rebuild, so without this you walk away unarmed while the
-- inventory still lists the guns as equipped.
local function runRc(model)
    local before <const> = PlayerPedId()
    if model and model ~= "" then
        ExecuteCommand(("%s %s"):format(RC, model))
    else
        ExecuteCommand(RC)
    end

    CreateThread(function()
        -- an /rc onto the SAME model never rebuilds, and then nothing was lost
        local waited = 0
        while PlayerPedId() == before and waited < 6000 do
            Wait(50)
            waited = waited + 50
        end
        if PlayerPedId() == before then return end

        -- let the new ped finish rendering before it is handed anything
        local ped = PlayerPedId()
        waited = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and waited < 5000 do
            Wait(50)
            waited = waited + 50
            ped = PlayerPedId()
        end
        -- clear of /rc's own re-decorate chain, which runs for about a second
        Wait(1500)

        -- an animal or horse ped has nothing to hold; the guns come back on the
        -- way out of it, when the real character is rebuilt
        ped = PlayerPedId()
        if not IsPedHuman(ped) then return end

        -- the same refresh a character select does: GET_LOADOUT clears the ped
        -- and re-gives every weapon still marked used
        TriggerServerEvent("vorpinventory:getInventory")
    end)
end

-- model = nil restores the player's own character
local function applyPed(target, model)
    if model and not isKnownPed(model) then return end
    if target then
        TriggerServerEvent("vorp_admin:server:setPlayerPed", target.serverId, model or "")
    else
        runRc(model)
    end
end

-- target = nil for yourself, otherwise a playersInfo row from the admin player list.
-- verifiedOnly limits the list to PedsVerified, the models known to render.
function BuildPedMenu(target, verifiedOnly)
    local who <const> = target and (target.PlayerName or ("ID " .. tostring(target.serverId))) or nil
    local options = {
        {
            label = "Default Character",
            desc = who and ("Restore " .. who .. " to their own character") or "Restore to original character",
            value = "System",
            pinned = true, -- stays reachable whatever is typed in the search box
            close = true,
            action = function() applyPed(target, nil) end,
        }
    }
    local verified <const> = PedsVerified or {}
    for _, row in ipairs(pedCatalog()) do
        if not verifiedOnly or verified[row.model:lower()] then
            options[#options + 1] = {
                label = row.label,
                desc = row.model,
                -- the tick is the only hint on the full list that a model is known good
                value = verified[row.model:lower()] and ("%s *"):format(row.group) or row.group,
                group = row.group,
                close = true,
                action = function() applyPed(target, row.model) end,
            }
        end
    end

    return {
        title = "Ped Menu",
        subtitle = who or "Change your own appearance",
        search = "Search peds",
        filters = FILTERS,
        options = options,
    }
end

-- OUTFITS. A ped model ships with numbered outfit presets; most use only the first
-- few, and an index a model does not have simply leaves it as it was.
local OUTFIT_MAX <const> = 24

-- preset = nil picks a random one
local function applyOutfitLocal(preset)
    local ped <const> = PlayerPedId()
    -- the random pass first: a preset on its own leaves some models untextured
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    if preset then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, preset, true)
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function applyOutfit(target, preset)
    if target then
        TriggerServerEvent("vorp_admin:server:setPlayerOutfit", target.serverId, preset or -1)
    else
        applyOutfitLocal(preset)
    end
end

-- target = nil for yourself, otherwise a playersInfo row
function BuildPedOutfitMenu(target)
    local who <const> = target and (target.PlayerName or ("ID " .. tostring(target.serverId))) or nil
    local options = {
        {
            label = "Random Outfit",
            desc = "Let the game pick",
            pinned = true,
            close = true,
            action = function() applyOutfit(target, nil) end,
        }
    }
    for i = 0, OUTFIT_MAX do
        options[#options + 1] = {
            label = ("Outfit %d"):format(i),
            desc = ("Preset %d"):format(i),
            close = true,
            action = function() applyOutfit(target, i) end,
        }
    end

    return {
        title = "Ped Outfits",
        subtitle = who or "Outfits for the ped you are wearing",
        search = "Search outfits",
        options = options,
    }
end

-- admin.lua's playerLabel/playerDesc are locals, and its desc is an eight-line block
-- that does not belong in a searchable picker, so this keeps its own one-line pair
local function pickLabel(info)
    return ("%s - ID %s"):format(info.PlayerName or "?", tostring(info.serverId or 0))
end
local function pickDesc(info)
    return ("%s  |  %s"):format(info.name or "", info.Job or "")
end

-- panelPlayers is the source the web panel's own Players page uses. getplayersinfo
-- reads a PlayersTable that is filled by a join event and comes back empty on a
-- running server.
local function onlinePlayers()
    local payload = VORP.Callback.TriggerAwait("vorp_admin:Callback:panelPlayers", { search = "" })
    if type(payload) ~= "table" or type(payload.rows) ~= "table" then return nil end
    local out = {}
    for _, row in ipairs(payload.rows) do
        local sid = tonumber(row.online)
        if sid then
            out[#out + 1] = { serverId = sid, PlayerName = row.name, name = row.steamname, Job = row.job }
        end
    end
    return out
end

-- pick a player first, then a ped or an outfit for them.
-- Returning nil here just closes the row silently, so every refusal says why.
function BuildPedGiveList(kind)
    if not IsAdminAllowed("ped_menu_others") then return nil end

    local players = onlinePlayers()
    if not players then
        TriggerEvent("vorp:TipRight", "The server sent no player list.", 4000)
        return nil
    end
    if #players == 0 then
        TriggerEvent("vorp:TipRight", "No players to give a ped to.", 4000)
        return nil
    end
    table.sort(players, function(a, b) return (a.serverId or 0) < (b.serverId or 0) end)

    local outfits <const> = kind == "outfit"
    local options = {}
    for _, info in ipairs(players) do
        options[#options + 1] = {
            label = pickLabel(info),
            desc = pickDesc(info),
            submenu = function()
                if outfits then return BuildPedOutfitMenu(info) end
                return BuildPedMenu(info)
            end
        }
    end

    return {
        title = "Ped Menu",
        subtitle = outfits and "Change a player's outfit" or "Give a player a ped",
        search = "Search players",
        options = options,
    }
end

function BuildPedRoot()
    return {
        title = "Ped Menu",
        subtitle = "Peds are temporary - a relog or death restores the real character",
        options = {
            {
                label = "Known Good Peds",
                desc = ("%d models confirmed to render as a player"):format(verifiedCount()),
                submenu = function() return BuildPedMenu(nil, true) end
            },
            {
                label = "Change My Ped",
                desc = "Every model in the game dump. Some will not render - those are unticked",
                submenu = function() return BuildPedMenu(nil) end
            },
            {
                label = "Give A Player A Ped",
                desc = "Pick a player, then pick what they turn into",
                submenu = function() return BuildPedGiveList() end
            },
            {
                label = "Change My Outfit",
                desc = "Outfit presets for the ped you are currently wearing",
                submenu = function() return BuildPedOutfitMenu(nil) end
            },
            {
                label = "Change A Player's Outfit",
                desc = "Pick a player, then pick an outfit for the ped they are wearing",
                submenu = function() return BuildPedGiveList("outfit") end
            },
        }
    }
end

-- -1 means the random variation
RegisterNetEvent("vorp_admin:client:setOutfit", function(preset)
    preset = tonumber(preset)
    if preset and (preset < 0 or preset % 1 ~= 0) then preset = nil end
    applyOutfitLocal(preset)
end)

-- the server only relays; this client owns the allowlist, so a forged model stops here
RegisterNetEvent("vorp_admin:client:setPed", function(model)
    if model and model ~= "" then
        if not isKnownPed(model) then return end
        runRc(model)
    else
        runRc(nil)
    end
end)
