-- pup_tailor | staff-hidden singleplayer garments (table clothing_hidden) and /hiddengarments.
local U = Tailor.U

local hidden = {}   -- [signed drawable] = true
local loaded = false

function Srv.isHidden(v)
    local s = U.signed(v)
    return s ~= nil and hidden[s] == true
end

-- the list sent to clients: signed drawables
function Srv.hiddenList()
    local out = {}
    for d in pairs(hidden) do out[#out + 1] = d end
    table.sort(out)
    return out
end

local function broadcast()
    TriggerClientEvent('pup_tailor:hidden', -1, Srv.hiddenList())
end

CreateThread(function()
    Wait(2000)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `clothing_hidden` (
            `drawable` INT(11) NOT NULL,
            `label` VARCHAR(96) NULL DEFAULT NULL,
            `hidden_by` VARCHAR(96) NULL DEFAULT NULL,
            `hidden_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`drawable`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local rows = MySQL.query.await('SELECT `drawable` FROM `clothing_hidden`') or {}
    for _, r in ipairs(rows) do
        local s = U.signed(tonumber(r.drawable))
        if s then hidden[s] = true end
    end
    loaded = true
    Srv.log('%d hidden garment(s) loaded', U.count(hidden))
    broadcast()
end)

RegisterNetEvent('pup_tailor:hide', function(drawable, label)
    local src = Srv.validSource(source)
    if not src or not Srv.throttle(src, 'hide', 500) then return end
    Srv.safe('hide', function()
        local char = Srv.char(src)
        if not char or not Srv.isStaff(src, char) then return end
        local d = U.signed(drawable)
        if not d or not loaded then return end
        if hidden[d] then return TriggerClientEvent('vorp:TipRight', src, L('alreadyHidden'), 5000) end

        label = U.cleanText(type(label) == 'string' and label or tostring(d), 96, true)
        local by = U.cleanText(GetPlayerName(src) or '?', 96, false)
        hidden[d] = true
        MySQL.insert.await([[
            INSERT INTO `clothing_hidden` (`drawable`, `label`, `hidden_by`) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `hidden_by` = VALUES(`hidden_by`)
        ]], { d, label, by })
        Srv.log('%s (id %d) hid drawable %d (%s)', by, src, d, label)
        broadcast()
        if Srv.validSource(src) then Srv.notify(src, L('hiddenForAll'), 5000) end
    end)
end)

RegisterCommand('hiddengarments', function(src, args)
    src = tonumber(src) or 0
    if src ~= 0 then
        if not Srv.validSource(src) or not Srv.isStaff(src) then return end
    end
    Srv.safe('hiddengarments', function()
        if args[1] == 'restore' then
            local d = U.signed(tonumber(args[2]))
            if not d then
                return Srv.log('usage: hiddengarments restore <drawable>  (signed or unsigned)')
            end
            local res = MySQL.update.await('DELETE FROM `clothing_hidden` WHERE `drawable` = ?', { d })
            hidden[d] = nil
            broadcast()
            Srv.log('restored %d (%d row(s) removed)', d, tonumber(res) or 0)
            return
        end
        local rows = MySQL.query.await(
            'SELECT `drawable`, `label`, `hidden_by`, `hidden_at` FROM `clothing_hidden` ORDER BY `hidden_at` DESC, `drawable` DESC') or {}
        Srv.log('%d hidden garment(s):', #rows)
        for _, r in ipairs(rows) do
            Srv.log('  %s  %s  hidden by %s', tostring(r.drawable), tostring(r.label or '-'), tostring(r.hidden_by or '-'))
        end
        if src ~= 0 then TriggerClientEvent('vorp:TipRight', src, L('hiddenPrinted', #rows), 5000) end
    end)
end, false)
