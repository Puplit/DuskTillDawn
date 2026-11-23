-- pup_hideouts | the door outside: buying, knocking (both sides), the raid prompt, staff delete

local H <const> = Config.Hideouts

HX.flags = { admin = false, staff = false, police = false }

-- what the server says this player is (job and group are read fresh on the server)
function HX.refreshFlags()
    local ok, f = HX.call('me', 4000)
    if ok and type(f) == 'table' then HX.flags = f end
    return HX.flags
end

local lastKnock = 0

----------------------------------------------------------------------------------------------------
-- knocks waiting for this player's answer (members)
----------------------------------------------------------------------------------------------------
local asks = {} -- list of { knocker, name, id }

RegisterNetEvent('pup_hideouts:knockAsk', function(knocker, name, id)
    knocker = tonumber(knocker)
    if not knocker then return end
    for _, a in ipairs(asks) do if a.knocker == knocker then return end end
    local who = type(name) == 'string' and name or '?'
    asks[#asks + 1] = { knocker = knocker, name = who, id = id }
    HX.tip(L('is_knocking', who))
end)

RegisterNetEvent('pup_hideouts:knockEnd', function(knocker)
    knocker = tonumber(knocker)
    for i = #asks, 1, -1 do
        if asks[i].knocker == knocker then table.remove(asks, i) end
    end
end)

-- knocks were asked of the previous character
AddEventHandler('vorp:SelectedCharacter', function() asks = {} end)

function HX.hasKnockAsk() return asks[1] ~= nil end

-- the answer prompt wins over everything else while no menu is open
function HX.knockPrompt()
    local a = asks[1]
    if not a or HX.menuOpen then return false end
    local title = L('is_knocking', a.name)
    local p = HX.prompt(title, L('allow_in'), L('deny_entry'))
    if p then
        table.remove(asks, 1)
        HX.send('knockAnswer', a.knocker, p == 'primary')
    end
    return true
end

----------------------------------------------------------------------------------------------------
-- actions at a door
----------------------------------------------------------------------------------------------------
local function buy(id)
    HX.busy = true
    HX.call('buy', 6000, id)
    HX.busy = false
end

local function delete(id)
    HX.busy = true
    HX.call('delete', 6000, id)
    HX.busy = false
end

local function knock(id)
    local now = GetGameTimer()
    if now - lastKnock < H.knockWait * 1000 then
        HX.tip(L('knock_wait'))
        return
    end
    lastKnock = now
    HX.send('knock', id)
    HX.bottom(L('knocked'))
end

local function startRaid(id)
    HX.busy = true
    local ok, accepted = HX.call('raidStart', 6000, id)
    HX.busy = false
    if not ok then HX.tip(L('no_answer')) return end
    if not accepted then HX.Raid.clear() end
end

-- may this player see the Raid prompt at this door?
local function canRaid(r)
    if r.raidcooldown or r.justraided or not r.owned or r.member then return false end
    if HX.Raid.active() then return false end
    local mode = Config.Raids.mode
    if mode == 'off' then return false end
    if mode == 'police' then return HX.flags.police == true end
    for _, row in pairs(HX.rows) do
        if row.member then return true end
    end
    return false
end

----------------------------------------------------------------------------------------------------
-- the nearest door within reach; returns true when something was shown
----------------------------------------------------------------------------------------------------
function HX.nearestDoor(pos, range)
    local best, bd = nil, range or H.promptRange
    for _, r in pairs(HX.rows) do
        if r.coords then
            local d = U.dist(pos, r.coords)
            if d <= bd then best, bd = r, d end
        end
    end
    return best, bd
end

function HX.doorPrompts(r)
    local id = r.id
    if not r.owned then
        local p = HX.prompt(L('price_prefix', U.money(r.price or 0)), L('buy_hideout'),
            HX.flags.staff and L('delete_hideout') or nil)
        if p == 'primary' then CreateThread(function() buy(id) end)
        elseif p == 'secondary' then CreateThread(function() delete(id) end) end
        return true
    end
    if HX.Raid.doorPrompts(r) then return true end
    if r.member or (r.justraided and r.isCrew) then
        if HX.prompt(L('hideout_id', id), L('enter_shack')) then CreateThread(function() HX.enter(id) end) end
        return true
    end
    if r.justraided then return false end
    local p = HX.prompt(L('hideout_id', id), L('secret_knock'), canRaid(r) and L('raid') or nil)
    if p == 'primary' then knock(id)
    elseif p == 'secondary' then CreateThread(function() startRaid(id) end) end
    return true
end
