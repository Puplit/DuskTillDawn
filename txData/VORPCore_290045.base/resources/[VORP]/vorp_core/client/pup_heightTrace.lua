-- Modified by Puppet (Dusk Till Dawn), 2026
-- HEIGHT TRACE. Observes SetPedScale calls on a player and never changes one.
-- OFF unless `setr pup_height_trace 1` is in server.cfg, because it prints per call.
-- To audit another resource, add this line FIRST in its client_scripts:
--     client_script '@vorp_core/client/pup_heightTrace.lua'

if IsDuplicityVersion() then return end
if PupHeightTraceInstalled then return end
if GetConvar('pup_height_trace', '0') ~= '1' then return end
PupHeightTraceInstalled = true

local SCALE_HASH <const> = 0x25ACFC650B65C538
local resource <const> = GetCurrentResourceName()
local nested, sequence = 0, 0
local rawInvoke = Citizen.InvokeNative
local rawGlobalInvoke = rawget(_G, 'InvokeNative')
local rawSetScale = SetPedScale

-- a diagnostic must never be the reason a real call failed
local function safe(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function isPlayerTarget(ped)
    if type(ped) ~= 'number' or ped == 0 then return true end -- keep invalid attempts
    if ped == safe(PlayerPedId) then return true end
    local player = safe(IsPedAPlayer, ped)
    return player == true or player == 1
end

-- up to four frames of whoever asked, so the line names the caller not this file
local function callSites()
    if not debug or type(debug.getinfo) ~= 'function' then return 'unavailable' end
    local sites = {}
    for level = 2, 9 do
        local info = debug.getinfo(level, 'Sl')
        if not info then break end
        local source = info.source or '?'
        if info.what ~= 'C' and not source:find('pup_heightTrace', 1, true) then
            sites[#sites + 1] = source .. ':' .. tostring(info.currentline)
            if #sites == 4 then break end
        end
    end
    return #sites > 0 and table.concat(sites, ' <- ') or 'unavailable'
end

-- GetPedScale is unavailable on some builds and returns raw bits on others
local function readScale(ped)
    local value = safe(GetPedScale, ped)
    if type(value) == 'number' and value > 0 and value <= 10 then return value end
    return 'unavailable'
end

local function report(api, ped, scale, before)
    sequence = sequence + 1
    local plyIdx = safe(NetworkGetPlayerIndexFromPed, ped)
    local sid = (type(plyIdx) == 'number' and plyIdx >= 0) and safe(GetPlayerServerId, plyIdx) or nil
    print(('^5[htrace %d]^7 %s res=%s api=%s ped=%s sid=%s mine=%s asked=%s before=%s after=%s  %s')
        :format(sequence, safe(GetGameTimer) or 0, resource, api, tostring(ped), tostring(sid),
            tostring(ped == safe(PlayerPedId)), tostring(scale), tostring(before), tostring(readScale(ped)),
            callSites()))
end

local function traced(original, api, ped, scale, ...)
    local before = safe(readScale, ped)
    nested = nested + 1
    local results = table.pack(pcall(original, ...))
    nested = nested - 1
    safe(report, api, ped, scale, before)
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end

local function wrapInvoke(original, api)
    return function(hash, ...)
        if nested > 0 or hash ~= SCALE_HASH then return original(hash, ...) end
        local ped, scale = ...
        if not safe(isPlayerTarget, ped) then return original(hash, ...) end
        return traced(original, api, ped, scale, hash, ...)
    end
end

Citizen.InvokeNative = wrapInvoke(rawInvoke, 'Citizen.InvokeNative')
if type(rawGlobalInvoke) == 'function' then
    InvokeNative = wrapInvoke(rawGlobalInvoke, 'InvokeNative')
end
if type(rawSetScale) == 'function' then
    SetPedScale = function(ped, scale, ...)
        if nested > 0 or not safe(isPlayerTarget, ped) then return rawSetScale(ped, scale, ...) end
        return traced(rawSetScale, 'SetPedScale', ped, scale, ped, scale, ...)
    end
end

print(('^5[htrace]^7 armed in %s'):format(resource))
