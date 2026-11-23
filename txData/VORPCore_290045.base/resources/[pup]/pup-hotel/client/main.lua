local Core <const> = exports.vorp_core:GetCore()

local function notify(msg, ms)
    TriggerEvent('vorp:TipRight', tostring(msg), tonumber(ms) or 5000)
end

local function money(n) return ('$%d'):format(math.floor(tonumber(n) or 0)) end

--- Seconds remaining -> "3d 4h". The client has no `os` library.
local function leftPretty(secs)
    secs = tonumber(secs) or 0
    if secs <= 0 then return Locale.expired end
    local days <const> = math.floor(secs / 86400)
    local hours <const> = math.floor((secs % 86400) / 3600)
    if days > 0 then return ('%dd %dh'):format(days, hours) end
    if hours > 0 then return ('%dh'):format(hours) end
    return ('%dm'):format(math.max(1, math.floor(secs / 60)))
end

-- -------------------------------------------------------------- the prompt

local deskGroup, deskPrompt
local atDesk = nil   -- hotel id the player is standing at
local atOffice = false -- true when that point is the office rather than the desk

local function setupPrompt()
    deskGroup = GetRandomIntInRange(0, 0xffffff)
    deskPrompt = UiPromptRegisterBegin()
    -- E, the same control doorlocks uses for its own prompt
    UiPromptSetControlAction(deskPrompt, Config.Keys.desk)
    UiPromptSetText(deskPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.promptDesk))
    UiPromptSetEnabled(deskPrompt, true)
    UiPromptSetVisible(deskPrompt, true)
    UiPromptSetStandardMode(deskPrompt, true)
    UiPromptSetGroup(deskPrompt, deskGroup, 0)
    UiPromptRegisterEnd(deskPrompt)
end

-- ------------------------------------------------------------- menu: guest

-- Always pushes a page so the menu stack is never stranded.
local function openMyStay()
    Core.Callback.TriggerAsync('pup-hotel:myStay', function(stay)
        if not stay then
            return PupMenu.Push({
                title = Locale.myStay,
                subtitle = Locale.nothingBooked,
                options = { { label = Locale.notStaying, disabled = true } },
            })
        end
        PupMenu.Push({
            title = stay.roomLabel,
            subtitle = stay.hotelLabel,
            options = {
                { label = Locale.runsOutIn .. ' ' .. leftPretty(stay.left), disabled = true },
                { label = Locale.untilTime:format(stay.untilText or '?'), disabled = true },
            },
        })
    end)
end

-- ------------------------------------------------------------- menu: clerk

local deskState = nil

--- pup-ui wants `fields`; without it openInput silently returns false.
local function askNumber(title, default, cb, lo, hi)
    local owner <const> = ('pup-hotel:%s'):format(GetGameTimer())
    local ev
    ev = AddEventHandler('pup-ui:client:inputDone', function(o, values)
        if o ~= owner then return end
        RemoveEventHandler(ev)
        cb(tonumber(values and values[1]))
    end)

    local field = { label = title, type = 'number', default = tonumber(default) or 1 }
    if lo then field.min = lo end
    if hi then field.max = hi end

    local opened <const> = exports['pup-ui']:OpenInput({
        owner = owner,
        title = title,
        submit = Locale.inputConfirm,
        fields = { field },
    })

    if not opened then
        RemoveEventHandler(ev)
        notify(Locale.ledgerWontOpen)
        PupMenu.Close()
    end
end

local openDesk -- forward: the room pages rebuild the root

--- One occupied room: extend, or turn them out.
local function occupiedPage(hotelId, room)
    return {
        title = room.label,
        subtitle = ('%s - %s'):format(room.tierLabel, room.guest or Locale.occupied),
        options = {
            { label = Locale.guest, desc = room.guest or '?', disabled = true },
            { label = Locale.characterId, desc = tostring(room.charid or '?'), disabled = true },
            { label = Locale.runsOutIn, desc = leftPretty(room.left), disabled = true },
            {
                label = Locale.extendStay,
                desc = Locale.perDay:format(money(room.price)),
                reopen = false, -- the list redraw would cover the input box
                action = function()
                    askNumber(Locale.howManyMoreDays, 1, function(days)
                        -- cancelling closes too, or the stack is stranded
                        if days and days >= 1 then
                            TriggerServerEvent('pup-hotel:extend', hotelId, room.id, days)
                        end
                        PupMenu.Close()
                    end, 1, Config.Rent.maxDays)
                end,
            },
            {
                label = Locale.revokeAccess,
                desc = Locale.revokeAccessDesc,
                action = function()
                    TriggerServerEvent('pup-hotel:evict', hotelId, room.id)
                    PupMenu.Close()
                end,
            },
        },
    }
end

--- One free room: who goes in it, and for how long.
local function vacantPage(hotelId, room)
    local function assign(charid, free)
        askNumber(Locale.howManyDays, 1, function(days)
            if days and days >= 1 then
                TriggerServerEvent('pup-hotel:assign', hotelId, room.id, charid, days, free == true)
            end
            PupMenu.Close()
        end, 1, Config.Rent.maxDays)
    end

    local options = {
        { label = room.tierLabel, desc = Locale.perDay:format(money(room.price)), disabled = true },
    }

    -- reopen = false on anything that opens an input, or the redraw covers it
    for _, p in ipairs((deskState and deskState.nearby) or {}) do
        options[#options + 1] = {
            label = p.name ~= '' and p.name or Locale.characterN:format(p.charid),
            desc = Locale.atDeskId:format(p.charid),
            action = function() assign(p.charid, false) end,
            reopen = false,
        }
    end

    options[#options + 1] = {
        label = Locale.byCharacterId,
        desc = Locale.byCharacterIdDesc,
        reopen = false,
        action = function()
            askNumber(Locale.characterId, 1, function(charid)
                if charid then assign(charid, false) else PupMenu.Close() end
            end, 1)
        end,
    }

    if deskState and deskState.staff and Config.Staff.allowFreeAssign then
        options[#options + 1] = {
            label = Locale.giveAway,
            desc = Locale.giveAwayDesc,
            reopen = false,
            action = function()
                askNumber(Locale.characterId, 1, function(charid)
                    if charid then assign(charid, true) else PupMenu.Close() end
                end, 1)
            end,
        }
    end

    return { title = room.label, subtitle = Locale.subtitleVacant, options = options }
end

openDesk = function(hotelId, office)
    Core.Callback.TriggerAsync('pup-hotel:deskState', function(state)
        if not state then return notify(Locale.deskClosed) end
        deskState = state

        local options = {}

        local hotel <const> = HotelById(hotelId)

        -- the office is the register, the desk is the counter
        if office then
            if not state.manage then
                return PupMenu.Open({
                    title = (hotel and hotel.label) or Locale.hotelFallback,
                    subtitle = Locale.subtitleOffice,
                    options = { { label = Locale.staffOnly, disabled = true } },
                })
            end

            local let, vacant = {}, 0
            for _, room in ipairs(state.rooms or {}) do
                if room.guest then let[#let + 1] = room else vacant = vacant + 1 end
            end

            options[#options + 1] = {
                label = Locale.letVacant:format(#let, vacant),
                desc = Locale.everyoneStaying,
                disabled = true,
            }

            options[#options + 1] = {
                label = Locale.nightlyRates,
                desc = Locale.nightlyRatesDesc,
                submenu = function()
                    local rows = {}
                    for _, t in ipairs((deskState and deskState.tiers) or {}) do
                        rows[#rows + 1] = {
                            label = t.label,
                            desc = ('%s per day%s'):format(money(t.price), t.fromConfig and Locale.fromConfig or ''),
                            reopen = false,
                            action = function()
                                askNumber(Locale.pricePerDayTitle:format(t.label), t.price, function(p)
                                    if p and p >= 0 then
                                        TriggerServerEvent('pup-hotel:setPrice', t.id, p)
                                    end
                                    PupMenu.Close()
                                end, 0)
                            end,
                        }
                    end
                    if #rows == 0 then
                        rows[1] = { label = Locale.noTiers, disabled = true }
                    end
                    return { title = Locale.nightlyRates, subtitle = Locale.ratesSubtitle, options = rows }
                end,
            }
            for _, room in ipairs(let) do
                options[#options + 1] = {
                    label = ('%s - %s'):format(room.label, room.guest),
                    desc = ('%s - ID %s - %s left'):format(room.tierLabel, tostring(room.charid), leftPretty(room.left)),
                    submenu = function() return occupiedPage(hotelId, room) end,
                }
            end
            if #let == 0 then
                options[#options + 1] = { label = Locale.nobodyHere, disabled = true }
            end

            return PupMenu.Open({
                title = (hotel and hotel.label) or Locale.hotelFallback,
                subtitle = Locale.subtitleOffice,
                options = options,
            })
        end

        options[#options + 1] = {
            label = Locale.myStay,
            desc = Locale.myStayDesc,
            action = openMyStay,
            reopen = false,
        }

        if state.manage then
            local vacantRooms = {}
            for _, room in ipairs(state.rooms or {}) do
                if room.guest == nil then vacantRooms[#vacantRooms + 1] = room end
            end
            for _, room in ipairs(vacantRooms) do
                options[#options + 1] = {
                    label = room.label,
                    desc = ('%s - %s per day'):format(room.tierLabel, money(room.price)),
                    submenu = function() return vacantPage(hotelId, room) end,
                }
            end
            if #(state.rooms or {}) == 0 then
                options[#options + 1] = { label = Locale.noRooms, disabled = true }
            elseif #vacantRooms == 0 then
                options[#options + 1] = { label = Locale.allLet, disabled = true }
            end
        end

        PupMenu.Open({
            title = (hotel and hotel.label) or Locale.hotelFallback,
            subtitle = state.manage and Locale.subtitleFrontDesk or Locale.subtitleGuest,
            options = options,
        })
    end, hotelId)
end

-- an offer waiting on this player's answer. Closing the menu counts as no.
local offerWaiting = false

PupMenu.OnClose = function()
    deskState = nil
    if offerWaiting then
        offerWaiting = false
        TriggerServerEvent('pup-hotel:offerAnswer', false)
    end
end

RegisterNetEvent('pup-hotel:refresh', function(hotelId)
    if offerWaiting then return end -- a redraw would take the offer off their screen
    if PupMenu.IsOpen() and atDesk == hotelId then openDesk(hotelId, atOffice) end
end)

RegisterNetEvent('pup-hotel:offer', function(offer)
    if type(offer) ~= 'table' then return end
    offerWaiting = true
    PupMenu.Open({
        title = offer.hotel or Locale.hotelFallback,
        subtitle = Locale.offerTitle,
        options = {
            {
                label = offer.extend and Locale.offerMore:format(offer.days, offer.room)
                    or Locale.offerRoom:format(offer.room, offer.days),
                disabled = true,
            },
            {
                label = Locale.offerAccept:format(money(offer.total)),
                desc = Locale.offerAcceptDesc,
                close = true,
                action = function()
                    offerWaiting = false
                    TriggerServerEvent('pup-hotel:offerAnswer', true)
                end,
            },
            {
                label = Locale.offerDecline,
                close = true,
                action = function()
                    offerWaiting = false
                    TriggerServerEvent('pup-hotel:offerAnswer', false)
                end,
            },
        },
    })
end)

RegisterNetEvent('pup-hotel:offerGone', function()
    if not offerWaiting then return end
    offerWaiting = false
    PupMenu.Close()
end)

-- ------------------------------------------------------------------ blips

CreateThread(function()
    for _, hotel in pairs(Config.Hotels or {}) do
        local b <const> = hotel.blip
        if b and b.show and hotel.desk then
            local blip = Citizen.InvokeNative(0x554d9d53f696d002, 1664425300, hotel.desk.x, hotel.desk.y, hotel.desk.z)
            SetBlipSprite(blip, b.sprite or -1282792512, true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, b.name or hotel.label or Locale.hotelFallback)
        end
    end
end)

-- ------------------------------------------------------------- the desk loop

CreateThread(function()
    setupPrompt()
    while true do
        local wait = 1000
        local me <const> = GetEntityCoords(PlayerPedId())
        local near = nil

        -- closest point, not the first in range
        local range <const> = tonumber(Config.Desk.promptRadius) or 1.2
        local nearest = range
        local nearLabel = Locale.promptDesk
        local nearIsOffice = false

        for id, hotel in pairs(Config.Hotels or {}) do
            if hotel.desk then
                local d <const> = #(me - hotel.desk)
                if d < nearest then near, nearest, nearLabel, nearIsOffice = id, d, Locale.promptDesk, false end
            end
            if hotel.office then
                local d <const> = #(me - hotel.office)
                if d < nearest then near, nearest, nearLabel, nearIsOffice = id, d, Locale.promptOffice, true end
            end
        end

        atDesk = near
        atOffice = nearIsOffice

        -- walking away clears the menu, so a stranded stack cannot hide the prompt
        if not near and PupMenu.IsOpen() then PupMenu.Close() end

        if near and not PupMenu.IsOpen() then
            wait = 0
            UiPromptSetText(deskPrompt, CreateVarString(10, 'LITERAL_STRING', nearLabel))
            UiPromptSetActiveGroupThisFrame(deskGroup, CreateVarString(10, 'LITERAL_STRING', nearLabel), 0, 0, 0, 0)
            if UiPromptHasStandardModeCompleted(deskPrompt, 0) then
                openDesk(near, atOffice)
            end
        end

        Wait(wait)
    end
end)
