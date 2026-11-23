-- pup-misc / bandana - server half

-- server/cannon/main.lua sets this first; reuse it rather than fetching a second copy
VorpCore = VorpCore or exports.vorp_core:GetCore()

RegisterServerEvent('pup-misc:bandana:getComps')
AddEventHandler('pup-misc:bandana:getComps', function()
    local src = source
    local user = VorpCore and VorpCore.getUser(src)
    local Character = user and user.getUsedCharacter
    if not Character then
        return TriggerClientEvent('pup-misc:bandana:comps', src, nil)
    end

    local raw = Character.comps
    if type(raw) ~= 'string' or raw == '' then
        return TriggerClientEvent('pup-misc:bandana:comps', src, nil)
    end
    TriggerClientEvent('pup-misc:bandana:comps', src, raw)
end)
