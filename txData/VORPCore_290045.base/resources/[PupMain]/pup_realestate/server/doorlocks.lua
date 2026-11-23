-- pup_realestate | optional doorlocks bridge (off by default): real doors run by the doorlocks resource
--
-- doorlocks API (server, exports.doorlocks:GetAPI()):
--   API:DoorByHash(hash)      -> door object or nil    (method: needs the API table as self)
--   API:AddNewDoor(def)       -> ok:boolean, door|nil  (method)
--   door.fn.SetCharAccess(list), door.fn.SetCanLockpick(bool), door.fn.SetLock(bool), door.fn.Delete()
--   door.Data.doorid
--   def = { name, door = { hash, model, coords } } or { name, doors = { {..}, {..} } } plus
--         jobAccess (map, must be a table), charAccess (list), itemNameAccess (false or item name),
--         lockedOnStart, canLockpick, alertLaw, showPrompt
-- Functions inside a table that crosses an export come back as callable tables, not Lua
-- functions, so every call here goes through callable() and pcall.

local function callable(f)
    if type(f) == 'function' then return true end
    if type(f) == 'table' then
        local mt = getmetatable(f)
        return type(mt) == 'table' and mt.__call ~= nil
    end
    return false
end

local warned = {}
local function warnOnce(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    Warn(fmt, ...)
end

local function api()
    local res = Config.Doorlocks.resource
    if GetResourceState(res) ~= 'started' then return nil end
    local ok, a = pcall(function() return exports[res]:GetAPI() end)
    if ok and type(a) == 'table' and callable(a.DoorByHash) and callable(a.AddNewDoor) then return a end
    warnOnce('api', 'doorlocks bridge: %s:GetAPI() is missing or has no DoorByHash/AddNewDoor (%s); bridge skipped', tostring(res), tostring(ok and type(a) or a))
    return nil
end

local function family(name)
    name = tostring(name or ''):lower()
    for _, suffix in ipairs({ '_lx', '_rx', '_l', '_r' }) do
        if name:sub(-#suffix) == suffix then return name:sub(1, -#suffix - 1), true end
    end
    return name, false
end

-- the lockable doors of a house, double doors paired
local function lockable(h)
    local doors = {}
    if h.kind ~= KIND_REAL then return doors end
    local function add(d, label)
        if type(d) == 'table' and U.int(d.objc) and U.int(d.objc) ~= 0 and U.vec(d) then
            doors[#doors + 1] = { door = d, label = label, pos = U.vec(d) }
        end
    end
    add(h.doors[1], ('House %s'):format(h.id))
    for i, d in ipairs(h.other) do add(d, ('House %s - door %s'):format(h.id, U.int(d.secondarydoorid) or i)) end
    local groups, used = {}, {}
    for i, a in ipairs(doors) do
        if not used[i] then
            used[i] = true
            local g = { label = a.label, parts = { a } }
            local fa, sided = family(a.door.doorname)
            if sided then
                for j = i + 1, #doors do
                    local b = doors[j]
                    if not used[j] and family(b.door.doorname) == fa and #(a.pos - b.pos) <= 3.0 then
                        used[j] = true
                        g.parts[2] = b
                        break
                    end
                end
            end
            groups[#groups + 1] = g
        end
    end
    return groups
end

local function charAccess(h)
    if not h.owned then return { -1 } end -- placeholder: nobody gets in by character
    local list = { h.buyerChar }
    for _, k in ipairs(h.keys) do
        local cid = tonumber(k.charidentifier or k.charid)
        if cid then list[#list + 1] = cid end
    end
    return list
end

-- door-system hashes are stored unsigned here; doorlocks may hold a door it captured itself
-- in the signed form, so both are tried
local function hashForms(hash)
    hash = U.int(hash)
    if not hash then return {} end
    local forms = { hash }
    if hash > 0x7FFFFFFF then forms[2] = hash - 0x100000000
    elseif hash < 0 then forms[2] = hash + 0x100000000 end
    return forms
end

local function doorOf(a, hash)
    for _, hv in ipairs(hashForms(hash)) do
        local ok, d = pcall(function() return a:DoorByHash(hv) end)
        if ok and type(d) == 'table' then return d end
        if not ok then warnOnce('byhash', 'doorlocks bridge: DoorByHash failed: %s', tostring(d)) end
    end
    return nil
end

-- doors this bridge registered are remembered per doorid (resource KVP: doorid -> house id);
-- any other doorlocks door is never changed or deleted from here
local function doorId(d)
    return d and type(d.Data) == 'table' and U.int(d.Data.doorid) or nil
end

local function remember(d, h)
    local id = doorId(d)
    if id then SetResourceKvp('dl_door_' .. id, tostring(h.id)) end
end

local function forget(d)
    local id = doorId(d)
    if id then DeleteResourceKvp('dl_door_' .. id) end
end

-- the names this bridge gives a house's doors
local function ourName(h, name)
    name = tostring(name or '')
    local base = ('House %s'):format(h.id)
    return name == base or name:sub(1, #base + 8) == base .. ' - door '
end

local function isOurs(d, h)
    local id = doorId(d)
    if not id then return false end
    local rec = GetResourceKvpString('dl_door_' .. id)
    if rec then return rec == tostring(h.id) end
    -- doors registered before the KVP record existed: adopt only by their exact bridge name
    if type(d.Data) == 'table' and ourName(h, d.Data.name) then
        remember(d, h)
        return true
    end
    return false
end

-- true when doorlocks already runs a door with this hash (used to refuse it for a new house)
function S.doorlocksHas(hash)
    if not U.int(hash) or U.int(hash) == 0 then return false end
    local a = api()
    if not a then return false end
    return doorOf(a, hash) ~= nil
end

local function call(door, fname, ...)
    local fn = door and type(door.fn) == 'table' and door.fn[fname]
    if not callable(fn) then
        warnOnce('fn_' .. fname, 'doorlocks bridge: door.fn.%s is missing in this doorlocks version', fname)
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then Warn('doorlocks bridge: door.fn.%s failed: %s', fname, tostring(err)) end
end

local function doorDef(p)
    return {
        hash = U.int(p.door.objc),
        model = U.int(p.door.doorhash) or 0,
        coords = vector3(p.pos.x, p.pos.y, p.pos.z),
    }
end

function S.bridgeSync(h)
    if not Config.Doorlocks.enabled or not h or h.kind ~= KIND_REAL then return end
    local a = api()
    if not a then return end
    local viewing = S.viewing[h.id] and S.viewing[h.id] > Now()
    for _, g in ipairs(lockable(h)) do
        local first = doorOf(a, g.parts[1].door.objc)
        local second = g.parts[2] and doorOf(a, g.parts[2].door.objc)
        if (first and not isOurs(first, h)) or (second and not isOurs(second, h)) then
            -- a door doorlocks already had: leave it alone
            warnOnce('foreign_' .. h.id, 'doorlocks bridge: house %s uses a door doorlocks already runs; it is left to doorlocks', h.id)
            goto continue
        end
        if g.parts[2] and first and second and first.Data and second.Data and first.Data.doorid ~= second.Data.doorid then
            forget(first)
            forget(second)
            call(first, 'Delete')
            call(second, 'Delete')
            first, second = nil, nil
            AdminLog(('House %s: re-registered a double doorway as ONE lock'):format(h.id))
            -- doorlocks drops a door only in its async DB callback; until then AddNewDoor
            -- would refuse the pair as "already exists"
            for _ = 1, 20 do
                if not doorOf(a, g.parts[1].door.objc) and not doorOf(a, g.parts[2].door.objc) then break end
                Wait(100)
            end
        end
        if not first then
            local def = {
                name = g.label,
                jobAccess = {}, charAccess = charAccess(h), itemNameAccess = false,
                lockedOnStart = true, canLockpick = Config.Doorlocks.lockpickable == true,
                alertLaw = false, showPrompt = true,
            }
            if g.parts[2] then
                def.doors = { doorDef(g.parts[1]), doorDef(g.parts[2]) }
            else
                def.door = doorDef(g.parts[1])
            end
            local ok, added, door = pcall(function() return a:AddNewDoor(def) end)
            if not ok then
                Warn('doorlocks bridge: AddNewDoor failed for house %s: %s', h.id, tostring(added))
            elseif added and type(door) == 'table' then
                first = door
                remember(first, h)
            else
                first = doorOf(a, g.parts[1].door.objc)
                if first and not isOurs(first, h) then first = nil end
            end
        end
        if first then
            call(first, 'SetCharAccess', charAccess(h))
            call(first, 'SetCanLockpick', Config.Doorlocks.lockpickable == true)
            if not h.owned then call(first, 'SetLock', not viewing) end
        end
        ::continue::
    end
end

function S.bridgeRemove(h)
    if not Config.Doorlocks.enabled or not h then return end
    local a = api()
    if not a then return end
    for _, g in ipairs(lockable(h)) do
        for _, p in ipairs(g.parts) do
            local d = doorOf(a, p.door.objc)
            if d and isOurs(d, h) then
                forget(d)
                call(d, 'Delete')
            end
        end
    end
end

local function onDoorlocksReady()
    local a = api()
    if not a then return end
    if Config.Doorlocks.enabled then
        for _, h in pairs(S.houses) do S.bridgeSync(h) end
        return
    end
    -- bridge off: evict our doors that doorlocks still knows
    local n = 0
    for _, h in pairs(S.houses) do
        for _, g in ipairs(lockable(h)) do
            for _, p in ipairs(g.parts) do
                local d = doorOf(a, p.door.objc)
                if d and isOurs(d, h) then
                    forget(d)
                    call(d, 'Delete')
                    n = n + 1
                end
            end
        end
    end
    if n > 0 then print(('[pup_realestate] removed %s house door(s) from doorlocks (bridge is off)'):format(n)) end
end

-- doorlocks fires this once its doors are loaded. It is ensured before us, so it usually
-- fires before our houses are loaded (or before we even start): run once both are ready.
local readySeen, readyRan = false, false
local function runWhenLoaded()
    CreateThread(function()
        while not S.ready do Wait(500) end
        if readyRan then return end
        readyRan = true
        onDoorlocksReady()
    end)
end

AddEventHandler('pup-doorlocks:Ready', function()
    readySeen = true
    readyRan = false -- a doorlocks restart reloads its doors: sync again
    runWhenLoaded()
end)

-- called by boot once houses are loaded: if doorlocks finished loading before we started,
-- its Ready event was missed, so give it a grace period and then run anyway
function S.bridgeBoot()
    CreateThread(function()
        if GetResourceState(Config.Doorlocks.resource) ~= 'started' then return end
        local waited = 0
        while not readySeen and waited < 15000 do
            Wait(1000)
            waited = waited + 1000
        end
        if not readySeen then runWhenLoaded() end
    end)
end
