-- pup_library | library actions: create, print, publish, buy, royalties.
-- The server decides every price, distance, rule and owner. Client values are ids and choices only.

local RESOURCE <const> = GetCurrentResourceName()

local collecting = {}   -- [charid] = true while a royalty collection runs
local titleLocks = {}   -- [lower title] = true while an application for it is being written

local function trimTo(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    -- broken UTF-8 would make the utf8mb4 insert fail; refuse it
    local chars = utf8.len(s)
    if not chars then return nil end
    -- cut on a character boundary
    if chars > max then
        s = s:sub(1, (utf8.offset(s, max + 1) or (#s + 1)) - 1)
    end
    return s
end

local function workMetadata(id, title, author, edit)
    return { id = id, title = title, author = author, edit = edit }
end

local function reply(src, token, kind, rows)
    TriggerClientEvent('pup_library:list', src, token, kind, rows)
end

--------------------------------------------------------------------------------
-- create
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:create', function(item, title, author, rule)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'create') then return end
    Lib.Exclusive(src, function()
        local c = Lib.AtLibrary(src)
        if not c then return end
        if type(title) ~= 'string' or type(author) ~= 'string' then return end
        if not Config.IsWork(item) then return end
        if not Lib.ChoosableRule(rule, c) then return end
        title = trimTo(title, Config.TitleMax)
        author = trimTo(author, Config.AuthorMax)
        if not title or not author then return end

        local cost = (Lib.IsStaff(c) and Config.StaffCreateFree) and 0 or Config.CreatePrice
        if Lib.Cash(c) < cost then
            Lib.Notify(src, T('no_cash'))
            return
        end
        if not Lib.CanCarry(src, item, 1) then
            Lib.Notify(src, T('no_space'))
            return
        end

        local charid = Lib.CharId(c)
        local id = MySQL.insert.await(
            'INSERT INTO books (title, author, data, edit, charid, item) VALUES (?, ?, ?, ?, ?, ?)',
            { title, author, Clean.NewBook(), rule, charid, item })
        id = tonumber(id)
        if not id or id < 1 then return end

        -- check everything again: the insert waited
        c = Lib.Char(src)
        local undo = false
        if not c or Lib.CharId(c) ~= charid then
            undo = true
        elseif Lib.Cash(c) < cost then
            Lib.Notify(src, T('no_cash'))
            undo = true
        elseif not Lib.CanCarry(src, item, 1) then
            Lib.Notify(src, T('no_space'))
            undo = true
        end
        if undo then
            MySQL.update.await('DELETE FROM books WHERE id = ?', { id })
            return
        end

        if cost > 0 then c.removeCurrency(0, cost) end
        if not Lib.Give(src, item, 1, workMetadata(id, title, author, rule)) then
            -- nothing was given: hand the money back and forget the record
            c = Lib.Char(src)
            if c and cost > 0 and Lib.CharId(c) == charid then c.addCurrency(0, cost) end
            MySQL.update.await('DELETE FROM books WHERE id = ?', { id })
            Lib.Notify(src, T('no_space'))
            return
        end
        Lib.Notify(src, T('created'))
    end)
end)

--------------------------------------------------------------------------------
-- carried works and print
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:listCarried', function(token)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'list') then return end
    if not Lib.AtLibrary(src) then return end
    local rows = {}
    for _, w in ipairs(Lib.CarriedWorks(src)) do
        rows[#rows + 1] = { itemId = w.itemId, name = w.name, metadata = w.metadata }
    end
    reply(src, token, 'carried', rows)
end)

RegisterNetEvent('pup_library:print', function(itemId, copies, rule)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'print') then return end
    Lib.Exclusive(src, function()
        local c = Lib.AtLibrary(src)
        if not c then return end
        copies = tonumber(copies)
        if not copies or math.type(copies) ~= 'integer' and copies ~= math.floor(copies) then return end
        copies = math.floor(copies)
        if copies < 1 or copies > Config.MaxCopies then return end
        local staff = Lib.IsStaff(c)
        if Config.PrintStaffOnly and not staff then
            Lib.Notify(src, T('staff_only'))
            return
        end
        if not Lib.ChoosableRule(rule, c) then return end

        -- the player must hold a written copy; its kind and book id come from the inventory
        local held
        for _, w in ipairs(Lib.CarriedWorks(src)) do
            if tostring(w.itemId) == tostring(itemId) then
                held = w
                break
            end
        end
        if not held then
            Lib.Notify(src, T('must_carry'))
            return
        end
        local item = held.name
        local bookId = held.metadata.id

        local charid = Lib.CharId(c)
        local book = MySQL.single.await('SELECT id, title, author, charid FROM books WHERE id = ?', { bookId })
        if not book then return end

        c = Lib.Char(src)
        if not c or Lib.CharId(c) ~= charid then return end
        if Config.PrintAuthorOnly and tonumber(book.charid) ~= charid then
            Lib.Notify(src, T('author_only_print'))
            return
        end
        staff = Lib.IsStaff(c)
        local perCopy = (staff and Config.StaffPrintFree) and 0 or Config.PrintPrice
        local cost = Config.Round2(perCopy * copies)
        if Lib.Cash(c) < cost then
            Lib.Notify(src, T('no_cash'))
            return
        end
        if not Lib.CanCarry(src, item, copies) then
            Lib.Notify(src, T('no_space'))
            return
        end

        if cost > 0 then c.removeCurrency(0, cost) end
        if not Lib.Give(src, item, copies, workMetadata(bookId, book.title, book.author, rule)) then
            c = Lib.Char(src)
            if c and cost > 0 and Lib.CharId(c) == charid then c.addCurrency(0, cost) end
            Lib.Notify(src, T('no_space'))
            return
        end
        Lib.Notify(src, T('printed'))
    end)
end)

--------------------------------------------------------------------------------
-- apply to publish
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:listOwn', function(token)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'list') then return end
    local c = Lib.AtLibrary(src)
    if not c then return end
    local rows = MySQL.query.await(
        'SELECT id, title FROM books WHERE charid = ? AND id NOT IN (SELECT id FROM books_publishing) ORDER BY title',
        { Lib.CharId(c) }) or {}
    reply(src, token, 'own', rows)
end)

RegisterNetEvent('pup_library:apply', function(bookId, price)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'apply') then return end
    Lib.Exclusive(src, function()
        local c = Lib.AtLibrary(src)
        if not c then return end
        price = Config.Round2(price)
        if not price or price <= 0 then
            Lib.Notify(src, T('invalid_amount'))
            return
        end
        if price > Config.MaxSalePrice then
            Lib.Notify(src, T('price_cap', Config.Money(Config.MaxSalePrice)))
            return
        end
        bookId = tonumber(bookId)
        if not bookId then return end
        local charid = Lib.CharId(c)
        local book = MySQL.single.await('SELECT id, title, author, charid FROM books WHERE id = ?', { bookId })
        if not book or tonumber(book.charid) ~= charid then return end

        local key = tostring(book.title):lower()
        if titleLocks[key] then
            Lib.Notify(src, T('wait'))
            return
        end
        titleLocks[key] = true
        local ok, err = pcall(function()
            local clash = MySQL.scalar.await('SELECT 1 FROM books_publishing WHERE id = ? OR title = ? LIMIT 1',
                { bookId, book.title })
            if clash then
                Lib.Notify(src, T('already_applied'))
                return
            end
            c = Lib.Char(src)
            if not c or Lib.CharId(c) ~= charid then return end
            if Lib.Cash(c) < Config.ApplicationFee then
                Lib.Notify(src, T('no_cash'))
                return
            end

            local inserted = MySQL.update.await(
                'INSERT IGNORE INTO books_publishing (id, publish, charid, copies, price, title) VALUES (?, 0, ?, 0, ?, ?)',
                { bookId, charid, price, book.title })
            if (tonumber(inserted) or 0) < 1 then
                Lib.Notify(src, T('already_applied'))
                return
            end

            c = Lib.Char(src)
            if not c or Lib.CharId(c) ~= charid or Lib.Cash(c) < Config.ApplicationFee then
                MySQL.update.await('DELETE FROM books_publishing WHERE id = ? AND publish = 0', { bookId })
                if c then Lib.Notify(src, T('no_cash')) end
                return
            end
            c.removeCurrency(0, Config.ApplicationFee)

            local who = Lib.FullName(c)
            if Config.LedgerIntegration and Config.PublishJob ~= '' and GetResourceState('pup_business') == 'started' then
                local called, res, why = pcall(function()
                    return exports.pup_business:AddToLedger(Config.PublishJob, Config.ApplicationFee, Config.LedgerReason, who)
                end)
                if not called or res == false then
                    print(('^3[%s]^7 pup_business AddToLedger failed (%s): the fee was taken but not credited.')
                        :format(RESOURCE, tostring(called and why or res)))
                end
            end

            Lib.Notify(src, T('applied'))
            Lib.Log(T('log_application'),
                ('**%s:** %s\n**%s:** %s\n**%s:** %s\n**%s:** %s'):format(
                    T('log_title'), book.title, T('log_author'), book.author,
                    T('log_applicant'), who, T('log_price'), Config.Money(price)),
                Config.Discord.colours.application)
        end)
        titleLocks[key] = nil
        if not ok then error(err) end
    end)
end)

--------------------------------------------------------------------------------
-- lists and details
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:listShelf', function(token)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'list') then return end
    if not Lib.AtLibrary(src) then return end
    local rows = MySQL.query.await(
        'SELECT id, publish, copies, price, title FROM books_publishing WHERE publish = 1 ORDER BY title') or {}
    reply(src, token, 'shelf', rows)
end)

RegisterNetEvent('pup_library:listQueue', function(token)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'list') then return end
    local c = Lib.AtLibrary(src)
    if not c or not Lib.IsPublisher(c) then return end
    local rows = MySQL.query.await(
        'SELECT id, publish, charid, copies, price, title FROM books_publishing WHERE publish = 0 ORDER BY title') or {}
    reply(src, token, 'queue', rows)
end)

-- mode 'shelf' (published only, anyone) or 'queue' (pending only, publishers)
RegisterNetEvent('pup_library:details', function(token, bookId, mode)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'details', 300) then return end
    local c = Lib.AtLibrary(src)
    if not c then return end
    bookId = tonumber(bookId)
    if not bookId then return end
    local wanted
    if mode == 'shelf' then
        wanted = 1
    elseif mode == 'queue' then
        if not Lib.IsPublisher(c) then return end
        wanted = 0
    else
        return
    end
    local row = MySQL.single.await([[
        SELECT b.id, b.title, b.author, b.item, b.charid, p.price, p.copies
        FROM books b JOIN books_publishing p ON p.id = b.id
        WHERE b.id = ? AND p.publish = ?]], { bookId, wanted })
    if not row then return end
    c = Lib.Char(src)
    if not c then return end
    reply(src, token, mode == 'shelf' and 'title' or 'application', {
        id = row.id,
        title = row.title,
        author = row.author,
        item = Lib.WorkKind(row.item),
        price = Config.Round2(row.price) or 0,
        copies = tonumber(row.copies) or 0,
        mine = tonumber(row.charid) == Lib.CharId(c),
        canRemove = tonumber(row.charid) == Lib.CharId(c) or Lib.IsPublisher(c),
    })
end)

--------------------------------------------------------------------------------
-- approve, remove/reject, reading copy
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:approve', function(bookId)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'approve') then return end
    local c = Lib.AtLibrary(src)
    if not c or not Lib.IsPublisher(c) then return end
    bookId = tonumber(bookId)
    if not bookId then return end
    local changed = MySQL.update.await('UPDATE books_publishing SET publish = 1 WHERE id = ? AND publish = 0', { bookId })
    if (tonumber(changed) or 0) < 1 then return end
    local title = MySQL.scalar.await('SELECT title FROM books_publishing WHERE id = ?', { bookId }) or '?'
    Lib.Notify(src, T('approved'))
    c = Lib.Char(src)
    Lib.Log(T('log_published'),
        ('**%s:** %s\n**%s:** %s'):format(T('log_title'), title, T('log_by'), c and Lib.FullName(c) or '?'),
        Config.Discord.colours.published)
end)

RegisterNetEvent('pup_library:remove', function(bookId, reason)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'remove') then return end
    local c = Lib.AtLibrary(src)
    if not c then return end
    bookId = tonumber(bookId)
    if not bookId then return end
    reason = trimTo(reason, Config.ReasonMax)

    local listing = MySQL.single.await('SELECT id, charid, title FROM books_publishing WHERE id = ?', { bookId })
    if not listing then return end
    c = Lib.Char(src)
    if not c then return end
    if tonumber(listing.charid) ~= Lib.CharId(c) and not Lib.IsPublisher(c) then return end

    local deleted = MySQL.update.await('DELETE FROM books_publishing WHERE id = ?', { bookId })
    if (tonumber(deleted) or 0) < 1 then return end
    Lib.Notify(src, T('removed'))
    local who = Lib.FullName(c)
    if reason then
        Lib.Log(T('log_rejected'),
            ('**%s:** %s\n%s\n**%s:** %s'):format(T('log_title'), tostring(listing.title),
                T('log_rejected_reason', reason), T('log_by'), who),
            Config.Discord.colours.removed)
    else
        Lib.Log(T('log_removed'),
            ('**%s:** %s\n**%s:** %s'):format(T('log_title'), tostring(listing.title), T('log_by'), who),
            Config.Discord.colours.removed)
    end
end)

RegisterNetEvent('pup_library:readingCopy', function(bookId)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'copy') then return end
    Lib.Exclusive(src, function()
        local c = Lib.AtLibrary(src)
        if not c or not Lib.IsPublisher(c) then return end
        bookId = tonumber(bookId)
        if not bookId then return end
        local row = MySQL.single.await([[
            SELECT b.id, b.title, b.author, b.item
            FROM books b JOIN books_publishing p ON p.id = b.id WHERE b.id = ?]], { bookId })
        if not row then return end
        c = Lib.Char(src)
        if not c or not Lib.IsPublisher(c) then return end
        local item = Lib.WorkKind(row.item)
        if not Lib.CanCarry(src, item, 1) then
            Lib.Notify(src, T('no_space'))
            return
        end
        if not Lib.Give(src, item, 1, workMetadata(row.id, row.title, row.author, 'none')) then
            Lib.Notify(src, T('no_space'))
            return
        end
        Lib.Notify(src, T('got_copy'))
    end)
end)

--------------------------------------------------------------------------------
-- buy
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:buy', function(bookId)
    local src = Lib.ValidSource(source)
    if not src or not Lib.Gate(src, 'buy') then return end
    Lib.Exclusive(src, function()
        local c = Lib.AtLibrary(src)
        if not c then return end
        bookId = tonumber(bookId)
        if not bookId then return end
        local row = MySQL.single.await([[
            SELECT b.id, b.title, b.author, b.item, p.charid, p.price
            FROM books b JOIN books_publishing p ON p.id = b.id
            WHERE b.id = ? AND p.publish = 1]], { bookId })
        if not row then return end
        local price = Config.Round2(row.price) or 0
        if price < 0 then return end
        local item = Lib.WorkKind(row.item)

        c = Lib.Char(src)
        if not c then return end
        local charid = Lib.CharId(c)
        if Lib.Cash(c) < price then
            Lib.Notify(src, T('no_cash'))
            return
        end
        if not Lib.CanCarry(src, item, 1) then
            Lib.Notify(src, T('no_space'))
            return
        end
        -- checked once more right before charging (nothing waits between this check and the charge)
        c = Lib.Char(src)
        if not c or Lib.CharId(c) ~= charid or Lib.Cash(c) < price then
            Lib.Notify(src, T('no_cash'))
            return
        end
        if price > 0 then c.removeCurrency(0, price) end

        if not Lib.Give(src, item, 1, workMetadata(row.id, row.title, row.author, 'none')) then
            c = Lib.Char(src)
            if c and price > 0 and Lib.CharId(c) == charid then c.addCurrency(0, price) end
            Lib.Notify(src, T('no_space'))
            return
        end

        MySQL.update.await('UPDATE books_publishing SET copies = copies + 1 WHERE id = ?', { bookId })
        local creator = tonumber(row.charid)
        if creator and price > 0 then
            MySQL.update.await(
                'INSERT INTO book_royalties (charid, cash) VALUES (?, ?) ON DUPLICATE KEY UPDATE cash = cash + VALUES(cash)',
                { creator, price })
        end
        Lib.Notify(src, T('bought'))
    end)
end)

--------------------------------------------------------------------------------
-- royalties
--------------------------------------------------------------------------------

RegisterNetEvent('pup_library:collect', function()
    local src = Lib.ValidSource(source)
    if not src then return end
    local c = Lib.AtLibrary(src)
    if not c then return end
    local charid = Lib.CharId(c)
    if collecting[charid] then
        Lib.Notify(src, T('wait'))
        return
    end
    collecting[charid] = true
    local ok, err = pcall(function()
        local cash = MySQL.scalar.await('SELECT cash FROM book_royalties WHERE charid = ?', { charid })
        local amount = Config.Round2(cash) or 0
        if amount <= 0 then return end
        local changed = MySQL.update.await(
            'UPDATE book_royalties SET cash = GREATEST(cash - ?, 0) WHERE charid = ?', { amount, charid })
        if (tonumber(changed) or 0) < 1 then return end
        c = Lib.Char(src)
        if not c or Lib.CharId(c) ~= charid then
            -- the character changed while we waited: put the money back for its owner
            MySQL.update.await('UPDATE book_royalties SET cash = cash + ? WHERE charid = ?', { amount, charid })
            return
        end
        c.addCurrency(0, amount)
        Lib.Notify(src, T('collected', Config.Money(amount)))
    end)
    collecting[charid] = nil
    if not ok then
        print(('^1[%s]^7 royalty collection failed for char %s: %s'):format(RESOURCE, tostring(charid), tostring(err)))
    end
end)
