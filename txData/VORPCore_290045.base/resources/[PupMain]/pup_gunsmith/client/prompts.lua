-- pup_gunsmith | world prompts (counters, crafting stations, benches), shop blips, station list

local function varString(text)
    if VarString then return VarString(10, 'LITERAL_STRING', text) end
    return CreateVarString(10, 'LITERAL_STRING', text)
end

-- one prompt group per kind of place; the group title is set each frame
local function makePrompt(text)
    local group = GetRandomIntInRange(0, 0xffffff)
    local p = UiPromptRegisterBegin()
    UiPromptSetControlAction(p, Config.InteractKey)
    UiPromptSetText(p, varString(text))
    UiPromptSetEnabled(p, true)
    UiPromptSetVisible(p, true)
    UiPromptSetStandardMode(p, true)
    UiPromptSetGroup(p, group, 0)
    UiPromptRegisterEnd(p)
    return { prompt = p, group = group }
end

local P = {}

local function ensurePrompts()
    if P.shop then return end
    P.shop = makePrompt(L('prompt_shop'))
    P.station = makePrompt(L('prompt_craft'))
    P.bench = makePrompt(L('prompt_customize'))
end

---------------------------------------------------------------------------
-- crafting stations pushed by the server
---------------------------------------------------------------------------
RegisterNetEvent('pup_gunsmith:stations', function(list)
    local out = {}
    if type(list) == 'table' then
        for _, s in ipairs(list) do
            local x, y, z = type(s) == 'table' and s.x, type(s) == 'table' and s.y, type(s) == 'table' and s.z
            if type(x) == 'number' and type(y) == 'number' and type(z) == 'number' and type(s.name) == 'string' then
                out[#out + 1] = { name = s.name, coords = vector3(x, y, z) }
            else
                print(('[pup_gunsmith] dropped a crafting station without numeric coordinates: %s')
                    :format(tostring(type(s) == 'table' and s.name or s)))
            end
        end
    end
    Cl.stations = out
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('pup_gunsmith:stationsRequest')
end)

RegisterCommand('weaponcraftdebug', function()
    if not (Config.Debug and Config.Debug.general) then return end
    print('[pup_gunsmith] crafting stations known to this client:')
    for _, s in ipairs(Cl.stations) do
        print(('  %-28s %.2f, %.2f, %.2f'):format(s.name, s.coords.x, s.coords.y, s.coords.z))
    end
    print(('[pup_gunsmith] %d station(s)'):format(#Cl.stations))
end, false)

---------------------------------------------------------------------------
-- blips (only counters flagged for one)
---------------------------------------------------------------------------
local blips = {}

CreateThread(function()
    if not Config.Shop.enabled then return end
    for _, c in ipairs(Config.ShopCounters) do
        if c.blip then
            local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, c.coords.x, c.coords.y, c.coords.z) -- BLIP_ADD_FOR_COORDS
            SetBlipSprite(b, Config.Shop.blipSprite, true)
            SetBlipScale(b, Config.Shop.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, c.name) -- SET_BLIP_NAME
            blips[#blips + 1] = b
        end
    end
end)

---------------------------------------------------------------------------
-- the prompt loop: slow while nothing is near, every frame only while a prompt shows
---------------------------------------------------------------------------
local function nearest(pos)
    local best, bestD, kind = nil, Config.PromptDistance, nil
    local far = math.huge
    local function consider(k, target, coords)
        local d = #(pos - coords)
        if d < far then far = d end
        if d <= bestD then best, bestD, kind = target, d, k end
    end
    if Config.Shop.enabled then
        for _, c in ipairs(Config.ShopCounters) do consider('shop', c, c.coords) end
    end
    for _, s in ipairs(Cl.stations) do consider('station', s, s.coords) end
    for _, b in ipairs(Config.Benches) do consider('bench', b, b.stand) end
    return kind, best, far
end

local function activate(kind, target)
    if kind == 'shop' then
        Cl.busy = 'shop'
        CreateThread(function() ShopCl.open(target) end)
    elseif kind == 'station' then
        Cl.busy = 'station'
        CreateThread(function() CraftCl.open(target) end)
    elseif kind == 'bench' then
        Cl.busy = 'benchOpening'
        CreateThread(function() BenchCl.open(target) end)
    end
end

CreateThread(function()
    ensurePrompts()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        if not Cl.busy and not IsEntityDead(ped) then
            local kind, target, far = nearest(GetEntityCoords(ped))
            if kind then
                wait = 0
                local p = P[kind]
                local title
                if kind == 'shop' then
                    title = target.name or L('shop_title')
                elseif kind == 'station' then
                    title = L('group_craft')
                else
                    title = L('group_customize', target.label or target.id)
                end
                UiPromptSetActiveGroupThisFrame(p.group, varString(title), 0, 0, 0, 0)
                if UiPromptHasStandardModeCompleted(p.prompt, 0) then
                    activate(kind, target)
                end
            elseif far < 20.0 then
                wait = 250
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GS.RES then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for _, p in pairs(P) do UiPromptDelete(p.prompt) end
end)
