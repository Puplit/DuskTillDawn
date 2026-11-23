-- pup_staffdesk | paid character changes: height, name, pet names, weapon names
-- Every change is checked and written first, and paid for only once it has gone through.
Changes = {}

local Inv = exports.vorp_inventory

local function pay(ch, price)
    price = math.max(0, tonumber(price) or 0)
    if price == 0 then return true end
    if (tonumber(ch.money) or 0) < price then return false end
    ch.removeCurrency(0, price)
    return true
end

local function canAfford(ch, price)
    return (tonumber(ch.money) or 0) >= math.max(0, tonumber(price) or 0)
end

-------------------------------------------------------------------------------
-- HEIGHT  (the ped scale saved in characters.skinPlayer)
-------------------------------------------------------------------------------
local function readSkin(charid)
    local raw = MySQL.scalar.await('SELECT skinPlayer FROM characters WHERE charidentifier = ?', { charid })
    if type(raw) ~= 'string' then return nil end
    local ok, skin = pcall(json.decode, raw)
    if not ok or type(skin) ~= 'table' then return nil end
    return skin
end

function Changes.height(src)
    local charid = Desk.charid(src)
    local skin = charid and readSkin(charid)
    return skin and tonumber(skin.Scale) or nil
end

function Changes.setHeight(src, value)
    local c = Config.Height
    if not c.enabled then return false, Locale.off end
    local ch = Desk.char(src)
    if not ch then return false, Locale.failed end
    value = tonumber(value)
    if not value or value < c.min or value > c.max then
        return false, Locale.heightRange:format(c.min, c.max)
    end
    value = math.floor(value * 100 + 0.5) / 100
    if not canAfford(ch, c.price) then return false, Locale.noCash end

    local charid = tonumber(ch.charIdentifier)
    local skin = readSkin(charid)
    if not skin then return false, Locale.noSkin end
    local old = tonumber(skin.Scale)
    if old and math.abs(old - value) < 0.001 then return false, Locale.heightSame end

    skin.Scale = value + 0.0
    local encoded = json.encode(skin)
    MySQL.update.await('UPDATE characters SET skinPlayer = ? WHERE charidentifier = ?', { encoded, charid })
    -- the live character too, or vorp writes the old skin back on its next save
    pcall(function() ch.updateSkin(encoded) end)
    pcall(function() exports.vorp_character:RefreshHeight(src) end)
    pay(ch, c.price)

    TriggerClientEvent('pup_staffdesk:heightChanged', src, value)
    Desk.log(Locale.logHeight, ('%s: %s -> %.2f ($%s)'):format(Desk.whoLog(src), old and ('%.2f'):format(old) or '?', value, Desk.money(c.price)))
    return true, Locale.heightDone:format(value)
end

-------------------------------------------------------------------------------
-- NAME
-------------------------------------------------------------------------------
-- "o'brien" -> "O'Brien", "mary-jane" -> "Mary-Jane"; nil if it is not a name
function Changes.cleanName(s)
    local c = Config.Rename
    s = Desk.trim(s)
    if #s < c.minLength or #s > c.maxLength then return nil end
    if not s:match("^[%a][%a'%-]*$") then return nil end
    if s:find("['%-][%-']") or s:match("['%-]$") then return nil end
    local lower = s:lower()
    for _, word in ipairs(c.blocked or {}) do
        if lower:find(word:lower(), 1, true) then return nil end
    end
    return (lower:gsub("^%a", string.upper):gsub("(['%-])(%a)", function(sep, ch) return sep .. ch:upper() end))
end

function Changes.renameLeft(charid)
    return DeskDB.cooldownLeft('name', charid, Config.Rename.cooldownDays)
end

-- the actual write, shared by the desk, staff and the Discord bridge. ch may be nil (offline)
function Changes.writeName(charid, ch, first, last)
    MySQL.update.await('UPDATE characters SET firstname = ?, lastname = ? WHERE charidentifier = ?', { first, last, charid })
    if ch then
        pcall(function()
            if ch.setFirstname then ch.setFirstname(first) else ch.firstname = first end
            if ch.setLastname then ch.setLastname(last) else ch.lastname = last end
        end)
    end
end

function Changes.rename(src, first, last)
    local c = Config.Rename
    if not c.enabled then return false, Locale.off end
    local ch = Desk.char(src)
    if not ch then return false, Locale.failed end
    local charid = tonumber(ch.charIdentifier)

    local f, l = Changes.cleanName(first), Changes.cleanName(last)
    if not f or not l then return false, Locale.badName:format(c.minLength, c.maxLength) end
    if f == ch.firstname and l == ch.lastname then return false, Locale.nameSame end

    local left = Changes.renameLeft(charid)
    if left > 0 then return false, Locale.cooldown:format(Desk.wait(left)) end

    if c.unique then
        local taken = tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM characters WHERE firstname = ? AND lastname = ? AND charidentifier <> ?', { f, l, charid })) or 0
        if taken > 0 then return false, Locale.nameTaken end
    end
    if not canAfford(ch, c.price) then return false, Locale.noCash end

    local oldName = Desk.trim((ch.firstname or '') .. ' ' .. (ch.lastname or ''))
    Changes.writeName(charid, ch, f, l)
    DeskDB.stamp('name', charid)
    pay(ch, c.price)
    Desk.log(Locale.logRename, ('%s is now **%s %s** (charid %d, $%s)'):format(oldName, f, l, charid, Desk.money(c.price)))
    return true, Locale.renamed:format(f, l)
end

-------------------------------------------------------------------------------
-- PETS  (pup-misc owns the whistles and writes the name; the price and cooldown are ours)
-------------------------------------------------------------------------------
local function petsReady()
    return Config.PetName.enabled and GetResourceState('pup-misc') == 'started'
end

local function petLeft(row)
    local days = tonumber(Config.PetName.cooldownDays) or 0
    local at = tonumber(row and row.namedAt) or 0
    if days <= 0 or at <= 0 then return 0 end
    return math.max(0, at + days * 86400 - os.time())
end

function Changes.pets(src)
    if not petsReady() then return nil end
    local ok, rows = pcall(function() return exports['pup-misc']:PetWhistles(src) end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, breed = r.breed, name = r.name or '', desc = r.desc or '', wait = petLeft(r) }
    end
    return out
end

function Changes.namePet(src, id, name, desc)
    if not petsReady() then return false, Locale.off end
    local ch = Desk.char(src)
    if not ch then return false, Locale.failed end
    local ok, row = pcall(function() return exports['pup-misc']:PetWhistleById(src, id) end)
    if not ok or type(row) ~= 'table' then return false, Locale.petMissing end
    local left = petLeft(row)
    if left > 0 then return false, Locale.cooldown:format(Desk.wait(left)) end
    if not canAfford(ch, Config.PetName.price) then return false, Locale.noCash end

    local okSet, done, detail = pcall(function() return exports['pup-misc']:SetPetName(src, id, name, desc) end)
    if not okSet or done ~= true then return false, tostring((okSet and detail) or Locale.failed) end
    pay(ch, Config.PetName.price)
    Desk.log(Locale.logPet, ('%s named their %s **%s**'):format(Desk.whoLog(src), tostring(row.breed), tostring(detail)))
    return true, Locale.named:format(tostring(detail))
end

-------------------------------------------------------------------------------
-- WEAPONS  (vorp's custom_label / custom_desc)
-------------------------------------------------------------------------------
-- the satchel prints a label into an html attribute, so the name is a whitelist
local function cleanWeaponName(s)
    s = Desk.trim(tostring(s or ''):gsub('<[^>]*>', ''):gsub("[^%w%s%-%.,!%?]", ''):gsub('%s+', ' '))
    return s:sub(1, Config.WeaponName.maxNameLength)
end

local function cleanWeaponDesc(s)
    local out = tostring(s or '')
    local ok, cleaned = pcall(function() return Inv:SanitizeDescription(out) end)
    if ok and type(cleaned) == 'string' then out = cleaned else out = out:gsub('<[^>]*>', '') end
    if #(out:gsub('<[^>]*>', '')) > Config.WeaponName.maxDescLength then return nil end
    return out
end

local function weaponsOf(src)
    local list = Inv:getUserInventoryWeapons(src)
    return type(list) == 'table' and list or {}
end

function Changes.weapons(src)
    if not Config.WeaponName.enabled then return nil end
    local out = {}
    for _, w in ipairs(weaponsOf(src)) do
        local id = tonumber(w.id)
        if id then
            out[#out + 1] = {
                id = id, base = Config.WeaponLabels[w.name] or w.label or w.name,
                name = w.custom_label or '', desc = w.custom_desc or '',
                wait = DeskDB.cooldownLeft('weapon', id, Config.WeaponName.cooldownDays),
            }
        end
    end
    return out
end

function Changes.nameWeapon(src, id, name, desc)
    if not Config.WeaponName.enabled then return false, Locale.off end
    local ch = Desk.char(src)
    if not ch then return false, Locale.failed end
    id = tonumber(id)
    local weapon
    for _, w in ipairs(weaponsOf(src)) do if tonumber(w.id) == id then weapon = w break end end
    -- only the player's own weapons: vorp's label setter does not check the owner
    if not weapon then return false, Locale.notYourWeapon end

    local left = DeskDB.cooldownLeft('weapon', id, Config.WeaponName.cooldownDays)
    if left > 0 then return false, Locale.cooldown:format(Desk.wait(left)) end
    local cleanName = cleanWeaponName(name)
    if cleanName == '' then return false, Locale.nameFirst end
    local cleanDesc = cleanWeaponDesc(desc)
    if not cleanDesc then return false, Locale.descLong:format(Config.WeaponName.maxDescLength) end
    if not canAfford(ch, Config.WeaponName.price) then return false, Locale.noCash end

    Inv:setWeaponCustomLabel(src, id, cleanName)
    Inv:setWeaponCustomDesc(src, id, cleanDesc)
    DeskDB.stamp('weapon', id)
    pay(ch, Config.WeaponName.price)
    Desk.log(Locale.logWeapon, ('%s named their %s **%s**'):format(Desk.whoLog(src), Config.WeaponLabels[weapon.name] or weapon.name, cleanName))
    return true, Locale.named:format(cleanName)
end
