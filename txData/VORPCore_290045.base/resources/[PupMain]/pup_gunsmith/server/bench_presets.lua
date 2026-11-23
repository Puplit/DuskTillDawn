-- pup_gunsmith | bench presets: named looks per character and weapon model

BenchPresets = {}

local NAME_MAX <const> = 32

function BenchPresets.list(charId, weaponName)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, name, comps FROM gunsmith_presets WHERE charid = ? AND weapon = ? ORDER BY name',
        { charId, tostring(weaponName):upper() })
    local out = {}
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            out[#out + 1] = {
                id = r.id,
                name = r.name,
                parts = GS.cleanParts(Srv.decode(r.comps, {}), Config.Bench.maxParts),
            }
        end
    end
    return out
end

local function cleanName(name)
    if type(name) ~= 'string' then return '' end
    name = GS.cleanText(name, true)
    name = name:gsub('%s+', ' ')
    name = GS.trim(name)
    return GS.trim(GS.cut(name, NAME_MAX))
end

Srv.rpc('benchPresetSave', function(src, char, name, set)
    local s = Bench.active(src, char, true)
    if not s then return { ok = false, msg = L('stand_bench') } end
    local gun = s.gun

    name = cleanName(name)
    if name == '' then return { ok = false, msg = L('preset_need_name') } end

    local clean = Bench.validateSet(gun, set)
    if not clean or next(clean) == nil then return { ok = false, msg = L('preset_need_parts') } end

    local weapon = gun.name:upper()
    local existing = MySQL.scalar.await(
        'SELECT id FROM gunsmith_presets WHERE charid = ? AND weapon = ? AND name = ?',
        { char.charIdentifier, weapon, name })
    if not existing then
        local total = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM gunsmith_presets WHERE charid = ?',
            { char.charIdentifier })) or 0
        if total >= Config.Bench.presetLimit then
            return { ok = false, msg = L('preset_limit', Config.Bench.presetLimit) }
        end
    end
    MySQL.query.await([[INSERT INTO gunsmith_presets (charid, weapon, name, comps) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE comps = VALUES(comps)]], { char.charIdentifier, weapon, name, json.encode(clean) })

    return {
        ok = true,
        presets = BenchPresets.list(char.charIdentifier, weapon),
        name = name,
        replaced = existing ~= nil,
    }
end, { exclusive = true, throttle = 750 })

Srv.rpc('benchPresetDelete', function(src, char, id)
    local s = Bench.sessions[src]
    if not s or s.charId ~= char.charIdentifier or not s.gun then return { ok = false } end
    id = GS.int(id)
    if id then
        MySQL.update.await('DELETE FROM gunsmith_presets WHERE id = ? AND charid = ?', { id, char.charIdentifier })
    end
    return { ok = true, presets = BenchPresets.list(char.charIdentifier, s.gun.name) }
end, { exclusive = true, throttle = 300 })
