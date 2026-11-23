-- pup_tailor | the pup-ui ink menus: main, sex, outfit (showroom) and bill.
local U = Tailor.U
local Cat = Tailor.Cat
local Ped = Tailor.Ped
local S = Tailor.S

local OWNER <const> = 'pup_tailor'
local INPUT_GIVEUP_MS <const> = 120000

local M = {}
Tailor.Menus = M

local st = {
    level = nil,        -- 'main' | 'sex' | 'outfit' | 'bill'
    open = false,
    index = 1,
    rows = {},          -- row index -> action descriptor
    sex = nil,
    picks = {},         -- [category] = catalogue entry (an identity, never a position)
    lastPut = nil,      -- last garment put on the mannequin: { entry, cat }
    keepMask = false,
    submitting = false,
    inputOpen = false,
    toBook = false,
}

local function ui() return exports['pup-ui'] end

function M.isOpen() return st.open end

local function show(subtitle, rows, startIndex)
    local options = {}
    st.rows = {}
    for i, r in ipairs(rows) do
        options[i] = {
            label = r.label, description = r.description,
            values = r.values, valueIndex = r.valueIndex, noneFirst = r.noneFirst,
        }
        st.rows[i] = r
    end
    st.index = math.max(1, math.min(startIndex or 1, #rows))
    st.open = true
    ui():OpenInkMenu({
        owner = OWNER, title = L('menuTitle'), subtitle = subtitle,
        startIndex = st.index, options = options,
    })
end

local function hide()
    st.open = false
    pcall(function() ui():HideInkMenu() end)
end

---------------------------------------------------------------------------
-- input boxes (one at a time; a box never answered gives up after 2 minutes)
---------------------------------------------------------------------------
local pendingInput = nil

local function input(title, fields)
    if pendingInput then pendingInput:resolve(false) end
    local p = promise.new()
    pendingInput = p
    st.inputOpen = true
    ui():OpenInput({ owner = OWNER, title = title, submit = L('submit'), fields = fields })
    SetTimeout(INPUT_GIVEUP_MS, function()
        if pendingInput == p then
            pendingInput = nil
            p:resolve(false)
        end
    end)
    local res = Citizen.Await(p)
    st.inputOpen = false
    if res == false then return nil end
    return res
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER or not pendingInput then return end
    local p = pendingInput
    pendingInput = nil
    p:resolve(type(values) == 'table' and values or false)
end)

---------------------------------------------------------------------------
-- catalogue helpers
---------------------------------------------------------------------------
local function lists()
    return Tailor.catalogue()[st.sex] or {}
end

local function positionOf(list, entry)
    if not entry then return 0 end
    for i, e in ipairs(list) do
        if e == entry then return i end
    end
    return 0
end

local function sortedCategories()
    local cats = {}
    for cat in pairs(lists()) do cats[#cats + 1] = cat end
    table.sort(cats, function(a, b)
        local la, lb = Cat.label(a) or a, Cat.label(b) or b
        if la == lb then return a < b end
        return la < lb
    end)
    return cats
end

local function pickCount()
    return U.count(st.picks)
end

local function outfitMap()
    local out = {}
    for cat, e in pairs(st.picks) do out[Cat.slotFor(cat)] = e.hash end
    return out
end

-- dress the mannequin in the background. One worker drains a per-category queue, so
-- fast slider moves are applied in order and the mannequin ends on the latest pick
-- (separate threads could finish out of order, because singleplayer garments wait
-- for the ped to be ready).
local dressWanted = {}   -- [cat] = entry, or false to take the slot off
local dressRunning = false

local function clearDressQueue()
    dressWanted = {}
end

local function dress(cat, entry)
    if not Ped.mannequin() then return end
    dressWanted[cat] = entry or false
    if entry then st.lastPut = { entry = entry, cat = cat } end
    if dressRunning then return end
    dressRunning = true
    CreateThread(function()
        while true do
            local c, e = next(dressWanted)
            if c == nil then break end
            dressWanted[c] = nil
            local ped = Ped.mannequin()
            if ped and DoesEntityExist(ped) then
                local slot = Cat.slotFor(c)
                if e then
                    Ped.putOn(ped, slot, e.hash, st.sex)
                else
                    Ped.removeSlot(ped, slot)
                end
                Ped.refresh(ped)
            end
        end
        dressRunning = false
    end)
end

---------------------------------------------------------------------------
-- leaving the outfit screen for good
---------------------------------------------------------------------------
local function leaveOutfit()
    Ped.showroom(false)
    clearDressQueue()
    Ped.removeMannequin()
    st.picks = {}
    st.lastPut = nil
    st.keepMask = false
    st.sex = nil
    local sess = S.session
    if sess then pcall(function() ui():SetMenuSide(sess.savedSide or 'left') end) end
end

-- called by endSession: hide everything, forget everything
function M.reset()
    local wasOutfit = st.level == 'outfit' or st.level == 'bill'
    st.level = nil
    if st.open then hide() end
    if wasOutfit then
        Ped.showroom(false)
        clearDressQueue()
        st.picks, st.lastPut, st.keepMask, st.sex = {}, nil, false, nil
    end
    if pendingInput then
        local p = pendingInput
        pendingInput = nil
        p:resolve(false)
    end
    st.submitting = false
    st.toBook = false
end

---------------------------------------------------------------------------
-- main menu
---------------------------------------------------------------------------
function M.openMain(startIndex)
    st.level = 'main'
    local rows = {}
    if not S.session.preview then
        rows[#rows + 1] = { act = 'copy', label = L('createItem'), description = L('createItemDesc', Config.CopyPrice) }
    end
    rows[#rows + 1] = { act = 'tailor', label = L('tailor'), description = L('tailorDesc') }
    rows[#rows + 1] = { act = 'dye', label = L('customize'), description = L('customizeDesc') }
    show(nil, rows, startIndex)
end

local function doCopy()
    if st.submitting then return end
    st.submitting = true
    local sessId = S.session and S.session.id
    local values = input(L('confirmTitle'), {
        { label = L('displayedDescription'), type = 'text', required = true, maxlength = 255 },
    })
    st.submitting = false
    if not values or not Tailor.sessionActive(sessId) then return end
    local desc = U.trim(values[1])
    if desc == '' then return end
    local sex = IsPedMale(PlayerPedId()) and 'm' or 'f'
    TriggerServerEvent('pup_tailor:copy', sex, desc)
    hide()
    Tailor.endSession()
end

local function doDye()
    if st.submitting then return end
    st.submitting = true
    local sessId = S.session and S.session.id
    local items = Tailor.ask('dyeItems', 5000)
    st.submitting = false
    if not Tailor.sessionActive(sessId) or st.level ~= 'main' then return end
    if items == nil then return Tailor.tip(L('noAnswer'), 4000) end
    st.toBook = true
    st.level = nil
    hide()
    st.toBook = false
    Tailor.Book.open(items)
end

---------------------------------------------------------------------------
-- sex menu
---------------------------------------------------------------------------
function M.openSex(startIndex)
    st.level = 'sex'
    show(nil, {
        { act = 'sex', sex = 'male', label = L('male'), description = L('maleDesc') },
        { act = 'sex', sex = 'female', label = L('female'), description = L('femaleDesc') },
    }, startIndex)
end

local function chooseSex(sex)
    local sess = S.session
    if not sess then return end
    local sessId = sess.id
    st.sex = sex
    st.picks, st.lastPut, st.keepMask = {}, nil, false
    st.level = 'outfit'
    hide()
    pcall(function() ui():SetMenuSide('right') end)
    Ped.setCameraSide(1)
    local ped = Ped.spawnMannequin(sess.bench, sex, function()
        return Tailor.sessionActive(sessId) and st.level == 'outfit' and st.sex == sex
    end)
    if not ped then
        if Tailor.sessionActive(sessId) and st.level == 'outfit' then
            leaveOutfit()
            M.openSex()
        end
        return
    end
    Ped.showroom(true)
    M.openOutfit()
end

---------------------------------------------------------------------------
-- outfit screen
---------------------------------------------------------------------------
function M.openOutfit(startIndex)
    st.level = 'outfit'
    local n = pickCount()
    local rows = {
        {
            act = 'finish',
            label = n > 0 and (L('finish') .. ' (' .. n .. ')') or L('finish'),
            description = n > 0 and L('finishDesc') or L('finishNone'),
        },
    }
    local all = lists()
    for _, cat in ipairs(sortedCategories()) do
        local list = all[cat]
        local values = { L('none') }
        for i = 1, #list do values[i + 1] = tostring(i) end
        local pos = positionOf(list, st.picks[cat])
        rows[#rows + 1] = {
            act = 'category', cat = cat,
            label = Cat.label(cat) or cat,
            values = values, valueIndex = pos + 1, noneFirst = true,
        }
    end
    if S.staff then
        rows[#rows + 1] = { act = 'hide', label = L('hideGarment'), description = L('hideGarmentDesc') }
    end
    show(L('showroomHint'), rows, startIndex or st.index)
end

local function setPick(cat, i)
    local list = lists()[cat]
    if not list then return end
    local before = pickCount()
    local entry = (i and i > 0) and list[i] or nil
    st.picks[cat] = entry
    dress(cat, entry)
    return before ~= pickCount()
end

local function goToNumber(row)
    if st.submitting then return end
    st.submitting = true
    local sessId = S.session and S.session.id
    local values = input(L('goToNumber'), {
        { label = L('number'), type = 'number', required = true },
    })
    st.submitting = false
    if not Tailor.sessionActive(sessId) or st.level ~= 'outfit' then return end
    if not values then return end
    local n = tonumber(values[1])
    if not n or n ~= n then return end
    n = math.floor(math.abs(n))
    local list = lists()[row.cat]
    if not list or n > #list then return end
    setPick(row.cat, n)
    M.openOutfit(st.index)
end

local function hideGarment()
    local last = st.lastPut
    if not S.staff then return end
    if not last or not last.entry.sp then
        return Tailor.tipRight(L('pickSpFirst'), 5000)
    end
    local d = last.entry.row.d
    TriggerServerEvent('pup_tailor:hide', d, ('%s %d'):format(last.cat, d))
end

-- the hidden list changed: drop picks that no longer exist, keep the rest on the same garment
function M.catalogueChanged()
    if st.level ~= 'outfit' and st.level ~= 'bill' then return end
    local all = lists()
    for cat, entry in pairs(st.picks) do
        if positionOf(all[cat] or {}, entry) == 0 then
            st.picks[cat] = nil
            dress(cat, nil)
            if st.lastPut and st.lastPut.entry == entry then st.lastPut = nil end
        end
    end
    -- redraw only a menu that is on screen: not while a box is open, and not while
    -- chooseSex is still spawning the mannequin (the menu is hidden then)
    if st.inputOpen or not st.open then return end
    if st.level == 'bill' and pickCount() == 0 then
        M.openOutfit()
    elseif st.level == 'outfit' then
        M.openOutfit(st.index)
    else
        M.openBill()
    end
end

---------------------------------------------------------------------------
-- bill
---------------------------------------------------------------------------
local function billTotals()
    local cash, mats, order = 0, {}, {}
    -- a stable order: categories sorted, so "first met" is the same every time
    local cats = {}
    for cat in pairs(st.picks) do cats[#cats + 1] = cat end
    table.sort(cats, function(a, b) return (Cat.label(a) or a) < (Cat.label(b) or b) end)
    for _, cat in ipairs(cats) do
        local p = Cat.price(st.picks[cat].hash)
        if p then
            cash = cash + p.cash
            for _, m in ipairs(p.items) do
                if not mats[m.name] then
                    mats[m.name] = { label = m.label, count = 0 }
                    order[#order + 1] = mats[m.name]
                end
                mats[m.name].count = mats[m.name].count + m.count
            end
        end
    end
    return cash, order
end

function M.openBill(startIndex)
    st.level = 'bill'
    local cash, mats = billTotals()
    local rows = {}
    if cash > 0 then rows[#rows + 1] = { act = 'none', label = L('price', cash), description = L('priceDesc') } end
    for _, m in ipairs(mats) do
        rows[#rows + 1] = { act = 'none', label = ('%s : %d'):format(m.label, m.count), description = L('perCopy') }
    end
    rows[#rows + 1] = {
        act = 'keep',
        label = L('keepMask', st.keepMask and L('on') or L('off')),
        description = L('keepMaskDesc'),
    }
    rows[#rows + 1] = { act = 'confirm', label = L('confirm'), description = L('confirmDesc') }
    show(nil, rows, startIndex)
end

local function confirmBill()
    if st.submitting then return end
    st.submitting = true
    local sessId = S.session and S.session.id
    local function stillHere() return Tailor.sessionActive(sessId) and st.level == 'bill' end

    local values = input(L('description'), {
        { label = L('description'), type = 'text', required = true, maxlength = 255 },
    })
    local desc = values and U.trim(values[1]) or ''
    if desc == '' or not stillHere() then st.submitting = false return end

    local amount
    while true do
        -- no min/max on the field: pup-ui clamps a number field to them without a word,
        -- which would turn 500 into 100 silently; the check below explains instead
        local v = input(L('howMany'), {
            { label = L('howMany'), type = 'number', required = true, default = 1 },
        })
        if not v or not stillHere() then st.submitting = false return end
        local n = tonumber(v[1])
        local whole = n and U.int(n)
        if whole and whole >= 1 and whole <= Config.MaxAmount then amount = whole break end
        if whole and whole > Config.MaxAmount then
            Tailor.tip(L('amountMax', Config.MaxAmount), 5000)
        else
            Tailor.tip(L('amountWhole'), 5000)
        end
    end
    st.submitting = false
    if not stillHere() or pickCount() == 0 then return end

    local cats = {}
    for cat in pairs(st.picks) do cats[#cats + 1] = cat end
    local code = (#cats == 1 and Cat.itemCategory[cats[1]]) and cats[1] or 'clothingset2'
    TriggerServerEvent(st.keepMask and 'pup_tailor:makeKeep' or 'pup_tailor:make',
        outfitMap(), code, desc, st.sex, amount)
    hide()
    Tailor.endSession()
end

---------------------------------------------------------------------------
-- pup-ui events
---------------------------------------------------------------------------
AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner ~= OWNER or not st.open then return end
    st.index = tonumber(index) or st.index
end)

AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    if owner ~= OWNER or st.level ~= 'outfit' or st.inputOpen then return end
    local row = st.rows[index]
    if not row or row.act ~= 'category' then return end
    st.index = index
    if setPick(row.cat, (tonumber(valueIndex) or 1) - 1) then
        M.openOutfit(index)
    end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not S.session or st.inputOpen then return end
    local row = st.rows[index]
    if not row then return end
    st.index = index
    local act = row.act
    if st.level == 'main' then
        if act == 'copy' then CreateThread(doCopy)
        elseif act == 'tailor' then M.openSex()
        elseif act == 'dye' then CreateThread(doDye) end
    elseif st.level == 'sex' and act == 'sex' then
        CreateThread(function() chooseSex(row.sex) end)
    elseif st.level == 'outfit' then
        if act == 'finish' then
            if S.session.preview then return Tailor.tip(L('onlyTailorMake'), 5000) end
            if pickCount() == 0 then return Tailor.tip(L('nothingPicked'), 4000) end
            M.openBill()
        elseif act == 'category' then
            CreateThread(function() goToNumber(row) end)
        elseif act == 'hide' then
            hideGarment()
        end
    elseif st.level == 'bill' then
        if act == 'keep' then
            st.keepMask = not st.keepMask
            M.openBill(index)
        elseif act == 'confirm' then
            CreateThread(confirmBill)
        end
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER then return end
    st.open = false
    if not S.session or st.toBook then return end
    local level = st.level
    if level == 'main' then
        st.level = nil
        Tailor.endSession()
    elseif level == 'sex' then
        M.openMain()
    elseif level == 'outfit' then
        leaveOutfit()
        M.openSex()
    elseif level == 'bill' then
        M.openOutfit()
    else
        Tailor.endSession()
    end
end)
