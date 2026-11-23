-- Client basics: core, the one request helper, notifications and per-character preferences.
Core = exports.vorp_core:GetCore()

OWNER = 'pup_workbench'

--- Ask the server. Returns the answer, or nil when it refused or failed.
function Req(kind, payload)
    local ok, res = pcall(function()
        return Core.Callback.TriggerAwait('pup_workbench:req', kind, payload)
    end)
    if ok then return res end
    return nil
end

function Notify(text, ms)
    TriggerEvent('vorp:TipRight', tostring(text or ''), ms or 4000)
end

-- PREFERENCES AND RECENT DESCRIPTIONS, stored in client KVP per character
Prefs = {
    charid = nil,
    data = { automax = false, reopen = false, amount = 1, desc = '' },
    saved = {},
}

local function suffix()
    return Prefs.charid and tostring(Prefs.charid) or 'none'
end

local function readJson(key)
    local raw = GetResourceKvpString(key)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, dec = pcall(json.decode, raw)
    if ok and type(dec) == 'table' then return dec end
    return nil
end

local function cleanList(list)
    local out, seen = {}, {}
    if type(list) ~= 'table' then return out end
    for _, s in ipairs(list) do
        if type(s) == 'string' then
            local t = WB.trim(s)
            if t ~= '' and not seen[t] then
                seen[t] = true
                out[#out + 1] = WB.cut(t, Config.Descriptions.maxLength)
                if #out >= Config.Descriptions.recentKept then break end
            end
        end
    end
    return out
end

function Prefs.load()
    local p = readJson('pupcraft_prefs_' .. suffix()) or {}
    Prefs.data = {
        automax = p.automax == true,
        reopen = p.reopen == true,
        amount = math.max(1, WB.int(p.amount) or 1),
        desc = type(p.desc) == 'string' and p.desc or '',
    }
    Prefs.saved = cleanList(readJson('pupcraft_saved_' .. suffix()))
end

function Prefs.save()
    SetResourceKvp('pupcraft_prefs_' .. suffix(), json.encode(Prefs.data))
end

function Prefs.saveRecent()
    SetResourceKvp('pupcraft_saved_' .. suffix(), json.encode(Prefs.saved))
end

--- Push a description to the front of the recent list.
function Prefs.remember(desc)
    if type(desc) ~= 'string' then return end
    desc = WB.trim(desc)
    if desc == '' then return end
    local list = { desc }
    for _, s in ipairs(Prefs.saved) do list[#list + 1] = s end
    Prefs.saved = cleanList(list)
    Prefs.saveRecent()
end

exports('GetSavedDescriptions', function()
    local copy = {}
    for i, s in ipairs(Prefs.saved) do copy[i] = s end
    return copy
end)

exports('RememberDescription', function(desc)
    Prefs.remember(desc)
end)

-- vorp_inventory's description card sends its edited list back here
AddEventHandler('pup_inventory:savedDescriptions', function(list)
    Prefs.saved = cleanList(list)
    Prefs.saveRecent()
end)

Prefs.load()
