-- Player-written item descriptions: sanitising, eligibility and the edit itself.
-- The satchel renders descriptions with .html(), so nothing reaches metadata unsanitised.

local Core = exports.vorp_core:GetCore()

PupItemDesc = {}

PupItemDesc.maxLength = 300

-- Tags kept. Pictures and links are allowed on purpose: shop cards use them.
local ALLOWED_TAGS <const> = {
    b = true, i = true, u = true, br = true, strong = true, em = true,
    small = true, p = true, span = true, div = true, center = true,
    a = true, img = true, font = true,
}

-- per tag: attribute -> how it is cleaned. Anything unlisted is dropped, which
-- is what keeps onerror/onclick and the rest out
local ALLOWED_ATTRS <const> = {
    a    = { href = 'url', target = 'word' },
    img  = { src = 'url', alt = 'word', border = 'word', width = 'word', height = 'word' },
    span = { style = 'style' },
    div  = { style = 'style', align = 'word' },
    p    = { style = 'style', align = 'word' },
    font = { color = 'word', size = 'word', face = 'word' },
}

-- item NAMES that can never be edited, whatever their metadata says
PupItemDesc.blocked = {
    -- paperwork and anything that carries meaning of its own
    letter = true, contract = true, newspaper = true, magazine = true,
    book = true, cards = true, playingcards = true,
}

-- item GROUPS blocked wholesale (vorp item `group` column)
PupItemDesc.blockedGroups = {}

-- substrings in an item name that block it: boxes, packs, gifts, pets, tools
PupItemDesc.blockedLike = {
    'storagebox', 'storage_box', 'transportbox', 'giftbox', 'gift_box',
    'pet_', 'book', 'letter', 'contract', 'newspaper', 'magazine',
}

PupItemDesc.bannedWords = {}

local function escape(s)
    s = s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
    return (s:gsub('"', '&quot;'):gsub("'", '&#39;'))
end

-- http(s) only: blocks javascript:, data: and vbscript: hrefs
local function cleanUrl(v)
    local low <const> = v:lower():gsub('%s', '')
    if low:find('^https?://') and not v:find('[<>"]') then return v end
    return nil
end

local function cleanWord(v)
    if v:find('[<>"\']') or #v > 64 then return nil end
    return v
end

-- inline css minus the parts that can fetch or execute
local function cleanStyle(v)
    if v:find('[<>"]') or #v > 160 then return nil end
    local low <const> = v:lower()
    if low:find('url%s*%(') or low:find('expression') or low:find('javascript')
        or low:find('@import') or low:find('behaviou?r%s*:') then return nil end
    return v
end

local CLEANERS <const> = { url = cleanUrl, word = cleanWord, style = cleanStyle }

--- Rebuild one tag from scratch, keeping only attributes we recognise and could
--- clean. An attacker's attribute is never copied through, so there is nothing
--- to escape out of.
local function rebuildTag(slash, tag, attrs)
    local t <const> = tag:lower()
    if not ALLOWED_TAGS[t] then return '' end
    if slash == '/' then return '</' .. t .. '>' end

    local spec <const> = ALLOWED_ATTRS[t]
    local out, seen = '<' .. t, {}

    if spec then
        local function take(name, value)
            name = name:lower()
            if seen[name] or not spec[name] then return end
            local fn <const> = CLEANERS[spec[name]]
            local v <const> = fn and fn(value)
            if v == nil then return end
            seen[name] = true
            out = out .. (' %s="%s"'):format(name, v)
        end
        for n, v in attrs:gmatch('([%a][%w%-]*)%s*=%s*"([^"]*)"') do take(n, v) end
        for n, v in attrs:gmatch("([%a][%w%-]*)%s*=%s*'([^']*)'") do take(n, v) end
        for n, v in attrs:gmatch('([%a][%w%-]*)%s*=%s*([^%s>"\']+)') do take(n, v) end
    end

    return out .. '>'
end

--- Allowed tags are rebuilt and held aside, EVERYTHING else is escaped, then the
--- rebuilt tags go back. Nothing attacker-written is ever re-enabled as markup.
function PupItemDesc.Sanitize(input)
    local s = tostring(input or '')
    if s == '' then return '' end

    s = s:gsub('<!%-%-.-%-%->', '')
    s = s:gsub('<%s*[sS][cC][rR][iI][pP][tT].-<%s*/%s*[sS][cC][rR][iI][pP][tT]%s*>', '')
    s = s:gsub('<%s*[sS][tT][yY][lL][eE].-<%s*/%s*[sS][tT][yY][lL][eE]%s*>', '')

    local keep = {}
    s = s:gsub('<%s*(/?)%s*([%a][%w]*)([^>]*)>', function(slash, tag, attrs)
        local built <const> = rebuildTag(slash, tag, attrs)
        if built == '' then return '' end
        keep[#keep + 1] = built
        return ('\1%d\1'):format(#keep)
    end)

    s = escape(s)
    s = s:gsub('\1(%d+)\1', function(i) return keep[tonumber(i)] or '' end)
    return s
end

exports('SanitizeDescription', function(text) return PupItemDesc.Sanitize(text) end)

-- VISIBLE length: tags are not charged against the limit
local function plainLength(s)
    local bare <const> = tostring(s or ''):gsub('<[^>]*>', '')
    return #bare
end

local function hasBannedWord(s)
    local low <const> = tostring(s or ''):lower()
    for _, w in ipairs(PupItemDesc.bannedWords) do
        if w ~= '' and low:find(tostring(w):lower(), 1, true) then return true end
    end
    return false
end

function PupItemDesc.IsBlocked(item)
    if not item then return true end
    local name <const> = tostring(item.name or ''):lower()
    if PupItemDesc.blocked[name] then return true end
    if item.group and PupItemDesc.blockedGroups[tostring(item.group)] then return true end
    for _, frag in ipairs(PupItemDesc.blockedLike) do
        if name:find(frag, 1, true) then return true end
    end
    return false
end

--- Only the character who crafted it, and only while it has never been emptied
function PupItemDesc.MayEdit(item, charid)
    if not item or PupItemDesc.IsBlocked(item) then return false end
    if item.type == 'item_weapon' then return false end

    local meta = item.metadata
    if type(meta) == 'string' then
        local ok, decoded = pcall(json.decode, meta)
        meta = ok and decoded or nil
    end
    if type(meta) ~= 'table' then return false end
    if meta.descLocked then return false end

    return tonumber(meta.crafter) ~= nil and tonumber(meta.crafter) == tonumber(charid)
end

-- the client asks for this when the character event has already fired
RegisterNetEvent('pup_inventory:whoAmI', function()
    local src <const> = source
    local user <const> = Core.getUser(src)
    local ch = user and user.getUsedCharacter
    if type(ch) ~= 'table' then return end
    TriggerClientEvent('pup_inventory:whoAmI', src, tonumber(ch.charIdentifier))
end)

local lastEdit = {}

RegisterNetEvent('pup_inventory:setItemDescription', function(itemId, text)
    local src <const> = source
    itemId = tonumber(itemId)
    if not itemId then return end

    -- one edit a second: this writes to the database
    if (GetGameTimer() - (lastEdit[src] or 0)) < 1000 then return end
    lastEdit[src] = GetGameTimer()

    local user <const> = Core.getUser(src)
    local ch = user and user.getUsedCharacter
    if type(ch) ~= 'table' then return end

    local item <const> = exports.vorp_inventory:getItemById(src, itemId)
    if not item then return end

    if not PupItemDesc.MayEdit(item, ch.charIdentifier) then
        return TriggerClientEvent('vorp:TipRight', src, 'You cannot change this item.', 4000)
    end

    local clean <const> = PupItemDesc.Sanitize(text)
    if plainLength(clean) > PupItemDesc.maxLength then
        return TriggerClientEvent('vorp:TipRight', src,
            ('Too long - %s characters at most.'):format(PupItemDesc.maxLength), 4000)
    end
    if hasBannedWord(clean) then
        return TriggerClientEvent('vorp:TipRight', src, 'You cannot use those words.', 4000)
    end

    local meta = item.metadata
    if type(meta) == 'string' then
        local ok, decoded = pcall(json.decode, meta)
        meta = ok and decoded or {}
    end
    if type(meta) ~= 'table' then meta = {} end

    meta.description = clean
    -- emptied on purpose: there is nothing left to identify it by, so it closes
    if clean == '' then meta.descLocked = true end

    exports.vorp_inventory:setItemMetadata(src, itemId, meta, item.count or 1)
    TriggerClientEvent('vorp:TipRight', src, 'Description saved.', 3000)

    -- staff record: the shared audit block every other item action logs through
    if PUP_INVLOG and PUP_INVLOG.Item then
        pcall(function()
            PUP_INVLOG.Item('Description Edited', src, {
                item  = item.name,
                label = item.label,
                desc  = clean ~= '' and clean or '(emptied - now closed)',
                extra = ('item id %s, whole stack of %s'):format(itemId, item.count or 1),
            })
        end)
    end

    TriggerEvent('pup_inventory:descriptionEdited', src, {
        charid = ch.charIdentifier,
        item   = item.name,
        itemId = itemId,
        text   = clean,
    })
end)
