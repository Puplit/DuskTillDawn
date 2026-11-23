-- Modified by Puppet (Dusk Till Dawn), 2026
-- extra data for the character select cards: where they are, when they were last
-- played, and whether they are sitting in a cell. Read by GetPlayerData in server.lua.

local Core <const> = exports.vorp_core:GetCore()

-- `lastplayed` is ours, so the column is added on start rather than left as a manual step
CreateThread(function()
    local sql <const> = LoadResourceFile(GetCurrentResourceName(), 'sql/charcards.sql')
    if sql and sql ~= '' then
        if not pcall(MySQL.query.await, sql) then
            print("^1[vorp_character]^7 could not add the characters.lastplayed column")
        end
    end
end)

local function stamp(charid)
    charid = tonumber(charid)
    if not charid then return end
    pcall(MySQL.update, "UPDATE characters SET lastplayed = NOW() WHERE charidentifier = ?", { charid })
end

-- stamped on both edges so the card reads "when you were last on them" either way
AddEventHandler("vorp:SelectedCharacter", function(src, character)
    if character and character.charIdentifier then stamp(character.charIdentifier) end
end)

AddEventHandler("playerDropped", function()
    local user = Core.getUser(source)
    local character = user and user.getUsedCharacter
    if character and character.charIdentifier then stamp(character.charIdentifier) end
end)

-- pup-mdt owns the town list; without it the card simply says nothing about location
local function zoneName(coords)
    if type(coords) ~= "table" or not coords.x then return nil end
    if GetResourceState("pup-mdt") ~= "started" then return nil end
    local ok, name = pcall(function() return exports["pup-mdt"]:ZoneNameFromCoords(coords) end)
    if not ok or type(name) ~= "string" or name == "" or name == "Unknown Zone" then return nil end
    return name
end

-- one round trip for every character, rather than two queries per card
local function placeholders(n)
    return string.rep("?", n, ",")
end

---@param charIds table list of charidentifiers belonging to this player
---@return table [charid] = { lastPlayed = epoch|nil, jailMinutes = number|nil }
function PupCardData(charIds)
    local out = {}
    if type(charIds) ~= "table" or #charIds == 0 then return out end
    for _, id in ipairs(charIds) do out[id] = {} end

    local marks <const> = placeholders(#charIds)

    local okL, rows = pcall(MySQL.query.await,
        ("SELECT charidentifier, UNIX_TIMESTAMP(lastplayed) AS lp FROM characters WHERE charidentifier IN (%s)")
        :format(marks), charIds)
    if okL then
        for _, r in ipairs(rows or {}) do
            local slot = out[tonumber(r.charidentifier)]
            if slot then slot.lastPlayed = tonumber(r.lp) end
        end
    end

    -- the prison table belongs to pup-mdt and may not exist at all
    local okJ, jails = pcall(MySQL.query.await,
        ("SELECT charidentifier, jail_time FROM mdt_prison_records WHERE status = 'active' AND jail_time > 0 AND charidentifier IN (%s)")
        :format(marks), charIds)
    if okJ then
        for _, r in ipairs(jails or {}) do
            local slot = out[tonumber(r.charidentifier)]
            local secs = tonumber(r.jail_time) or 0
            if slot and secs > 0 then
                slot.jailMinutes = math.max(1, math.floor(secs / 60))
            end
        end
    end

    return out
end

-- coords are already decoded by the caller
function PupCardWhere(coords)
    return zoneName(coords)
end

-- Job display names, resolved as pup_id does: the job key (e.g. `vttailor`) maps to that
-- society's shop name. The joblabel column is not used.
---@param jobs table list of job keys
---@return table [key] = shop name
function PupCardJobNames(jobs)
    local out = {}
    local want, seen = {}, {}
    for _, j in ipairs(jobs or {}) do
        local key = tostring(j or "")
        if key ~= "" and not seen[key] then
            seen[key] = true
            want[#want + 1] = key
        end
    end
    if #want == 0 then return out end

    -- a society can own several shops; the lowest id wins, matching the ID card
    local ok, rows = pcall(MySQL.query.await,
        ("SELECT society, name FROM society_shops WHERE society IN (%s) ORDER BY id")
        :format(placeholders(#want)), want)
    if not ok then return out end

    for _, r in ipairs(rows or {}) do
        local key = tostring(r.society)
        if out[key] == nil and type(r.name) == "string" and r.name ~= "" then
            out[key] = r.name
        end
    end
    return out
end
