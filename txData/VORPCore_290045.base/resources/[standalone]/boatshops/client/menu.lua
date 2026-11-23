-- boatshops | a level stack over pup-ui's ink menu (keyboard driven, no mouse focus,
-- so the game keys stay readable while a menu is up)
--
--   BoatMenu.open(level)   new stack with level as its root
--   BoatMenu.push(level)   add a level
--   BoatMenu.back()        run the level's onBack, or go back one level
--   BoatMenu.close()       hide and run every level's onLeave, then BoatMenu.onClose
--   BoatMenu.redraw()
--   BoatMenu.isOpen()
--
-- level  = { title, subtitle, options, startIndex, hints,
--            onMove = fn(index, option), onBack = fn() -> true when handled,
--            onLeave = fn() when the level is removed }
-- option = { label, description, onSelect = fn(option, index) }

BoatMenu = {}
BoatMenu.onClose = function() end

local resName <const> = GetCurrentResourceName()
local levels = {}
local generation = 0

local function token()
    return ('%s:menu:%d'):format(resName, generation)
end

local function top()
    return levels[#levels]
end

local function safe(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, r = pcall(fn, ...)
    if not ok then print(('^1[boatshops/menu]^7 %s'):format(tostring(r))) end
    return r
end

local function draw()
    local level = top()
    if not level then return end
    local rows = {}
    for i, opt in ipairs(level.options or {}) do
        rows[i] = { label = opt.label or '', description = opt.description }
    end
    generation = generation + 1
    exports['pup-ui']:OpenInkMenu({
        owner = token(),
        title = level.title or '',
        subtitle = level.subtitle,
        startIndex = level.index or level.startIndex or 1,
        hints = level.hints,
        options = rows,
    })
    -- the ink menu sends no move for the row it opens on
    local index = level.index or level.startIndex or 1
    if level.onMove and level.options[index] then safe(level.onMove, index, level.options[index]) end
end

local function leave(level)
    if level then safe(level.onLeave) end
end

function BoatMenu.open(level)
    for i = #levels, 1, -1 do leave(levels[i]) end
    levels = { level }
    draw()
end

function BoatMenu.push(level)
    if #levels == 0 then return BoatMenu.open(level) end
    levels[#levels + 1] = level
    draw()
end

function BoatMenu.close()
    if #levels == 0 then return end
    local was = levels
    levels = {}
    generation = generation + 1
    exports['pup-ui']:HideInkMenu()
    for i = #was, 1, -1 do leave(was[i]) end
    safe(BoatMenu.onClose)
end

function BoatMenu.back()
    local level = top()
    if not level then return end
    if level.onBack and safe(level.onBack) == true then return end
    if #levels <= 1 then return BoatMenu.close() end
    levels[#levels] = nil
    leave(level)
    draw()
end

function BoatMenu.redraw()
    draw()
end

function BoatMenu.isOpen()
    return #levels > 0
end

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner ~= token() then return end
    local level = top()
    if not level then return end
    level.index = tonumber(index) or 1
    local opt = (level.options or {})[level.index]
    if opt and level.onMove then safe(level.onMove, level.index, opt) end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= token() then return end
    local level = top()
    if not level then return end
    index = tonumber(index) or 1
    level.index = index
    local opt = (level.options or {})[index]
    if opt and opt.onSelect then safe(opt.onSelect, opt, index) end
end)

-- Escape: pup-ui has already hidden the menu
AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= token() then return end
    local level = top()
    if not level then return end
    if level.onBack and safe(level.onBack) == true then return end
    if #levels <= 1 then
        local was = levels
        levels = {}
        for i = #was, 1, -1 do leave(was[i]) end
        safe(BoatMenu.onClose)
        return
    end
    levels[#levels] = nil
    leave(level)
    draw()
end)
