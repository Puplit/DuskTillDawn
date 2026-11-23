-- pup_tailor | client core: questions to the server, sign-in, job and blips, the bench prompt, sessions.
local U = Tailor.U
local Cat = Tailor.Cat
local Ped = Tailor.Ped

local S = {
    job = nil,
    staff = false,
    hiddenSet = {},       -- [unsigned drawable] = true
    catalogue = nil,      -- Cat.build(hiddenSet)
    paletteNames = {},
    session = nil,        -- { id, bench, preview, savedSide }
    changing = false,     -- a clothes change is running
    pressing = false,     -- a prompt press is being handled
}
Tailor.S = S

function Tailor.tip(text, ms) TriggerEvent('vorp:TipBottom', text, ms or 4000) end
function Tailor.tipRight(text, ms) TriggerEvent('vorp:TipRight', text, ms or 4000) end

---------------------------------------------------------------------------
-- questions with a time limit
---------------------------------------------------------------------------
local askSeq = 0
local waiting = {}

-- returns the server's answer values, or nil after timeoutMs
function Tailor.ask(name, timeoutMs, ...)
    askSeq = askSeq + 1
    local id = askSeq
    local p = promise.new()
    waiting[id] = p
    TriggerServerEvent('pup_tailor:ask', id, name, ...)
    SetTimeout(timeoutMs or 5000, function()
        if waiting[id] then
            waiting[id] = nil
            p:resolve({ n = 0 })
        end
    end)
    local res = Citizen.Await(p)
    if res.n == 0 then return nil end
    return table.unpack(res, 1, res.n)
end

RegisterNetEvent('pup_tailor:answer', function(id, ...)
    local p = waiting[id]
    if not p then return end
    waiting[id] = nil
    p:resolve(table.pack(...))
end)

---------------------------------------------------------------------------
-- catalogue (rebuilt when the hidden list changes)
---------------------------------------------------------------------------
function Tailor.catalogue()
    if not S.catalogue then S.catalogue = Cat.build(S.hiddenSet) end
    return S.catalogue
end

RegisterNetEvent('pup_tailor:hidden', function(list)
    local set = {}
    for _, d in ipairs(type(list) == 'table' and list or {}) do
        local u = U.unsigned(d)
        if u then set[u] = true end
    end
    -- replace, never just add: a restored garment comes back
    S.hiddenSet = set
    S.catalogue = Cat.build(set)
    if Tailor.Menus and Tailor.Menus.catalogueChanged then Tailor.Menus.catalogueChanged() end
end)

RegisterNetEvent('pup_tailor:staff', function(flag) S.staff = flag == true end)

RegisterNetEvent('pup_tailor:paletteNames', function(map)
    S.paletteNames = type(map) == 'table' and map or {}
    if Tailor.Book and Tailor.Book.namesChanged then Tailor.Book.namesChanged() end
end)

---------------------------------------------------------------------------
-- job and blips
---------------------------------------------------------------------------
local blips = {}

local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function buildBlips()
    clearBlips()
    for _, bench in ipairs(Config.Benches) do
        local show = false
        for _, j in ipairs(bench.jobs or {}) do
            if j == S.job then show = true break end
        end
        if show then
            local p = bench.prompt
            local b = Citizen.InvokeNative(0x554D9D53F696D002, Config.Blip.style, p.x, p.y, p.z)
            SetBlipSprite(b, bench.sprite, true)
            SetBlipScale(b, Config.Blip.scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, CreateVarString(10, 'LITERAL_STRING', bench.name))
            blips[#blips + 1] = b
        end
    end
end

local function benchTakesJob(bench, job)
    if not bench.jobLocked then return true end
    for _, j in ipairs(bench.jobs or {}) do
        if j == job then return true end
    end
    return false
end

RegisterNetEvent('pup_tailor:job', function(job)
    S.job = type(job) == 'string' and job or nil
    buildBlips()
    -- lost the job mid-session: the bench is no longer theirs
    local sess = S.session
    if sess and not sess.preview and not benchTakesJob(sess.bench, S.job) then
        Tailor.tip(L('lostAccess'), 5000)
        Tailor.endSession()
    end
end)

local function signIn()
    TriggerServerEvent('pup_tailor:signIn')
end

---------------------------------------------------------------------------
-- sessions
---------------------------------------------------------------------------
local sessionSeq = 0

function Tailor.sessionActive(id)
    return S.session ~= nil and (id == nil or S.session.id == id)
end

function Tailor.endSession()
    local sess = S.session
    if not sess then return end
    S.session = nil
    Ped.showroom(false)
    if Tailor.Menus then Tailor.Menus.reset() end
    if Tailor.Book then Tailor.Book.close(true) end
    Ped.removeMannequin()
    pcall(function() exports['pup-ui']:SetMenuSide(sess.savedSide or 'left') end)
    FreezeEntityPosition(PlayerPedId(), false)
end

local function startSession(bench, preview)
    if S.session then return end
    local ped = PlayerPedId()
    if Ped.blocked(ped) or IsPedOnMount(ped) then return end
    sessionSeq = sessionSeq + 1
    local side = 'left'
    pcall(function() side = exports['pup-ui']:GetMenuSide() or 'left' end)
    S.session = { id = sessionSeq, bench = bench, preview = preview, savedSide = side }
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    if preview then Tailor.tip(L('browsingOnly'), 6000) end
    Tailor.Menus.openMain()

    -- end the session if the player is hogtied, cuffed or killed
    local id = sessionSeq
    CreateThread(function()
        while Tailor.sessionActive(id) do
            Wait(500)
            if Tailor.sessionActive(id) and Ped.blocked() then
                -- endSession hides our menu (only ours) and closes the book
                Tailor.endSession()
            end
        end
    end)
end

local function onPress(bench)
    if S.pressing then return end
    S.pressing = true
    local preview = false
    if bench.jobLocked then
        local job = Tailor.ask('job', 5000)
        if job == nil then
            S.pressing = false
            return Tailor.tip(L('noAnswer'), 4000)
        end
        S.job = job
        preview = not benchTakesJob(bench, job)
    end
    startSession(bench, preview)
    S.pressing = false
end

---------------------------------------------------------------------------
-- the prompt
---------------------------------------------------------------------------
local prompt, promptGroup = nil, GetRandomIntInRange(0, 0xffffff)

local function createPrompt()
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Keys.open)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', L('promptText')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, promptGroup, 0)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, prompt, true)
    PromptRegisterEnd(prompt)
end

local function promptAllowed()
    if S.session or S.changing or S.pressing then return false end
    if Tailor.Menus and Tailor.Menus.isOpen() then return false end
    if IsPedOnMount(PlayerPedId()) then return false end
    return true
end

local function nearBench()
    local pos = GetEntityCoords(PlayerPedId())
    for _, b in ipairs(Config.Benches) do
        if #(pos - b.prompt) <= Config.PromptDistance then return b end
    end
    return nil
end

CreateThread(function()
    Wait(1000)
    createPrompt()
    while true do
        local bench = nearBench()
        if bench and promptAllowed() then
            -- near a bench: draw every frame, re-check the distance twice a second
            local until_ = GetGameTimer() + 500
            while GetGameTimer() < until_ and promptAllowed() do
                PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', L('promptGroup')), 0, 0, 0, 0)
                local done = Citizen.InvokeNative(0xC92AC953F0A982AE, prompt)
                if done == true or done == 1 then
                    CreateThread(function() onPress(bench) end)
                    Wait(250)
                    break
                end
                Wait(0)
            end
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- sign-in, character switch, resource stop
---------------------------------------------------------------------------
-- vorp_core sends this from the server (TriggerClientEvent), so it must be registered as a net event here
RegisterNetEvent('vorp:SelectedCharacter', function()
    Tailor.endSession()
    if Tailor.Wear and Tailor.Wear.characterChanged then Tailor.Wear.characterChanged() end
    signIn()
end)

CreateThread(function()
    Wait(2000)
    signIn()
end)

-- vorp_admin world cleanup is about to delete the mannequin (a networked ped): close the
-- bench first so no menu is left dressing a ped that is gone
RegisterNetEvent('vorp_admin:worldCleanup', function()
    Tailor.endSession()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- only hide the ink menu when it is ours; another resource's menu is left alone
    if Tailor.Menus and Tailor.Menus.isOpen() then
        pcall(function() exports['pup-ui']:HideInkMenu() end)
    end
    if prompt then PromptDelete(prompt) end
    clearBlips()
    if Tailor.Book then Tailor.Book.close(true) end
    SetNuiFocus(false, false)
    Ped.showroom(false)
    Ped.removeMannequin()
    local sess = S.session
    S.session = nil
    if sess then
        pcall(function() exports['pup-ui']:SetMenuSide(sess.savedSide or 'left') end)
    end
    -- unfreeze only what we froze (a session or a clothes change), never another resource's freeze
    if sess or S.changing then FreezeEntityPosition(PlayerPedId(), false) end
end)
