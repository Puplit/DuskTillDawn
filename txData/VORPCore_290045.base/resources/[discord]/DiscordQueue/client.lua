Citizen.CreateThread(function()
	while true do 
		Citizen.Wait(0);
		if NetworkIsSessionStarted() then 
			TriggerServerEvent('DiscordQueue:Activated'); -- They got past queue, deactivate them in it
			return 
		end
	end
end)

-- Badger_Discord_API's client half: its server half (discord_api.lua) listens for this
triggered = false;
AddEventHandler("playerSpawned", function()
    if not triggered then 
        triggered = true;
        Citizen.Wait((1000 * 20)); -- Wait 20 seconds
        TriggerServerEvent('Badger_Discord_API:PlayerLoaded');
    end
end)
