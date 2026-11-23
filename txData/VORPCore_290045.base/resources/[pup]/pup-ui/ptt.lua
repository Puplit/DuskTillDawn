-- pup-ui | push-to-talk inside NUI menus: a drop-in other resources load as '@pup-ui/ptt.lua'
-- It wraps SetNuiFocus so voice (latched mic and radio) keeps working while a page has focus.

local PTT   <const> = `INPUT_PUSH_TO_TALK`
local RADIO <const> = 249

local pttFocused = false
local pttThread  = false
local nativeSetNuiFocus = SetNuiFocus

-- keep voice alive for this frame; everything else stays disabled
local function passVoiceThrough()
	EnableControlAction(0, PTT, true)
	if LocalPlayer.state.pup_ptt_latched then
		SetControlNormal(0, PTT, 1.0)
	end
	if LocalPlayer.state.pup_radio_talking then
		EnableControlAction(0, RADIO, true)
		SetControlNormal(0, RADIO, 1.0)
		SetControlNormal(1, RADIO, 1.0)
		SetControlNormal(2, RADIO, 1.0)
	end
end

-- deliberately not short-circuited when focus is unchanged
function SetNuiFocus(hasFocus, hasCursor)
    nativeSetNuiFocus(hasFocus, hasCursor)
    SetNuiFocusKeepInput(hasFocus and true or false)

    pttFocused = hasFocus and true or false
    if not pttFocused or pttThread then return end

    pttThread = true
    CreateThread(function()
        while pttFocused do
            Wait(0)
            DisableAllControlActions(0)
            passVoiceThrough()
        end
        pttThread = false
    end)
end

-- if the resource stops mid-menu the loop dies with it; controls return on their own
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        pttFocused = false
    end
end)
