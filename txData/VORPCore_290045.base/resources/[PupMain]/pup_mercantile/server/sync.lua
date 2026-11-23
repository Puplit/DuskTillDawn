-- pup_mercantile | what each client needs at start and on character select

local lastInit = {}

RegisterNetEvent('pup_mercantile:init', function(wantCatalogue)
    local src = source
    local now = GetGameTimer()
    if lastInit[src] and now - lastInit[src] < 1000 then return end
    lastInit[src] = now
    local char = GetChar(src)
    TriggerClientEvent('pup_mercantile:init', src, {
        charid = char and tonumber(char.charIdentifier) or nil,
        job = char and char.job or nil,
        shops = ShopsReady and ShopListFor(src) or {},
        catalogue = (wantCatalogue and ShopsReady) and ClientCatalogue() or nil,
        raidJobs = RaidJobsHint(), -- prompt hint only; raids are checked again on the server
    })
end)

AddEventHandler('playerDropped', function()
    lastInit[source] = nil
end)

-- remember the player's Discord id so staff lists can mention them
AddEventHandler('vorp:SelectedCharacter', function(src, char)
    src = tonumber(src)
    if not src then return end
    SetTimeout(2000, function()
        local c = GetChar(src) or char
        local discord = DiscordId(src)
        if not c or not discord then return end
        local charid = tonumber(c.charIdentifier or c.charidentifier)
        if not charid then return end
        pcall(MySQL.update.await, 'UPDATE characters SET discordid = ? WHERE charidentifier = ?', { discord, charid })
    end)
end)
