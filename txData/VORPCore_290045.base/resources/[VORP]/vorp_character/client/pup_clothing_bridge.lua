-- Modified by Puppet (Dusk Till Dawn), 2026
---@diagnostic disable: undefined-global
-- dressing during creation through pup_clothing's store, not this resource's menus

local pending = nil -- { tbl, value } - what to reopen the creator with

function PupClothingCreatorAvailable()
    if GetResourceState('pup_clothing') ~= 'started' then return false end
    -- dot, not colon: `exports.x:Name` without a call is a syntax error
    local ok, res = pcall(function() return exports['pup_clothing'].OpenCreatorFitting end)
    return ok and res ~= nil
end

function OpenPupClothingFitting(tbl, value)
    if not PupClothingCreatorAvailable() then
        return OpenCharCreationMenu(tbl, value)
    end
    pending = { tbl = tbl, value = value }

    -- open the store on what the creator is currently wearing
    local comps = "{}"
    pcall(function() comps = json.encode(GetNewCompOldStructure(PlayerClothing)) end)

    -- hand the screen over: StartPrompts stops driving its camera
    CreatorFittingActive = true

    local ok = false
    pcall(function() ok = exports['pup_clothing']:OpenCreatorFitting(comps) end)
    if not ok then
        CreatorFittingActive = false
        pending = nil
        return OpenCharCreationMenu(tbl, value)
    end
end

local function backToCreator()
    local p = pending
    pending = nil
    -- let pup_clothing tear its page down first: its destroy runs DestroyAllCams
    CreateThread(function()
        Wait(350)
        CreatorFittingActive = false -- StartPrompts rebuilds and re-frames
        if RefreshCreatorCamPreset then
            Wait(50)
            RefreshCreatorCamPreset()
        end
        if p then OpenCharCreationMenu(p.tbl, p.value) end
    end)
end

-- saved: fold the garments into PlayerClothing so the creator writes them
AddEventHandler('pup_clothing:creatorDone', function(clothz, extras)
    local ok, worn = pcall(json.decode, clothz or "{}")
    if ok and type(worn) == "table" then
        local n = 0
        for slot, hash in pairs(worn) do
            hash = tonumber(hash)
            if hash then
                if type(PlayerClothing[slot]) ~= "table" then PlayerClothing[slot] = {} end
                PlayerClothing[slot].comp = hash
                n = n + 1
            end
        end
        print(("^2[vorp_character]^7 creator fitting: %d slot(s) taken from pup_clothing"):format(n))
        if n > 0 then CreatorClothesOn = true end -- the Clothing row must now say On
    end

    -- `extras` (tints, singleplayer drawables) is deliberately not merged
    backToCreator()
end)

AddEventHandler('pup_clothing:creatorCancelled', backToCreator)
