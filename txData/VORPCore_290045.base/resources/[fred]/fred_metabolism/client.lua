local next = next
local checked = false
local playerstatus = {}
local ingame = false
local crazydrunk = false 
local reallycold = false
local temp = 0
local water = Config.Needs.initialWater
local starveTick = 0 -- seconds counted toward the next starvation damage tick
local food = Config.Needs.initialFood
local metabolism = Config.Metabolism.initial

local drunken = 0
local timer = 0

local timer2 = 0
local hard = 0

local IsPlayerLoaded = false
local FirstCheck = false

local Exempt = false
RegisterNetEvent("fred_meta:exempt")
AddEventHandler("fred_meta:exempt", function(state)
    Exempt = state
    if Exempt then
        food, water = 100, 100
    end
end)

local Anims = {

    ["eat"] = {
            dict = "mech_inventory@eating@multi_bite@sphere_d8-2_sandwich",
            name = "quick_left_hand", 
            flag = 24
        },
    ["drink"] = {
            dict = "amb_rest_drunk@world_human_drinking@male_a@idle_a",
            name = "idle_a", 
            flag = 24
	},
  
}

local Vomits = {
	["vomit1"] = {
			dict = "amb_misc@world_human_vomit@male_a@idle_a",
			name = "idle_a" ,
			flag = 0,
	},
	["vomit2"] = {
		dict = "amb_misc@world_human_vomit@male_a@idle_c",
		name = "idle_g" ,
		flag = 0,
	},
	["vomit3"] = {
		dict = "amb_misc@world_human_vomit@male_a@idle_c",
		name = "idle_h" ,
		flag = 0,
	},    
}

local BodyCustomization = {

    BodySizes = {
        61606861,
        -1241887289,
        -369348190,
        32611963,
        -20262001
    },
    WaistSizes = {
        -2045421226,
        -1745814259,
        -325933489,
        -1065791927,
        -844699484,
        -1273449080,
        927185840,
        149872391,
        399015098,
        -644349862,
        1745919061,
        1004225511,
        1278600348,
        502499352,
        -2093198664,
        -1837436619,
        1736416063,
        2040610690,
        -1173634986,
        -867801909,
        1960266524
    }
}

local ClotheList ={
    0x9925C067, -- Hat
    0x2026C46D, -- Shirt
    0x1D4C528A, -- Pants
    0x777EC6EF, -- Boots
    0xE06D30CE, -- Coats
    0x662AC34, -- Closed Coats
    0xEABE0032, -- Gloves
    0x485EE834, -- Vest
    0xAF14310B, -- Ponchos 1
    0x3C1A74CD -- Ponchos 2
}


function getThirst()
	return water
end

function getHunger()
	return food
end

-- clothing-adjusted temperature for fred_hud's thermometer
function getEffectiveTemp()
	if not ingame then return nil end
	return temp
end


function PlayAnimation(ped, anim)
	if not DoesAnimDictExist(anim.dict) then
		return
	end

	RequestAnimDict(anim.dict)

	while not HasAnimDictLoaded(anim.dict) do
		Wait(0)
	end

	TaskPlayAnim(ped, anim.dict, anim.name, 1.0, 1.0, -1, anim.flag, 0, false, false, false, '', false)

	RemoveAnimDict(anim.dict)
end

local screeneffects = {}

function ScreenEffect(effect, time)
	table.insert(screeneffects,effect)
	--Citizen.InvokeNative(0x4102732DF6B4005F, effect)
	AnimpostfxPlay(effect)
	Citizen.Wait(time)
	--Citizen.InvokeNative(0xB4FD7446BAB2F394, effect)
	AnimpostfxStop(effect)
	crazydrunk = false
end

RegisterNetEvent('pup_camps:washedface')
AddEventHandler('pup_camps:washedface', function() 
	for k, hightypex in pairs(screeneffects) do
    	Citizen.InvokeNative(0x516C6ABD18322B63, PlayerPedId(), false)
    	Citizen.InvokeNative(0x95D2D383D5396B8A, PlayerPedId(), false)
    	if Citizen.InvokeNative(0x4A123E85D7C4CA0B,hightypex) then 
    	    Citizen.InvokeNative(0xB4FD7446BAB2F394,hightypex)
    	end
		screeneffects[k] = nil
	end

end)

-- sleeves1 = rolled sleeves (/sleeves), sleeves2 = open collar (/sleeves2)
local sleeves1 = false
local sleeves2 = false

-- What each one COSTS you in warmth
local function rolledClothingPenalty()
	local penalty = 0
	if sleeves1 then penalty = penalty + (Config.Warmth.rolledSleevesPenalty or 0) end
	if sleeves2 then penalty = penalty + (Config.Warmth.openCollarPenalty or 0) end
	return penalty
end

RegisterNetEvent("pup-clothing:sleevestoggle")
AddEventHandler("pup-clothing:sleevestoggle", function(x, y)
	sleeves1 = x
	sleeves2 = y
end)
-- effective-temperature computation, separate from the needs loop
local function RecomputeEffectiveTemp()
	local player = PlayerPedId()
	local coords = GetEntityCoords(player)
	Citizen.InvokeNative(0xB98B78C3768AF6E0,true)
	temp = math.floor(GetTemperatureAtCoords(coords))

	do
			-- Checks if the player is wearing clothes
			--for k,v in pairs(ClotheList) do
				    local isWearingHat = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[1])
        	        local isWearingShirt = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[2])
        	        local isWearingPants = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[3])
        	        local isWearingBoots = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[4])
        	        local isWearingCoat = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[5])
        	        local isWearingClosedCoat = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[6])
        	        local isWearingGloves = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[7])
        	        local isWearingVest = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[8])
        	        local isWearingPonchoOne = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[9])
        	        local isWearingPonchoTwo = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, ClotheList[10])
        	        local isWearingMask = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x7505EF42)

					
				if not reallycold then
        	        if isWearingHat then
        	            temp = temp + Config.Warmth.hat--1
        	        end

        	        if isWearingShirt then
        	            temp = temp + Config.Warmth.shirt --2
        	        end

        	        if isWearingPants then
        	            temp = temp + Config.Warmth.pants --2
        	        end

        	        if isWearingBoots then
        	            temp = temp + Config.Warmth.boots --2
        	        end

        	        if isWearingCoat then
        	            temp = temp + Config.Warmth.coat --3
					elseif isWearingClosedCoat then
						temp = temp + Config.Warmth.closedCoat --4
					else
						-- no coat: rolled sleeves and an open collar each cost their own warmth, and they stack
						temp = temp - rolledClothingPenalty()
        	        end

        	        if isWearingGloves then
        	            temp = temp + Config.Warmth.gloves --1
        	        end

        	        if isWearingVest then
        	            temp = temp + Config.Warmth.vest --1
        	        end

        	        if isWearingPonchoOne then
        	            temp = temp + Config.Warmth.poncho --5
        	        end

        	        if isWearingPonchoTwo then
        	            temp = temp + Config.Warmth.poncho --5
        	        end

        	        -- MaskTemp was dead config - the code hardcoded a mask as +3 hot AND cold drain instead
        	        if isWearingMask then
        	            temp = temp + (Config.Warmth.mask or 0)
        	        end
				else
					if isWearingHat then
        	            temp = temp - Config.Warmth.hat--1
        	        end

        	        if isWearingShirt then
        	            temp = temp - Config.Warmth.shirt --2
        	        end

        	        if isWearingPants then
        	            temp = temp - Config.Warmth.pants --2
        	        end

        	        if isWearingBoots then
        	            temp = temp - Config.Warmth.boots --2
        	        end

        	        if isWearingCoat then
        	            temp = temp - Config.Warmth.coat --3
					elseif isWearingClosedCoat then
						temp = temp - Config.Warmth.closedCoat --4
					else
						-- same rule in the really-cold branch
						temp = temp - rolledClothingPenalty()
        	        end

        	        if isWearingGloves then
        	            temp = temp - Config.Warmth.gloves --1
        	        end

        	        if isWearingVest then
        	            temp = temp - Config.Warmth.vest --1
        	        end

        	        if isWearingPonchoOne then
        	            temp = temp - Config.Warmth.poncho --5
        	        end

        	        if isWearingPonchoTwo then
        	            temp = temp - Config.Warmth.poncho --5
        	        end

        	        if isWearingMask then
        	            temp = temp - (Config.Warmth.mask or 0)
        	        end
				end
        	    --[[local IsWearingClothes = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, v)
        	    if IsWearingClothes then
        	        temp = temp + 1
        	    end
			end]]--
	end

	-- INDOORS bonus - inside any interior you are sheltered
	if (Config.Warmth.interior or 0) ~= 0 and GetInteriorFromEntity(player) ~= 0 then
		temp = temp + Config.Warmth.interior
	end
end

-- fast recompute: keeps ambient/interior drift fresh (250ms = effectively live
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(250)
		if ingame and not Exempt then
			RecomputeEffectiveTemp()
		end
	end
end)

-- INSTANT updates - recompute the moment clothing actually changes instead of waiting for the next poll
AddEventHandler("pup-clothing:sleevestoggle", function()
	if ingame and not Exempt then RecomputeEffectiveTemp() end
end)
AddEventHandler("vorp_character:Client:OnClothingAdded", function()
	if ingame and not Exempt then
		Citizen.Wait(100) -- let the ped variation settle before re-reading
		RecomputeEffectiveTemp()
	end
end)
AddEventHandler("vorp_character:Client:OnClothingRemoved", function()
	if ingame and not Exempt then
		Citizen.Wait(100)
		RecomputeEffectiveTemp()
	end
end)

-- DEFINED HERE, ABOVE EVERY CALLER
local function ColdPoints()
	local c = tonumber(Config.Temperature.coldBelow) or 0
	return c, c - 10, c - 12, c - 14   -- cold, then the 50/75/100% food steps
end

-- HEALTH damage steps, straight from config and independent of MinTemperature.
local function ColdHurtPoints()
	return tonumber(Config.ColdDamage.hurtAt) or -4,
		tonumber(Config.ColdDamage.worseAt) or -6,
		tonumber(Config.ColdDamage.dyingAt) or -8
end

-- DAMAGE ----------------------------------------------------------------------
-- Read the real max rather than assuming 100. vorp_core spawns players at 600
-- (spawnplayer.lua), so a flat "1 hp" was 0.17% of a bar.
local function MaxHp(ped)
	local m = tonumber(GetEntityMaxHealth(ped)) or 0
	if m <= 0 then m = 600 end
	return m
end

-- Take health AND pull the health core down with it.
--
-- vorp_core runs HealthRecharge at x2 (config/config.lua), so entity health on
-- its own is simply healed straight back - which is why the pain grunt played
-- and the bar never moved. The core is what caps regen, and it is also the ring
-- the player actually watches, so it has to fall too.
--
-- `pct` and `floorPct` are PERCENTAGES of max health. Returns the health left.
function HurtPlayer(ped, pct, floorPct)
	local maxHp <const> = MaxHp(ped)
	local dmg <const> = math.max(1, math.floor(maxHp * ((tonumber(pct) or 0) / 100) + 0.5))

	local newHp = (tonumber(GetEntityHealth(ped)) or maxHp) - dmg
	local floorHp <const> = floorPct and math.floor(maxHp * (floorPct / 100) + 0.5) or 0
	if newHp < floorHp then newHp = floorHp end
	if newHp < 0 then newHp = 0 end

	SetEntityHealth(ped, ToInteger(newHp), nil)

	-- core follows health, downward only: regen can never exceed it
	local fraction <const> = math.floor((newHp / maxHp) * 100 + 0.5)
	local core <const> = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger())) or 100
	if core > fraction then
		Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, fraction) -- SetAttributeCoreValue
	end

	if Config.General.debug then
		print(("[fred_metabolism] hurt %.2f%% = %d hp (max %d) -> %d left, core %d -> %d")
			:format(tonumber(pct) or 0, dmg, maxHp, newHp, core, math.min(core, fraction)))
	end
	return newHp
end

Citizen.CreateThread(function()
    while true do
		Citizen.Wait(0)
		if ingame and not Exempt then
			RecomputeEffectiveTemp()
			local hot = 0
			local cold = 0

			if (food < 0) then
				food = 0
			end
		
			if (food > 100) then
				food = 100
			end
		
			if water < 0 then
				water = 0
			end
		
			if water > 100 then
				water = 100
			end

			if temp > Config.Temperature.hotAbove then
				hot = Config.Temperature.hotWaterLoss
			else
				hot = 0
			end

			-- THE COLD PENALTY IS GRADED, not a cliff
			local coldAt, hurtAt, worseAt, dyingAt = ColdPoints()
			if temp < coldAt then
				local full = tonumber(Config.Temperature.coldFoodLoss) or 0
				local step = 0.25
				if temp <= dyingAt then step = 1.0
				elseif temp <= worseAt then step = 0.75
				elseif temp <= hurtAt then step = 0.5 end
				cold = full * step
			else
				cold = 0
			end
			-- the old hardcoded mask rule (+3 hot AND cold drain) is gone

			-- base drain for the current movement state
			local foodLoss, waterLoss
			if IsPedRunning(PlayerPedId()) then
				foodLoss, waterLoss = Config.Needs.foodDrain.running, Config.Needs.waterDrain.running
			elseif IsPedWalking(PlayerPedId()) then
				foodLoss, waterLoss = Config.Needs.foodDrain.walking, Config.Needs.waterDrain.walking
			else
				foodLoss, waterLoss = Config.Needs.foodDrain.idle, Config.Needs.waterDrain.idle
			end

			if Config.Temperature.enabled then
				foodLoss = foodLoss + cold
				waterLoss = waterLoss + hot
			end

			food = food - foodLoss
			water = water - waterLoss
			Citizen.Wait(Config.Needs.tickMs)
		end
	end
end)
local cooolmecheck = false


-- TEMPERATURE CHECK
Citizen.CreateThread(function()
    while true do
		Citizen.Wait(60000)
		if ingame and not Exempt then
			if Config.Temperature.enabled then
				-- tier 1 is "you are cold" and follows the FOOD threshold; tiers 2 and 3 warn about health
				local coldAt = (ColdPoints())
				local COLD_HURT, _, COLD_DIE = ColdHurtPoints()
				local t = tonumber(temp) or 0
				-- Temperature Checks
				if Config.Framework.vorp then
					if t <= COLD_DIE then
						TriggerEvent("vorp:NotifyLeft", Locale.tempTitleFreezing, Locale.tempNotify3, "rpg_textures", "rpg_cold", 4000)
						cooolmecheck = true
					elseif t <= COLD_HURT then
						TriggerEvent("vorp:NotifyLeft", Locale.tempTitleColder, Locale.tempNotify2, "rpg_textures", "rpg_cold", 4000)
						cooolmecheck = true
					elseif t < coldAt then
						TriggerEvent("vorp:NotifyLeft", Locale.tempTitleCold, Locale.tempNotify1, "rpg_textures", "rpg_cold", 4000)
						cooolmecheck = true
					else
						cooolmecheck = false
					end
				end
				if Config.Framework.redEm then
					if t <= COLD_DIE then
						TriggerEvent("redem_roleplay:NotifyLeft", Locale.tempTitleFreezing, Locale.tempNotify3, "rpg_textures", "rpg_cold", 4000)
					elseif t <= COLD_HURT then
						TriggerEvent("redem_roleplay:NotifyLeft", Locale.tempTitleColder, Locale.tempNotify2, "rpg_textures", "rpg_cold", 4000)
					elseif t < coldAt then
						TriggerEvent("redem_roleplay:NotifyLeft", Locale.tempTitleCold, Locale.tempNotify1, "rpg_textures", "rpg_cold", 4000)
				--	elseif tonumber(roundtemp) <= 20 then 
				--		TriggerEvent("redem_roleplay:NotifyLeft", "~o~Temperature", "Feeling hot, quench your thirst often!", "rpg_textures", "rpg_hot", 3000)
				--	elseif tonumber(roundtemp) <= 25 then 
					--	TriggerEvent("redem_roleplay:NotifyLeft", "~d~Temperature", "You are hot, seek shelter and quench your thirst often!", "rpg_textures", "rpg_hot", 3000)
					--elseif tonumber(roundtemp) <= 30 then 
						--TriggerEvent("redem_roleplay:NotifyLeft", "~t2 ~Temperature", "You're too hot, look for shelter, otherwise it's the end!", "rpg_textures", "rpg_hot", 3000)
					end
				end
			end
		end
    end
end)

function ToInteger(number)
    number = tonumber(number)
    if number ~= nil then 
        if 0 >  number then 
            number = number * -1
        end
        return math.floor(number or error("Could not cast '" .. tostring(number) .. "' to number.'"))
    else
        return 0
    end
end
 -- TEMPERATURE DAMAGE EFFECT
Citizen.CreateThread(function()
	while true do
		Wait(6000)
		if Config.Temperature.enabled then
			local ped = PlayerPedId()
			-- see HurtPlayer below: damage is a % of the real max, not raw points
			-- a corpse does not get colder
			if ingame and cooolmecheck and not Exempt and not IsEntityDead(ped) then
				local rate = 0
				-- same ladder the tier 2/3 warnings use, so "you will die" and the health actually dropping line up (see ColdHurtPoints
				local cHurt, cHurtMore, cDying = ColdHurtPoints()
				local t = tonumber(temp) or 0
				if t <= cDying then
					rate = tonumber(Config.ColdDamage.dyingPct) or 6.5
				elseif t <= cHurtMore then
					rate = tonumber(Config.ColdDamage.worsePct) or 2.5
				elseif t <= cHurt then
					rate = tonumber(Config.ColdDamage.hurtPct) or 1.0
				end

				if rate > 0 then
					local floorPct = (not Config.ColdDamage.canKill) and (tonumber(Config.ColdDamage.floorPct) or 50) or nil
					local left = HurtPlayer(ped, rate, floorPct)
					if Config.ColdDamage.canKill and left <= 0 then
						-- kill it the way starvation does rather than setting 0 and hoping: a raw zero leaves the death system to notice
						Citizen.InvokeNative(0x697157CED63F18D4, ped, 500000, false, true, true) -- ApplyDamageToPed
					elseif floorPct == nil or left > 0 then
						PlayPain(ped, 9, 1, true, true)
					end
				end
			end
		end
	end
end) 

RegisterNetEvent("pup:cold")
AddEventHandler("pup:cold", function()
	reallycold = true
	Wait(60000)
	reallycold = false
end)

Citizen.CreateThread(function()
    while true do
		Citizen.Wait(1000)
		if ingame and not Exempt then 
			local showNotification1 = false
			local showNorification2 = false

			if food <= Config.Needs.lowFoodWarnAt and not shownotifiaction2 then
				shownotifiaction1 = true
				if Config.Framework.redEm then
					TriggerEvent("redem_roleplay:Tip", Locale.lowFood, 3000)
				end
				if Config.Framework.vorp then
					TriggerEvent("vorp:Tip", Locale.lowFood, 3000)
				end
			end

			if water <= Config.Needs.lowWaterWarnAt and not shownotifiaction1 then
				shownotifiaction2 = true
				if Config.Framework.redEm then
					TriggerEvent("redem_roleplay:Tip", Locale.lowWater, 3000)
				end
				if Config.Framework.vorp then
					TriggerEvent("vorp:Tip", Locale.lowWater, 3000)
				end
			end

			shownotifiaction2 = not shownotifiaction2
			shownotifiaction1 = not shownotifiaction1

			-- <=, not <. food and water are clamped to 0 further up, so the old
			-- "food < 0" could never be true and this block never ran at all.
			if food <= Config.Starvation.foodAt or water <= Config.Starvation.waterAt then
				starveTick = starveTick + 1
				local every <const> = math.max(1, tonumber(Config.Starvation.intervalSeconds) or 4)
				if starveTick >= every then
					starveTick = 0
					local ped <const> = PlayerPedId()
					PlayPain(ped, 9, 1, true, true)
					local left <const> = HurtPlayer(ped, tonumber(Config.Starvation.damagePct) or 2.0)
					if left <= 0 then
						Citizen.InvokeNative(0x697157CED63F18D4, ped, 500000, false, true, true) -- ApplyDamageToPed
						food = 100
						water = 100
					end
				end
			else
				starveTick = 0
			end
		end
    end
end)

function updatePlayerBody(ped, bodyPart1, bodypart2)
	Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, bodyPart1) -- Changes bodysize
	Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, bodypart2) -- Changes waist
	Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) --updates bodycomponents	
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if ingame and not Exempt then 
			local ped = PlayerPedId()
			
			if (metabolism < 1) then
				metabolism = 0
			end

			if (metabolism > 20000) then
				metabolism = 20000
			end

			if IsPedRunning(ped) then
				metabolism = metabolism - Config.Metabolism.loss.running
			elseif IsPedWalking(ped) then
				-- pup: was MetabolismLossRunning (copy-paste) - walking burned as much as running
				metabolism = metabolism - Config.Metabolism.loss.walking
			else
				metabolism = metabolism - Config.Metabolism.loss.idle
			end

			if Config.Metabolism.bodyChanges then
				if (metabolism > 0) and (metabolism <= 2500) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[2], BodyCustomization.WaistSizes[1])	
				end
			
				if (metabolism > 2500) and (metabolism <= 5000) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[2], BodyCustomization.WaistSizes[21])	
				end
			
				if (metabolism > 5000) and (metabolism <= 7500) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[3], BodyCustomization.WaistSizes[1])		
				end
			
				if (metabolism > 7500) and (metabolism <= 12500) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[3], BodyCustomization.WaistSizes[21])	
				end
			
				if (metabolism > 12500) and (metabolism <= 15000) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[5], BodyCustomization.WaistSizes[1])
				end
			
				if (metabolism > 15000) and (metabolism <= 17500) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[5], BodyCustomization.WaistSizes[21])
				end

				if (metabolism > 17500) and (metabolism <= 20000) then
					updatePlayerBody(ped, BodyCustomization.BodySizes[4], BodyCustomization.WaistSizes[21])	
				end		
			end
			if Config.Framework.vorp then
				--local statusx = {food = food, water = water, metabolism = metabolism}
				TriggerServerEvent("fred_meta:setStatus", food, water, metabolism)
				--TriggerServerEvent("fred_meta:savedtodb", statusx)
			end
			if Config.Framework.redEm and IsPlayerLoaded then
				TriggerServerEvent("fred_meta:setStatus", food, water, metabolism)
			end
			if Config.Framework.redEm and not IsPlayerLoaded then
				print("^4[Waiting for player to load...]^0")
			end
			Citizen.Wait(Config.Metabolism.tickMs)
		end
	end
end)

-- EVENT, USE THIS FOR OTHER RESOURCES
RegisterNetEvent("fred_meta:consume")
-- the metabolism PARAM was named the same as the file-local `metabolism`
AddEventHandler("fred_meta:consume", function(hunger, thirst, metabo, innercorestamina, innercorestaminagold, outercorestaminagold, innercorehealth, innercorehealthgold, outercorehealthgold)
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)

	hunger = tonumber(hunger) or 0
	thirst = tonumber(thirst) or 0
	innercorestamina = tonumber(innercorestamina) or 0
	innercorehealth = tonumber(innercorehealth) or 0

	food = food + hunger
	water = water + thirst
	metabolism = metabolism + (tonumber(metabo) or 0)
	if Config.General.debug then
		print(("^3[fred_meta]^7 consume event -> food %.1f water %.1f metabolism %d"):format(food, water, metabolism))
	end
	TriggerServerEvent("fred_meta:setStatus", food, water, metabolism)

	if (food < 0) then
		food = 0
	end

	if (food > 100) then
		food = 100
	end

	if water < 0 then
		water = 0
	end

	if water > 100 then
		water = 100
	end

	if (innercorestamina ~= 0) then
		stamina = Citizen.InvokeNative(0x36731AC041289BB1, ped, 1, Citizen.ResultAsInteger()) --ACTUAL STAMINA CORE GETTER
		newStamina = stamina + tonumber(innercorestamina)

		if (newStamina > 100) then
		newStamina = 100
		end
		Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, newStamina)
	end

	if (innercorehealth ~= 0)then
		health = Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger()) --ACTUAL HEALTH CORE GETTER
		newHealth = health + tonumber(innercorehealth)

		if (newHealth > 100) then
		newHealth = 100
		end
		Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, newHealth)
	end

		-- TO DO OUTER CORE HEALTH parametro = outerCoreHealth GOLDS - BOTH gold natives take a FLOAT
	local function goldValue(v)
		return (tonumber(v) or 0) + 0.0
	end

	local innerStamGold = goldValue(innercorestaminagold)
	local outerStamGold = goldValue(outercorestaminagold)
	local innerHealGold = goldValue(innercorehealthgold)
	local outerHealGold = goldValue(outercorehealthgold)

	if innerStamGold ~= 0.0 then
		Citizen.InvokeNative(0x4AF5A4C7B9157D14, PlayerPedId(), 1, innerStamGold, true)
	end
	if outerStamGold ~= 0.0 then
		Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 1, outerStamGold, true)
	end
	if innerHealGold ~= 0.0 then
		Citizen.InvokeNative(0x4AF5A4C7B9157D14, PlayerPedId(), 0, innerHealGold, true)
	end
	if outerHealGold ~= 0.0 then
		Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 0, outerHealGold, true)
	end

	if Config.General.debug then
		print(("^3[fred_meta]^7 gold cores -> stamina inner %.1f outer %.1f | health inner %.1f outer %.1f")
			:format(innerStamGold, outerStamGold, innerHealGold, outerHealGold))
	end
end)

function vomitLogic()
	hard = hard + 1
	timer2 = 60000
	if hard == 1 then
		local vomitchance = math.random(1,10) -- 10% chance
		if vomitchance == 1 then
			local vom = math.random(1,3)
			PlayAnimation(PlayerPedId(), Vomits["vomit"..vom])
		end
	elseif hard == 2 then
		local vomitchance = math.random(1, 4) -- 25% chance
		if vomitchance == 1 then
			local vom = math.random(1,3)
			PlayAnimation(PlayerPedId(), Vomits["vomit"..vom])
		end
	elseif hard == 3 then
		local vomitchance = math.random(1, 2) -- 50% chance
		if vomitchance == 1 then
			local vom = math.random(1,3)
			PlayAnimation(PlayerPedId(), Vomits["vomit"..vom])
		end
	elseif hard == 4 then
		local vomitchance = math.random(1, 1) -- 100% chance
		if vomitchance == 1 then
			local vom = math.random(1,3)
			PlayAnimation(PlayerPedId(), Vomits["vomit"..vom])
		end
	elseif hard == 5 then
		SetPedToRagdoll(PlayerPedId(-1), 60000, 60000, 0, 0, 0, 0)
		ScreenEffect("PlayerDrunk01", 5000)
		ScreenEffect("PlayerDrunk01_PassOut", 30000)
		hard = 0
	end
end


local prop
local prop2
-- SKILL CHECK ON CONSUME (pup-minigames skill_bar) An item with Diff > 0 makes the player pass a skill bar before it
-- Diff = 0, which is the column default and what every pre-existing row has,
-- skips the bar entirely
local function skillCheckFor(diff, cb)
    diff = tonumber(diff) or 0
    if diff <= 0 then return cb(true) end

    if GetResourceState('pup-minigames') ~= 'started' then
        -- never hold an item hostage to a resource that is not running
        print('^3[fred_meta]^7 pup-minigames is not started - skill check skipped')
        return cb(true)
    end

    -- 5000 is the common value and should be comfortable; 3000 is noticeably tighter; 10000 is generous
    local scale <const> = math.max(0.3, math.min(2.0, diff / 5000))
    local ok, err = pcall(function()
        exports['pup-minigames']:skill_bar({
            style             = 'default',
            icon              = 'fa-solid fa-syringe',
            orientation       = 1,
            area_size         = math.floor(12 + (10 * scale)),  -- 15 .. 32
            perfect_area_size = 5,
            speed             = math.max(0.25, 0.9 - (0.3 * scale)),
            moving_icon       = false,
            icon_speed        = 3,
        }, function(success)
            cb(success == 'perfect' or success == 'success')
        end)
    end)
    if not ok then
        print(('^1[fred_meta]^7 skill check failed to start (%s) - consuming anyway'):format(tostring(err)))
        cb(true)
    end
end

-- THE EFFECT, applied from a resolved item table.
-- Separate from fred_meta:useItem so a caller that builds its item at runtime
-- (pup-gangs gives every gang its own drug) runs through THIS code rather than
-- standing up a second stat system. `entry` is the same shape as a
-- Config.Consumables row, plus an optional DurationMs after which the gold
-- cores are released again.
local function applyConsumable(entry)
	TriggerEvent("vorp_inventory:CloseInv")

	if not entry then return end

	-- the bar first; everything below only runs on a pass
	local passed = nil
	skillCheckFor(entry["Diff"], function(result) passed = result end)
	local waited = 0
	while passed == nil and waited < 60000 do
		Wait(50)
		waited = waited + 50
	end
	if passed == false then
		TriggerEvent("vorp:TipBottom", Locale.skillBotched, 4000)
		return
	end

	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	-- `or 0` guards - config items without Hunger/Thirst/Metabolism keys crashed here with nil arithmetic (Metabolism is
	food = food + (tonumber(entry["Hunger"]) or 0)
	water = water + (tonumber(entry["Thirst"]) or 0)
	metabolism = metabolism + (tonumber(entry["Metabolism"]) or 0)
	if Config.General.debug then
		print(("^3[fred_meta]^7 consumed %s -> food %.1f water %.1f metabolism %d"):format(
			tostring(entry["Name"]), food, water, metabolism))
	end
	TriggerServerEvent("fred_meta:setStatus", food, water, metabolism)
	-- CORES
	if (entry["InnerCoreStamina"] ~= 0) then
		local stamina = Citizen.InvokeNative(0x36731AC041289BB1, PlayerPedId(), 1, Citizen.ResultAsInteger())
		if stamina == false then
			newStamina = tonumber(entry["InnerCoreStamina"])
			Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 1, newStamina)
		else
			stamina = Citizen.InvokeNative(0x36731AC041289BB1, PlayerPedId(), 1, Citizen.ResultAsInteger()) --ACTUAL STAMINA CORE GETTER
			newStamina = stamina + tonumber(entry["InnerCoreStamina"])

			if (newStamina > 100) then
			newStamina = 100
			end
			Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 1, newStamina)
		end
	end

	if (entry["InnerCoreHealth"] ~= 0)then
		health = Citizen.InvokeNative(0x36731AC041289BB1, PlayerPedId(), 0, Citizen.ResultAsInteger()) --ACTUAL HEALTH CORE GETTER
		newHealth = health + tonumber(entry["InnerCoreHealth"])

		if (newHealth > 100) then
		newHealth = 100
		end
		Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 0, newHealth)
	end

		--TO DO OUTER CORE HEALTH parametro = outerCoreHealth

	-- GOLDS
	local function goldValue(v)
		return (tonumber(v) or 0) + 0.0
	end

	local innerStamGold = goldValue(entry["InnerCoreStaminaGold"])
	local outerStamGold = goldValue(entry["OuterCoreStaminaGold"])
	local innerHealGold = goldValue(entry["InnerCoreHealthGold"])
	local outerHealGold = goldValue(entry["OuterCoreHealthGold"])

	if innerStamGold ~= 0.0 then
		Citizen.InvokeNative(0x4AF5A4C7B9157D14, PlayerPedId(), 1, innerStamGold, true)
	end
	if outerStamGold ~= 0.0 then
		Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 1, outerStamGold, true)
	end
	if innerHealGold ~= 0.0 then
		Citizen.InvokeNative(0x4AF5A4C7B9157D14, PlayerPedId(), 0, innerHealGold, true)
	end
	if outerHealGold ~= 0.0 then
		Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 0, outerHealGold, true)
	end

	-- DEAD EYE buffs (attribute index 2) - the original had health and stamina only
	if (tonumber(entry["InnerCoreDeadeye"]) or 0) ~= 0 then
		local de = Citizen.InvokeNative(0x36731AC041289BB1, PlayerPedId(), 2, Citizen.ResultAsInteger())
		local newDe = (tonumber(de) or 0) + tonumber(entry["InnerCoreDeadeye"])
		if newDe > 100 then newDe = 100 end
		if newDe < 0 then newDe = 0 end
		Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 2, newDe)
	end
	if (tonumber(entry["InnerCoreDeadeyeGold"]) or 0) ~= 0 then
		Citizen.InvokeNative(0x4AF5A4C7B9157D14, PlayerPedId(), 2, goldValue(entry["InnerCoreDeadeyeGold"]), true)
	end
	if (tonumber(entry["OuterCoreDeadeyeGold"]) or 0) ~= 0 then
		Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 2, goldValue(entry["OuterCoreDeadeyeGold"]), true)
	end

	if (food < 0) then
		food = 0
	end

	if (food > 100) then
		food = 100
	end

	if water < 0 then
		water = 0
	end

	if water > 100 then
		water = 100
	end
	-- ANIMATIONS - delegated to animations.lua (adds "smoke"
	local animKey = entry["Animation"]
	local propName = entry["PropName"]
	local effect = entry["Effect"]
	local effectDuration = tonumber(entry["EffectDuration"]) or 0
	if animKey and animKey ~= "" then
		-- the item's own name, so the drink prompt says what it actually is
		local label <const> = entry["DisplayName"] or entry["Label"] or entry["Name"]
		Citizen.CreateThread(function()
			executeAnimation(animKey, propName, label)
		end)
	end
	if effect and effect ~= "" and effectDuration > 0 then
		Citizen.CreateThread(function()
			screenEffect(effect, effectDuration / 1000)
		end)
	end

	
	-- TIMED BUFF: gold (fortified) cores normally sit there until the engine
	-- decays them. DurationMs releases them on a clock instead, so a caller can
	-- say how long its effect lasts.
	local holdMs = tonumber(entry["DurationMs"]) or 0
	if holdMs > 0 and (innerStamGold ~= 0.0 or outerStamGold ~= 0.0 or innerHealGold ~= 0.0 or outerHealGold ~= 0.0
		or (tonumber(entry["InnerCoreDeadeyeGold"]) or 0) ~= 0 or (tonumber(entry["OuterCoreDeadeyeGold"]) or 0) ~= 0) then
		Citizen.CreateThread(function()
			Wait(holdMs)
			local ped = PlayerPedId()
			for _, idx in ipairs({ 0, 1, 2 }) do
				Citizen.InvokeNative(0x4AF5A4C7B9157D14, ped, idx, 0.0, true)
				Citizen.InvokeNative(0xF6A7C08DF2E28B28, ped, idx, 0.0, true)
			end
		end)
	end
end

RegisterNetEvent("fred_meta:useItem")
AddEventHandler("fred_meta:useItem", function(index)
	applyConsumable(Config.Consumables[index])
end)

-- Runtime consumable: the caller passes the whole resolved item table. Used by
-- pup-gangs, whose drug effect is per GANG and cannot live in a config row.
RegisterNetEvent("fred_meta:applyEffect")
AddEventHandler("fred_meta:applyEffect", function(entry)
	if type(entry) ~= "table" then return end
	applyConsumable(entry)
end)

Citizen.CreateThread(function()
    Wait(1000)
	if Config.General.debug then
		TriggerServerEvent("fred_meta:checkStatus")
		TriggerEvent("vorpcharacter:refreshPlayerSkin")
	end
end) 



if Config.Framework.vorp then
	RegisterNetEvent("vorp:SelectedCharacter")
	AddEventHandler("vorp:SelectedCharacter", function(charid)
		TriggerServerEvent("fred_meta:checkStatus")
		TriggerEvent("vorpcharacter:refreshPlayerSkin")
	end)
end
RegisterNetEvent("fred_meta:updateconfig")
AddEventHandler("fred_meta:updateconfig", function(newconfig)
	Config.Consumables = newconfig
end)


if Config.Framework.redEm then
	RegisterNetEvent("fred_meta:PlayerLoaded")
	AddEventHandler("fred_meta:PlayerLoaded", function()
		IsPlayerLoaded = true
		if IsPlayerLoaded then
			print("^2[Player loaded!]^0")
		end
	end)
end
RegisterNetEvent("fred_meta:switch")
AddEventHandler("fred_meta:switch", function(x)
	ingame = x
end)

RegisterNetEvent("fred_meta:applyChanges")
AddEventHandler("fred_meta:applyChanges", function(hunger, thirst, metabo)
	if hunger ~= nil then 
		food = hunger
	end
	if food > 100 then 
		food = 100 
	end
	if thirst ~= nil then 
		water = thirst
	end
	if water > 100 then 
		water = 100 
	end
	if metabo ~= nil then
		metabolism = metabo
	end
	if Config.General.debug then
		print(("^2[fred_meta]^7 status restored from server: food %.1f water %.1f metabolism %d - drains ACTIVE"):format(food, water, metabolism))
	end
	ingame = true
	TriggerEvent("fred_meta:isready")
end)


-- /temp - real-time temperature readout
RegisterCommand(Config.General.tempCommand, function()
	local player = PlayerPedId()
	local ambient = math.floor(GetTemperatureAtCoords(GetEntityCoords(player)))
	local clothes = temp - ambient
	local state = Locale.tempComfortable
	if temp < Config.Temperature.coldBelow then
		state = Locale.tempTooCold
	elseif temp > Config.Temperature.hotAbove then
		state = Locale.tempTooHot
	end

	-- itemized readout: the SAME category natives + config values the loop uses, so what prints is exactly what counts
	local W <const> = Config.Warmth
	local function worn(hash) return Citizen.InvokeNative(0xFB4891BD7578CDC1, player, hash) end
	local parts = {}
	local function add(label, value)
		parts[#parts + 1] = ("%s %+d"):format(label, value or 0)
	end
	if worn(0x9925C067) then add(Locale.tempPartHat, W.hat) end
	if worn(0x2026C46D) then add(Locale.tempPartShirt, W.shirt) end
	if worn(0x1D4C528A) then add(Locale.tempPartPants, W.pants) end
	if worn(0x777EC6EF) then add(Locale.tempPartBoots, W.boots) end
	local hasCoat = worn(0xE06D30CE)
	local hasClosedCoat = (not hasCoat) and worn(0x662AC34)
	if hasCoat then add(Locale.tempPartCoat, W.coat)
	elseif hasClosedCoat then add(Locale.tempPartClosedCoat, W.closedCoat) end
	if worn(0xEABE0032) then add(Locale.tempPartGloves, W.gloves) end
	if worn(0x485EE834) then add(Locale.tempPartVest, W.vest) end
	if worn(0xAF14310B) then add(Locale.tempPartPoncho, W.poncho) end
	if worn(0x3C1A74CD) then add(Locale.tempPartCloak, W.poncho) end
	if worn(0x7505EF42) then add(Locale.tempPartMask, W.mask) end
	if (W.interior or 0) ~= 0 and GetInteriorFromEntity(player) ~= 0 then
		parts[#parts + 1] = Locale.tempIndoors:format(W.interior)
	end
	-- rolled clothing only costs warmth while NO coat covers it
	if not hasCoat and not hasClosedCoat then
		if sleeves1 then parts[#parts + 1] = Locale.tempSleevesRolled:format(W.rolledSleevesPenalty or 0) end
		if sleeves2 then parts[#parts + 1] = Locale.tempCollarOpen:format(W.openCollarPenalty or 0) end
	elseif sleeves1 or sleeves2 then
		parts[#parts + 1] = Locale.tempRolledCovered
	end
	local detail = (#parts > 0) and (": " .. table.concat(parts, ", ")) or ""

	TriggerEvent("vorp:TipRight",
		Locale.tempReadout:format(temp, ambient, clothes, detail, state), 6000)
	if Config.General.debug then
		print(("^3[fred_meta]^7 /temp: effective %d ambient %d clothes %+d | cold below %d, hot above %d | food %.1f water %.1f metabolism %d"):format(
			temp, ambient, clothes, Config.Temperature.coldBelow, Config.Temperature.hotAbove, food, water, metabolism))
	end
end, false)
