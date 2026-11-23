-- pup-misc / instance - isolates the player while vorp_character's creator is open

AddEventHandler('vorpcharacter:startCharacterCreator', function()
    TriggerServerEvent('pup-misc:instance:creatorStart')
end)
