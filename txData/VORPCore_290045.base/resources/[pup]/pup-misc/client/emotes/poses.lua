-- pup-misc / emotes / poses
-- /photopose <id> and /photoposes. The poses themselves are in config/emotes/poses.lua.
-- Plays through EmotesPlayAnim (client/emotes/main.lua), which owns the dict load,
-- the female-variant swap and the dead/tied/mounted guards. /sa stops.

-- /photopose <id> - the radial calls this with an argument.
-- NOT /pose: pup-ui's posse roster already owns /pose and /posse.
RegisterCommand(EmotesConfig.General.poseCommand, function(_, args)
    local id = args and args[1] and tostring(args[1]):lower()
    if not id or id == '' then
        return TriggerEvent('vorp:TipRight', EmotesLocale.poseUsage, 5000)
    end
    local entry = EmotesConfig.Poses[id]
    if not entry then
        return TriggerEvent('vorp:TipRight', (EmotesLocale.poseUnknown):format(id), 5000)
    end
    if not EmotesPlayAnim then
        return print('^1[pup-misc/poses]^7 client/emotes/main.lua did not load first')
    end
    EmotesPlayAnim(entry)
end, false)

RegisterCommand(EmotesConfig.General.poseListCommand, function()
    local byCat = {}
    for id, e in pairs(EmotesConfig.Poses) do
        byCat[e.cat] = byCat[e.cat] or {}
        byCat[e.cat][#byCat[e.cat] + 1] = ('%s (%s)'):format(id, e.label)
    end
    print('^3[poses]^7 /photopose <id>, /sa to stop')
    for cat, list in pairs(byCat) do
        table.sort(list)
        print(('^5%s^7  %s'):format(cat, table.concat(list, ', ')))
    end
end, false)

TriggerEvent('chat:addSuggestion', '/' .. EmotesConfig.General.poseCommand, EmotesLocale.poseSuggestion, { { name = 'id', help = EmotesLocale.poseArgHelp } })
