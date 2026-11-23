-- pup_library | libraries on the map: blips, the prompt and the library menus.

local blips = {}
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local openPrompt = nil
local frozen = false
local helloWaits = {} -- [token] = promise
local helloSeq = 0

-- what the server told us when this menu opened
local info = { job = '', balance = 0, charid = 0, grade = 0 }
local currentLibrary = nil

local function tipRight(msg, ms) TriggerEvent('vorp:TipRight', msg, ms or Config.Notify.default) end
local function tipBottom(msg, ms) TriggerEvent('vorp:TipBottom', msg, ms or Config.Notify.default) end

local function isStaff() return Config.IsStaffJob(info.job) end
local function isPublisher() return Config.IsPublisherJob(info.job, info.grade) end

-- cut to `max` characters without splitting a UTF-8 sequence
local function cutChars(s, max)
    if not utf8.len(s) then return s:sub(1, max) end
    local stop = utf8.offset(s, max + 1)
    return stop and s:sub(1, stop - 1) or s
end

local function workLabel(item)
    local w = Config.WorkByItem[item]
    return w and w.label or tostring(item or '')
end

--------------------------------------------------------------------------------
-- blips and prompt
--------------------------------------------------------------------------------

local function createBlips()
    for _, lib in ipairs(Config.Libraries) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, Config.Blip.style, lib.pos.x, lib.pos.y, lib.pos.z) -- BlipAddForCoords
        Citizen.InvokeNative(0x74F74D3207ED525C, blip, Config.Blip.sprite, true)                             -- SetBlipSprite
        Citizen.InvokeNative(0xD38744167B2FA257, blip, Config.Blip.scale)                                     -- SetBlipScale
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', lib.name))        -- SetBlipName
        blips[#blips + 1] = blip
    end
end

local function createPrompt()
    local p = Citizen.InvokeNative(0x04F97DE45A519419) -- PromptRegisterBegin
    Citizen.InvokeNative(0xB5352B7494A08258, p, Config.Prompt.key)                                    -- SetControlAction
    Citizen.InvokeNative(0x5DD02A8318420DD7, p, CreateVarString(10, 'LITERAL_STRING', T('prompt_label'))) -- SetText
    Citizen.InvokeNative(0x8A0FB4D03A630D21, p, true)                                                 -- SetEnabled
    Citizen.InvokeNative(0x71215ACCFDE075EE, p, true)                                                 -- SetVisible
    Citizen.InvokeNative(0xCC6656799977741B, p, true)                                                 -- SetStandardMode
    Citizen.InvokeNative(0x2F11D3A254169EA4, p, promptGroup, 0)                                       -- SetGroup
    Citizen.InvokeNative(0xF7AA2696A22AD8B9, p)                                                       -- RegisterEnd
    openPrompt = p
end

--------------------------------------------------------------------------------
-- freezing and closing
--------------------------------------------------------------------------------

local function setFrozen(on)
    frozen = on
    FreezeEntityPosition(PlayerPedId(), on)
end

function LibraryRelease()
    if frozen then setFrozen(false) end
end

function LibraryCloseMenu()
    Menu.Close()
    LibraryRelease()
end

--------------------------------------------------------------------------------
-- rule slider shared by create and print
--------------------------------------------------------------------------------

-- Returns the rule values and their labels. "My job" is left out when the player has no job.
local function ruleChoices()
    local rules = { 'author' }
    local labels = { T('rule_author') }
    if info.job ~= '' then
        rules[#rules + 1] = info.job
        labels[#labels + 1] = T('rule_job', info.job)
    end
    rules[#rules + 1] = 'any'
    labels[#labels + 1] = T('rule_any')
    return rules, labels
end

local function ruleRow(state)
    local rules, labels = ruleChoices()
    state.ruleIndex = math.min(state.ruleIndex or 1, #rules)
    local description = T('editable_desc')
    if info.job == '' then description = description .. ' - ' .. T('rule_job_missing') end
    return {
        label = T('editable'),
        description = description,
        values = labels,
        valueIndex = state.ruleIndex,
        onChange = function(v) state.ruleIndex = v end,
    }, rules[state.ruleIndex]
end

--------------------------------------------------------------------------------
-- creation
--------------------------------------------------------------------------------

local function createForm(work)
    Menu.Push({
        title = T('create_kind', work.label),
        subtitle = currentLibrary and currentLibrary.name,
        build = function(level)
            local s = level.state
            s.name = s.name or ''
            s.author = s.author or ''
            local rows = {
                {
                    label = T('name_row', s.name),
                    onSelect = function()
                        Menu.Input({
                            title = T('create_kind', work.label),
                            fields = { { label = T('name_prompt', work.label:lower()), type = 'text', required = true,
                                maxlength = Config.TitleMax, default = s.name } },
                        }, function(values)
                            local v = values[1]
                            if type(v) == 'string' and v:gsub('%s', '') ~= '' then
                                s.name = cutChars(v, Config.TitleMax)
                                Menu.Draw()
                            end
                        end)
                    end,
                },
                {
                    label = T('author_row', s.author),
                    onSelect = function()
                        Menu.Input({
                            title = T('create_kind', work.label),
                            fields = { { label = T('author_prompt'), type = 'text', required = true,
                                maxlength = Config.AuthorMax, default = s.author } },
                        }, function(values)
                            local v = values[1]
                            if type(v) == 'string' and v:gsub('%s', '') ~= '' then
                                s.author = cutChars(v, Config.AuthorMax)
                                Menu.Draw()
                            end
                        end)
                    end,
                },
            }
            local rRow, rule = ruleRow(s)
            rows[#rows + 1] = rRow
            if s.name ~= '' and s.author ~= '' then
                local free = isStaff() and Config.StaffCreateFree
                rows[#rows + 1] = {
                    label = T('confirm'),
                    description = T('create_cost', free and T('free') or Config.Money(Config.CreatePrice)),
                    onSelect = function()
                        TriggerServerEvent('pup_library:create', work.item, s.name, s.author, rule)
                        LibraryCloseMenu()
                    end,
                }
            end
            return rows
        end,
    })
end

local function creationMenu()
    Menu.Push({
        title = T('creation'),
        subtitle = T('creation_desc'),
        build = function()
            local works = {}
            for _, w in ipairs(Config.Works) do works[#works + 1] = w end
            table.sort(works, function(a, b) return a.label < b.label end)
            local rows = {}
            for _, w in ipairs(works) do
                rows[#rows + 1] = {
                    label = T('create_kind', w.label),
                    description = T('create_kind_desc', w.label:lower()),
                    onSelect = function() createForm(w) end,
                }
            end
            return rows
        end,
    })
end

--------------------------------------------------------------------------------
-- print
--------------------------------------------------------------------------------

local function printPerCopy()
    if isStaff() and Config.StaffPrintFree then return 0 end
    return Config.PrintPrice
end

local function printForm(entry)
    local md = entry.metadata or {}
    local copiesValues = {}
    for i = 1, Config.MaxCopies do copiesValues[i] = tostring(i) end
    Menu.Push({
        title = (md.title ~= '' and md.title) or workLabel(entry.name),
        subtitle = T('print_subtitle', Config.Money(printPerCopy())),
        build = function(level)
            local s = level.state
            s.copies = s.copies or 1
            local rRow, rule = ruleRow(s)
            return {
                rRow,
                {
                    label = T('copies'),
                    description = T('copies_desc'),
                    values = copiesValues,
                    valueIndex = s.copies,
                    onChange = function(v) s.copies = v end,
                },
                {
                    label = T('confirm'),
                    description = T('total', Config.Money(printPerCopy() * s.copies)),
                    onSelect = function()
                        TriggerServerEvent('pup_library:print', entry.itemId, s.copies, rule)
                        LibraryCloseMenu()
                    end,
                },
            }
        end,
    })
end

local function printList()
    Menu.Request('carried', function(token)
        TriggerServerEvent('pup_library:listCarried', token)
    end, function(list)
        Menu.Push({
            title = T('print'),
            subtitle = T('select'),
            build = function()
                local rows = {}
                for _, entry in ipairs(list) do
                    local md = type(entry.metadata) == 'table' and entry.metadata or {}
                    entry.metadata = md
                    rows[#rows + 1] = {
                        label = (type(md.title) == 'string' and md.title ~= '') and md.title or workLabel(entry.name),
                        description = ('%s / %s'):format(tostring(md.author or ''), tostring(md.id or '')),
                        onSelect = function() printForm(entry) end,
                    }
                end
                return rows
            end,
        })
    end)
end

--------------------------------------------------------------------------------
-- apply to publish
--------------------------------------------------------------------------------

local function applyList()
    Menu.Request('own', function(token)
        TriggerServerEvent('pup_library:listOwn', token)
    end, function(list)
        Menu.Push({
            title = T('publish'),
            subtitle = T('select'),
            build = function()
                local rows = {}
                for _, b in ipairs(list) do
                    rows[#rows + 1] = {
                        label = tostring(b.title or ''),
                        description = T('application_price', Config.Money(Config.ApplicationFee)),
                        onSelect = function()
                            Menu.Input({
                                title = tostring(b.title or ''),
                                fields = { { label = T('sale_price'), type = 'number', required = true,
                                    min = 1, max = Config.MaxSalePrice } },
                            }, function(values)
                                local n = tonumber(values[1])
                                if not n then return end
                                local price = Config.Round2(n)
                                if not price or price <= 0 then
                                    tipRight(T('invalid_amount'))
                                    return
                                end
                                TriggerServerEvent('pup_library:apply', b.id, price)
                                LibraryCloseMenu()
                            end)
                        end,
                    }
                end
                return rows
            end,
        })
    end)
end

--------------------------------------------------------------------------------
-- shelf
--------------------------------------------------------------------------------

local function titlePage(d)
    Menu.Push({
        title = tostring(d.title or ''),
        subtitle = currentLibrary and currentLibrary.name,
        build = function()
            local rows = {
                {
                    label = T('buy_copy', Config.Money(d.price)),
                    description = T('buy_copy_desc'),
                    onSelect = function()
                        TriggerServerEvent('pup_library:buy', d.id)
                        LibraryCloseMenu()
                    end,
                },
                { label = T('author_row', tostring(d.author or '')) },
                { label = workLabel(d.item), description = T('kind_desc') },
                { label = T('copies_sold', tonumber(d.copies) or 0), description = T('copies_sold_desc') },
            }
            if d.canRemove then
                rows[#rows + 1] = {
                    label = T('remove'),
                    description = T('remove_desc'),
                    onSelect = function()
                        TriggerServerEvent('pup_library:remove', d.id)
                        LibraryCloseMenu()
                    end,
                }
            end
            return rows
        end,
    })
end

local function shelfList()
    Menu.Request('shelf', function(token)
        TriggerServerEvent('pup_library:listShelf', token)
    end, function(list)
        Menu.Push({
            title = T('published_titles'),
            subtitle = T('published_desc'),
            build = function()
                local rows = {}
                for _, r in ipairs(list) do
                    rows[#rows + 1] = {
                        label = tostring(r.title or ''),
                        description = T('shelf_row_desc', Config.Money(r.price), tonumber(r.copies) or 0),
                        onSelect = function()
                            Menu.Request('title', function(token)
                                TriggerServerEvent('pup_library:details', token, r.id, 'shelf')
                            end, titlePage)
                        end,
                    }
                end
                return rows
            end,
        })
    end)
end

--------------------------------------------------------------------------------
-- publisher queue
--------------------------------------------------------------------------------

local function applicationPage(d)
    Menu.Push({
        title = tostring(d.title or ''),
        subtitle = T('pending'),
        build = function()
            return {
                { label = workLabel(d.item), description = T('kind_desc') },
                { label = T('author_row', tostring(d.author or '')) },
                {
                    label = T('get_copy'),
                    description = T('get_copy_desc'),
                    onSelect = function()
                        TriggerServerEvent('pup_library:readingCopy', d.id)
                        LibraryCloseMenu()
                    end,
                },
                {
                    label = T('reject'),
                    description = T('reject_desc'),
                    onSelect = function()
                        Menu.Input({
                            title = T('reject'),
                            fields = { { label = T('reason'), type = 'text', required = true, maxlength = Config.ReasonMax } },
                        }, function(values)
                            local reason = values[1]
                            if type(reason) ~= 'string' or reason:gsub('%s', '') == '' then return end
                            TriggerServerEvent('pup_library:remove', d.id, cutChars(reason, Config.ReasonMax))
                            LibraryCloseMenu()
                        end)
                    end,
                },
                {
                    label = T('approve'),
                    description = T('approve_desc'),
                    onSelect = function()
                        TriggerServerEvent('pup_library:approve', d.id)
                        LibraryCloseMenu()
                    end,
                },
            }
        end,
    })
end

local function queueList()
    Menu.Request('queue', function(token)
        TriggerServerEvent('pup_library:listQueue', token)
    end, function(list)
        Menu.Push({
            title = T('applications'),
            subtitle = T('applications_desc'),
            build = function()
                local rows = {}
                for _, r in ipairs(list) do
                    rows[#rows + 1] = {
                        label = tostring(r.title or ''),
                        description = T('pending'),
                        onSelect = function()
                            Menu.Request('application', function(token)
                                TriggerServerEvent('pup_library:details', token, r.id, 'queue')
                            end, applicationPage)
                        end,
                    }
                end
                return rows
            end,
        })
    end)
end

--------------------------------------------------------------------------------
-- top level
--------------------------------------------------------------------------------

local function topMenu(lib)
    Menu.onClosed = LibraryRelease
    Menu.Push({
        title = T('menu_title'),
        subtitle = lib.name,
        build = function()
            local rows = {
                { label = T('published_titles'), description = T('published_desc'), onSelect = shelfList },
                { label = T('creation'), description = T('creation_desc'), onSelect = creationMenu },
            }
            if not Config.PrintStaffOnly or isStaff() then
                rows[#rows + 1] = { label = T('print'), description = T('print_desc'), onSelect = printList }
            end
            rows[#rows + 1] = { label = T('publish'), description = T('publish_desc'), onSelect = applyList }
            if isPublisher() then
                rows[#rows + 1] = { label = T('applications'), description = T('applications_desc'), onSelect = queueList }
            end
            if (tonumber(info.balance) or 0) > 0 then
                rows[#rows + 1] = {
                    label = T('royalties', Config.Money(info.balance)),
                    description = T('royalties_desc'),
                    onSelect = function()
                        TriggerServerEvent('pup_library:collect')
                        LibraryCloseMenu()
                    end,
                }
            end
            return rows
        end,
    })
end

RegisterNetEvent('pup_library:helloReply', function(token, job, balance, charid, grade)
    local p = helloWaits[token]
    if not p then return end
    helloWaits[token] = nil
    p:resolve({
        job = type(job) == 'string' and job or '',
        balance = tonumber(balance) or 0,
        charid = tonumber(charid) or 0,
        grade = tonumber(grade) or 0,
    })
end)

local opening = false

local function openLibrary(lib)
    if opening or Menu.active then return end
    opening = true
    helloSeq = helloSeq + 1
    local token = helloSeq
    local p = promise.new()
    helloWaits[token] = p
    SetTimeout(Config.ServerReplyTimeout, function()
        if helloWaits[token] then
            helloWaits[token] = nil
            p:resolve(false)
        end
    end)
    TriggerServerEvent('pup_library:hello', token)
    local reply = Citizen.Await(p)
    opening = false
    if not reply then
        tipBottom(T('no_answer'))
        return
    end
    if Config.StaffOnlyLibrary and not Config.IsStaffJob(reply.job) then
        tipBottom(T('no_job'), Config.Notify.noJob)
        return
    end
    if Book.open or Menu.active then return end
    info = reply
    currentLibrary = lib
    setFrozen(true)
    topMenu(lib)
end

--------------------------------------------------------------------------------
-- proximity loop
--------------------------------------------------------------------------------

CreateThread(function()
    createBlips()
    createPrompt()
    while true do
        local wait = Config.Prompt.farScanMs
        local pos = GetEntityCoords(PlayerPedId())
        local nearest, nearestDist = nil, nil
        for _, lib in ipairs(Config.Libraries) do
            local d = #(pos - lib.pos)
            if not nearestDist or d < nearestDist then
                nearest, nearestDist = lib, d
            end
        end
        local busyNow = Menu.active or opening or Book.open
        if nearest and nearestDist <= Config.Prompt.nearScan and not busyNow then
            wait = 0
            if nearestDist <= Config.Prompt.distance then
                Citizen.InvokeNative(0xC65A45D4453C2627, promptGroup, CreateVarString(10, 'LITERAL_STRING', nearest.name), 0, 0, 0, 0) -- PromptSetActiveGroupThisFrame
                if Citizen.InvokeNative(0xC92AC953F0A982AE, openPrompt) then -- PromptHasStandardModeCompleted
                    CreateThread(function() openLibrary(nearest) end)
                    wait = 250
                end
            end
        end
        Wait(wait)
    end
end)

--------------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------------

-- a new character: nothing from the old one stays open
RegisterNetEvent('vorp:SelectedCharacter', function()
    LibraryCloseMenu()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Menu.open then exports['pup-ui']:HideInkMenu() end
    LibraryRelease()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    blips = {}
    if openPrompt then Citizen.InvokeNative(0x00EDE88D4D13CF59, openPrompt) end -- PromptDelete
end)
