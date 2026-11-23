-- pup-misc / scene - server

local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)

-- [serverId] = status text, for /status. Lives in memory only: a status is a
-- moment-to-moment thing and should not survive a relog.
local statuses = {}

local MAX_TEXT <const> = SceneConfig.Limits.maxTextLength or 200
                               -- hard cap; the DB column is longtext but a 3D label of unbounded length is a grief vector

-- [serverId] = last accepted preview push, for rate limiting the ghost relay
local previewGate = {}

-- helpers

local function getChar(src)
    local user = VorpCore.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

-- one action per this many ms, per player and per kind
local gates = {}
local function tooSoon(src, kind, ms)
    local now = GetGameTimer()
    gates[src] = gates[src] or {}
    if gates[src][kind] and now - gates[src][kind] < ms then return true end
    gates[src][kind] = now
    return false
end

local function clean(text)
    if type(text) ~= "string" then return nil end
    -- nothing real is this long, and the patterns below get slow on huge text
    if #text > MAX_TEXT * 8 + 256 then return nil end
    -- Strip every raw game text token FIRST
    text = SceneMarkupSanitise(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    -- the cap counts characters, not bytes: decorative symbols are 3 bytes each and a byte cut would split one
    local n = utf8.len(text)
    if not n then return nil end
    if n > MAX_TEXT then text = text:sub(1, utf8.offset(text, MAX_TEXT + 1) - 1) end
    return text
end

local function hasJob(job, list)
    if type(list) ~= "table" then return false end
    for _, v in pairs(list) do
        if v == job then return true end
    end
    return false
end

-- staff override: the admin group plus roles holding every permission (opening the admin
-- panel alone does not allow writing on the map)
local function isSceneAdmin(src)
    local user = VorpCore.getUser(src)
    local group = user and user.getGroup
    if group == "admin" or group == "superadmin" then return true end
    local ok, allowed = pcall(function() return exports.vorp_admin:allowedToExecuteAction(src, "manage_scenes") end)
    return ok and allowed == true
end

-- Can this character place / remove scenes at all?
local function sceneAccess(Character, src)
    if src and isSceneAdmin(src) then return true, true end
    local canPlace = (not SceneConfig.Access.jobLock) or hasJob(Character.job, SceneConfig.Access.allowJobs)
    -- removejobs clears anyone's scenes, so they keep the removal mode even when they are not allowed to place
    local canRemove = canPlace or hasJob(Character.job, SceneConfig.Access.removeJobs)
    return canPlace, canRemove
end

local function pushAccess(src)
    local Character = getChar(src)
    if not Character then return end
    local canPlace, canRemove = sceneAccess(Character, src)
    TriggerClientEvent("pup-scene:setAccess", src, canPlace, canRemove)
end

RegisterServerEvent("pup-scene:requestAccess")
AddEventHandler("pup-scene:requestAccess", function()
    pushAccess(source)
end)

-- job can change mid-session, so re-send on character select too
AddEventHandler("vorp:SelectedCharacter", function(src)
    SetTimeout(2000, function() pushAccess(src) end)
end)

-- Everyone within range of `src`, worked out here rather than trusting the list the client sent
local function nearby(src, radius)
    local out = {}
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return out end
    local origin = GetEntityCoords(ped)

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target then
            local tped = GetPlayerPed(target)
            if tped and tped ~= 0 then
                if #(origin - GetEntityCoords(tped)) <= radius then
                    out[#out + 1] = target
                end
            end
        end
    end
    return out
end

local function statusList()
    local out = {}
    for id, text in pairs(statuses) do
        out[#out + 1] = { id = id, texts = text }
    end
    return out
end

local function pushStatuses()
    TriggerClientEvent("pup-scene:triggerDisplay2", -1, statusList())
end

-- style: the client can send anything, so nothing it sends is stored as given

local function clampNum(v, lo, hi, fallback)
    local n = tonumber(v)
    if not n then return fallback end
    if n ~= n then return fallback end -- NaN
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function sanitizeStyle(s)
    if type(s) ~= "table" then s = {} end
    local L <const> = SceneConfig.Limits

    -- accent must be a key we actually know; anything else becomes no accent
    local accent = tostring(s.accent or ""):lower()
    if accent ~= "" and not SceneConfig.Styles.inlineColours[accent] then accent = "" end

    local pattern = tostring(s.pattern or "none")
    local known = false
    for _, p in ipairs(SceneConfig.Styles.patterns) do
        if p.id == pattern then known = true break end
    end
    if not known then pattern = "none" end

    return {
        r       = math.floor(clampNum(s.r, 0, 255, 255)),
        g       = math.floor(clampNum(s.g, 0, 255, 255)),
        b       = math.floor(clampNum(s.b, 0, 255, 255)),
        scale   = clampNum(s.scale, L.minScale, L.maxScale, 0.30),
        font    = math.floor(clampNum(s.font, 0, 9, 1)),
        back    = clampNum(s.back, 0.0, 1.0, 0.0),
        range   = clampNum(s.range, 1.0, L.maxRange, SceneConfig.Display.defaultRange + 0.0),
        accent  = accent,
        pattern = pattern,
    }
end

local function logWebhook(title, description)
    local url = Secrets.Webhooks and Secrets.Webhooks.scene and Secrets.Webhooks.scene.log
    if not url or url == "" then return end
    PerformHttpRequest(url, function() end, "POST", json.encode({
        embeds = { { title = title, description = description, color = 3066993 } },
    }), { ["Content-Type"] = "application/json" })
end

-- scenes

-- the `style` column is added here so an existing install picks it up on the next restart
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await("ALTER TABLE `playerscenes` ADD COLUMN IF NOT EXISTS `style` longtext DEFAULT NULL", {})
    end)
    if not ok then
        print(("[pup-scene] could not add the `style` column: %s\n" ..
            "  Scenes will still work, they will all render in the default style."):format(tostring(err)))
    end
end)

local function fetchScenes()
    local rows = MySQL.query.await("SELECT id, charid, coords, text, style FROM playerscenes", {})
    local out = {}
    for _, r in ipairs(rows or {}) do
        local ok, coords = pcall(json.decode, r.coords or "{}")
        -- a row with unreadable coords would crash the client's distance check, so it is skipped rather than sent
        if ok and type(coords) == "table" and coords.x and coords.y and coords.z then
            -- a scene saved before styling existed has style NULL; sanitizeStyle turns that into the defaults
            local style
            if r.style then
                local sok, decoded = pcall(json.decode, r.style)
                if sok then style = decoded end
            end

            out[#out + 1] = {
                id     = r.id,
                charid = r.charid,
                coords = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
                text   = r.text or "",
                style  = sanitizeStyle(style),
            }
        end
    end
    return out
end

RegisterServerEvent("pup-scene:pullscenes")
-- every client pulls at once after a change, so they share one read
local scenesCache, scenesCacheUntil = nil, 0
local function cachedScenes()
    local now = GetGameTimer()
    if not scenesCache or now >= scenesCacheUntil then
        scenesCache = fetchScenes()
        scenesCacheUntil = now + 5000
    end
    return scenesCache
end

AddEventHandler("pup-scene:pullscenes", function(_state, _x)
    local src = source
    TriggerClientEvent("pup-scene:getscenes", src, cachedScenes())
end)

RegisterServerEvent("pup-scene:savescene")
AddEventHandler("pup-scene:savescene", function(coords, text, style)
    local src = source
    local Character = getChar(src)
    if not Character then return end

    -- the /scene command has no job check client-side, so this is the only gate
    if SceneConfig.Access.jobLock and not hasJob(Character.job, SceneConfig.Access.allowJobs) and not isSceneAdmin(src) then
        return VorpCore.NotifyRightTip(src, SceneLocale.notjob, 4000)
    end

    if type(coords) ~= "table" or not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then return end
    local body = clean(text)
    if not body then return end
    if tooSoon(src, 'save', 1000) then return end

    -- trust the SERVER's idea of where the player is: the coords come from the client's placement UI
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local here = GetEntityCoords(ped)
        local there = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
        if #(here - there) > (SceneConfig.Limits.maxPlaceDistance or 25.0) then
            print(("[pup-scene] %s (%s) tried to place a scene %.1fm away - rejected")
                :format(GetPlayerName(src), src, #(here - there)))
            return VorpCore.NotifyRightTip(src, SceneLocale.toofar, 4000)
        end
    end

    local cap = tonumber(SceneConfig.Limits.maxScenesPerChar) or 0
    if cap > 0 then
        local rows = MySQL.query.await("SELECT COUNT(*) AS n FROM playerscenes WHERE charid = ?",
            { Character.charIdentifier })
        local have = (rows and rows[1] and tonumber(rows[1].n)) or 0
        if have >= cap then
            return VorpCore.NotifyRightTip(src, (SceneLocale.toomanyscenes):format(cap), 5000)
        end
    end

    MySQL.insert.await(
        "INSERT INTO playerscenes (charid, coords, text, style) VALUES (?, ?, ?, ?)",
        { Character.charIdentifier,
          json.encode({ x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }),
          body,
          json.encode(sanitizeStyle(style)) })

    scenesCache = nil
    -- whatever they were placing is now real; drop the ghost for everyone
    TriggerClientEvent("pup-scene:previewEnd", -1, src)

    VorpCore.NotifyRightTip(src, SceneLocale.scenereg, 4000)
    logWebhook("Scene placed", ("**%s %s** (char %s)\n%s"):format(
        Character.firstname or "", Character.lastname or "", Character.charIdentifier, body))

    -- everyone re-pulls; the client already listens for this
    TriggerClientEvent("pup-scene:getscenes2", -1)
end)

RegisterServerEvent("pup-scene:removescene")
AddEventHandler("pup-scene:removescene", function(id, charid, _players)
    local src = source
    local Character = getChar(src)
    if not Character then return end

    id = tonumber(id)
    if not id then return end

    -- Owner comes from the DATABASE, not from the client
    local row = MySQL.query.await("SELECT charid FROM playerscenes WHERE id = ? LIMIT 1", { id })
    if not row or not row[1] then return end

    local owner = tonumber(row[1].charid)
    local mine = owner ~= nil and owner == Character.charIdentifier
    if not mine and not hasJob(Character.job, SceneConfig.Access.removeJobs) and not isSceneAdmin(src) then
        return VorpCore.NotifyRightTip(src, SceneLocale.notjob, 4000)
    end

    MySQL.query.await("DELETE FROM playerscenes WHERE id = ?", { id })
    scenesCache = nil
    VorpCore.NotifyRightTip(src, SceneLocale.sceneremoved, 4000)
    TriggerClientEvent("pup-scene:getscenes2", -1)
end)

-- live placement preview ("ghost") - while a player is positioning a scene

RegisterServerEvent("pup-scene:preview")
AddEventHandler("pup-scene:preview", function(x, y, z, text, style)
    local src = source
    local previewer = getChar(src)
    if not previewer then return end
    -- same gate as placing one
    if SceneConfig.Access.jobLock and not hasJob(previewer.job, SceneConfig.Access.allowJobs) and not isSceneAdmin(src) then return end

    local hz <const> = math.max(1, tonumber(SceneConfig.Place.previewHz) or 6)
    local minGap <const> = math.floor(1000 / hz) - 5 -- small slack for frame jitter
    local now <const> = GetGameTimer()
    if previewGate[src] and (now - previewGate[src]) < minGap then return end
    previewGate[src] = now

    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end

    local body = clean(text)
    if not body then return end

    -- same anti-reach rule as an actual placement, so the ghost can never be used to paint text across the map
    local ped <const> = GetPlayerPed(src)
    if ped and ped ~= 0 then
        if #(GetEntityCoords(ped) - vector3(x + 0.0, y + 0.0, z + 0.0)) > (SceneConfig.Limits.maxPlaceDistance or 25.0) then
            return
        end
    end

    local clean_style <const> = sanitizeStyle(style)
    for _, target in ipairs(nearby(src, SceneConfig.Place.previewRange or 30.0)) do
        if target ~= src then
            TriggerClientEvent("pup-scene:previewFrom", target, src, x, y, z, body, clean_style)
        end
    end
end)

local function clearPreview(src)
    previewGate[src] = nil
    TriggerClientEvent("pup-scene:previewEnd", -1, src)
end

RegisterServerEvent("pup-scene:previewEnd")
AddEventHandler("pup-scene:previewEnd", function()
    clearPreview(source)
end)

-- /me /ooc /id /cash

local function share(src, text, radius)
    local body = clean(text)
    if not body then return end
    for _, target in ipairs(nearby(src, radius or 20.0)) do
        TriggerClientEvent("pup-scene:triggerDisplay", target, body, src)
    end
end

RegisterServerEvent("pup-scene:shareDisplay")
AddEventHandler("pup-scene:shareDisplay", function(text, _players)
    if tooSoon(source, 'share', 500) then return end
    share(source, text)
end)

-- /cash: the AMOUNT is added here
RegisterServerEvent("pup-scene:shareDisplay3")
AddEventHandler("pup-scene:shareDisplay3", function(text, _players)
    local src = source
    local Character = getChar(src)
    if not Character then return end
    if tooSoon(src, 'share', 500) then return end
    local label = clean(text) or SceneLocale.cash
    share(src, ("%s%.2f"):format(label, tonumber(Character.money) or 0))
end)

-- /status /cstatus KNOCKED OUT - a separate channel from /status so the two never fight
local kos = {} -- [serverId] = true

local function koList()
    local out = {}
    for id in pairs(kos) do out[#out + 1] = id end
    return out
end

local function pushKOs(target)
    TriggerClientEvent("pup-scene:koList", target or -1, koList())
end

-- client/knockout fires this
RegisterServerEvent("pup-scene:setKO")
AddEventHandler("pup-scene:setKO", function(state)
    local src = source
    if not getChar(src) then return end
    local want = state and true or nil
    if kos[src] == want then return end -- the KO loop fires every frame; only broadcast on CHANGE
    if tooSoon(src, 'ko', 250) then return end
    kos[src] = want
    pushKOs()
end)

RegisterServerEvent("pup-scene:getstatus")
AddEventHandler("pup-scene:getstatus", function()
    TriggerClientEvent("pup-scene:triggerDisplay2", source, statusList())
    pushKOs(source) -- a joiner should see anyone already on the floor
end)

RegisterServerEvent("pup-scene:shareDisplay2")
AddEventHandler("pup-scene:shareDisplay2", function(text, _players)
    local src = source
    if not getChar(src) then return end
    local body = clean(text)
    if not body then return end
    if tooSoon(src, 'status', 250) then return end
    statuses[src] = body
    pushStatuses()
end)

RegisterServerEvent("pup-scene:stopdisplay")
AddEventHandler("pup-scene:stopdisplay", function(_players)
    local src = source
    if statuses[src] == nil then return end
    if tooSoon(src, 'status', 250) then return end
    statuses[src] = nil
    pushStatuses()
end)

-- a status belongs to a session: clear it when they leave, or the label would hang on whoever inherits that server id next
AddEventHandler("playerDropped", function()
    local src = source
    gates[src] = nil
    if statuses[src] ~= nil then
        statuses[src] = nil
        pushStatuses()
    end
    -- a player who logs out while knocked out would otherwise leave the label floating over whoever inherits that server id
    if kos[src] ~= nil then
        kos[src] = nil
        pushKOs()
    end
    -- drop a ghost left by someone who disconnects mid-placement
    clearPreview(src)
end)
