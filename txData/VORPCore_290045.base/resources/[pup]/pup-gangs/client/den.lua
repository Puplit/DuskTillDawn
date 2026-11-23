-- pup-gangs | client/den.lua: the den door

local Core = exports.vorp_core:GetCore()

-- The five MP006 shells the dens sit in. Requesting one twice is free.
CreateThread(function()
    Wait(500)
    for _, m in ipairs({
        'MP006_A3SUPP_MOONSHINE01', 'MP006_A3SUPP_MOONSHINE01_PLUG',
        'MP006_A2SUPP_MOONSHINE02', 'MP006_A2SUPP_MOONSHINE02_PLUG',
        'MP006_A4SUPP_MOONSHINE03', 'MP006_A4SUPP_MOONSHINE03_PLUG',
        'MP006_A1SUPP_MOONSHINE04', 'MP006_A1SUPP_MOONSHINE04_PLUG',
        'MP006_A4SUPP_MOONSHINE05', 'MP006_A4SUPP_MOONSHINE05_PLUG',
    }) do
        RequestImap(GetHashKey(m))
    end
end)

local inside = nil     -- the site key we are currently stood inside, or nil
local busy   = false   -- a transition is running; do not stack them

local function dbg(...)
    if Config.General.debug then print('^5[pup-gangs den]^7', ...) end
end

-- PROMPT - its own group, so it never shares a frame with the den's other prompts
local doorGroup = GetRandomIntInRange(0, 0xffffff)
local doorPrompt

CreateThread(function()
    doorPrompt = PromptRegisterBegin()
    PromptSetControlAction(doorPrompt, Config.Keys.denDoor) -- G
    PromptSetText(doorPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.denEnter))
    PromptSetEnabled(doorPrompt, 1)
    PromptSetVisible(doorPrompt, 1)
    PromptSetStandardMode(doorPrompt, 1)
    PromptSetGroup(doorPrompt, doorGroup)
    PromptRegisterEnd(doorPrompt)
    dbg('door prompt registered in its own group', doorGroup)
end)

-- MOVING THROUGH THE DOOR

-- turn on the shack's dressing
local function applyInterior(site)
    local id = tonumber(site.interior)
    if not id then return end
    for _, set in ipairs(site.interiorSets or {}) do
        if not IsInteriorEntitySetActive(id, set) then
            ActivateInteriorEntitySet(id, set)
        end
    end
end

-- Sets stick per client; 77313 is shared with pup_hideouts, 78337 with the creator.
local function clearInterior(site)
    local id = tonumber(site.interior)
    if not id then return end
    for _, set in ipairs(site.interiorSets or {}) do
        if IsInteriorEntitySetActive(id, set) then
            DeactivateInteriorEntitySet(id, set)
        end
    end
end

-- Fade, move, fade back
local function moveTo(pos, heading)
    DoScreenFadeOut(400)
    local guard = 0
    while not IsScreenFadedOut() and guard < 50 do guard = guard + 1 Wait(20) end

    local ped = PlayerPedId()
    SetEntityCoords(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
    if heading then SetEntityHeading(ped, heading + 0.0) end

    guard = 0
    while not HasCollisionLoadedAroundEntity(ped) and guard < 100 do guard = guard + 1 Wait(20) end
    Wait(250)

    DoScreenFadeIn(500)
end

local function goInside(siteKey)
    local site = (Config.Dens.sites or {})[siteKey]
    if not site or not site.inside then return end
    if busy then return end
    busy = true

    applyInterior(site)
    moveTo(site.inside, site.inside.h)
    inside = siteKey
    dbg('entered', siteKey)

    busy = false
end

local function goOutside()
    local site = inside and (Config.Dens.sites or {})[inside] or nil
    if not site or not site.outside then inside = nil return end
    if busy then return end
    busy = true

    moveTo(site.outside, site.outside.h)
    clearInterior(site) -- after the move, or the room empties around them
    dbg('left', inside)
    inside = nil

    busy = false
end

-- If the resource restarts while somebody is stood in a shack they would be sealed in a room with no exit prompt
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if not inside then return end
    local site = (Config.Dens.sites or {})[inside]
    if site and site.outside then
        local ped = PlayerPedId()
        SetEntityCoords(ped, site.outside.x + 0.0, site.outside.y + 0.0, site.outside.z + 0.0,
            false, false, false, false)
        clearInterior(site)
    end
end)

-- THE DEN PANEL - its own prompt at the site's `bench` spot, in its own group for the same reason the door has one
local panelGroup = GetRandomIntInRange(0, 0xffffff)
local panelPrompt

-- the Den Stores container, its own group again so it never shares a frame with the panel prompt four metres away
local stashGroup = GetRandomIntInRange(0, 0xffffff)
local stashPrompt

CreateThread(function()
    panelPrompt = PromptRegisterBegin()
    PromptSetControlAction(panelPrompt, Config.Keys.denWorkbench) -- E
    PromptSetText(panelPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.denWorkbench))
    PromptSetEnabled(panelPrompt, 1)
    PromptSetVisible(panelPrompt, 1)
    PromptSetStandardMode(panelPrompt, 1)
    PromptSetGroup(panelPrompt, panelGroup)
    PromptRegisterEnd(panelPrompt)

    stashPrompt = PromptRegisterBegin()
    PromptSetControlAction(stashPrompt, Config.Keys.denStores) -- E
    PromptSetText(stashPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.denStores))
    PromptSetEnabled(stashPrompt, 1)
    PromptSetVisible(stashPrompt, 1)
    PromptSetStandardMode(stashPrompt, 1)
    PromptSetGroup(stashPrompt, stashGroup)
    PromptRegisterEnd(stashPrompt)
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession

    while true do
        local sleep = 800

        -- only worth checking while actually stood in a shack
        if Config.Dens.enabled and inside and panelPrompt and not busy then
            local site = (Config.Dens.sites or {})[inside]
            local coords = GetEntityCoords(PlayerPedId())
            local reach <const> = (tonumber(Config.Dens.interactDistance) or 2.0) + 0.5

            -- DEN STORES
            local sst = site and site.stash or nil
            if sst and #(coords - vector3(sst.x + 0.0, sst.y + 0.0, sst.z + 0.0)) <= reach then
                sleep = 0
                PromptSetActiveGroupThisFrame(stashGroup,
                    CreateVarString(10, 'LITERAL_STRING', site.label or 'Den'))
                if Citizen.InvokeNative(0xC92AC953F0A982AE, stashPrompt) then
                    TriggerServerEvent('pup-gangs:openStash', 'den')
                end
            else

            local spot = site and site.bench or nil
            if spot then
                local d = #(coords - vector3(spot.x + 0.0, spot.y + 0.0, spot.z + 0.0))
                if d <= reach then
                    sleep = 0
                    PromptSetActiveGroupThisFrame(panelGroup,
                        CreateVarString(10, 'LITERAL_STRING', site.label or 'Den'))
                    if Citizen.InvokeNative(0xC92AC953F0A982AE, panelPrompt) then
                        -- which den is this shack? the door only tracks the SITE, so match it back to the den row we hold
                        local denId
                        for _, den in ipairs((GangDensMine and GangDensMine()) or {}) do
                            if den.site == inside then denId = den.id break end
                        end
                        if denId and OpenDenPanel then
                            OpenDenPanel(denId)
                        else
                            dbg('no den row for site', inside, '- panel not opened')
                        end
                    end
                end
            end
            end
        end

        Wait(sleep)
    end
end)

-- the door loop needs to know we are inside; expose it for client/main.lua too
function GangDenInsideSite() return inside end

-- /denwhere - why is there no prompt?
if Config.General.debug then
    RegisterCommand('denwhere', function()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        print('^3[denwhere]^7 ------------------------------------------')
        print(('  dens enabled   : %s'):format(tostring(Config.Dens.enabled)))
        print(('  door prompt    : %s'):format(doorPrompt and 'registered' or '^1NOT REGISTERED^7'))
        print(('  doorDistance   : %.1f'):format(tonumber(Config.Dens.doorDistance) or -1))
        print(('  inside now     : %s'):format(tostring(inside)))
        print(('  you are at     : %.2f %.2f %.2f'):format(coords.x, coords.y, coords.z))

        local mine  = (GangDensMine and GangDensMine()) or {}
        local known = (GangDensKnown and GangDensKnown()) or {}
        print(('  our dens       : %d'):format(#mine))
        print(('  found dens     : %d   ^3(0 = your gang has not discovered any - ride within %.0fm)^7')
            :format(#known, tonumber(Config.Dens.discovery.discoverDistance) or 35))

        local function report(tag, list)
            for _, den in ipairs(list) do
                local s = den.site and (Config.Dens.sites or {})[den.site] or nil
                local o = s and s.outside or nil
                local d = o and #(coords - vector3(o.x + 0.0, o.y + 0.0, o.z + 0.0)) or -1
                print(('  [%s] %s  site=%s  %s  door %s')
                    :format(tag, tostring(den.label or '?'), tostring(den.site or '^1none^7'),
                        den.unowned and 'unowned' or ('held by ' .. tostring(den.holder or 'us')),
                        d >= 0 and (('%.1fm %s'):format(d, d <= (Config.Dens.doorDistance or 1.8) and '^2IN RANGE^7' or 'too far'))
                            or '^1no site coords^7'))
            end
        end
        report('ours', mine)
        report('found', known)
        print('^3[denwhere]^7 ------------------------------------------')
    end, false)
end

-- /gangdendoor <site> - record where the door ACTUALLY is
if Config.General.debug then
    RegisterCommand('gangdendoor', function(_, args)
        local key = tostring(args[1] or '')
        local site = (Config.Dens.sites or {})[key]
        if not site then
            print('^1[gangdendoor]^7 usage: /gangdendoor <site>')
            local names = {}
            for k in pairs(Config.Dens.sites or {}) do names[#names + 1] = k end
            table.sort(names)
            print('  sites: ' .. table.concat(names, ', '))
            return
        end

        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local h = GetEntityHeading(ped)

        -- live for this session so the prompt can be tested straight away
        site.outside = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, h = h + 0.0 }

        print(('^2[gangdendoor]^7 %s door set - paste this into config/dens.lua:'):format(key))
        print(('        outside  = { x = %.2f, y = %.2f, z = %.2f, h = %.2f },'):format(c.x, c.y, c.z, h))
        print(('        -- interior is at z %.2f (%.1fm %s you)')
            :format(tonumber(site.inside and site.inside.z) or 0,
                math.abs((tonumber(site.inside and site.inside.z) or 0) - c.z),
                ((tonumber(site.inside and site.inside.z) or 0) > c.z) and 'above' or 'below'))
    end, false)
end

-- THE DOOR LOOP
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession

    while true do
        local sleep = 800

        if Config.Dens.enabled and not busy and doorPrompt then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if inside then
                -- INSIDE: one prompt back out, at the spot we arrived on
                local site = (Config.Dens.sites or {})[inside]
                local exitAt = site and site.inside
                if exitAt then
                    local d = #(coords - vector3(exitAt.x + 0.0, exitAt.y + 0.0, exitAt.z + 0.0))
                    if d <= (Config.Dens.doorDistance + 1.2) then
                        sleep = 0
                        PromptSetText(doorPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.denLeave))
                        PromptSetActiveGroupThisFrame(doorGroup,
                            CreateVarString(10, 'LITERAL_STRING', site.label or 'Den'))
                        if Citizen.InvokeNative(0xC92AC953F0A982AE, doorPrompt) then
                            goOutside()
                        end
                    end
                end
            else
                -- OUTSIDE: our own dens open, found-but-unowned ones take a key
                local hit, mode = nil, nil

                for _, den in ipairs((GangDensMine and GangDensMine()) or {}) do
                    if den.site and (Config.Dens.sites or {})[den.site] then
                        local s = Config.Dens.sites[den.site]
                        local o = s.outside
                        if o and #(coords - vector3(o.x + 0.0, o.y + 0.0, o.z + 0.0)) <= Config.Dens.doorDistance then
                            hit, mode = den, 'enter'
                            break
                        end
                    end
                end

                if not hit then
                    for _, den in ipairs((GangDensKnown and GangDensKnown()) or {}) do
                        if den.unowned and den.site and (Config.Dens.sites or {})[den.site] then
                            local s = Config.Dens.sites[den.site]
                            local o = s.outside
                            if o and #(coords - vector3(o.x + 0.0, o.y + 0.0, o.z + 0.0)) <= Config.Dens.doorDistance then
                                hit, mode = den, 'key'
                                break
                            end
                        end
                    end
                end

                if hit then
                    sleep = 0
                    local s = Config.Dens.sites[hit.site]
                    PromptSetText(doorPrompt, CreateVarString(10, 'LITERAL_STRING',
                        mode == 'key' and Locale.denUseKey or Locale.denEnter))
                    PromptSetActiveGroupThisFrame(doorGroup,
                        CreateVarString(10, 'LITERAL_STRING', hit.label or s.label or 'Den'))
                    if Citizen.InvokeNative(0xC92AC953F0A982AE, doorPrompt) then
                        if mode == 'key' then
                            -- the server decides: it checks the satchel, spends the key and hands the den over
                            TriggerServerEvent('pup-gangs:denUseKey', hit.id)
                        else
                            goInside(hit.site)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

