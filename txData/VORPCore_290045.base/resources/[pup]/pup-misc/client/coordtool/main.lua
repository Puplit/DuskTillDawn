local coordsVisible = false

local function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
	SetTextCentre(centre)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
	Citizen.InvokeNative(0xADA9255D, 1);
    DisplayText(str, x, y)
end

Citizen.CreateThread(function()
    while true do
		local sleepThread = 250
		
		if coordsVisible then
			sleepThread = 5

			local playerPed = PlayerPedId()
			local playerX, playerY, playerZ = table.unpack(GetEntityCoords(playerPed))
			local playerH = GetEntityHeading(playerPed)

            DrawTxt("X = "..playerX.. " Y = " ..playerY.. " Z = " ..playerZ.." H = " ..playerH.." ", 0.60, 0.93, 0.4, 0.4, true, 0, 255, 85, 255, true)
		end

		Citizen.Wait(sleepThread)
	end
end)

local FormatCoord = function(coord)
	if coord == nil then
		return "unknown"
	end

	return tonumber(string.format("%.2f", coord))
end

local ToggleCoords = function()
	coordsVisible = not coordsVisible
end

RegisterCommand(CoordtoolConfig.General.commands.toggle, function()
    ToggleCoords()
end)
local function round(number, decimals)
    local scale = 10^decimals
    local c = 2^52 + 2^51
    return ((number * scale + c ) - c) / scale
end
RegisterCommand(CoordtoolConfig.General.commands.record, function()
	local playerPed = PlayerPedId()
	local playerX, playerY, playerZ = table.unpack(GetEntityCoords(playerPed))
	local coords = "{x="..round(playerX, 2)..",y="..round(playerY, 2)..",z="..round(playerZ, 2).."},"
    TriggerServerEvent('pup-misc:coords:record',coords)
end)

RegisterCommand(CoordtoolConfig.General.commands.copy, function(source, args, rawCommand)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local x, y, z = coords.x, coords.y, coords.z
    local h = GetEntityHeading(ped)
    local useTableFormat = false

    -- Check if first arg is "1" for table format
    local argOffset = 0
    if #args > 0 and args[1] == "1" then
        useTableFormat = true
        argOffset = 1
    end

    -- Check if user provided 3 coordinate arguments
    if #args >= argOffset + 3 then
        local argX = tonumber(args[argOffset + 1])
        local argY = tonumber(args[argOffset + 2])
        local argZ = tonumber(args[argOffset + 3])
        
        if argX and argY and argZ then
            x, y, z = argX, argY, argZ
        end
    end

    local coordsString
    if useTableFormat then
        coordsString = string.format("{x = %.3f, y = %.3f, z = %.3f},", x, y, z)
    else
        coordsString = string.format("%.3f %.3f %.3f", x, y, z)
    end

    -- Send to NUI for clipboard copy
    SendNUIMessage({
        action = "copy",
        text   = coordsString
    })

    -- Feedback in F8 console
    print("Copied coords to clipboard: " .. coordsString)
end)
