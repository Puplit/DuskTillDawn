-- Modified by Puppet (Dusk Till Dawn), 2026
-- pupmenu.lua | shared helper (identical in every pup- resource; owner token isolates us)
PupMenu = {}
local RES = GetCurrentResourceName()
local stack = {} -- { { spec, index } }  spec = { title, subtitle, options } ; option = { label, desc, action=fn, submenu=fn|spec, close=bool }
local seq = 0
local function ownerTok() return RES .. ':menu:' .. seq end

local function renderTop()
    local top = stack[#stack]
    if not top then return end
    local opts = {}
    for i, o in ipairs(top.spec.options) do opts[i] = { label = o.label, desc = o.desc, value = o.value, price = o.price, disabled = o.disabled } end
    exports['pup-ui']:OpenListMenu({ owner = ownerTok(), title = top.spec.title, subtitle = top.spec.subtitle, options = opts })
end

function PupMenu.Open(spec)          -- open as a fresh root menu
    seq = seq + 1
    stack = { { spec = spec } }
    renderTop()
end
function PupMenu.Push(spec)          -- open a submenu level
    stack[#stack + 1] = { spec = spec }
    renderTop()
end
function PupMenu.Pop()               -- back one level (closes menu at root)
    stack[#stack] = nil
    if #stack > 0 then renderTop() else exports['pup-ui']:HideListMenu() PupMenu.OnClose() end
end
function PupMenu.Close()
    if #stack == 0 then return end
    stack = {}
    exports['pup-ui']:HideListMenu()
    PupMenu.OnClose()
end
function PupMenu.Refresh(spec)       -- rebuild current level in place (after a purchase etc.)
    if #stack == 0 then return end
    stack[#stack].spec = spec or stack[#stack].spec
    renderTop()
end
function PupMenu.IsOpen() return #stack > 0 end
PupMenu.OnClose = function() end     -- resources overwrite to clear their own state

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= ownerTok() or #stack == 0 then return end
    local top = stack[#stack]
    local opt = top.spec.options[index]
    if not opt then return end
    if opt.submenu then
        local sub = type(opt.submenu) == 'function' and opt.submenu() or opt.submenu
        if sub then PupMenu.Push(sub) end
        return
    end
    if opt.action then opt.action(opt) end
    if opt.close then PupMenu.Close() elseif opt.reopen ~= false and #stack > 0 then renderTop() end
end)
AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= ownerTok() then return end
    PupMenu.Pop()
end)
AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= ownerTok() then return end
    if #stack > 0 then stack = {} PupMenu.OnClose() end
end)
