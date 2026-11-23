-- pup-medical | player lifecycle: disconnect and character switch

AddEventHandler('playerDropped', function()
    local src = source
    ForgetPlayer(src, 'dropped')
    Sessions[src] = nil
end)

-- vorp_core: a character was chosen. A different one than before means
-- everything held for the old character must go (duty, calls, clocks).
AddEventHandler('vorp:SelectedCharacter', function(src, character)
    src = tonumber(src)
    if not src then return end
    local charId = type(character) == 'table' and tonumber(character.charIdentifier) or nil
    local known = Sessions[src]
    if known and charId and known ~= charId then
        Sessions[src] = charId
        ForgetPlayer(src, 'character switch')
    elseif charId then
        Sessions[src] = charId
    end
end)
