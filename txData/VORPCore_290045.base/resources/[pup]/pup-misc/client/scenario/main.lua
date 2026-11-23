-- scenario | the /scenario menu (pup-ui), grouped into categories

local OWNER = 'scenario'

-- what the menu is currently showing; selections are routed by this view = 'root' | 'nearby' | a category key
local view    = nil
local rows    = {}   -- index -> { kind = 'point'|'inplace'|'cat'|'getup', ... }
local inMenu  = false

-- categories, built ONCE from config/scenario/scenarios.lua's ScenarioConfig.Scenarios
local MUSIC_WORDS = { 'MUSIC', 'GUITAR', 'VIOLIN', 'BANJO', 'HARMONICA', 'PIANO',
                      'SINGING', 'CONCERTINA', 'WASHBOARD', 'ACCORDION', 'FIDDLE', 'DRUM' }

local function isMusic(n)
    for _, w in ipairs(MUSIC_WORDS) do
        if n:find(w, 1, true) then return true end
    end
    return false
end

local CATEGORIES = {
    -- music FIRST in match order: a seated banjo scenario contains SEAT too, and it belongs with the instruments
    { key = 'music',   label = ScenarioLocale.catMusic,
      match = isMusic },
    { key = 'sitting', label = ScenarioLocale.catSitting,
      match = function(n) return (n:find('SIT', 1, true) or n:find('SEAT', 1, true)) and not isMusic(n) end },
    { key = 'leaning', label = ScenarioLocale.catLeaning,
      match = function(n) return n:find('LEAN', 1, true) ~= nil end },
    { key = 'vice',    label = ScenarioLocale.catVice,
      match = function(n) return (n:find('DRINK', 1, true) or n:find('SMOK', 1, true)) and not isMusic(n) end },
}

local pools = {}   -- key -> { scenario name, ... }

-- scenario type hash -> name, so the nearby scan is one lookup per point
local nameByHash

local function buildHashIndex()
    if nameByHash then return nameByHash end
    nameByHash = {}
    for _, name in ipairs(ScenarioConfig.Scenarios) do
        local h = GetHashKey(name)
        -- first match wins
        if nameByHash[h] == nil then nameByHash[h] = name end
    end
    return nameByHash
end

CreateThread(function()
    Wait(500)
    buildHashIndex()
    for _, c in ipairs(CATEGORIES) do pools[c.key] = {} end
    for _, name in ipairs(ScenarioConfig.Scenarios) do
        if name:find('^WORLD_HUMAN') or name:find('^PROP_HUMAN') then
            for _, c in ipairs(CATEGORIES) do
                if c.match(name) then
                    table.insert(pools[c.key], name)
                    break   -- one category per scenario; match order decides
                end
            end
        end
    end
    for _, c in ipairs(CATEGORIES) do table.sort(pools[c.key]) end
end)

-- menu label for a scenario name: "WORLD_HUMAN_SEAT_BENCH_DRINKING" -> "Seat Bench Drinking".
-- Whole words only, so a word like CAMP keeps its letters.
local NOISE_WORDS = { WORLD = true, HUMAN = true, PROP = true, MP = true, ANIMAL = true, PLAYER = true, VEHICLE = true }

local function scenarioLabel(name)
    local words = {}
    for word in name:gmatch('[^_]+') do
        if not NOISE_WORDS[word] then
            words[#words + 1] = word:sub(1, 1) .. word:sub(2):lower()
        end
    end
    if #words == 0 then return name end
    return table.concat(words, ' ')
end

-- pup-ui plumbing
local function uiUp()
    if GetResourceState('pup-ui') == 'started' then return true end
    TriggerEvent('vorp:TipRight', ScenarioLocale.menuUnavailable, 3000)
    return false
end

local function openList(title, subtitle, options)
    inMenu = true
    exports['pup-ui']:OpenListMenu({
        owner    = OWNER,
        title    = title,
        subtitle = subtitle,
        options  = options,
    })
end

-- the ROOT menu

-- world scenario points around the player that the menu can name.
-- GET_SCENARIO_POINTS_IN_AREA fills a buffer of 8-byte slots (the first slot is the
-- header, points follow); empty slots stay 0.
local GET_SCENARIO_POINTS_IN_AREA = 0x345EC3B7EBDE1CB5
local GET_SCENARIO_POINT_TYPE     = 0xA92450B5AE687AAF
local NEARBY_RADIUS, NEARBY_MAX   = 3.0, 10

local function pointsAround()
    -- the startup thread normally has the index ready; opening the menu inside its
    -- first half second builds it here instead
    local names = buildHashIndex()
    local slots = DataView.ArrayBuffer(8 * 32)
    local got = Citizen.InvokeNative(GET_SCENARIO_POINTS_IN_AREA, GetEntityCoords(PlayerPedId()),
        NEARBY_RADIUS, slots:Buffer(), NEARBY_MAX)
    if not got then return {} end

    local list = {}
    for slot = 1, NEARBY_MAX do
        local point = slots:GetInt32(slot * 8)
        local name = point ~= 0 and names[Citizen.InvokeNative(GET_SCENARIO_POINT_TYPE, point)] or nil
        if name then list[#list + 1] = { point = point, name = name } end
    end
    return list
end

local function openRoot()
    if not uiUp() then return end
    view, rows = 'root', {}
    local options = {}
    local function add(row, label, desc)
        options[#options + 1] = { label = label, desc = desc }
        rows[#rows + 1] = row
    end

    local nearby = pointsAround()
    if #nearby > 0 then
        add({ kind = 'cat', key = 'nearby', nearby = nearby },
            (ScenarioLocale.nearbyCount):format(#nearby),
            ScenarioLocale.nearbyDesc)
    end
    for _, c in ipairs(CATEGORIES) do
        local n = pools[c.key] and #pools[c.key] or 0
        if n > 0 then
            add({ kind = 'cat', key = c.key },
                ('%s (%d)'):format(c.label, n),
                ScenarioLocale.categoryDesc)
        end
    end
    add({ kind = 'getup' }, ScenarioLocale.getUp, ScenarioLocale.getUpDesc)

    openList(ScenarioLocale.title, ScenarioLocale.pickCategory, options)
end

local function openCategory(row)
    view, rows = row.key, {}
    local options = {}

    if row.key == 'nearby' then
        for _, f in ipairs(row.nearby) do
            options[#options + 1] = { label = scenarioLabel(f.name), desc = ScenarioLocale.nearbySpotDesc }
            rows[#rows + 1] = { kind = 'point', point = f.point }
        end
        openList(ScenarioLocale.nearbyTitle, ScenarioLocale.nearbySubtitle, options)
        return
    end

    local label = row.key
    for _, c in ipairs(CATEGORIES) do if c.key == row.key then label = c.label end end
    for _, name in ipairs(pools[row.key] or {}) do
        options[#options + 1] = { label = scenarioLabel(name), desc = '' }
        rows[#rows + 1] = { kind = 'inplace', name = name }
    end
    openList(label, ScenarioLocale.playHere, options)
end

-- selection / navigation (owner-filtered: several resources share the list)
AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= OWNER or not inMenu then return end
    local row = rows[index]
    if not row then return end

    if row.kind == 'cat' then
        openCategory(row)
        return
    end

    inMenu = false
    local ped = PlayerPedId()
    if row.kind == 'getup' then
        ClearPedTasks(ped)
        return
    end

    ClearPedTasks(ped)
    Wait(400)
    if row.kind == 'point' then
        TaskUseScenarioPoint(ped, row.point, '', -1.0, true, false, 0, false, -1.0, true)
    elseif row.kind == 'inplace' then
        -- -1 = hold the pose until the player moves or picks Get Up
        TaskStartScenarioInPlace(ped, GetHashKey(row.name), -1, true, false, false, false)
    end
end)

-- ESC in a category steps back to the root; ESC at the root just closes
AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= OWNER or not inMenu then return end
    if view ~= nil and view ~= 'root' then
        openRoot()
    else
        inMenu = false
        view, rows = nil, {}
    end
end)

-- forced close (another panel took over, /hideui, death): drop our state so a stale selection can never fire later
AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= OWNER then return end
    inMenu = false
    view, rows = nil, {}
end)

RegisterCommand(ScenarioConfig.General.command, function()
    openRoot()
end)
