-- legendaryhunt | pup-ui list menus
-- One owner token for this resource; events carrying any other owner are ignored.
-- Menu.open(data, handlers) shows a list; handlers.select(index), handlers.back(), handlers.closed().

Menu = { owner = 'legendaryhunt:list', handlers = nil }

function Menu.isOpen()
    return Menu.handlers ~= nil
end

function Menu.open(data, handlers)
    if GetResourceState('pup-ui') ~= 'started' then
        Cli.warnOnce('pupui', 'pup-ui is not started; menus are unavailable')
        return false
    end
    Menu.handlers = handlers
    Menu.openedAt = GetEntityCoords(PlayerPedId())
    data.owner = Menu.owner
    data.keyboard = true
    local ok, err = pcall(function() exports['pup-ui']:OpenListMenu(data) end)
    if not ok then
        Menu.handlers = nil
        Cli.warnOnce('pupui_open', 'pup-ui OpenListMenu failed: ' .. tostring(err))
        return false
    end
    return true
end

-- another resource can open its list over ours with no close event; the ped stands still while ours is up, so movement means ours is gone
function Menu.stale()
    if not Menu.handlers or not Menu.openedAt then return false end
    if #(GetEntityCoords(PlayerPedId()) - Menu.openedAt) <= 3.0 then return false end
    local h = Menu.handlers
    Menu.handlers = nil
    if h.closed then h.closed() end
    return true
end

-- close without firing any handler (used on cleanup)
function Menu.hide()
    if not Menu.handlers then return end
    Menu.handlers = nil
    pcall(function() exports['pup-ui']:HideListMenu() end)
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= Menu.owner or not Menu.handlers then return end
    local h = Menu.handlers
    Menu.handlers = nil -- pup-ui closes the list on select
    if h.select then h.select(tonumber(index)) end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= Menu.owner or not Menu.handlers then return end
    local h = Menu.handlers
    Menu.handlers = nil
    if h.back then h.back() elseif h.closed then h.closed() end
end)

-- pup-ui re-fires a forced close with the real owner, so a nil owner is not ours to act on
AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= Menu.owner then return end
    if not Menu.handlers then return end
    local h = Menu.handlers
    Menu.handlers = nil
    if h.closed then h.closed() end
end)
