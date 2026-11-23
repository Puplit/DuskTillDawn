-- height (ped scale) reset, client half

-- a blood-vial disguise wears the target's Scale, so it owns the height while on
local function isDisguised()
    local ok, res = pcall(function() return exports.vorp_character:IsDisguised() end)
    return ok and res == true
end

-- SetPedScale alone does not redraw the ped; these three natives do
local function commitPed(ped)
    if not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- /heightdiag: F8 trace of carry/attach/death transitions and every scale write
local diagOn = false
local function diag(fmt, ...)
    if diagOn then print(("^5[hdiag %d]^7 " .. fmt):format(GetGameTimer(), ...)) end
end

-- never rescale an attached ped: the skeleton rebuild re-evaluates the attachment
-- matrix and the ped jumps. The watcher below re-applies once it detaches.
local function scaleBlocked(ped)
    return IsEntityAttached(ped)
end

-- true only if the write landed, so callers can spot one the attach guard ate
local function forceScale(ped, scale, allowAttached)
    if not DoesEntityExist(ped) then return false end
    if not allowAttached and scaleBlocked(ped) then
        diag("forceScale SKIPPED ped=%d - attached", ped)
        return false
    end
    diag("forceScale ped=%d scale=%.3f carriable=%d attached=%s dead=%s", ped, scale,
        Citizen.InvokeNative(0x61914209C36EFDDB, ped, Citizen.ResultAsInteger()),
        tostring(IsEntityAttached(ped)), tostring(IsEntityDead(ped)))
    SetPedScale(ped, scale + 0.01)
    UpdatePedVariation(ped)
    SetPedScale(ped, scale)
    UpdatePedVariation(ped)
    commitPed(ped)
    return true
end

-- Our own ped: one write and ONE redraw. Every UpdatePedVariation rebuilds the outfit and
-- shows as a blink, and ped scale is never networked (other players read the pupHeight
-- state bag and set it on their own screen), so the old +0.01 nudge and retry burst only
-- made the player blink 3-4 times. A freshly rebuilt ped (revive, respawn, first load)
-- can still drop the scale, so those get one late re-apply.
local REBUILD_REASONS <const> = { selected = true, revive = true, respawn = true, restream = true, ["resource start"] = true }
local selfApplied = { ped = 0, scale = nil } -- what we last wrote to our own ped
local applyToken = 0

local function writeSelf(ped, scale)
    SetPedScale(ped, scale)
    UpdatePedVariation(ped)
    commitPed(ped)
    selfApplied.ped, selfApplied.scale = ped, scale
end

local function applyScale(scale, reason)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    applyToken = applyToken + 1
    local token = applyToken

    CreateThread(function()
        diag("applyScale(self) scale=%.3f ped=%d reason=%s dead=%s attached=%s", scale, ped, tostring(reason),
          tostring(IsEntityDead(ped)), tostring(IsEntityAttached(ped)))
        -- being escorted is an attachment: a rebuild jolts us on every screen
        if scaleBlocked(ped) then
            diag("applyScale SKIPPED - attached")
            return
        end
        -- already at this height on this ped: nothing to redraw
        if selfApplied.ped == ped and selfApplied.scale == scale and not REBUILD_REASONS[reason] then
            diag("applyScale SKIPPED - already %.3f", scale)
            return
        end
        writeSelf(ped, scale)

        if REBUILD_REASONS[reason] then
            Wait(750)
            -- a newer apply (another height) wins
            if token ~= applyToken then return end
            ped = PlayerPedId()
            if DoesEntityExist(ped) and not scaleBlocked(ped) then writeSelf(ped, scale) end
        end
    end)
end

-- the ped /rc (or anything else) just rebuilt already wears CachedSkin.Scale
function PupNoteSelfScale(ped, scale)
    scale = tonumber(scale)
    if ped and scale then selfApplied.ped, selfApplied.scale = ped, scale end
end

RegisterNetEvent("vorp_character:pupApplyHeight", function(scale, reason)
    scale = tonumber(scale)
    if not scale or scale < 0.1 or scale > 5.0 then return end
    if isDisguised() then return end

    if type(CachedSkin) == "table" then
        CachedSkin.Scale = scale
    end
    applyScale(scale, reason)

    if Config and Config.General.devMode then
        print(("^3[pup height]^7 applied saved scale %.3f (%s)"):format(scale, tostring(reason or "?")))
    end
end)

-- ask the server for the saved height and re-apply it
function PupResetHeight()
    TriggerServerEvent("vorp_character:pupResetHeight")
end

-- height on other players' screens
local applied = {} -- [serverId] = { ped = handle, scale = number, nonce = number }

-- the bag holds { s = scale, n = nonce }
local function readHeight(v)
    if type(v) == "table" then return tonumber(v.s), tonumber(v.n) or 0 end
    return tonumber(v), 0
end

local function applyToPlayerIndex(plyIdx, value)
    local scale, nonce = readHeight(value)
    if not scale or scale < 0.1 or scale > 5.0 then return end

    -- our own ped goes through the local path above, which honours the disguise
    if plyIdx == PlayerId() then return end

    local ped = GetPlayerPed(plyIdx)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local serverId = GetPlayerServerId(plyIdx)
    local rec = applied[serverId]

    local attachedNow <const> = IsEntityAttached(ped)

    -- first apply only: a new handle, a changed scale, or a write made while carried
    if rec and rec.ped == ped and rec.scale == scale and rec.nonce == nonce
        and not (rec.attached and not attachedNow) then
        return
    end

    -- one already scaled is left alone until let go; an unscaled one still gets
    -- a single write, or the carrier sees default height for the whole escort
    if attachedNow and rec and rec.ped == ped then
        diag("observer apply DEFERRED sid=%d ped=%d - attached, already scaled", serverId, ped)
        return
    end

    diag("observer apply sid=%d ped=%d scale=%.3f nonce=%d attached=%s",
        serverId, ped, scale, nonce, tostring(attachedNow))
    applied[serverId] = { ped = ped, scale = scale, nonce = nonce, attached = attachedNow }

    -- one write, no retry burst: the burst on an attached ped is the bob
    if attachedNow then
        if not forceScale(ped, scale, true) then applied[serverId] = nil end
        return
    end

    CreateThread(function()
        local landed = false
        for _, delay in ipairs({ 0, 300, 800, 1600 }) do
            if delay > 0 then Wait(delay) end
            -- bail if this player left, re-streamed, or the value moved on
            local cur = applied[serverId]
            if not cur or cur.scale ~= scale or cur.nonce ~= nonce then return end
            local p = GetPlayerFromServerId(serverId)
            if p == -1 then return end
            local pd = GetPlayerPed(p)
            if pd == 0 or pd ~= cur.ped or not DoesEntityExist(pd) then return end
            if forceScale(pd, scale) then landed = true end
        end

        -- re-attached mid-burst: clear the stamp or the 2s sweep thinks it landed
        local cur = applied[serverId]
        if not landed and cur and cur.scale == scale and cur.nonce == nonce then
            diag("observer apply UNSTAMPED sid=%d - never landed, will retry", serverId)
            applied[serverId] = nil
        end
    end)
end

AddStateBagChangeHandler("pupHeight", nil, function(bagName, _, value)
    CreateThread(function()
        local plyIdx, waited = GetPlayerFromStateBagName(bagName), 0
        while plyIdx == 0 and waited < 5000 do
            Wait(100)
            waited = waited + 100
            plyIdx = GetPlayerFromStateBagName(bagName)
        end
        if plyIdx == 0 then return end

        -- the ped can lag the player handle by a few frames on stream-in
        waited = 0
        while GetPlayerPed(plyIdx) == 0 and waited < 2000 do
            Wait(50)
            waited = waited + 50
        end

        applyToPlayerIndex(plyIdx, value)
    end)
end)


-- the per-frame pin is off
local HEIGHT_PIN <const> = false

if HEIGHT_PIN then
    CreateThread(function()
        while true do
            Wait(0)
            local any = false
            for serverId, rec in pairs(applied) do
                any = true
                local plyIdx = GetPlayerFromServerId(serverId)
                if plyIdx ~= -1 then
                    local ped = GetPlayerPed(plyIdx)
                    if ped == rec.ped and ped ~= 0 and DoesEntityExist(ped) then
                        SetPedScale(ped, rec.scale)
                    end
                end
            end
            if not any then Wait(1000) end
        end
    end)
end

-- keep the bag honest across carry, attach and death transitions
CreateThread(function()
    local lastAttached, lastPed, lastDead = nil, 0, nil
    while true do
        Wait(1500)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local attached = IsEntityAttached(ped) and true or false
            -- death counts: a revive can leave handle and attachment unchanged
            local dead = IsEntityDead(ped) and true or false
            if ped ~= lastPed or attached ~= lastAttached or dead ~= lastDead then
                local becameAttached = attached and not lastAttached
                if lastDead and not dead then diag("revived - re-sending height") end
                lastPed, lastAttached, lastDead = ped, attached, dead
                -- only once free: rebuilding on the way in throws the prisoner about
                if not dead and not becameAttached and not attached and not isDisguised() then
                    PupResetHeight()
                end
            end
        end
    end
end)

-- rebuild once after a carry
PupForceRebuild = false

-- the restream is deferred 2.5s, so a carry starting inside that window needs its own number
local carryGeneration = 0

CreateThread(function()
    local needRebuild, stable = false, 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local st = Citizen.InvokeNative(0x61914209C36EFDDB, ped, Citizen.ResultAsInteger())
            if (st >= 4 and st <= 9) or st == 12 then
                if not needRebuild then carryGeneration = carryGeneration + 1 end
                needRebuild, stable = true, 0
            elseif needRebuild then
                local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, ped)
                local cuffed = Citizen.InvokeNative(0x74E559B3BC910685, ped)
                local free = st == 0 and not IsEntityAttached(ped) and not IsEntityDead(ped)
                    and not hogtied and not cuffed and not isDisguised()
                stable = free and (stable + 1) or 0
                if stable >= 3 then
                    needRebuild, stable = false, 0
                    -- read the model before /rc replaces the ped: the old handle then answers 0
                    local gen <const> = carryGeneration
                    local model <const> = GetEntityModel(ped)
                    diag("post-carry rebuild -> /%s", Config.Reload.command)
                    PupForceRebuild = true
                    ExecuteCommand(Config.Reload.command)
                    -- the rebuild renews only our handle, so ask for a restream.
                    -- generation and model, not net id: /rc always changes the id
                    CreateThread(function()
                        Wait(2500)
                        if gen ~= carryGeneration then
                            diag("post-carry restream dropped - another carry started")
                            return
                        end
                        local p = PlayerPedId()
                        if not DoesEntityExist(p) then return end
                        if IsPedOnMount(p) or GetVehiclePedIsIn(p, false) ~= 0 then return end
                        -- carried, hogtied or cuffed again inside the window
                        local stNow = Citizen.InvokeNative(0x61914209C36EFDDB, p, Citizen.ResultAsInteger())
                        if IsEntityAttached(p) or IsEntityDead(p) or stNow ~= 0
                            or Citizen.InvokeNative(0x3AA24CCC0D451379, p)
                            or Citizen.InvokeNative(0x74E559B3BC910685, p) then
                            diag("post-carry restream dropped - not free any more")
                            return
                        end
                        if isDisguised() or GetEntityModel(p) ~= model then
                            diag("post-carry restream dropped - model changed")
                            return
                        end
                        diag("post-carry restream request")
                        TriggerServerEvent("vorp_character:pupRestream")
                    end)
                end
            end
        end
    end
end)

local function publishEffectiveScale()
    local s = (type(CachedSkin) == "table") and tonumber(CachedSkin.Scale) or nil
    if not s or s < 0.1 or s > 5.0 then return end
    TriggerServerEvent("vorp_character:pupHeightPublish", s)
end

AddEventHandler("pup-disguise:apply", function()
    CreateThread(function()
        Wait(1500)
        publishEffectiveScale()
    end)
end)

AddEventHandler("pup-disguise:restore", function()
    CreateThread(function()
        Wait(1500)
        -- back to the saved height, by the normal server path
        PupResetHeight()
    end)
end)

-- /heightdiag toggles the F8 trace, /heightpoke <sid> re-applies one player's bag
local CARRIABLE_NAME <const> = { [0] = "NONE", "TO_HOGTIED", "INTRO", "CARRIABLE", "PICKUP_GROUND",
  "CARRIED_BY_HUMAN", "PLACING_GROUND", "CARRIED_BY_MOUNT", "PLACING_MOUNT", "PICKUP_MOUNT",
  "CUT_FREE", "PLACING_GROUND_ESCAPE", "PLACING_VEHICLE" }

local function carriableState(ped)
  return Citizen.InvokeNative(0x61914209C36EFDDB, ped, Citizen.ResultAsInteger())
end

RegisterCommand("heightdiag", function()
  diagOn = not diagOn
  print(("^5[hdiag]^7 trace %s"):format(diagOn and "ON" or "OFF"))
end, false)

RegisterCommand("heightpoke", function(_, args)
  local sid = tonumber(args[1])
  local plyIdx = sid and GetPlayerFromServerId(sid) or PlayerId()
  if plyIdx == -1 then return print("^1[hdiag]^7 no such player in scope") end
  local ped = GetPlayerPed(plyIdx)
  local s = readHeight(Player(GetPlayerServerId(plyIdx)).state.pupHeight)
  if not s then return print("^1[hdiag]^7 no pupHeight bag for that player") end
  print(("^5[hdiag]^7 poke sid=%d ped=%d bag=%.3f"):format(GetPlayerServerId(plyIdx), ped, s))
  forceScale(ped, s)
end, false)

CreateThread(function()
  local track = {} -- [serverId] = { ped, carr, att, dead, model }
  while true do
    Wait(100)
    if diagOn then
      local seen = {}
      for _, plyIdx in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(plyIdx)
        local ped = GetPlayerPed(plyIdx)
        seen[sid] = true
        if ped ~= 0 and DoesEntityExist(ped) then
          local cur = {
            ped = ped, carr = carriableState(ped), att = IsEntityAttached(ped),
            dead = IsEntityDead(ped), model = GetEntityModel(ped),
          }
          local prev = track[sid]
          if not prev then
            diag("track sid=%d%s ped=%d carr=%s att=%s dead=%s", sid, plyIdx == PlayerId() and "(me)" or "",
              ped, CARRIABLE_NAME[cur.carr] or cur.carr, tostring(cur.att), tostring(cur.dead))
          else
            for _, k in ipairs({ "ped", "carr", "att", "dead", "model" }) do
              if prev[k] ~= cur[k] then
                local pv, cv = prev[k], cur[k]
                if k == "carr" then pv, cv = CARRIABLE_NAME[pv] or pv, CARRIABLE_NAME[cv] or cv end
                diag("sid=%d%s %s: %s -> %s  (attachedTo=%d)", sid, plyIdx == PlayerId() and "(me)" or "",
                  k, tostring(pv), tostring(cv), GetEntityAttachedTo(ped))
              end
            end
          end
          track[sid] = cur
        end
      end
      for sid in pairs(track) do
        if not seen[sid] then track[sid] = nil; diag("untrack sid=%d", sid) end
      end
    end
  end
end)

CreateThread(function()
    while true do
        Wait(2000)
        for _, plyIdx in ipairs(GetActivePlayers()) do
            local st = Player(GetPlayerServerId(plyIdx)).state
            local scale = st and st.pupHeight
            if scale then applyToPlayerIndex(plyIdx, scale) end
        end

        -- drop rows for players who have left
        for serverId in pairs(applied) do
            if GetPlayerFromServerId(serverId) == -1 then applied[serverId] = nil end
        end
    end
end)
