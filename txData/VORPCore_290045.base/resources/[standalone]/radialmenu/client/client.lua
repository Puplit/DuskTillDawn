-- murphy_radialmenu -- client entry
-- Holds wheel state, owns the keybind, sends payloads to the NUI, and routes
-- selections into the actions declared in shared/config.lua.

local RESOURCE = GetCurrentResourceName()

-- ============================================================================
-- STATE
-- ============================================================================

-- Live copy of the catalog: Config.Menus is deep-cloned so runtime mutations
-- (registerMenu / registerSlot / removeSlot) never leak back into Config.
local menus = {}

local currentMenuId = nil    -- menu shown by the NUI, nil when closed

-- Resolved copy of the open menu (childrenBuilder results included) so
-- findSlot can return the live dynamic slots. nil when closed.
local currentResolved = nil

local contextResolver = nil  -- optional override for Config.Contexts

-- ============================================================================
-- HELPERS
-- ============================================================================

local function deepCopy(t)
  if type(t) ~= 'table' then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepCopy(v) end
  return out
end

for id, def in pairs(Config.Menus or {}) do menus[id] = deepCopy(def) end

local function logError(fmt, ...)
  print(('[radialmenu] ' .. fmt):format(...))
end

-- ============================================================================
-- PLAYER TARGETING -- slots with `target = 'closest' | 'nearby' | 'cursor'`
-- ----------------------------------------------------------------------------
-- A targeted slot resolves another player before its action runs. The
-- resolved entry is { playerId, serverId, ped, dist, name, label }: `name`
-- is the raw display name, `label` adds " [serverId]" when configured.
-- ============================================================================

local TARGET_MODES = { closest = true, nearby = true, cursor = true }
local HEAD_BONE = 21030

local function targetCfg() return Config.Target or {} end

local function targetRange(slot)
  return tonumber(slot and slot.targetRange) or tonumber(targetCfg().Range) or 5.0
end

local function targetLabel(mode)
  local labels = targetCfg().Labels
  return labels and labels[mode] or nil
end

local function playerDisplayName(playerId, serverId)
  local name
  local getName = targetCfg().GetName
  if type(getName) == 'function' then
    local ok, v = pcall(getName, playerId, serverId)
    if ok and v ~= nil and v ~= '' then name = tostring(v) end
  end
  if not name or name == '' then name = GetPlayerName(playerId) end
  if not name or name == '' then name = '#' .. tostring(serverId) end
  return name
end

-- Other players within `range` meters, closest first.
local function nearbyPlayers(range)
  local myCoords = GetEntityCoords(PlayerPedId())
  local myId = PlayerId()
  local showId = targetCfg().ShowServerId ~= false
  local out = {}
  for _, p in ipairs(GetActivePlayers()) do
    if p ~= myId then
      local ped = GetPlayerPed(p)
      if ped ~= 0 and DoesEntityExist(ped) then
        local dist = #(myCoords - GetEntityCoords(ped))
        if dist <= range then
          local serverId = GetPlayerServerId(p)
          local name = playerDisplayName(p, serverId)
          out[#out + 1] = {
            playerId = p,
            serverId = serverId,
            ped      = ped,
            dist     = dist,
            name     = name,
            label    = showId and ('%s [%d]'):format(name, serverId) or name,
          }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.dist < b.dist end)
  return out
end

local function closestPlayer(range)
  return nearbyPlayers(range)[1]
end

-- `{target}` -> server id, `{targetName}` -> name. Second return: whether
-- anything was substituted.
local function fillPlaceholders(s, target)
  if type(s) ~= 'string' then return s, false end
  local n1, n2
  s, n1 = s:gsub('{targetName}', function() return target.name end)
  s, n2 = s:gsub('{target}', function() return tostring(target.serverId) end)
  return s, (n1 + n2) > 0
end

-- Command line / args with the target injected. Placeholders are replaced
-- (a bare '{target}' arg becomes a number); with no placeholder anywhere the
-- server id is appended as the last argument.
local function withTarget(action, target)
  local v = action.value
  local args = {}
  local replaced = false

  if action.type == 'command' then
    v, replaced = fillPlaceholders(v, target)
  end
  for i, a in ipairs(action.args or {}) do
    if a == '{target}' then
      args[i] = target.serverId
      replaced = true
    else
      local na, hit = fillPlaceholders(a, target)
      args[i] = na
      replaced = replaced or hit
    end
  end

  if not replaced then
    if action.type == 'command' then
      v = tostring(v) .. ' ' .. tostring(target.serverId)
    else
      args[#args + 1] = target.serverId
    end
  end
  return v, args
end

-- 'nearby': one child per player in range, carrying the parent's action.
local function nearbyChildren(slot, candidates)
  local out = {}
  for _, c in ipairs(candidates) do
    out[#out + 1] = {
      id          = ('%s__%d'):format(tostring(slot.id), c.serverId),
      icon        = slot.icon,
      label       = c.label,
      description = ('%d m'):format(math.floor(c.dist + 0.5)),
      stayOpen    = slot.stayOpen,
      delay       = slot.delay,
      action      = slot.action,
      _target     = c,
    }
  end
  return out
end

-- Materialize a slot tree: run visibleWhen / childrenBuilder without mutating
-- the static `menus` table. visibleWhen errors fall open (slot shown) so a
-- broken predicate doesn't silently hide functionality.
local function resolveSlots(slots)
  local out = {}
  for _, s in ipairs(slots or {}) do
    local visible = true
    if type(s.visibleWhen) == 'function' then
      local ok, v = pcall(s.visibleWhen)
      if ok then
        visible = v ~= false
      else
        logError('visibleWhen for slot %s failed: %s', tostring(s.id), tostring(v))
      end
    end

    -- Targeted slot: scan for players now so the wheel can hide (or grey
    -- out) the slot when nobody is around, and build the 'nearby' sub-wheel.
    local candidates = nil
    if visible and TARGET_MODES[s.target] and not (s.children or s.childrenBuilder) then
      candidates = nearbyPlayers(targetRange(s))
      if #candidates == 0 and targetCfg().HideWhenNobody ~= false then visible = false end
    end

    if visible then
      local copy
      if s.childrenBuilder or s.children or candidates then
        copy = {}
        for k, v in pairs(s) do
          if k ~= 'childrenBuilder' and k ~= 'visibleWhen' then copy[k] = v end
        end
        if s.childrenBuilder then
          local ok, built = pcall(s.childrenBuilder)
          copy.children = (ok and type(built) == 'table') and built or {}
          if not ok then logError('childrenBuilder for slot %s failed: %s', tostring(s.id), tostring(built)) end
        end
        if candidates then
          copy.description = copy.description or targetLabel(s.target)
          if s.target == 'nearby' then
            if #candidates > 0 then
              copy.children = nearbyChildren(s, candidates)
            else
              copy.disabled = true
            end
          elseif s.target == 'closest' and #candidates == 0 then
            copy.disabled = true
          elseif s.target == 'cursor' then
            -- The picker takes over the screen: the wheel can't stay open.
            copy.stayOpen = nil
          end
        end
        if copy.children then
          copy.children = resolveSlots(copy.children)
          -- A sub-menu that resolves to nothing (every child hidden, empty
          -- builder, nobody in range) disappears instead of being a dead
          -- button; with an `action` of its own it degrades to a plain leaf.
          if #copy.children == 0 then
            copy.children = nil
            if not copy.action then copy = nil end
          end
        end
      else
        copy = s
      end
      if copy then out[#out + 1] = copy end
    end
  end
  return out
end

-- nil when the menu doesn't exist or resolves to zero visible slots.
local function materialize(menuId)
  local menu = menus[menuId]
  if not menu then return nil end
  local baseSlots = menu.slots
  -- A menu can build its whole slot list at open time (`slotsBuilder`), the
  -- menu-level counterpart of a slot's childrenBuilder. Integrations use it
  -- to expose a sub-menu as a directly-openable wheel (`/radial clothing`).
  if type(menu.slotsBuilder) == 'function' then
    local ok, built = pcall(menu.slotsBuilder)
    if not ok then
      logError('slotsBuilder for menu %s failed: %s', tostring(menuId), tostring(built))
    end
    baseSlots = (ok and type(built) == 'table') and built or (menu.slots or {})
  end
  local slots = resolveSlots(baseSlots)
  if #slots == 0 then return nil end
  return {
    menuId = menuId,
    title  = menu.title,
    logo   = menu.logo,
    slots  = slots,
  }
end

-- Slot matching `slotId` at the end of `path` (array of parent slot ids).
local function findSlot(slotId, path)
  if not currentResolved then return nil end
  local list = currentResolved.slots
  for _, parentId in ipairs(path or {}) do
    local parent
    for _, s in ipairs(list) do if s.id == parentId then parent = s; break end end
    if not parent or not parent.children then return nil end
    list = parent.children
  end
  for _, s in ipairs(list) do
    if s.id == slotId then return s end
  end
  return nil
end

-- NUI payload: rendering fields only -- `action` / `childrenBuilder` are Lua
-- values SendNUIMessage can't serialize.
local function serializeMenu(resolved)
  if not resolved then return nil end
  local function strip(slots)
    local out = {}
    for i, s in ipairs(slots) do
      out[i] = {
        id          = s.id,
        icon        = s.icon,
        label       = s.label,
        description = s.description or nil,
        disabled    = s.disabled or nil,
        stayOpen    = s.stayOpen or nil,
        children    = s.children and strip(s.children) or nil,
      }
    end
    return out
  end
  return {
    menuId = resolved.menuId,
    title  = resolved.title,
    logo   = resolved.logo,
    slots  = strip(resolved.slots or {}),
  }
end

-- ============================================================================
-- ON-SCREEN PICKER -- target = 'cursor'
-- ----------------------------------------------------------------------------
-- Takes NUI focus (cursor visible, camera frozen like the wheel) and streams
-- the screen position of every player in range to the NUI, which draws a
-- clickable name tag over each head. Click a tag = pick; Esc / right click /
-- click on nothing = cancel. Only one picker at a time.
-- ============================================================================

local picker = nil   -- { range, cb, openedAt } while the picker is up

local function closePicker(target)
  if not picker then return end
  local p = picker
  picker = nil
  SendNUIMessage({ action = 'nui:picker:close', payload = {} })
  SetNuiFocusKeepInput(false)
  SetNuiFocus(false, false)
  if p.cb then
    local ok, err = pcall(p.cb, target)
    if not ok then logError('picker callback failed: %s', tostring(err)) end
  end
end

-- Screen-space tags for the NUI: x / y in 0..1, `visible` false when the
-- head is off screen (tag hidden, player still selectable once it comes back).
local function pickerFrame(candidates)
  local players = {}
  for i, c in ipairs(candidates) do
    local head = GetPedBoneCoords(c.ped, HEAD_BONE, 0.0, 0.0, 0.0)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(head.x, head.y, head.z + 0.25)
    players[i] = { serverId = c.serverId, name = c.label, x = sx, y = sy, visible = onScreen == true }
  end
  return players
end

-- cb(target | nil) once the player picks someone or cancels.
local function openPicker(range, cb)
  if picker then closePicker(nil) end
  local mine = { range = range, cb = cb, openedAt = GetGameTimer() }
  picker = mine

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(true)
  SendNUIMessage({ action = 'nui:picker:open', payload = { players = pickerFrame(nearbyPlayers(range)) } })

  CreateThread(function()
    local candidates, lastScan = {}, 0
    local timeout = tonumber(targetCfg().PickerTimeout) or 15000
    while picker == mine do
      local now = GetGameTimer()
      if timeout > 0 and now - mine.openedAt > timeout then
        closePicker(nil)
        break
      end
      -- Players enter / leave range: rescan a few times a second, project
      -- every frame so the tags follow the heads.
      if now - lastScan > 250 then
        candidates = nearbyPlayers(range)
        lastScan = now
      end
      SendNUIMessage({ action = 'nui:picker:update', payload = { players = pickerFrame(candidates) } })
      Wait(0)
    end
  end)
end

RegisterNUICallback('picker:select', function(data, cb)
  local serverId = data and tonumber(data.serverId)
  local target = nil
  if picker and serverId then
    -- Re-validate at click time: the player may have walked out of range.
    for _, c in ipairs(nearbyPlayers(picker.range)) do
      if c.serverId == serverId then target = c break end
    end
  end
  closePicker(target)
  cb({ ok = true })
end)

RegisterNUICallback('picker:cancel', function(_, cb)
  closePicker(nil)
  cb({ ok = true })
end)

-- ============================================================================
-- DISPATCH
-- ============================================================================

local function runAction(slot, slotId, path, target)
  local action = slot.action
  local t = action.type
  local v = action.value
  local args = action.args or {}
  if target and t ~= 'callback' then v, args = withTarget(action, target) end

  if t == 'command' then
    ExecuteCommand(v)

  elseif t == 'event' then
    TriggerEvent(v, table.unpack(args))

  elseif t == 'serverEvent' then
    TriggerServerEvent(v, table.unpack(args))

  elseif t == 'export' then
    local resource, fn = v[1], v[2]
    local ok, err = pcall(function()
      exports[resource][fn](exports[resource], table.unpack(args))
    end)
    if not ok then logError('export %s.%s failed: %s', resource, fn, tostring(err)) end

  elseif t == 'callback' then
    local ok, err = pcall(v, slotId, path, target)
    if not ok then logError('callback for slot %s failed: %s', slotId, tostring(err)) end

  else
    logError('unknown action type %q for slot %s', tostring(t), tostring(slotId))
  end
end

-- `delay` (ms) defers the action so the click that selected the slot doesn't
-- bleed into a chained NUI (interaction picker, player selector, keyboard).
-- Targeted slots resolve their player first: 'nearby' children already carry
-- it, 'closest' looks it up now, 'cursor' asks the on-screen picker.
local function dispatch(slot, slotId, path)
  local action = slot.action
  if not action or not action.type then return end

  local function run(target)
    local delay = tonumber(slot.delay) or 0
    if delay > 0 then
      CreateThread(function()
        Wait(delay)
        runAction(slot, slotId, path, target)
      end)
    else
      runAction(slot, slotId, path, target)
    end
  end

  if slot._target then
    run(slot._target)
  elseif slot.target == 'closest' then
    local target = closestPlayer(targetRange(slot))
    if not target then
      logError('slot %s: no player within %.1f m', tostring(slotId), targetRange(slot))
      return
    end
    run(target)
  elseif slot.target == 'cursor' then
    openPicker(targetRange(slot), function(target)
      if target then run(target) end
    end)
  else
    run(nil)
  end
end

-- ============================================================================
-- OPEN / CLOSE / REFRESH
-- ============================================================================

-- pup: dead or bleeding out = no wheel. IsPlayerDead is what vorp_core's own
-- respawn system uses to decide a player is down; IsPedDeadOrDying also catches
-- the moment between the hit and the death cam.
local function isDead()
  local ped = PlayerPedId()
  return IsPlayerDead(PlayerId()) or IsPedDeadOrDying(ped, true)
end

-- Open `menuId`, or (nil) the first matching context whose menu materializes
-- to at least one slot -- empty menus fall through to the next context.
local function open(menuId)
  if isDead() then return false end
  local resolved = nil

  if menuId then
    resolved = materialize(menuId)
  else
    if contextResolver then
      local ok, id = pcall(contextResolver)
      if ok and id then resolved = materialize(id) end
    end
    if not resolved then
      local ped = PlayerPedId()
      for _, ctx in ipairs(Config.Contexts or {}) do
        local ok, hit = pcall(ctx.when, ped)
        if ok and hit then
          resolved = materialize(ctx.menuId)
          if resolved then break end
        end
      end
    end
  end

  if not resolved then return false end
  currentMenuId = resolved.menuId
  currentResolved = resolved
  SetNuiFocus(true, true)
  -- KeepInput: without it NUI focus swallows the keyboard, so the hold-key
  -- release fires on the next frame and the wheel closes itself instantly.
  SetNuiFocusKeepInput(true)
  SendNUIMessage({ action = 'nui:radial:open', payload = serializeMenu(currentResolved) })
  return true
end

local function close()
  if not currentMenuId then return end
  SendNUIMessage({ action = 'nui:radial:close', payload = {} })
  SetNuiFocusKeepInput(false)
  SetNuiFocus(false, false)
  currentMenuId = nil
  currentResolved = nil
end

-- Re-resolve and push fresh slots into the open wheel; close if now empty.
local function refresh()
  if not currentMenuId then return end
  local resolved = materialize(currentMenuId)
  if not resolved then close() return end
  currentResolved = resolved
  SendNUIMessage({ action = 'nui:radial:update', payload = { slots = serializeMenu(currentResolved).slots } })
end

-- pup: dying with the wheel up would leave NUI focus stuck on a corpse, so
-- anything open is shut the moment the player goes down.
local function shutWheel()
  if picker then closePicker(nil) end
  close()
end

AddEventHandler('vorp_core:Client:OnPlayerDeath', shutWheel)

-- The event covers a clean kill; this catches bleeding out and anything that
-- kills without firing it. Only spins while something is actually open.
CreateThread(function()
  while true do
    if currentMenuId or picker then
      if isDead() then shutWheel() end
      Wait(200)
    else
      Wait(1000)
    end
  end
end)

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('radial:select', function(data, cb)
  local slotId = data and data.slotId
  local path   = (data and data.path) or {}
  local slot   = slotId and findSlot(slotId, path) or nil
  local stayOpen = slot and slot.stayOpen and true or false

  -- Leaf select: the NUI already hid itself, so release focus. stayOpen
  -- slots keep the wheel + focus up so the player can pick again.
  if not stayOpen then
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    currentMenuId = nil
    currentResolved = nil
  end

  if slot and not slot.disabled then
    dispatch(slot, slotId, path)
  end

  cb({ ok = true })
end)

RegisterNUICallback('radial:close', function(_, cb)
  SetNuiFocusKeepInput(false)
  SetNuiFocus(false, false)
  currentMenuId = nil
  currentResolved = nil
  cb({ ok = true })
end)

-- ============================================================================
-- INPUT LOCK -- while the wheel is open
-- ----------------------------------------------------------------------------
-- SetNuiFocusKeepInput leaks the mouse axes to the game, so the camera would
-- rotate with the wheel; keyboard KeepInput is still needed for movement and
-- hold-key detection, so look + combat controls are disabled per frame
-- instead. RDR3 control hashes -- the FiveM numeric IDs no-op on RedM.
-- ============================================================================

local INPUT_LOOK_LR    = 0xA987235F
local INPUT_LOOK_UD    = 0xD2047988
local INPUT_ATTACK     = 0x07CE1E61  -- LMB / melee primary (also F unarmed)
local INPUT_ATTACK2    = 0xCEE12B50  -- secondary attack / mounted melee
local INPUT_AIM        = 0xB2F377E8  -- RMB aim

CreateThread(function()
  while true do
    if currentMenuId or picker then
      DisableControlAction(0, INPUT_LOOK_LR, true)
      DisableControlAction(0, INPUT_LOOK_UD, true)
      DisableControlAction(0, INPUT_ATTACK,  true)
      DisableControlAction(0, INPUT_ATTACK2, true)
      DisableControlAction(0, INPUT_AIM,     true)
      DisablePlayerFiring(PlayerId(), true)
      Wait(0)
    else
      Wait(200)
    end
  end
end)

-- ============================================================================
-- KEYBIND
-- ----------------------------------------------------------------------------
-- Config.OpenControl (control hash) is a toggle: hold-to-show can't work on
-- mouse binds because once the NUI takes focus the game side never sees the
-- release. The opening press is detected here; the closing press / Esc /
-- backdrop click are detected by the NUI page (App.jsx), the only layer that
-- still sees input while focused. The control stays disabled so its native
-- effect (e.g. INPUT_ATTACK2 = secondary attack) never leaks through.
-- Config.OpenKey (keyboard) polls IsRawKey*, which survives NUI focus:
-- hold-to-show works.
-- ============================================================================

local KEY_CODES = {
  A = 0x41, B = 0x42, C = 0x43, D = 0x44, E = 0x45, F = 0x46, G = 0x47,
  H = 0x48, I = 0x49, J = 0x4A, K = 0x4B, L = 0x4C, M = 0x4D, N = 0x4E,
  O = 0x4F, P = 0x50, Q = 0x51, R = 0x52, S = 0x53, T = 0x54, U = 0x55,
  V = 0x56, W = 0x57, X = 0x58, Y = 0x59, Z = 0x5A,
  ['0'] = 0x30, ['1'] = 0x31, ['2'] = 0x32, ['3'] = 0x33, ['4'] = 0x34,
  ['5'] = 0x35, ['6'] = 0x36, ['7'] = 0x37, ['8'] = 0x38, ['9'] = 0x39,
  TAB = 0x09, SPACE = 0x20, ESCAPE = 0x1B, ENTER = 0x0D, BACKSPACE = 0x08,
  F1 = 0x70, F2  = 0x71, F3  = 0x72, F4  = 0x73, F5  = 0x74, F6  = 0x75,
  F7 = 0x76, F8  = 0x77, F9  = 0x78, F10 = 0x79, F11 = 0x7A, F12 = 0x7B,
  LSHIFT = 0xA0, RSHIFT = 0xA1, LCTRL = 0xA2, RCTRL = 0xA3,
  LALT = 0xA4, RALT = 0xA5,
}

local function resolveKeyCode(name)
  if type(name) == 'number' then return name end
  if type(name) ~= 'string' then return nil end
  return KEY_CODES[name:upper()]
end

CreateThread(function()
  -- pup: Config.OpenKeyMapping uses the game's own keybind system (see below the
  -- /radial command). Nothing to poll, and neither stock bind should also fire.
  if Config.OpenKeyMapping then return end

  if type(Config.OpenControl) == 'number' then
    local control = Config.OpenControl
    local wasPressed = false
    while true do
      Wait(0)
      if not IsPauseMenuActive() then
        DisableControlAction(0, control, true)
        local pressed = IsDisabledControlPressed(0, control)
        if pressed and not wasPressed and not currentMenuId and not picker then
          open(nil)
        end
        wasPressed = pressed
      end
    end
  else
    local vk = resolveKeyCode(Config.OpenKey or 'B')
    if not vk then
      logError('unknown Config.OpenKey %q, no keybind installed', tostring(Config.OpenKey))
      return
    end
    while true do
      Wait(0)
      if not IsPauseMenuActive() then
        if IsRawKeyPressed(vk) and not currentMenuId and not picker then
          open(nil)
        elseif IsRawKeyReleased(vk) and currentMenuId then
          close()
        end
      end
    end
  end
end)

--   /radial          -> open the context-appropriate menu
--   /radial <menuId> -> open a specific menu
RegisterCommand('radial', function(_, args)
  if picker then closePicker(nil); return end
  if currentMenuId then close(); return end
  open(args[1])
end, false)

-- pup: bind /radial through the game's keybind system. This is what puts the
-- wheel in Settings > Key Bindings > FiveM, where a player can change it for
-- themselves the same way they change the inventory key. The default below is
-- only a default; once a player rebinds it, their choice sticks.
--
-- /radial already toggles, so the same press opens and closes.
if Config.OpenKeyMapping then
  RegisterKeyMapping('radial',
    Config.OpenKeyMappingLabel or 'Open Radial Menu',
    'keyboard',
    tostring(Config.OpenKeyMapping))
end

-- Direct-open keybinds: Config.DirectMenuKeys maps a menu id to a key that
-- opens that wheel straight away, skipping the context wheel. Same
-- hold-to-show model as Config.OpenKey.
CreateThread(function()
  local binds = {}
  for menuId, keyName in pairs(Config.DirectMenuKeys or {}) do
    local vk = resolveKeyCode(keyName)
    if vk then
      binds[#binds + 1] = { vk = vk, menuId = menuId }
    else
      logError('unknown key %q in Config.DirectMenuKeys.%s, bind skipped', tostring(keyName), tostring(menuId))
    end
  end
  if #binds == 0 then return end
  while true do
    Wait(0)
    if not IsPauseMenuActive() then
      for _, b in ipairs(binds) do
        if IsRawKeyPressed(b.vk) and not currentMenuId and not picker then
          open(b.menuId)
        elseif IsRawKeyReleased(b.vk) and currentMenuId == b.menuId then
          close()
        end
      end
    end
  end
end)

-- pup: no ragdoll here; pup-misc/ragdoll owns /ragdoll and its Z keybind.

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

AddEventHandler('onClientResourceStart', function(name)
  if name ~= RESOURCE then return end
  if Config.Locale then
    SendNUIMessage({ action = 'nui:locale:set', payload = { locale = Config.Locale } })
  end
end)

AddEventHandler('onClientResourceStop', function(name)
  if name ~= RESOURCE then return end
  if currentMenuId or picker then
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
  end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('open', function(menuId) return open(menuId) end)

exports('openContext', function() return open(nil) end)

exports('close', function() close() end)

exports('isOpen', function() return currentMenuId ~= nil end)

exports('registerMenu', function(menuId, def)
  if type(menuId) ~= 'string' or type(def) ~= 'table' then return false end
  menus[menuId] = def
  if currentMenuId == menuId then refresh() end
  return true
end)

exports('unregisterMenu', function(menuId)
  if not menus[menuId] then return false end
  if currentMenuId == menuId then close() end
  menus[menuId] = nil
  return true
end)

-- `path` (array of parent slot ids) targets a sub-menu. Replaces by id.
exports('registerSlot', function(menuId, slot, path)
  local menu = menus[menuId]
  if not menu or type(slot) ~= 'table' or not slot.id then return false end
  local list = menu.slots
  for _, parentId in ipairs(path or {}) do
    local parent
    for _, s in ipairs(list) do if s.id == parentId then parent = s; break end end
    if not parent then return false end
    parent.children = parent.children or {}
    list = parent.children
  end
  for i, s in ipairs(list) do
    if s.id == slot.id then
      list[i] = slot
      if currentMenuId == menuId then refresh() end
      return true
    end
  end
  list[#list + 1] = slot
  if currentMenuId == menuId then refresh() end
  return true
end)

exports('removeSlot', function(menuId, slotId, path)
  local menu = menus[menuId]
  if not menu then return false end
  local list = menu.slots
  for _, parentId in ipairs(path or {}) do
    local parent
    for _, s in ipairs(list) do if s.id == parentId then parent = s; break end end
    if not parent or not parent.children then return false end
    list = parent.children
  end
  for i, s in ipairs(list) do
    if s.id == slotId then
      table.remove(list, i)
      if currentMenuId == menuId then refresh() end
      return true
    end
  end
  return false
end)

-- fn() must return a menuId, or nil to fall back to Config.Contexts.
-- Pass nil to remove the override.
exports('setContextResolver', function(fn)
  contextResolver = (type(fn) == 'function') and fn or nil
end)

-- Player targeting, usable from any client script:
--   getNearbyPlayers(range?) -> { { serverId, playerId, name, dist }, ... }
--   pickPlayer(cb, range?)   -> on-screen picker; cb(target | nil)
exports('getNearbyPlayers', function(range)
  local out = {}
  for i, c in ipairs(nearbyPlayers(tonumber(range) or targetRange(nil))) do
    out[i] = { serverId = c.serverId, playerId = c.playerId, name = c.name, dist = c.dist }
  end
  return out
end)

exports('pickPlayer', function(cb, range)
  if type(cb) ~= 'function' then return false end
  if isDead() then return false end   -- the picker is the one path that skips open()
  if currentMenuId then close() end
  openPicker(tonumber(range) or targetRange(nil), function(target)
    if target then
      cb({ serverId = target.serverId, playerId = target.playerId, name = target.name, dist = target.dist })
    else
      cb(nil)
    end
  end)
  return true
end)

-- Optional `translations` table is deep-merged onto the locale.
exports('setLocale', function(locale, translations)
  if type(locale) ~= 'string' then return false end
  SendNUIMessage({ action = 'nui:locale:set', payload = {
    locale = locale,
    translations = translations,
  }})
  return true
end)
