-- pup-misc/coordtool | settings and text (see README)

CoordtoolConfig = {}

-------------------------------------------------------------------------------
-- GENERAL  (chat commands)
-------------------------------------------------------------------------------
CoordtoolConfig.General = {
    commands = {
        toggle = 'coords',        -- show / hide X Y Z H on screen
        copy   = 'cc',            -- copy to the clipboard
        record = 'xcc',           -- send your position to the server list
        list   = 'coordslist',    -- print the server list in chat
        clear  = 'coordsclear',   -- empty the server list
    },
}

CoordtoolConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
CoordtoolConfig.Integrations = {}

-------------------------------------------------------------------------------
-- TEXT
-------------------------------------------------------------------------------
CoordtoolLocale = {
    chatTitle = 'Coords',
    none      = 'No coordinates recorded yet.',
    total     = '^3Total recorded: ',   -- followed by the count
}
