-- pup_tailor | shared palette names (table palette_names).
local U = Tailor.U
local Cat = Tailor.Cat

local NAME_MAX <const> = 24
local names = {}   -- ["<unsigned hash>"] = name

local function broadcast()
    TriggerClientEvent('pup_tailor:paletteNames', -1, names)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `palette_names` (
            `palette` BIGINT(20) NOT NULL,
            `name` VARCHAR(24) NOT NULL,
            PRIMARY KEY (`palette`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local rows = MySQL.query.await('SELECT `palette`, `name` FROM `palette_names`') or {}
    for _, r in ipairs(rows) do
        local u = U.unsigned(tonumber(r.palette))
        if u and Cat.paletteSet[u] and type(r.name) == 'string' then names[U.hashKey(u)] = r.name end
    end
end)

RegisterNetEvent('pup_tailor:askPaletteNames', function()
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'paletteNames', 500) then return end
    TriggerClientEvent('pup_tailor:paletteNames', src, names)
end)

RegisterNetEvent('pup_tailor:namePalette', function(palette, name)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'rename', 2000) then return end
    Srv.safe('namePalette', function()
        local char = Srv.char(src)
        if not char or not Srv.requireBench(src, char) then return end
        local u = U.unsigned(palette)
        if not u or not Cat.paletteSet[u] then return end
        name = U.cleanText(name, NAME_MAX, false)
        local key = U.hashKey(u)
        if name == '' then
            MySQL.update.await('DELETE FROM `palette_names` WHERE `palette` = ?', { u })
            names[key] = nil
        else
            MySQL.insert.await(
                'INSERT INTO `palette_names` (`palette`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)',
                { u, name })
            names[key] = name
        end
        broadcast()
    end)
end)
