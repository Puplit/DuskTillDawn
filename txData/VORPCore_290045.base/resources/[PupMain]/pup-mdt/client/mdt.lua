-- pup-mdt client | opening and closing the clipboard: checks, props, animation, focus, input

MdtC = MdtC or {}

local props = {}
local opening = false

local PROPS = {
    male = {
        { model = 'P_AMB_CLIPBOARD_01', bone = 'SKEL_L_Hand', off = { 0.17, 0.07, 0.08 }, rot = { 80.0, 160.0, 180.0 } },
        { model = 'P_PEN01X', bone = 'SKEL_R_Hand', off = { 0.105, 0.055, -0.13 }, rot = { -5.0, 0.0, 0.0 } },
    },
    female = {
        { model = 'P_AMB_CLIPBOARD_01', bone = 'SKEL_L_Hand', off = { 0.17, 0.07, 0.08 }, rot = { 70.0, 155.0, 185.0 } },
        { model = 'P_PEN01X', bone = 'SKEL_R_Hand', off = { 0.095, 0.045, -0.095 }, rot = { -5.0, 0.0, 0.0 } },
    },
}
local ANIM = {
    male = 'amb_work@world_human_write_notebook@male_a@idle_c',
    female = 'amb_work@world_human_write_notebook@female_a@idle_c',
    clip = 'idle_h',
}

local function gender(pd)
    local g = pd and pd.gender
    if g == 'male' or g == 'female' then return g end
    return IsPedMale(PlayerPedId()) and 'male' or 'female'
end

local function deleteProps()
    for _, obj in ipairs(props) do
        if DoesEntityExist(obj) then
            DetachEntity(obj, true, true)
            DeleteObject(obj)
        end
    end
    props = {}
end

local function spawnProps(g)
    deleteProps()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    for _, p in ipairs(PROPS[g]) do
        local hash = MdtC.loadModel(p.model, 5000)
        if hash then
            local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, false, true, false)
            SetEntityCollision(obj, false, false)
            AttachEntityToEntity(obj, ped, GetEntityBoneIndexByName(ped, p.bone),
                p.off[1], p.off[2], p.off[3], p.rot[1], p.rot[2], p.rot[3], true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(hash)
            props[#props + 1] = obj
        end
    end
end

local function playAnim(g)
    local dict = ANIM[g]
    if not MdtC.loadDict(dict) then return end
    TaskPlayAnim(PlayerPedId(), dict, ANIM.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- refused states, each with its own message
local function blockedReason()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return L('cannot_use_dead') end
    if MdtC.nativeTrue(0x3AA24CCC0D451379, ped) or LocalPlayer.state.hogtied or LocalPlayer.state.isHogtied then return L('cannot_use_hogtied') end
    if MdtC.nativeTrue(0x74E559B3BC910685, ped) or LocalPlayer.state.cuffed or LocalPlayer.state.isCuffed then return L('cannot_use_cuffed') end
    if IsPedRagdoll(ped) or MdtC.nativeTrue(0x4FBACCE3B4138EE6, ped) then return L('cannot_use_incapacitated') end
    if MdtC.nativeTrue(0xC024869A53992F34, ped) or IsPedFalling(ped) then return L('cannot_use_incapacitated') end
    return nil
end

-- local pre-checks, then the server runs the open gate
function MdtC.tryOpen()
    if MdtC.mdtOpen or opening then return end
    local why = blockedReason()
    if why then MdtC.notify(why, 3500) return end
    TriggerServerEvent('pup-mdt:server:open')
end

RegisterNetEvent('pup-mdt:client:tryOpen', function() MdtC.tryOpen() end)

if Config.UseCommand ~= false then
    RegisterCommand(Config.Command or 'mdt', function() MdtC.tryOpen() end, false)
end

---------------------------------------------------------------------------
-- the page config sent with every open
---------------------------------------------------------------------------
local function flatList(groups)
    local out = {}
    for _, g in ipairs(groups or {}) do
        if g.items then
            for _, it in ipairs(g.items) do out[#out + 1] = { name = it.name, label = it.label or it.name } end
        elseif g.name then
            out[#out + 1] = { name = g.name, label = g.label or g.name }
        end
    end
    return out
end

local function boardColor(pd)
    local want = pd and pd.dutyRegion
    for _, r in ipairs((Config.Duty and Config.Duty.regions) or {}) do
        if want and (r.id == want or r.label == want) then return r.boardColor end
    end
    return nil
end

local function pageTheme(isLawyer)
    local t = Config.Theme or {}
    local theme = {
        colors = t.colors, fonts = t.fonts, fontImport = t.fontImport, logo = t.logo,
        stampTint = t.stampTint or 'original', layout = t.layout or 'portrait',
        toastPosition = t.toastPosition or 'bottom-center', regionColors = t.regionColors ~= false,
        letterhead = { line1 = t.name, line2 = t.subtitle, line3 = t.tagline },
    }
    if isLawyer and Config.Legal and Config.Legal.theme then
        local lt = Config.Legal.theme
        theme.lawyerSubtitle = lt.subtitle
        theme.lawyerTagline = lt.tagline
        if lt.colors then theme.colors = lt.colors end
    end
    return theme
end

local function stationList()
    local out = {}
    for i, s in ipairs((Config.Prison and Config.Prison.stations) or {}) do
        out[#out + 1] = { index = i, label = s.label or ('Station ' .. i) }
    end
    return out
end

function MdtC.sendLocale()
    MdtC.send({ action = 'setLocale', locale = Config.Locale, strings = PupMdtLocale.strings() })
end

---------------------------------------------------------------------------
-- open
---------------------------------------------------------------------------
local function watchInput()
    CreateThread(function()
        local ptt = joaat('INPUT_PUSH_TO_TALK')
        while MdtC.mdtOpen do
            Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, ptt, true)
            if LocalPlayer.state.pup_ptt_latched then SetControlNormal(0, ptt, 1.0) end
            if LocalPlayer.state.pup_radio_talking then
                EnableControlAction(0, 249, true)
                SetControlNormal(0, 249, 1.0)
            end
            DisableControlAction(0, Config.Keys.esc, true)
            DisableControlAction(0, Config.Keys.backspace, true)
            if IsDisabledControlJustPressed(0, Config.Keys.esc) then
                MdtC.send({ action = 'escPressed' })
            end
        end
    end)
end

local function watchAnim(g)
    CreateThread(function()
        while MdtC.mdtOpen do
            Wait(1000)
            if MdtC.mdtOpen and not IsEntityPlayingAnim(PlayerPedId(), ANIM[g], ANIM.clip, 3) then playAnim(g) end
        end
    end)
end

RegisterNetEvent('pup-mdt:client:open', function(isLawyer, playerData, settings)
    if MdtC.mdtOpen or opening then return end
    opening = true
    if MdtC.kioskOpen then MdtC.closeKiosk(false) end
    if MdtC.boardOpen and MdtC.closeBoard then MdtC.closeBoard(nil, true) end
    MdtC.mdtOpen = true
    MdtC.isLawyer = isLawyer == true
    TriggerEvent('vorp_inventory:blockInventory', true)
    local g = gender(playerData)
    spawnProps(g)
    Wait(100)
    if not MdtC.mdtOpen then opening = false deleteProps() return end
    playAnim(g)
    Wait(200)
    if not MdtC.mdtOpen then opening = false deleteProps() ClearPedTasks(PlayerPedId()) return end
    watchAnim(g)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    watchInput()
    playerData = playerData or {}
    if settings then playerData.settings = settings end
    MdtC.sendLocale()
    MdtC.send({
        action = 'openMDT',
        isLawyer = MdtC.isLawyer,
        playerData = playerData,
        config = {
            confiscateds = { weapons = flatList(Config.Confiscation and Config.Confiscation.weapons), items = flatList(Config.Confiscation and (Config.Confiscation.contraband or Config.Confiscation.items)) },
            inventoryImagePath = Config.InventoryImagePath,
            theme = pageTheme(MdtC.isLawyer),
            trainings = (Config.Profiles and Config.Profiles.trainings) or {},
            prisonStations = stationList(),
            boardColor = boardColor(playerData),
            nuiDebug = Config.NuiDebug == true,
        },
    })
    -- the alert feed the client already holds
    if MdtC.pushAlerts then MdtC.pushAlerts() end
    if MdtC.ackReminders then MdtC.ackReminders() end
    opening = false
end)

---------------------------------------------------------------------------
-- close
---------------------------------------------------------------------------
-- tellPage=false when the page closed itself
function MdtC.closeMdt(tellPage)
    if not MdtC.mdtOpen then return end
    MdtC.mdtOpen = false
    deleteProps()
    ClearPedTasks(PlayerPedId())
    if not MdtC.pageHoldsFocus() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        TriggerEvent('vorp_inventory:blockInventory', false)
    end
    if tellPage ~= false then MdtC.send({ action = 'closeNUI' }) end
end

RegisterNetEvent('pup-mdt:client:close', function() MdtC.closeMdt(true) end)

-- closes the MDT, the kiosk and both boards, and always lets go of the cursor
function MdtC.closeAllPages()
    if MdtC.mdtOpen then MdtC.closeMdt(true) end
    if MdtC.kioskOpen and MdtC.closeKiosk then MdtC.closeKiosk(true) end
    if MdtC.boardOpen and MdtC.closeBoard then MdtC.closeBoard(nil, true) end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerEvent('vorp_inventory:blockInventory', false)
end

-- death closes every page (checked twice a second, only while one is open)
CreateThread(function()
    while true do
        Wait(500)
        if MdtC.mdtOpen or MdtC.pageHoldsFocus() then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then MdtC.closeAllPages() end
        end
    end
end)

-- a character switch closes every page
RegisterNetEvent('vorp:SelectedCharacter', function()
    if MdtC.mdtOpen or MdtC.kioskOpen or MdtC.boardOpen then MdtC.closeAllPages() end
end)

-- forwarded pushes; dropped while the MDT is closed
RegisterNetEvent('pup-mdt:client:nui', function(msg)
    if type(msg) ~= 'table' or not MdtC.mdtOpen then return end
    MdtC.send(msg)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteProps()
    if MdtC.mdtOpen or MdtC.kioskOpen or MdtC.boardOpen then
        ClearPedTasks(PlayerPedId())
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        TriggerEvent('vorp_inventory:blockInventory', false)
    end
end)
