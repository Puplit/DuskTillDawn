-- pup_shaman | ancient trees on the client: props, prompt, menus and the spirit vision

Trees = {}

local OWNER_TREE <const> = 'pup_shaman:tree'
local OWNER_VISION <const> = 'pup_shaman:vision'

local T <const> = Config.TreeRules
local props = {}        -- tree index -> local object
local nearIndex = nil   -- the tree within reach (nearest wins)
local interacting = false
local menu = nil        -- { owner, tree, giveTo } while one of our tree menus is open

-- props ------------------------------------------------------------------------------

local function spawnProp(i, tree)
    local hash = Shaman.LoadModel(tree.prop, 5000)
    if not hash or props[i] then return end
    local c = tree.coords
    local obj = CreateObject(hash, c.x, c.y, c.z - (tree.sink or 0.0), false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if obj and obj ~= 0 then
        FreezeEntityPosition(obj, true)
        props[i] = obj
    end
end

local function deleteProp(i)
    local obj = props[i]
    props[i] = nil
    if obj and DoesEntityExist(obj) then DeleteObject(obj) end
end

-- menus ------------------------------------------------------------------------------

local function closeMenu()
    if menu then
        menu = nil
        exports['pup-ui']:HideInkMenu()
    end
end

local function openTreeMenu(i)
    local tree = Config.Trees[i]
    menu = { owner = OWNER_TREE, tree = i }
    exports['pup-ui']:OpenInkMenu({
        owner = OWNER_TREE,
        title = tree.name,
        subtitle = L('tree_subtitle'),
        options = {
            { label = L('tree_eat'), description = L('tree_eat_desc') },
            { label = L('tree_give'), description = L('tree_give_desc') },
        },
    })
end

local function openVisionMenu(i, giveTo)
    local tree = Config.Trees[i]
    local options = {}
    for _, v in ipairs(tree.visions) do
        options[#options + 1] = { label = v.label }
    end
    menu = { owner = OWNER_VISION, tree = i, giveTo = giveTo }
    exports['pup-ui']:OpenInkMenu({
        owner = OWNER_VISION,
        title = tree.name,
        subtitle = L('tree_choose'),
        options = options,
    })
end

--- The nearest other player within range: player index and ped, or nil.
local function nearestPlayer(range)
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    local best, bestPed, bestDist
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= PlayerId() then
            local ped = GetPlayerPed(pl)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(pos - GetEntityCoords(ped))
                if d <= range and (not best or d < bestDist) then best, bestPed, bestDist = pl, ped, d end
            end
        end
    end
    return best, bestPed
end

local function eatSequence()
    local ped = PlayerPedId()
    local pick, bite, fruit = T.pick, T.bite, T.fruit
    Shaman.PlayAnim(ped, pick.dict, pick.clip, pick.ms, 0)
    Wait(pick.ms)
    local hash = Shaman.LoadModel(fruit.model, 3000)
    local prop
    if hash then
        local pos = GetEntityCoords(ped)
        prop = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, fruit.bone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            true, true, false, true, 1, true)
    end
    Shaman.PlayAnim(ped, bite.dict, bite.clip, bite.ms, 0)
    Wait(bite.ms)
    if prop and DoesEntityExist(prop) then DeleteObject(prop) end
end

local function giveSequence(otherPed)
    local ped = PlayerPedId()
    if otherPed and DoesEntityExist(otherPed) then
        TaskTurnPedToFaceEntity(ped, otherPed, 1000, 0, 0, 0)
        Wait(800)
    end
    Shaman.PlayAnim(ped, T.give.dict, T.give.clip, T.give.ms, 0)
    Wait(T.give.ms)
end

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if not menu then return end
    -- pup-ui has one active menu: an event for another owner means ours was replaced
    if owner ~= menu.owner then menu = nil; return end
    local m = menu
    if owner == OWNER_TREE then
        if index == 1 then
            return openVisionMenu(m.tree, nil)
        elseif index == 2 then
            local pl = nearestPlayer(T.giveRange)
            if not pl then
                closeMenu()
                return Shaman.Tip(L('tree_no_one'))
            end
            return openVisionMenu(m.tree, GetPlayerServerId(pl))
        end
        return
    end
    -- OWNER_VISION
    local tree = Config.Trees[m.tree]
    if not tree or not tree.visions[index] then return end
    closeMenu()
    if Shaman.busy then return end
    Shaman.busy = true
    CreateThread(function()
        if m.giveTo then
            local pl = GetPlayerFromServerId(m.giveTo)
            giveSequence(pl ~= -1 and GetPlayerPed(pl) or nil)
        else
            eatSequence()
        end
        Shaman.busy = false
        TriggerServerEvent('pup_shaman:server:vision', m.tree, index, m.giveTo)
    end)
end)

-- our menu closed, or another owner's menu (which replaced ours) closed: either way ours is gone
AddEventHandler('pup-ui:client:inkClose', function()
    menu = nil
end)

-- prompt -----------------------------------------------------------------------------------

local function canUseTree()
    return not Shaman.dream and not Shaman.form and not Shaman.busy and not menu and not Rituals.Participating()
end

local function interactLoop()
    if interacting then return end
    interacting = true
    CreateThread(function()
        local shown, refreshAt = false, 0
        while nearIndex do
            local tree = Config.Trees[nearIndex]
            if tree and canUseTree() then
                local now = GetGameTimer()
                if now >= refreshAt then
                    exports['pup-ui']:Prompt({ key = Config.ActionKeyLabel, label = tree.name })
                    refreshAt = now + 300
                    shown = true
                end
                if IsControlJustPressed(0, Config.ActionKey) then
                    exports['pup-ui']:PromptHide()
                    shown, refreshAt = false, 0
                    openTreeMenu(nearIndex)
                end
            elseif shown then
                exports['pup-ui']:PromptHide()
                shown = false
            end
            Wait(0)
        end
        if shown then exports['pup-ui']:PromptHide() end
        interacting = false
    end)
end

-- once a second: props in range, and which tree (if any) is within reach
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local closest, closestDist
        for i, tree in ipairs(Config.Trees) do
            local d = #(pos - tree.coords)
            if d <= T.propDistance then
                if not props[i] then spawnProp(i, tree) end
            elseif props[i] then
                deleteProp(i)
            end
            if d <= T.reach and (not closestDist or d < closestDist) then closest, closestDist = i, d end
        end
        nearIndex = closest
        if nearIndex then interactLoop() end
        Wait(1000)
    end
end)

-- visions ------------------------------------------------------------------------------------

local function dreamLoop()
    CreateThread(function()
        while Shaman.dream do
            Shaman.DisableControls(false)
            local d = Shaman.dream
            if d.endsAt and GetGameTimer() >= d.endsAt and not Shaman.busy then
                Trees.Wake()
                break
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('pup_shaman:client:dream', function(treeIndex, visionIndex, dest)
    local tree = Config.Trees[tonumber(treeIndex) or -1]
    local vision = tree and tree.visions[tonumber(visionIndex) or -1]
    if not vision or type(dest) ~= 'vector3' or Shaman.dream or Shaman.form or Shaman.busy then
        -- tell the server, so it does not think we are dreaming
        return TriggerServerEvent('pup_shaman:server:woke')
    end
    Shaman.busy = true
    local ped = PlayerPedId()
    local origin, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    Shaman.FadeOut()
    Shaman.Teleport(dest)
    local animal = Shaman.BecomeAnimal(vision.model, nil)
    if not animal then
        Shaman.Teleport(origin)
        Shaman.FadeIn()
        Shaman.busy = false
        return TriggerServerEvent('pup_shaman:server:woke')
    end
    Shaman.Shield(animal)
    if vision.filter then Shaman.FxPlay(vision.filter) end
    Shaman.dream = {
        tree = tonumber(treeIndex), vision = vision, origin = origin, heading = heading,
        endsAt = vision.minutes and GetGameTimer() + vision.minutes * 60000 or nil,
    }
    Shaman.FadeIn()
    Shaman.busy = false
    TriggerServerEvent('pup_shaman:server:dreamStarted')
    Shaman.Tip(L('dream_start', vision.label, T.wakeCommand), 6000)
    dreamLoop()
end)

function Trees.Wake()
    local d = Shaman.dream
    if not d or Shaman.busy then return end
    Shaman.busy = true
    Shaman.dream = nil
    Shaman.FadeOut()
    Shaman.FxStop(d.vision.filter)
    Shaman.Teleport(d.origin)
    Shaman.RestoreHuman(false)
    local ped = PlayerPedId()
    SetEntityCoords(ped, d.origin.x, d.origin.y, d.origin.z, false, false, false, false)
    SetEntityHeading(ped, d.heading)
    Shaman.RefillCores()
    TriggerServerEvent('pup_shaman:server:woke')
    Shaman.FadeIn()
    Shaman.busy = false
    Shaman.Tip(L('dream_wake'))
end

RegisterCommand(T.wakeCommand, function()
    if Shaman.dream and not Shaman.busy then
        CreateThread(Trees.Wake)
    end
end, false)

-- after a reconnect mid-vision the server sends the tree we left from
RegisterNetEvent('pup_shaman:client:returnTo', function(spot)
    if type(spot) ~= 'vector3' then return end
    CreateThread(function()
        local t = GetGameTimer() + 60000
        while GetGameTimer() < t and (not IsScreenFadedIn() or not LocalPlayer.state.IsInSession) do Wait(500) end
        Wait(T.returnAfterJoinMs)
        if Shaman.dream or Shaman.form or Shaman.busy then return end
        Shaman.busy = true
        Shaman.FadeOut()
        Shaman.Teleport(spot + vector3(1.5, 0.0, 0.0))
        Shaman.FadeIn()
        Shaman.busy = false
    end)
end)

-- the character changed: the vision just ends (vorp_character spawns the new one)
Shaman.OnReset(function()
    closeMenu()
    local d = Shaman.dream
    if not d then return end
    Shaman.dream = nil
    Shaman.FxStop(d.vision.filter)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    TriggerEvent('vorpinventory:ammoUpdateToggle', true)
end)

Shaman.OnStop(function()
    if menu then exports['pup-ui']:HideInkMenu() end
    if interacting then exports['pup-ui']:PromptHide() end
    for i in pairs(props) do deleteProp(i) end
    local d = Shaman.dream
    if d then
        Shaman.dream = nil
        Shaman.FxStop(d.vision.filter)
        local ped = PlayerPedId()
        SetEntityCoords(ped, d.origin.x, d.origin.y, d.origin.z, false, false, false, false)
        SetEntityInvincible(ped, false)
        SetEntityCanBeDamaged(ped, true)
        ExecuteCommand(Config.Shift.rebuildCommand)
        TriggerEvent('vorpinventory:ammoUpdateToggle', true)
    end
end)
