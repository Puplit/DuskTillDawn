-- Modified by Puppet (Dusk Till Dawn), 2026
-- Character codes, server half. Stores a LOOK and hands back a short code.
-- A name is never written here: the client strips it, and so does this.

local Core = exports.vorp_core:GetCore()

-- no O/0 or I/1, because these get read aloud and typed by hand
local ALPHABET <const> = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
local CODE_LEN <const> = 8
local MAX_PAYLOAD <const> = 200000 -- bytes of json, per field

-- keys that must never travel in a code
local STRIP <const> = {
    firstname = true, lastname = true, charidentifier = true, charIdentifier = true,
    identifier = true, name = true, steamname = true, discordid = true,
    money = true, gold = true, rol = true, xp = true, job = true, jobgrade = true,
}

local function newCode()
    local out = {}
    for i = 1, CODE_LEN do
        local n <const> = math.random(#ALPHABET)
        out[i] = ALPHABET:sub(n, n)
    end
    return table.concat(out)
end

local function charOf(src)
    local user <const> = Core.getUser(src)
    local ch = user and user.getUsedCharacter
    return (type(ch) == 'table') and ch or nil
end

local function tip(src, msg)
    TriggerClientEvent('vorp:TipRight', src, msg, 5000)
end

--- strips identity keys out of a decoded skin table
local function scrub(tbl)
    if type(tbl) ~= 'table' then return {} end
    local out = {}
    for k, v in pairs(tbl) do
        if not STRIP[k] and not STRIP[tostring(k):lower()] then out[k] = v end
    end
    return out
end

-- one code per player every CREATE_COOLDOWN ms
local CREATE_COOLDOWN <const> = 30000
local lastCreate = {}

AddEventHandler('playerDropped', function()
    lastCreate[source] = nil
end)

RegisterNetEvent('pup-charcode:create', function(skinJson, compsJson, tintsJson)
    local src <const> = source
    local ch <const> = charOf(src)
    if not ch then return end

    local now <const> = GetGameTimer()
    if lastCreate[src] and now - lastCreate[src] < CREATE_COOLDOWN then
        return tip(src, 'Please wait a little before making another code.')
    end
    lastCreate[src] = now

    if type(skinJson) ~= 'string' or type(compsJson) ~= 'string' then return end
    if tintsJson == nil then tintsJson = '{}' end
    if type(tintsJson) ~= 'string' then return end
    if #skinJson > MAX_PAYLOAD or #compsJson > MAX_PAYLOAD or #tintsJson > MAX_PAYLOAD then
        return tip(src, 'That look is too large to share.')
    end
    local okt, tints = pcall(json.decode, tintsJson)
    if not okt or type(tints) ~= 'table' then
        return tip(src, 'Could not read that look.')
    end

    local ok, skin = pcall(json.decode, skinJson)
    if not ok or type(skin) ~= 'table' or not skin.sex then
        return tip(src, 'Could not read that look.')
    end
    skin = scrub(skin)

    local sex <const> = tostring(skin.sex)
    local payload <const> = json.encode(skin)

    -- a handful of attempts is plenty: 32^8 keys
    for _ = 1, 5 do
        local code <const> = newCode()
        local inserted = MySQL.insert.await(
            'INSERT IGNORE INTO character_codes (code, sex, skin, comps, tints, created_by) VALUES (?, ?, ?, ?, ?, ?)',
            { code, sex, payload, compsJson, tintsJson, tonumber(ch.charIdentifier) })
        if inserted then
            TriggerClientEvent('pup-charcode:made', src, code)
            return
        end
    end

    tip(src, 'Could not make a code just now.')
end)

RegisterNetEvent('pup-charcode:fetch', function(code, context)
    local src <const> = source
    if type(code) ~= 'string' then return end
    code = code:upper():gsub('[^%w]', '')
    if #code < 4 or #code > 12 then return tip(src, 'That is not a character code.') end

    local row <const> = MySQL.single.await(
        'SELECT code, sex, skin, comps, tints FROM character_codes WHERE code = ?', { code })
    if not row then return tip(src, 'No look saved under that code.') end

    -- second gate only: in the creator there is no saved sex yet, so the
    -- client's own check is the one that counts
    local ch <const> = charOf(src)
    local mine = ch and ch.skin
    if type(mine) == 'string' then
        local okm, decoded = pcall(json.decode, mine)
        mine = okm and decoded or nil
    end
    local mySex <const> = type(mine) == 'table' and mine.sex and tostring(mine.sex) or nil
    if context == 'secondchance' and mySex and mySex ~= tostring(row.sex) then
        return tip(src, 'That code is for the other sex.')
    end

    MySQL.update.await('UPDATE character_codes SET uses = uses + 1 WHERE code = ?', { code })
    TriggerClientEvent('pup-charcode:apply', src, row.sex, row.skin, row.comps, row.tints, context)
end)

-- One-time move from the old table name: an older database keeps its saved codes.
-- Only when pup_character_codes exists and character_codes does not; never overwrites anything.
local function renameOldTable(old, new)
    local function has(name)
        return (tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) or 0) > 0
    end
    if not has(old) then return end
    if has(new) then
        print(('^3[vorp_character]^7 both %s and %s exist: using %s, the old table is left alone'):format(old, new, new))
        return
    end
    MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(old, new), {})
    print(('^2[vorp_character]^7 renamed table %s to %s'):format(old, new))
end

CreateThread(function()
    renameOldTable('pup_character_codes', 'character_codes')
    local sql <const> = LoadResourceFile(GetCurrentResourceName(), 'sql/charcodes.sql')
    if sql and sql ~= '' then
        MySQL.query.await(sql)
    end
end)
