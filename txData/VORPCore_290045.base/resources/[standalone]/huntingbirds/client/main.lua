-- huntingbirds | prompts for the bird that is out, start-up and shutdown

local K <const> = Config.Keys

CreateThread(function()
    local shoulder = Cl.newGroup()
    local pTalk   = Cl.prompt(K.talk, Locale.talk, shoulder)
    local pHome   = Cl.prompt(K.sendHome, Locale.sendHome, shoulder)
    local pFollow = Cl.prompt(K.follow, Locale.follow, shoulder)
    local pHunt   = Cl.prompt(K.hunt, Locale.hunt, shoulder)
    local pSell   = Cl.prompt(K.sell, Locale.sell, shoulder)

    local follow = Cl.newGroup()
    local pLand   = Cl.prompt(K.land, Locale.land, follow)
    local pCam    = Cl.prompt(K.camera, Locale.changeView, follow)

    local selling = Cl.newGroup()
    local pStop   = Cl.prompt(K.stopSell, Locale.stopSelling, selling)

    while true do
        local sleep = 500
        local st = Bird.state
        if Bird.ped and st ~= 'none' then sleep = 100 end
        if Bird.ped and Cl.exists(Bird.ped) and Bird.data and not Cl.uiOwner and not Bird.nearCarcass then
            local player = PlayerPedId()
            local tied = Cl.isHogtied(player)
            if st == 'shoulder' then
                sleep = 0
                Cl.showGroup(shoulder, Bird.data.name)
                if not tied then
                    if Cl.pressed(pTalk) then
                        TriggerEvent('huntingbirds:checktalk')
                    elseif Cl.pressed(pHome) then
                        Bird.sendHome(false)
                    elseif Cl.pressed(pFollow) then
                        CreateThread(Bird.follow)
                    elseif Cl.pressed(pHunt) then
                        Bird.askHunt()
                    elseif Cl.pressed(pSell) then
                        TriggerServerEvent('pup_huntingbirds:check_sell')
                    end
                end
            elseif st == 'following' then
                sleep = 0
                Cl.showGroup(follow, Bird.data.name)
                if not tied then
                    if Cl.pressed(pLand) then
                        CreateThread(Bird.land)
                    elseif Cl.pressed(pCam) then
                        Bird.camToggle()
                    end
                end
            elseif st == 'selling' then
                sleep = 0
                DisableControlAction(0, 0xF8982F00, true)
                Cl.showGroup(selling, ('%s $%s'):format(Locale.sellingLabel, Util.money(Bird.salePrice or 0)))
                if not tied and Cl.pressed(pStop) then Sell.stop() end
            end
        end
        Wait(sleep)
    end
end)

-- a fresh character never inherits the previous one's bird
RegisterNetEvent('vorp:SelectedCharacter', function()
    if Bird.isOut() then Bird.reset(false) end
    if Shop.isOpen() then Shop.close() end
end)

CreateThread(function()
    -- after a restart the server may still think a bird is out
    TriggerServerEvent('huntingbirds:birdhome')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Bird.camOff()
    LocalPlayer.state:set('pup_cam_owned', false, false)
    if Bird.carry then Cl.deleteEntity(Bird.carry) end
    Cl.deleteEntity(Bird.ped)
    if Cl.uiOwner then
        pcall(function() exports['pup-ui']:HideInkMenu() end)
        ClearPedTasks(PlayerPedId())
    end
    if Bird.state == 'landing' or Bird.state == 'selling' then ClearPedTasks(PlayerPedId()) end
end)
