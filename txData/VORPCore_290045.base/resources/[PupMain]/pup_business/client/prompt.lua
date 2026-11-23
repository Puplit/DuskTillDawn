-- pup_business | the interaction prompt at job-menu points and duty stations:
-- the game's own prompt (Config.PromptStyle = 'native') or pup-ui's key pill ('pill')

BizPrompt = {}

local group = GetRandomIntInRange(0, 0xffffff)
local prompt = nil
local shownLabel = nil

local function ensure(label)
    if not prompt then
        prompt = PromptRegisterBegin()
        PromptSetControlAction(prompt, Config.InteractKey)
        PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', label))
        PromptSetEnabled(prompt, true)
        PromptSetVisible(prompt, true)
        PromptSetStandardMode(prompt, true)
        PromptSetGroup(prompt, group)
        PromptRegisterEnd(prompt)
        shownLabel = label
    elseif label ~= shownLabel then
        PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', label))
        shownLabel = label
    end
end

--- Call every frame while the player is in reach. Returns true on the frame the key is used.
--- label = the action ("Job Menu"), title = the heading above it (the business or region).
function BizPrompt.show(label, title)
    if Config.PromptStyle == 'pill' then
        exports['pup-ui']:Prompt({ key = Config.InteractLabel, label = label })
        return IsControlJustReleased(0, Config.InteractKey)
    end
    ensure(label)
    PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', title or label))
    return PromptHasStandardModeCompleted(prompt)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and prompt then PromptDelete(prompt) end
end)
