-- pup_tailor | the dye book: an NUI page on the left, a mannequin on the right.
local U = Tailor.U
local Cat = Tailor.Cat
local Ped = Tailor.Ped
local S = Tailor.S

local READY_MS <const> = 4000
local SAVE_GAP_MS <const> = 3000

local B = {}
Tailor.Book = B

local book = nil -- { sessId, ready, pickSeq, item = { id, name, outfit, sex, slots }, lastSave }

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function toast(text, bad)
    send('toast', { text = tostring(text or ''), bad = bad == true })
end

local function pageText()
    return {
        title = L('bookTitle'), empty = L('bookEmpty'), back = L('bookBack'),
        namePlaceholder = L('bookPaletteName'), nameBtn = L('bookNameBtn'),
        copy = L('bookCopy'), paste = L('bookPaste'), undye = L('bookUndye'),
        before = L('bookBefore'), save = L('bookSave'), cost = Locale.bookCost,
        free = L('bookFree'), palette = Locale.bookPalette, keys = L('bookKeys'),
        pick = L('bookPick'), onlyTailor = L('onlyTailorDye'), colourFirst = L('colourFirst'),
    }
end

local function theme()
    local ok, t = pcall(function() return exports['pup-ui']:GetTheme() end)
    if ok and type(t) == 'table' then return t end
    return nil
end

function B.isOpen() return book ~= nil end

function B.namesChanged()
    if book then send('names', S.paletteNames) end
end

-- close the page. silent = called from endSession (do not end it again)
function B.close(silent)
    if not book then return end
    book = nil
    SetNuiFocus(false, false)
    send('close', {})
    Ped.removeMannequin()
    if not silent then Tailor.endSession() end
end

function B.open(items)
    if book or not S.session then return end
    -- the player's own menu side (saved when the tailor opened, before any scene forced one)
    local side = S.session.savedSide == 'right' and 'right' or 'left'
    book = { sessId = S.session.id, ready = false, pickSeq = 0, item = nil, lastSave = 0, side = side }
    local me = book
    send('open', {
        side = side,
        items = items or {},
        palettes = Cat.palettes,
        channels = Locale.channels,
        names = S.paletteNames,
        text = pageText(),
        materials = Config.DyeMaterials,
        preview = S.session.preview == true,
        theme = theme(),
    })
    TriggerServerEvent('pup_tailor:askPaletteNames')
    SetNuiFocus(true, true)
    SetTimeout(READY_MS, function()
        if book == me and not me.ready then
            B.close(false)
            Tailor.tip(L('bookFailed'), 5000)
        end
    end)
end

local function dressItem(item)
    local ped = Ped.mannequin()
    if not ped then return end
    for slot, s in pairs(item.slots) do
        Ped.putOn(ped, slot, s.hash, item.sex)
    end
    Ped.refresh(ped)
end

local function clearItem()
    if not book then return end
    book.pickSeq = book.pickSeq + 1
    book.item = nil
    Ped.removeMannequin()
end

---------------------------------------------------------------------------
-- page callbacks
---------------------------------------------------------------------------
local function cb(name, fn)
    RegisterNUICallback(name, function(data, reply)
        reply('ok')
        if not book then return end
        local ok, err = pcall(fn, type(data) == 'table' and data or {})
        if not ok then print(('[pup_tailor] dye book %s failed: %s'):format(name, tostring(err))) end
    end)
end

cb('ready', function() book.ready = true end)

cb('close', function() B.close(false) end)

cb('pick', function(data)
    local id = U.int(tonumber(data.id))
    if not id then return end
    book.pickSeq = book.pickSeq + 1
    local seq, me = book.pickSeq, book
    CreateThread(function()
        local res = Tailor.ask('dyeItem', 5000, id)
        if book ~= me or me.pickSeq ~= seq then return end
        if type(res) ~= 'table' or not res.name or type(res.outfit) ~= 'table' then
            return toast(L('noAnswer'), true)
        end
        if res.dyed then return toast(L('alreadyDyed'), true) end
        local sess = S.session
        if not sess then return end
        local slots = Cat.dyeableSlots(res.outfit, res.name)
        local item = { id = id, name = res.name, sex = res.sex == 'female' and 'female' or 'male', slots = slots }
        -- the mannequin stands on the side away from the book: book right -> mannequin left (1), book left -> right (-1)
        Ped.setCameraSide(me.side == 'right' and 1 or -1)
        local ped = Ped.spawnMannequin(sess.bench, item.sex, function()
            return book == me and me.pickSeq == seq
        end)
        if not ped then return end
        me.item = item
        dressItem(item)
        local rows = {}
        for slot, s in pairs(slots) do rows[#rows + 1] = { slot = slot, label = s.label } end
        table.sort(rows, function(a, b)
            if a.label == b.label then return a.slot < b.slot end
            return a.label < b.label
        end)
        send('item', { id = id, rows = rows })
    end)
end)

cb('back', function() clearItem() end)

local function currentSlot(slot)
    local item = book.item
    if not item or type(slot) ~= 'string' or not item.slots[slot] then return nil end
    return item.slots[slot]
end

cb('tint', function(data)
    if not currentSlot(data.slot) then return end
    local ped = Ped.mannequin()
    if ped then Ped.tint(ped, data.slot, data.palette, data.c1, data.c2, data.c3) end
end)

local function fresh(slot)
    local s = currentSlot(slot)
    local ped = Ped.mannequin()
    if not s or not ped then return end
    Ped.putOn(ped, slot, s.hash, book.item.sex)
    Ped.refresh(ped)
end

cb('undye', function(data) fresh(data.slot) end)

cb('before', function(data)
    if data.down then
        fresh(data.slot)
    elseif type(data.edit) == 'table' and currentSlot(data.slot) then
        local ped = Ped.mannequin()
        if ped then Ped.tint(ped, data.slot, data.edit.palette, data.edit.c1, data.edit.c2, data.edit.c3) end
    end
end)

cb('save', function(data)
    local item = book.item
    if not item then return end
    if not S.session or S.session.preview then return toast(L('onlyTailorDye'), true) end
    local colours = type(data.colours) == 'table' and data.colours or {}
    if next(colours) == nil then return toast(L('colourFirst'), true) end
    local now = GetGameTimer()
    if now - book.lastSave < SAVE_GAP_MS then return end
    book.lastSave = now
    local out = {}
    for slot, c in pairs(colours) do
        if currentSlot(slot) and type(c) == 'table' then
            out[slot] = {
                palette = tonumber(c.palette), color1 = tonumber(c.color1),
                color2 = tonumber(c.color2), color3 = tonumber(c.color3),
            }
        end
    end
    TriggerServerEvent('pup_tailor:dyeSave', item.id, out)
end)

cb('name', function(data)
    if not S.session or S.session.preview then return toast(L('onlyTailorDye'), true) end
    local u = U.unsigned(tonumber(data.palette))
    if not u or not Cat.paletteSet[u] then return end
    TriggerServerEvent('pup_tailor:namePalette', u, U.cleanText(tostring(data.name or ''), 24, false))
end)

cb('cam', function(data)
    local s = Config.Camera.book
    local a = data.action
    if a == 'left' then Ped.turn(s.turn)
    elseif a == 'right' then Ped.turn(-s.turn)
    elseif a == 'zoomIn' then Ped.moveCamera(-s.zoom, 0)
    elseif a == 'zoomOut' then Ped.moveCamera(s.zoom, 0)
    elseif a == 'up' then Ped.moveCamera(0, s.raise)
    elseif a == 'down' then Ped.moveCamera(0, -s.raise)
    elseif a == 'reset' then Ped.resetCamera() end
end)

---------------------------------------------------------------------------
-- server answer to a save
---------------------------------------------------------------------------
RegisterNetEvent('pup_tailor:dyeResult', function(ok, message, items)
    if not book then return end
    if ok then
        clearItem()
        send('saved', { items = type(items) == 'table' and items or {}, message = tostring(message or '') })
    else
        toast(message and message ~= '' and message or L('onlyTailorDye'), true)
    end
end)
