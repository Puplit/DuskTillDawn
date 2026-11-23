-- pup_library | server core: helpers, library check, reading and saving books.

local Core = exports.vorp_core:GetCore()
local RESOURCE <const> = GetCurrentResourceName()

Lib = {}

-- [src] = { bookId = n, copyRule = 'author'|'any'|job|nil }
local editSessions = {}
-- [src] = { [key] = last request time }
local lastRequest = {}
-- [src] = true while a money or item action is running for that player
local busy = {}

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------

function Lib.ValidSource(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if not GetPlayerName(src) then return nil end
    return src
end

-- The active character, read fresh each time (money and job change between awaits).
function Lib.Char(src)
    local user = Core.getUser(src)
    if not user then return nil end
    local c = user.getUsedCharacter
    if not c or not c.charIdentifier then return nil end
    return c
end

function Lib.CharId(c)
    return tonumber(c and c.charIdentifier)
end

function Lib.Job(c)
    local job = c and c.job
    if type(job) ~= 'string' then return '' end
    return job
end

function Lib.IsStaff(c)
    return Config.IsStaffJob(Lib.Job(c))
end

function Lib.IsPublisher(c)
    return Config.IsPublisherJob(Lib.Job(c), c and c.jobGrade)
end

function Lib.FullName(c)
    return ('%s %s'):format(tostring(c.firstname or ''), tostring(c.lastname or ''))
end

function Lib.Notify(src, msg, ms)
    TriggerClientEvent('vorp:TipRight', src, msg, ms or Config.Notify.default)
end

-- false when the same kind of request came too soon
function Lib.Gate(src, key, gap)
    local now = GetGameTimer()
    local per = lastRequest[src]
    if not per then
        per = {}
        lastRequest[src] = per
    end
    local last = per[key]
    if last and now - last < (gap or Config.RequestGapMs) then return false end
    per[key] = now
    return true
end

-- Runs fn while holding the player's busy flag. A second request meanwhile is told to wait.
function Lib.Exclusive(src, fn)
    if busy[src] then
        Lib.Notify(src, T('wait'))
        return
    end
    busy[src] = true
    local ok, err = pcall(fn)
    busy[src] = nil
    if not ok then
        print(('^1[%s]^7 action failed for %s: %s'):format(RESOURCE, tostring(src), tostring(err)))
    end
end

--------------------------------------------------------------------------------
-- library check
--------------------------------------------------------------------------------

local function nearLibrary(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return Config.PassAtWorldOrigin end
    local pos = GetEntityCoords(ped)
    if pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0 then
        -- no OneSync: the server cannot see where the player is
        return Config.PassAtWorldOrigin
    end
    for _, lib in ipairs(Config.Libraries) do
        if #(pos - lib.pos) <= Config.ReachDistance then return true end
    end
    return false
end

-- Returns the character when the player may act at a library right now.
function Lib.AtLibrary(src)
    local c = Lib.Char(src)
    if not c then return nil end
    if Config.StaffOnlyLibrary and not Lib.IsStaff(c) then
        Lib.Notify(src, T('staff_only'))
        return nil
    end
    if not nearLibrary(src) then
        Lib.Notify(src, T('not_at_library'))
        return nil
    end
    return c
end

--------------------------------------------------------------------------------
-- edit rules
--------------------------------------------------------------------------------

-- Does one rule let this character edit a book created by `creator`?
local function ruleAllows(rule, c, creator)
    if rule == 'any' then return true end
    if rule == 'author' then return Lib.CharId(c) == tonumber(creator) end
    if rule == 'none' or type(rule) ~= 'string' or rule == '' then return false end
    return Lib.Job(c) == rule
end

-- The book's rule and the copy's rule must both allow it. A copy without a rule follows the book.
function Lib.CanEdit(c, book, copyRule, published)
    if published then return false end
    if not ruleAllows(book.edit, c, book.charid) then return false end
    if copyRule ~= nil and copyRule ~= '' then
        return ruleAllows(copyRule, c, book.charid)
    end
    return true
end

-- The rules a player may choose when creating or printing.
function Lib.ChoosableRule(rule, c)
    if rule == 'author' or rule == 'any' then return true end
    local job = Lib.Job(c)
    return type(rule) == 'string' and job ~= '' and rule == job and rule ~= 'none'
end

function Lib.WorkKind(item)
    if Config.IsWork(item) then return item end
    return Config.DefaultWork
end

--------------------------------------------------------------------------------
-- inventory
--------------------------------------------------------------------------------

function Lib.CanCarry(src, item, amount)
    local ok, res = pcall(function()
        return exports.vorp_inventory:canCarryItem(src, item, amount)
    end)
    return ok and res == true
end

function Lib.Give(src, item, amount, metadata)
    local ok, res = pcall(function()
        return exports.vorp_inventory:addItem(src, item, amount, metadata)
    end)
    return ok and res == true
end

-- Every written work the player carries: { itemId, name, metadata }
function Lib.CarriedWorks(src)
    local ok, items = pcall(function()
        return exports.vorp_inventory:getUserInventoryItems(src)
    end)
    local out = {}
    if not ok or type(items) ~= 'table' then return out end
    for _, it in ipairs(items) do
        local md = type(it.metadata) == 'table' and it.metadata or nil
        if Config.IsWork(it.name) and md and tonumber(md.id) then
            out[#out + 1] = {
                itemId = it.id,
                name = it.name,
                metadata = {
                    id = tonumber(md.id),
                    title = type(md.title) == 'string' and md.title or '',
                    author = type(md.author) == 'string' and md.author or '',
                    edit = type(md.edit) == 'string' and md.edit or nil,
                },
            }
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- money
--------------------------------------------------------------------------------

function Lib.Cash(c)
    return tonumber(c and c.money) or 0
end

--------------------------------------------------------------------------------
-- Discord
--------------------------------------------------------------------------------

function Lib.Log(title, description, colour)
    local url = Secrets.Webhook('publishing')
    if not url then return end
    local payload = {
        username = Config.Discord.username,
        embeds = { {
            title = title,
            description = description,
            color = colour,
            footer = { text = ('%s | %s'):format(Config.Discord.username, os.date('%Y-%m-%d %H:%M:%S')) },
        } },
    }
    if Config.Discord.avatar ~= '' then payload.avatar_url = Config.Discord.avatar end
    PerformHttpRequest(url, function(status)
        if status and (status < 200 or status >= 300) then
            print(('^3[%s]^7 Discord log failed with status %s'):format(RESOURCE, tostring(status)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

--------------------------------------------------------------------------------
-- job and royalty lookup (no library check)
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:hello', function(token)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'hello', 500) then return end
    local c = Lib.Char(src)
    if not c then return end
    local charid = Lib.CharId(c)
    local balance = MySQL.scalar.await('SELECT cash FROM book_royalties WHERE charid = ?', { charid })
    c = Lib.Char(src)
    if not c or Lib.CharId(c) ~= charid then return end
    TriggerClientEvent('pup_library:helloReply', src, token, Lib.Job(c), Config.Round2(balance) or 0,
        charid, tonumber(c.jobGrade) or 0)
end)

--------------------------------------------------------------------------------
-- using a work item
--------------------------------------------------------------------------------

local function useWork(data)
    local src = Lib.ValidSource(data and data.source)
    if not src then return end
    if not Lib.Gate(src, 'use', 1000) then return end
    local c = Lib.Char(src)
    if not c then return end

    local md = data.item and data.item.metadata
    local bookId = type(md) == 'table' and tonumber(md.id) or nil
    if not bookId then
        Lib.Notify(src, T('blank_pages'))
        return
    end
    local copyRule = type(md.edit) == 'string' and md.edit or nil

    local book = MySQL.single.await('SELECT id, title, author, data, edit, charid, item FROM books WHERE id = ?', { bookId })
    if not book then
        Lib.Notify(src, T('blank_pages'))
        return
    end
    local publish = MySQL.scalar.await('SELECT publish FROM books_publishing WHERE id = ?', { bookId })

    c = Lib.Char(src)
    if not c then return end
    local editable = Lib.CanEdit(c, book, copyRule, tonumber(publish) == 1)
    if editable then
        editSessions[src] = { bookId = bookId, copyRule = copyRule }
    else
        editSessions[src] = nil
    end

    TriggerClientEvent('pup_library:openBook', src, {
        id = bookId,
        data = book.data,
        title = book.title,
        author = book.author,
        editable = editable,
    })
end

CreateThread(function()
    for _, w in ipairs(Config.Works) do
        exports.vorp_inventory:registerUsableItem(w.item, useWork, RESOURCE)
    end
end)

--------------------------------------------------------------------------------
-- saving
--------------------------------------------------------------------------------

local SAVE_REFUSAL <const> = { large = 'too_large', pages = 'too_many_pages', bad = 'not_saved' }

RegisterNetEvent('pup_library:save', function(bookId, raw)
    local src = Lib.ValidSource(source)
    if not src then return end
    local session = editSessions[src]
    editSessions[src] = nil -- used up by the attempt
    local c = Lib.Char(src)
    bookId = tonumber(bookId)
    if not c or not session or not bookId or session.bookId ~= bookId then return end

    local cleaned, why = Clean.Book(raw)
    if not cleaned then
        Lib.Notify(src, T(SAVE_REFUSAL[why] or 'not_saved'), Config.Notify.refusal)
        return
    end

    local book = MySQL.single.await('SELECT id, edit, charid FROM books WHERE id = ?', { bookId })
    local publish = MySQL.scalar.await('SELECT publish FROM books_publishing WHERE id = ?', { bookId })
    c = Lib.Char(src)
    if not c then return end
    if not book then
        Lib.Notify(src, T('not_saved'), Config.Notify.refusal)
        return
    end
    if tonumber(publish) == 1 then
        Lib.Notify(src, T('locked'), Config.Notify.refusal)
        return
    end
    if not Lib.CanEdit(c, book, session.copyRule, false) then
        Lib.Notify(src, T('not_saved'), Config.Notify.refusal)
        return
    end

    -- oxmysql raises on a query error; catch it so the player is told
    local queried, result = pcall(MySQL.update.await, 'UPDATE books SET data = ? WHERE id = ?', { cleaned, bookId })
    local affected = queried and tonumber(result) or nil
    if not affected then
        if not queried then
            print(('^1[%s]^7 saving book %d failed: %s'):format(RESOURCE, bookId, tostring(result)))
        end
        -- the query failed: never report a save that did not happen
        Lib.Notify(src, T('not_saved'), Config.Notify.refusal)
        return
    end
    if affected < 1 then
        -- the same data written twice reports 0 rows on some servers; the row exists, so this is still a save
        local still = MySQL.scalar.await('SELECT 1 FROM books WHERE id = ?', { bookId })
        if not still then
            Lib.Notify(src, T('not_saved'), Config.Notify.refusal)
            return
        end
    end
    Lib.Notify(src, T('saved'), Config.Notify.saved)
end)

--------------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------------

-- dropped = the player left; otherwise a character switch
function Lib.Forget(src, dropped)
    editSessions[src] = nil
    if dropped then
        lastRequest[src] = nil
        busy[src] = nil
    end
end

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then Lib.Forget(src, true) end
end)

-- a character switch ends the edit session (saves are re-checked anyway)
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src then Lib.Forget(src, false) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RESOURCE then return end
    -- unRegisterUsableItem would also wipe another resource's handler for a shared item name
    for _, w in ipairs(Config.Works) do
        if not Config.SharedUsableItems[w.item] then
            pcall(function() exports.vorp_inventory:unRegisterUsableItem(w.item) end)
        end
    end
end)
