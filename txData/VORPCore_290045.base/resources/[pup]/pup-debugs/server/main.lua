-- no per-event console output: log file and webhook only

local tracked = {}        -- src -> join record + last client beacon
local starts = {}         -- resource -> { timestamps } for restart storms
local MAX_LOG_LINES <const> = 2000

local srvLoad = {            -- rolling server-lag figures
    worst = 0, stalls = 0, samples = 0, total = 0, since = os.time(),
}

-- ------------------------------------------------------------------ helpers
local function hms(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return ("%dm %ds"):format(math.floor(sec / 60), sec % 60)
end

local function appendFile(file, line)
    if not Config.General.writeLogFiles then return end
    local existing = LoadResourceFile(GetCurrentResourceName(), file) or ""
    local lines = {}
    for l in existing:gmatch("[^\r\n]+") do lines[#lines + 1] = l end
    lines[#lines + 1] = ("[%s] %s"):format(os.date("%Y-%m-%d %H:%M:%S"), line)
    while #lines > MAX_LOG_LINES do table.remove(lines, 1) end
    SaveResourceFile(GetCurrentResourceName(), file, table.concat(lines, "\n") .. "\n", -1)
end

local function post(url, title, colour, fields)
    if not url or url == "" then return end
    PerformHttpRequest(url, function() end, "POST", json.encode({
        username = "pup-debugs",
        embeds = { { title = title, color = colour, fields = fields,
                     footer = { text = os.date("%Y-%m-%d %H:%M:%S") } } },
    }), { ["Content-Type"] = "application/json" })
end

local function identifiers(src)
    local out = { license = "?", steam = "?", discord = "?", fivem = "?" }
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local k, v = id:match("^(%w+):(.+)$")
        if k and out[k] ~= nil then out[k] = v end
    end
    return out
end

-- ======================================================== 1. SERVER LOAD
-- a thread wakes every TickInterval; how late it wakes is how far behind the server is
CreateThread(function()
    local last = GetGameTimer()
    while true do
        Wait(Config.ServerLoad.tickIntervalMs)
        local now = GetGameTimer()
        local over = (now - last) - Config.ServerLoad.tickIntervalMs
        last = now

        srvLoad.samples = srvLoad.samples + 1
        srvLoad.total = srvLoad.total + math.max(0, over)
        if over > srvLoad.worst then srvLoad.worst = over end

        if over >= Config.ServerLoad.warnMs then
            srvLoad.stalls = srvLoad.stalls + 1
            appendFile(Config.General.serverLogFile,
                ("STALL %dms behind | %d players"):format(over, #GetPlayers()))
            if over >= Config.ServerLoad.alertMs then
                post(Secrets.Webhooks.load, "Server stalled", 15158332, {
                    { name = "Behind by", value = over .. " ms", inline = true },
                    { name = "Players", value = tostring(#GetPlayers()), inline = true },
                })
            end
        end
    end
end)

-- rolling summary so the log shows a trend, not only the spikes
CreateThread(function()
    while true do
        Wait(Config.ServerLoad.reportSeconds * 1000)
        if srvLoad.samples > 0 then
            appendFile(Config.General.serverLogFile, ("load: avg %.1fms behind | worst %dms | %d stalls over %s | %d players")
                :format(srvLoad.total / srvLoad.samples, srvLoad.worst, srvLoad.stalls,
                    hms(os.time() - srvLoad.since), #GetPlayers()))
        end
        srvLoad.worst, srvLoad.stalls, srvLoad.samples, srvLoad.total, srvLoad.since = 0, 0, 0, 0, os.time()
    end
end)

-- ==================================================== 2. RESOURCE WATCH
local function allResources()
    local out = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then out[#out + 1] = { name = name, state = GetResourceState(name) } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

if Config.Resources.enabled then
    AddEventHandler("onResourceStart", function(name)
        local t = starts[name] or {}
        t[#t + 1] = os.time()
        -- keep only what is inside the storm window
        local cut = os.time() - Config.Resources.stormWindowSeconds
        local keep = {}
        for _, ts in ipairs(t) do if ts >= cut then keep[#keep + 1] = ts end end
        starts[name] = keep

        appendFile(Config.General.serverLogFile, ("resource START %s (%d in the last %ds)")
            :format(name, #keep, Config.Resources.stormWindowSeconds))

        if #keep >= Config.Resources.stormCount then
            post(Secrets.Webhooks.load, "Resource restart storm", 15158332, {
                { name = "Resource", value = name, inline = true },
                { name = "Restarts", value = ("%d in %ds"):format(#keep, Config.Resources.stormWindowSeconds), inline = true },
                { name = "Why it matters", value = "A resource restarting in a loop is usually erroring on start, and each restart stalls the server.", inline = false },
            })
        end
    end)

    AddEventHandler("onResourceStop", function(name)
        appendFile(Config.General.serverLogFile, "resource STOP " .. name)
    end)
end

-- ============================================================= 3. DROPS
local function track(src)
    if tracked[src] then return tracked[src] end
    tracked[src] = {
        joined = os.time(), name = GetPlayerName(src) or "unknown",
        ids = identifiers(src), beacon = nil, beaconAt = nil, charSelected = false,
    }
    return tracked[src]
end

AddEventHandler("playerJoining", function() track(source) end)

-- beacons go to the log and Discord, so only whole numbers and a short stage name are kept
local BEACON_NUMBERS <const> = { "x", "y", "z", "coll", "scene", "int", "net", "faded", "hitch", "hitches", "tick" }

local function cleanBeacon(data)
    local out = { stage = tostring(data.stage or "?"):gsub("[^%w_%- ]", ""):sub(1, 32) }
    for _, k in ipairs(BEACON_NUMBERS) do
        local v = tonumber(data[k])
        if v and v == v and math.abs(v) < 1e9 then out[k] = math.floor(v) end -- also what %d can print
    end
    return out
end

RegisterNetEvent("pup-debugs:beacon", function(data)
    if type(data) ~= "table" then return end
    local t = track(source)
    t.beacon, t.beaconAt = cleanBeacon(data), os.time()
end)

AddEventHandler("vorp:SelectedCharacter", function(src)
    local t = tracked[src]
    if t then t.charSelected = true end
end)

-- "stuck on streaming" reads straight off the flags the client sent
local function verdict(t, reason)
    local r = tostring(reason)
    local low = r:lower()
    local b = t.beacon

    -- a crash is not a clean leave: the faulting module points at memory or at a resource dll
    local crashMod = r:match("[Gg]ame crashed:%s*(.+)")
    if crashMod then
        local note = ""
        if b and b.hitch and b.hitch > 0 then
            note = (" - was hitching %dms before it went"):format(b.hitch)
        end
        return ("CRASH in %s at stage '%s'%s"):format(crashMod, tostring(b and b.stage or "unknown"), note)
    end

    local timedOut = low:find("timed out") ~= nil
    if not timedOut then return "clean leave or kick" end
    if not b then
        -- no beacon after a long session: the client was still joining or downloading
        local secs = os.time() - t.joined
        if secs > 60 then
            return ("TIMEOUT after %s and the client NEVER started its scripts - stuck joining or downloading")
                :format(hms(secs))
        end
        return "TIMEOUT - client never reported in at all"
    end
    if b.stage == "ingame" then return "TIMEOUT while playing - not a join problem" end

    local missing = {}
    if b.coll == 0 then missing[#missing + 1] = "collision" end
    if b.int == 0 then missing[#missing + 1] = "interior" end
    if b.scene == 0 then missing[#missing + 1] = "loadscene" end
    if b.net == 0 then missing[#missing + 1] = "network-player" end
    local miss = #missing > 0 and (" - never streamed: " .. table.concat(missing, ", ")) or ""

    if b.hitch and b.hitch > 0 then
        return ("TIMEOUT after a %dms FREEZE at stage '%s'%s"):format(b.hitch, tostring(b.stage), miss)
    end
    if #missing > 0 then
        return ("TIMEOUT at stage '%s'%s"):format(tostring(b.stage), miss)
    end
    return ("TIMEOUT at stage '%s' - everything had loaded, look at their connection"):format(tostring(b.stage))
end

AddEventHandler("playerDropped", function(reason)
    local src = source
    local t = tracked[src]
    tracked[src] = nil
    if not t then return end
    if Config.Drops.onlyPreSession and t.charSelected then return end

    local v = verdict(t, reason)
    local b = t.beacon or {}
    appendFile(Config.General.dropLogFile, ("%s (src %s) | session %s | char %s | stage %s | last heard %ss ago | freeze %sms x%s | clienttick %sms | coll=%s int=%s scene=%s net=%s faded=%s | pos %s,%s,%s | license %s | discord %s | reason: %s | %s")
        :format(t.name, src, hms(os.time() - t.joined), t.charSelected and "yes" or "NONE",
            b.stage or "-", t.beaconAt and (os.time() - t.beaconAt) or "-",
            b.hitch or 0, b.hitches or 0, b.tick or "-",
            b.coll or "-", b.int or "-", b.scene or "-", b.net or "-", b.faded or "-",
            b.x or "-", b.y or "-", b.z or "-", t.ids.license, t.ids.discord, tostring(reason), v))

    post(Secrets.Webhooks.drops, "Player dropped before entering the world",
        v:find("TIMEOUT") and 15158332 or 9807270, {
        { name = "Player", value = ("%s\nDiscord: <@%s>"):format(t.name, t.ids.discord), inline = true },
        { name = "Session", value = hms(os.time() - t.joined), inline = true },
        { name = "Character", value = t.charSelected and "selected" or "**none selected**", inline = true },
        { name = "Stage", value = tostring(b.stage or "no beacon"), inline = true },
        { name = "Last heard", value = t.beaconAt and (hms(os.time() - t.beaconAt) .. " before the drop") or "never", inline = true },
        { name = "Worst freeze", value = (b.hitch and b.hitch > 0) and (b.hitch .. " ms (" .. (b.hitches or 0) .. " hitches)") or "none seen", inline = true },
        { name = "Streaming", value = ("collision %s | interior %s | loadscene %s | net %s | faded %s"):format(
            b.coll == 1 and "ok" or "NO", b.int == 1 and "ok" or "NO", b.scene == 1 and "ok" or "NO",
            b.net == 1 and "ok" or "NO", b.faded == 1 and "yes" or "no"), inline = false },
        { name = "Position", value = ("%s, %s, %s"):format(b.x or "?", b.y or "?", b.z or "?"), inline = true },
        { name = "License", value = t.ids.license, inline = false },
        { name = "Reason", value = tostring(reason), inline = false },
        { name = "Verdict", value = v, inline = false },
    })
end)

-- ================================================= 3b. INSTANCED PLAYER
-- the client confirmed it has no networked ped here; logged like a drop
local lastSyncReport = {}
AddEventHandler("playerDropped", function() lastSyncReport[source] = nil end)

local function shortText(v)
    return tostring(v):gsub("[^%w_%- ]", ""):sub(1, 40)
end

RegisterNetEvent("pup-debugs:syncFailed", function(charId, clientNet, serverNet, signature)
    local src <const> = source
    -- the real client says this once. Each report rewrites the log file and posts to staff.
    local nowMs <const> = GetGameTimer()
    if lastSyncReport[src] and nowMs - lastSyncReport[src] < 60000 then return end
    lastSyncReport[src] = nowMs
    charId, clientNet, serverNet, signature = shortText(charId), shortText(clientNet), shortText(serverNet), shortText(signature)
    local ids <const> = identifiers(src)
    local name <const> = GetPlayerName(src) or "?"

    appendFile(Config.General.dropLogFile, ("INSTANCED | %s (src %s) | char %s | clientNet %s | serverNet %s | %s | license %s | discord %s")
        :format(name, src, tostring(charId), tostring(clientNet), tostring(serverNet),
            tostring(signature), ids.license, ids.discord))

    post(Secrets.Webhooks.drops, "Player is instanced", 15158332, {
        { name = "Player", value = ("%s\nDiscord: <@%s>"):format(name, ids.discord), inline = true },
        { name = "Character", value = tostring(charId), inline = true },
        { name = "Signature", value = tostring(signature), inline = true },
        { name = "Net id", value = ("client %s | server %s"):format(tostring(clientNet), tostring(serverNet)), inline = false },
        { name = "License", value = ids.license, inline = false },
    })
end)

-- =========================================================== 4. COMMAND
local function out(lines) print(table.concat(lines, "\n")) end

-- restricted: Cfx refuses it without command.pupdebug; the ace check is a second gate
RegisterCommand("pupdebug", function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, "command.pupdebug") then return end
    local what = (args[1] or "help"):lower()

    if what == "load" then
        local avg = srvLoad.samples > 0 and (srvLoad.total / srvLoad.samples) or 0
        out({ "^3[pup-debugs]^7 server load",
            ("  avg %.1fms behind | worst %dms | %d stalls in the last %s")
                :format(avg, srvLoad.worst, srvLoad.stalls, hms(os.time() - srvLoad.since)),
            ("  %d players online"):format(#GetPlayers()),
            "  a stall is the scheduler waking late - it does NOT say which resource did it, use 'profile'" })

    elseif what == "resources" then
        local list, bad = allResources(), {}
        for _, r in ipairs(list) do
            if r.state ~= "started" then bad[#bad + 1] = ("  %-34s %s"):format(r.name, r.state) end
        end
        local lines = { ("^3[pup-debugs]^7 %d resources, %d not started:"):format(#list, #bad) }
        for _, l in ipairs(bad) do lines[#lines + 1] = l end
        if #bad == 0 then lines[#lines + 1] = "  all started" end
        lines[#lines + 1] = "^3restarts in the storm window:^7"
        local any = false
        for name, ts in pairs(starts) do
            if #ts > 1 then
                any = true
                lines[#lines + 1] = ("  %-34s %d"):format(name, #ts)
            end
        end
        if not any then lines[#lines + 1] = "  none" end
        out(lines)

    elseif what == "joins" then
        local lines = { "^3[pup-debugs]^7 players not yet in the world:" }
        local n = 0
        for id, t in pairs(tracked) do
            if not t.charSelected then
                n = n + 1
                local b = t.beacon or {}
                lines[#lines + 1] = ("  %s (src %s) | %s | stage %s | last heard %ss | freeze %sms | coll=%s int=%s scene=%s")
                    :format(t.name, id, hms(os.time() - t.joined), b.stage or "-",
                        t.beaconAt and (os.time() - t.beaconAt) or "-", b.hitch or 0,
                        b.coll or "-", b.int or "-", b.scene or "-")
            end
        end
        if n == 0 then lines[#lines + 1] = "  none" end
        out(lines)

    elseif what == "profile" then
        -- per-resource timings are not exposed to server Lua; the profile lands next to run.bat
        local frames = tonumber(args[2]) or 500
        out({ ("^3[pup-debugs]^7 recording %d frames..."):format(frames) })
        ExecuteCommand(("profiler record %d"):format(frames))
        SetTimeout(10000, function()
            ExecuteCommand("profiler saveJSON pup-debugs-profile.json")
            print("^3[pup-debugs]^7 saved pup-debugs-profile.json next to run.bat - open it in Chrome DevTools (Performance > Load profile)")
        end)

    elseif what == "resmon" then
        -- svgui: the built-in per-resource monitor on Windows servers
        out({ "^3[pup-debugs]^7 opening the server GUI - Tools > Resource Monitor > Time%",
              "  shows CPU ms and memory per resource, live. Windows only." })
        ExecuteCommand("svgui")

    else
        out({ "^3[pup-debugs]^7 commands:",
            "  /pupdebug load        how far behind the server scheduler is",
            "  /pupdebug resources   anything not started, plus restart storms",
            "  /pupdebug joins       players stuck short of the world, live",
            "  /pupdebug resmon      server GUI resource monitor, live per-resource ms (Windows)",
            "  /pupdebug profile [n] record n frames to a JSON profile (default 500)" })
    end
end, true)

CreateThread(function()
    Wait(5000)
    local list, bad = allResources(), 0
    for _, r in ipairs(list) do if r.state ~= "started" then bad = bad + 1 end end
    print(("^2[pup-debugs]^7 watching %d resources (%d not started), joins and server load - /pupdebug for a look")
        :format(#list, bad))
end)
