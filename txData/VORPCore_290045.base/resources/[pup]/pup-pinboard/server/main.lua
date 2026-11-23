local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)

local TABLE_SQL = [[
CREATE TABLE IF NOT EXISTS `pinboard_posters` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(16) NOT NULL,
    `content` LONGTEXT NOT NULL,
    `author_charid` INT NOT NULL,
    `author_name` VARCHAR(128) DEFAULT NULL,
    `location` VARCHAR(64) NOT NULL,
    `created_at` INT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `location` (`location`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local function lifetimeSeconds()
    return math.max(1, tonumber(Config.Notices.expireHours) or 24) * 3600
end

local function prune()
    exports.oxmysql:execute("DELETE FROM `pinboard_posters` WHERE `created_at` < ?",
        { os.time() - lifetimeSeconds() })
end

CreateThread(function()
    exports.oxmysql:execute(TABLE_SQL, {}, function()
        -- an older table still has the previous column names until sql/migrate_2026-11-21.sql is run
        exports.oxmysql:execute("SHOW COLUMNS FROM `pinboard_posters` LIKE 'author_charid'", {}, function(r)
            if type(r) ~= 'table' or #r == 0 then
                print('^1[pup-pinboard]^7 `pinboard_posters` has no `author_charid` column: run sql/migrate_2026-11-21.sql')
            end
        end)
        prune()
    end)
    while true do
        Wait(15 * 60 * 1000)
        prune()
    end
end)

-- helpers

local function character(src)
    local ok, user = pcall(function() return VorpCore.getUser(src) end)
    if not ok or not user then return nil, nil end
    return user.getUsedCharacter, user
end

local function boardFor(city)
    for _, b in ipairs(Config.Boards or {}) do
        if b.city == city then return b end
    end
    return nil
end

-- what the page needs to know about the player reading the board
local function whoIs(src)
    local char, user = character(src)
    if not char then return nil end

    local group = user.getGroup or 'user'
    local name  = ((char.firstname or '') .. ' ' .. (char.lastname or '')):gsub('^%s+', '')

    local all = Config.Staff.pinToAllBoards or {}
    local allBoards = ((all.groups or {})[group] == true) or ((all.characters or {})[name] == true)

    return {
        charId    = tonumber(char.charIdentifier) or 0,
        name      = name,
        job       = char.job or '',
        grade     = tonumber(char.jobGrade) or 0,
        allBoards = allBoards,
    }
end

local function mayTakeDownAny(src)
    local char, user = character(src)
    if not char then return false end
    local rule = Config.Staff.takeDownAny or {}
    if (rule.groups or {})[user.getGroup or 'user'] then return true end
    if (rule.jobs or {})[char.job or ''] then return true end
    return false
end

-- a notice without a valid section counts as 'notices'
local SECTIONS <const> = { sale = true, buying = true, jobs = true, notices = true }
local function cleanSection(s)
    s = tostring(s or '')
    return SECTIONS[s] and s or 'notices'
end

-- PO boxes come from pup_postoffice's `mail` table; without it the lookup is skipped
local hasMailTable = false
CreateThread(function()
    exports.oxmysql:execute("SHOW TABLES LIKE 'mail'", {}, function(r)
        hasMailTable = type(r) == 'table' and #r > 0
        if not hasMailTable then print('^3[pup-pinboard]^7 no `mail` table from pup_postoffice: notices will show no PO box') end
    end)
end)

local function poBoxes(rows, cb)
    if not hasMailTable or GetResourceState('pup_postoffice') ~= 'started' then return cb({}) end
    local ids, seen = {}, {}
    for _, r in ipairs(rows or {}) do
        local id = tonumber(r.author_charid)
        if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    if #ids == 0 then return cb({}) end
    local marks = string.rep('?,', #ids):sub(1, -2)
    exports.oxmysql:execute(
        "SELECT `charidentifier`, `address` FROM `mail` WHERE `charidentifier` IN (" .. marks .. ")", ids,
        function(found)
            local boxes = {}
            for _, b in ipairs(found or {}) do
                local c, a = tonumber(b.charidentifier), tonumber(b.address)
                if c and a then boxes[c] = a end
            end
            cb(boxes)
        end)
end

-- rows as the page sees them: no character ids or names, only whether the notice is the reader's own
local function forPage(rows, boxes, myCharId)
    local out = {}
    for _, r in ipairs(rows or {}) do
        local ok, content = pcall(json.decode, r.content or '')
        content = (ok and type(content) == 'table') and content or {}
        local author = tonumber(r.author_charid)
        out[#out + 1] = {
            id      = r.id,
            kind    = r.type == 'image' and 'picture' or 'text',
            content = content,
            section = cleanSection(content.section),
            poBox   = boxes[author],
            mine    = myCharId ~= nil and myCharId > 0 and author == myCharId,
        }
    end
    return out
end

RegisterServerEvent('pup-pinboard:wake')
AddEventHandler('pup-pinboard:wake', function()
    local src = source
    local p = whoIs(src)
    if p then TriggerClientEvent('pup-pinboard:player', src, p) end
end)

local BOARD_REACH <const> = 20.0 -- metres; room to step back with the board open
local MAX_NOTICE_BYTES <const> = 20000
local POST_EVERY_MS <const> = 10000
local MAX_LIST <const> = 200
local MAX_LINES <const> = 10
local MAX_HEADING <const> = 120
local MAX_BODY <const> = 1200
local MAX_URL <const> = 1024

local function nearBoard(src, board)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not board then return false end
    local c = GetEntityCoords(ped)
    local dx, dy, dz = c.x - board.coords[1], c.y - board.coords[2], c.z - board.coords[3]
    return dx * dx + dy * dy + dz * dz <= BOARD_REACH * BOARD_REACH
end

local function nearAnyBoard(src)
    for _, b in ipairs(Config.Boards or {}) do
        if nearBoard(src, b) then return true end
    end
    return false
end

local lastPost = {}
-- per-player gap for list reads and removals; a list asked inside the gap is answered once it is over
local LIST_EVERY_MS <const>, REMOVE_EVERY_MS <const> = 1000, 1000
local lastList, listQueued, lastRemove = {}, {}, {}
AddEventHandler('playerDropped', function()
    lastPost[source] = nil
    lastList[source], listQueued[source], lastRemove[source] = nil, nil, nil
end)

-- reads

local function sendList(src, city, token)
    local p = whoIs(src)
    exports.oxmysql:execute(
        "SELECT * FROM `pinboard_posters` WHERE `location` = ? AND `created_at` >= ? ORDER BY `id` DESC LIMIT " .. MAX_LIST,
        { tostring(city), os.time() - lifetimeSeconds() },
        function(rows)
            poBoxes(rows, function(boxes)
                TriggerClientEvent('pup-pinboard:list', src, token, {
                    ok           = true,
                    notices      = forPage(rows, boxes, p and p.charId),
                    canRemoveAny = mayTakeDownAny(src),
                    -- the board can open before pup-pinboard:wake answers
                    player       = p,
                })
            end)
        end)
end

RegisterServerEvent('pup-pinboard:getList')
AddEventHandler('pup-pinboard:getList', function(city, _, token)
    local src = source
    local nowMs = GetGameTimer()
    if lastList[src] and nowMs - lastList[src] < LIST_EVERY_MS then
        -- only the newest request waits; the page ignores answers to older ones
        local queued = listQueued[src]
        listQueued[src] = { city = city, token = token }
        if queued then return end
        SetTimeout(LIST_EVERY_MS, function()
            local q = listQueued[src]
            listQueued[src] = nil
            if not q or not GetPlayerName(src) then return end
            lastList[src] = GetGameTimer()
            sendList(src, q.city, q.token)
        end)
        return
    end
    lastList[src] = nowMs
    sendList(src, city, token)
end)

-- what is saved: only these fields, whatever else the page sent
--   text:    { paper = 1..6, section, lines = { { style = 'heading'|'body', align = 'left'|'center'|'right', text } } }
--   picture: { picture = 'https://...', section }

local STYLES <const> = { heading = true, body = true }
local ALIGNS <const> = { left = true, center = true, right = true }

local function textContent(data)
    local lines = {}
    for _, l in ipairs(type(data.lines) == 'table' and data.lines or {}) do
        if #lines >= MAX_LINES then break end
        if type(l) == 'table' and type(l.text) == 'string' then
            local style = STYLES[l.style] and l.style or 'body'
            local text = l.text:gsub('^%s+', ''):gsub('%s+$', '')
            text = text:sub(1, style == 'heading' and MAX_HEADING or MAX_BODY)
            if text ~= '' then
                lines[#lines + 1] = { style = style, align = ALIGNS[l.align] and l.align or 'left', text = text }
            end
        end
    end
    local paper = math.tointeger(tonumber(data.paper)) or 5
    if paper < 1 or paper > 6 then paper = 5 end
    return { paper = paper, section = cleanSection(data.section), lines = lines }
end

local function pictureContent(data)
    return { picture = tostring(data.picture or ''), section = cleanSection(data.section) }
end

local function insert(src, city, kind, content, cb)
    local p = whoIs(src)
    if not p then return cb(false) end

    exports.oxmysql:insert(
        "INSERT INTO `pinboard_posters` (`type`, `content`, `author_charid`, `author_name`, `location`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)",
        { kind, json.encode(content), p.charId, p.name, city, os.time() },
        function(id) cb(id and true or false) end)
end

local function targets(src, city, allBoards)
    local p = whoIs(src)
    if allBoards and p and p.allBoards then
        local all = {}
        for _, b in ipairs(Config.Boards or {}) do all[#all + 1] = b.city end
        return all
    end
    return { city }
end

-- the stored type stays 'image' for pictures, so rows from before the rename still read
local function kindAllowed(city, kind)
    local board = boardFor(city)
    if not board then return false end
    local key = kind == 'image' and 'picture' or 'text'
    if (Config.Notices.kinds or {})[key] == false then return false end
    if (board.kinds or {})[key] == false then return false end
    return true
end

local function jobAllowed(src, city)
    local board = boardFor(city)
    local jobs = board and board.jobs
    if not jobs or next(jobs) == nil then return true end
    local char = character(src)
    if not char then return false end
    local needed = jobs[char.job or '']
    return needed ~= nil and (tonumber(char.jobGrade) or 0) >= tonumber(needed)
end

local function hostRefused(city, url)
    url = tostring(url or ''):lower()
    local board = boardFor(city)
    for _, list in ipairs({ Config.Notices.refusedHosts or {}, (board and board.refusedHosts) or {} }) do
        for _, host in ipairs(list) do
            if url:find(tostring(host):lower(), 1, true) then return true end
        end
    end
    return false
end

local function save(src, city, kind, content, allBoards, token)
    local reply = function(ok, reason)
        TriggerClientEvent('pup-pinboard:saved', src, token, { ok = ok and true or false, reason = reason })
    end

    if not kindAllowed(city, kind) or not jobAllowed(src, city) then return reply(false, 'not_allowed') end
    if not nearBoard(src, boardFor(city)) then return reply(false, 'too_far') end

    if kind == 'image' then
        local url = content.picture
        if url == '' then return reply(false, 'link_missing') end
        -- the URL loads on every viewer's screen
        if #url > MAX_URL or not url:lower():match('^https?://[^%s\\]+$') then return reply(false, 'link_invalid') end
        if hostRefused(city, url) then return reply(false, 'link_blocked') end
    elseif #content.lines == 0 then
        return reply(false, 'write_first')
    end

    if #json.encode(content) > MAX_NOTICE_BYTES then return reply(false, 'too_long') end

    local nowMs = GetGameTimer()
    if lastPost[src] and nowMs - lastPost[src] < POST_EVERY_MS then return reply(false, 'too_fast') end
    lastPost[src] = nowMs

    local list = targets(src, city, allBoards)
    local left = #list
    if left == 0 then return reply(false) end

    local function pin()
        local pinned = 0
        for _, target in ipairs(list) do
            insert(src, target, kind, content, function(ok)
                left = left - 1
                if ok then pinned = pinned + 1 end
                if left == 0 then
                    reply(pinned > 0)
                    if pinned > 0 then Discord(kind, content, city) end
                end
            end)
        end
    end

    -- the per-character cap does not apply to those who may pin to every board
    local cap = tonumber(Config.Notices.perCharacter) or 0
    local p = whoIs(src)
    if cap <= 0 or not p or p.allBoards then return pin() end
    exports.oxmysql:execute("SELECT COUNT(*) AS n FROM `pinboard_posters` WHERE `author_charid` = ? AND `created_at` >= ?",
        { p.charId, os.time() - lifetimeSeconds() }, function(rows)
            if (tonumber(rows and rows[1] and rows[1].n) or 0) >= cap then return reply(false, 'too_many') end
            pin()
        end)
end

RegisterServerEvent('pup-pinboard:saveText')
AddEventHandler('pup-pinboard:saveText', function(city, data, token)
    if type(data) ~= 'table' then return end
    save(source, city, 'text', textContent(data), data.allBoards == true, token)
end)

RegisterServerEvent('pup-pinboard:saveImage')
AddEventHandler('pup-pinboard:saveImage', function(city, data, token)
    if type(data) ~= 'table' then return end
    save(source, city, 'image', pictureContent(data), data.allBoards == true, token)
end)

RegisterServerEvent('pup-pinboard:remove')
AddEventHandler('pup-pinboard:remove', function(data, token)
    local src = source
    local id = tonumber(type(data) == 'table' and data.id)
    if not id then return end

    local nowMs = GetGameTimer()
    if lastRemove[src] and nowMs - lastRemove[src] < REMOVE_EVERY_MS then
        return TriggerClientEvent('pup-pinboard:removed', src, token, { ok = false, reason = 'too_fast' })
    end
    lastRemove[src] = nowMs

    local p = whoIs(src)
    if not p then return end

    -- ownership is enforced here; the page only hides the button
    exports.oxmysql:execute("SELECT `author_charid` FROM `pinboard_posters` WHERE `id` = ?", { id },
        function(rows)
            local row = rows and rows[1]
            if not row then return end
            local mine = tonumber(row.author_charid) == p.charId
            if not mine and not mayTakeDownAny(src) then
                TriggerClientEvent('pup-pinboard:removed', src, token, { ok = false, reason = 'not_allowed' })
                return
            end
            exports.oxmysql:execute("DELETE FROM `pinboard_posters` WHERE `id` = ?", { id }, function()
                TriggerClientEvent('pup-pinboard:removed', src, token, { ok = true })
            end)
        end)
end)

-- eco boost (owned by Config.EcoBoost.resource)

local NO_ECO = { state = 'disabled' }

RegisterServerEvent('pup-pinboard:ecoStatus')
AddEventHandler('pup-pinboard:ecoStatus', function(_, token)
    local src = source
    local ok, status = pcall(function() return exports[Config.EcoBoost.resource]:GetEcoBoostStatus(src) end)
    TriggerClientEvent('pup-pinboard:eco', src, token, {
        ok     = ok and true or false,
        status = (ok and type(status) == 'table') and status or NO_ECO,
    })
end)

RegisterServerEvent('pup-pinboard:ecoActivate')
AddEventHandler('pup-pinboard:ecoActivate', function(_, token)
    local src = source
    if not nearAnyBoard(src) then
        return TriggerClientEvent('pup-pinboard:eco', src, token, { ok = false, status = NO_ECO, reason = 'disabled' })
    end
    local ok, res = pcall(function() return exports[Config.EcoBoost.resource]:ActivateEcoBoost(src) end)
    if not ok or type(res) ~= 'table' then res = { ok = false, status = NO_ECO, reason = 'disabled' } end
    TriggerClientEvent('pup-pinboard:eco', src, token, {
        ok     = res.ok and true or false,
        status = res.status or NO_ECO,
        reason = res.reason,
    })
end)

-- admin

RegisterCommand(Config.Command.wipe, function(src)
    if src ~= 0 then
        local _, user = character(src)
        if not user or user.getGroup ~= 'admin' then return end
    end
    exports.oxmysql:execute("DELETE FROM `pinboard_posters`", {}, function()
        print('^3[pup-pinboard]^7 every notice taken down')
    end)
end, false)

-- logging

-- the webhook never includes character details
function Discord(kind, content, city)
    local hook = Secrets.Webhooks and Secrets.Webhooks.posters
    if not hook or hook == '' then return end

    local name = Config.Logging.webhookUsername or 'Somebody'
    local footer = { text = ('Town: %s | Section: %s'):format(tostring(city), tostring(content.section or 'notices')) }

    local embed
    if kind == 'image' then
        local url <const> = tostring(content.picture or '')
        embed = {
            color = 3447003,
            title = 'New picture pinned',
            description = ('[View the picture](%s)'):format(url),
            image = { url = url },
            footer = footer,
        }
    else
        local lines = {}
        for _, l in ipairs(content.lines or {}) do
            lines[#lines + 1] = tostring(l.text or '')
        end
        local body = table.concat(lines, '\n')
        if body:gsub('%s', '') == '' then body = '_(no text on this notice)_' end
        embed = {
            color = 3447003,
            title = 'New text pinned',
            description = body:sub(1, 4000), -- Discord's description ceiling is 4096
            footer = footer,
        }
    end

    PerformHttpRequest(hook, function() end, 'POST',
        json.encode({ username = name, embeds = { embed } }),
        { ['Content-Type'] = 'application/json' })
end
