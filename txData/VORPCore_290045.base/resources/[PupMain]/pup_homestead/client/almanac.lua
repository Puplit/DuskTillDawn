-- pup_homestead | the Almanac (pup-ui ink menu): your plots, the crop guide, your ledger
local H = Homestead
local OWNER <const> = 'pup_homestead:almanac'

local rows = nil -- what each option of the open menu does: { run = fn } per index
local data = nil -- the server's almanac answer while the menu is open

local function show(title, sub, list)
    rows = list
    local opts = {}
    for i, r in ipairs(list) do opts[i] = { label = r.label, description = r.desc } end
    exports['pup-ui']:OpenInkMenu({ owner = OWNER, title = title, subtitle = sub, options = opts })
end

local menus = {}

-- a GPS route to a plot (RedM has no SetNewWaypoint)
local function routeTo(p)
    pcall(function()
        local me = GetEntityCoords(PlayerPedId())
        ClearGpsMultiRoute()
        StartGpsMultiRoute(GetHashKey('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(me.x, me.y, me.z, false)
        AddPointToGpsMultiRoute(p.x + 0.0, p.y + 0.0, p.z + 0.0, false)
        SetGpsMultiRouteRender(true)
    end)
    H.tip(Locale.marked)
end

function menus.main()
    local c = { growing = 0, thirsty = 0, ready = 0 }
    for _, p in ipairs(data.plots) do c[p.stage] = c[p.stage] + 1 end
    local crops = 0
    for _, cr in pairs(Config.Crops) do if not cr.gang then crops = crops + 1 end end
    show(Locale.title, Locale.plotsCount:format(#data.plots, data.cap), {
        { label = Locale.tabPlots, desc = Locale.mainPlots:format(c.growing, c.thirsty, c.ready), run = menus.plots },
        { label = Locale.tabCrops, desc = Locale.mainCrops:format(crops), run = menus.crops },
        { label = Locale.tabLedger, desc = Locale.ledgerSub, run = menus.ledger },
    })
end

function menus.plots()
    local list = { { label = Locale.back, desc = Locale.backDesc, run = menus.main } }
    local me = GetEntityCoords(PlayerPedId())
    -- ready first, then the thirsty, then the rest; nearest first within each
    local order = { ready = 1, thirsty = 2, growing = 3 }
    table.sort(data.plots, function(a, b)
        if order[a.stage] ~= order[b.stage] then return order[a.stage] < order[b.stage] end
        return #(me - vector3(a.x, a.y, a.z)) < #(me - vector3(b.x, b.y, b.z))
    end)
    for _, p in ipairs(data.plots) do
        list[#list + 1] = {
            label = H.status({ crop = p.crop, left = p.left, watered = p.watered, fert = p.fert, trim = p.trim }),
            desc = Locale.plotDesc:format(#(me - vector3(p.x, p.y, p.z)), p.health),
            close = true, -- choosing a plot routes you there and closes the almanac
            run = function() routeTo(p) end,
        }
    end
    if #data.plots == 0 then list[#list + 1] = { label = Locale.plotsEmpty, desc = '', run = menus.plots } end
    show(Locale.tabPlots, Locale.plotsCount:format(#data.plots, data.cap), list)
end

function menus.crops()
    local b = data.bonus
    local list = {
        { label = Locale.back, desc = Locale.backDesc, run = menus.main },
        { label = Locale.yourBonus, desc = Locale.bonusLine:format(b.limit, b.yield, b.waterRadius, b.fertRadius), run = menus.crops },
    }
    local names = {}
    for name, c in pairs(Config.Crops) do if not c.gang then names[#names + 1] = name end end
    table.sort(names)
    for _, name in ipairs(names) do
        local c = Config.Crops[name]
        local gives = {}
        for _, r in ipairs(c.yield) do gives[#gives + 1] = ('%d %s'):format(r.count, r.label) end
        local desc = Locale.cropLine:format(c.seeds, c.seeds == 1 and Locale.seed or Locale.seeds, c.grow, c.waterAt, table.concat(gives, ', '))
        if c.jobs then desc = desc .. '  -  ' .. Locale.cropJob:format(table.concat(c.jobs, ', ')) end
        list[#list + 1] = { label = name, desc = desc, run = menus.crops }
    end
    show(Locale.tabCrops, Locale.cropsSub, list)
end

function menus.ledger()
    local list = { { label = Locale.back, desc = Locale.backDesc, run = menus.main } }
    local total = 0
    for _, r in ipairs(data.stats) do total = total + r.harvested end
    for _, r in ipairs(data.stats) do
        list[#list + 1] = { label = r.crop, desc = Locale.ledgerLine:format(r.planted, r.harvested, r.gathered), run = menus.ledger }
    end
    if #data.stats == 0 then list[#list + 1] = { label = Locale.ledgerEmpty, desc = '', run = menus.ledger } end
    show(Locale.tabLedger, Locale.ledgerTotal:format(total), list)
end

RegisterCommand(Config.General.almanacCommand, function()
    if rows then return end
    data = H.ask({ op = 'almanac' })
    if not data then return end
    menus.main()
end, false)

-- the menu stays open on select; each choice draws the next menu (or routes and closes)
AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not rows then return end
    local r = rows[index]
    if not r or not r.run then return end
    if r.close then
        rows, data = nil, nil
        exports['pup-ui']:HideInkMenu()
    end
    r.run()
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner == OWNER then rows, data = nil, nil end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and rows then exports['pup-ui']:HideInkMenu() end
end)
