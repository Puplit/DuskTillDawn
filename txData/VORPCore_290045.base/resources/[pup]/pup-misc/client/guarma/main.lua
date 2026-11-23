-- pup-misc / guarma - client half

local prompt, promptGroup
local crossing = false

local GUARMA_HASHES <const> = {
    [joaat('GuarmaD')] = true,
    [joaat('Guarma')] = true,
}

local function inGuarma()
    return GUARMA_HASHES[GetMapZoneAtCoords(GetEntityCoords(PlayerPedId()), 10)] == true
end

-- Map, water and the island flag
local function setWorldState(onIsland)
    Citizen.InvokeNative(0x74E2261D2A66849A, onIsland)
    Citizen.InvokeNative(0xE8770EE02AEE45C2, onIsland and 1 or 0)
    Citizen.InvokeNative(0xA657EC9DBC6CC900, onIsland and 1935063277 or -1868977180)
end

local function ensurePrompt()
    if prompt then return end
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, GuarmaConfig.Keys.board)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', GuarmaLocale.board))
    -- registered OFF: an enabled prompt owns its key everywhere, and this server already has dozens bound to G
    PromptSetEnabled(prompt, false)
    PromptSetVisible(prompt, false)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
end

local function cross(to)
    if crossing then return end
    crossing = true

    DoScreenFadeOut(800)
    while IsScreenFadingOut() do Wait(0) end

    local ped <const> = PlayerPedId()
    RequestCollisionAtCoord(to.x, to.y, to.z)
    SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    setWorldState(to == GuarmaConfig.Docks.island)

    local waited = 0
    while not HasCollisionLoadedAroundEntity(ped) and waited < 10000 do
        Wait(100)
        waited = waited + 100
    end
    -- the island drops you into the sea if the ground has not streamed yet
    waited = 0
    while IsPedFalling(ped) and waited < 5000 do
        Wait(500)
        waited = waited + 500
        SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    end

    Wait(500)
    DoScreenFadeIn(800)
    crossing = false
end

RegisterNetEvent('pup-misc:guarma:board', function(to)
    cross(to == 'island' and GuarmaConfig.Docks.island or GuarmaConfig.Docks.mainland)
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    ensurePrompt()

    -- Logged out on the island: put the world state back or the map is wrong
    -- until the next crossing.
    Wait(2000)
    if inGuarma() then setWorldState(true) end

    while true do
        local sleep = 1000
        if not crossing then
            local c <const> = GetEntityCoords(PlayerPedId())
            local dm <const> = #(c - vector3(GuarmaConfig.Docks.mainland.x, GuarmaConfig.Docks.mainland.y, GuarmaConfig.Docks.mainland.z))
            local di <const> = #(c - vector3(GuarmaConfig.Docks.island.x, GuarmaConfig.Docks.island.y, GuarmaConfig.Docks.island.z))
            local near <const> = (dm <= GuarmaConfig.Docks.promptDistance and 'island')
                or (di <= GuarmaConfig.Docks.promptDistance and 'mainland')
                or nil

            if near then
                sleep = 0
                PromptSetEnabled(prompt, true)
                PromptSetVisible(prompt, true)
                PromptSetActiveGroupThisFrame(promptGroup,
                    CreateVarString(10, 'LITERAL_STRING', near == 'island' and GuarmaLocale.toGuarma or GuarmaLocale.toMainland))
                if PromptHasStandardModeCompleted(prompt) then
                    -- the server checks job, price and ticket, then sends us back
                    TriggerServerEvent('pup-misc:guarma:request', near)
                end
            else
                PromptSetEnabled(prompt, false)
                PromptSetVisible(prompt, false)
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then setWorldState(false) end
end)
